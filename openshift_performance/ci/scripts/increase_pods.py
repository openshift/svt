import subprocess
#pip install ruamel.yaml
from ruamel.yaml import YAML


def run(command):
    try:
        output = subprocess.Popen(command, shell=True,
                                  universal_newlines=True, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT)
        (out, err) = output.communicate()
        print("Out " + str(out))
    except Exception as e:
        print("Failed to run %s, error: %s" % (command, e))
    return out


def print_new_yaml(num, fileName):
    # append to file
    yaml = YAML()
    with open(fileName, "r") as f:
        yaml_file = yaml.safe_load(f)
        yaml_file['projects'][0]['num'] = num
    with open(fileName, "w+") as f:
        yaml.indent(mapping=2, sequence=4, offset=2)
        yaml.dump(yaml_file, f)


def print_new_yaml_temp(num, fileName):
    # append to file
    yaml = YAML()
    with open(fileName, "r") as f:
        yaml_file = yaml.safe_load(f)
        yaml_file['projects'][0]['templates'][0]['num'] = num
    with open(fileName, "w+") as f:
        yaml.indent(mapping=2, sequence=4, offset=2)
        yaml.dump(yaml_file, f)

