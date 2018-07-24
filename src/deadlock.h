// Basic spinlock that does NOT suspend/resume, e.g. may deadlock unless used with a special runtime system
#include <pthread.h>
#include "porr.h"

namespace porr {

  class deadlock {
  private:
    base_lock_t m_lock;

    // Record/Replay fields
    acquire_container m_acquires;
            
    void record_acquire(pedigree_t& p);
    void replay_lock(pedigree_t& p);
    void replay_unlock();
		void replay_wait(acquire_info *a);

    inline void init(uint64_t id);

  public:
    deadlock();
    deadlock(uint64_t index);
    ~deadlock();

    void lock();
    void unlock();

  };

}
