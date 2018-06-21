// Basic test of trylock record and replay functionality.
#include "trylock.h"
#include <iostream>

#include <cilk/cilk.h>
#include <cilk/cilk_api.h>


porr::trylock g_mutex;
int g_val = 0;

// trylock [# threads] [# trylock attempts]
int main(int argc, char *argv[]) {
  size_t num_threads = (argc > 1) ? std::strtoul(argv[1], nullptr, 0) : 4096;
  size_t num_attempts = (argc > 2) ? std::strtoul(argv[2], nullptr, 0) : 3;

#pragma cilk grainsize = 1
  cilk_for (int i = 0; i < num_threads; ++i) {
    int fail_count = 0;

    while (fail_count++ < num_attempts) {

      if (g_mutex.try_lock()) { // success path
	g_val += fail_count * __cilkrts_get_worker_number();
      } else { // fail path
	// do nothing, fail_count is already incremented
      }
    }
  }
  std::cout << "Result: " << g_val << std::endl;
  return 0;

}
