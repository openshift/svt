import re
import sys

def percent_difference(new, old):

    response = (new - old)/old*100
    return response

def compare_app_build(json_1, json_2):
    for k1, v1 in list(json_1)[0].items():
        found = False
        for k2, v2 in list(json_2)[0].items():
            if k1 == k2:
                print('\tnumber of builds ' + str(int(k1)))

                build_compare = percent_difference(v1[0], v2[0])
                push_compare = percent_difference(v1[1], v2[1])
                print('\t\tbuild compare: ' + str(build_compare) + "%")
                print('\t\tpush_compare: ' + str(push_compare) + "%")

def read_file(file):
    all_file = []

    app_split = re.split(r"[=]+", file)
    #print('app split ' + str(app_split))
    i = 0
    for app in app_split:
        # first is name
        if app == "":
            continue
        if "\n" == app:
            i = 0
        elif i == 0:
            #get app name
            app_name = app.strip("=").split(' ')[-3]
            i += 1
        else:
            file_lines = app.split('\n')
            file_lines = file_lines[1:-1]
            #might just have to ignore first and last items in last
            j = 0
            build_info = {}
            offset = int(len(file_lines)/3)
            while j < offset:
                build_time = float(file_lines[j].split(': ')[-1])
                push_time = float(file_lines[j + offset].split(': ')[-1])
                num = float(file_lines[j + offset + offset].split(': ')[-1])
                build_info[num] = [build_time, push_time]
                j += 1
            all_file.append({app_name: build_info})
    return all_file

if len(sys.argv) > 3 or len(sys.argv) <= 2:
    print("Need 2 build files to compare")
    sys.exit(1)

#get command line parameters
file_1 = sys.argv[1]
file_2 = sys.argv[2]

with open(file_1, "r") as f1:
    f1_content = f1.read()

f1_list = read_file(f1_content)

with open(file_2, "r") as f2:
    f2_content = f2.read()

f2_list = read_file(f2_content)

for item_1 in f1_list:
    for item_2 in f2_list:
        if item_1.keys() == item_2.keys():
            print("App " + str(list(item_1.keys())[0]))
            compare_app_build(item_1.values(), item_2.values())
            break








