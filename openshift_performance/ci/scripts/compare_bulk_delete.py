import re
import sys

def percent_difference(new, old):

    response = (new - old)/old*100
    return response

def compare_delete_timing(json_1, json_2):
    for k1, v1 in json_1.items():
        for k2, v2 in json_2.items():
            if k1 == k2:
                print('\tnumber of projects ' + str(k1))
                delete_compare = percent_difference(v1, v2)
                print('\t\tdeletion compare: ' + str(delete_compare) + "%")


def read_file(file):
    all_file = []

    delete_split = file.split('\n')
    i = 0
    proj_dict = {'empty': {}, 'loaded': {}}
    empty = True
    for delete_line in delete_split:
        # each set of info is 2 lines:
        # 1 line number and type of projects
        # line 2 is deletion time
        if "delet" not in delete_line.lower():
            i = 0
            continue
        elif delete_line in ["", "\n"]:
            i = 0
            continue
        elif i == 0:
            delete_num = int(delete_line.split(' ')[-3])
            i += 1
            if "empty" in delete_line:
                empty = True
            else:
                empty = False

        else:
            #might just have to ignore first and last items in last
            delete_time = delete_line.split(" - ")[-1]
            if empty:
                proj_dict['empty'][delete_num] = int(delete_time)
            else:
                proj_dict['loaded'][delete_num] = int(delete_time)
            i = 0
    return proj_dict

if len(sys.argv) > 3 or len(sys.argv) <= 2:
    print("Need 2 delete output files to compare")
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

for k1, v1 in f1_list.items():
    for k2, v2 in f2_list.items():
        if k1 == k2:
            print('Comparing deletion time of ' + str(k1) + ' projects')
            compare_delete_timing(v1, v2)








