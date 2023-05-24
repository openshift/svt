#!/usr/bin/env python3

import argparse
from oauth2client.service_account import ServiceAccountCredentials
import gspread
import os

def push_to_gsheet(sheetname, csv_file_name, google_svc_acc_key, email_id):
    scope = [
        "https://spreadsheets.google.com/feeds",
        "https://www.googleapis.com/auth/drive",
    ]
    credentials = ServiceAccountCredentials.from_json_keyfile_name(google_svc_acc_key, scope)
    gc = gspread.authorize(credentials)
    sh = gc.create(sheetname)  # Specify name of the Spreadsheet
    sh.share(email_id, perm_type="user", role="writer")
    spreadsheet_id = sh.id
    spreadsheet_url = f"https://docs.google.com/spreadsheets/d/{sh.id}"
    if not os.path.exists(csv_file_name):
      print(f"CSV File doesn't exist {csv_file_name}")
      return 
    with open(csv_file_name, "r") as f:
        gc.import_csv(spreadsheet_id, f.read())
    worksheet = sh.get_worksheet(0)
    fit_to_data_body = {
      "requests": [
        {
          "setBasicFilter": {
            "filter": {
              "range": {
                "sheetId": worksheet.id,
              }
            }
          }
        },
        {
          "autoResizeDimensions": {
            "dimensions": {
              "sheetId": worksheet.id,
              "dimension": "COLUMNS"
            }
          }
        }
      ]
    }
    sh.batch_update(fit_to_data_body)
    print(f"************** Google Spreadsheet link ---> {spreadsheet_url} ***************")


# Main
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--sheetname",
        help="Google Spreadsheet name",
        required=True
    )
    parser.add_argument(
        "-c",
        "--csv",
        help="CSV file to import",
        required=True,
        dest="csv",
    )
    parser.add_argument(
        "--email",
        help="service account email",
        required=True,
    )
    parser.add_argument(
        "--service-account",
        help="Google service account file",
        required=True,
    )
    args = parser.parse_args()
    push_to_gsheet(args.sheetname, args.csv, args.service_account, args.email)
