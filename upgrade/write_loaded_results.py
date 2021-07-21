from oauth2client.service_account import ServiceAccountCredentials
import gspread
import json
import subprocess
from datetime import datetime
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

def get_upgrade_duration():

    version_str = run("oc get clusterversion -o json")
    all_versions = []
    end_date_time = datetime.now()
    start_date_time = datetime.now()
    if version_str != "":
        version_json = json.loads(version_str)
        for item in version_json['items']:
            for hist in item['status']['history']:
                all_versions.append(hist['version'])
                print("hist" + str(hist['version']))
                start_time = hist['startedTime']
                if not hist['completionTime']:
                    end_date_time = datetime.now()
                    print("date time now ")
                else:
                    end_time = hist['completionTime']
                    end_date_time = datetime.strptime(end_time[:-1], "%Y-%m-%dT%H:%M:%S")
                start_date_time = datetime.strptime(start_time[:-1], "%Y-%m-%dT%H:%M:%S")

        time_elapsed = end_date_time - start_date_time

        print("time elapsed" + str(time_elapsed))

        return str(time_elapsed), sorted(all_versions)
    return "", get_oc_version()

def get_oc_version():
    cluster_version_str = run("oc get clusterversion -o json")
    cluster_version_json = json.loads(cluster_version_str)
    for item in cluster_version_json['items']:
        for status in item['status']['conditions']:
            if status['type'] == "Progressing":
                version = status['message'].split(" ")[-1]
                print('version ' + str(version))
                return [version]


def flexy_install_type(flexy_url):
    version_type_string = run('curl -s '+ flexy_url + '/consoleFull' + ' | grep "run_installer template -c private-templates/functionality-testing/aos-"')
    version_lists = version_type_string.split("-on-")
    print('version_lists ' + str(version_lists))
    install_type = version_lists[0].split('/')[-1]
    cloud_type = version_lists[1].split('/')[0]
    if "ovn" in version_type_string:
        network_type = "OVN"
    else:
        network_type = "SDN"

    return cloud_type, install_type, network_type

def get_pod_latencies():
    # In the form of [[json_data['quantileName'], json_data['avg'], json_data['P99']...]
    pod_latencies_list = get_es_data.get_pod_latency_data()
    print(str(pod_latencies_list))
    avg_list = []
    p99_list = []
    for pod_info in pod_latencies_list:
        avg_list.append(pod_info[1])
        p99_list.append(pod_info[2])
    return avg_list

def write_to_sheet(google_sheet_account, flexy_id, scale_ci_job, upgrade_job_url, loaded_upgrade_url, status, scale, force):
    scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive'
    ]
    credentials = ServiceAccountCredentials.from_json_keyfile_name(google_sheet_account, scopes) #access the json key you downloaded earlier
    file = gspread.authorize(credentials) # authenticate the JSON key with gspread
    #sheet = file.open("Test") #.Outputs
    sheet = file.open_by_url("https://docs.google.com/spreadsheets/d/1uiKGYQyZ7jxchZRU77lsINpa23HhrFWjphsqGjTD-u4/edit?usp=sharing")
    #open sheet

    ws = sheet.worksheet("Loaded Proj Result")

    index = 2
    flexy_url ="https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/ocp-common/job/Flexy-install/" + str(flexy_id)
    cloud_type, install_type, network_type = flexy_install_type(flexy_url)
    duration, versions = get_upgrade_duration()
    print('version ' + str(versions))
    flexy_cell = '=HYPERLINK("' + str(flexy_url) + '","' + str(flexy_id) + '")'
    job_type = ""
    if scale_ci_job != "":
        job_type = scale_ci_job.split('/')[-3]
        if job_type == "job":
            job_type = scale_ci_job.split('/')[-2]
    ci_cell = '=HYPERLINK("'+str(scale_ci_job) + '","' + str(job_type) + '")'

    if len(versions) > 1:
        upgrade_path_cell = '=HYPERLINK("'+str(upgrade_job_url) + '","' + str(versions[1:]) + '")'
    else:
        upgrade_path_cell = '=HYPERLINK("' + str(upgrade_job_url) + '","' + str(versions) + '")'
    status_cell = '=HYPERLINK("' + str(loaded_upgrade_url) + '","' + str(status) + '")'
    tz = timezone('EST')

    worker_count = run("oc get nodes | grep worker | wc -l | xargs").strip()
    row = [flexy_cell, versions[0], worker_count, ci_cell, upgrade_path_cell, status_cell, str(datetime.now(tz))]
    ws.insert_row(row, index, "USER_ENTERED")

    worker_master = run("oc get nodes | grep worker | grep master|  wc -l | xargs").strip()
    sno = "no"
    if worker_master == "1":
        sno = "yes"

    last_version = versions[-1].split(".")
    print('last version ' + str(last_version))
    print('last version ' + str(last_version))
    row = [flexy_cell, versions[0], upgrade_path_cell, ci_cell, worker_count, status_cell, duration,scale, force,
           cloud_type, install_type, network_type, sno, str(datetime.now(tz))]
    row.extend(get_pod_latencies())
    upgrade_sheet = file.open_by_url(
        "https://docs.google.com/spreadsheets/d/1yqQxAxLcYEF-VHlQ_KDLs8NOFsRLb4R8V2UM9VFaRBI/edit?usp=sharing")
    ws_upgrade = upgrade_sheet.worksheet(str(last_version[0]) + "." + str(last_version[1]))
    ws_upgrade.insert_row(row, index, "USER_ENTERED")


#write_to_sheet("/Users/prubenda/.secrets/perf_sheet_service_account.json", "50396", "https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/paige-e2e-multibranch/job/cluster-density/126/", "https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/paige-e2e-multibranch/job/upgrade_test/180/", "https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/paige-e2e-multibranch/job/loaded-upgrade/167/console", "TEST", False, True)