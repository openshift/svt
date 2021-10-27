import yaml


# Get the project name and number of pods from the yaml we loaded
def get_pod_counts_python(file):
    pod_list = []
    with open(file, "r") as f:
        yaml_file = yaml.safe_load(f)
        for proj in yaml_file['projects']:
            for pod in proj['pods']:
                if "total" in pod.keys():
                    print(str(proj['basename']) + " " + str(pod['total']))


# Get the project name and number of pods from the yaml we loaded
def get_pod_counts_golang(file):

    pod_list=[]
    with open(file, "r") as f:
        yaml_file = yaml.safe_load(f)
        for proj in yaml_file['ClusterLoader']['projects']:
            for pod in proj['pods']:
                if "num" in pod.keys():
                    print(str(proj['basename']) + " " + str(pod['num']))
