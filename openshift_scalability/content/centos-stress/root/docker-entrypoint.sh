#!/bin/bash -x
# Some parts written for /bin/bash, see arrays in jmeter
# Entrypoint script for Load Generator Docker Image

ProgramName=${0##*/}

# Global variables
pctl_bin=pctl
url_gun_ws="http://${GUN}:9090"
gw_hex=$(grep ^eth0 /proc/net/route | head -1 | awk '{print $3}')
#gateway=$(/sbin/ip route|awk '/default/ { print $3 }')	# sometimes there is no /sbin/ip ...
gateway=$(printf "%d.%d.%d.%d" 0x${gw_hex:6:2} 0x${gw_hex:4:2} 0x${gw_hex:2:2} 0x${gw_hex:0:2})
JVM_ARGS=${JVM_ARGS:--Xms512m -Xmx4096m}	# increase heap size by default

fail() {
  echo $@ >&2
}

warn() {
  fail "$ProgramName: $@"
}

die() {
  local err=$1
  shift
  fail "$ProgramName: $@"
  exit $err
}

usage() {
  cat <<EOF 1>&2
Usage: $ProgramName
EOF
}

use_option() {
  local option="$1"
  local env_var="$2"
  local empty_sets="${3:-n}"
  local neg="${4:-n}"
  eval local env_var_val='$'"$env_var"

  test "$env_var_val" || {
    if test "$empty_sets" = y ; then
      echo -n $option
    else
      :
    fi
    return 0
  }

  case "$env_var_val" in
    [Yy]) 
      if test "$neg" = y ; then
        :
      else
        echo -n "$option"
      fi
      ;;

    [Nn])
      if test "$neg" = y ; then
        echo -n "$option"
      else
        :
      fi
      ;;
    
    *)
      die 1 "invalid value \`$env_var_val\` for $env_var"
      ;;
  esac
}

have_server() {
  local server="$1"
  if test "${server}" = "127.0.0.1" || test "${server}" = "" ; then
    # server not defined
    return 1
  fi 
}

# Wait for all the pods to be in the Running state
synchronize_pods() {
  have_server "${GUN}" || return

  while [ "$(curl -s ${url_gun_ws}/)" != "GOTIME" ] ; do 
    sleep 5
    fail "${url_gun_ws} not ready"
  done
}

announce_finish() {
  have_server "${GUN}" || return

  curl -s ${url_gun_ws}/gotime/finish
}

get_cfg() {
  local path="$1"

  curl -Ls "${url_gun_ws}/${path}"
}

# basic checks for toybox/busybox/coreutils timeout
define_timeout_bin() {
  test "${RUN_TIME}" || return	# timeout empty, do not define it and just return

  timeout -t 0 /bin/sleep 0 >/dev/null 2>&1

  case $? in
    # we have a busybox timeout with '-t' option for number of seconds
    0)
      timeout="timeout -t ${RUN_TIME}"
      ;;

    # we have toybox's timeout without the '-t' option for number of seconds
    1)   
      timeout="timeout ${RUN_TIME}"
      ;;

    # we have coreutil's timeout without the '-t' option for number of seconds
    125)
      timeout="timeout ${RUN_TIME}"
      ;;

    # couldn't find timeout or unknown version
    *)
      warn "running without timeout"
      timeout=""
      ;;
  esac
}

timeout_exit_status() {
  local err="${1:-$?}"

  case $err in
    # coreutil's return code for timeout
    124)
      return 0
      ;;

    # timeout also sends SIGKILL if a process fails to respond
    137)
      return 0
      ;;

    # busybox's return code for timeout with default signal TERM
    143)
      return 0
      ;;

    *)
      return $err
      ;;
  esac
}

