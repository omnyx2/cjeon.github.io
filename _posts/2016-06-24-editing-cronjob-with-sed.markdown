---
layout: post
title: Sed 활용해서 cronjob 쉽게 edit하기
---
DB서버를 대대적으로 점검할 일이 있어서, DB가 한시적으로 작동을 중지해야하는 일이 있었습니다. 점검공지를 걸고 클라이언트 접속을 막고, 혹시 있을 문제를 대비해 영향을 받는 시간대에 실행되는 cronjob들도 다 주석처리를 하기로 했죠.  

그런데 cronjob이 꽤 많습니다. 일일이 들여다보면서 주석처리를 하기에는 눈도, 머리도 아프죠. 또, 실수로 하나 빼먹었다가 다른 서버에서 문제가 생길 수도 있는 일입니다.  

다행히 프로그래밍을 할 줄 아니까, `sed`라는 명령어를 사용해보기로 합니다.  

## grep으로 패턴과 일치하는 line 추출하기  
다음은 제가 임시로 만든 cronjob들입니다.  

```
cat test_cron.txt
39 11 * * * (some job)
42 7 * * * (some job)
7 0 * * * (some job)
30 19 * * * (some job)
31 10 * * * (some job)
48 21 * * * (some job)
44 9 * * * (some job)
50 23 * * * (some job)
15 11 * * * (some job)
54 0 * * * (some job)
0 23 * * * (some job)
27 4 * * * (some job)
16 21 * * * (some job)
35 0 * * * (some job)
1 15 * * * (some job)
26 1 * * * (some job)
21 4 * * * (some job)
36 16 * * * (some job)
48 20 * * * (some job)
14 13 * * * (some job)
50 7 * * * (some job)
52 23 * * * (some job)
25 18 * * * (some job)
48 5 * * * (some job)
13 9 * * * (some job)
29 9 * * * (some job)
30 5 * * * (some job)
44 15 * * * (some job)
31 3 * * * (some job)
10 13 * * * (some job)
40 9 * * * (some job)
39 2 * * * (some job)
20 12 * * * (some job)
1 13 * * * (some job)
15 6 * * * (some job)
47 21 * * * (some job)
13 4 * * * (some job)
2 17 * * * (some job)
8 21 * * * (some job)
23 23 * * * (some job)
```

여기서 특정 시간대에만 실행되는 cronjob을 다 주석처리한다고 생각해봅시다. 예를 들어, DB 점검 작업이 02시 ~ 06시에 진행된다고 하면, 02시 00분의 cronjob부터 05시 59분의 cronjob을 주석처리해야합니다.  

그 시간대에 실행되는 cronjob은 grep으로 쉽게 찾을 수 있습니다. 다음과 같이 하면 됩니다.  

> `cat test_cron.txt | grep '^.* [2-5] .*$'`

하나 하나 설명하면 cat은 file의 content를 standard output으로 콘솔에 뿌려줍니다. test_cron.txt는 위의 (39 11 * * ...)이 저장되어있는 파일이구요.  

