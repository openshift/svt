#!/usr/bin/bash
interval=450

interval=300
start_time=`date +%Y%m%d%H%M%S`
hoststr=`hostname -s`
logfile="${hoststr}-${start_time}.log"


system_info()
{
        time=`date +%Y%m%d-%H%M%S`

        echo "time: $time"
        echo ""
        echo "****** 1. Filesystem info: ******"
        echo
        df -h

        echo "****** 2. Lvs info: ******"
        lvs -S lv_name=docker-pool
        echo

        echo
        echo "****** 3. MEMORY info: ******"
        echo
        free -m
        echo ""
        echo "****** 4. Vmstat info: ******"
        echo
        vmstat 1 3|tee -a $logfile
        echo
        echo "****** 5. Cpu consume top 5: ******"
        ps auxw|head -1;ps auxw --no-header|sort -rn -k3|head -5
        echo
        echo "****** 6. Mem consume top 5: ******"
        echo
        ps auxw|head -1;ps auxw --no-header|sort -rn -k4|head -5
        echo

        echo "****** 7. Openshift process info: ******"
        echo
        ps auxw |grep openshift |grep -v grep
        echo

        echo "****** 8. Docker container number: ******"
        echo
        activenum=`docker ps |wc -l`
        allnum=`docker ps -a |wc -l`
        echo "Active/all ${activenum}/${allnum}"
        echo

        echo "****** 9. Docker process info: ******"
        echo
        ps auxw |grep docker|grep -v grep
        echo
        echo "===========================next ========= record==============================="
}
while true;do
        system_info |tee -a $logfile
        eval sleep $interval
done

