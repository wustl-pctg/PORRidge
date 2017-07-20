#!/bin/bash
set -e
ulimit -v 6291456
MAXTIME="10m"
CORES="1 2 4 6 8"
NITER=1

bench=(fib) #fib cilkfor cbt
declare -A dirs args

args["fib"]=25
args["cilkfor"]=1000
args["cbt"]=100

errcheck () {
    errcode=$1
    logname=$2
    # printf "\t"
    # I'm not sure tail -1 is right for delaunay refinement
    if [[ $errcode -eq 0 ]]; then
        printf "%0.2f" "$(grep 'time' log | tail -1 | cut -d':' -f 2 | tr -d ' ')"
    else
        printf "\n[Error]:\n"
				if [[ $errcode -eq 124 ]]; then
						printf "Timed out after %s.\n" $MAXTIME
						exit 1
				fi
        cat log
        exit 1
    fi
}

runcmd() {
		P=$1
		mode=$2
		name=$3
		args=$4
		# CILK_NWORKERS=$P CILKRR_MODE=$mode timeout $MAXTIME ./$name $args &> log
		CILK_NWORKERS=$P CILKRR_MODE=$mode ./$name $args &> log
}

runreplay() {
		name=$1
		args=$2

		for P in $CORES; do
				avg=0
				for i in $(seq $NITER); do
						runcmd "$P" "replay" "$name" "$args"
						val=$(errcheck $? "log")
						avg=$( echo "scale=2; $avg + $val" | bc )
				done
				avg=$( echo "scale=2; $avg / $NITER" | bc )
				printf "\t%s" "$avg"
    done

}

runall () {
    set +e

		## Hack
		if [[ "$1" = "chess" ]]; then
				name="chess-cover-locking"
		else
				name=$1
		fi
    args=$2

    printf -- "--- $name $args ---\n"
		header_left="P\tbase\trecord"
		printf "${header_left}\t\t\treplayP\n"
		printf "%${#header_left}s\t" | tr " " "=" | tr "\t" "====="
		for P in $CORES; do printf "\t$P"; done;
		printf "\n"

    for P in $CORES; do
				printf "$P"
				avg=0
				for i in $(seq $NITER); do
						runcmd "$P" "none" "$name" "$args"
						val=$(errcheck $? "log")
						avg=$( echo "scale=2; $avg + $val" | bc )
				done
				avg=$( echo "scale=2; $avg / $NITER" | bc )
				printf "\t%s" "$avg"

				avg=0
				for i in $(seq $NITER); do
						runcmd "$P" "record" "$name" "$args"
						val=$(errcheck $? "log")
						avg=$( echo "scale=2; $avg + $val" | bc )
				done
				avg=$( echo "scale=2; $avg / $NITER" | bc )
				printf "\t%s" "$avg"

				runreplay "$name" "$args"
				printf "\n"
		done
    printf "\n-------------------------"
    set -e
}

if [ $# -gt 0 ]; then
    bench=($1)
fi

for b in "${bench[@]}"; do
    make -j "$b"
    runall "$b" "${args[$b]}"
done
