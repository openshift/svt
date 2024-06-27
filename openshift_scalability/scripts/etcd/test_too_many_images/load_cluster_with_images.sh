#!/bin/bash

#################################################
# Author: skordas@redhat.com
# Related Test Case: OCP-69210
#
# Description:
# Script to support loading cluster with large
# number of images.
# ###############################################

START=$(date)

for i in {1..120000}
  do sh load_image.sh $i &
done

END=$(date)
sleep 5 # Some time to finish all images to be created.
echo "Start: $START"
echo "End  : $END" 
