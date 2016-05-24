require 'benchmark'
require 'redis'

redis = Redis.new(db: 1)
KEYS = 100_000.times.collect { |i| "KEY#{i}" }
#KEYS.each { |key| redis.zadd(key, 0, 'DATA') }

script = "
local sum = 0
for index, key in pairs(KEYS) do
  sum = sum + redis.call('zcard', key);
end
return sum"


# # ZCARD 100_000 times
# zcard = Benchmark.measure("zcard") do
#   sum = 0
#   KEYS.each do |key|
#     sum += redis.zcard(key)
#   end
# end
#
# zcard_build_command = Benchmark::Tms.new
# zcard_socket_write = Benchmark::Tms.new
# zcard_socket_read = Benchmark::Tms.new
# client = redis.client
# client.send(:ensure_connected) do
#   connection = client.connection
#   socket = connection.instance_variable_get(:@sock)
#   KEYS.map do |key|
#     command = connection.build_command([:zcard, key])
#     zcard_build_command += Benchmark.measure('zcard_build_command') do command = connection.build_command([:zcard, key]) end
#     # Redis::Connection::Ruby
#     socket.write(command)
#     zcard_socket_write += Benchmark.measure('zcard_socket write') do socket.write(command) end # write to socket, 20% of execution time
#     line = socket.gets
#     zcard_socket_read += Benchmark.measure('zcard_socket read') do line = socket.gets end # read from socket, 80% of execution time
#     reply_type = line.slice!(0, 1)
#     connection.format_reply(reply_type, line)
#   end.inject(:+)
# end.tap { |res| puts "zcard result is #{res}"}

# EVAL 1 times
use_eval = Benchmark.measure("eval") { puts "eval result is #{redis.eval(script, KEYS)}" }
eval_build_command = Benchmark::Tms.new
eval_socket_write = Benchmark::Tms.new
eval_socket_read = Benchmark::Tms.new
puts("redis client", Benchmark.measure("redis client") {client = redis.client})
client = redis.client
client.send(:ensure_connected) do
  puts "eval-connection", Benchmark.measure("eval-connection") { connection = client.connection }
  connection = client.connection
  puts "get socket", Benchmark.measure("get socket") { socket = connection.instance_variable_get(:@sock) }
  socket = connection.instance_variable_get(:@sock)
  eval_build_command += Benchmark.measure('eval_build_command') do command = connection.build_command([:eval, script, KEYS]) end
  command = connection.build_command([:eval, script, KEYS])
  eval_socket_write += Benchmark.measure('eval_socket write') do socket.write(command) end
  socket.write(command)
  eval_socket_read += Benchmark.measure('eval_socket read') do line = socket.gets end
  line = socket.gets
  reply_type = line.slice!(0, 1)
  connection.format_reply(reply_type, line)
  puts(connection.format_reply(reply_type, line).class)
end

#puts('%-20s' % "zcard" + zcard.to_s,'%-20s' % "zcard_build_command" + zcard_build_command.to_s,
#'%-20s' %"zcard_socket_write" + zcard_socket_write.to_s,'%-20s' % "zcard_socket_read" + zcard_socket_read.to_s)
puts('%-20s' %"use_eval"+use_eval.to_s,'%-20s' % "eval_build_command"+eval_build_command.to_s,
'%-20s' %"eval_socket_write" + eval_socket_write.to_s, '%-20s' %"eval_socket_read" + eval_socket_read.to_s)
