#!/bin/bash
### bash library file for master node

### get value of the first key in master-config file
function get_first(){
  printf "$(grep -i "${1}" /etc/origin/master/master-config.yaml | head -n 1 | awk '{print $2}' | tr -d '"')"
}

### get ose image version
function get_image_version(){
  printf "$(docker images | grep ose | head -n 1 | awk '{print $2}')"
}

### get host ip
### the function is only tested on ec2 host
function get_ip(){
  printf "$(hostname -i)"
}
