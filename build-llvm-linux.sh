#!/bin/bash

###### This file keeps the script to build Linux version of CilkPlus Clang based compiler

###### By default we assume you're using 'llvm-cilk' folder created in the current directory as a base folder of your source installation
###### If you use some specific location then pass it as argument to this script

if [ "$1" = "" ]
then
  LLVM_NAME=llvm-cilk
else
  LLVM_NAME=$1
fi

: ${BINUTILS_PLUGIN_DIR:="/usr/local/include"}

LLVM_HOME=`pwd`/"$LLVM_NAME"/src
LLVM_TOP=`pwd`/"$LLVM_NAME"

LLVM_GIT_REPO="https://gitlab.com/wustl-pctg-pub/llvm-cilk.git"
LLVM_BRANCH="cilkplus"
CLANG_GIT_REPO="https://gitlab.com/wustl-pctg-pub/clang-cilk.git"
CLANG_BRANCH="compressed_pedigrees"
COMPILERRT_GIT_REPO="https://gitlab.com/wustl-pctg/compiler-rt.git"
COMPILERRT_BRANCH="cilkplus-wustl"

echo Building $LLVM_HOME...

if [ ! -d $LLVM_HOME ]; then
    if [ "" != "$LLVM_BRANCH" ]; then
        git clone -b $LLVM_BRANCH $LLVM_GIT_REPO $LLVM_HOME
    else
        git clone $LLVM_GIT_REPO $LLVM_HOME
    fi
else
    cd $LLVM_HOME
    git pull --rebase
    cd -
fi

if [ ! -d $LLVM_HOME/tools/clang ]; then
    if [ "" != "$CLANG_BRANCH" ]; then
        git clone -b $CLANG_BRANCH $CLANG_GIT_REPO $LLVM_HOME/tools/clang
    else
        git clone $CLANG_GIT_REPO $LLVM_HOME/tools/clang
    fi
else
    cd $LLVM_HOME/tools/clang
    git pull --rebase
    cd -
fi

if [ ! -d $LLVM_HOME/projects/compiler-rt ]; then
    if [ "" != "$COMPILERRT_BRANCH" ]; then
	git clone -b $COMPILERRT_BRANCH $COMPILERRT_GIT_REPO $LLVM_HOME/projects/compiler-rt
    else
	git clone $COMPILERRT_GIT_REPO $LLVM_HOME/projects/compiler-rt
    fi
else
    cd $LLVM_HOME/projects/compiler-rt
    git pull --rebase
    cd -
fi

BUILD_HOME=$LLVM_HOME/build
if [ ! -d $BUILD_HOME ]; then
    mkdir -p $BUILD_HOME
fi
cd $BUILD_HOME

set -e

# Our very old version of llvm/clang does not like new C++ headers...
# I have tried using --with-gcc-toolchain and just setting CXX (which
# you'd think would be enough), but somehow it still looks in the
# g++-7 headers and finds problems.
# CPLUS_INCLUDE_PATH=/usr/include:/usr/include/c++/5 
CONFIG_ARGS="--enable-targets=host --enable-optimized"
echo ../configure $CONFIG_ARGS

if [[ ($BINUTILS_PLUGIN_DIR != "") && (-e $BINUTILS_PLUGIN_DIR/plugin-api.h) ]]; then
    echo "Using bintuils gold header: $BINUTILS_PLUGIN_DIR/plugin-api.h"
    ../configure --prefix="$LLVM_TOP" $CONFIG_ARGS --with-binutils-include="$BINUTILS_PLUGIN_DIR"
else
    echo "NOT using bintuils gold header."
    ../configure --prefix="$LLVM_TOP" $CONFIG_ARGS
fi

# ###### Now you're able to build the compiler
# old clang does not like new c++ headers...
PRE="CPLUS_INCLUDE_PATH=/usr/include:/usr/include/c++/5"
#eval "$PRE make -j > build.log"
make -j > build.log
make install
