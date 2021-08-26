#!/bin/sh

# set HELM_BIN using Helm, or default to 'helm' if empty
HELM_BIN="${HELM_BIN:-helm}"
PROGNAME="$(basename $0 .sh)"
TIMEOUT=5
DELETEPV=1
SKIP_NS=""      # NS to skip, if set

display_help() {
    echo "Usage: helm $PROGNAME [option...]" >&2
    # echo
    echo "   -t | --timeout [seconds]       Change default timeout, in seconds (default 5)"
    echo "   -d | --deletePersistent        If set, deletes all PVCs"
    echo "   -e | --except-namespace [ns]   Skips this namespaces"
    echo "   -h | --help                    Show this message"
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
# Canonicalizing (is that a word?) opts
TEMP=$(getopt -o t:hde: --long timeout:,help,deletePersistent,except-namespace: \
    -n "$0" -- "$@")

eval set -- "$TEMP"

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
        -e | --except-namespace)
            echo "skipping NS $2" && SKIP_NS="$2"
            shift 2
            ;;
        -[hH] | --[hH]elp)
            display_help
            exit 0
            ;;
        --deletePersistent | -d)
            DELETEPV=0
            shift
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

timeout "$TIMEOUT" kubectl cluster-info > /dev/null 2>&1
test ${?} -eq 0 || handle_error "the server might be offline"


namespaces=$(kubectl get namespaces -o custom-columns=:.metadata.name)
for namespace in $namespaces
do
    echo "Namespace: $namespace"
    echo "--------"
    ### Skip this namespace if in -e flag
    [ "$namespace" = "$SKIP_NS" ] &&  printf "skipping ns %s as requested\n" "${namespace}"; continue
    helm_charts="$($HELM_BIN list -a -n ${namespace} --short)"
    if [ -z "$helm_charts" ]; then
        printf "Namespace is empty!\n"
    else
        for chart in $helm_charts ; do
            "$HELM_BIN" delete -n "${namespace}" "$chart"
        done
    fi

done

if [ "$DELETEPV" -eq 0 ] ; then
    #### check if there are persistent volumes in the namespace ####
    persistent_volume=$(kubectl get persistentvolumeclaims 2> /dev/null | tail -n+2 | cut -d " " -f 1 )
    if [ -z "$persistent_volume" ] ; then
        echo "No PersistentVolumes to delete"
    else
        for pvc in $persistent_volume; do
            ### added pv patch to finelaizers from https://github.com/kubernetes/kubernetes/issues/77258#issuecomment-514543465 ###
            #kubectl patch persistentvolume "${pv}" -p '{"metadata":{"finalizers": null}}'
            kubectl delete persistentvolumeclaim "${pvc}"
        done
    fi
fi

