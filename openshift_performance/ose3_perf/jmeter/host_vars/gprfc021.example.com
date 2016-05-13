ose3name: ose3-node1.example.com
ipaddress10ge: xx.xx.10.21

network_ether_interfaces:
  - device: p1p1
    address: xx.xx.10.21
    netmask: 255.255.255.0
    bootproto: static
    stp: "off"
