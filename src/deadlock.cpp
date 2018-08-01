#include "deadlock.h"

#include <cassert>
#include <cstdio>

namespace porr {

void deadlock::init(uint64_t id) { base_lock_init(&m_lock, id); }

deadlock::deadlock()
  : m_acquires(g_rr_state->register_spinlock()) {
  init(0); // not correct
}

deadlock::deadlock(uint64_t id)
  : m_acquires(g_rr_state->register_spinlock(id)) {
  init(id);
}

deadlock::~deadlock() {
  base_lock_destroy(&m_lock);
  g_rr_state->unregister_spinlock(m_acquires.m_size);
}

void deadlock::lock() {
  enum mode m = get_mode();
  pedigree_t p;
  if (m != NONE) p = get_pedigree();

  if (m == REPLAY) replay_lock(p);
  else base_lock(&m_lock);

  if (m == RECORD) record_acquire(p);
}

void deadlock::unlock() {
  enum mode m = get_mode();
  if (m == REPLAY) replay_unlock();

  base_unlock(&m_lock);

  if (m != NONE) __cilkrts_bump_worker_rank();
}

bool deadlock::try_lock() { assert(0); }

void deadlock::record_acquire(pedigree_t& p) { m_acquires.add(p); }

void deadlock::replay_wait(acquire_info *a) {
  acquire_info *volatile front = nullptr;
  while (front != a)
    front = m_acquires.current();
}

void deadlock::replay_lock(pedigree_t& p) {
  acquire_info *a = m_acquires.find((const pedigree_t)p);
  if (!a) {
    fprintf(stderr, "Ped %lu not found for main lock!\n", p);
  }
  assert(a);
  replay_wait(a);
}

void deadlock::replay_unlock() {
  acquire_info *front = m_acquires.current();
  if (front) m_acquires.next();
}

}
