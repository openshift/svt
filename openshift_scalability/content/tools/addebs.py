#!/usr/bin/env python 

# program to create EBS Amazon EC2 volumes and attach to instance
# License GPL2/3 

__author__ = "elko"

import argparse
import boto3
import botocore
import logging
import string
import time
import urllib2

class CreateEbs():
	
	def __init__(self):
		
		print("Create EBS volume and attach to ec2 instance")
	
	def ec2_volume(self, volumesize, vtype, region, tagprefix, num):
		
		self.volumesize = volumesize
		self.vtype = vtype
		self.region = region
		self.tagprefix = tagprefix
		self.num = num
		
		logging.basicConfig(filename='create.log', level=logging.INFO,
							format='%(message)s')  # , format='%(asctime)s %(message)s')
		
		formatter = logging.Formatter('%(message)s')
		
		# ebs logger create
		ebs_logger = logging.getLogger('ebslogger')
		ebsh = logging.FileHandler('ebscreate.log')
		ebsh.setFormatter(formatter)
		ebs_logger.addHandler(ebsh)
		
		# ebs logger tag
		ebs_logger_tag = logging.getLogger('ebstaglogger')
		hdlr_tag = logging.FileHandler('ebstag.log')
		hdlr_tag.setFormatter(formatter)
		ebs_logger_tag.addHandler(hdlr_tag)
		
		ebs_attach = logging.getLogger('ebs_attach')
		ebs_tag = logging.FileHandler('ebs_attach.log')
		ebs_tag.setFormatter(formatter)
		ebs_attach.addHandler(ebs_tag)
		
		global tags
		global volumeid
		while True:
			try:
				ec2 = boto3.resource("ec2")
				vc_start = time.time()
				volume = ec2.create_volume(VolumeType=vtype,
										   AvailabilityZone=region,
										   Size=volumesize)
				vc_stop = time.time()
				volumeid = volume.id
				ebs_logger.info('%s, %s, %s', "ebs_volume_created", volume.id, vc_stop - vc_start)
			except botocore.exceptions.ClientError as err:
				print(err)
				# if this exception happens... we do not care ... volume will not be created and that is ....
				continue
			try:
				tag_start = time.time()
				tags = ec2.create_tags(DryRun=False, Resources=[volumeid],
									   Tags=[{'Key': tagprefix + volumeid, 'Value': tagprefix}, ])
				tag_end = time.time()
				ebs_logger_tag.info('%s, %s, %s', "ebs_volume_tagged", volume.id, tag_end - tag_start)
			except botocore.exceptions.ClientError as err:
				print("exception happended in tagging block ... we will sleep 5 sec ...and try again to tag it again",
					  err.response['Error']['Code'])
				time.sleep(5)
				continue
			else:
				print("volume", volumeid, "tagged in ", tag_end - tag_start)
			
			# get instance ID from where the script is executed
			# todo - make instance id as an input option
			
			getinsturl = urllib2.urlopen('http://169.254.169.254/latest/meta-data/instance-id')
			instanceid = getinsturl.read()
			instance = ec2.Instance(id=instanceid)
			
			volume = ec2.Volume(volumeid)
			volumestate = volume.state
			
			# volume states can be ['creating','in-use','deleting','deleted','error', 'available']:
			# it must be 'available' before we can attach it to instance
			while (volumestate != 'available'):
				time.sleep(1)
				volume = ec2.Volume(volumeid)
				volumestate = volume.state
			try:
				if not base:
					# cover /dev/xvda-/dev/xvdz case - taking into consideration that /dev/xvda and /dev/xvdb are not allocatable
					device = string.lowercase[int(num + 2):int(num + 3)]
					instance.attach_volume(VolumeId=volumeid, InstanceId=instanceid,
												   Device=str("/dev/") + str("xvd") + str(device))
					ebs_attach.info('%s, %s', "device attached", str("/dev/") + str("xvd") + str(device))
				else:
					# for other cases we assume that all device names can be allocated
					device = string.lowercase[int(num):int(num + 1)]
					instance.attach_volume(VolumeId=volumeid, InstanceId=instanceid,
										   Device=str("/dev/") + str("xvd") + str(base) + str(device))
					ebs_attach.info('%s, %s', "device attached", str("/dev/") + str("xvd") + str(base) + str(device))
			
			except botocore.exceptions.ClientError  as err:
					print("Exception in attaching device...", err.response['Error']['Code'])
			else:
					print("Volume", volumeid, "attached to instance", instanceid)
			break


if __name__ == "__main__":
	
	parser = argparse.ArgumentParser(
		description="Script to create EBS volumes and attach them to ec2 instance from where this script is run")
	parser.add_argument("--volumesize", help="size of EBS volume - in GB ", default=1, type=int)
	parser.add_argument("--vtype", help="EBS volume type, default is gp2", default="gp2")
	parser.add_argument("--region", help="Amazon region - will be ignored and defaults taken if aws configure was ran", default="us-west-2b")
	parser.add_argument("--tagprefix",
						help="tag prefix for EBS volumes, default tag is openshift-testing-EBS_volume_id",
						default="openshift-testing")
	parser.add_argument("--num", help="How many EBS volumes, max is 26 devices, eg, devices will be /dev/xvdba-/dev/xvdbz,"
									  "different sets are possible /dev/xvdb, /dev/xvdc... ",
						required=True)
	parser.add_argument("--base",
						help="in which range to start adding device, base can be b,c,d ... , eg /dev/xvdba-/dev/xvdbz "
							 "and here is base which to use /dev/xvdb, same for /dev/xvdc... etc", type=str)
	
	args = parser.parse_args()
	volumesize = args.volumesize
	vtype = args.vtype
	region = args.region
	tagprefix = args.tagprefix
	num = args.num
	base = args.base
	
	create_ebs = CreateEbs()
	for num in range(0, int(num)):
		create_ebs.ec2_volume(volumesize, vtype, region, tagprefix, num)
