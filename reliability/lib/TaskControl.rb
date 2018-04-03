require 'json'
require 'ProjectsManager'
require 'UsersManager'
require 'EnvironmentManager'

module OpenshiftReliability

  class  TaskControl
    include OpenshiftReliability::EnvironmentManager
  
    def initialize()
      @admin=ClusterUser.new()
      @users=UsersManager.new()
      @projects=ProjectsManager.new(@users)
      @instructions=[]
    end

    def execute_task(tasklist)
      get_instructions(tasklist)
      @users.login("all")
      @instructions.each do |instruction|
        $logger.info(" Start instruction #{instruction} in #{tasklist}")
        run_instruction(instruction)
        $logger.info(" End instruction #{instruction} in #{tasklist}")
      end
    end

    def get_instructions(taskfile)
      @instructions.clear
      File.read(taskfile).split(/\n/).each do |instruction|
        if (/^[^#|;].*/ =~ instruction )
          @instructions << instruction.chomp()
        end
      end
    end
  
    def run_instruction(instruction)
      ds=/.+ "(.*)" .*/.match(instruction)
      if ds
        numstr=ds[1]
      else
        numstr="0"
      end

      case  instruction 
        when /create.*user.*/   then @users.create(numstr) 
        when /login.*users.*/   then @users.login(numstr) 
        when /create.*project.*/   then @projects.create(numstr)
        when /create.*app.*/   then  @projects.create(numstr)
        when /create.*ds.*/    then @projects.create_ds()
        when /scale up.*ds.*/ then @projects.scale_up_ds()
        when /scale down.*ds.*/ then @projects.scale_down_ds()
        when /create ss.*/    then @projects.create_ss()
        when /scale up ss.*/ then @projects.scale_up_ss()
        when /scale down ss.*/ then @projects.scale_down_ss()
        when /delete ss pods.*/ then @projects.delete_ss_pods()
        when /modify.*project.*/ then @projects.modify(numstr)
        when /modify.*app.*/ then @projects.modify(numstr)
        when /scale up.*app.*/ then @projects.scale_up(numstr)
        when /scale down.*app.*/ then @projects.scale_down(numstr)
        when /delete.*project.*/ then @projects.delete(numstr)
        when /delete.*user.*/ then @users.delete(numstr)
        when /check project info.*/ then @projects.status(numstr)
        when /clean environment/ then clean_environment()
        when /monitor openshift.*/ then monitor_openshift()
        when /monitor masters.*/ then monitor_masters()
        when /monitor nodes.*/ then monitor_nodes()
        when /monitor etcds.*/ then monitor_etcds()
        when /[curl|visit] .*app.*/   then  @projects.access(numstr)
        else  $logger.info(" unknown instruction ")
        #else $exec.shell_exec(@active_instruction)
      end
    end
  end
end
