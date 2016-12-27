#!/usr/bin/env ruby

require './garage'

g = Garage::Client.new

def map x, in_min, in_max, out_min, out_max
  (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

class Float < Numeric
  def to_percent
    in_min, in_max, out_min, out_max = 0, 30, 0, 100
    (self.to_i - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
  end
end

while true
  t1 = 8 # out
  t2 = g.temp? # in

  puts "#{t2.to_percent}% #{t2}ºC"
  if t2 < 50
    g.speed! t2.to_percent
  end
  sleep 2
end

