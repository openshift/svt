require 'User'
require 'Project'
require 'Config'

module OpenshiftReliability

  class Rails_psql_example < Project

    def initialize(project_name,user)
      super(project_name, user, template:"rails-postgresql-example" )
      @counter=0
    end

    def access_route()

      if @routes.length == 0
         get_route()
      end
      @routes.each do |route|
        fqdn=route.split(/\s+/)[1]
        cmd="curl --resolve #{fqdn}:80:#{$config.routers.first} http://#{fqdn}|grep 'Welcome to your Rails application on OpenShift'"
        $exec.shell_exec(cmd)
      end
    end
  end
  
  class Cake_php_mysql < Project
  
    def initialize(project_name,user)
      super(project_name, user, template:"cakephp-mysql-example" )
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
    def initialize(project_name,user)
      super(project_name, user, template:"dancer-mysql-example" )
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
    def initialize(project_name,user)
      super(project_name, user, template:"nodejs-mongodb-example" )
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
    def initialize(project_name,user)
      super(project_name, user, template:"django-psql-example" )
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
  
 class EAP_app_mysql < Project
    def initialize(project_name,user)
      super(project_name,user, template:"eap64-mysql-s2i" )
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
end  
