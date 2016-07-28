#include "mutex.h"
#include <cstdio>
#include <iostream>
#include <cassert>

#include <atomic>
#define MEM_FENCE std::atomic_thread_fence(std::memory_order_seq_cst)
#define LOAD_FENCE std::atomic_thread_fence(std::memory_order_acquire)
#define STORE_FENCE std::atomic_thread_fence(std::memory_order_release)

#include <internal/abi.h>
#include "cilk/cilk_api.h"

namespace cilkrr {

  mutex::mutex()
  {
    m_id = g_rr_state->register_mutex();
    pthread_spin_init(&m_lock, PTHREAD_PROCESS_PRIVATE);

    if (get_mode() != NONE)
      m_acquires = g_rr_state->get_acquires(m_id);
  }

  mutex::mutex(uint64_t index)
  {
    m_id = g_rr_state->register_mutex(index);
    pthread_spin_init(&m_lock, PTHREAD_PROCESS_PRIVATE);
    
    if (get_mode() != NONE)
      m_acquires = g_rr_state->get_acquires(m_id);
  }

  mutex::~mutex()
  {
    pthread_spin_destroy(&m_lock);
    g_rr_state->unregister_mutex(m_id);
  }

  inline void mutex::acquire()
  {
#ifdef DEBUG_ACQUIRE
    m_owner = __cilkrts_get_tls_worker();
#endif
  }
  
  inline void mutex::release()
  {
#ifdef DEBUG_ACQUIRE
    m_owner = nullptr;
    m_active = nullptr;
#endif
    pthread_spin_unlock(&m_lock);
  }

  void mutex::lock()
  {
    enum mode m = get_mode();
    pedigree_t p;
    if (m != NONE) p = get_pedigree();
    
    if (get_mode() == REPLAY) {
      // returns locked, but not acquired
      replay_lock(m_acquires->find((const pedigree_t)p));
    } else {
      pthread_spin_lock(&m_lock);
    }
    acquire();
    if (get_mode() == RECORD) record_acquire(p);
  }

  bool mutex::try_lock()
  {
    fprintf(stderr, "try_lock not implemented for CILKRR\n");
    std::abort();
    pthread_spin_trylock(&m_lock);
  }

  void mutex::unlock()
  {
    if (get_mode() == REPLAY) replay_unlock();
    else release();
    if (get_mode() != NONE)
      __cilkrts_bump_worker_rank();
  }

  void mutex::record_acquire(pedigree_t& p)
  {
    acquire_info *a = m_acquires->add(p);
#ifdef DEBUG_ACQUIRE
    m_active = a;
#endif
  }

  void mutex::replay_lock(acquire_info* a)
  {
    // perf debug
    // m_mutex.lock();
    // return;
    // end perf debug
    
    a->suspended_deque = __cilkrts_get_deque();
    MEM_FENCE;

    acquire_info *front = m_acquires->current();
    if (front == a) {

      while (m_checking) ;
      LOAD_FENCE;
      if (front->suspended_deque) {
        front->suspended_deque = nullptr;
        //m_mutex.lock();
        pthread_spin_lock(&m_lock);
        return; // continue
      }
    }
    __cilkrts_suspend_deque();
  }

  void mutex::replay_unlock()
  {
    // for performance debugging
    // m_acquires->next();
    // release();
    // return;
    // end perf
    
    void *deque = nullptr;
    m_checking = true;
    m_acquires->next();
    acquire_info *front = m_acquires->current();
    MEM_FENCE;

    if (front && front->suspended_deque) {
      deque = front->suspended_deque;
      front->suspended_deque = nullptr;
      STORE_FENCE;
    }
    m_checking = false;
    if (deque)
      __cilkrts_resume_suspended(deque, 1);
    else
      release();

  }

}
