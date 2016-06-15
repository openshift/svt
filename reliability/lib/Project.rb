require 'Config'
require 'User'

module OpenshiftReliability

  class Project
    attr_reader :name, :template 
    def initialize(name,user, template:"cakephp-mysql-example")
      @name = name
      @user=user
      @template=template
      @bcs=[]
      @builds=[]
      @dcs=[]
      @pods=[]
      @rcs=[]
      @routes=[]
      @services=[]
    end
    def user_name
      return @user.name
    end

    def exec(cmd) 
      @user.exec(cmd+"##{@name}")
    end

    def create()
      exec("oc new-project #{@name}")
    end

    def delete()
      exec("oc delete project #{@name}")
    end

    def use()
      exec("oc project #{@name} ")
    end

    def access_app()
      access_service()
      access_route()
    end

    def modify_app()
      start_build()
      scale_up
      scale_down
    end

    def status_app()
      get_all()
    end

    def exec(cmd)
      cmd=cmd + '#' + @project_name.to_s
      @user.exec(cmd)
    end
  
    def get_bc
       res=exec("oc get bc --no-headers")
       if res[:status] ==0 && ! res[:output].nil? && res[:output].length>0
         @bcs=res[:output].split(/\n/)
       end
    end
  
    def get_build
       res=exec("oc get builds --no-headers")
       if res[:status] ==0 && ! res[:output].nil? && res[:output].length>0
         @builds=res[:output].split(/\n/)
       end
    end
  
    def get_dc
       res=exec("oc get dc --no-headers")
       if res[:status] ==0 && ! res[:output].nil? && res[:output].length>0
         @dcs=res[:output].split(/\n/)
       end
    end
  
    def get_pods
       res=exec("oc get pods -- --no-headers")
       if res[:status] ==0 && ! res[:output].nil? && res[:output].length>0
         @pods=res[:output].split(/\n/)
       end
    end
  
    def get_rc
       res=exec("oc get rc --no-headers")
       if res[:status] ==0 && ! res[:output].nil? && res[:output].length>0
         @rcs=res[:output].split(/\n/)
       end
    end
  
    def get_route
       res=exec("oc get route --no-headers")
       if res[:status] ==0 && ! res[:output].nil? && res[:output].length>0
         @routes=res[:output].split(/\n/)
       end
    end
  
    def get_service()
       res=exec("oc get service --no-headers")
       if res[:status] ==0 && ! res[:output].nil? && res[:output].length>0
         @services=res[:output].split(/\n/)
       end
    end
  
    def get_all()
       exec("oc get all")
    end

    def new_app(template:nil)
      get_service
      if @services.length > 0 
        $logger.info("Service exist, app creake skipped") 
        return
      end
      @template=template if template 
      @user.exec("oc new-app --template=#{@template}")
      wait_until_ready
    end
  
    def start_build()
      if @bcs.length == 0
         get_bc()
      end
      @bcs.each do |bc|
        bcname=bc.split(/\s+/)[0]
        @user.exec("oc start-build #{bcname} --follow")
      end
    end
  
    def deploy_latest()
     if @dcs.length == 0 
       get_dc()
     end
     @dcs.each do |dc|
       dcname=dc.split(/\s+/)[0]
       @user.exec("oc deploy #{dcname} --latest")
     end
    end
  
    def access_route()
      if @routes.length == 0 
         get_route()
      end 
      @routes.each do |route|
        fqdn=route.split(/\s+/)[1]
        cmd="curl -H 'Host:#{fqdn}' #{$config.routers.first} >/dev/null | echo $?"
        $exec.shell_exec(cmd)
      end
    end
  
    def access_service()
      if @services.length ==0
         get_service()
      end
      host=$config.master
      @services.each do |sr|
        array=sr.split(/\s+/)
        port=array[3].split('/')[0]
        cmd="curl -s #{array[1]}:#{port} >/dev/null | echo $?"
        $exec.remote_exec( "root",host, cmd)
      end
    end
  
    def scale_up()
     get_dc()
     @dcs.each do |dc|
       array=dc.split(/\s+/)
       name=array[0]
       number=array[2].to_i
  
       # I want to skip db,amq and etc, need to find a better way to do this
       if (name != 'database' && name != 'mysql' && name != 'eap-app-mysql') && number>0
          number=number+1
          @user.exec("oc scale dc #{name} --replicas=#{number}")
       end
     end
     #wait for few secs
     sleep 10
    end
  
    def scale_down()
     get_dc()
     @dcs.each do |dc|
       array=dc.split(/\s+/)
       name=array[0]
       number=array[2].to_i
  
       # I want to skip db,amq and etc
       if (name != 'database' && name != 'mysql' && name != 'eap-app-mysql') && number>0
          number=number-1
          @user.exec("oc scale dc #{name} --replicas=#{number}")
       end
       
     end
     #wait for few secs
     sleep 10
    end
  
    def wait_until_ready()
  
        wait_minute_num=15
        i = 0
        while i < wait_minute_num
  
           res=@user.exec("oc status")
           if res[:output] =~ /.*deployment.*waiting on image or update.*/ || res[:output] =~ /.*deployment.*running for.*/
             sleep 60
             i = i + 1
           else
             break
           end
        end
    end
  end
end
