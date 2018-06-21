include ../common.mk

OBJ = spinlock.o porr.o acquire.o trylock.o
.SECONDARY: $(OBJ)

.PHONY: default
default: $(LIBNAME)

%.a: $(OBJ)
	$(AR) $(ARFLAGS) $@ $^

# CILKFLAGS only needed to access the Cilk API without compiler error.
%.o: %.cpp %.h util.h
	$(CXX) $(CXXFLAGS) $(CILKFLAGS) -c $(*:=.cpp)

clean:
	rm -f *.o
	rm -f ../build/*.a
