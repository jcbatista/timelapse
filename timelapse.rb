# sudo gem install sys-filesystem
require 'sys/filesystem'
require 'thread'
require 'pi_piper'
include PiPiper

# quick and dirty implementation of using push buttons to preview a timelaps
# on the Raspberry Pi using the Pi Camera and an LCD touch pannel 
# commands are taken using the raspberry pi

$semaphore = Mutex.new
$timelapse_started = false
$wait_time = 1 # in seconds
$save_dir = "pics"
$filename_template = nil
$max_running_length = 8 # in hours 

def get_remaining_space
  stat = Sys::Filesystem.stat("/")
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
  execute("raspistill -w 1920 -h 1080 -o preview.jpg");
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

def thread_func
  begin
  start_time = Time.new
  puts "Starting timelapse: #{get_display_time(start_time)}"
    while $timelapse_started
      remaining_space = get_remaining_space
      if !can_proceed?(remaining_space)
        stop_timelaspe
        return
      end
      #puts "$filename_template=#{$filename_template}"
      files = Dir.glob("#{$filename_template}*")
      puts "image count=#{files.length} remaining space=#{remaining_space}mb"
      sleep $wait_time + 0.01
    end
  rescue
    puts "An error has occured...", $!, $@
  end
  end_time = Time.new
  puts "timelapse stopped at #{get_display_time(end_time)}."
end

def start_timelapse
  $timelapse_started = true
  puts "starting timelapse intervall=#{$wait_time} secs for a max of #{$max_running_length} hours..."    
  date = Time.now.strftime("%Y%d%m")
  random = [*0..100].sample
  $filename_template = "./#{$save_dir}/f#{random}_#{date}"         
  filename = "#{$filename_template}_%04d.jpg"
  wait_time_ms = $wait_time * 1000
  max_length = $max_running_length * 60 * 60 * 1000
  command = "raspistill -t #{max_length} -tl #{wait_time_ms} -w 1920 -h 1080 -n -o #{filename}"
  puts "Running '#{command}'..."
  fork do
    `#{command}`
  end
  timelapse_thread = Thread.new { thread_func }
end

def stop_timelapse
  puts "Stopping timelapse..."  
    $timelapse_started = false
    `sudo pkill raspistill`
end

#watch :pin => 17 do
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

puts "Timelapse thingy started ..."
PiPiper.wait
