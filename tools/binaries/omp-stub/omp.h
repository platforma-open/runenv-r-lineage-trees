/* Single-threaded stand-in for the OpenMP runtime, used for the macOS IgPhyML
 * build. zig's clang has no libomp for macOS and IgPhyML calls omp_get_wtime
 * and a lock unconditionally, so without this it does not link. The pragmas
 * are ignored without -fopenmp, so the program runs on one thread and
 * --threads has no effect. */
#ifndef LINEAGE_TREES_OMP_STUB_H
#define LINEAGE_TREES_OMP_STUB_H

#include <time.h>

typedef int omp_lock_t;

static inline double omp_get_wtime(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}
static inline void omp_set_dynamic(int v) { (void)v; }
static inline void omp_set_num_threads(int n) { (void)n; }
static inline int omp_get_num_threads(void) { return 1; }
static inline int omp_get_thread_num(void) { return 0; }
static inline void omp_init_lock(omp_lock_t *l) { (void)l; }
static inline void omp_destroy_lock(omp_lock_t *l) { (void)l; }
static inline void omp_set_lock(omp_lock_t *l) { (void)l; }
static inline void omp_unset_lock(omp_lock_t *l) { (void)l; }

#endif
