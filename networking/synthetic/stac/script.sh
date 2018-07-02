#!/bin/sh

numa_cores=<range>
mtu_size="1800"

start() {
    ethtool -C <benchmark_interface> rx-usecs-irq 0 adaptive-rx off
    sfcirqaffinity <benchmark_interface> -c $numa_cores
    tuna -C -c$numa_cores -q '<benchmark_interface>*' -m
    ip link set <benchmark_interface> mtu $mtu_size
    tuna -C -c$numa_cores -q 'em1*' -m
    for i in \
        NetworkManager-wait-online.service \
        NetworkManager-dispatcher.service   \
        plymouth-read-write.service   \
        plymouth-quit-wait.service \
        plymouth-poweroff.service  \
        systemd-bootchart.service  \
        blk-availability.service   \
        abrt-pstoreoops.service \
        plymouth-reboot.service \
        rhel-domainname.service \
        NetworkManager.service  \
        plymouth-kexec.service  \
        plymouth-start.service  \
        wpa_supplicant.service  \
        console-shell.service   \
        plymouth-halt.service   \
        plymouth-quit.service   \
        ctrl-alt-del.target  \
        debug-shell.service  \
        nfs-rquotad.service  \
        rpc-rquotad.service  \
        arp-ethers.service   \
        irqbalance.service   \
        nfs-blkmap.service   \
        nfs-server.service   \
        rhel-dmesg.service   \
        rhsm-facts.service   \
        firewalld.service \
        iprupdate.service \
        cgconfig.service  \
        cpupower.service  \
        ebtables.service  \
        gssproxy.service  \
        runlevel0.target  \
        runlevel1.target  \
        runlevel6.target  \
        dnsmasq.service   \
        iprdump.service   \
        iprinit.service   \
        iprutils.target   \
        machines.target   \
        ntpdate.service   \
        ntpd.service      \
        poweroff.target   \
        kpatch.service \
        psacct.service \
        rsyncd.service \
        abrtd.service  \
        brandbot.path  \
        cgred.service  \
        rdisc.service  \
        reboot.target  \
        rescue.target  \
        rsyncd.socket  \
        fstrim.timer   \
        kexec.target   \
        rhsm.service   \
        tcsd.service   \
        halt.target \
        nfs.service \
        tmp.mount   \
        atd.service  \
        rngd.service \
        crond.service   \
        rpcbind.socket  \
        smartd.service  \
        postfix.service \
        remote-fs.target   \
        runlevel2.target   \
        runlevel3.target   \
        runlevel4.target   \
        abrt-ccpp.service  \
        abrt-oops.service  \
        abrt-xorg.service  \
        mdmonitor.service  \
        nfs-client.target  \
        rhsmcertd.service  \
        abrt-vmcore.service   \
        libstoragemgmt.service   \
        dmraid-activation.service   \
        systemd-readahead-drop.service \
        systemd-readahead-replay.service  \
        systemd-readahead-collect.service \
        systemd-readahead-done.service   \
        systemd-readahead-done.timer \
        rpcbind.service \
        microcode.service  \
        kdump.service \
        libvirt-guests.service \
        libvirtd.service  \
        virtlockd.socket  \
        virtlogd.socket   \
        iscsid.service \
        iscsiuio.service \
        libvirt-guests.service \
        libvirtd.service \
        qemu-guest-agent.service \
        spice-vdagentd.service \
        iscsid.socket \
        iscsiuio.socket \
        virtlockd.socket \
        bluetooth.service \
        cups.path \
        accounts-daemon.service \
        avahi-daemon.service \
        chrony-wait.service \
        cups.service \
        gdm.service \
        initial-setup-reconfiguration.service \
        iscsi.service \
        ksmtuned.service \
        ModemManager.service \
        multipathd.service \
        rtkit-daemon.service \
        vgauthd.service \
        vmtoolsd.service \
        avahi-daemon.socket \
        cups.socket         \
        unbound-anchor.timer \
        chronyd.service
    do
       systemctl stop $i
       systemctl disable $i
       # systemctl status $i # debug only
    done

    for i in rsyslog.service sshd.service sysstat.service tuned.service
    do
       systemctl enable $i
       systemctl start $i
    done

    return "$?"
}

stop() {
    return 0
}

verify() {
    return 0
}

process $@
