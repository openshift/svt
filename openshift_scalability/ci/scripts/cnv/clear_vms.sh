#/bin/bash


function get_ns_names {
  # returns array with name spaces name according to test name
  base_name="cnv-vm-testing-"$1
  for index in {0..20}
  do
    args+=$base_name"${index}"
    args+=" "
  done
  echo "${args[@]}"
}


echo "Select namespace base name (cirros_vm, fedora_vm) :  "
while :
do
  read TEST_NAME
  case ${TEST_NAME} in
        cirros_vm)
                echo "cirros vm selected"
                declare -a CURRENT_TEST_NS=$(get_ns_names "cirros")
                break
                ;;
        fedora_vm)
                echo "fedora vm selected"
                declare -a CURRENT_TEST_NS=$(get_ns_names "fedora")
                break
                ;;
        *)
                echo "Sorry, did have this namespace"
                break
                ;;
  esac
done

echo $CURRENT_TEST_NS
echo "Start deleting ...."

# Cleanup namespaces
for ns in ${CURRENT_TEST_NS[@]}; do
   oc delete project --wait=true $ns
done
