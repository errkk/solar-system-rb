#!/usr/bin/env ruby

require 'thor'
require './garage'


class Tool < Thor
  def initialize *args
    super *args
    @g = Garage::Client.new
    puts "🌡  #{@g.temp?}ºC"
  end

  desc "on", "Start pump"
  option :speed, type: :numeric

  def on
    puts "Turning on"
    @g.on!

    speed = options[:speed]

    if speed
      puts "speed @ #{speed}"
      @g.speed! speed
    end
  end

  desc "off", "Stop pump"

  def off
    puts "Off"
    @g.off!
  end

  desc "speed", "Set speed"
  option :speed, type: :numeric

  def speed
    speed = options[:speed]

    if speed
      puts "Speed @ #{speed}"
      @g.speed! speed
    else
      puts "Speed = #{@g.speed?}"
    end
  end
end

Tool.start(ARGV)
