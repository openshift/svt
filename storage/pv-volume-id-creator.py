#!/usr/bin/env python

from clusterloaderstorage import *

global ebsvolumeid
ebsvolumeid = ec2_volume(1,"gp2","ebs-fio","us-west-2b")
