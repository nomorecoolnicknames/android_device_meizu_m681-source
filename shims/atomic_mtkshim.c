/* libatomic_mtkshim - legacy libcutils android_atomic_* family for MTK vendor
 * blobs (Oreo made these static-inline; pre-Lollipop blobs import them).
 * All operate on 32-bit int; return the PRIOR value (inc/dec/add/and/or). */
typedef int int32_t;  /* int is 32-bit on arm/arm64 ABIs; avoids needing a sysroot */

int32_t android_atomic_inc(volatile int32_t* a){ return __atomic_fetch_add(a, 1, __ATOMIC_RELEASE); }
int32_t android_atomic_dec(volatile int32_t* a){ return __atomic_fetch_sub(a, 1, __ATOMIC_RELEASE); }
int32_t android_atomic_add(int32_t v, volatile int32_t* a){ return __atomic_fetch_add(a, v, __ATOMIC_RELEASE); }
int32_t android_atomic_and(int32_t v, volatile int32_t* a){ return __atomic_fetch_and(a, v, __ATOMIC_RELEASE); }
int32_t android_atomic_or (int32_t v, volatile int32_t* a){ return __atomic_fetch_or (a, v, __ATOMIC_RELEASE); }

int32_t android_atomic_load(volatile const int32_t* a){ return __atomic_load_n(a, __ATOMIC_SEQ_CST); }
int32_t android_atomic_acquire_load(volatile const int32_t* a){ return __atomic_load_n(a, __ATOMIC_ACQUIRE); }
int32_t android_atomic_release_load(volatile const int32_t* a){ return __atomic_load_n(a, __ATOMIC_SEQ_CST); }

void android_atomic_store(int32_t v, volatile int32_t* a){ __atomic_store_n(a, v, __ATOMIC_SEQ_CST); }
void android_atomic_acquire_store(int32_t v, volatile int32_t* a){ __atomic_store_n(a, v, __ATOMIC_SEQ_CST); }
void android_atomic_release_store(int32_t v, volatile int32_t* a){ __atomic_store_n(a, v, __ATOMIC_RELEASE); }

/* android_atomic_*cas: return 0 on success (value swapped), nonzero on failure. */
int android_atomic_cas(int32_t oldv, int32_t newv, volatile int32_t* a){
    return !__atomic_compare_exchange_n(a, &oldv, newv, 0, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST); }
int android_atomic_acquire_cas(int32_t oldv, int32_t newv, volatile int32_t* a){
    return !__atomic_compare_exchange_n(a, &oldv, newv, 0, __ATOMIC_ACQUIRE, __ATOMIC_ACQUIRE); }
int android_atomic_release_cas(int32_t oldv, int32_t newv, volatile int32_t* a){
    return !__atomic_compare_exchange_n(a, &oldv, newv, 0, __ATOMIC_RELEASE, __ATOMIC_RELAXED); }
int32_t android_atomic_cmpxchg(int32_t oldv, int32_t newv, volatile int32_t* a){
    return !__atomic_compare_exchange_n(a, &oldv, newv, 0, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST); }
