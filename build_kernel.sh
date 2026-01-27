#!/bin/bash

export CLANG_PATH="$PWD/toolchain/proton-clang"
export PATH=$CLANG_PATH/bin:$PATH

git submodule update --init

if [ ! -d $CLANG_PATH ]; then
    git clone --depth=1 https://github.com/kdrag0n/proton-clang $CLANG_PATH
fi

if [[ "$1" == "--clean" ]]; then
    bash build.sh cleanbuild renoir
else
    bash build.sh all renoir
fi
