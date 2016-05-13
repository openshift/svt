#!/usr/bin/env python

import boto3
import time  
import rbd 
import rados 


# Amazon EC2 image creation and reservation 

def ec2_volume(ebsvolumesize,ebsvtype,ebstagprefix,ebsregion):

    ec2 = boto3.resource("ec2")
    ebsvolume = ec2.create_volume(VolumeType=ebsvtype,
    	AvailabilityZone=ebsregion,Size=ebsvolumesize)
    ebsvolumeid = ebsvolume.id
    print ("Sleep 10 seconds before tagging volume we just created:", ebsvolumeid)
    # sleep 10sec  - ...  http://docs.aws.amazon.com/AWSEC2/latest/APIReference/query-api-troubleshooting.html#api-request-rate 
    time.sleep(10)

    tags = ec2.create_tags(DryRun=False, Resources=[ebsvolume.id],
    	Tags=[{'Key': ebstagprefix + ebsvolume.id,
    	'Value': ebstagprefix
    	},
    	])
    return ebsvolumeid 

# ceph images creation , it will take cephpool, imagename, and cephimagesize  
def ceph_volume(cephpool,cephimagename,cephimagesize):    
    
    """
    create ceph cluster handle
    defaults : user=admin, conffile=/etc/ceph/ceph.conf
    """
    try:
        cluster = rados.Rados(conffile="/etc/ceph/ceph.conf")
        cluster.connect()
    except Exception as e:
        print ("Not possible to connect to ceph cluster")
        raise
    print ("Connected")
    """
    Create desired number of images - these will be used by pods
    """ 
    iocntx = cluster.open_ioctx(cephpool)
    rbd_ins = rbd.RBD()
    try:
        rbd_ins.create(iocntx, cephimagename, cephimagesize)
    except Exception as e: 
        print ("image with", cephimagename, "exist, not creating again")
# gluster configuration 

# nfs configuration 

