#!/usr/bin/env python3

"""Logging index verification tool

This script is meant to help verify ElasticSearch indices after generating logs with logtest clusterloader.
It also has a lot of general helper functions for working with ElasticSearch.

To use this script, you should set up a route to ElasticSearch as described here:
https://docs.openshift.com/container-platform/4.1/logging/config/efk-logging-elasticsearch.html#efk-logging-elasticsearch-exposing_efk-logging-elasticsearch

This script uses python 3 and has Requests as an external dependency.
I recommend setting up a venv like so:

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

"""

import argparse
import json
import math
import os
import sys
import time

import requests
import urllib3

# https://urllib3.readthedocs.io/en/latest/advanced-usage.html#ssl-warnings
urllib3.disable_warnings()


class ElsHelper:

    def __init__(self, route, token, verbose=False):
        self.headers = {"Authorization": "Bearer {}".format(token)}
        if 'http' in route:
            # Assume we were passed route properly formatted already
            self.base_url = route
        else:
            self.base_url = "https://{}".format(route)
        self.verbose = verbose

    def custom_query(self, custom_endpoint: str):
        url = self.base_url + custom_endpoint
        r = requests.get(url, headers=self.headers, verify=False)
        r.raise_for_status()
        if 'json' in r.headers['content-type']:
            print(json.dumps(r.json(), indent=2))
        else:
            print(r.text)

    def print_health(self):
        endpoint = "/_cluster/health"
        url = self.base_url + endpoint
        r = requests.get(url, headers=self.headers, verify=False)
        r.raise_for_status()
        print(json.dumps(r.json(), indent=2))
        return

    def print_indices(self):
        """
        Print ElasticSearch indices and exit.
        """
        # Putting the param in the endpoint here because why not
        endpoint = "/_cat/indices?v"
        url = self.base_url + endpoint
        r = requests.get(url, headers=self.headers, verify=False)
        r.raise_for_status()
        print(r.text)
        return

    def print_info(self):
        r = requests.get(self.base_url, headers=self.headers, verify=False)
        r.raise_for_status()
        print(r.text)
        return

    def print_nodes(self):
        endpoint = "/_cat/nodes?v&h=ip,m,disk.used_percent,disk.total,heap.percent,ram.percent,cpu,load_1m,load_5m"
        url = self.base_url + endpoint
        r = requests.get(url, headers=self.headers, verify=False)
        r.raise_for_status()
        print(r.text)
        return

    def get_index_doc_count(self, index):
        count_endpoint = "/{}/_count".format(index)
        count_request = requests.get(self.base_url + count_endpoint, headers=self.headers, verify=False)
        count_request.raise_for_status()
        index_count = count_request.json()["count"]
        return index_count

    def dump_index(self, index, output=None):
        """
        Uses ELS scroll search to dump an entire logtest index.
        If there are more than 10k results, then further API calls are made and those results are lumped into the ["hits"]["hits"] value of the first call.
        :type output: str
        :param index:
        """
        endpoint = "/{}/_search".format(index)
        url = self.base_url + endpoint
        params = {"scroll": "1m"}
        result_size = 10000
        data = {"sort": ["_doc"], "size": result_size}
        scroll_headers = {"Content-Type": "application/json"}
        scroll_headers.update(self.headers)

        # Initial request to _search endpoint
        r1 = requests.get(url, headers=scroll_headers, params=params, data=json.dumps(data), verify=False)
        r1.raise_for_status()
        r1_dict = r1.json()
        r1_ml: list = r1_dict["hits"]["hits"]

        total_hits = r1_dict['hits']['total']
        # To find the number of time we have to scroll.
        # Divide total results by result_size
        # Round up to nearest integer
        # Subtract 1 because we already pulled the first ${result_size} results in the first request
        # Provide result or 0 if it is negative
        num_of_scrolls = max(int(math.ceil((total_hits / result_size))) - 1, 0)
        if self.verbose:
            print("num of scrolls: {}".format(num_of_scrolls))

        # Get _scroll_id
        # Scroll requests hit generic _search/scroll endpoint
        scroll_id = r1_dict["_scroll_id"]
        scroll_endpoint = "/_search/scroll"
        scroll_url = self.base_url + scroll_endpoint
        data = {"scroll": "1m", "scroll_id": scroll_id}

        # Call scroll API til we have all results pushed into r1_dict
        for i in range(num_of_scrolls):
            if self.verbose:
                print("Current length of message list: {}".format(len(r1_ml)))
                print("Calling scroll endpoint: {}/{}".format(i + 1, num_of_scrolls))
                start = time.time()
            r_scroll = requests.get(scroll_url, headers=scroll_headers, data=json.dumps(data), verify=False)
            if self.verbose:
                end = time.time()
                print("Time taken for scroll request: {}".format(end - start))
            r_scroll.raise_for_status()
            r_scroll_dict = r_scroll.json()
            if self.verbose:
                print("Extending r1_ml with new messages")
            r1_ml.extend(r_scroll_dict["hits"]["hits"])

        # print("Dict obj size: {}".format(sys.getsizeof(json.dumps(r1_dict))))

        # If output is specified then output to file
        if output is not None:
            with open(output, 'w') as f:
                json.dump(r1_dict, f, indent=2)
        return r1_dict

    def index_generator(self, index):
        endpoint = "/{}/_search".format(index)
        url = self.base_url + endpoint
        params = {"scroll": "1m"}
        result_size = 10000
        data = {"sort": ["_doc"], "size": result_size}
        scroll_headers = {"Content-Type": "application/json"}
        scroll_headers.update(self.headers)
        scroll_endpoint = "/_search/scroll"
        scroll_url = self.base_url + scroll_endpoint
        scroll_id = None
        scroll_data = {"scroll": "1m", "scroll_id": scroll_id}

        # Get number of documents in the index
        index_count = self.get_index_doc_count(index)
        print("Index document count: {}".format(index_count))

        num_of_scrolls = max(int(math.ceil((index_count / result_size))), 1)
        if self.verbose:
            print("num scrolls: {}".format(num_of_scrolls))

        for i in range(num_of_scrolls):
            if i == 0:
                if self.verbose:
                    print("Making initial request to search endpoint")
                r = requests.get(url, headers=scroll_headers, params=params, data=json.dumps(data), verify=False)
                scroll_id = r.json()["_scroll_id"]
                scroll_data["scroll_id"] = scroll_id
                yield r.json()
            else:
                if self.verbose:
                    print("Requesting scroll enpoint")
                    scroll_start = time.time()
                    r = requests.get(scroll_url, headers=scroll_headers, data=json.dumps(scroll_data), verify=False)
                    print("Time taken: {}".format(time.time() - scroll_start))
                else:
                    r = requests.get(scroll_url, headers=scroll_headers, data=json.dumps(scroll_data), verify=False)
                yield r.json()

    def extract_message_list(self, r_json: dict):
        message_list = []
        for i in r_json["hits"]["hits"]:
            message_list.append(i["_source"]["message"])
        return message_list


