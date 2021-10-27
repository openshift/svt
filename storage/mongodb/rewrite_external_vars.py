import yaml


def replace_value_in_file(fileName, key,value):
    # append to file
    with open(fileName, "r") as f:
        yaml_file = yaml.safe_load(f)
        yaml_file[key] = value
    with open(fileName, "w+") as f:
        f.write('---\n')
        str_file = yaml.dump(yaml_file)
        f.write(str_file)