[anonymous 파이프](https://en.wikipedia.org/wiki/Pipeline_(Unix))(`|`)는 파이프 앞의 결과물을 파이프 뒤의 인풋으로 넘겨줍니다. 다시말해 cat 의 결과가 grep의 인풋이되죠. grep은 input에 대해 regular expression을 적용해주는 unix command로, 아주 활용도가 많은 command입니다.  

grep을 일일이 설명하기에는 포스트의 집중도가 떨어지므로 설명은 이만 줄이겠습니다.  

이후 grep은 regex를 적용합니다. `^`는 라인의 시작을, `$`는 라인의 끝을 나타냅니다. `.* `(whitespace가 있습니다)는 첫 번째 whitespace전에 오는 모든 걸 match 하라는 뜻입니다. 모든 분(0-59)를 매치하기 위해 있습니다. (cronjob 파일에 문자가 있으면 `\d+`가 더 정확할 겁니다.)  

`[2-5]`는 시간을 매치하기 위해 있습니다. 2시부터 5시까지, 그리고 앞의 분과 조합하면 2시 00분부터 5시 59분까지가 매칭됩니다. 이어지는 `.*$`(첫 글자는 whitespace입니다.)는 2시 00분부터 5시 59분 이후 어떤 문자열이 와도 모두 매치하라는 뜻입니다. 스페이스는 시각과 나머지 문자열을 구분하기 위해 꼭 필요합니다.  

결과는 다음과 같습니다.  

```  
cat test_cron.txt | grep '^.* [2-5] .*$'
27 4 * * * (some job)
21 4 * * * (some job)
48 5 * * * (some job)
30 5 * * * (some job)
31 3 * * * (some job)
39 2 * * * (some job)
13 4 * * * (some job)
```  
꽤 잘 나왔습니다. 이 정보만 가지고 수동으로 주석처리를 해도 되겠지만, 영 귀찮으니 regex로 capture한 정보를 sed를 이용해서 자동으로 주석처리해봅시다.  

## sed 소개  
[SED](https://www.gnu.org/software/sed/manual/sed.html)는 Stream Editor의 준말로, Unix utility 중 하나입니다. Text를 파싱한 뒤 바꾸는 데 흔히 사용되며, 오늘은 Text file안에서 regex에 매칭되는 라인을 바꾸는 데 사용할 겁니다.  

sed의 기초 문법은 다음과 같습니다.  

> `sed s/찾을패턴/바꿀패턴/ filename`  

이렇게 하면 `찾을패턴`이 등장하는 **처음** 부분이 `바꿀패턴`으로 바뀌어서 출력됩니다.  

보통은 g옵션을 넣어서 사용하기도 하는데, 오늘은 필요하지 않아서 사용하지 않을 예정입니다.  

g옵션을 넣으면 명령어는 다음과 같이 바뀌고,  

> `sed s/찾을패턴/바꿀패턴/g filename`  

이렇게 하면 `찾을패턴`이 등장하는 **모든** 부분이 `바꿀패턴`으로 바뀌어서 출력됩니다.  

이때 `sed`가 아니라 `sed -i`로 쓰면 바뀐 결과가 출력되지 않고 그대로 저장됩니다.  

하지만 cronjob을 잠깐 주석처리 했다가 주석을 다시 없앨 것이기 때문에 `-i` 옵션은 사용하지 않을 예정입니다.  

## sed 활용
sed는 일반 regex를 쓰는 것 처럼 쓰면 되지만, regex를 쓸 때 조금 주의해야 합니다. 일반적으로 regex에서 capture는 `()`로 하는데 이를 `\(\)`로 해야한다는 점, 또 그냥 whitespace는 인식이 안되어서 `[[:space:]]`로 표기해줘야 한다는 점이 좀 다릅니다.  
이런 규칙을 유념하고, sed 명령어를 차근차근 만들어보겠습니다. 필요한 규칙은 다음과 같습니다.  

1. 분에 상관없이 시간이 2-5면 모두 캡쳐한다.
2. 1번을 만족하는 라인의 가장 앞에 #을 추가한다.
3. 결과는 파일에 적히지 않고, 새로운 파일 test_cron_new.txt에 적힌다.  

1번을 만족하는 regex는 위에서 grep을 할 때 썼던 것을 조금만 변형하면 됩니다. Grep에서 쓴 regex는 아래와 같았습니다.  

> `'^.* [2-5] .*$'`

여기서 whitespace를 위에서 말한 것처럼 `[[:space:]]`로 변경해줘야 합니다. 그럼 결과는 아래와 같습니다.  

> `/^.*[[:space:]][2-5][[:space:]].*$/`

여기서 2번을 적용하려면 regex를 capture하고, 그 capture한 걸 사용해야 합니다. 일반적으로 capture 하는 것처럼 `()`를 써서 `\1`처럼 refer해도 되고, 혹은 더 간단하게 앞에서 match되는 전체 패턴을 매칭하고 싶다면 그냥 `&`를 쓰면 됩니다. 앞의 pattern 전체에 `()`이 있는 것처럼 작동합니다.  

저희는 주석 처리를 할 거니까, 앞에서 매칭된 라인 전체의 앞에 `#`을 추가해주면 될 것 같습니다. 그러면 다음과 같이 적으면 되겠죠.

> `/#&/`  

두 regex를 합치고 s를 붙이면 다음과 같습니다.  

> `s/^.*[[:space:]][2-5][[:space:]].*$/#&/`  

이후 파이프를 이용해 텍스트를 넣어줘도 되고, 그냥 `sed regex filename` 처럼 적어도 됩니다. grep에서 파이프를 이용했으니 이번에는 그냥 텍스트를 넣겠습니다.  

그럼 결과가 standard output으로 콘솔에 뿌려지겠죠. 역시 파이프를 이용해 test_cron_new.txt에 저장합시다. 이번에 사용할 파이프는 [named pipe](https://en.wikipedia.org/wiki/Named_pipe)(`>`)로, `command > filename`을 하면 command에서 리턴한 standard output이 그대로 filename에 저장됩니다.  

> `command > test_cron_new.txt`

의 형태로 명령어가 만들어지겠네요.  

모두를 합하면

> `sed 's/^.*[[:space:]][2-5][[:space:]].*$/#&/' test_cron.txt > test_cron_new.txt`

가 됩니다. 실행 후 test_cron_new를 열어보면 다음과 같이 원했던 처리가 잘 되어있는 것을 확인 할 수 있습니다.  

```
39 11 * * * (some job)
42 7 * * * (some job)
7 0 * * * (some job)
30 19 * * * (some job)
31 10 * * * (some job)
48 21 * * * (some job)
44 9 * * * (some job)
50 23 * * * (some job)
15 11 * * * (some job)
54 0 * * * (some job)
0 23 * * * (some job)
#27 4 * * * (some job)
16 21 * * * (some job)
35 0 * * * (some job)
1 15 * * * (some job)
26 1 * * * (some job)
#21 4 * * * (some job)
36 16 * * * (some job)
48 20 * * * (some job)
14 13 * * * (some job)
50 7 * * * (some job)
52 23 * * * (some job)
25 18 * * * (some job)
#48 5 * * * (some job)
13 9 * * * (some job)
29 9 * * * (some job)
#30 5 * * * (some job)
44 15 * * * (some job)
#31 3 * * * (some job)
10 13 * * * (some job)
40 9 * * * (some job)
#39 2 * * * (some job)
20 12 * * * (some job)
1 13 * * * (some job)
15 6 * * * (some job)
47 21 * * * (some job)
#13 4 * * * (some job)
2 17 * * * (some job)
8 21 * * * (some job)
23 23 * * * (some job)
```

## 더 읽을거리
1. [Bruce Barnett의 sed manual](http://www.grymoire.com/Unix/Sed.html#uh-3)  
2. [GNU.org의 sed manual](https://www.gnu.org/software/sed/manual/sed.html)  
3. [위키피디아 파이프라인](https://en.wikipedia.org/wiki/Pipeline_(Unix))  
4. [위키피디아 named pipeline](https://en.wikipedia.org/wiki/Named_pipe)  
