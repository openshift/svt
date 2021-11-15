from tasks.TaskManager import TaskManager
from tasks.GlobalData import global_data
from tasks.KrakenIntegration import KrakenIntegration
from optparse import OptionParser
import logging
import sys

def init_logger(my_logger,log_file): 
    my_logger.setLevel(logging.INFO)
    fh = logging.FileHandler(log_file)
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
    if not global_data.load_data(options.config):
        sys.exit(1)
    
    # init Kraken integration
    kraken_enable = global_data.config["krakenIntegration"].get("kraken_enable", False)
    if kraken_enable:
        krakenIntegration = KrakenIntegration()
        krakenIntegration.add_jobs()
        krakenIntegration.start()

    # start task manager
    task_manager = TaskManager(options.cerberus_history)

    task_manager.start()

