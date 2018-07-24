include test.mk

TESTS = trylock spinlock

default: $(TESTS)

trylock: trylock.o
spinlock: spinlock.o

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $<

clean:
	rm -rf *.o $(TESTS)
