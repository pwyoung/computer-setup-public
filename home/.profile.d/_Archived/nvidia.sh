#!/bin/bash

LOG=/tmp/setup-nvidia.out

if [ -e /usr/local/cuda ]; then
    export CUDA_HOME=/usr/local/cuda
    export PATH=$PATH:$CUDA_HOME/bin
    export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
fi

nvcc --version | tee $LOG


# For ngc cli app(s)
# https://org.ngc.nvidia.com/setup/installers/cli
# moved to locale.sh
#export LC_CTYPE=en_US.UTF-8
#export LC_ALL=en_US.UTF-8
