chmod +x get_openshift_tests.sh
#/!/bin/bash
#need to run as a root user
tag=$([ -z $1 ] && echo "latest" || echo "$1")
echo "tag $tag"
export IMAGE_ID=$(podman create quay.io/openshift/origin-tests:$tag)
echo $IMAGE_ID
podman images
podman ps -a  ; ### you'll see that image was run and no longer running, IMAGE_ID is the ID of running image origin-tests
mkdir /root/openshift-tests_binaries_dir
cd /root/openshift-tests_binaries_dir
podman cp $IMAGE_ID:/bin/openshift-tests .
ls -ltr
cp openshift-tests ~/
cp openshift-tests /usr/bin
which openshift-tests