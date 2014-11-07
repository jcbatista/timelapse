# sudo gem install sys-filesystem
require 'sys/filesystem'
require 'thread'
require 'chronic'

class TimelapseController

public
  
  attr_accessor :save_dir

  def initialize( settings, ledPin )
    @semaphore = Mutex.new
    @timelapse_started = false
    @save_drive = `lsusb`.include?(settings[:usb_key]) ?  "/mnt/usb/" : "./"
    @save_dir = "#{@save_drive}pics"
    @filename_template = nil
    @settings = settings
    @ledPin = ledPin 
  end

  # start / stop the timelapse
  def perform
      @semaphore.synchronize {
        if @timelapse_started == false 
          return if !can_proceed?(get_remaining_space)
          start_timelapse
        else
          stop_timelapse
        end
      }
  end

  def preview
    execute("raspistill -q 100 -w 1920 -h 1080 -o preview.jpg");
  end

  # properly shutdown the Pi
  def shutdown
    @semaphore.synchronize {
      stop_timelapse
      exec("sudo halt -p")
    }
  end

  def wait_for_start_date
    return if @settings[:start_date].to_s == '' 

    target_time  = Chronic.parse(@settings[:start_date])
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

private

  def use_led?
    return @settings[:use_led]
  end

  def get_remaining_space
    stat = Sys::Filesystem.stat("#{@save_drive}")
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
    wait_time = @settings[:timelapse_interval] / 2 + 0.01 
    @ledPin.on if use_led?
    sleep wait_time
    @ledPin.off if use_led?
    sleep wait_time
  end

  def thread_func
    begin
    start_time = Time.new
    puts "Starting timelapse: #{get_display_time(start_time)}"
      while @timelapse_started
        remaining_space = get_remaining_space
        if !can_proceed?(remaining_space)
          stop_timelapse
          return
        end

        files = Dir.glob("#{@filename_template}*")
        puts "image count=#{files.length} remaining space=#{remaining_space}mb"
        wait 
        # make sure the raspistill process is still running
        if `pgrep raspistill`.to_s == '' 
          @timelapse_started = false
        end
      end
    rescue
      puts "An error has occured...", $!, $@
    end
    end_time = Time.new
    puts "timelapse stopped at #{get_display_time(end_time)}."
  end

  def start_timelapse
    @timelapse_started = true
    puts "starting timelapse intervall=#{@settings[:timelapse_interval]} secs for a max of #{@settings[:duration]} hours..."    
    date = Time.now.strftime("%Y%d%m")
    random = [*0..100].sample
    @filename_template = "#{@save_dir}/f#{random}_#{date}"         
    filename = "#{@filename_template}_%04d.jpg"
    wait_time_ms = @settings[:timelapse_interval] * 1000
    max_length = @settings[:duration] * 60 * 60 * 1000
    command = "raspistill -q 100 -t #{max_length.floor} -tl #{wait_time_ms} -w 1920 -h 1080 -n -o #{filename}"
    puts "Running '#{command}'..."
    fork do
      puts `#{command}`
    end
    timelapse_thread = Thread.new { thread_func }
  end

  def stop_timelapse
    puts "Stopping timelapse..."  
      @timelapse_started = false
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

end # end TimelapseController
