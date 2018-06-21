#include "trylock.h"

namespace porr {

  trylock::trylock() { base_lock_init(&m_lock, 0); }
  trylock::~trylock() { base_lock_destroy(&m_lock); }
	
  void trylock::lock() { base_lock(&m_lock); }
  bool trylock::try_lock() { return base_trylock(&m_lock); }
  void trylock::unlock() { base_unlock(&m_lock); }

}
