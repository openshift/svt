import subprocess
import yaml


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
    with open(fileName, "r") as f:
        yaml_file = yaml.load(f, Loader=yaml.FullLoader)
        print("yaml file " + str(yaml_file))
        yaml_file['projects'][0]['num'] = num
        print("new yaml file " + str(yaml_file))
    with open(fileName, "w+") as f:
        str_file = yaml.dump(yaml_file)
        print('type ' + str(type(str_file)))
        f.write(str_file)

def print_new_storage_class(storage_class, fileName):
    # append to file
    with open(fileName, "r") as f:
        yaml_file = yaml.load(f, Loader=yaml.FullLoader)
        print("yaml file " + str(yaml_file['projects'][0]))
        i = 0
        for params in yaml_file['projects'][0]['templates'][0]['parameters']:
            print("params " + str(params))
            if "STORAGE_CLASS" in params.keys():
                yaml_file['projects'][0]['templates'][0]['parameters'][i]['STORAGE_CLASS'] = storage_class
            i += 1
        print("new yaml file " + str(yaml_file))
    with open(fileName, "w+") as f:
        str_file = yaml.dump(yaml_file)
        f.write(str_file)

def print_new_yaml_temp(num, fileName):
    # append to file
    with open(fileName, "r") as f:
        yaml_file = yaml.load(f, Loader=yaml.FullLoader)
        print("yaml file " + str(yaml_file))
        yaml_file['projects'][0]['templates'][0]['num'] = num
        print("new yaml file " + str(yaml_file))
    with open(fileName, "w+") as f:
        str_file = yaml.dump(yaml_file)
        print('type ' + str(type(str_file)))
        f.write(str_file)
