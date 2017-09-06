#!/bin/bash -e
#set -x

function prepare_s2i_builder_image_locally {
	make -C ./stac-s2i-builder-image STAC_CONFIG=$stac_config
}

function push_builder_image_to_internal_registry {
	token=`oc whoami -t`
        registry_svc_ip=`oc get svc docker-registry -n default -o json | jq .spec.clusterIP| tr -d '"'` 
	retVal=`docker login -u admin -p $token $registry_svc_ip:5000`
	if [ ! "$retVal" == "Login Succeeded" ]; then
                        echo " "
                        echo "ERROR: Unable to login integrated(internal) docker registry, $registry_svc_ip:5000. $retVal"
                        echo " "
                        exit 1
        fi
        retVal=`docker tag s2i-stac-builder $registry_svc_ip:5000/stac/s2i-stac-builder:latest`
        if [ ! "$retVal" == "" ]; then
        	echo " "
        	echo "ERROR: Unable to tag local builder image : $retVal"
        	echo " "
                exit
        fi
        echo "docker push $registry_svc_ip:5000/stac/s2i-stac-builder:latest. This will create s2i-stac-builder imagestream automatically"
        docker push $registry_svc_ip:5000/stac/s2i-stac-builder:latest
}
function is_builder_imageStream_created {
	retVal=`oc get is s2i-stac-builder -n stac -o json | jq .status.tags[0].tag| tr -d '"' 2>&1`
        if [ ! "$retVal" == "latest" ]; then
        	echo " "
        	echo "ERROR: builder imagestream or tag is not correct : $retVal"
        	echo " "
                exit
        fi
}

function wait_ready {
	while $(sleep 5); do
	    result=$(oc get pods --namespace=stac --selector="name="${LABEL}"" --no-headers | awk '{print $3}' | awk -F/ '{print $1}' | tr ' ' '\n' | sort --numeric-sort | head --lines=1)
	    if [[ "${result}" == "Running" ]]; then
		break
	    fi
	done
}


if [ $# -lt 1 ] || [ $# -gt 1 ] ; then
        echo " "
        echo "Usage: ./stac-build-n-deploy.sh <http(s)://github-repo-url-for-stac-config.git>"
        echo " "
        exit 1
fi

stac_config=$1
echo stac_config repo: $stac_config

echo "Cleaning any older deployment before creating a new one!!"
`pwd`/scripts/clean_stac

oc create namespace stac 2> /dev/null || true
oc policy add-role-to-user system:image-builder --serviceaccount=builder -n stac
oc policy add-role-to-user system:deployer --serviceaccount=deployer -n=stac
oc policy add-role-to-group system:image-puller system:serviceaccounts:stac -n=stac
oadm policy add-scc-to-user privileged -z builder -n stac
oc create -f content/stac-scc.json

echo "Creating s2i builder image for STAC application!!"
prepare_s2i_builder_image_locally

echo " "
echo " "
echo "Pushing builder image to internal registry!!!"
push_builder_image_to_internal_registry

is_builder_imageStream_created
echo "s2i-stac-builder imagestream got created successfully!!!"

echo " "
echo " "
echo "Building image and imagestream for final stac pods, using s2i-stac-builder image"
oc process -p STAC_CONFIG=$stac_config -f content/stac-buildconfig.yaml | oc create --namespace=stac -f -

echo " "
echo " "
echo "Deploying 'Producer'"
oc process -p ROLE=producer -f content/stac-deploymentconfig.yaml | oc create --namespace=stac -f -
echo "Waiting for Producer pod to get ready"
LABEL=producer
wait_ready

echo " "
echo " "

echo "Deploying 'Consumer'"
oc process -p ROLE=consumer -f content/stac-deploymentconfig.yaml | oc create --namespace=stac -f -
echo "Waiting for Consumer pod to get ready"
LABEL=consumer
wait_ready

echo " "
echo " "
echo "Pods are ready. To start test, run ./run-stac-test.sh"
