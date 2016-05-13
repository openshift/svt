ose3name: ose3-master.example.com
ipaddress10ge: xx.xx.10.44

network_ether_interfaces:
  - device: ens2f1
    address: xx.xx.10.44
    netmask: 255.255.255.0
    bootproto: static
    stp: "off"
