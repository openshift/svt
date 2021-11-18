from oauth2client.service_account import ServiceAccountCredentials
import gspread
import json
import subprocess
from datetime import datetime
import calendar
from pytz import timezone
import get_es_data
import write_helper

def get_benchmark_uuid():
    benchmark_str = write_helper.run("oc get benchmark -n benchmark-operator -o json")
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
            return grafana_cell, workload_args
    return "", ""

def get_nodes():
    cluster_version_str = write_helper.run("oc get nodes -o json")
    cluster_version_json = json.loads(cluster_version_str)
    for item in cluster_version_json['items']:
        for status in item['status']['conditions']:
            if status['type'] == "Progressing":
                version = status['message'].split(" ")[-1]
                print('version ' + str(version))
                return version

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
    version = write_helper.get_oc_version()
    tz = timezone('EST')


    row = [version, flexy_cell, ci_cell, grafana_cell, status, workload_args]
    row.extend(write_helper.get_pod_latencies())
    row.append(str(datetime.now(tz)))
    print(row)
    ws.insert_row(row, index, "USER_ENTERED")


#write_to_sheet("/Users/prubenda/.secrets/perf_sheet_service_account.json", 50396, 126, 'cluster-density', "https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/paige-e2e-multibranch/job/cluster-density/126/", "PASS")