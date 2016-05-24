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
    puts(redis.eval(script, KEYS))
  end
end
