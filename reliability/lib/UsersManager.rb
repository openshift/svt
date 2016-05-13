require 'User'

module OpenshiftReliability
  class  UsersManager
  
    attr_reader :users
    def initialize()
      @users=[]
      load_users()
      @admin=ClusterUser.new()
    end

    def load_users()
      userlist=File.read($config.home+"/config/users.data")
      userlist.split(/\n/).each do |line|
        array=line.split(':')
        @users.push(User.new(array[0],array[1], $config.master))
      end
    end

    def login(numstr)
      sel_objects(@users.length,to_digit(numstr)).each do |i|
        @users[i].login()
      end
    end

    def create(numstr)

      if $config.authtype == 'htpasswd'
         $logger.info " Create number users."
         number=to_digit(numstr)
         create_htpusers(number)
      else
         $logger.info " skip user creatation now."
      end
    end

    def create_htpusers(number)

      host=$config.master
      newusers=[]
      defaultpassword="redhat"
      usercreatecmds=[]
      (1..number).each do
         newuser="#{$config.prefix}-#{$config.seq}"
         newusers << newuser
         cmd="htpasswd -b #{$config.htpasswd} #{newuser} #{defaultpassword}"
         usercreatecmds << cmd
      end
      usercreatecmds << "exit 0"
      $exec.remote_upload("root", host, "/root/bin/addnewusers", usercreatecmds)
      cmd="root@#{host} sh /root/bin/addnewusers#addnewuser"
      res=$exec.execute(cmd)
      if res[:status] == 0
        newusers.each do |u|
           @users.push(User.new(u, defaultpassword, $config.master))
        end
        f =File.open($config.home+"/config/users.data", "w+")
        @users.each do |u|
           f.puts "#{u.name}:#{defaultpassword}\n"
        end
        f.close
      end
    end

    def chose()
       @users[Random.rand(@users.length)]
    end

    def delete(numstr)

      sel_objects(@users.length,to_digit(numstr)).each do |i|
        projects=@users[i].get_projects
        if(projects.length > 0)
          #cant delete this user, because there is a project associated with this user.
          $logger.info("User #{@users[i].name} can't be deleted, there is a project associated with this user")
        else
          @admin.delete_user(@users[i].name)
          @users[i]=nil
	      end
      end
      @users.compact!

      f =File.open($config.home+"/config/users.data", "w")
      @users.each do |u|
         f.puts "#{u.name}:#{u.password}\n"
      end
      f.close

    end

    def clear_project
         @users.each do |u|
         u.get_projects().each { |p_name| @admin.exec("oc delete project #{p_name}") }
      end

    end

    def to_digit(numstr)
      number=0
      percent_status=false

      if numstr =~ /all/
        return @users.length
      elsif /([\d]+)(%)+/ =~ numstr
        number=$1.to_i
        return @users.length * number / 100
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
  end
end
