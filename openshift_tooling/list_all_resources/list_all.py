from optparse import OptionParser
from subprocess import check_output, STDOUT
from time import time

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
        result = get_all(this_type, namespace)
        elapsed_time = time() - start_time
        if options.verbose:
            print(this_type + ": " + str(elapsed_time))
        if len(result) > 0:
            type_items[this_type] = result
    return(type_items)

# def adjust_for_scope

def print_items(all_items):
    all_types = list(all_items.keys())
    for this_type in all_types:
        print("\n\n===============")
        print("TYPE: " + this_type)
        for this_item in all_items[this_type]:
            print("\t" + this_item)



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
        

    
    
    
