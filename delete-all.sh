#!/bin/sh

# set HELM_BIN using Helm, or default to 'helm' if empty
HELM_BIN="${HELM_BIN:-helm}"
PROGNAME="$(basename $0 .sh)"
TIMEOUT=5
DELETEPV=1
display_help() {
    echo "Usage: helm $PROGNAME [option...]" >&2
    # echo
    echo "   -t                 change default timeout, in seconds (default 5)"
    # echo "   -d, --display              Set on which display to host on "
    echo
    # echo some stuff here for the -a or --add-options
    exit 0
}

# TRAPS!
trap 'printf "\n----\n%s\n----\n" "ABORTING!"; exit 1'  INT HUP

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
# --
while :
do
    case "$1" in
        -t | --[tT]imeout)
            if [ $# -ne 0  ]; then
                if is_integer "$2"; then
                    echo "setting timeout to: $2" && TIMEOUT="$2"
                else
                    echo "Please use a NUMBER for timeout! (e.g, '4' for 4 secs)"
                    exit 1
                fi
            fi
            shift 2
            ;;
        -[hH] | --[hH]elp)
            display_help
            exit 0
            ;;
        --deletePersistent | -d)
            DELETEPV=0
            ;;       
        --)
            shift
            break
            ;;
        -*)
            echo "Illegal option!"
            display_help
            exit 1
            ;;
        *)
            break
            ;;
    esac
done
# --

# more POSIXy(?) getopts, no "--" for now
#while getopts ":[hH]t:" option; do
#    case "$option" in
#        t)  if is_integer "$OPTARG"; then
#                echo "Setting timeout to: $OPTARG" && TIMEOUT="$OPTARG"
#            else
#                echo "Please use a NUMBER for timeout! (e.g, '4' for 4 secs)"
#                exit 1
#            fi
#            ;;
#       # v)  echo "Verbose mode on" && _V=1
#       #     ;;
#        [Hh]) display_help
#            exit 0
#            ;;
#        \?) echo "Illegal option."
#            display_help
#            exit 1
#            ;;
#    esac
#done

## Get rid of the options that were processed
#shift $((OPTIND -1))

timeout "$TIMEOUT" kubectl cluster-info > /dev/null 2>&1
test ${?} -eq 0 || handle_error "the server might be offline"


namespaces=$(kubectl get namespaces -o custom-columns=:.metadata.name)
for namespace in $namespaces
do
    echo "Namespace: $namespace"
    echo "--------"
    helm_charts="$($HELM_BIN list -a -n ${namespace} --short)"
    if [ -z "$helm_charts" ]; then
        echo "Namespace is empty!"
    else
        for chart in $helm_charts ; do
            "$HELM_BIN" delete -n "${namespace}" "$chart"
        done
    fi
done

if [ DELETEPV -eq 0 ] ; then
    #### check if there are persistent volumes ####
    persistent_volume=$(kubectl get persistentvolume 2> /dev/null | sed 1,1d | cut -d " " -f 1 )
    if [ -z "$persistent_volume" ] ; then
        echo "No PersistentVolumes to delete"
        exit 1
    else
        ### added pv patch to finelaizers from https://github.com/kubernetes/kubernetes/issues/77258#issuecomment-514543465 ###
        kubectl patch persistentvolume "$persistent_volume" -p '{"metadata":{"finalizers": null}}' 
        ### delete pv ###
        kubectl delete persistentvolume "$persistent_volume"  
    fi
fi
