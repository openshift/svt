import pandas as pd
from typing import *
import argparse
import os


def get_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Process CSVs")
    parser.add_argument(
        "-c",
        "--csv-list",
        nargs="+",
        default=[],
        help="list of CSV filepaths",
        required=True,
    )
    parser.add_argument(
        "-o", "--output", type=str, default=None, help="Output filepath"
    )
    parser.add_argument(
        "-m",
        "--mode",
        choices=["a", "w"],
        type=str.lower,
        default="a",
        help="Mode a: append, w: create new output file",
    )

    args = parser.parse_args()
    return args


def read_csv(filepath: str) -> pd.DataFrame:
    if os.path.exists(filepath):
        try: 
            df = pd.read_csv(filepath)
            return df
        except Exception as e: 
            print(f"Error reading csv file {filepath} : {e}")
            df = pd.DataFrame()
    else: 
        # set empty data frame
        df = pd.DataFrame()
    return df


def divide_col(x: float) -> float:
    div_by = os.environ.get("div_by", 1)
    try: 
        return round(x / float((div_by)), 3)
    except:
        return x


def write_df(df: pd.DataFrame, target_filepath: str, mode: str = "a"):
    df.to_csv(target_filepath, mode=mode, index=False)


def main():
    args = get_args()
    mode = args.mode
    output_filepath = args.output
    for csv_filepath in args.csv_list:
        df = read_csv(csv_filepath)
        if not df.empty: 
            num_rows = len(df.index)
            num_columns = len(df.columns)
            if num_rows > 0:
                select_columns = -1
                if "ES_SERVER_BASELINE" in os.environ and "BASELINE_UUID" in os.environ:
                    select_columns = -2
                if ("SORT_BY_VALUE" in os.environ) and (os.getenv("SORT_BY_VALUE") == "true"):
                    df.sort_values(df.columns[-1], ascending=False, inplace=True)
                df[df.columns[select_columns:num_columns]] = df[
                    df.columns[select_columns:num_columns]
                ].apply(divide_col)
                output_filepath = output_filepath or f"{df.columns[-1]}.csv"
            write_df(
                df.head(int(os.environ.get("NUM_LINES", num_rows))), output_filepath, mode
            )


main()