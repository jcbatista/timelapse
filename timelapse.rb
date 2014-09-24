require 'thread'
require 'pi_piper'
include PiPiper

# quick and dirty implementation of using push buttons to preview a timelaps
# on the Raspberry Pi using the Pi Camera and an LCD touch pannel 

$semaphore = Mutex.new
$timelapse_started = false
$wait_time = 5
$save_dir = "pics"

def execute(command)
  puts 'taking preview pic...'
  fork do
    `sudo ./fbcp`
  end
  `#{command}`
  `sudo pkill fbcp`
  puts 'Done.'
end

#watch :pin => 4 do
after :pin => 4, :goes => :high do
  puts "Pin changed from #{last_value} to #{value}"
  execute("raspistill -w 1920 -h 1080 -o preview.jpg");
end

def thread_func
  $timelapse_started = true 
  date = Time.now.strftime("%Y%d%m")
  counter = 0
  random = [*0..100].sample
  
  while $timelapse_started
    filename = "./#{$save_dir}/f_r#{random}_#{date}_#{counter}.jpg"         
    command = "raspistill -w 1920 -h 1080 -n -o #{filename}"
    puts "#{counter}. Running '#{command}'..."
    puts `#{command}`
    counter = counter + 1
    sleep $wait_time
  end
  puts "timelapse stopped!"
end

#watch :pin => 17 do
after :pin => 17, :goes => :high do
  puts "Pin changed from #{last_value} to #{value}"
  $semaphore.synchronize {
    if $timelapse_started == false 
      $timelapse_started = true
      puts "starting timelapse intervall=#{$wait_time} secs..."    
      timelapse_thread = Thread.new { thread_func }
    else
      puts "Stopping timelapse..."  
      $timelapse_started = false
    end
  }
end

#Or
#
#after :pin => 23, :goes => :high do
#  puts "Button pressed"
#  end
#
PiPiper.wait
