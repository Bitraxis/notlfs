#!/bin/bash
set -e
export OPTIMIZATION="-Os -pipe"
export STRIP_DEBUG="true"
export DISABLE_NETWORK="true"
export HOSTNAME="notlfs-minimal"
