from oauth2client.service_account import ServiceAccountCredentials
import gspread
import json
import subprocess
import datetime
import calendar

def run(command):
    try:
        output = subprocess.check_output(command, shell=True,
                                         universal_newlines=True)
    except Exception as e:
        print("Failed to run %s" % (command))
        print("Error %s" % (str(e)))
        return ""
    return output


def get_sheet_info(google_sheet_account):
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

    row_vals = ws.row_values(2)
    print('row vals '+ str(row_vals))
    print('type ' + str(type(row_vals)))
    #row vals ['Initial Version', 'Test Types', 'Num Worker Node ', 'Upgrade Path', 'Cloud', 'Network Type', 'Install Type']


    #ws.cell(1, 1).value
get_sheet_info('/Users/prubenda/.secrets/perf_sheet_service_account.json')


# get items from google sheet

#randomly select line of installation

# get specific version of ocp start version

# run 1 version of n-1

# run 1 version of n-2

# run 1 version of n-3

