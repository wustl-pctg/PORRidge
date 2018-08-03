#!/bin/bash
#set -x
T=20

for N in 2 4 8 16; do
 		export CILK_NWORKERS=$N
		printf "N=$N:\t"
 		for i in {1..100}; do
				for m in record replay; do
   					PORR_MODE=$m timeout $T ./spinlock &> ${m}.log;
						ret=$?
						if [[ "$ret" -ne 0 ]]; then
									 if [[ "$ret" -eq 124 ]]; then printf "\nTimeout "; else printf "\nCrash "; fi
									 printf "during $m\n"
									 exit
   					fi
   			printf "."
				done
   	done
  	printf "\nFinished with $N\n"
done

