#!/bin/sh
# echo "Context: $HELM_KUBECONTEXT"
# helm list -a | xargs -L1 helm delete
PROGNAME="$(basename $0 .sh)"
TIMEOUT=5
display_help() {
    echo "Usage: helm $PROGNAME [option...]" >&2
    # echo
    echo "   -t                 change default timeout, in seconds (default 5)"
    # echo "   -d, --display              Set on which display to host on "
    echo
    # echo some stuff here for the -a or --add-options
    exit 0
}

handle_error(){
    # red=`tput setaf 1`
    # green=`tput setaf 2`
    # reset=`tput sgr0`
    tput setaf 1; printf "ERROR: " && tput sgr0 ; printf "%s\n" "$1"
    exit 1
}

# check if var is integer
is_integer(){
    case "${1#[+-]}" in
        (*[!0123456789]*)  return 1 ;;
        ('')               return 1 ;;
        (*)                return 0 ;;
    esac
}

# more POSIXy(?) getopts, no "--" for now
while getopts ":[hH]t:" option; do
    case "$option" in
        t)  if is_integer "$OPTARG"; then
                echo "Setting timeout to: $OPTARG" && TIMEOUT="$OPTARG"
            else
                echo "Please use a NUMBER for timeout! (e.g, '4' for 4 secs)"
                exit 1
            fi
            ;;
       # v)  echo "Verbose mode on" && _V=1
       #     ;;
        [Hh]) display_help
            exit 0
            ;;
        \?) echo "Illegal option."
            display_help
            exit 1
            ;;
    esac
done

# Get rid of the options that were processed
shift $((OPTIND -1))

timeout "$TIMEOUT" kubectl cluster-info > /dev/null 2>&1
test ${?} -eq 0 || handle_error "the server might be offline"


namespaces=$(kubectl get namespaces -o custom-columns=:.metadata.name)
for namespace in $namespaces
do
    echo "Namespace: $namespace"
    helm_charts="$(helm list -a -n ${namespace} --short)"
    if [ -z "$helm_charts" ]; then
        echo "Namespace is empty!"
    else
        for chart in $helm_charts ; do
            helm delete -n "${namespace}" "$chart"
        done
    fi
done

