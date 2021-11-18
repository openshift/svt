import yaml
import json
import subprocess
import datetime
from pytz import timezone

def run(command):
    try:
        output = subprocess.check_output(command, shell=True,
                                         universal_newlines=True)
    except Exception as e:
        print("Failed to run %s" % (command))
        print("Error %s" % (str(e)))
        return ""
    return output


def find_key_to_overwrite(json_file, find_key, new_value):
    counter = 0
    for filters_list in json_file['query']['bool']['filter']:
        for filters, values in filters_list.items():
            print('filter ' + str(filters) + "---" + str(values))
            for k, v in values.items():
                print('v ' + str(v))
                if k == find_key:
                    print('key to replace' + str(json_file['query']['bool']['filter'][counter][filters][k]))
                    json_file['query']['bool']['filter'][counter][filters][k] = new_value
                    print(json_file)
                    return json_file
                if type(v) is dict:
                    print('is dict')
                    for k2, v2 in v.items():
                        if k2 == find_key:
                            json_file['query']['bool']['filter'][counter][filters][k][k2] = new_value
                            print(json_file)
                            return json_file
        counter += 1


def print_new_json(new_value, find_key, fileName):
    # append to file
    with open(fileName, "r") as f:
        json_file = json.loads(f.read())

    new_json_file = find_key_to_overwrite(json_file, find_key, new_value)
    with open(fileName, "w+") as f:
        json.dump(new_json_file, f, indent=4)

def get_benchmark_data():

    benchmark_str = run("oc get benchmark -n benchmark-operator -o yaml")
    if benchmark_str != "":
        benchmark_yaml_all = yaml.safe_load(benchmark_str)
        benchmark_yaml = benchmark_yaml_all['items'][0]
        es_url = benchmark_yaml['spec']['elasticsearch']['url']
        uuid = benchmark_yaml['spec']['uuid']
        creation_time = benchmark_yaml['metadata']['creationTimestamp'][:-1] + ".000Z"
        return es_url, uuid, creation_time
    return "", "", ""

def rewrite_data(start_time, uuid, file_name):

    print_new_json(start_time,"gte", file_name)
    print_new_json(uuid, "uuid", file_name)
    # rewrite lte with current date
    tz = timezone('UTC')
    end_time = datetime.datetime.now(tz).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"
    print_new_json(end_time, "lte", file_name)

def execute_command(es_url, fileName):

    with open(fileName, "r") as f:
        data_json = f.read()
    str_response = run('curl -X GET '+ es_url +"/_search?pretty -H 'Content-Type: application/json' -d'" + data_json + "'")
    data_info = []
    json_response = json.loads(str_response)
    for hits in json_response['hits']['hits']:
        data_info.append(get_data_from_json(hits['_source']))
    sorted_data = sorted(data_info, key=lambda kv:(kv[0], kv[1], kv[2]), reverse=True)
    return sorted_data


def get_data_from_json(json_data):
    return [json_data['quantileName'], json_data['avg'], json_data['P99']]


def get_pod_latency_data():
    file_name = "get_es_data.json"
    es_url, uuid, creation_time = get_benchmark_data()
    if es_url != "":
        rewrite_data(creation_time, uuid, file_name)
        return execute_command(es_url, file_name)
    return []