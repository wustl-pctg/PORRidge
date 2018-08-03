#!/bin/bash
set -e

red=$(tput setaf 1)
normal=$(tput sgr0)

err_report() {
    printf "%40s\n" "${red}----------------------------------------"
    printf "setup failed at line $1 of $0 \n"
    printf "%40s\n" "----------------------------------------${normal}"
}

trap 'err_report $LINENO' ERR

BASE_DIR=$(pwd)
CPLUS_INCLUDE_PATH=/usr/include:/usr/include/c++/5 
export CPLUS_INCLUDE_PATH

function msg() {
    echo "$1" | tee -a setup.log
}

msg "Begin PORRidge setup at $(date)"
rm -f setup.log

: ${BINUTILS_PLUGIN_DIR:="/usr/local/include"}
if [[ ($BINUTILS_PLUGIN_DIR != "") &&
          (-e $BINUTILS_PLUGIN_DIR/plugin-api.h) ]]; then
    export LTO=1
else
    export LTO=0
    echo "Warning: no binutils plugin found, necessary for LTO"
fi

t=$(ldconfig -p | grep tcmalloc)
if [[ $? != 0 ]]; then
    echo "tcmalloc not found! Install google-perftools"
fi

# Setup and compile our compiler
./build-llvm-linux.sh

msg "Modified clang compiled."

# Build the runtime (ability to suspend/resume deques)

# It would be better to have this as a separate repo and either clone
# it or make it a submodule. I've started a repo for this purpose at
# https://gitlab.com/wustl-pctg/mdcilk.git, though some changes are
# necessary to make it work.
# git clone https://gitlab.com/wustl-pctg/mdcilk.git cilkrtssuspend

cd ./cilkrtssuspend
make clean && make distclean
libtoolize
autoreconf -i
./remake.sh pre opt lto
cd -

msg "Suspendable work-stealing runtime built"

## Compile library
mkdir -p build
BASE_DIR=$(pwd)
if [ ! -e config.mk ]; then
    echo "BUILD_DIR=$BASE_DIR/build" >> config.mk
    echo "RUNTIME_HOME=$BASE_DIR/cilkrtssuspend" >> config.mk
    echo "COMPILER_HOME=$BASE_DIR/llvm-cilk" >> config.mk
    echo "RTS_LIB=\$(COMPILER_HOME)/lib/libcilkrts.a" >> config.mk
    echo "LTO=$LTO" >> config.mk
fi
cd src
make clean
make -j
cd -

# Check out our fork of PBBS
cd bench
if [ ! -d cilkplus-tests ]; then
    git clone https://gitlab.com/robertutterback/cilkplus-tests.git cilkplus-tests
fi

# Compile benchmarks
./build.sh

# Generate data sets for PBBS benchmarks
cd cilkplus-tests
./gendata.sh
cd -

# Download and setup data sets for dedup and ferret
cd $BASE_DIR/bench/dedup
wget www.cse.wustl.edu/~utterbackr/dedup-data.tar.gz
tar -vxzf dedup-data.tar.gz data

cd $BASE_DIR/bench/ferret
wget www.cse.wustl.edu/~utterbackr/ferret-data.tar.gz
tar -vxzf ferret-data.tar.gz data

# Now we're ready to go!
msg "Setup completed. Use bench/bench.sh to run benchmarks"
msg "Running the benchmarks will require setting vm.max_map_count to a high level"
msg "e.g. 'sysctl -w vm.max_map_count=1000000'"
