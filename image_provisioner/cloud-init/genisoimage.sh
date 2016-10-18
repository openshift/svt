#!/bin/sh
sudo yum install -y genisoimage
genisoimage -output cidata.iso -volid cidata -joliet -rock user-data meta-data
