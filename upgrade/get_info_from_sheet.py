from oauth2client.service_account import ServiceAccountCredentials
import gspread
import json
import subprocess
from datetime import datetime,date
import calendar
from pytz import timezone
from get_latest_release import get_wanted_versions

google_sheet="https://docs.google.com/spreadsheets/d/1uiKGYQyZ7jxchZRU77lsINpa23HhrFWjphsqGjTD-u4/edit?usp=sharing"

def get_info_from_sheet(google_sheet_account):
    scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive'
    ]
    credentials = ServiceAccountCredentials.from_json_keyfile_name(google_sheet_account, scopes) #access the json key you downloaded earlier
    file = gspread.authorize(credentials) # authenticate the JSON key with gspread
    #sheet = file.open("Test") #.Outputs
    sheet = file.open_by_url("https://docs.google.com/spreadsheets/d/1uiKGYQyZ7jxchZRU77lsINpa23HhrFWjphsqGjTD-u4/edit?usp=sharing")
    #open sheet

    ws = sheet.worksheet("Inputs")

    all_values = ws.get_all_values()
    print(all_values)
    all_values_length = len(all_values)
    upgrades = get_upgrades_to_run(all_values)
    return upgrades

def get_upgrades_to_run(all_values):
    upgrades_to_run = []
    today = date.today()
    first_row = True
    for val_list in all_values:
        if first_row:
            first_row = False
            continue

        #get list of items that is during the dates range
        dates_list = val_list[0].split('-')
        first_date = datetime.strptime(dates_list[0], '%m/%d').date().replace(year=today.year)


        second_date =datetime.strptime(dates_list[-1], '%m/%d').date().replace(year=today.year)

        print('first date ' + str(first_date))
        print('second_dat ' + str(second_date))
        if first_date <= today <= second_date:
            upgrades_to_run.append(val_list)

    print("ugrades to run " + str(upgrades_to_run))
    return upgrades_to_run

def main_func(google_sheet_account):
    upgrades = get_info_from_sheet(google_sheet_account)
    up = upgrades[0]
    #call get latest relase based on worker count and general
    install_version, upgrade_list_str = get_wanted_versions(up[1], up[2])
    #return ocp version, upgrade list, install types (cloud,network,install type)
    return install_version, upgrade_list_str, up

#main_func("/Users/prubenda/.secrets/perf_sheet_service_account.json")