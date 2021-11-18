from oauth2client.service_account import ServiceAccountCredentials
import gspread
from datetime import datetime
from pytz import timezone
import write_helper

def write_to_sheet(google_sheet_account, flexy_id, job_url, status, scale, force):
    scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive'
    ]
    credentials = ServiceAccountCredentials.from_json_keyfile_name(google_sheet_account, scopes) #access the json key you downloaded earlier
    file = gspread.authorize(credentials) # authenticate the JSON key with gspread
    #sheet = file.open("Test") #.Outputs
    sheet = file.open_by_url("https://docs.google.com/spreadsheets/d/1uiKGYQyZ7jxchZRU77lsINpa23HhrFWjphsqGjTD-u4/edit?usp=sharing")
    #open sheet

    index = 2
    flexy_url ="https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/ocp-common/job/Flexy-install/" + str(flexy_id)
    flexy_cell = '=HYPERLINK("' + str(flexy_url) + '","' + str(flexy_id) + '")'

    cloud_type, install_type, network_type = write_helper.flexy_install_type(flexy_url)

    duration, all_versions = write_helper.get_upgrade_duration()
    ci_cell = '=HYPERLINK("' + str(job_url) + '","' + str(all_versions[1:]) + '")'
    tz = timezone('EST')
    worker_count = write_helper.run("oc get nodes | grep worker | wc -l | xargs").strip()

    worker_master = write_helper.run("oc get nodes | grep worker | grep master|  wc -l | xargs").strip()
    sno = "no"
    if worker_master == "1":
        sno = "yes"

    last_version = all_versions[-1].split(".")
    print('last version ' + str(last_version))
    print('last version ' + str(last_version))
    row = [flexy_cell, all_versions[0], ci_cell, worker_count, status, duration, scale, force, cloud_type, install_type, network_type, sno, str(datetime.now(tz))]

    ws = sheet.worksheet("Upgrade Output")
    ws.insert_row(row, index, "USER_ENTERED")
