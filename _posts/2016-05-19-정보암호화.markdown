---
layout: post
title: Ruby 에서 복호화 불가능하게 암호화하기
tags: ruby, 암호화, data encryption
---

개발을 하다보면 민감한 정보를 암호화해서 저장해야할 때가 있습니다. 대표적으로 비밀번호, 전화번호 등을 들 수 있습니다. 이런 민감한 정보는 보통 두 종류로 나뉩니다. **복호화 할 필요가 있는** 정보와 **복호화가 되면 안되는** 정보입니다. 전자의 예는 전화번호를 들 수 있고 (유저에게 전화를 할 수도 있으니까요) 후자의 예로는 비밀번호를 들 수 있습니다. 오늘 글에서는 후자를 중점적으로 다뤄보겠습니다. <br>

### 0. 반드시 명심해야 할 점<br>
글을 시작하기 전에, 한 가지를 분명히 하고 싶습니다. **절대 직접 만든 해싱 알고리즘을 사용하지 마세요.** 물론 이 글을 읽고계시는 분이 암호학의 최전선에서 학계를 이끌어나가고 있는 분이라면 말이 다르겠지만, 가능하면 이미 만들어진 알고리즘을 사용하는 걸 권장합니다. 제 글에서도 이미 만들어진 알고리즘을 사용해 데이터를 암호화하는 방법을 소개합니다.<br>

> If you are thinking of writing your own password hashing code, **please don't!**. It's too easy to screw up. No, that cryptography course you took in university doesn't make you exempt from this warning. This applies to everyone: **DO NOT WRITE YOUR OWN CRYPTO! The problem of storing passwords has already been solved.**  
> -crackstation.net

### 1. 개론<br>
잘 만들어진 라이브러리를 사용하면 복호화 불가능하게 암호화하는 것은 꽤나 간단합니다. 아래의 4단계를 따르시면 됩니다.<br>
1. 데이터를 준비한다.   
2. salt를 만든다.  
3. 데이터+salt를 암호화한다.  
4. 3단계의 결과와 salt를 둘 다 저장한다.  

### 2. 실행<br>

#### 1. 데이터 준비<br>
테스트용으로 "아주 중요한 비밀번호!!"를 암호화해보겠습니다. 

``` ruby
password = "아주 중요한 비밀번호!!"
=> "아주 중요한 비밀번호!!"
```

