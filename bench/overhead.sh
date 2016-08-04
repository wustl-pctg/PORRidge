#!/bin/bash
set -e
# ulimit -v 6291456
# Don't forget that we might need to set vm.max_map_limit
trap "kill -- -$$" SIGINT

: ${BENCH_LOG_FILE:=$HOME/tmp/log}
logfile=$BENCH_LOG_FILE
echo "********** Begin script: $(realpath $0) **********" >> $logfile

MAXTIME="5m"
ITER=3
CORES="1 2 4 8 12 16"

#refine MIS matching BFS chess dedup ferret
bench=(MIS matching refine)
basedir=..
source config.sh

errcheck () {
    errcode=$1
    logname=$2

    #cat $logname
    if [[ $errcode -eq 0 ]]; then
        printf "%0.2f" "$(grep 'time' $logname | tail -1 | cut -d':' -f 2 | tr -d ' ')"
        #printf "%0.2f" "$(grep 'time' $logname | tail -1 | cut -d' ' -f 4 | tr -d ' ')"
    else
        printf "\n[Error]:\n"
        if [[ $errcode -eq 124 ]]; then
            printf "Timed out after %s.\n" $MAXTIME
            exit 1
        fi
        cat $logname
        exit 1
    fi
    # No error, so remove the log file
    rm $logname
}

runcmd() {
    P=$1
    mode=$2
    name=$3
    args=$4
    if [[ $name =~ "run.sh" ]]; then
        args="$args out $P"
    fi
    cmd="CILK_NWORKERS=$P CILKRR_MODE=$mode ./$name $args"
    echo "$cmd" >> $logfile
    #echo "$cmd"
    
    CILK_NWORKERS=$P CILKRR_MODE=$mode ./$name $args 2>&1 | tee -a $logfile &> .log
    echo "------------------------------------------------------------" >> $logfile
}

compile() {
    b=$1
    (${makecmds[$b]} -j 2>&1) > compile.log
    if [[ "$?" -ne 0 ]]; then
        echo "Compile error!"
        cat compile.log
        exit 1
    fi
}

runmode () {
    P=$1
    name=$2
    cmdname=$3
    mode=$4
    args=$5
    declare -A vals
    cd ${dirs[$name]}
    compile $name

    vals=()
    for i in $(seq $ITER); do
        runcmd "$P" "$mode" "$cmdname" "$args"
        val=$(errcheck $? ".log")
        if [[ $? -ne 0 ]]; then
            printf "Error\n"
            exit 1
        fi
        vals[$i]=$val
        #echo $val
    done
    avg=$( echo ${vals[@]} | tr " " "\n" | datamash mean 1 | tr -s " ")
    # stdev=$( echo ${vals[@]} | tr " " "\n" | datamash sstdev 1 | tr -s " ")
    printf "%10.2f" "$avg"
    # printf "(%.2f)" "$stdev"

    make clean &> /dev/null
    cd - >/dev/null
}

newstage () {
    stage=$1
    cd $basedir
    make clean &> /dev/null

    make STAGE=$stage -j &> compile.log
    if [[ "$?" -ne 0 ]]; then
        echo "Compile error!"
        cat compile.log
        exit 1
    fi
    cd - >/dev/null
}


if [ $# -gt 0 ]; then bench=($@); fi

printf "%-10s%5s%10s%10s%10s%10s\n" "bench" "P" "none" "get" "insert" "conflict"

for b in "${bench[@]}"; do
    printf "%-10s" "$b"
    for P in $CORES; do
        printf "%5s" $P
        newstage "0"
        runmode "$P" "$b" "${cmdnames[$b]}" "none" "${args[$b]}" # baseline
        newstage "1"
        runmode "$P" "$b" "${cmdnames[$b]}" "record" "${args[$b]}" # get pedigree
        newstage "2"
        runmode "$P" "$b" "${cmdnames[$b]}" "record" "${args[$b]}" # insert
        newstage "3"
        runmode "$P" "$b" "${cmdnames[$b]}" "record" "${args[$b]}" # check conflicts
        printf "\n"
    done
done

echo "********** End script: $(realpath $0) **********" >> $logfile