echo "WARNING THIS TEST IS RIDICULOSLY STUPID AND BREAKS YOUR ENTIRE NODE OR DOCKER DAEMON OR POSSIBLY BOTH"
read x

# Log something infinitely long
function startlog() {
        docker run -d gcr.io/google_containers/busybox:1.24 '/bin/sh' '-c' 'while true ; do echo "aasd asdfjsdofijsdofi  ojfodfijdofij oi jo ijoaijoaisjdoaijsdoij oaisj oasjdoasijda oisjdao sijsaoid j" ; done'
}

startlog

while true ; do
        df /var/lib/docker/containers/
        sleep 5
done
