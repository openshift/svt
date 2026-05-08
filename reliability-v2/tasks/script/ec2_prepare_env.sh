#!/bin/bash
set -e

cd ~/reliability-v2

ENABLE_LVMS="$1"
REGISTRY_NAMESPACE="$2"
PODMAN_USERNAME="$3"
REPOSITRY_NAME="$4"
CREATE_USERS="$5"
# PODMAN_PASSWORD is read from environment variable (set by caller)
export KUBECONFIG=~/reliability-v2/path_to_auth_files/kubeconfig

echo "[INFO] Installing TMUX and dependencies..."
sudo dnf install -y git make podman skopeo bison gcc libevent-devel ncurses-devel autoconf automake go wget

echo "[INFO] Adding github.com to known_hosts..."
mkdir -p ~/.ssh
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null

if ! command -v tmux &> /dev/null; then
  wget https://github.com/tmux/tmux/releases/download/3.5a/tmux-3.5a.tar.gz
  tar -xzf tmux-3.5a.tar.gz
  cd tmux-3.5a
  ./configure && make && sudo make install
  cd ..
  rm -rf tmux-3.5a*
fi

if [[ "$CREATE_USERS" == "yes" ]]; then
  echo "[INFO] Checking if HTPasswd identity provider already exists..."

  if oc get oauth cluster -o json | grep -q '"name": "local_users"'; then
    echo "[SKIP] HTPasswd identity provider 'local_users' already exists. Skipping user creation."
  else
    echo "[INFO] Creating htpasswd users..."

    # Force overwrite the users.htpasswd file
    rm -f users.htpasswd

    # Add perf-user and testuser-*
    htpasswd -c -B -b users.htpasswd perf-user perfpass
    for i in 1 2 21 22 31 32 41; do
      htpasswd -bB users.htpasswd testuser-$i pass$i
    done

    if ! oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd -n openshift-config --dry-run=client -o yaml | oc apply -f -; then
      echo "[ERROR] Failed to create htpass-secret"
      exit 1
    fi

    if ! oc patch oauth cluster --type=merge -p '{
      "spec": {
        "identityProviders": [
          {
            "name": "local_users",
            "mappingMethod": "claim",
            "type": "HTPasswd",
            "htpasswd": {
              "fileData": {
                "name": "htpass-secret"
              }
            }
          }
        ]
      }
    }'; then
      echo "[ERROR] Failed to patch OAuth cluster with HTPasswd provider"
      exit 1
    fi

    echo "[INFO] Assigning cluster-admin role to perf-user..."
    if ! oc adm policy add-cluster-role-to-user cluster-admin perf-user; then
      echo "[ERROR] Failed to assign cluster-admin role to perf-user"
      exit 1
    fi

    echo "[SUCCESS] HTPasswd users and identity provider configured."
  fi
else
  echo "[INFO] Skipping user creation as requested."
fi

# Generate auth files for start.sh
mkdir -p ~/reliability-v2/path_to_auth_files
echo "perf-user:perfpass" > ~/reliability-v2/path_to_auth_files/admin
echo "testuser-1:pass1,testuser-2:pass2,testuser-21:pass21,testuser-22:pass22,testuser-31:pass31,testuser-32:pass32,testuser-41:pass41" > ~/reliability-v2/path_to_auth_files/users
echo "[INFO] Auth files written to path_to_auth_files/"

