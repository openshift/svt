require 'TaskControl'
require 'Config'

module OpenshiftReliability
  class  EventControl
   
    # By default 1 hour =60 minute, 1 day=24 hours ....
    def initialize(taskobj)
      @taskobj=taskobj
      @minute=1
      @hour=60
      @day=1440
      @week=10080
      @month=43299
      load_config()
    end
  
    def load_config()
       if $config.schedule
         @minute=$config.schedule["minute"].to_i if $config.schedule["minute"]
         @day=$config.schedule["day"].to_i if $config.schedule["day"]
         @hour=$config.schedule["hour"].to_i if $config.schedule["hour"]
         @week=$config.schedule["week"].to_i if $config.schedule["week"]
         @month=$config.schedule["month"].to_i if $config.schedule["month"]
       end 
    end
  
    def schedule_event()
      elapse_count = 1 
      play_task ("pre")
      while true
        if (elapse_count % @month == 0 )
          play_task ("month")
        end
        if (elapse_count % @week == 0 )
          play_task("week")
        end
        if (elapse_count % @day == 0 )
          play_task("day")
        end
        if (elapse_count % @hour == 0 )
          play_task("hour")
        end
        if (elapse_count % @minute == 0 )
          play_task("minute")
        end
        elapse_count = elapse_count +1
        sleep 60
      end 
    end
  
    def play_task(tag)
      $config.increment_tasknum()
      $config.save()
      tasklist=$config.tasks + tag
      $logger.info(" start task #{tasklist} #{$config.tasknum}")
      @taskobj.execute_task(tasklist)
      $logger.info(" end task #{tasklist} #{$config.tasknum}")
    end
  end
end
