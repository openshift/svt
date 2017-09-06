from optparse import OptionParser
from sys import maxint
import string
import time
import random
import socket


fixed_line = ""
hostname = socket.gethostname()

# Possible run times are:
#  - fixed number of seconds
#  - set number of messages
#  - run until stopped
def determine_run_time() :
    if int(options.time) > 0 :
        print "time option found, num-lines option ignored"
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
       if sleep_time < 0.1 :
           sleep_this_time = False
           batch_size = 0.1 / options.sleep_time
           sleep_time = 0.1
           if num_messages % int(batch_size) == 0 :
              sleep_this_time = True
       if sleep_this_time :
          time.sleep(sleep_time)
    return

# When file input used, pull a line from the file or re-open file if wrapped/eof
def next_line_from_file() :
    global infile
    current_line = ""
    if infile :
        while len(current_line) < options.line_length :
            in_line = infile.readline()
            if in_line == "" :
                infile.close()
                infile = open(options.file,'r')
            else :
                current_line = current_line + " " + in_line.rstrip()


    return current_line[:options.line_length]

def get_word() :
    return ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(options.word_length))

def get_new_line():

    current_line = ""
    if options.text_type == "random" :
        while len(current_line) < options.line_length :
            current_line = current_line + get_word() + " "
    else:
        current_line = next_line_from_file()

    return current_line[:options.line_length]

def single_line():
    if options.fixed_line and (not fixed_line == ""):
        single_line = fixed_line
    else:
        single_line = get_new_line()

    return single_line

def create_message(seq_number, msg) :
    global hostname
    return hostname + " : " + str(seq_number) + " : " + msg

# Fixed time period, in seconds
def generate_for_time():
    now = time.time()
    then = now + options.time
    number_generated = 0
    while now <= then :
        number_generated += 1
        print create_message(number_generated, single_line())
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
        print create_message(number_generated, single_line())
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


if __name__ ==  "__main__":

    parser = OptionParser()
    parser.add_option("-l", "--line-length", dest="line_length", type="int", default=100,
                     help="length of each output line")
    parser.add_option("--text-type", dest="text_type",
                     help="random or input", default="random")
    parser.add_option("--word-length", dest="word_length", type="int", default=9,
                     help="word length for random text")
    parser.add_option("--fixed-line", dest="fixed_line", action="store_true", default=False,
                      help="the same line is repeated if true, variable line content if false")
    parser.add_option("-f","--file", dest="file", default="",
                     help="file for input text")
    parser.add_option("-r", "--rate", dest="rate", type="float", default=10.0,
                     help="rate in lines per minute")
    parser.add_option("-n", "--num-lines", dest="num_lines", type="int", default=0,
                     help="number of lines to generate, 0 is infinite - cannot be used with -t")
    parser.add_option("-t", "--time", dest="time", type="int", default=0,
                     help="time to run in seconds, cannot be used with -n")

    (options, args) = parser.parse_args()

    if not options.file == "" :
        infile = open(options.file,'r')

    options.sleep_time = 0.0
    if options.rate > 0.0 : 
        options.sleep_time = 60.0/options.rate

    generate_messages()