if [[ "$ENABLE_LVMS" == "yes" ]]; then
  echo "[INFO] Preparing for LVMS..."

  OCP_VERSION=$(oc version -o json | python3 -c "import sys,json; v=json.load(sys.stdin).get('openshiftVersion',''); print('.'.join(v.split('.')[:2]))")
  LVMS_BRANCH="release-${OCP_VERSION}"

  git clone https://github.com/openshift/lvm-operator.git || true
  cd lvm-operator
  git fetch origin

  if ! git rev-parse --verify "origin/${LVMS_BRANCH}" &>/dev/null; then
    LVMS_BRANCH=$(git branch -r | grep -oP 'origin/release-\d+\.\d+$' | sort -t. -k1,1n -k2,2n | tail -1 | sed 's|origin/||')
    echo "[WARN] release-${OCP_VERSION} not found, falling back to latest: ${LVMS_BRANCH}"
  fi
  echo "[INFO] OCP version: ${OCP_VERSION}, LVMS branch: ${LVMS_BRANCH}"

  git checkout "$LVMS_BRANCH"

  export IMAGE_REGISTRY=quay.io
  LVMS_VERSION=$(echo "$LVMS_BRANCH" | sed 's/release-//')
  export IMAGE_TAG=${LVMS_VERSION}.1
  export IMAGE_REPO=$IMAGE_REGISTRY/$REGISTRY_NAMESPACE/$REPOSITRY_NAME
  export IMG=$IMAGE_REPO:$IMAGE_TAG

  # Unset ENABLE_LVMS to prevent Makefile from using it as a variable
  unset ENABLE_LVMS

  echo "[DEBUG] IMG=$IMG"
  echo "[INFO] Logging into quay.io with podman"
  podman login $IMAGE_REGISTRY -u "$PODMAN_USERNAME" -p "$PODMAN_PASSWORD"

  make docker-build docker-push
  make deploy

  cd ~/reliability-v2

  LVMS_NAMESPACE=$(oc get deployments -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\n"}{end}' | grep -m1 lvm)
  if [ -z "$LVMS_NAMESPACE" ]; then
    LVMS_NAMESPACE="openshift-lvm-storage"
  fi

  # Replace the default StorageClass with one that disables nrext64.
  # Source-built xfsprogs may enable nrext64 by default, but RHCOS kernels
  # may not support it, causing XFS mount failures.
  echo "[INFO] Replacing StorageClass with nrext64=0 for kernel compatibility..."
  oc scale deploy lvms-operator -n $LVMS_NAMESPACE --replicas=0
  sleep 5
  oc delete sc lvms-vg1 --ignore-not-found
  oc create -f - <<'SCEOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: lvms-vg1
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: topolvm.io
parameters:
  topolvm.io/device-class: vg1
  topolvm.io/fstype: xfs
  topolvm.io/mkfs-options: "-i nrext64=0"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
SCEOF
  oc scale deploy lvms-operator -n $LVMS_NAMESPACE --replicas=1
  echo "[SUCCESS] StorageClass lvms-vg1 recreated with nrext64=0."

  echo "[INFO] LVMS namespace: $LVMS_NAMESPACE"

  for node in $(oc get nodes -l node-role.kubernetes.io/master -o jsonpath='{.items[*].metadata.name}'); do
    echo "[INFO] Checking if fake disks already exist on $node..."
    oc debug node/$node -- bash -c "chroot /host bash -c '
      set -e

      DISK_DIR=/var/fake-disks

      if losetup -a | grep -qE \"/(var/)?fake-disks/fake-disk1.img\"; then
        echo \"[SKIP] Fake disks already exist on $node\"
        exit 0
      fi

      echo \"[INFO] Creating fake disks on $node\"
      mkdir -p \$DISK_DIR
      fallocate -l 10G \$DISK_DIR/fake-disk1.img
      fallocate -l 10G \$DISK_DIR/fake-disk2.img
      losetup -fP \$DISK_DIR/fake-disk1.img
      losetup -fP \$DISK_DIR/fake-disk2.img
      losetup -a
    '"
  done

  echo "[INFO] Waiting for lvms-webhook-service to be ready..."
  for i in {1..12}; do
    ENDPOINTS=$(oc get endpoints lvms-webhook-service -n $LVMS_NAMESPACE -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
    if [ -n "$ENDPOINTS" ]; then
      echo "[INFO] Webhook service is now available."
      break
    fi
    echo "[WAIT] Waiting for webhook service endpoints..."
    sleep 5
  done

  if [ -z "$ENDPOINTS" ]; then
    echo "[ERROR] Webhook service still has no endpoints. Cannot continue."
    oc get endpoints lvms-webhook-service -n $LVMS_NAMESPACE
    exit 1
  fi

  # Deploy LVMCluster only if it doesn't exist
  if ! oc get lvmcluster my-lvmcluster -n $LVMS_NAMESPACE &>/dev/null; then
    echo "[INFO] Deploying LVMCluster"
    oc create -n $LVMS_NAMESPACE -f - <<'LCEOF'
apiVersion: lvm.topolvm.io/v1alpha1
kind: LVMCluster
metadata:
  name: my-lvmcluster
spec:
  storage:
    deviceClasses:
    - name: vg1
      default: true
      thinPoolConfig:
        name: thin-pool-1
        sizePercent: 90
        overprovisionRatio: 10
LCEOF
  else
    echo "[SKIP] LVMCluster 'my-lvmcluster' already exists. Skipping creation."
  fi

  echo "[INFO] Waiting for LVMCluster to be ready..."
  if ! oc wait lvmcluster/my-lvmcluster -n $LVMS_NAMESPACE --for=jsonpath='{.status.state}'=Ready --timeout=180s; then
    echo "[ERROR] LVMCluster did not become ready in time."
    oc get lvmcluster -n $LVMS_NAMESPACE -o yaml
    exit 1
  fi

  echo "[INFO] Waiting for pods in $LVMS_NAMESPACE to be ready..."
  if ! oc wait --for=condition=Ready pods --all -n $LVMS_NAMESPACE --timeout=120s; then
    echo "[ERROR] Some pods in $LVMS_NAMESPACE are not ready:"
    oc get pods -n $LVMS_NAMESPACE
    exit 1
  fi

  echo "[SUCCESS] LVMS deployed and all pods are running."
fi

echo "[INFO] EC2 preparation completed."