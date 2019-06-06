from tasks.TaskManager import TaskManager
from optparse import OptionParser
import logging

def init_logger(my_logger): 
    my_logger.setLevel(logging.INFO)
    fh = logging.FileHandler('/tmp/reliability.log')
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
    parser.add_option("-f", "--file", dest="file",
                      help="YAML reliability config file")
    (options, args) = parser.parse_args()

    logger = logging.getLogger('reliability')
    init_logger(logger)
    
    task_manager = TaskManager(options.file)

    task_manager.start()