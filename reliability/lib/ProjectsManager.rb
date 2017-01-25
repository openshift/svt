require 'json'
require 'Config'
require 'Project'
require 'ProjectTemplate'
require 'User'
require 'ClusterUser'

module OpenshiftReliability

  class ProjectsManager
    attr_reader :projects

    def initialize(users)
      @users=users
      @projects=[]
      if $config.projectload
        load()
      end
      @defined_templates=$config.templates
      @avaible_templates=$config.templates
      #@avaible_templates=get_avaible_templates()
    end

    def load()
      @users.users.each do |user|
        projects = user.get_projects()
        user.get_projects().each do |project_name|
           @projects.push(Project.new(project_name,user))
        end
      end
    end

    def create(numstr)
      i=0; 
      while i < to_digit(numstr)
        template = guess_template
        user = guess_user
        project_name = template + "-" + user.name + "-" + $config.seq
        case template
          when "rails-postgresql-example" then project=Rails_psql_example.new(project_name,user )
          when "nodejs-example"           then project=Project.new(project_name,user )
          when "django-example"           then project=Project.new(project_name,user )
          when "cakephp-example"          then project=Project.new(project_name ,user)
          when "nodejs-mongodb-example"   then project=Nodejs_mongodb.new(project_name,user )
          when "django-psql-example"      then project=Django_psql.new(project_name,user )
          when "dancer-mysql-example"     then project=Dancer_mysql.new(project_name,user )
          when "cakephp-mysql-example"    then project=Cake_php_mysql.new(project_name ,user)
          when "ruby-hello-world"         then project=Ruby_hello_world.new(project_name ,user)
          when "eap64-mysql-s2i"          then project=EAP_app_mysql.new(project_name,user )
          else project=Project.new(project_name,user )
        end
        project.create()
        project.new_app()
        @projects.push(project)
        i=i+1
      end
    end
     alias create_projects create

    def add(project)
       @projects.push(project)
    end

    def new_app(numstr)
      sel_objects(@projects.length,to_digit(numstr)).each do |i|
        @projects[i].new_app
      end
    end
  
    def delete(numstr)
      sel_objects(@projects.length,to_digit(numstr)).each do |i|
        @projects[i].delete
        @projects[i]=nil
      end
      @projects.compact!
    end

    def delete_all()
      delete("all")
    end

    def rebuild(numstr)
      sel_objects(@projects.length,to_digit(numstr),"1").each do |i|
        project=@projects[i]
        project.use()
        project.modify_app()
      end
    end
    alias modify rebuild
  
    def access(numstr)
      sel_objects(@projects.length,to_digit(numstr),"1").each do |i|
        project=@projects[i]
        project.use()
        project.access_app()
      end
    end
  
    def scale_up(numstr)
      sel_objects(@projects.length,to_digit(numstr),"1").each do |i|
        project=@projects[i]
        project.use()
        project.scale_up()
      end
    end
  
    def scale_down(numstr)
      sel_objects(@projects.length,to_digit(numstr),"1").each do |i|
        project=@projects[i]
        project.use()
        project.scale_down()
      end
    end
  
    def status(numstr)
      sel_objects(@projects.length,to_digit(numstr),"1").each do |i|
        project=@projects[i]
        project.use()
        project.status_app()
      end
    end
    alias check_project_info status
  
    def to_digit(numstr)
      number=0
      percent_status=false
  
      if numstr =~ /all/
        return @projects.length
      elsif /([\d]+)(%)+/ =~ numstr
        number=$1.to_i
        return @projects.length * number / 100
      else /([\d]+)/ =~ numstr
        return $1.to_i 
      end
      return number
    end
  
    def sel_objects(maxnum, usenum, type="0")
       $logger.debug("sel_objects: max=#{maxnum} user=#{usenum}")
       seldigits=[]
       if maxnum==0
          return seldigits
       end
  
       if type=="0"
         if usenum > maxnum
            (0..(maxnum-1)).each {|i| seldigits << i} 
         else
            (0..(usenum-1)).each {|i| seldigits << i} 
         end 
       end
       if type=="1"
         if usenum > maxnum
            (1..(usenum/maxnum)).each do 
               (0..(maxnum-1)).each {|i| seldigits << i} 
            end
            (0..(usenum%maxnum-1 )).each {|i| seldigits << i}
         else
            (0..(usenum-1)).each {|i| seldigits << i} 
         end 
       end
       $logger.debug("sel_objects: selected  #{seldigits}" )
       return seldigits
    end 

    def guess_template()
      return $config.templates[Random.rand($config.templates.length)]
    end
    
    def guess_user()
      return @users.chose()
    end

  end
end
