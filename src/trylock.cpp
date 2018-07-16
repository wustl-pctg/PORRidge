#include "trylock.h"
#include <cstdio>
#include <iostream>
#include <cassert>
#include <cstring>

#ifndef FAKE_ATOMIC
#include <atomic>
#define MEM_FENCE std::atomic_thread_fence(std::memory_order_seq_cst)
#define LOAD_FENCE std::atomic_thread_fence(std::memory_order_acquire)
#define STORE_FENCE std::atomic_thread_fence(std::memory_order_release)
#define FAA(loc, val) __sync_fetch_and_add(loc, val)
#else
#define MEM_FENCE
#define LOAD_FENCE
#define STORE_FENCE
#define FAA(loc, val) (loc += val)
#endif

#include <internal/abi.h>
#include "cilk/cilk_api.h"

namespace porr {

  void trylock::init(uint64_t id) {base_lock_init(&m_lock, id);}
  trylock::trylock()
    : m_acquires(g_rr_state->register_spinlock())
  {
    init(0);
  }

  trylock::trylock(uint64_t id)
    : m_acquires(g_rr_state->register_spinlock(id))
  {
    init(id);
  }
  
  trylock::~trylock(){
    base_lock_destroy(&m_lock);
    g_rr_state->unregister_spinlock(m_acquires.m_size);
  }

   inline void trylock::acquire()
  {
#ifdef DEBUG_ACQUIRE
    m_owner = __cilkrts_get_tls_worker();
#endif
#ifdef PORR_STATS
    m_num_acquires++;
#endif
    //m_checking = 0;
    //    m_passed = false;
  }

    inline void trylock::release()
  {
#ifdef DEBUG_ACQUIRE
    m_owner = nullptr;
    m_active = nullptr;
#endif
    base_unlock(&m_lock);
  }

  void trylock::lock(){
    enum mode m = get_mode();
    pedigree_t p;
    if(m  != NONE) p = get_pedigree();

    if(get_mode() == REPLAY) {
      replay_lock(m_acquires.find((const pedigree_t) p));
    } else
      base_lock(&m_lock);

    acquire();
    if(get_mode() == RECORD) record_acquire(p);
  }
  //**************
  bool trylock::try_lock(){
    enum mode m = get_mode();
    pedigree_t p;
    if(m != NONE){
      p = get_pedigree();
      
    }

    //t_counter stores the number of failed lock acquire attempts
    static __thread int t_fail_counter = 0;
    bool lock_available = false;

    while(!lock_available){
      ++t_fail_counter;
    }
    
    //write t_counter to acquire    
    //t_fail_counter = 0;

    if(get_mode() == REPLAY){
      replay_lock(m_acquires.find((const pedigree_t) p));
    } else {
      base_lock(&m_lock);
    }

    if (get_mode() == RECORD) record_acquire(p);
    return lock_available;
  }
  
  void trylock::unlock(){
    if(get_mode() == REPLAY) replay_unlock();
    else
      release();
    if(get_mode() != NONE)
      __cilkrts_bump_worker_rank();
  }

  void trylock::record_acquire(pedigree_t& p){
    acquire_info *a = m_acquires.add(p);
#ifdef DEBUG_ACQUIRE
    m_active = a;
#endif
  }

  void trylock::replay_lock(acquire_info* a){
    acquire_info *front = m_acquires.current();;
    void *deque = __cilkrts_get_deque();

    while(front->t_fail_counter != 0){
      if(front == a || FAA(&a->suspended_deque, deque)){
	base_lock(&m_lock);
      }
      
      a->suspended_deque = deque;
      LSTAT_INC(LSTAT_SUS);
      __cilkrts_suspend_deque();

      front->t_fail_counter--;
    }
  }

  void trylock::replay_unlock(){
    void *deque = nullptr;
    acquire_info *front = m_acquires.current();
    if(!front || !front->next)
      return release();
    front = m_acquires.next();

    deque = FAA(&front->suspended_deque, (void*)0x1);
    if(deque){
      __cilkrts_resume_suspended(deque, 1);
    }else{
      release();
    }
  }
}
