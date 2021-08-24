#!/bin/sh
$HELM_BIN list -a | xargs -L1 $HELM_BIN delete