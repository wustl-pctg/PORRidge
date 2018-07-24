// Basic test of spinlock record and replay functionality.

#ifdef USE_CILKRTSRR
#include "deadlock.h"
using spinlock_t = porr::deadlock;
#else
#include "spinlock.h"
using spinlock_t = porr::spinlock;
#endif

#include <iostream>

#include <cilk/cilk.h>
#include <cilk/cilk_api.h>

spinlock_t g_mutex;
int g_val = 0;
int g_prev_i = -1;

// spinlock [# threads]
int main(int argc, char *argv[]) {
  size_t num_threads = (argc > 1) ? std::strtoul(argv[1], nullptr, 0) : 4096;

#pragma cilk grainsize = 1
  cilk_for (int i = 0; i < num_threads; ++i) {

		g_mutex.lock();
		g_val += g_prev_i * i;
		g_prev_i = i;
		g_mutex.unlock();
	}
  std::cout << "Result: " << g_val << std::endl;
  return 0;

}