#### 2. salt 생성<br>
Salt는 데이터를 암호화하기 전에 데이터에 추가해주는 **임의의 값**(항상 새로 만들어져야하며, 재사용되어선 안됩니다)입니다. 그냥 암호화하면 될 것 같은데 왜 굳이 salt를 추가해야할까요? 바로 Salt가 데이터를 공격하는 많은 방법을 효과적으로 방어해주기 때문입니다. 데이터를 공격하는 방법은 [이 글](https://crackstation.net/hashing-security.htm)에 잘 정리되어 있습니다. <br>
그럼 salt는 어떻게 만들까요? salt를 만들 때는 두 가지 원칙만 지키면 됩니다.<br><br>
1. Cryptographically Secure Pseudo-Random Number Generator (CSPRNG)을 이용해서 salt를 생성한다.  
2. 한 번 암호화할 때마다 salt를 새로 생성한다. **Salt를 재사용하지 않는다**.  <br><br>
부가적으로 짧은 salt를 이용하지 않는다(해쉬 결과와 같은 길이의 salt를 사용하는 게 권장됩니다.) 등이 있습니다.<br>
루비에서는 CSPRNG로 [SecureRandom](http://ruby-doc.org/stdlib-2.2.2/libdoc/securerandom/rdoc/SecureRandom.html)를 제공합니다. 이 라이브러리를 이용해 다음과 같이 쉽게 salt를 생성할 수 있습니다.  

``` ruby
require 'securerandom'
salt = SecureRandom.base64(10)
=> "kTHYJKcyuC/OnQ=="
```
예제에서 사용된 `base64(n=nil)` 함수는 임의의 base64 string을 리턴합니다. n은 리턴되는 string의 크기(in bytes)를 나타내며, 설정되지 않으면 자동으로 16 byte의 string을 리턴합니다.<br>
이때 이 random string은 어떠한 meaningful information도 갖고 있지 않고, 완전히 random합니다. 또, 매번 생성할 때마다 값이 달라집니다.  

``` ruby
require 'securerandom'
SecureRandom.base64(10)
=> "MLg1GGh9FZKJMA=="
SecureRandom.base64(10)
=> "D0XQUBZ3D2zv5Q=="
```
매번 실행할 때마다 값이 달라지기 때문에, 한번 만든 salt를 잃어버리지 않도록 각별히 주의해야 합니다.<br>

#### 4. 데이터+salt 암호화<br>
이제 데이터와 salt를 합친 후, 이 데이터를 암호화합니다. 먼저 데이터와 salt를 합칩시다.  

``` ruby
password << salt
=> "아주 중요한 비밀번호!!kTHYJKcyuC/OnQ=="
```
이제 암호화 알고리즘을 선택해야하는데요, 루비에서 기본적으로 제공하는 SHA2-512를 사용해보겠습니다. (SHA3는 별도 gem을 통해 이용하실 수 있습니다.)  

``` ruby
password = Digest::SHA512.hexdigest password
=> "a12e519f7b3cc3fac2ee98452c5a2df77aa48b55439c7587661d9e603c47505962df8b3b166fbd7c1e51799d67cf4cfb3e24c5117b60689253855ec525c0c203"
```
이제 이 과정을 **많이** 반복한 뒤 데이터를 저장하면 끝납니다. 얼마나 반복해야 할까요?  

> All hash functions are unsafe if you use only one iteration. The hash function, whether it is SHA-1, or one of the SHA-2 family, should be repeated thousands of times. I would consider 10,000 iterations the minimum, and 100,000 iterations is not unreasonable, given the low cost of powerful hardware.  
> -[source](http://security.stackexchange.com/questions/4687/are-salted-sha-256-512-hashes-still-safe-if-the-hashes-and-their-salts-are-expos)  

5만번 반복해도 시간이 별로 오래 걸리지 않습니다. (0.1초 내외입니다.)  

``` ruby
50000.times do 
  password = Digest::SHA512.hexdigest password
end
=>50000
password
=> "7f5a8d20a27f220e0b2fd3c194a7ab019ba3ef745884c8bdd33a4a83c325d29903e6351628e3d35558ebf71bc6387a3c73393972356883efa2b2653b2ea6b88a"
```
이제 password가 random salt와 SHA2-512 알고리즘을 이용해 암호화되었습니다. 이제 저장만 마치면 끝입니다.  

#### 5. 저장하기
저장은 한 가지만 명심하시면 됩니다. **salt도 저장하셔야 합니다.** 이후에 데이터를 비교할 때 위에서 사용한 방법과 정확히 같은 방법을 사용해야 똑같은 결과가 나오는데, salt는 random하게 만들어졌기 때문에 복구가 불가능하기 때문입니다. salt와 password 값을 안전하게 저장합시다.  

#### 6. 비교하기
이후에 암호화한 값을 사용해야할 때는 어떻게 해야 할까요? 위의 단계를 조금 간소화해서 비슷하게 따라가시면 됩니다. 예를 들어 유저가 로그인을 하려하고, 비밀번호가 DB에 저장된 비밀번호와 일치하는지 비교해야한다고 생각해봅시다.<br>   

1. 유저가 비밀번호를 입력함  
2. 비밀번호와 기존에 DB에 존재하는 salt를 합침.  
3. 기존에 사용한 알고리즘, 반복횟수를 이용해 암호화.  
4. DB에 존재하는 복호화 불가능한 string과 3의 결과가 일치하는지 확인.  

``` ruby
user_input = "아주 중요한 비밀번호!!" # 유저가 입력한 비밀번호
=> "아주 중요한 비밀번호!!"
hash_from_db = "kTHYJKcyuC/OnQ==" # DB에서 가져온 hash값.
=> "kTHYJKcyuC/OnQ=="
user_input << hash_from_db # 유저가 입력한 값과 hash를 합침.
=> "아주 중요한 비밀번호!!kTHYJKcyuC/OnQ=="
50001.times do # 처음에 1 + 50000번 반복했으므로 50001 번 iterate.
  user_input = Digest::SHA512.hexdigest user_input
end
=>50001
user_input
=> "7f5a8d20a27f220e0b2fd3c194a7ab019ba3ef745884c8bdd33a4a83c325d29903e6351628e3d35558ebf71bc6387a3c73393972356883efa2b2653b2ea6b88a"
user_input == password # password는 위에서 만든 값이고, DB에서 가져온 값이기도 합니다.
=> true
```
이렇게하면 모든 과정이 끝납니다. 수고하셨습니다.  

#### 7. 더 읽을 거리

[FIPS PUBLICATIONS](http://csrc.nist.gov/publications/PubsFIPS.html)<br>
[Ruby Digest Document](http://ruby-doc.org/stdlib-2.1.0/libdoc/digest/rdoc/Digest.html)
