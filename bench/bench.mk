# This file defins BASIC_CFLAGS, BASIC_CXXFLAGS, LDFLAGS, LDLIBS, TOOL_FLAGS, TOOL_LDFLAGS
# Makefile including this file should use these flags

CURR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
PORR_HOME = $(CURR)/..
BENCH_DIR = $(PORR_HOME)/bench
include $(PORR_HOME)/config.mk
#COMPILER_HOME = $(PORR_HOME)/llvm-cilk
CILKRTS_HOME = $(PORR_HOME)/llvm-cilk

CC = $(COMPILER_HOME)/bin/clang
CXX = $(COMPILER_HOME)/bin/clang++

ifeq ($(PORR), 1)
    PORR_CFLAGS = -DPORR -fcilk-no-inline
    PORR_LIBS = $(PORR_HOME)/build/libporr.a
else
    PORR_CFLAGS = -fcilk-no-inline
endif

INC += -I$(COMPILER_HOME)/include -I$(RUNTIME_HOME)/include
INC += -I$(BENCH_DIR) -I$(PORR_HOME)/src
LDFLAGS = -lrt -ldl -lpthread -ltcmalloc
ARFLAGS = rcs
OPT ?= -O0 #-O3 -march=native -DNDEBUG

LTO ?= 1
ifeq ($(LTO),1)
  OPT += -flto
	LDFLAGS += -flto
	ARFLAGS += --plugin $(COMPILER_HOME)/lib/LLVMgold.so
endif

LIBS += $(PORR_LIBS)
ifeq ($(rr),rts)
  LIBS += $(CILKRTS_HOME)/lib/libcilkrtsrr.a
  PORR_CFLAGS += -DCILKRTSRR

  # cilkrtsrr and porr (with rr=rts) actually depend on each other, so
  # need to add PORR_LIBS (libporr.a) again here...
  LIBS += $(PORR_LIBS)
  LIBS += $(CILKRTS_HOME)/lib/libcilkrtsrr.a
else
  LIBS += $(CILKRTS_HOME)/lib/libcilkrts.a
endif


BASIC_FLAGS = $(OPT) -g -fcilkplus $(PORR_CFLAGS) $(INC) #-Wfatal-errors
BASIC_CFLAGS += $(BASIC_FLAGS) -std=gnu11
BASIC_CXXFLAGS = $(BASIC_FLAGS) -std=gnu++11
