#!/bin/sh
# echo "Context: $HELM_KUBECONTEXT"
# $HELM_BIN list -a | xargs -L1 $HELM_BIN delete
PROGNAME=$(basename $0)
display_help() {
    echo "Usage: $PROGNAME [option...] {start|stop|restart}" >&2
    echo
    echo "   -r, --resolution           run with the given resolution WxH"
    echo "   -d, --display              Set on which display to host on "
    echo
    # echo some stuff here for the -a or --add-options 
    exit 0
}
while :
do
    case "$1" in
    #   -r | --resolution)
    #       if [ $# -ne 0 ]; then
    #         resolution="$2"   # You may want to check validity of $2
    #       fi
    #       shift 2
    #       ;;
      -h | --help)
          display_help  # Call your function
          exit 0
          ;;
    #   -d | --display)
    #       display="$2"
    #        shift 2
    #        ;;

    #   -a | --add-options)
    #       # do something here call function
    #       # and write it in your help function display_help()
    #        shift 2
    #        ;;

      --) # End of all options
          shift
          break
          ;;
      -*)
          echo "Error: Unknown option: $1" >&2
          ## or call function display_help
          exit 1 
          ;;
      *)  # No more options
          break
          ;;
    esac
done
namespaces=$(kubectl get namespaces -o custom-columns=:.metadata.name)
echo $namespaces

