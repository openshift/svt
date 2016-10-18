echo "WARNING: This test runs a container which logs a string to syslog forever."
read -p "Press any key to proceed:" x

# Log something infinitely long
function startlog() {
        docker run -d gcr.io/google_containers/busybox:1.24 '/bin/sh' '-c' 'while true ; do logger "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"; done'
}

startlog

while true ; do
        df /var/lib/docker/containers/
        sleep 5
done
