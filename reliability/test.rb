## add our lib dir to load path
$LOAD_PATH << File.expand_path("lib")
require 'Config'
require 'logger'
require 'pathname'
require 'InstructionExecute'
require 'EventControl'
require 'TaskControl'

if File.directory?  "#{ENV["RELIA_HOME"]}"
else
   ENV["RELIA_HOME"]=Pathname.new(File.dirname(__FILE__)).realpath.to_s
end
$config=OpenshiftReliability::Config.new()

$logger = Logger.new(STDOUT) 
$logger.datetime_format = "%Y-%m-%d %H:%M:%S"

$logger.level = Logger::DEBUG

task=OpenshiftReliability::TaskControl.new()
task.execute_task("config/tasks/test")
