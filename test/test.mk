# Compilation flags for tests
# Makefile should include this file
THIS_DIR=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))
include ../common.mk

LIBS += $(LIBNAME) $(CILKRTS_HOME)/lib/libcilkrts.a

APPFLAGS = -I$(PORR_HOME)/src $(CILKFLAGS)
LDLIBS := $(LIBS) -lrt $(LDLIBS)
CFLAGS += $(APPFLAGS) 
CXXFLAGS += $(APPFLAGS)