main() {
  define_timeout_bin
  synchronize_pods

  case "${RUN}" in
    stress)
      [ "${STRESS_CPU}" ] && STRESS_CPU="--cpu ${STRESS_CPU}"
      $timeout \
        stress ${STRESS_CPU}
      $(timeout_exit_status) || die $? "${RUN} failed: $?"
      ;;

    logger)
      local slstress_log=/tmp/${HOSTNAME}-${gateway}.log

      $timeout \
        /usr/local/bin/logger.sh
      $(timeout_exit_status) || die $? "${RUN} failed: $?"
      ;;

    jmeter)
      IFS=$'\n'
      # Massage the host data passed in from OSE
      TARGET=($(echo $TARGET_HOST | sed 's/\:/\n/g'))
      TARGET_HOST="$(echo $TARGET_HOST | sed 's/\:/\ /g')"
      NUM="$(echo $TARGET_HOST | wc -w)"
      # JMeter constant throughput times wants TPM
      ((JMETER_TPS*=60))

      # Add router IP & hostnames to hosts file
      [ "${ROUTER_IP}" ] && echo "${ROUTER_IP} ${TARGET_HOST}" >> /etc/hosts

      local ips=""
      local i=0
      while test $i -lt $NUM ; do
        ips=${ips}$'\n'"-Jipaddr$(($i+1))=${TARGET[$i]}"
        i=$((i+1))
      done

      # Wait for Cluster Loader start signal webservice
      results_filename=jmeter-"${HOSTNAME}"-"$(date +%y%m%d%H%M)" 

      # Call JMeter packed with ENV vars
      jmeter -n -t test.jmx -Jnum=${NUM} -Jramp=${JMETER_RAMP} \
        -Jduration=${RUN_TIME} -Jtpm=${JMETER_TPS} \
        ${ips} \
        -Jport=${TARGET_PORT} \
        -Jresults_file="${results_filename}".jtl -l "${results_filename}".jtl \
        -j "${results_filename}".log -Jgun="${GUN}" || die $? "${RUN} failed: $?"

      have_server "${GUN}" && scp -o StrictHostKeyChecking=false -p *.jtl *.log *.png ${GUN}:${PBENCH_DIR}
      ;; 

    wrk)
      local wrk_log=/tmp/${HOSTNAME}-${gateway}.log
      local requests_awk=requests.awk
      local dir_out=${RUN}-${HOSTNAME:-${IDENTIFIER:-0}}
      local targets_lst=/opt/wlg/targets.txt
      local requests_json=$dir_out/requests.json
      local wrk=/usr/local/bin/wrk
      local wrk_script=wrk.lua
      local env_out=$dir_out/environment	# for debugging
      local results_csv=$dir_out/results.csv
      local graph_dir=gnuplot/${RUN}
      local graph_sh=gnuplot/$RUN/graph.sh
      local interval=10				# sample interval for d3js graphs [s]
      local tls_session_reuse=""

      rm -rf ${dir_out} && mkdir -p ${dir_out}
      ulimit -n 1048576				# use the same limits as HAProxy pod
      #sysctl -w net.ipv4.tcp_tw_reuse=1	# safe to use on client side
      env > $env_out				# dump out the environment for debugging

      cat ${targets_lst} | grep "${WRK_TARGETS:-.}" | awk \
        -vpath=${URL_PATH:-/} -vdelay_min=0 -vdelay_max=${WRK_DELAY:-1000} \
        -f ${requests_awk} > ${requests_json} || \
        die $? "${RUN} failed: $?: unable to retrieve wrk targets list \`targets'"
      ln -sf $dir_out/requests.json	# TODO: look into passing values to "$wrk_script"'s init()

      local wrk_threads=`python -c 'import sys, json; print len(json.load(sys.stdin))' < ${requests_json}`
      test "${wrk_threads}" -eq 0 && die 1 "no targets to test against"
      local wrk_host=`python -c 'import sys, json; print json.load(sys.stdin)[0]["host"]' < ${requests_json}`
      local wrk_port=`python -c 'import sys, json; print json.load(sys.stdin)[0]["port"]' < ${requests_json}`
      local wrk_conns=$(($wrk_threads * ${WRK_CONNS_PER_THREAD:=1}))
      local no_keepalive=$(use_option "--no_keepalive" WRK_KEEPALIVE n y)		# keepalive is enabled by default
      local tls_session_reuse=$(use_option "--reuse" WRK_TLS_SESSION_REUSE n n)		# TLS session reuse is disabled by default

      $timeout \
        $wrk \
          -q \
          -t${wrk_threads} \
          -c${wrk_conns} \
          -d${RUN_TIME:-600}s \
          ${no_keepalive} \
          ${tls_session_reuse} \
          -s ${wrk_script} \
          http://${wrk_host}:${wrk_port} > ${results_csv}.$$
      $(timeout_exit_status) || die $? "${RUN} failed: $?"
      LC_ALL=C sort -t, -n -k1 ${results_csv}.$$ > ${results_csv}
      rm -f ${results_csv}.$$
      $graph_sh ${graph_dir} ${results_csv} $dir_out/graphs $interval
      xz -0 -T0 < ${results_csv} > ${results_csv}.xz && rm -f ${results_csv}

      have_server "${GUN}" && \
        scp -rp ${dir_out} ${GUN}:${PBENCH_DIR}
      $(timeout_exit_status) || die $? "${RUN} failed: scp: $?"

      announce_finish
      ;;

    *)
      die 1 "No harness for RUN=\"$RUN\"."
      ;;
  esac
  timeout_exit_status
}

main
