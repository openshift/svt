import os
import subprocess
import sys
import argparse

# TODO: Do not rely on curl. 
# Use requests 

"""
 saved
    |
    -- {dashboard,visualization,search}/*.json
"""


def get_parser():
    parser = argparse.ArgumentParser(
        description="Loads (HTTP PUT) ES json objects into a specified Elasticsearch instance")
    parser.add_argument("--url", help="Elasticsearch URL. E.g. http://localhost:9200.",
                        default="http://gprfc076.sbu.lab.eng.bos.redhat.com:9200")
    parser.add_argument("--index", help="Destination index. Defaults to .kibana", default=".kibana")
    parser.add_argument("--path", help="Directory path with .json objects. Defaults to \"saved\"", default="saved")

    return parser.parse_args()


def enumerate_paths(path):
    """Returns the path to all the files in a directory recursively
    :param path:
    """
    path_collection = []
    for dirpath, dirnames, filenames in os.walk(path):
        for f in filenames:
            fullpath = os.path.join(dirpath, f)
            path_collection.append(fullpath)

    return path_collection


if __name__ == '__main__':
    args = get_parser()

    if not os.path.exists(args.path):
        print('Directory does not exist. Exiting.')
        sys.exit(-1)

    for file in (enumerate_paths(args.path)):
        basename, extension = os.path.splitext(file)
        print("\nLoading {}".format(basename))
        esurl = '/'.join((args.url, args.index, basename.split('/')[1], basename.split('/')[2]))

        subprocess.check_call(["curl", "-iX", "PUT", esurl, "-d@{}".format(file)])
