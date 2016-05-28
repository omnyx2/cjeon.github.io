require 'benchmark'
require 'redis'

bm = Benchmark
redis = Redis.new(db: 1)
KEYS = 1_000_000.times.collect { |i| "KEY#{i}" }
KEYS.each { |key| redis.zadd(key, 0, 'DATA') }

script = "
local sum = 0
for index, key in pairs(KEYS) do
  sum = sum + redis.call('zcard', key);
end
return sum"

def bm_add(bm1, bm2)
  Benchmark::Tms.new(bm1.utime + bm2.utime,
                     bm1.stime + bm2.stime,
                     0,
                     bm1.utime + bm2.utime + bm1.stime + bm2.stime,
                     bm1.real + bm2.real,
                     bm1.label)
end
#       #
# ZCARD #
#       #

result = 0
zcard_client = Benchmark::Tms.new(0,0,0,0,0,:zcard_client)
zcard_connection = Benchmark::Tms.new(0,0,0,0,0,:zcard_connection)
zcard_get_socket = Benchmark::Tms.new(0,0,0,0,0,:zcard_get_socket)
zcard_build_command = Benchmark::Tms.new(0,0,0,0,0,:zcard_build_command)
zcard_socket_write = Benchmark::Tms.new(0,0,0,0,0,:zcard_socket_write)
zcard_socket_get = Benchmark::Tms.new(0,0,0,0,0,:zcard_socket_get)
zcard_reply_type = Benchmark::Tms.new(0,0,0,0,0,:zcard_reply_type)
zcard_format_reply = Benchmark::Tms.new(0,0,0,0,0,:zcard_format_reply)

zcard_client = bm_add(zcard_client, bm.measure(:client) {client = redis.client})
client = redis.client
written_commands = ""
read_lines = ""
client.send(:ensure_connected) do
  KEYS.each do |key|
    connection = nil
    zcard_connection = bm_add(zcard_connection, bm.measure(:connection) {connection = client.connection})

    socket = nil
    zcard_get_socket = bm_add zcard_get_socket, bm.measure {socket = connection.instance_variable_get(:@sock)}

    built_command = nil
    zcard_build_command = bm_add zcard_build_command, bm.measure { built_command = connection.build_command([:zcard, key]) }
    written_commands << built_command

    zcard_socket_write = bm_add zcard_socket_write, bm.measure{socket.write(built_command)}

    line = nil
    zcard_socket_get = bm_add zcard_socket_get, bm.measure{line = socket.gets}
    read_lines << line

    reply_type = nil
    zcard_reply_type = bm_add zcard_reply_type, bm.measure{reply_type = line.slice!(0, 1)}

    reply = nil
    zcard_format_reply = bm_add zcard_format_reply, bm.measure{reply = connection.format_reply(reply_type, line)}
    result += reply
  end
end

puts("----ZCARD----")
[zcard_client,zcard_connection,zcard_get_socket,
  zcard_build_command,zcard_socket_write,zcard_socket_get,
  zcard_reply_type,zcard_format_reply].each do |bm|
    puts(bm.format("%-20n %10.6u %10.6y %10.6t %10.6r\n"))
  end
puts("result is #{result}")
puts("written commands in bytes : #{written_commands.bytesize}")
puts("read lines in bytes       : #{read_lines.bytesize}")

#      #
# EVAL #
#      #

result = 0
eval_client = Benchmark::Tms.new(0,0,0,0,0,:eval_client)
eval_connection = Benchmark::Tms.new(0,0,0,0,0,:eval_connection)
eval_get_socket = Benchmark::Tms.new(0,0,0,0,0,:eval_get_socket)
eval_build_command = Benchmark::Tms.new(0,0,0,0,0,:eval_build_command)
eval_socket_write = Benchmark::Tms.new(0,0,0,0,0,:eval_socket_write)
eval_socket_get = Benchmark::Tms.new(0,0,0,0,0,:eval_socket_get)
eval_reply_type = Benchmark::Tms.new(0,0,0,0,0,:eval_reply_type)
eval_format_reply = Benchmark::Tms.new(0,0,0,0,0,:eval_format_reply)
written_commands = ""
read_lines = ""

eval_client = bm_add(eval_client, bm.measure(:client) {client = redis.client})
client = redis.client
client.send(:ensure_connected) do
  connection = nil
  eval_connection = bm_add(eval_connection, bm.measure(:connection) {connection = client.connection})

  socket = nil
  eval_get_socket = bm_add eval_get_socket, bm.measure {socket = connection.instance_variable_get(:@sock)}


  built_command = nil
  eval_build_command = bm_add eval_build_command, bm.measure { built_command = connection.build_command([:eval, script, KEYS.length].concat KEYS) }
  written_commands << built_command

  eval_socket_write = bm_add eval_socket_write, bm.measure{socket.write(built_command)}

  line = nil
  eval_socket_get = bm_add eval_socket_get, bm.measure{line = socket.gets}
  read_lines << line

  reply_type = nil
  eval_reply_type = bm_add eval_reply_type, bm.measure{reply_type = line.slice!(0, 1)}

  reply = nil
  eval_format_reply = bm_add eval_format_reply, bm.measure{reply = connection.format_reply(reply_type, line)}
  result += reply
end

puts("----EVAL----")
[eval_client,eval_connection,eval_get_socket,
  eval_build_command,eval_socket_write,eval_socket_get,
  eval_reply_type,eval_format_reply].each do |bm|
    puts(bm.format("%-20n %10.6u %10.6y %10.6t %10.6r\n"))
  end
puts("result is #{result}")
puts("written commands in bytes : #{written_commands.bytesize}")
puts("read lines in bytes       : #{read_lines.bytesize}")
