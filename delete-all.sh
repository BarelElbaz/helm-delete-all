#!/bin/sh

# set HELM_BIN using Helm, or default to 'helm' if empty
HELM_BIN="${HELM_BIN:-helm}"
PROGNAME="$(basename $0 .sh)"
TIMEOUT=10
DELETEPV=1
SKIP_NS=""      # NS to skip, if set

display_help() {
    echo "Usage: helm $PROGNAME [option...]" >&2
    # echo
    echo "   -t | --timeout [seconds]       Change default timeout, in seconds (default 10)"
    echo "   -d | --deletePersistent        If set, deletes all PVCs"
    echo "   -e | --except-namespace [ns]   Skips this namespaces"
    echo "   -h | --help                    Show this message"
    echo
    # echo some stuff here for the -a or --add-options
    exit 0
}

# TRAPS!
trap 'printf "\n----\n%s\n----\n" "ABORTING!"; exit 1'  INT HUP
trap 'echo "Happy Helming!"' EXIT #CLEAN UP!!

color_print(){
    ### https://unix.stackexchange.com/a/521120/391114 ###
    red='tput setaf 1'
    green='tput setaf 2'
    reset='tput sgr0'

    $green ; printf "%s\n" "$1"
    $reset
    return 0
}

handle_error(){
    # red=`tput setaf 1`
    # green=`tput setaf 2`
    # reset=`tput sgr0`
    if [ -n "$1" ] ; then
        IN="$1"
    else
        read IN
    fi
    [ -z "$IN" ] && return 0
    tput setaf 1; printf "ERROR: " && tput sgr0 ; printf "%s\n" "${IN#Error: }" >&2
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
    echo "--------"
    color_print "Namespace: $namespace" 2>/dev/null || echo "Namespace: $namespace"

    ### Skip this namespace if in -e flag
    [ "$namespace" = "$SKIP_NS" ] &&  printf "skipping ns %s as requested\n" "${namespace}" && continue

    helm_charts="$($HELM_BIN list -a -n ${namespace} --short)"
    if [ -z "$helm_charts" ]; then
        printf "No releases in this namespace!\n"
    else
        for chart in $helm_charts ; do
            ("$HELM_BIN" delete -n "${namespace}" "$chart" 2>&1 >&3 3>&- | handle_error >&2 3>&-) 3>&1
        done
    fi

    ### PVC delete [merged from ThreatACC]###
    if [ "$DELETEPV" -eq 0 ] ; then
        persistent_volume=$(kubectl get persistentvolumeclaims -n "${namespace}" 2> /dev/null | tail -n+2 | cut -d " " -f 1 )
        if [ -z "$persistent_volume" ] ; then
            echo "No PersistentVolumes to delete in this namespace"
        else
            for pvc in $persistent_volume; do
                kubectl delete -n "${namespace}" persistentvolumeclaim "${pvc}"
            done
        fi
    fi

    echo "--------"
done



