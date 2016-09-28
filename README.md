# Processor Obvivious Record and Replay

A runtime system to deterministically record lock acquires and replay
them on an arbitrary number of cores. Currently, you need to build the
library and link it statically, although there is no technical reason
why this couldn't be a dynamically-loaded library.

This library relies on modifications to the Cilk runtime library
(provided in the cilkrtssuspend directory), as well as a special
compiler that won't inline some Cilk helper functions. You can find
such a compiler [here](https://gitlab.com/wustl-pctg/llvm-cilk).

Currently, the provided interface is basically that of
pthread_spinlock, so just replace calls to pthread_spinlock_<func>
with porr::spinlock::<func>. That namespace will probably change.

By default, once you've linked, nothing will actually happen. You'll
need to set the environment variable CILKRR_MODE to tell the library
to either record or replay. You can record with

    PORR_MODE=record ./prog

which will write out the results to ".cilkrecord". Later, the filename
will be customizable with an environment variable. To replay, use

	PORR_MODE=replay ./prog

You'll need to define a "config.mk" file at the top-level. Example file:

	BUILD_DIR=$(BASE_DIR)/build
	RUNTIME_HOME=$(BASE_DIR)/cilkrtssuspend
	COMPILER_HOME=$(HOME)/src/llvm-cilk
	RTS_LIB=$(COMPILER_HOME)/lib/libcilkrts.a
	LTO=0


## TODO

* Implement porr::spinlock::trylock
* Add porr::mutex -- no record/replay, but locking failure suspends the fiber