def verify_els_message_stream(index_iter, max_expected):
    num_tracker = {i: 0 for i in range(1, max_expected + 1)}
    for i in index_iter:
        # Extract message list from JSON
        message_list = [message["_source"]["message"] for message in i["hits"]["hits"]]

        # Extract message numbers from message list lines
        for m in message_list:
            try:
                num = int(m.split()[9])
                # print(type(num))
                num_tracker[num] += 1
            except ValueError:
                print("ERROR: Couldn't parse number from log line. Got '{}'".format(m.split()[9]))
                print(m)

    # Output duplicates
    duplicates_found = 0
    for k, v in num_tracker.items():
        if v > 1:
            print("Duplicate: {} - Count: {}".format(k, v))
            duplicates_found += 1

    # Output missing
    missing_nums = [i for i in num_tracker if num_tracker[i] == 0]
    missing_found = len(missing_nums)
    missing_ranges = compute_ranges(missing_nums)
    for j in missing_ranges:
        print("Missing log line(s): {}".format(j))

    # Output summary
    if duplicates_found > 0:
        print("Duplicate numbers found: {}".format(duplicates_found))
    else:
        print("No duplicates found!")
    if missing_found > 0:
        print("Number of missing logs: {}".format(missing_found))
        print("{:.4f}% message loss rate".format(missing_found / max_expected * 100))
    else:
        print("No missing messages!")


