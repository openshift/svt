## add our lib dir to load path
$LOAD_PATH << File.expand_path("lib")
require 'Config'
require 'logger'
require 'pathname'
require 'InstructionExecute'
require 'EventControl'
require 'TaskControl'

$config=OpenshiftReliability::Config.new()
$logger = Logger.new('logs/reliability.log', 100, 102400000) 
$logger.datetime_format = "%Y-%m-%d %H:%M:%S"
$logger.level = Logger::DEBUG
#$logger.level = Logger::INFO

evc=OpenshiftReliability::EventControl.new(OpenshiftReliability::TaskControl.new())
evc.schedule_event()
