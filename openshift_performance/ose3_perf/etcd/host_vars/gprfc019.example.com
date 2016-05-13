ose3name: gprfc019
ipaddress10ge: xx.xx.10.19
interface1g: em1

network_ether_interfaces:
  - device: p1p1
    address: xx.xx.10.19
    netmask: 255.255.255.0
    bootproto: static
    stp: "off"
