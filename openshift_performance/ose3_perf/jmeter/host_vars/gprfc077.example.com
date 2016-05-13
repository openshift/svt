ose3name: jmeter.example.com
ipaddress10ge: xx.xx.10.77

network_ether_interfaces:
  - device: p3p1
    address: xx.xx.10.77
    netmask: 255.255.255.0
    bootproto: static
    stp: "off"
