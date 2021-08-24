#!/bin/sh
TIMEOUT=5
handle_error(){
    # red=`tput setaf 1`
    # green=`tput setaf 2`
    # reset=`tput sgr0`
    tput setaf 1; printf "ERROR: " && tput sgr0 ; printf "$1\n"
    exit 1
}

timeout $TIMEOUT kubectl cluster-info > /dev/null 2>&1
test ${?} -eq 0 || handle_error "the server might be offline"

namespaces=$(kubectl get namespaces -o custom-columns=:.metadata.name)
for namespace in $namespaces
do
    echo "Namespace: $namespace"
    helm_charts=$(helm list -a -n ${namespace} --short)
    if [ -z "$helm_charts" ]; then
        echo "Namespace is empty!"
    else
        for chart in $helm_charts ; do
            helm delete -n ${namespace} $chart
        done
    fi  
done
