require 'pi_piper'
include PiPiper
require_relative "TimelapseController.rb"
 
# quick and dirty implementation of using push buttons to preview/start a timelapse
# on the Raspberry Pi using the Pi Camera and an LCD touch pannel 
# commands are issued using the Raspberry Pi's native 'raspistill' command-line tool.

settings = {
  #if set, the timelapse will start at this given date/time
  :start_date => nil,       
  # interval between pictures (in seconds)
  :timelapse_interval => 3,
  # duration in hours 
  :duration => 10,          
  # frame storage device
  :usb_key => "Kingston DataTraveler",
  # if true a led will indicate that the timelapse is running
  :use_led => true           
}

led_pin_gpio = 22
led_pin = PiPiper::Pin.new(:pin => led_pin_gpio, :direction => :out)

timelapse = TimelapseController.new(settings, led_pin)

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
