BASE_DIR=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))
include $(BASE_DIR)/config.mk

PORR_HOME = $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
CILKRTS_HOME = $(PORR_HOME)/llvm-cilk

CC := $(COMPILER_HOME)/bin/clang++
CXX := $(COMPILER_HOME)/bin/clang++
LIBNAME = $(BUILD_DIR)/libporr.a

INC = -I$(RUNTIME_HOME)/include
LDLIBS = -ldl -lpthread -ltcmalloc
ARFLAGS = rcs
OPT = -O3 #-march=native -DNDEBUG

STATS ?= 0
PTYPE ?= 1
STAGE ?= 4
DEFS = -DPTYPE=$(PTYPE) -DSTAGE=$(STAGE) -DSTATS=$(STATS)

LTO ?= 1
ifeq ($(LTO),1)
	OPT += -flto
	LDFLAGS += -flto
	ARFLAGS += --plugin $(COMPILER_HOME)/lib/LLVMgold.so
endif

FLAGS = -g -Wfatal-errors -Werror $(OPT) $(DEFS) $(INC)
CFLAGS = $(FLAGS) -std=c11
CXXFLAGS := $(FLAGS) -std=c++11 
CILKFLAGS := -fcilkplus -fcilk-no-inline
