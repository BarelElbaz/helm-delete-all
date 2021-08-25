#!/bin/sh

# set HELM_BIN using Helm, or default to 'helm' if empty
HELM_BIN="${HELM_BIN:-helm}"
PROGNAME="$(basename $0 .sh)"
TIMEOUT=5
display_help() {
    echo "Usage: helm $PROGNAME [option...]" >&2
    # echo
    echo "   -t, --timeout                 Change default timeout, in seconds (default 5)"
    echo "   -h, --help                    Show this message"
    # echo "   -d, --display              Set on which display to host on "
    echo
    # echo some stuff here for the -a or --add-options
    exit 0
}

# TRAPS!
trap 'printf "\n----\n%s\n----\n" "ABORTING!"; exit 1'  INT HUP
trap 'echo "Happy Helming!"' EXIT #CLEAN UP!!

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
    tput setaf 1; printf "ERROR: " && tput sgr0 ; printf "%s\n" "$IN" >&2
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
    helm_charts="$($HELM_BIN list -a -n ${namespace} --short)"
    if [ -z "$helm_charts" ]; then
        echo "Namespace is empty!"
    else
        for chart in $helm_charts ; do
            ("$HELM_BIN" delete -n "${namespace}" "$chart" 2>&1 >&3 3>&- | handle_error >&2 3>&-) 3>&1
        done
    fi
done

