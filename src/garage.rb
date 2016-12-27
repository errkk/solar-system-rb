#!/usr/bin/env ruby
#
require 'rmodbus'

module Garage

  STATUS_LABELS = [
    ['Drive not ready', 'Ready for operation (READY)'],
    ['Stop', 'Running operation message (RUN)'],
    ['Clockwise rotating field (FWD)', 'Anticlockwise rotating field (REV)'],
    ['No fault', 'Fault detected (FAULT)'],
    ['No warning', 'Warning active (ALARM)'],
    ['Acceleration ramp', 'Frequency actual value equals setpoint value definition'],
    [nil, 'Zero speed'],
    ['Speed control deactivated', 'Speed control activated'],
  ]

  CONTROL_STATES = [
    [:stop, :operation],
    [:clockwise, :anticlockwise],
    [nil, :reset_error],
    [:per_setting, :free_coasting],
    [:per_setting, :ramp],
    [nil, 'Overwrite acceleration/deceleration ramps to 0.1 s'],
    [nil, 'Block setpoint (speed not variable)'],
    [nil, 'Overwrite setpoint with 0'],
    [nil, 'Control level = Fieldbus'],
    [nil, 'Setpoint input = Fieldbus'],
  ]

  CONTROL_WORD = 2000
  STATUS_WORD = 2100
  MOTOR_STATUS_REGISTERS = 2102..2110
  SPEED_REGISTER = 2002

  BIT_NUMBER_POWER = 0
  BIT_NUMBER_DIRECTION = 1

  class Client < ModBus::TCPClient
    def initialize
      super '192.168.0.7', 502
    end

    def temp?
      with_thermometer do |slave|
        slave.input_registers[1].first / 10.0
      end
    end

    def status?
      with_inverter do |slave|
        status_word = slave.holding_registers[STATUS_WORD].first
        status_bits = status_word.to_s(2).split('').map(&:to_i)
        status_bits.each_with_index.map {|val, idx| STATUS_LABELS[idx][val]}
      end
    end

    def motor?
      with_inverter do |slave|
        keys = [:actual_speed, :frequency, :speed, :current, :torque, :power, :voltage, :dc_link]
        speed = slave.holding_registers[MOTOR_STATUS_REGISTERS]
        Hash[keys.zip speed]
      end
    end

    def on!
      set! 1, BIT_NUMBER_POWER
    end

    def off!
      set! 0, BIT_NUMBER_POWER
    end

    def fwd
      set! 0, BIT_NUMBER_DIRECTION
    end

    def rev
      set! 1, BIT_NUMBER_DIRECTION
    end

    def speed!(percent)
      value = percent * 100

      with_inverter do |slave|
        slave.holding_registers[SPEED_REGISTER] = value
      end
    end

    def speed?
      with_inverter do |slave|
        slave.holding_registers[SPEED_REGISTER]
      end
    end

    private

    def with_inverter
      with_slave 3 do |slave|
        yield slave
      end
    rescue ModBus::Errors::ModBusTimeout
      puts "Soz, Contacting inverter timeed out"
    end

    def with_thermometer
      with_slave 49 do |slave|
        yield slave
      end
    rescue ModBus::Errors::ModBusTimeout
      puts "Soz, Contacting thermometer timeed out"
    end

    def wordsmash
      # Connect to slave, get status word, yield it to the block
      # and then take back the return value and set it to the register

      with_inverter do |slave|
        # Get current word by reading register
        word = slave.holding_registers[CONTROL_WORD].first

        puts word.to_s 2
        # Do the block
        # Set the result to the register
        slave.holding_registers[CONTROL_WORD] = yield word
      end
    end

    def toggle!(bit_number)
      # Shift a 1 across to the bit we want to operate on
      mask = 1 << bit_number

      wordsmash do |word|
        # Exclusive or, so swap only the bit forwhich this mask lines up
        # Manipulates only the bit that we're doing stuff for
        word ^= mask
      end
    end

    def set!(value, bit_number)
      # Set a single bit of the control word to on or off
      # Shift a 1 across to the bit we want to operate on
      mask = 1 << bit_number
      puts "Setting bit: #{CONTROL_STATES[bit_number][value]}"

      wordsmash do |word|
        # Manipulates only the bit that we're doing stuff for
        if value > 0
          # And or for on
          word |= mask
        else
          # And not for off
          word = word &~ mask
        end
      end
    end
  end
end
