#!/usr/bin/bash
interval=450
start_time=`date +%Y%m%d%H%M%S`
hoststr=`hostname -s`
logfile="${hoststr}-${start_time}.log"


system_info()
{
        time=`date +%Y%m%d-%H%M%S`

        echo "time: $time"
        echo ""
        echo "****** 1. Filesystem info: ******"
        df -h
        echo
        echo "****** 2. MEMORY info: ******"
        free -m
        echo ""
        echo "****** 3. Vmstat info: ******"
        echo
        vmstat 1 3|tee -a $logfile
        echo
        echo "****** 4. Cpu consume top 5: ******"
        ps auxw|head -1;ps auxw --no-header|sort -rn -k3|head -5
        echo
        echo "****** 5. Mem consume top 5: ******"
        echo
        ps auxw|head -1;ps auxw --no-header|sort -rn -k4|head -5
        echo
        echo "===========================next ========= record==============================="
}
while true;do
        system_info |tee -a $logfile
        eval sleep $interval
done

