#!/usr/bin/python
import argparse
import yaml

parser = argparse.ArgumentParser()
parser.add_argument('-u', '--urlfile', action="store", dest="urlfile")
parser.add_argument('-c', '--concurrency', action="store", \
		    dest="concurrency", default=100)
parser.add_argument('-r', '--ramp-up', action="store", dest="ramp_up",\
                    default='10s')
parser.add_argument('-d', '--hold_for', action="store", dest="hold_for",\
                    default='1m')
parser.add_argument('-s', '--scenario', action="store", dest="scenario",\
                    default='simple')
parser.add_argument('-o', '--out_yml_file', action="store",\
                    dest="out_yml_file", default='/tmp/bzt.yml')
parser.add_argument('-n', '--test_name', action="store", dest="test_name",\
                    default='OSE')
parser.add_argument('-p', '--prefix', action="store", dest="prefix",\
                    default='http://')
parser.add_argument('-f', '--stats_file', action="store", dest="stats_file",\
                    default='/tmp/taurus.csv')

results = parser.parse_args()

urlfile = results.urlfile
concurrency = int(results.concurrency)
ramp_up = str(results.ramp_up)
hold_for = str(results.hold_for)
scenario = str(results.scenario)
out_yml_file = str(results.out_yml_file)
test_name = str(results.test_name)
prefix = str(results.prefix)
stats_file = str(results.stats_file)

bzt_conf = dict()
bzt_conf['execution'] = []
bzt_conf['scenarios'] = {}
bzt_conf['reporting'] = []
bzt_conf['reporting'].append({'module': 'final_stats', 'dump-csv': stats_file})

bzt_conf['modules'] = {}

if scenario == "simple": 
	#Add executiona and scenarios
	count = 1
	with open(urlfile) as f:
	    for line in f:
		bzt_conf['execution'].append({'concurrency': concurrency, \
			'hold-for': hold_for, 'ramp-up': ramp_up,\
			'scenario': scenario+str(count)})
		bzt_conf['scenarios'][scenario+str(count)] = {'requests': [prefix + line.strip()]}
		count = count + 1

	# Added blazemeter module
	bzt_conf['modules']['blazemeter'] = {'browser-open': False, 'test': test_name }

	#Write the yaml file
	with open(out_yml_file, 'w') as yaml_file:
	       yaml_file.write("---\n")
	       yaml_file.write( yaml.dump(bzt_conf, default_flow_style=False))

if scenario == "key-value-put":
	#Add executiona and scenarios
	count = 1
	with open(urlfile) as f:
	    for line in f:
		bzt_conf['execution'].append({'concurrency': concurrency, \
			'hold-for': hold_for, 'ramp-up': ramp_up,\
			'scenario': scenario+str(count)})
		d = {'body': {'value': count},\
		     'method':'POST',\
		     'url':prefix + line.strip() + "/keys" + "/key" + str(count)}
		bzt_conf['scenarios'][scenario+str(count)] = {'requests' : [d]}
		count = count + 1

	# Added blazemeter module
	bzt_conf['modules']['blazemeter'] = {'browser-open': False, 'test': test_name }

	#Write the yaml file
	with open(out_yml_file, 'w') as yaml_file:
	       yaml_file.write("---\n")
	       yaml_file.write( yaml.dump(bzt_conf, default_flow_style=False))

if scenario == "key-value-get":
	#Add executiona and scenarios
	count = 1
	with open(urlfile) as f:
	    for line in f:
		bzt_conf['execution'].append({'concurrency': concurrency, \
			'hold-for': hold_for, 'ramp-up': ramp_up,\
			'scenario': scenario+str(count)})
		d ={ 'method':'GET',\
		     'url':prefix + line.strip() + "/keys" + "/key" + str(count)}
		bzt_conf['scenarios'][scenario+str(count)] = {'requests' : [d]}
		count = count + 1

	# Added blazemeter module
	bzt_conf['modules']['blazemeter'] = {'browser-open': False, 'test': test_name }

	#Write the yaml file
	with open(out_yml_file, 'w') as yaml_file:
	       yaml_file.write("---\n")
	       yaml_file.write( yaml.dump(bzt_conf, default_flow_style=False))
