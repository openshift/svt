import subprocess


def run_cmd(command):
    try:
        output = subprocess.Popen(command, shell=True,
                                  universal_newlines=True, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT)
        (out, err) = output.communicate()
        print("out " + str(out))
    except Exception as e:
        print("Failed to run %s, error: %s" % (command, e))
        return ""
    return out