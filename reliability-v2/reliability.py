from optparse import OptionParser
import logging
from tasks.TaskManager import TaskManager
from tasks.GlobalData import global_data


def init_logger(my_logger,log_file,verbose): 
    my_logger.setLevel(logging.INFO)
    fh = logging.FileHandler(log_file)
    ch = logging.StreamHandler()
    if verbose == 0:
        fh.setLevel(logging.DEBUG)
        ch.setLevel(logging.DEBUG)
    else:
        fh.setLevel(logging.INFO)
        ch.setLevel(logging.INFO)       
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
    parser.add_option("-v", "--verbose", dest="verbose",default=0, 
                      help="Optional. 0: no verbose, 1: pods and events of ns if new_app failed.Default is 0.")
    (options, args) = parser.parse_args()

    # init logging
    logger = logging.getLogger('reliability')
    init_logger(logger,options.log_file,options.verbose)

    # init global data
    if global_data.load_config(options.config):
        global_data.init_scheduler()
        global_data.init_intgration()
        global_data.init_verbose(options.verbose)
        if global_data.init_users():
            # start task manager
            taskManager = TaskManager(options.cerberus_history)
            taskManager.start()
