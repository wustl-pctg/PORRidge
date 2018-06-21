include test.mk

TESTS = trylock

default: $(TESTS)

trylock: trylock.o

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $<

clean:
	rm -rf *.o $(TESTS)
