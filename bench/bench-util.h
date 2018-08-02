#ifdef PORR
#include <porr.h>

#ifdef CILKRTSRR
#include <deadlock.h>
typedef porr::deadlock lock_t;
#else
#include <spinlock.h>
typedef porr::spinlock lock_t;
#endif

inline void lock_init(lock_t *l, int i) { new (l) lock_t(i); }
inline void lock_destroy(lock_t *l) { l->~lock_t(); }
inline void lock(lock_t *l) { l->lock(); }
inline void unlock(lock_t *l) { l->unlock(); }

#else
#include <pthread.h>
typedef pthread_spinlock_t lock_t;

// We should probably handle errors here...
inline void lock_init(lock_t *l, int i) { pthread_spin_init(l, PTHREAD_PROCESS_PRIVATE); }
inline void lock_destroy(lock_t *l) { pthread_spin_destroy(l); }
inline void lock(lock_t *l) { pthread_spin_lock(l); }
inline void unlock(lock_t *l) { pthread_spin_unlock(l); }

#endif
