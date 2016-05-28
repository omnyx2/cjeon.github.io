---
layout: post
title: Eval을 활용해 Redis 성능 개선하기
tags: Redis, ruby, benchmark, test, 레디스, 루비, 벤치마크, 테스트
---

며칠 전 Redis를 처음 접했는데요, 지금까지 사용해왔던 RDBMS와 많이 달라 재밌기도 하고, '어라, 이게 왜 안되지' 싶은 상황도 있었습니다. Redis는 memory에 올려져있는 만큼 아주 빠른 속도를 보장하지만, single threaded 라 쿼리 하나 하나에 신중을 가해서 실행해야 합니다. 예를 들어 Redis 공식 문서에 "절대 production에서 사용하지 말아라"라고 적혀있는 Keys함수는 DB의 성능을 엄청나게 저하시킬 수 있죠. 이 이야기는 나중에 더 하도록 하고, 오늘의 주제에 대해 이야기해보겠습니다.

# 1.Eval이란?
[Eval](http://redis.io/commands/EVAL)은 Redis에서 공식적으로 제공하는 함수입니다. 인자로

1. 스크립트
2. 키의 개수
3. (0개 이상의) 데이터를 받고,  

스크립트의 결과를 아웃풋으로 내보냅니다. 이때 스크립트는 Lua를 이용해 작성된 스크립트이고, 데이터는 KEYS와 ARGV의 형태로 스크립트 내에서 인식됩니다. 아래 코드를 보시죠.

``` redis
>eval "return {KEYS[1],KEYS[2],ARGV[1],ARGV[2]}" 2 key1 key2 first second
1) "key1"
2) "key2"
3) "first"
4) "second"
```

이제 하나 하나 분석해보겠습니다. 먼저, 가장 첫줄은 다음과 같습니다.

1. **함수호출, eval**  
Eval 함수를 호출하고, 뒤에 오는 데이터를 인자로 넘겨줍니다.  
2. **첫번째 인자, "return {KEYS[1],KEYS[2],ARGV[1],ARGV[2]}"**  
string 형태의 Lua 스크립트입니다. 스크립트 내용은 한 줄 짜리 return statement네요. KEYS[1], KEYS[2], ARGV[1], ARGV[2]를 리턴하네요.  
3. **두번째 인자, 2**  
위에서 인자로 '스크립트, 키의 개수, 데이터…'를 받는다고 말씀드렸습니다. '2’는 키의 개수입니다. 즉, 이 인자(2) 뒤에 오는 데이터 중 2개가 KEY이고, 나머지는 ARGV라는 것을 LUA가 알 수 있게 해줍니다.
4. **나머지 인자, key1 key2 first second**  
총 네 개의 데이터가 들어왔는데요, 위에서 명시된 대로 두번째 까지는 KEY이고, 나머지는 ARGV로 인식됩니다. 즉, 인풋 데이터는 루아 내에서 `KEYS = [key1, key2]`, `ARGVS = [first, second]`로 인식됩니다.

그런데 KEYS[**0**], KEYS[**1**]이 아니라 KEYS[**1**], KEYS[**2**]를 리턴하네요? 네, 그렇습니다. LUA에서는 숫자를 1부터 셉니다! 이 점 유념하시면서, Eval의 활용에 대해 이야기해보겠습니다.

# 2. Eval의 활용
Eval은 Redis에 **새로운 함수를 추가하는 것**과 같다고 생각하시면 됩니다. 서버사이드에서 처리하는 것보다 DB에서 처리한 뒤 결과만 가져오는 게 편할 때가 있죠. 항상 사용하는 (RDBMS의) select 쿼리를 DB가 처리하지 않고 서버가 테이블에 있는 데이터를 모조리 긁어와서 그 안에서 찾는다고 하면 좀 끔찍하죠? 그런데 지금 사용하고 있는 DB가 select를 지원하지 않으면… 어떡하죠? select뿐만 아니라 **'DB side에서 하는 게 훨씬 나을 것 같은데’라고 생각되는 기능이 있는데 그 DB가 필요한 함수를 제공하지 않을 때 Eval을 사용하시면 됩니다.** 내가 원하는 기능을 Lua 스크립트로 직접 짜서 구현하는 거죠.

**하지만 Eval은 절대 남용되어서는 안되고, 아주 주의하면서 쓰셔야합니다.** 가장 큰 이유는 Redis가 single threaded이기 때문입니다. Redis는 하나의 명령(쿼리)이 들어오면 그 명령이 끝나기 전에는 어떤 명령도 받지 않습니다. 만약 구현한 script의 러닝타임이 아주 길다면, 그 **script가 실행되고 있는 동안에는 다른 모든 쿼리가 멈춰버리는 대참사가 일어날 수 있습니다.** 따라서 Eval을 이용하실 때는 script의 time complexity를 꼭 계산해보시는 걸 추천합니다. Redis 기본 함수의 complexity는 [Redis 공식 홈페이지](http://redis.io/commands/)에 모두 공개되어 있습니다. 예를 들어 GET 커맨드는 O(1)이고, 극악의 KEYS 커맨드는 O(N)입니다. 

# 3. Eval 활용 예시
이제 제가 Eval을 어떤 경우에 사용했는지를 설명드리겠습니다.

## 1. 상황
아주 긴급한 상황에 사용되는 특수한 기능이 있습니다. **이 기능은 아주 중요해서 이 기능의 실행이 다른 기능의 실행을 느리게 하더라도 괜찮습니다.** 이 기능은 "매일 자동으로 실행되어야 하는 아주 중요한 작업이 알 수 없는 오류로 인해 작동하지 않았을 경우" 수동으로 그 작업을 진행하는 기능입니다.  

함수가 느려지는 부분을 간략히 설명하면 다음과 같습니다.  

```
인풋 : 없음  
아웃풋 : 적당히 많은 KEYS에 해당하는 ZSET 크기의 합.  
```
KEYS는 Ruby Array에 담겨 있습니다. 간단히 하기 위해 예시에서는 `KEYS = %w(KEY0 KEY2 KEY3 … KEY99999)` 로 하겠습니다.  

기본 설정은 다음과 같습니다.

``` ruby
redis = Redis.new(host: '127.0.0.1', db: 1)
=> #<Redis client v3.2.1 for redis://127.0.0.1:6379/1>
KEYS = 100_000.times.collect do |i| "KEY#{i}" end
=> ["KEY0", "KEY1", ... , "KEY99999"]
KEYS.each do |key|  
  redis.zadd(key, 0, "DATA")
end
```

## 2. Naïve Approach

아웃풋은 ZSET 크기의 합입니다. 이는 Redis가 기본적으로 제공하는 [ZCARD](http://redis.io/commands/zcard) 함수를 이용해서 간단하게 구할 수 있습니다. [ZCARD](http://redis.io/commands/zcard) 함수는 O(1)의 time complexity를 가지고 있습니다. 

``` redis
redis> ZADD myzset 1 "one"
(integer) 1
redis> ZADD myzset 2 "two"
(integer) 1
redis> ZCARD myzset
(integer) 2
```

십만 번의 ZCARD에 시간이 얼마나 걸릴지 계산해봅시다. 다음 코드를 쓰면 간단히 구할 수 있습니다.

``` ruby
require 'redis'
require 'benchmark'
redis = Redis.new(db: 1)
KEYS = 100_000.times.collect do |i| "KEY#{i}" end
KEYS.each do |key|
  redis.zadd(key, 0, "DATA")
end
Benchmark.bm do |bm|
  bm.report(:zcard_100_000_times) do
    sum = 0
    KEYS.each do |key|
      sum += redis.zcard(key)
    end
  end
end

# 결과 =>
user     system      total        real
zcard_100_000_times
5.520000   5.850000  11.370000 (  9.494240)
```
총 `9494ms`, 한 번에 겨우 `0.0949ms`밖에 걸리지 않네요. 네트워크 레이턴시가 없다는 게 엄청난 것 같습니다. (제가 google에 ping을 하면 `4ms` 정도 걸립니다.)


## 3. Eval approach
Localhost라서 network delay가 없는 점, 그리고 아무도 DB를 쓰지 않고 있다는 점을 감안해도 `0.094ms`은 아주 짧은 시간인 것 같습니다. 여기서 굳이 script를 쓸 필요가 있을까 싶기도 한데, 의심을 잠시 제쳐두고 eval을 사용해봅시다.

``` ruby
require 'redis'
require 'benchmark'
redis = Redis.new(db: 1)
KEYS = 100_000.times.collect do |i| "KEY#{i}" end
script = "local sum=0;
for index, key in pairs(KEYS) do
  sum = sum + redis.call('zcard', key)
  end;
return sum;"
Benchmark.bm do |bm|
  rep = bm.report(:eval_script_once) do
    redis.eval(script, KEYS)
  end
end

# 결과
eval_script_once
user     system      total        real
0.080000   0.010000   0.090000 (  0.192150)
```
총 실행 시간이 `190ms` 로 나오네요. 위에서 계산한 값 (`9494ms`)보다 **49배나 빠릅니다.**  

## 4. 왜 eval이 더 빠를까?
Network latency는 없고, 데이터 양도 같습니다. Redis server는 오직 테스트를 위해서만 띄웠기 때문에 외부 쿼리 변수도 없습니다. (network latency와 외부 쿼리 변수가 끼기 시작하면 차이가 훨씬 커지겠죠?) 그런데 왜 무려 50배나 빠른 걸까요?  

이는 다음 포스트에서 살펴보겠습니다. 글이 너무 길어져서요.

[다음 포스트 보기](http://cjeon.github.io/2016/05/28/%EB%A0%88%EB%94%94%EC%8A%A4-Eval2.html)

# 5. 더 읽을 거리
[Redis](http://redis.io/)  
[Redis-rb](https://github.com/redis/redis-rb)
