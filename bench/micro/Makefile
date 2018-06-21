# Should use ../bench.mk, but that file needs some updates.
include ../../common.mk

ifeq ($(STATS),1)
	LDFLAGS += -lpapi
endif
LIBS += $(LIBNAME) $(CILKRTS_HOME)/lib/libcilkrts.a
APPFLAGS = -I$(PORR_HOME)/src $(CILKFLAGS)
LDLIBS := $(LIBS) -lrt $(LDLIBS)

CFLAGS += $(APPFLAGS)
CXXFLAGS += $(APPFLAGS)

BENCH = fib cilkfor cbt
default: $(BENCH)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $<

clean:
	rm -f *.o $(BENCH)
