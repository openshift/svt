#!/usr/bin/env python3

import argparse
import os
import json
from elasticsearch import Elasticsearch


class DumpKibana(Elasticsearch):
    def __init__(self, url):
        super().__init__()
        self.es = Elasticsearch(url)
        self.res = None

    def search_doc(self, index, doc_type):
        self.res = self.es.search(
            index=index,
            doc_type=doc_type,
            size=1000)

    def dump_json(self, parent_dir, type_):
        dir_ = os.path.join(parent_dir, type_)
        if not os.path.exists(dir_):
            os.makedirs(dir_)

        for doc in self.res['hits']['hits']:
            filepath = os.path.join(dir_, doc['_id'] + '.json')
            with open(filepath, 'w') as f:
                json.dump(doc['_source'], f, indent=2)
                print("Written {}".format(filepath))


def get_parser():
    parser = argparse.ArgumentParser(
        description="Retrieves ES objects in json file output")
    parser.add_argument("--url", help="Elasticsearch URL. E.g. " +
                                      "http://localhost:9200", required=True)
    parser.add_argument("--index", help="Index to query. Defaults to .kibana", default=".kibana")
    parser.add_argument("--dir", help="Output directory. Defaults to \"saved\"", default="saved")
    return parser.parse_args()


def main():
    # python3 DumpKibana.py --url 'http://host76:9200' --dir saved_poc
    args = get_parser()
    es = DumpKibana(args.url)
    types = ("search", "visualization", "dashboard")
    for t in types:
        es.search_doc(args.index, t)
        es.dump_json(args.dir, t)


if __name__ == "__main__":
    main()
