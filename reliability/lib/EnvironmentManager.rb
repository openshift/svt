require 'ProjectsManager'
require 'UsersManager'

module OpenshiftReliability
 module EnvironmentManager

    def clean_environment()
      # 1) delete projects
      @projects.delete_all()
      @users.clear_project()
      # 2) delete all users?
      #@users.delete("all")
      # 3) delete all Exited docker containers
      clear_container()
      
    end

    def monitor_openshift()
      monitor_masters
      monitor_nodes
      monitor_etcds
    end
 
    def monitor_nodes()
      puts "Monitor Nodes"
      $config.nodes.each do |host|
        cmd="root@#{host} /root/bin/node-monitor#monitor-node-#{host}"
        $logger.info("Monitor node #{host} system information ")
        $exec.execute(cmd)
      end
    end
  
    def monitor_masters()
      puts "Monitor Master"
      $config.masters.each do |host|
         cmd="root@#{host} /root/bin/master-monitor#monitor-master-#{host}"
         $logger.info("Monitor master #{host} system information ")
         $exec.execute(cmd)
      end
    end
  
    def monitor_etcds()
      puts "Monitor etcd"
      $config.etcds.each do |host|
         cmd="root@#{host} /root/bin/etcd-monitor#monitor-etcd-#{host}"
         $logger.info("Monitor etcd #{host} system information")
         $exec.execute(cmd)
      end
    end 

    def clear_container()
      puts "clear docker containers on nodes"
      $config.nodes.each do |host|
        #cmd="root@#{host} 'docker rm -v -f $(docker ps -a |grep Exited | awk %NR>1 {print $1}%)'"
        cmd="root@#{host} '/root/bin/dockerclear'"
        $exec.execute(cmd)
      end
    end

  end
end
