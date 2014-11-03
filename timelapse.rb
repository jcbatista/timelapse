# sudo gem install sys-filesystem
require 'sys/filesystem'
require 'thread'
require 'pi_piper'
require 'chronic'
include PiPiper

# quick and dirty implementation of using push buttons to preview/start a timelapse
# on the Raspberry Pi using the Pi Camera and an LCD touch pannel 
# commands are issued using the Raspberry Pi's native 'raspistill' command-line tool.
#
# start date as an UTC + 4 for eastern time
$start_date = nil; #'in one minute' #'tomorrow 7:00am' # if set, the timelapse will start at this given date/time
$timelapse_interval = 2 # interval between pictures (in seconds) 
$max_running_length = 10 #0.016 # in hours 
$useLed = true
$semaphore = Mutex.new
$timelapse_started = false
$save_drive = `lsusb`.include?("Kingston DataTraveler") ?  "/mnt/usb/" : "./"
$save_dir = "#{$save_drive}pics"
$filename_template = nil
$ledPin = nil

def init
  ledPinGPIO = 22
  $ledPin = PiPiper::Pin.new(:pin => ledPinGPIO, :direction => :out)
end

def useLed?
  return $useLed
end

def wait_for_start_date
  return if $start_date.to_s == '' 

  target_time  = Chronic.parse($start_date)
  current_time = Time.now
  time_diff = (target_time - current_time).to_i

  if time_diff > 0
    wait_thread = Thread.new { 
      puts "Starting timelapse at #{target_time}, waiting #{humanize time_diff} ..."
      sleep time_diff
      start_timelapse
    }
  else 
    puts "Invalid Date/Time..."
  end
end

def get_remaining_space
  stat = Sys::Filesystem.stat("#{$save_drive}")
  mb_available = stat.block_size * stat.blocks_available / 1024 / 1024
  return mb_available
end

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
  execute("raspistill -q 100 -w 1920 -h 1080 -o preview.jpg");
end

def can_proceed?(remaining_space)
  success = true
  if remaining_space < 10
    puts "running out of disk space..."
    success = false
  end 
  return success
end

def get_display_time(time)
  return time.localtime
end

def wait
  wait_time = $timelapse_interval / 2 + 0.01 
  $ledPin.on if useLed?
  sleep wait_time
  $ledPin.off if useLed?
  sleep wait_time
end

def thread_func
  begin
  start_time = Time.new
  puts "Starting timelapse: #{get_display_time(start_time)}"
    while $timelapse_started
      remaining_space = get_remaining_space
      if !can_proceed?(remaining_space)
        stop_timelapse
        return
      end

      files = Dir.glob("#{$filename_template}*")
      puts "image count=#{files.length} remaining space=#{remaining_space}mb"
      wait 
      # make sure the raspistill process is still running
      if `pgrep raspistill`.to_s == '' 
        $timelapse_started = false
      end
    end
  rescue
    puts "An error has occured...", $!, $@
  end
  end_time = Time.new
  puts "timelapse stopped at #{get_display_time(end_time)}."
end

def start_timelapse
  $timelapse_started = true
  puts "starting timelapse intervall=#{$timelapse_interval} secs for a max of #{$max_running_length} hours..."    
  date = Time.now.strftime("%Y%d%m")
  random = [*0..100].sample
  $filename_template = "#{$save_dir}/f#{random}_#{date}"         
  filename = "#{$filename_template}_%04d.jpg"
  wait_time_ms = $timelapse_interval * 1000
  max_length = $max_running_length * 60 * 60 * 1000
  command = "raspistill -q 100 -t #{max_length.floor} -tl #{wait_time_ms} -w 1920 -h 1080 -n -o #{filename}"
  puts "Running '#{command}'..."
  fork do
    puts `#{command}`
  end
  timelapse_thread = Thread.new { thread_func }
end

def stop_timelapse
  puts "Stopping timelapse..."  
    $timelapse_started = false
    `sudo pkill raspistill`
end

def humanize secs
  [[60, :seconds], [60, :minutes], [24, :hours], [1000, :days]].map{ |count, name|
    if secs > 0
      secs, n = secs.divmod(count)
      "#{n.to_i} #{name}"
    end
  }.compact.reverse.join(' ')

end

# properly shutdown the Pi
def shutdown
  stop_timelapse
  exec("sudo halt -p")
end

init

after :pin => 18, :goes => :high do
  $semaphore.synchronize {
    shutdown 
  }
end

after :pin => 17, :goes => :high do
  puts "Pin changed from #{last_value} to #{value}"
  $semaphore.synchronize {
    if $timelapse_started == false 
      return if !can_proceed?(get_remaining_space)
      start_timelapse
    else
      stop_timelapse
    end
  }
end

puts "Timelapse thingy started, saving files to #{$save_dir}"
wait_for_start_date
PiPiper.wait
