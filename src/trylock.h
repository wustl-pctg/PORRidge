// A trylock that can record its successes and failures.
// Currently unimplemented.

#include <pthread.h>
#include "porr.h"

namespace porr {

  class trylock {
  private:
    base_lock_t m_lock;

/* #ifdef DEBUG_ACQUIRE */
/*     __cilkrts_worker *m_owner = nullptr; */
/*     acquire_info volatile *m_active = nullptr; */
/* #endif */
/* #ifdef PORR_STATS */
/*     uint64_t m_num_acquires; */
/*     //uint64_t m_id; */
/* #endif */

/*     // Record/Replay fields */
/*     acquire_container m_acquires; */
/*     /\* char pad[32]; *\/ */
            
    /* void record_acquire(pedigree_t& p); */
    /* void replay_lock(acquire_info *a); */
    /* void replay_unlock(); */

    /* inline void acquire(); */
    /* inline void release(); */
    /* inline void init(uint64_t id); */

  public:
    trylock();
    //trylock(uint64_t index);
    ~trylock();

    void lock();
    void unlock();
    bool try_lock();

  };// __attribute__((aligned(64)));

}
