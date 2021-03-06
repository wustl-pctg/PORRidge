#include "porr.h"
#include <sstream>
#include <cstdio>
#include <fstream>
#include <cstring> // memset

namespace porr {

// Initialize static thread locals
__thread size_t acquire_container::t_index = 0;
__thread acquire_container::chunk_t* acquire_container::t_first_chunk = nullptr;
__thread acquire_container::chunk_t* acquire_container::t_current_chunk = nullptr;

std::string get_pedigree_str() {
  acquire_info tmp = acquire_info(get_pedigree());
  return tmp.str();
}

acquire_info::acquire_info(pedigree_t p) : ped(p) {}
acquire_info::acquire_info(pedigree_t p, full_pedigree_t f)
: ped(p), full(f) {}

std::string acquire_info::array_str() {
  full_pedigree_t p = full;
  std::string s = "[";
  for (int i = 0; i < p.length; ++i)
    s += std::to_string(p.array[i]) + ",";
  s += "]";
  return s;
}

// We don't really care about speed here, maybe reeval later.
std::string acquire_info::str() {
  std::string s = std::to_string(ped);
  if (full.length > 0)
    s += array_str();
  return s;
}
  
std::ostream& operator<< (std::ostream &out, acquire_info s) {
  out << s.str();
  return out;
}

acquire_container::acquire_container(acquire_info** start_ptr) {
  enum mode m = g_rr_state->m_mode;
  if (m == NONE) return;

  acquire_info *first;
  if (m == RECORD) {
    first = new_acquire_info();
    memset(first, 0, sizeof(acquire_info));
    *start_ptr = first;
		m_size = 0;
  } else {
    first = *start_ptr;
    // We may have locks that are initialized but never used...
    if (first) {
      m_size = first->full.length;
      first = first->next;
    }

    // Using array to search
    m_start = first;
  }
  m_it = first;

	// Either clang has a bug or there's something weird about mixing C
	// and C++ code that does not accept my initializer (in
	// acquire.h). Probably the latter.
	m_index = 0;
}

#if PTYPE == PARRAY
size_t acquire_container::hash(full_pedigree_t k) {
  size_t h = 0;
  for (int i = 0; i < k.length; ++i)
    h += g_rr_state->randvec[i] * k.array[i];
  return h;
}
#endif

// This is only called by the internal rrmutex, and it's okay to not find it (trylock).
acquire_info* acquire_container::find(full_pedigree_t& p) {
  for (acquire_info* a = &m_start[m_index]; a != &m_start[m_size]; ++a) {
    if (a->full == p) {
      delete p.array;
      return a;
    }
  }
  return nullptr;
}

acquire_info* acquire_container::find(const pedigree_t& p) {
  size_t num_matches = 0;
  acquire_info* first_match = nullptr;

  // Simple search (use a->next in loop)
  acquire_info* it = m_it;

  full_pedigree_t full;
  for (acquire_info *a = &m_start[m_index]; a != &m_start[m_size]; ++a) {
    if (a->ped == p) {
      num_matches++;
      if (num_matches == 1)
        first_match = a;
      else {
        if (num_matches == 2)
          full = get_full_pedigree();
        if (a->full == full) {
          free(full.array);
          return a;
        }
      }
    }
  }
  // if (num_matches == 0) {
  //   fprintf(stderr, "Error: %zu not found!\n", p);
  //   std::exit(1);
  // }
  return first_match;
}

acquire_info* acquire_container::new_acquire_info()
{
  if (t_first_chunk == nullptr) {
    t_first_chunk = t_current_chunk = new chunk();
    assert(t_first_chunk);
    t_first_chunk->size = RESERVE_SIZE;
    t_first_chunk->next = nullptr;
    t_first_chunk->array = (acquire_info*)
      malloc(RESERVE_SIZE * sizeof(acquire_info));
    assert(t_first_chunk->array);
    t_current_chunk = t_first_chunk;
    return &t_first_chunk->array[t_index++];
  }

  acquire_info *a = &t_current_chunk->array[t_index++];


  size_t current_size = t_current_chunk->size;
  if (t_index >= current_size) {

    t_index = 0;
    if (current_size < MAX_CHUNK_SIZE)
      current_size *= 2;
    t_current_chunk = t_current_chunk->next = new chunk();
    t_current_chunk->size = current_size;
    t_current_chunk->next = nullptr;
    t_current_chunk->array = (acquire_info*)
      malloc(current_size * sizeof(acquire_info));
  }
    
  return a;
}

acquire_info* acquire_container::add(pedigree_t p, full_pedigree_t full) {
  return new(new_acquire_info()) acquire_info(p, full);
}

acquire_info* acquire_container::add_fake(full_pedigree_t full) {
  acquire_info *a = new(new_acquire_info()) acquire_info(0, full);
  m_size++;
  m_it = m_it->next = a;
  return a;
}

acquire_info* acquire_container::add(pedigree_t p) {

  acquire_info *a = new(new_acquire_info()) acquire_info(p);
  m_size++;
  
#if PTYPE == PARRAY
  a->full = get_full_pedigree();
#else
    
  size_t num = p & (m_filter_size - 1);
  size_t index = num / bits_per_slot;
  size_t bit = 1 << (num - (index * bits_per_slot));

  uint64_t* filter = (m_filter_size > DEFAULT_FILTER_SIZE)
    ? m_filter
    : (uint64_t*)&m_filter_base;

  if (filter[index] & bit) {
    a->full = get_full_pedigree();
  } else
    filter[index] |= bit;

#if RESIZE == 1
  resize filter
    if (m_num_conflicts > __builtin_ctzl(m_filter_size)) {
      if (m_num_conflicts > (m_filter_size >> 2)) {
        if (m_filter_size > DEFAULT_FILTER_SIZE)
          free(m_filter);

        m_resizes++;

        m_filter_size <<= 1;
        m_filter = (uint64_t*) calloc(m_filter_size / bits_per_slot,
                                      sizeof(uint64_t));
      
        acquire_info *a = m_first;
        uint64_t mask = m_filter_size - 1;
        while (a) {
          num = a->ped & mask;
          index = num / bits_per_slot;
          bit = 1 << (num - (index * bits_per_slot));
          m_filter[index] |= bit;
        
          a = a->next;
        }
      }
#endif // resize
#endif
    
      m_it = m_it->next = a;

      assert(m_it->next != m_it);
      return a;
    }

}

