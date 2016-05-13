ose3name: ose3-master.example.com
ipaddress10ge: xx.xx.10.22

network_ether_interfaces:
  - device: p1p1
    address: xx.xx.10.22
    netmask: 255.255.255.0
    bootproto: static
    stp: "off"
