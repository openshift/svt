#!/usr/bin/env python3

import csv
import glob
import os
import argparse


def parser():
    parser_obj = argparse.ArgumentParser()
    parser_obj.add_argument('-d', '--working_dir', dest="working_dir", required=True)
    parser_obj.add_argument('-o', '--out_dir', dest="out_dir", default='header_removed')
    parser_obj.add_argument('-w', '--wildcard', dest="wildcard", type=str, default='*.csv')

    return parser_obj.parse_args()


def remove_headers(dir_, outdir_, pattern):
    """
    reads a set set of csv files from dirA and writes them to dirB, without the headers.

    :param dir_:
    :param outdir_:
    :param pattern:
    :return:
    """
    wd = os.getcwd()
    os.chdir(dir_)
    for csvfile in glob.glob(pattern):
        print('Removing header from ' + csvfile + '...')

        rows = []
        fileobj = open(csvfile)
        reader = csv.reader(fileobj)
        # read, but skip the first row
        [rows.append(row) for row in reader if reader.line_num != 1]
        fileobj.close()

        # write the header-less CSV files
        os.makedirs(outdir_, exist_ok=True)
        fileobj = open(os.path.join(outdir_, csvfile), 'w', newline='')
        writer = csv.writer(fileobj)
        [writer.writerow(row) for row in rows]
        fileobj.close()
        os.chdir(wd)

if __name__ == '__main__':
    opts = parser()
    remove_headers(opts.working_dir, opts.out_dir, opts.wildcard)
