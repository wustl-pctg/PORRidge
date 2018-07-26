#ifndef _CILKRR_H
#define _CILKRR_H

#include <string>
#include <atomic>
#include <limits>
#include <fstream>

#include "util.h"
#include "acquire.h"

namespace porr {
  
class state {
public:
	template <class T>
	class achunk {
	public:
		size_t size;
		achunk* next = nullptr;
		T* data;
		
		achunk() = delete;
    achunk(size_t _size) : size(_size)
		{ data = (T*) malloc(sizeof(T) * size); }
	};

private:
	size_t num_digits(size_t num);
	
#define CHUNK_TYPE acquire_info*
	achunk<CHUNK_TYPE> *m_current_chunk = nullptr;
	union {
		achunk<CHUNK_TYPE> *m_first_chunk; // recording only
		acquire_info* m_acquires;// replay only
	};
	// Replay hash tables
	//acquire_info** m_tables = nullptr;

	// replay only
	size_t m_curr_base_index = 0;
	size_t m_next_base_index = 0;
    
	std::string m_filename;
	size_t m_num_locks = 0;
	uint64_t m_num_acquires = 0;

public:
	enum mode m_mode = NONE;

	state();
	~state();
	void reserve(size_t n);
    
	CHUNK_TYPE* register_spinlock(); // For individual, sequentially allocated spinlocks
	CHUNK_TYPE* register_spinlock(size_t id); // For batches of spinlocks
	void unregister_spinlock(size_t size);
	std::pair<size_t,uint64_t> output_chunks(std::ofstream& output, achunk<CHUNK_TYPE> *first_chunk);
	std::pair<size_t,uint64_t> read_log(std::ifstream& input, achunk<CHUNK_TYPE>*& chunk, acquire_info*& acquires);
};
extern state *g_rr_state;
inline enum mode get_mode() { return g_rr_state->m_mode; }
void reserve_locks(size_t n);

}

#endif // ifndef _CILKRR_H
