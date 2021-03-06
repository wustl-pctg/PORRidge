// Basic test of spinlock record and replay functionality.
#ifdef USE_CILKRTSRR
#include "deadlock.h"
using spinlock_t = porr::deadlock;
#else
#include "spinlock.h"
using spinlock_t = porr::spinlock;
#endif

#include <cstdio>

#include <cilk/cilk.h>
#include <cilk/cilk_api.h>

spinlock_t g_mutex;
int g_val = 0;
int g_prev_i = -1;

void loop(int n) {
#pragma cilk grainsize = 1
  cilk_for (int i = 0; i < n; ++i) {
		g_mutex.lock();
		g_val += g_prev_i * i;
		g_prev_i = i;
		g_mutex.unlock();
	}
}

// spinlock [# threads]
int main(int argc, char *argv[]) {
  size_t inner = (argc > 1) ? std::strtoul(argv[1], nullptr, 0) : 4096;
	size_t outer = (argc > 2) ? std::strtoul(argv[2], nullptr, 0) : 8;

	for (int i = 0; i < outer; ++i) {
		//fprintf(stderr, "Iter %i\n", i);
		loop(inner);
	}
	printf("Result: %i\n", g_val);
  return 0;

}
