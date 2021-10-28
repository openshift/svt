import yaml


def print_new_yaml_temp(num, fileName):
    # append to file
    with open(fileName, "r") as f:
        yaml_file = yaml.safe_load(f)
        yaml_file['projects'][0]['templates'][0]['num'] = num
    with open(fileName, "w+") as f:
        str_file = yaml.dump(yaml_file)
        f.write(str_file)


def get_time_stats(time_file, final_log, pod_num):

    times = []
    with open(time_file, "r") as f:
        str_f = f.read()
    for s in str_f.split():
        if s.isdigit():
            times.append(int(s))

    # get min, max, average
    average_time = sum(times) / len(times)
    with open(final_log, "a+") as fin:
        # Iterations needs to be divided by 2 for draining on 2 nodes
        fin.write("======== Stats for " + str(pod_num) + " pods in " + str(len(times)/2) + " iterations ========\n")
        fin.write("Average: " + str(average_time) + " seconds\n")
        fin.write("Max: " + str(max(times)) + " seconds\n")
        fin.write("Min: " + str(min(times)) + " seconds\n")
        fin.write("========================================\n")
