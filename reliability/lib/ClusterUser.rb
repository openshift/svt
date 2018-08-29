require 'Config'

module OpenshiftReliability
  class ClusterUser

    def initialize()
      @userkey=$config.keys+"admin.kubeconfig"
    end

    def get_projects()
      projects=[]
      res=exec("oc get projects --no-headers")
      if res[:status] ==0 && ! res[:output].nil? && res[:output].length>0
        res[:output].split(/\n/).each do |line|
          project_name=line.split(/\s/)[0]
          next if project_name == "default" || project_name =~ /.*openshift.*/
          projects.push( project_name)
        end
      end
      return projects
    end

    def delete_project(project_name)
      exec("oc delete project #{project_name}")
    end

    def exec(cmd)
      $exec.shell_exec( "#{cmd} --config=#{@userkey}" )
    end

    def delete_user(user_name)
      exec("oc delete user #{user_name}")

      #deleting identity also because if the same user is created it wont have problem
      exec("oc delete identity htpasswd_auth:#{user_name}")
    end

    def create_ds(project_name)
      exec("oc create -f /root/svt/reliability/daemonset-pause-test.yaml -n #{project_name}")
    end

    def label_ds_nodes()
      exec ("oc label nodes -l node-role.kubernetes.io/compute=true --overwrite ds-node=true")
    end

    def unlabel_ds_nodes()
      exec ("oc label nodes -l node-role.kubernetes.io/compute=true --overwrite ds-node=false")
    end
  end
end
