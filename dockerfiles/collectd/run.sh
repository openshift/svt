#!/bin/bash

# bind mount
mount -o bind /proc_host /proc

sed -i "/graphite_host/c \ \ \ \ Host \"${graphite_host}\"" /etc/collectd.conf
sed -i "/graphite_prefix/c \ \ \ \ Prefix \"${graphite_prefix}.\"" /etc/collectd.conf
sed -i "/^Interval/c Interval "${collectd_interval}"" /etc/collectd.conf

# run collectd
/usr/sbin/collectd -f
