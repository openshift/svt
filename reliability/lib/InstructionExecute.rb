require 'net/ssh'
require 'net/http'
require 'net/scp'
require 'open3'
require 'logger'

module OpenshiftReliability
  class  InstructionExecute
    
    def initialize(user:"root", password:nil)
      @user=user
      @password=password
    end
  
    def shell_exec(cmdstr)
      result={}
      $logger.debug(" shell_exec #{cmdstr} ")
      array=cmdstr.split('#')
      cmd=array[0]
      if array[1].nil?
        descr=""
      else
        descr=array[1]
      end
      stdout_str=""
      stderr_str=""
      status=""
      # To capature tree output, we must use Open3
      stdout_str,stderr_str, status = Open3.capture3(cmd)
  
      output=""
      outerr=""
      if ! stdout_str.nil? && stdout_str.length>0
        output=stdout_str.gsub(/\n/,"[#]")
      end
      if ! stderr_str.nil? && stderr_str.length>0
        outerr=stderr_str.gsub(/\n/,"[#]")
      end
      
      if "#{status}" =~ /.*exit 0.*/
        $logger.info("#{descr} Execute: #{cmd}  -> pass")
        $logger.info("#{descr} status: #{status}")
        $logger.info("#{descr} stdout: #{output}")
        $logger.info("#{descr} stderr: #{outerr}")
        result[:status] = 0
      else
        $logger.error("#{descr} Execute: #{cmd}  -> fail")
        $logger.error("#{descr} status: #{status}")
        $logger.error("#{descr} stdout: #{output}")
        $logger.error("#{descr} stderr: #{outerr}")
        result[:status] = 1
      end
  
      result[:output] = stdout_str
      result[:stderr] = stderr_str
      return result
   end
  
    def execute(rmtcmd)
      /(\w+)@([\w|.|-]+) (.*)/ =~ rmtcmd
      user=$1
      host=$2
      cmd=$3
      result={}
  
      $logger.info("Execute [#{rmtcmd}] ")
      if host=~/127.0.0.1/ || host=~/localhost/ 
         result= shell_exec(cmd)
      else
         result= remote_exec(user,host,cmd)
      end
    end
  
    def remote_exec(user="root", host="127.0.0.1", cmdstr="pwd")
      $logger.debug(" remote_exec user=#{user} host=#{host} cmd=#{cmdstr} ")
  
      result={}
      array=cmdstr.split('#')
      cmd=array[0]
      if array[1].nil?
        descr=""
      else
        descr=array[1]
      end
      
      stdout=""
      stderr=""
      status=0
      session=Net::SSH.start(host, user, :password=>@password ) do | session |
        session.open_channel do |channel|
          #channel.send_request "shell", nil, true
          channel.exec(cmd) do |ch, success|
            abort "could not execute command" unless success

            if success
              status = 0
            else
              status = 1
              break
            end

            channel.on_data do |ch, data|
              stdout=stdout + data
            end
  
            channel.on_extended_data do |ch, type, data|
              stderr=stderr + data
            end

            channel.on_close do |ch|
              # puts "channel closed"
            end
          end
        end
        session.loop
      end
  
      output=""
      outerr=""
      if ! stdout.nil? && stdout.length>0
        output=stdout.gsub(/\n/,"[#]")
      end
      if ! stderr.nil? && stderr.length>0
        outerr=stderr.gsub(/\n/,"[#]")
      end
      if status ==0
        $logger.info("#{descr} Execute: #{cmd}  -> pass")
        $logger.info("#{descr} ssh status: #{status}")
        $logger.info("#{descr} ssh stdout: #{output}")
        $logger.info("#{descr} ssh stderr: #{outerr}")
      else
        $logger.error("#{descr} Execute: #{cmd}  -> fail")
        $logger.error("#{descr} ssh status: #{status}")
        $logger.error("#{descr} ssh stdout: #{output}")
        $logger.error("#{descr} ssh stderr: #{outerr}")
      end
  
      result[:stderr] = stderr
      result[:output] = stdout
      result[:status] = status
  
      return result
    end
    
    # Upload commands in an array to a files in remote 
    def remote_upload(user=@user, host="127.0.0.1", remotefile, cmdsarray)
      $logger.debug(" remote_upload user=#{user} host=#{host} remotefile=#{remotefile}")
      shellcmds="#!/usr/bin/bash"
      cmdsarray.each do |item|
        shellcmds="#{shellcmds}\n#{item}"
      end
      Net::SCP.start(host, user, :password=>@password ) do |session|
        session.upload! StringIO.new(shellcmds) , "#{remotefile}"
      end
    end
  end
  $exec=InstructionExecute.new()
end
