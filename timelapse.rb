require 'pi_piper'
include PiPiper

require_relative "TimelapseController.rb"

ledPinGPIO = 22
ledPin = PiPiper::Pin.new(:pin => ledPinGPIO, :direction => :out)

timelapse = TimelapseController.new(ledPin)

after :pin => 18, :goes => :high do
  timelapse.shutdown 
end

after :pin => 17, :goes => :high do
  puts "Pin changed from #{last_value} to #{value}"
  timelapse.perform
end

after :pin => 4, :goes => :high do
  puts "Pin changed from #{last_value} to #{value}"
  timelapse.preview
end

puts "Timelapse thingy started, saving files to #{$save_dir}"
timelapse.wait_for_start_date

PiPiper.wait
