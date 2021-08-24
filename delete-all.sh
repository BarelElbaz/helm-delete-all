#!/bin/sh
echo "Context: $HELM_KUBECONTEXT"
$HELM_BIN list -a | xargs -L1 $HELM_BIN delete