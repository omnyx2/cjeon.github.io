---
layout: post
title: Array 비교 알고리즘 Time complexity 정리
---

오늘의 주제는 Array가 같은지 비교하는 알고리즘입니다. 며칠 전 불현듯 생각나 머리속으로 계속 고민하다가 정리하게 되었습니다.

# 기본 가정과 최소 시간복잡도
먼저, 전제는 다음과 같습니다.  

1. 두 Array를 직접 비교하지 않고 다름을 판별하는 것은 불가능하다 (예를 들어 두 array의 사이즈는 항상 같습니다.)  
2. 두 Array에 담긴 elements는 같은 class의 다른 elements와 같은지 비교가 가능해야한다.  
3. 이외에 두 Array의 elements에 대한 어떤 전제도 하지 않는다. (`Int`일 수도 있고, `custom object`일 수도 있고..)

1번 전제는 당연합니다. Array가 같은 elements를 포함하고 있는지 확인하려면 array에 포함된 어떤 element가 다른 element와 같은지 비교할 수 있어야 하기 때문입니다. (두 array가 참조하는 address가 같으면 이럴 필요도 없겠지만 이 경우는 포스트 주제 밖에 있죠.)  

2번 전제는 조금 특수한데, 데이터에 대한 쓸모있는 정보가 있다면 문제에 대한 답이 너무 많기 때문에 전제를 걸어서 일반적인 답을 찾고자 했습니다.

일단 기본적으로 최소 worst-case 시간 복잡도는 `O(n)`입니다. (여기서 n은 array의 size입니다.)  

두 개의 list에 각각 n개의 데이터가 있다고 할 때 2n개보다 적은 데이터를 보고 같음을 판별할 수 없기 때문입니다.  

# 사용 가능한 방법들
사용 가능한 방법을 정리하면 총 세가지가 있는 것 같습니다. 세가지는 다음과 같습니다.  

1. 이중 루프 돌리기  
2. Sort 이용하기  
3. Hash 이용하기  

각각을 정리하면 다음과 같습니다.  

|알고리즘|average-case 시간복잡도|worst-case 시간복잡도|제한|비고|  
|-|-|-|-|  
|Loop|`O(n^2)`|`O(n^2)`|||  
|Sort|`O(nlogn)`|`O(n^2)`|데이터가 Comparable 해야함|데이터와 sort 알고리즘에 따라 복잡도가 달라짐.|  
|Hash|`O(n)`|`O(n^2)`|데이터가 Hashable 해야함|데이터와 hash algorithm에 따라 복잡도가 달라짐.|  

Hashing과 sorting은 각각 데이터 타입에 특화된 hash algorithm과 sorting algorithm을 쓰면 worst-case를 `O(n)`까지 낮출 수 있습니다.   Hashing의 경우 data type에 특화되어 collision이 일어나지 않게 설계된 알고리즘을 사용하면 되고, sorting의 경우 data type에 특화된 (radix sort 같은) 알고리즘을 이용하면 되니까요.  

이제 방법을 하나 하나 소개해보겠습니다.  

# Naïve Approach: 이중 루프
아마 가장 빠르게, 또 간단히 생각하고 구현할 수 있는 건 이중루프를 사용하는 걸 겁니다. 아래처럼 하면 쉽고 간단하게, 또, 오래 걸리는 solution이 완성됩니다.  

``` ruby
def compare_by_looping(list1, list2)
  list1.each do |item|
    if list2.include? item
      list2.delete item
    else
      return false
    end
  end
  return true
end
```

list1의 모든 아이템을 list2에서 지워봅니다. 루프가 끝났다면 두 array의 사이즈는 같기 때문에 두 Array는 동일합니다. list1의 모든 아이템에 대해(`O(n)`) Array 색인(`O(n)`)을 실행하므로 총 시간 복잡도는 `O(n^2)`이 됩니다.

