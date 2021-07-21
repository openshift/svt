from oauth2client.service_account import ServiceAccountCredentials
import gspread
import json
import subprocess
from datetime import datetime
import calendar
from pytz import timezone
import get_es_data

def run(command):
    try:
        output = subprocess.check_output(command, shell=True,
                                         universal_newlines=True)
    except Exception as e:
        print("Failed to run %s" % (command))
        print("Error %s" % (str(e)))
        return ""
    return output

def get_benchmark_uuid():
    benchmark_str = run("oc get benchmark -n benchmark-operator -o json")
    if benchmark_str != "":
        benchmark_json = json.loads(benchmark_str)
        for item in benchmark_json['items']:
            uuid = item['status']['uuid']
            #if mutliple not sure what to do
            creation_time = item['metadata']['creationTimestamp']
            # "2021-08-10T13:53:20Z"
            d = datetime.strptime(creation_time[:-1], "%Y-%m-%dT%H:%M:%S")
            from_time = calendar.timegm(d.timetuple()) * 1000

            n_time = datetime.utcnow()
            to_time = calendar.timegm(n_time.timetuple()) * 1000
            grafana_url = "http://grafana.rdu2.scalelab.redhat.com:3000/d/hIBqKNvMz123/kube-burner-report?orgId=1&from="+ str(from_time) + "&to="+ str(to_time) + "&var-Datasource=Development-AWS-ES_ripsaw-kube-burner&var-sdn=openshift-sdn&var-sdn=openshift-ovn-kubernetes&var-job=All&var-uuid=" + uuid + "&var-namespace=All&var-verb=All&var-resource=All&var-flowschema=All&var-priority_level=All"
            print(grafana_url)
            grafana_cell = '=HYPERLINK("' + str(grafana_url) + '","' + str(uuid) + '")'

            workload_args = json.dumps(item['spec']['workload']['args'])
            print('workload ' + str(type(workload_args)))

            # get total duration of run from logs

            return grafana_cell, workload_args
    return "", ""

def get_oc_version():
    cluster_version_str = run("oc get clusterversion -o json")
    cluster_version_json = json.loads(cluster_version_str)
    for item in cluster_version_json['items']:
        for status in item['status']['conditions']:
            if status['type'] == "Progressing":
                version = status['message'].split(" ")[-1]
                print('version ' + str(version))
                return version

def get_nodes():
    cluster_version_str = run("oc get nodes -o json")
    cluster_version_json = json.loads(cluster_version_str)
    for item in cluster_version_json['items']:
        for status in item['status']['conditions']:
            if status['type'] == "Progressing":
                version = status['message'].split(" ")[-1]
                print('version ' + str(version))
                return version


def get_pod_latencies():
    # In the form of [[json_data['quantileName'], json_data['avg'], json_data['P99']...]
    pod_latencies_list = get_es_data.get_pod_latency_data()
    if len(pod_latencies_list) != 0:
        print(str(pod_latencies_list))
        avg_list = []
        p99_list = []
        for pod_info in pod_latencies_list:
            avg_list.append(pod_info[1])
            p99_list.append(pod_info[2])
        return avg_list
    return ["", "", "", ""]

def write_to_sheet(google_sheet_account, flexy_id, ci_job, job_type, job_url, status):
    scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive'
    ]
    credentials = ServiceAccountCredentials.from_json_keyfile_name(google_sheet_account, scopes) #access the json key you downloaded earlier
    file = gspread.authorize(credentials) # authenticate the JSON key with gspread
    #sheet = file.open("Test") #.Outputs
    sheet = file.open_by_url("https://docs.google.com/spreadsheets/d/1uiKGYQyZ7jxchZRU77lsINpa23HhrFWjphsqGjTD-u4/edit?usp=sharing")
    #open sheet

    ws = sheet.worksheet(job_type)

    index = 2

    flexy_cell='=HYPERLINK("https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/ocp-common/job/Flexy-install/'+str(flexy_id)+'","'+str(flexy_id)+'")'
    grafana_cell, workload_args = get_benchmark_uuid()
    ci_cell = '=HYPERLINK("'+str(job_url) + '","' + str(ci_job) + '")'
    version = get_oc_version()
    tz = timezone('EST')


    row = [version, flexy_cell, ci_cell, grafana_cell, status, workload_args]
    row.extend(get_pod_latencies())
    row.append(str(datetime.now(tz)))
    print(row)
    ws.insert_row(row, index, "USER_ENTERED")


#write_to_sheet("/Users/prubenda/.secrets/perf_sheet_service_account.json", 50396, 126, 'cluster-density', "https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/paige-e2e-multibranch/job/cluster-density/126/", "PASS")