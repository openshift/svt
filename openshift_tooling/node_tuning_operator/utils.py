from sys import stdout
from time import sleep
import subprocess

# Setting the output colors

black = "\33[30m"
red = "\33[31m"
on_red = "\33[41m"
blue = "\33[34m"
on_blue = "\33[44m"
green = "\33[32m"
on_green = "\33[42m"
reset = "\33[0m"


def print_title(title):
    print("Running test: {}{}{}{}".format(black, on_blue, title, reset))


def print_step(step_description):
    print("\nStep: {}{}{}{}".format(black, on_blue, step_description, reset))


def print_command(command_description):
    print("Executing command: {}{}{}".format(blue, command_description, reset))


def print_warning(warning):
    print("{}{}{}{}".format(black, red, warning, reset))


def passed(description):
    print("{}{}STEP PASSED{}".format(black, on_green, reset))
    if description is not None:
        print("{}{}{}".format(green, description, reset))


def fail(description, cleaning_method):
    print("{}{}STEP FAILED{}".format(black, on_red, reset))
    if description is not None:
        print("{}{}{}".format(red, description, reset))
    cleaning_method()


def execute_command(command_to_execute):
    print_command(command_to_execute)
    try:
        value_to_return = subprocess.check_output(command_to_execute, shell=True)
    except subprocess.CalledProcessError as exc:
        value_to_return = exc.output
    return value_to_return


def execute_command_on_node(node_address, command_to_execute):
    command_on_node = "oc debug node/{} -- chroot /host {}".format(node_address, command_to_execute)
    return execute_command(command_on_node)


def countdown(t):
    while t:
        minutes, secs = divmod(t, 60)
        time_format = '{:02d}:{:02d}'.format(minutes, secs)
        stdout.write("\r%s" % time_format)
        stdout.flush()
        sleep(1)
        t -= 1
    stdout.write("\r00:00 Continue...\n")
