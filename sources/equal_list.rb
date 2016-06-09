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

def compare_by_sorting(list1, list2)
  list1.sort
  list2.sort

  list1.each_with_index do |list_1_item, index|
    return false if list_1_item != list2[index]
  end
  return true
end

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
