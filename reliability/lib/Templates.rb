require 'yaml'
require 'User'
require 'Config'

module 'OpenshiftReliability'
  class Ruby_hello_world < Project
  
    def initialize(user,project_name)
      super(user,project_name, template:"ruby-hello-world" )
      @counter=0
    end
  
    def new_app()
      get_service
      if @services.length > 0
        $logger.info("Service exsit, app creake skipped")
        return
      end
  
      @user.exec("new-app -i ruby https://github.com/anpingli/ruby-hello-world")
      wait_until_ready
    end
  
  
    def access_route()
      key="osekey"+ @counter.to_s
      value="osevalue"+@counter.to_s
      @counter=@counter+1
  
      if @routes.length == 0
         get_route()
      end
      @routes.each do |route|
        fqdn=route.split(/\s+/)[1]
        postcmd="curl --resolve #{fqdn}:80:#{$config.routers.first} http://#{fqdn}/keys/#{key} -X POST -d 'value=#{value}'"
        getcmd="curl --resolve #{fqdn}:80:#{$config.routers.first} http://#{fqdn}/keys/#{key} -X GET"
        delcmd="curl --resolve #{fqdn}:80:#{$config.routers.first} http://#{fqdn}/keys/#{key} -X DELETE"
        $exec.shell_exec(postcmd)
        $exec.shell_exec(getcmd)
        $exec.shell_exec(delcmd)
      end
    end
  end
  
  class Cake_php_mysql < Project
  
    def initialize(user,project_name)
      super(user,project_name, template:"cakephp-mysql-example" )
      @counter=0
    end
  
    def access_route()
  
      if @routes.length == 0
         get_route()
      end
      @routes.each do |route|
        fqdn=route.split(/\s+/)[1]
        cmd="curl --resolve #{fqdn}:80:#{$config.routers.first} http://#{fqdn}|grep 'count-value'"
        $exec.shell_exec(cmd)
      end
    end
  end
  
  class Dancer_mysql < Project
    def initialize(user,project_name)
      super(user,project_name, template:"dancer-mysql-example" )
      @counter=0
    end
  
    def access_route()
  
      if @routes.length == 0
         get_route()
      end
      @routes.each do |route|
        fqdn=route.split(/\s+/)[1]
        cmd="curl --resolve #{fqdn}:80:#{$config.routers.first} http://#{fqdn}|grep 'count-value'"
        $exec.shell_exec(cmd)
      end
    end
  end
  
  class Nodejs_mongodb < Project
  
    def initialize(user,project_name)
      super(user,project_name, template:"nodejs-mongodb-example" )
      @counter=0
    end
  
    def access_route()
  
      if @routes.length == 0
         get_route()
      end
      @routes.each do |route|
        fqdn=route.split(/\s+/)[1]
        cmd="curl --resolve #{fqdn}:80:#{$config.routers.first} http://#{fqdn}|grep 'count-value'"
        $exec.shell_exec(cmd)
      end
    end
  end
  
  class Django_psql < Project
  
    def initialize(user,project_name)
      super(user,project_name, template:"django-psql-example" )
      @counter=0
    end
  
    def access_route()
  
      if @routes.length == 0
         get_route()
      end
      @routes.each do |route|
        fqdn=route.split(/\s+/)[1]
        cmd="curl --resolve #{fqdn}:80:#{$config.routers.first} http://#{fqdn}|grep 'Page views'"
        $exec.shell_exec(cmd)
      end
    end
  end
end

class EAP_app_mysql < Ops
  def initialize(user,project_name)
    super(user,project_name, template:"eap64-mysql-s2i" )
    @counter=0
  end

  def new_app()
    get_service
    if @services.length > 0
      $logger.info("Service exist, app create skipped")
      return
    end

    @user.exec("oc create -f https://raw.githubusercontent.com/jboss-openshift/application-templates/master/secrets/eap-app-secret.json")
    @user.exec("oc new-app --template=eap64-mysql-s2i")
    wait_until_ready
  end

  def access_route()

    if @routes.length == 0
       get_route()
    end
    @routes.each do |route|
      fqdn=route.split(/\s+/)[1]

      #ignore the secure route, since we do not expect this to work
      next if fqdn.include?"secure"

      cmd="curl --resolve #{fqdn}:80:#{$config.routers.first} http://#{fqdn}|grep 'TODO list'"
      $exec.shell_exec(cmd)
    end
  end
end