def verify_els_messages(els_json: dict, max_expected):
    els_hits_total = els_json["hits"]["total"]
    print("ElasticSearch hits matching search query: {}".format(els_hits_total))

    hit_list = els_json["hits"]["hits"]
    print("Number of hits in this JSON body: {}".format(len(hit_list)))

    # Extract just message value from dict
    # Example log message:
    # 2019-06-19 18:56:25,359 - SVTLogger - INFO - centos-logtest-2cvbs : 1 : cviv9Fexf iJXjmkt5q 9OEE6ym79 gUFpysfap sseH7CIk4 DVbdIk4Bx YDNVPfhhk BVW5GRR6u O4zTsDm7x etc....
    message_list = [i["_source"]["message"] for i in hit_list]

    # Extract message number from message and sort resulting list
    # TODO: change this as splitting the message can be unreliable
    message_num_list = []
    for m in message_list:
        try:
            num = int(m.split()[9])
            message_num_list.append(num)
        except ValueError:
            print("ERROR: Couldn't parse number from log line. Got '{}'".format(m.split()[9]))
            print(m)
    message_num_list.sort()

    min_num = message_num_list[0]
    max_num = message_num_list[-1]
    print("Lowest number found: {}".format(min_num))
    print("Highest number found: {}".format(max_num))

    if max_expected is None:
        max_expected = max_num
        print(
            "WARNING: No max specified in command line, assuming expected maximum is the highest number found in the message list. "
            "This will throw off metrics if the expected max is higher than the max found in the message list")

    print("Expected max number: {}".format(max_expected))

    # Find number of occurrences for each number from min_num to max_num
    num_tracker = {i: 0 for i in range(1, max_expected + 1)}
    for i in message_num_list:
        num_tracker[i] += 1
    missing_nums = [i for i in num_tracker if num_tracker[i] == 0]
    missing_found = len(missing_nums)

    # Output duplicates
    duplicates_found = 0
    for k, v in num_tracker.items():
        if v > 1:
            print("Duplicate: {} - Count: {}".format(k, v))
            duplicates_found += 1

    # Output missing number ranges
    missing_ranges = compute_ranges(missing_nums)
    for i in missing_ranges:
        print("Missing log line(s): {}".format(i))

    # Output Summary
    if duplicates_found > 0:
        print("Duplicate numbers found: {}".format(duplicates_found))
    if missing_found > 0:
        print("Number of missing logs: {}".format(missing_found))
        print("{:.4f}% message loss rate".format(missing_found / max_expected * 100))


