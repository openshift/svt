from optparse import OptionParser
import logging
from tasks.TaskManager import TaskManager
from tasks.GlobalData import global_data


def init_logger(my_logger,log_file): 
    my_logger.setLevel(logging.INFO)
    fh = logging.FileHandler(log_file)
    # todo: let user to configure the log level to only output error logs
    fh.setLevel(logging.INFO)
    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    fh.setFormatter(formatter)
    ch.setFormatter(formatter)
    my_logger.addHandler(fh)
    my_logger.addHandler(ch)

if __name__ == "__main__":
    parser = OptionParser()
    parser.add_option("-c", "--config", dest="config",
                      help="YAML reliability config file.")
    parser.add_option("-l", "--log", dest="log_file",default="/tmp/reliability.log", 
                      help="Optional. Log file location. Default is '/tmp/reliability.log'")
    parser.add_option("--cerberus-history", dest="cerberus_history",default="/tmp/cerberus-history.json", 
                      help="Optional. Location to save Cerberus history if Cerberus is enabled in config file. Default is '/tmp/cerberus-history.json'")
    (options, args) = parser.parse_args()

    # init logging
    logger = logging.getLogger('reliability')
    init_logger(logger,options.log_file)

    # init global data
    if global_data.load_config(options.config):

        global_data.init_scheduler()
        global_data.init_intgration()
        if global_data.init_users():
            # start task manager
            taskManager = TaskManager(options.cerberus_history)
            taskManager.start()
