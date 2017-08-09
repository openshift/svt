module OpenshiftReliability
  class User

    attr_reader :name, :password, :token ,:master
    attr_accessor :status
    def initialize(name=nil, password=nil, master=nil, port=8443, token:nil, status:1 )
      @name = name
      @password = password
      @master=master
      @port=port
      @status = status
      @cakey= $config.keys + "ca.crt"
      @userkey=$config.keys + name + ".kubeconfig"
      login()
    end

    #login to sync token for a while
    def login()
      delete_key()
      $exec.shell_exec("oc login #{@master}:#{@port} -u #{@name} -p #{@password} --insecure-skip-tls-verify=true  --certificate-authority=#{@cakey} --config=#{@userkey}")
    end

    def avaible?()
      return true if @status == 1
      return false
    end

    def delete_key()
      $exec.shell_exec("rm #{@userkey}")
    end


    # execute cmd with this user
    def exec(cmdstr)
      cmds=cmdstr.split('#')
      cmd=cmds[0].to_s + " --config=#{@userkey} #" + cmds[1].to_s
      $exec.shell_exec(cmd)
    end

    def get_projects()
      projects=[]

      res=exec("oc get projects --no-headers")
      if res[:status] == 0 && ! res[:output].nil? && res[:output].length>0
        res[:output].split(/\n/).each do |line|
          project_name=line.split(/\s/)[0]
          next if project_name == "default" || project_name =~ /.*openshift.*/
          projects.push( project_name)
        end
      end
      return projects
    end
  end
end
