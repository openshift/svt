from check_upgrade import invoke 
import requests
from lxml import html

def get_z_streams():

    z_steams = {}
    response_req = html.fromstring(requests.get("https://openshift-release.apps.ci.l2s4.p1.openshiftapps.com/").content)
    max = 10 #(4.10 )
    min = 1
    for i in range(min, max + 1):
        z_steams['4.' + str(i)] = {}
        z_version = response_req.xpath("(//h2[@title='From image stream ocp/release']/following-sibling::table//tr//a[@class='text-success' and starts-with(.,4."+ str(i) + ")])[1]/text()")
        z_steams['4.' + str(i)]['z_stream'] = z_version[0]
        latest_nightly_version = response_req.xpath(
            "(//h2[@title='From image stream ocp/release']/following-sibling::table//tr//a[@class='text-success' and starts-with(.,'4."+ str(i) + ".0-0.nightly')])[1]/text()")
        z_steams['4.' + str(i)]['nightlies'] = latest_nightly_version[0]
    print(z_steams)
    return z_steams


def get_upgrade_path(cur_version, z_dict, count_back):

    #this only works because the z_dict is ordered
    counter_num = 0
    uprade_list = []
    start_count = False
    for k,v in reversed(z_dict.items()):
        if start_count:
            if counter_num < count_back:
                uprade_list.insert(0,v['z_stream'])
                counter_num += 1

        elif k == cur_version:
            start_count = True

        if counter_num >= count_back:
            break

    uprade_list = ','.join(uprade_list)
    print('first ' + str(uprade_list))

    return uprade_list

def get_wanted_versions(ocp_version, count_back):

    version_dict = get_z_streams()

    if "night" in ocp_version:
        ocp_version_list = ocp_version.split(" ")
        install_version = version_dict[ocp_version_list[0]]['nightlies']
        print('install version ' + str(install_version))
        upgrade_list_str = get_upgrade_path(ocp_version_list[0], version_dict, count_back)
    else:
        install_version = version_dict[ocp_version]['z_stream']
        print('install version ' + str(install_version))
        upgrade_list_str = get_upgrade_path(ocp_version, version_dict, count_back)

    print('install version ' + str(install_version))
    # return ocp version and upgrade list
    return install_version, upgrade_list_str


#get_z_streams()
#get_wanted_versions("4.9", 2)