# Advanced Approach: Sorting
위의 approach에서 cost를 조금 줄여봅시다. 모든 아이템을 보는 건 피할 수 없고, `O(n)`의 cost가 드는 Array 색인을 줄일 수 있을 것 같습니다. 색인을 하지 않으면 어떨까요? Array를 sort해서 앞에서부터 확인하면 `O(n)`짜리 색인이 아닌, `O(1)`짜리 retrieval로 문제를 해결할 수 있습니다. 다만 element에 대한 정보 없이 사용가능한 최적의 sorting complexity는 `O(nlogn)`이기 때문에 총 `O(n)`은 불가능하고, `O(nlogn)`이 최소 worst-case compleixty가 됩니다.  

(* 이 방법을 사용하려면 데이터에 대한 추가 전제가 필요합니다. Data가 sortable, i.e., comparable 해야합니다.)

코드는 아래와 같습니다.

```ruby
def compare_by_sorting(list1, list2)
  list1.sort
  list2.sort

  list1.each_with_index do |list_1_item, index|
    return false if list_1_item != list2[index]
  end
  return true
end
```

먼저, array를 sort합니다. 이론적으로 보장된 `O(nlogn)`짜리 알고리즘을 사용하면 두 array를 색인하는 데 `O(nlogn)`이면 충분합니다. 이후, 앞에서부터 array를 읽어나가면서 하나라도 다르면 false를, 끝까지 도달했다면 true를 리턴합니다. Looping에서 색인이 index를 갖고 있으므로 `O(1)`밖에 걸리지 않아 최종 complexity는 `O(nlogn)`이 됩니다.

# More Advanced Approach: Hashing
위의 approach에서 cost를 더 줄일 수도 있습니다. Worst-case time complexity는 오히려 안좋아진다는 단점이 있지만, quicksort와 mergesort 중 더 많이 사용되는 건 quicksort니까요. 이 approach의 기본 전략은 'element가 나오는 횟수를 hash해서 두 array의 모든 element가 같은 수만큼 나오는지 확인하자'입니다. Hash를 만드는 데 드는 평균적인 cost는 `O(n)`이므로 average-case에서는 `O(n)`으로 비교를 끝낼 수 있습니다. 하지만 Collision이 많아지면 `O(n^2)`이 걸려서 이론적으로는 sorting보다 나은 방법이 아닙니다.  

(* 이 방법 역시 사용하려면 데이터에 대한 추가 전제가 필요합니다. Data가 hashable, i.e., key로 사용할 stable한 value가 element에 있어야 합니다.)

코드는 아래와 같습니다.

```ruby
def compare_by_hashing(list1, list2)
  hash1 = {}
  list1.each do |item|
    hash1[item] ||= 0
    hash1[item] += 1
  end
  hash2 = {}
  list2.each do |item|
    hash2[item] ||= 0
    hash2[item] += 1
  end

  hash1.each do |key, hash_1_value|
    return false if hash_1_value != hash2[key]
  end
  return true
end
```

Array들을 hash로 변환하고(average `O(n)`, worst `O(n^2)`), hash를 색인합니다(worst `O(n)`) average case에는 `O(n)`이, worst case에는 `O(n^2)`이 나옵니다. 하지만 잘 만들어진 hash algorithm을 이용하면 worst case보다는 average case에 기울 확률이 훨씬 높기 때문에 (hash가 많이 쓰이는 데에는 이유가 있으니까요) sorting과 hashing 중에서는 hashing이 더 나은 방법이라고 생각합니다.

# Best Approach: ?
지금까지 소개한 방법들은 제한적으로 `O(n)`이 되거나(hashing의 average case), 아니면 작은 제한으로 `O(nlogn)`이 되는(sortable한 제한으로 sorting) 방법들입니다. 제한없이, 혹은 작은 제한으로 worst-case `O(n)`을 달성한 방법은 없습니다. 꽤 오래 고민해봤는데 아직 찾지 못했습니다. 혹시 방법을 아신다면 알려주시면 감사하겠습니다.
