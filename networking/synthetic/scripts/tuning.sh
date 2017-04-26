#!/bin/sh

. /usr/lib/tuned/functions

start() {
    tuna -c22 -q p5p1 -m -x
    tuned-adm profile stac || exit 1
    # additional tuning necessary if using nohz_full:
    if grep -q nohz_full /proc/cmdline
    	then
    	for i in `pgrep rcu` ; do taskset -pc 0 $i ; done
    fi

    return "$?"
}

stop() {
    return 0
}

verify() {
    return 0
}

process $@
