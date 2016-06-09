---
layout: post
title: Jekyll에 lunr.js 붙이기 (+ 한국어 검색 문제 해결)
---
Jekyll에 lunr.js를 붙였습니다. [Jekyll Tips](http://jekyll.tips/jekyll-casts/jekyll-search-using-lunr-js/)의 자료를 따라서 했는데, 영어로 쿼리하면 결과가 잘 나오는 반면 한국어로 쿼리하면 결과가 하나도 나오지 않더군요.  

저는 아래와 같은 간단한 처리를 해준 결과 검색 결과가 잘 나오네요.

# 1. js charset 설정

search.html에서 js를 임포트 할 때 처음에는 아래와 같이 적혀있습니다.

``` html
<script src="/js/lunr.min.js"></script>
<script src="/js/search.js"></script>
```

이를 아래와 같이 바꿔주면 검색 결과에서 한국어가 깨지지 않습니다.

``` html
<script src="/js/lunr.min.js" charset="utf-8"></script>
<script src="/js/search.js" charset="utf-8"></script>
```

# 2. Lunr.js 검색시 stemmer 등 제거

lunr.js는 non-english word를 filter합니다. 그래서 문장부호, 한국어 등이 filter되는데요, 이를 피하기 위해서는 stemmer, stop word filter 등을 제거해줄 필요가 있습니다. (한국어용 stemmer, stop word filter를 사용하셔도 됩니다.)   

이를 위해서는 search.js 에서 아래 부분을 바꾸어 주면 됩니다. lunr(function() {})으로 initialize 하면 자동으로 stemmer 등이 들어가므로 아래 코드를

``` javascript
var idx = lunr(function () {
      this.field('id');
      this.field('title', { boost: 10 });
      this.field('author');
      this.field('category');
      this.field('content');
    });
```

아래처럼 바꿔주면 됩니다.

``` javascript
var idx = new lunr.Index;
idx.field('id');
idx.field('title', { boost: 10 });
idx.field('author');
idx.field('category');
idx.field('content');
```

이렇게 하면 검색할 때 한국어가 filter 되지 않고, 한국어가 검색 결과에 잘 반영되기도 합니다.
