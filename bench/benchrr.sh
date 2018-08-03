#!/bin/bash
trap "kill -- -$$" SIGINT

red=$(tput setaf 1)
normal=$(tput sgr0)

script_failure() {
    printf "\n%40s\n" "${red}----------------------------------------"
    printf "benchmark script failed at line $1 of $0 \n"
    printf "%40s\n" "----------------------------------------${normal}"
    exit 1
}
trap 'script_failure $LINENO' ERR

bench_failure() {
    printf "\n%40s\n" "${red}----------------------------------------"
    printf "benchmark run failed:\n"
    printf "Command: $(tail -2 $logfile | head -1)\n"
    cat $errlog
    printf "%40s\n" "----------------------------------------${normal}"
    exit 1
}
trap 'bench_failure' SIGTERM

# Check if datamash is installed and available
type datamash &>/dev/null || {
    echo >&2 "This script requries datamash. Aborting. "
    echo >&2 "On Ubuntu 14+, this can be installed with apt-get.";
    exit 1;
}

export TOP_PID=$$
scriptdir=$(pwd)
: ${BENCH_LOG_FILE:=${scriptdir}/bench.log}
logfile=$BENCH_LOG_FILE
tmplog=${scriptdir}/.log
export errlog=${scriptdir}/error.log
rm -f $logfile $tmplog $errlog

echo "********** Begin script: $(realpath $0) **********" >> $logfile

#MAXTIME="20m"
MAXTIME=1s
CORES="1 2 4 8 12 16"
BASE_ITER=3
RECORD_ITER=3
REPLAY_ITER=3

# MIS matching dedup ferret chess refine # BFS not used in paper
bench=(chess refine)
source config.sh

function errcheck () {
    errcode=$1
    logname=$2

    if [[ $errcode -eq 0 ]]; then
        tmp=$(grep "time" $logname | tr "=" ":" | tail -1 | cut -d':' -f 2 | cut -d' ' -f 2 | tr -d ' ')
        printf "%0.2f" "$tmp"
    else
        if [[ $errcode -eq 124 ]]; then
            printf "Timed out after %s.\n" $MAXTIME >> $errlog
        else
            cat $logname >> $errlog
        fi
        kill -s TERM $TOP_PID
    fi
}

function runcmd() {
    local P=$1
    local mode=$2
    local name=$3
    local args=$4
    if [[ "$name" = "run.sh lock"* ]]; then
        args="$4 log $P"
    fi

    cmd="CILK_NWORKERS=$P PORR_MODE=$mode ./$name $args"
    echo "$cmd" >> $logfile
    # Using timeout $MAXTIME causes some problem with dedup...why I hate bash scripting...
    CILK_NWORKERS=$P PORR_MODE=$mode ./$name $args 2>&1 | tee -a $logfile &> $tmplog
    local res=$?
    echo "------------------------------------------------------------" >> $logfile
    return $res
}

runall () {
    local name=$1
    local cmdname=$2
    local basecmd="${cmdname}_base"
    local args=$3

    printf -- "--- $name $args ---\n"
    printf "P\tbase\t\trecord\t\treplay\n"

    declare -A vals

    for P in $CORES; do
        printf "$P"
        vals=()
        for i in $(seq $BASE_ITER); do
            runcmd "$P" "none" "$basecmd" "$args"
            val=$(errcheck $? $tmplog)
            vals[$i]=$val
        done
        avg=$( echo ${vals[@]} | tr " " "\n" | datamash mean 1 | tr -s " ")
        stdev=$( echo ${vals[@]} | tr " " "\n" | datamash sstdev 1 | tr -s " ")
        printf "\t%.2f(%.2f)" "$avg" "$stdev"
        base=$avg

        rm -f .recordtimes
        vals=()
        for i in $(seq $RECORD_ITER); do
            runcmd "$P" "record" "$cmdname" "$args"
            val=$(errcheck $? $tmplog)
            vals[$i]=$val
            printf "%.2f\t%d\n" "$val" "$i" >> .recordtimes
            #mv .cilkrecord .cilkrecord.$i
        done
        avg=$( echo ${vals[@]} | tr " " "\n" | datamash mean 1 | tr -s " ")
        stdev=$( echo ${vals[@]} | tr " " "\n" | datamash sstdev 1 | tr -s " ")
        printf "\t%.2f(%.2f)" "$avg" "$stdev"

        median=$(cat .recordtimes | sort | cut -f 2 | datamash median 1)
        #mv .cilkrecord.$median .cilkrecord

        vals=()
        for i in $(seq $REPLAY_ITER); do
            runcmd "$P" "replay" "$cmdname" "$args"
            val=$(errcheck $? $tmplog)
            vals[$i]=$val
        done
        avg=$( echo ${vals[@]} | tr " " "\n" | datamash mean 1 | tr -s " ")
        stdev=$( echo ${vals[@]} | tr " " "\n" | datamash sstdev 1 | tr -s " ")
        printf "\t%.2f(%.2f)" "$avg" "$stdev"

        #mv .cilkrecord .cilkrecord-p$P


        printf "\n"
    done
    printf "\n-------------------------"
    set -e

}

if [ $# -gt 0 ]; then bench=($@); fi
for b in "${bench[@]}"; do
    cd ${dirs[$b]}
    (${makecmds[$b]} 2>&1) > compile.log
    if [[ "$?" -ne 0 ]]; then
        echo "Compile error!"
        cat compile.log
    fi
    runall "$b" "${cmdnames[$b]}" "${args[$b]}"
    cd - >/dev/null
done

echo "********** End script: $(realpath $0) **********" >> $logfile
