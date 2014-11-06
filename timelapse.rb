require 'pi_piper'
include PiPiper
require_relative "TimelapseController.rb"

settings = {
  #if set, the timelapse will start at this given date/time
  :start_date => nil,       
  # interval between pictures (in seconds)
  :timelapse_interval => 3,
  # duration in hours 
  :duration => 10,          
  # if true a led will indicate that the timelapse is running
  :use_led => true           
}

ledPinGPIO = 22
ledPin = PiPiper::Pin.new(:pin => ledPinGPIO, :direction => :out)

timelapse = TimelapseController.new(settings, ledPin)

after :pin => 4, :goes => :high do
  puts "Pin changed from #{last_value} to #{value}"
  timelapse.preview
end

after :pin => 17, :goes => :high do
  puts "Pin changed from #{last_value} to #{value}"
  timelapse.perform
end

after :pin => 18, :goes => :high do
  timelapse.shutdown 
end

puts "Timelapse thingy started, saving files to #{timelapse.save_dir}"
timelapse.wait_for_start_date

PiPiper.wait
