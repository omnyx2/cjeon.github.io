require 'redis'
require 'benchmark'
redis = Redis.new(host: '127.0.0.1', db: 1)
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
