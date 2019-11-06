from optparse import OptionParser
from subprocess import check_output, STDOUT
import re
from time import time


ns_match = re.compile("(\S+?)\s+(.*)")
def run(cmd, config=""):

    if config:
        cmd = "KUBECONFIG=" + config + " " + cmd
    result = check_output(cmd, stderr=STDOUT, shell=True)
    return result

def get_namespace_param(namespace):
    if namespace == "":
        namespace_param = ""
    elif namespace == "all-namespaces":
        namespace_param = " --all-namespaces"
    else:
        namespace_param = " -n " + namespace
    return namespace_param

def get_all(type, namespace):
    namespace_param = get_namespace_param(namespace)
    result = run("oc get --ignore-not-found --no-headers " + type + namespace_param ) 
    return result.splitlines()

def get_crd_list(scope):
    scope_flag = ""
    if scope != "all":
        scope_flag = "| grep -i " + scope
    result = run("oc get crd --no-headers -o=custom-columns=NAME:.metadata.name,SCOPE:.spec.scope " + scope_flag)
    return result.splitlines()
    

def get_all_api_resources(scope):
    scope_flag = ""
    if scope == "namespaced":
        scope_flag = "--namespaced=true"
    elif scope == "cluster":
        scope_flag = "--namespaced=false"
    result = run("oc api-resources --verbs=list -o name " + scope_flag)
    return result.splitlines()

def get_all_items(all_types, namespace):
    type_items = {}
    for this_type in all_types:
        result = []
        start_time = time()
        # temporary black list
        if this_type != "packagemanifests.packages.operators.coreos.com":
            result = get_all(this_type, namespace)
        elapsed_time = time() - start_time
        type_items[this_type] = []
        if options.verbose:
            print(this_type + ": " + str(elapsed_time))
        if len(result) > 0:
            for this_result in result:
                this_item={}
                if namespace == "all-namespaces":
                    m = ns_match.match(this_result)
                    this_item["namespace"] = m.group(1)
                    this_item["value"] = m.group(2)
                else:
                    this_item["namespace"] = namespace
                    this_item["value"] = this_result
                type_items[this_type].append(this_item)
    return(type_items)

# def adjust_for_scope

def print_items(all_items):
    all_types = list(all_items.keys())
    for this_type in all_types:
        if options.output == "list":    
            print("\n\n===============")
            print("TYPE: " + this_type)
            for this_item in all_items[this_type]:
                print("\t" + this_item["namespace"] + ": " + this_item["value"])
        elif options.output == "ns-count":
            ns_count = {}
            for this_item in all_items[this_type]:
                ns = this_item["namespace"]
                if ns in ns_count:
                    ns_count[ns] += 1
                else:
                    ns_count[ns] = 1
            print("\n\n===============")
            print("TYPE: " + this_type)
            for this_ns in ns_count:
                print("\t" + this_ns + ": " + str(ns_count[this_ns]) )
        else:
            count = len(all_items[this_type])
            print(this_type + ": " + str(count))



if __name__ == "__main__":

    parser = OptionParser()
    parser.add_option("-n", "--namespace", dest="namespace", default="",
                        help="namespace to retrieve from")
    parser.add_option("-t", "--type", dest="type", default="all",
                        help="type of items to retrieve - cannot use with -c")
    parser.add_option("-c", "--crd", dest="crd", action="store_true", default=False,
                        help="retrieve all CRDs from a namespace (or all namespaces) - cannot use with -t")
    parser.add_option("-s", "--scope", dest="scope", default="all",
                        help="namespaced, cluster or all (default)")
    parser.add_option("-v", "--verbose", dest="verbose", action="store_true", default=False)
    parser.add_option("-o", "--output", dest="output", default="list", help="output type: list or count or ns_count")


    (options, args) = parser.parse_args()

    type_list = []
    if options.crd:
        crd_type_result = get_crd_list(options.scope)
        for crd_type in crd_type_result:
            crd_type = crd_type.split(" ",1)[0]
            type_list.append(crd_type)
    else:
        if options.type == "all":
            type_list = get_all_api_resources(options.scope)
        else:
            type_list.append(options.type)
    
    items = get_all_items(type_list,options.namespace)
    print_items(items)  
        

    
    
    
