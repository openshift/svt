#!/usr/bin/python2
from optparse import OptionParser
from sys import maxint
import string
import time
import random
import socket
import logging
import logging.handlers
import json_logging, sys

fixed_line = ""
hostname = socket.gethostname()

# Possible run times are:
#  - fixed number of seconds
#  - set number of messages
#  - run until stopped
def determine_run_time() :
    if int(options.time) > 0 :
        fixed_count = False
        infinite = False
        fixed_time = True
    elif int(options.num_lines) > 0 :
        fixed_count = True
        infinite = False
        fixed_time = False
    else:
        fixed_count = False
        infinite = True
        fixed_time = False

    return fixed_count, fixed_time, infinite

def delay(sleep_time,num_messages) :

# Avoid unnecessary calls to time.sleep()
    if sleep_time > 0.0 :
       sleep_this_time = True;

# Calling time.sleep() more than 10 times per second is pointless and adds too much overhead
# Back off to batches of messages big enough so that sleep is called 10 times per second max
       if sleep_time < 0.05 :
           sleep_this_time = False
           batch_size = (0.05 / sleep_time) * 10.0
           sleep_time = 0.5
           if num_messages % int(round(batch_size)) == 0 :
              sleep_this_time = True
       if sleep_this_time :
          time.sleep(sleep_time)
    return

# When file input used, pull a line from the file or re-open file if wrapped/eof
def next_line_from_file() :
    global infile
    if infile :
        in_line = infile.readline()
        if in_line == "" :
            infile.close()
            infile = open(options.file,'r')
            in_line = infile.readline()

    return in_line.rstrip()

def next_line_from_file_by_length(line_length):
    current_line = next_line_from_file()
    while (len(current_line) < line_length) :
        current_line = current_line + " " + next_line_from_file()

    return current_line[:line_length]

def get_word() :
    return ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(options.word_length))

def get_new_line():

    current_line = ""
    if options.text_type == "random" or options.text_type == "randomjson" :
        while len(current_line) < options.line_length :
            current_line = current_line + get_word() + " "
    elif options.text_type == "input":
        current_line = next_line_from_file_by_length(options.length)

    return current_line[:options.line_length]

def get_raw_line():
    return next_line_from_file()

def single_line():
    if options.fixed_line and (not fixed_line == ""):
        single_line = fixed_line
    elif options.raw:
        single_line = get_raw_line()
    else:
        single_line = get_new_line()

    return single_line

def create_message(seq_number, msg) :
    global hostname
    if not options.raw :
       msg = hostname + " : " + str(seq_number) + " : " + msg
    return msg

def print_json_message(seq_number, msg) :
    global hostname
    logger.info(msg, extra = {'props' : {'seqnum' : seq_number, "hostname": hostname }})

def print_message(seq_number):
    if options.text_type == "randomjson":
       print_json_message(seq_number,single_line())

    else:
        logger.info( create_message(seq_number, single_line()) )


# Fixed time period, in seconds
def generate_for_time():
    now = time.time()
    then = now + options.time
    number_generated = 0
    while now <= then :
        number_generated += 1
        #logger.info( create_message(number_generated, single_line()) )
        print_message(number_generated)
        delay(options.sleep_time, number_generated)
        now = time.time()

    return

#Set number of lines, or infinite if time is 0
def generate_num_lines() :
    global hostname
    if options.num_lines == 0 :
        number_to_generate = maxint
    else :
        number_to_generate = options.num_lines

    number_generated = 0
    while (number_generated < number_to_generate) :
        number_generated += 1
        #logger.info( create_message(number_generated, single_line()) )
        print_message(number_generated)
        delay(options.sleep_time, number_generated)

def generate_messages() :
    global fixed_line
    if options.fixed_line :
        fixed_line = single_line()
    (fixed_count, fixed_time, infinite) = determine_run_time()
    if fixed_time :
        generate_for_time()
    else:
        generate_num_lines()

def init_logger(my_logger):
    my_logger.setLevel(logging.INFO)

    if options.text_type == "randomjson":
        json_logging.ENABLE_JSON_LOGGING = True
        json_logging.init_non_web()

    if options.journal :
        jh = logging.handlers.SysLogHandler(address = '/dev/log')
        my_logger.addHandler(jh)

    elif options.log_on_file:
        print 'log_on_file: {}'.format(options.log_on_file)
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        fh = logging.FileHandler(options.log_on_file)

        if not (options.raw or options.text_type == "randomjson") :
           fh.setFormatter(formatter)
        my_logger.addHandler(fh)
    else :
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        sh = logging.StreamHandler(sys.stdout)
        if not (options.raw or options.text_type == "randomjson") :
           sh.setFormatter(formatter)
        my_logger.addHandler(sh)

if __name__ ==  "__main__":

    parser = OptionParser()
    parser.add_option("-l", "--line-length", dest="line_length", type="int", default=100,
                     help="length of each output line")
    parser.add_option("--text-type", dest="text_type",
                     help="random randomjson or input", default="random")
    parser.add_option("--word-length", dest="word_length", type="int", default=9,
                     help="word length for random text")
    parser.add_option("--fixed-line", dest="fixed_line", action="store_true", default=False,
                      help="the same line is repeated if true, variable line content if false")
    parser.add_option("-f","--file", dest="file", default="",
                     help="file for input text")
    parser.add_option("-j","--journal", dest="journal", action="store_true", default=False,
                      help="use logger to log messages to journald instead of stdout")
    parser.add_option("--raw", dest="raw", action="store_true", default=False,
                      help="log raw lines from a file with no timestamp or counters")
    parser.add_option("-o", "--log-on-file", dest="log_on_file",
                      help="the file path to which the log outputs")
    parser.add_option("-r", "--rate", dest="rate", type="float", default=10.0,
                     help="rate in lines per minute")
    parser.add_option("-n", "--num-lines", dest="num_lines", type="int", default=0,
                     help="number of lines to generate, 0 is infinite - cannot be used with -t")
    parser.add_option("-t", "--time", dest="time", type="int", default=0,
                     help="time to run in seconds, cannot be used with -n")

    (options, args) = parser.parse_args()

    if not options.file == "" :
        infile = open(options.file,'r')

    if options.raw and options.file == "":
        print "ERROR: --raw mode can only be used if --file is specified"
        exit(-1)

    options.sleep_time = 0.0
    if options.rate > 0.0 : 
        options.sleep_time = 60.0/options.rate


    logger = logging.getLogger('SVTLogger')
    init_logger(logger)


    generate_messages()
