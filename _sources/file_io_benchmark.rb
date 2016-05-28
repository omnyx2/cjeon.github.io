require 'benchmark'
require 'securerandom'

def bm_add(bm1, bm2)
  Benchmark::Tms.new(bm1.utime + bm2.utime,
                     bm1.stime + bm2.stime,
                     0,
                     bm1.utime + bm2.utime + bm1.stime + bm2.stime,
                     bm1.real + bm2.real,
                     bm1.label)
end
open_bm = Benchmark::Tms.new(0,0,0,0,0, :open_bm)
write_bm = Benchmark::Tms.new(0,0,0,0,0, :io_bm)
close_bm = Benchmark::Tms.new(0,0,0,0,0, :close_bm)

1_000_000.times do |idx|
  puts(index) if idx%10000 == 0
  string = SecureRandom.random_bytes(29)
  f = nil
  open_bm = bm_add open_bm, Benchmark.measure { f = File.open("test", "w") }
  write_bm = bm_add write_bm, Benchmark.measure { f.write(string) }
  close_bm = bm_add close_bm, Benchmark.measure { f.close }
end

puts(write_bm.format("%-20n %10.6u %10.6y %10.6t %10.6r\n"))
