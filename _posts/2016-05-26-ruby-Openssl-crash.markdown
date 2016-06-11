---
layout: post
title: 코드 세 줄로 루비 크래시시키기
tags: ruby, openssl, ruby-lang, crash, bug report, 버그리포트, 루비
---
최근 포스트에서 Ruby에서 복호화가 불가능하게 암호화하는 방법을 다뤘었는데요, 그 후속 포스트인 복호화가 가능한 암호화 방식을 정리하다가 재미있는 버그를 발견했습니다. 덕분에 처음으로 루비 인터프리터가 crash되는 걸 봤네요.  

문제의 코드는 아래와 같습니다.

```ruby
require('openssl')
p = OpenSSL::PKey::RSA.new
p.public_encrypt('hi')
```
OpenSSL::PKey::RSA는 SSL, HTTPS 등에서 아주 범용적으로 쓰이는 RSA key pair를 다루는 class입니다. (자세한 정보는 [ruby-doc](http://ruby-doc.org/stdlib-2.0.0/libdoc/openssl/rdoc/OpenSSL/PKey/RSA.html) 을 참고하세요)  

이 class는 여타 다른 class처럼 new를 통해 새로운 인스턴스를 만들 수 있는데요, 이때 첫번째 parameter는 keysize를 의미합니다.  

그런데 위처럼 keysize가 주어지지 않으면 0비트 key (즉 null)가 할당되고, 이때 0비트 key를 참조해서 암호화를 진행하면 crash가 나는 것으로 보입니다.  

문제를 발견하고 ruby-lang.org에 [보고](https://bugs.ruby-lang.org/issues/12428)했고, [r55175](https://bugs.ruby-lang.org/projects/ruby-trunk/repository/revisions/55175)에서 개선이 반영될 예정이라고 합니다.