def compute_ranges(num_list):
    if len(num_list) == 0:
        return []
    if len(num_list) == 1:
        return [str(num_list[0])]
    result = []
    current_range = [num_list[0]]
    for i in num_list[1:]:
        if i == current_range[-1] + 1:
            current_range.append(i)
        else:
            if len(current_range) > 1:
                num_range = current_range[-1] - current_range[0] + 1
                result.append("{}-{} ({})".format(current_range[0], current_range[-1], num_range))
            elif len(current_range) == 1:
                result.append(str(current_range[0]))
            else:
                result.append(str(i))
            current_range = [i]
    if len(current_range) == 1:
        # Handle last number in num list being by itself
        result.append(str(current_range[0]))
    elif len(current_range) > 1:
        # handle case where all numbers in num_list are sequential
        num_range = current_range[-1] - current_range[0] + 1
        result.append("{}-{} ({})".format(current_range[0], current_range[-1], num_range))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--custom', help="Print output from given custom endpoint")
    parser.add_argument('--file', '-f', help='JSON file containing ELS search query results')
    parser.add_argument('--route', '-r', help='Route to ElasticSearch endpoint')
    parser.add_argument('--token', '-t', help='OAuth token to use if pulling data directly from the ElasticSearch endpoint')
    parser.add_argument('--max', '-m', type=int, help='Highest log message number expected. If you are expecting 60k logs then you should pass 60000')
    parser.add_argument('--index', '-i', help='ElasticSearch index to verify')
    parser.add_argument('--no-verify', action='store_true', help="Don't verify the index after grabbing all results. Requires --output be set")
    parser.add_argument('--output', '-o', help='Output ELS query results to a JSON file')
    parser.add_argument('--print-health', action='store_true', help="Just print ElasticSearch cluster health and exit")
    parser.add_argument('--print-indices', action='store_true', help='Just print ElasticSearch indices and exit')
    parser.add_argument('--print-info', action='store_true', help='Just print ElasticSearch cluster info (version info etc.) and exit')
    parser.add_argument('--print-nodes', action='store_true')
    parser.add_argument('--stream', action='store_true', help='Process messages in 10k chunks to reduce memory footprint. Disables ability to save index to a file.')
    parser.add_argument('--verbose', '-v', action='store_true', help='Set verbose logging.')

    args = parser.parse_args()

    if len(sys.argv) < 2:
        parser.print_usage()
        exit(1)

    # Handle read from file use-case
    if args.file is not None:
        filename = args.file
        with open(filename) as f:
            raw_json = json.load(f)
        verify_els_messages(raw_json, args.max)
    else:
        # For everything else we need a route and token set
        route = args.route or os.getenv('ELS_ROUTE')
        token = args.token or os.getenv('ELS_TOKEN')
        if route is None:
            print("Please provide route through CLI --route or export ELS_ROUTE")
            exit(1)
        if token is None:
            print("Please provide token through CLI --token or export ELS_TOKEN")
            exit(1)

        # Construct ElsHelper
        if args.verbose:
            es = ElsHelper(route, token, verbose=True)
        else:
            es = ElsHelper(route, token)

        # Handle --custom
        if args.custom:
            es.custom_query(args.custom)
            exit(0)

        # Handle --print-indices
        if args.print_indices is True:
            es.print_indices()
            exit(0)
        # Handle --print-health
        if args.print_health is True:
            es.print_health()
            exit(0)
        # Handle --print-info
        if args.print_info is True:
            es.print_info()
            exit(0)
        # Handle --print-nodes
        if args.print_nodes is True:
            es.print_nodes()
            exit(0)

        # Make sure --index is specified since all actions require index from this point on
        if args.index is None:
            print("Please provide index through CLI --index")
            print("You can print available indices with --print-indices")
            exit(1)
        if args.no_verify is True:
            if args.output is None:
                print("Must specify --output with --no-verify")
                exit(1)
        if args.stream is True:
            expected_max = args.max
            if args.max is None:
                print("WARNING: --max not specified, defaulting to # of docs in index: ", end="")
                expected_max = es.get_index_doc_count(args.index)
                print("{}".format(expected_max))
            verify_els_message_stream(es.index_generator(args.index), expected_max)
            es.index_generator(args.index)
            exit()
        print("Starting to dump index...")
        if args.verbose:
            dump_start = time.time()
            dump = es.dump_index(args.index, output=args.output)
            dump_end = time.time()
            print("Total time to dump index: {}".format(dump_end - dump_start))
        else:
            dump = es.dump_index(args.index, output=args.output)
        print("Done dumping index")
        if args.no_verify is False:
            verify_els_messages(dump, args.max)
