/*
 * libsfleaktrack - name the call site that retains imported graphics buffers.
 *
 * WHY THIS SHAPE
 * --------------
 * The defect (docs/LANE_SF_BUFFER_LEAK_20260729.md) is that SurfaceFlinger
 * never releases imported graphics buffers: ~7 full-screen buffers / ~56 MB are
 * lost per app launch, `GraphicBufferMapper::freeBuffer` is never called for
 * them, and because every MTK graphics blob shares AOSP's single ION client
 * inside that one process, no readout from OUTSIDE the process can tell
 * "AOSP SF holds it" from "an MTK blob inside SF holds it".
 *
 * This library answers that from inside the process WITHOUT modifying
 * libui.so. It is LD_PRELOADed into surfaceflinger only, and interposes four
 * global (and therefore preemptible - libui.so carries no DT_SYMBOLIC) symbols.
 *
 * ⚠ BOTH ENTRY PATHS, on purpose. A buffer reaches this process two ways, and
 * an instrument watching only one returns a clean-looking zero for a leak in
 * the other:
 *
 *   IMPORTED - produced by an app, unflattened from binder into SF:
 *     _ZN7android19GraphicBufferMapper12importBufferEPK13native_handlejjjimjPS3_
 *     _ZN7android19GraphicBufferMapper10freeBufferEPK13native_handle
 *
 *   ALLOCATED - SF makes it itself. SurfaceFlinger.cpp:5122 does
 *   `*outBuffer = new GraphicBuffer(...)` for every screen capture, so the
 *   8.36 MB that §1 measured leaking per `screencap` is an ALLOCATION, not an
 *   import, and hooking only the mapper would have reported live=0 for it:
 *     _ZN7android22GraphicBufferAllocator8allocateEjjijmPPK13native_handlePjmNSt3__1...
 *     _ZN7android22GraphicBufferAllocator4freeEPK13native_handle
 *
 * On a successful import/allocate we record handle -> backtrace; on the
 * matching free we erase it. The survivors, grouped by backtrace and tagged
 * IMPORT or ALLOC, ARE the leak, and their stack names the retaining call site
 * and the library it lives in.
 *
 * NOTE - check this first, it is free: GraphicBufferAllocator already keeps
 * sAllocList of everything THIS process allocated, and SurfaceFlinger.cpp:4562
 * already dumps it. So `dumpsys SurfaceFlinger` alone may already name the
 * requestor of the allocated leaks, with no instrument deployed at all. Deploy
 * this when that readout does not settle it, or to get backtraces and to cover
 * the imported path, which sAllocList does not see.
 *
 * BLAST RADIUS
 * ------------
 * One process. Patching libui.so instead would put new code in every process on
 * the device, where a bad build is a non-booting phone and recovery on this
 * device means the user holding buttons.
 *
 * ROLLBACK - read this before deploying.
 * An LD_PRELOAD entry that cannot be loaded is FATAL, not a warning: bionic
 * appends preloads to the same list as DT_NEEDED and calls
 * __linker_cannot_link() if any of them fails
 * (bionic/linker/linker_main.cpp:405-419). So deleting this .so does NOT undo
 * the change - it stops surfaceflinger from starting at all. The rollback is
 * restoring /system/etc/init/surfaceflinger.rc; keep a backup of it, install
 * the .so BEFORE editing the .rc, and never remove the .so while the .rc still
 * names it. The failure stays inside surfaceflinger - init and adbd survive -
 * but on this device a framework restart also drops the USB gadget, so treat
 * "recoverable over adb" as thin cover and pre-flight instead (see below).
 *
 * PRE-FLIGHT (no /system write beyond placing this file, no risk to SF)
 *   setprop debug.sfleak.enable 1
 *   LD_PRELOAD=/system/lib64/libsfleaktrack.so screencap /data/local/tmp/x.png
 *   setprop debug.sfleak.dump 1
 * Preload from /system/lib64, the same path surfaceflinger.rc will name, so a
 * pass is evidence about the real deployment and not about a copy elsewhere.
 * screencap both allocates and imports graphics buffers, so a dump with
 * imports+allocs > 0 proves the library loads, resolves its dependencies, and
 * that the interposition actually reaches these symbols - which is the exact
 * failure that would otherwise keep surfaceflinger from starting.
 *
 * COST
 * ----
 * Two hash-map operations per buffer import or allocate - not per malloc, which
 * is what made malloc_debug unaffordable for SurfaceFlinger on this device. When
 * tracking is off the hooks are one relaxed atomic load and a tail call.
 *
 * CONTROLS BUILT IN
 * -----------------
 * The dump carries counters (imports, allocs, frees, live) that must
 * independently agree with the external `anon_inode:dmabuf` fd count in
 * /proc/<sf>/fd, and it has a state in which it reports a negative: with
 * tracking enabled and the device idle, live must stay flat. It records how many
 * frees arrived for handles it never saw, which is how it reports that it is
 * watching the wrong path rather than silently returning a clean answer. And the
 * free_fds_* counters answer a question no return code can: whether free
 * actually closed the descriptors, decided by inode identity rather than by fd
 * number, which the kernel reuses.
 *
 * KNOBS (all volatile properties, nothing persists across a reboot)
 *   debug.sfleak.enable 1|0   start/stop tracking (0 also clears the table)
 *   debug.sfleak.dump   1     write the dump, then the property is reset to 0
 *   debug.sfleak.path         output path, default /data/local/tmp/sfleak
 */

#define LOG_TAG "sfleaktrack"

#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <unwind.h>

#include <algorithm>
#include <atomic>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

#include <cutils/properties.h>
#include <log/log.h>

namespace {

constexpr size_t kMaxFrames = 24;

struct Backtrace {
    uintptr_t frames[kMaxFrames];
    size_t count;

    bool operator==(const Backtrace& o) const {
        return count == o.count &&
               memcmp(frames, o.frames, count * sizeof(uintptr_t)) == 0;
    }
};

struct BacktraceHash {
    size_t operator()(const Backtrace& b) const {
        size_t h = 1469598103934665603ULL;
        for (size_t i = 0; i < b.count; i++) {
            h = (h ^ b.frames[i]) * 1099511628211ULL;
        }
        return h;
    }
};

// A buffer can enter this process two ways, and an instrument that watches only
// one of them returns a clean-looking zero for a leak in the other.
enum Origin { ORIGIN_IMPORT = 0, ORIGIN_ALLOC = 1 };

// What we remember about one live buffer.
struct Entry {
    Backtrace bt;
    uint32_t width, height, layer_count, stride;
    int32_t format;
    uint64_t usage;
    Origin origin;
};

std::mutex g_lock;
std::unordered_map<const void*, Entry> g_live;   // handle -> import site
std::atomic<bool> g_enabled{false};

// Counters. Deliberately independent of the table so they can contradict it.
std::atomic<uint64_t> g_imports{0};
std::atomic<uint64_t> g_import_fail{0};
std::atomic<uint64_t> g_frees{0};
std::atomic<uint64_t> g_frees_untracked{0};      // free of a handle we never saw
std::atomic<uint64_t> g_allocs{0};
std::atomic<uint64_t> g_alloc_fail{0};
std::atomic<uint64_t> g_alloc_frees{0};

// ---------------------------------------------------------------------------
// fd-level verdict on what free() actually did.
//
// This is the discriminator between the only two explanations that survive the
// lead's measurement (sAllocList entry gone after a screencap => free() ran,
// yet SF's dma_buf fd count rose by one and stayed up):
//
//   (A) freeBuffer claims success but does NOT close the handle's fds
//   (B) freeBuffer DOES close them, and the fd that stays open is a DIFFERENT
//       one on the same dma_buf - most plausibly the Mali EGLImage created when
//       SF rendered into the capture buffer (§6's standing suspect)
//
// Distinguishing them needs the handle's own fd numbers checked across the free
// call. An fd number alone is ambiguous because the kernel reuses numbers, so
// the identity of the OBJECT is carried by st_ino: same number AND same inode
// means genuinely still open, same number with a different inode means the slot
// was reused and the original was in fact closed.
std::atomic<uint64_t> g_free_fds_seen{0};
std::atomic<uint64_t> g_free_fds_closed{0};
std::atomic<uint64_t> g_free_fds_still_open{0};
std::atomic<uint64_t> g_free_fds_reused{0};

// ------------------------------------------------------- handle fd forensics

// Stable public ABI (system/core/libcutils/include/cutils/native_handle.h):
// data[0 .. numFds-1] are file descriptors, the rest are ints.
struct NativeHandleLite {
    int version;
    int numFds;
    int numInts;
    int data[];
};

constexpr int kMaxHandleFds = 8;

struct FdSnapshot {
    int count;
    int fd[kMaxHandleFds];
    ino_t ino[kMaxHandleFds];
};

// Record the handle's fds and the inode of each, BEFORE free runs.
void snapshot_fds(const void* handle, FdSnapshot* snap) {
    snap->count = 0;
    if (handle == nullptr) return;
    const NativeHandleLite* h = static_cast<const NativeHandleLite*>(handle);
    int n = h->numFds;
    if (n < 0 || n > kMaxHandleFds) n = (n < 0) ? 0 : kMaxHandleFds;
    for (int i = 0; i < n; i++) {
        int fd = h->data[i];
        if (fd < 0) continue;
        struct stat st;
        if (fstat(fd, &st) != 0) continue;   // already closed - nothing to say
        snap->fd[snap->count] = fd;
        snap->ino[snap->count] = st.st_ino;
        snap->count++;
    }
}

// After free returns, decide what actually happened to each of those fds.
void verify_fds(const FdSnapshot* snap) {
    for (int i = 0; i < snap->count; i++) {
        g_free_fds_seen.fetch_add(1, std::memory_order_relaxed);
        struct stat st;
        if (fstat(snap->fd[i], &st) != 0) {
            // EBADF - the descriptor is gone. free() closed it.
            g_free_fds_closed.fetch_add(1, std::memory_order_relaxed);
        } else if (st.st_ino == snap->ino[i]) {
            // Same number AND same object: genuinely still open.
            g_free_fds_still_open.fetch_add(1, std::memory_order_relaxed);
        } else {
            // Number reused by a different object => the original was closed.
            g_free_fds_reused.fetch_add(1, std::memory_order_relaxed);
        }
    }
}

// ---------------------------------------------------------------- backtrace

struct UnwindState {
    Backtrace* bt;
    size_t skip;
};

_Unwind_Reason_Code unwind_cb(struct _Unwind_Context* ctx, void* arg) {
    UnwindState* st = static_cast<UnwindState*>(arg);
    uintptr_t pc = _Unwind_GetIP(ctx);
    if (pc == 0) return _URC_NO_REASON;
    if (st->skip > 0) {
        st->skip--;
        return _URC_NO_REASON;
    }
    if (st->bt->count >= kMaxFrames) return _URC_END_OF_STACK;
    st->bt->frames[st->bt->count++] = pc;
    return _URC_NO_REASON;
}

void capture(Backtrace* bt) {
    bt->count = 0;
    UnwindState st{bt, 1 /* drop capture() itself */};
    _Unwind_Backtrace(unwind_cb, &st);
}

// -------------------------------------------------------------------- dump

std::string prop(const char* key, const char* dflt) {
    char buf[PROPERTY_VALUE_MAX] = {};
    property_get(key, buf, dflt);
    return buf;
}

void write_dump() {
    std::string base = prop("debug.sfleak.path", "/data/local/tmp/sfleak");
    char path[512];
    snprintf(path, sizeof(path), "%s.%d.txt", base.c_str(), getpid());

    // Group survivors by backtrace. Copy under the lock, format outside it.
    std::unordered_map<Backtrace, std::vector<const Entry*>, BacktraceHash> groups;
    std::unordered_map<const void*, Entry> snapshot;
    {
        std::lock_guard<std::mutex> guard(g_lock);
        snapshot = g_live;
    }
    for (const auto& kv : snapshot) {
        groups[kv.second.bt].push_back(&kv.second);
    }

    FILE* fp = fopen(path, "w");
    if (fp == nullptr) {
        ALOGE("sfleak: cannot open %s: %s", path, strerror(errno));
        return;
    }

    fprintf(fp, "sfleaktrack dump v1\n");
    fprintf(fp, "pid: %d\n", getpid());
    fprintf(fp, "enabled: %d\n", g_enabled.load() ? 1 : 0);
    fprintf(fp, "imports: %" PRIu64 "\n", g_imports.load());
    fprintf(fp, "import_failures: %" PRIu64 "\n", g_import_fail.load());
    fprintf(fp, "frees: %" PRIu64 "\n", g_frees.load());
    fprintf(fp, "frees_of_untracked_handles: %" PRIu64 "\n",
            g_frees_untracked.load());
    fprintf(fp, "allocs: %" PRIu64 "\n", g_allocs.load());
    fprintf(fp, "alloc_failures: %" PRIu64 "\n", g_alloc_fail.load());
    fprintf(fp, "alloc_frees: %" PRIu64 "\n", g_alloc_frees.load());
    // ⭐ The discriminator. free() demonstrably runs for capture buffers (the
    // sAllocList entry disappears) yet SF's dma_buf fd count stays up. Either
    // the handle's own fds survive the free, or they are closed and something
    // else holds a different fd on the same dma_buf. These four numbers say
    // which, and they are about the fds themselves, not about a return code.
    fprintf(fp, "free_fds_seen: %" PRIu64 "\n", g_free_fds_seen.load());
    fprintf(fp, "free_fds_closed: %" PRIu64 "        <- free did close them\n",
            g_free_fds_closed.load());
    fprintf(fp, "free_fds_still_open: %" PRIu64
                "    <- same fd AND same inode: free did NOT close them\n",
            g_free_fds_still_open.load());
    fprintf(fp, "free_fds_reused: %" PRIu64
                "        <- number reused by another object: closed\n",
            g_free_fds_reused.load());
    size_t live_import = 0, live_alloc = 0;
    for (const auto& kv : snapshot) {
        if (kv.second.origin == ORIGIN_ALLOC) live_alloc++; else live_import++;
    }
    fprintf(fp, "live: %zu  (imported %zu, allocated %zu)\n", snapshot.size(),
            live_import, live_alloc);
    fprintf(fp, "distinct_import_sites: %zu\n", groups.size());
    fprintf(fp, "\n");

    // Human-readable, most-retained first.
    std::vector<const std::pair<const Backtrace, std::vector<const Entry*>>*> sorted;
    for (const auto& g : groups) sorted.push_back(&g);
    std::sort(sorted.begin(), sorted.end(), [](auto* a, auto* b) {
        return a->second.size() > b->second.size();
    });

    for (const auto* g : sorted) {
        const Entry* rep = g->second.front();
        fprintf(fp,
                "SITE live=%zu  origin=%s  w=%u h=%u layers=%u stride=%u "
                "format=%d usage=0x%" PRIx64 "\n",
                g->second.size(),
                rep->origin == ORIGIN_ALLOC ? "ALLOC" : "IMPORT", rep->width,
                rep->height, rep->layer_count, rep->stride, rep->format,
                rep->usage);
    }
    fprintf(fp, "\n");

    // Same record syntax as an Android malloc_debug native heap dump (v1.1) so
    // the existing symbolizer reads this file unchanged.
    for (const auto* g : sorted) {
        fprintf(fp, "z 0  sz %8u  num    %zu  bt", 1u, g->second.size());
        for (size_t i = 0; i < g->first.count; i++) {
            fprintf(fp, " %016" PRIxPTR, g->first.frames[i]);
        }
        fprintf(fp, "\n");
    }

    // Same file carries the mappings, so PCs can be resolved from it alone.
    fprintf(fp, "\nMAPS\n");
    FILE* maps = fopen("/proc/self/maps", "r");
    if (maps != nullptr) {
        char line[1024];
        while (fgets(line, sizeof(line), maps) != nullptr) fputs(line, fp);
        fclose(maps);
    } else {
        fprintf(fp, "could not open /proc/self/maps\n");
    }
    fprintf(fp, "END\n");
    fclose(fp);

    ALOGI("sfleak: wrote %s (live=%zu sites=%zu imports=%" PRIu64
          " frees=%" PRIu64 ")",
          path, snapshot.size(), groups.size(), g_imports.load(),
          g_frees.load());
}

// ------------------------------------------------------------- control loop

void* control_thread(void*) {
    pthread_setname_np(pthread_self(), "sfleak-ctl");
    bool was_enabled = false;
    while (true) {
        bool want = prop("debug.sfleak.enable", "0") == "1";
        if (want != was_enabled) {
            if (!want) {
                std::lock_guard<std::mutex> guard(g_lock);
                g_live.clear();
            }
            g_enabled.store(want, std::memory_order_relaxed);
            was_enabled = want;
            ALOGI("sfleak: tracking %s", want ? "ENABLED" : "disabled");
        }
        if (prop("debug.sfleak.dump", "0") == "1") {
            property_set("debug.sfleak.dump", "0");
            write_dump();
        }
        usleep(1000 * 1000);
    }
    return nullptr;
}

std::once_flag g_started;

void ensure_started() {
    std::call_once(g_started, [] {
        pthread_t t;
        if (pthread_create(&t, nullptr, control_thread, nullptr) == 0) {
            pthread_detach(t);
            ALOGI("sfleak: control thread up; "
                  "setprop debug.sfleak.enable 1 to track");
        } else {
            ALOGE("sfleak: could not start control thread");
        }
    });
}

// ------------------------------------------------------------------- hooks

using import_fn = int32_t (*)(void*, const void*, uint32_t, uint32_t, uint32_t,
                              int32_t, uint64_t, uint32_t, const void**);
using free_fn = int32_t (*)(void*, const void*);

// GraphicBufferAllocator::allocate(uint32_t w, uint32_t h, PixelFormat format,
//     uint32_t layerCount, uint64_t usage, buffer_handle_t* handle,
//     uint32_t* stride, uint64_t graphicBufferId, std::string requestorName)
// requestorName is a std::string BY VALUE. Under AAPCS64 a type with a
// non-trivial copy constructor is passed as a pointer to a temporary, so the
// slot is pointer-sized and we forward it opaquely. We deliberately do NOT
// read it: libc++'s std::string layout is an internal detail, and the captured
// backtrace names the caller better than the string would anyway.
using alloc_fn = int32_t (*)(void*, uint32_t, uint32_t, int32_t, uint32_t,
                             uint64_t, const void**, uint32_t*, uint64_t,
                             const void*);
using allocfree_fn = int32_t (*)(void*, const void*);

const char kImportSym[] =
    "_ZN7android19GraphicBufferMapper12importBufferEPK13native_handlejjjimjPS3_";
const char kFreeSym[] =
    "_ZN7android19GraphicBufferMapper10freeBufferEPK13native_handle";
const char kAllocSym[] =
    "_ZN7android22GraphicBufferAllocator8allocateEjjijmPPK13native_handlePjmNS"
    "t3__112basic_stringIcNS6_11char_traitsIcEENS6_9allocatorIcEEEE";
const char kAllocFreeSym[] =
    "_ZN7android22GraphicBufferAllocator4freeEPK13native_handle";

import_fn real_import() {
    static import_fn fn =
        reinterpret_cast<import_fn>(dlsym(RTLD_NEXT, kImportSym));
    return fn;
}

free_fn real_free() {
    static free_fn fn = reinterpret_cast<free_fn>(dlsym(RTLD_NEXT, kFreeSym));
    return fn;
}

alloc_fn real_alloc() {
    static alloc_fn fn = reinterpret_cast<alloc_fn>(dlsym(RTLD_NEXT, kAllocSym));
    return fn;
}

allocfree_fn real_allocfree() {
    static allocfree_fn fn =
        reinterpret_cast<allocfree_fn>(dlsym(RTLD_NEXT, kAllocFreeSym));
    return fn;
}

}  // namespace

// The asm labels make these definitions carry libui.so's mangled names, so the
// dynamic linker resolves callers to us first. Signatures match the C++ member
// functions with the implicit `this` spelled out as the leading argument.
extern "C" int32_t sfleak_import_hook(void* thiz, const void* raw, uint32_t w,
                                      uint32_t h, uint32_t layer_count,
                                      int32_t format, uint64_t usage,
                                      uint32_t stride, const void** out_handle)
    __asm__(
        "_ZN7android19GraphicBufferMapper12importBufferEPK13native_handlejjjimj"
        "PS3_");

extern "C" int32_t sfleak_free_hook(void* thiz, const void* handle)
    __asm__("_ZN7android19GraphicBufferMapper10freeBufferEPK13native_handle");

extern "C" int32_t sfleak_alloc_hook(void* thiz, uint32_t w, uint32_t h,
                                     int32_t format, uint32_t layer_count,
                                     uint64_t usage, const void** handle,
                                     uint32_t* stride, uint64_t buffer_id,
                                     const void* requestor_name)
    __asm__(
        "_ZN7android22GraphicBufferAllocator8allocateEjjijmPPK13native_handlePj"
        "mNSt3__112basic_stringIcNS6_11char_traitsIcEENS6_9allocatorIcEEEE");

extern "C" int32_t sfleak_allocfree_hook(void* thiz, const void* handle)
    __asm__("_ZN7android22GraphicBufferAllocator4freeEPK13native_handle");

extern "C" int32_t sfleak_import_hook(void* thiz, const void* raw, uint32_t w,
                                      uint32_t h, uint32_t layer_count,
                                      int32_t format, uint64_t usage,
                                      uint32_t stride, const void** out_handle) {
    import_fn fn = real_import();
    if (fn == nullptr) {
        ALOGE("sfleak: importBuffer not resolvable via RTLD_NEXT");
        return -1;
    }
    int32_t rc = fn(thiz, raw, w, h, layer_count, format, usage, stride,
                    out_handle);

    ensure_started();
    if (!g_enabled.load(std::memory_order_relaxed)) return rc;

    if (rc != 0 || out_handle == nullptr || *out_handle == nullptr) {
        g_import_fail.fetch_add(1, std::memory_order_relaxed);
        return rc;
    }
    g_imports.fetch_add(1, std::memory_order_relaxed);

    Entry e;
    capture(&e.bt);
    e.width = w;
    e.height = h;
    e.layer_count = layer_count;
    e.stride = stride;
    e.format = format;
    e.usage = usage;
    e.origin = ORIGIN_IMPORT;
    {
        std::lock_guard<std::mutex> guard(g_lock);
        g_live[*out_handle] = e;
    }
    return rc;
}

extern "C" int32_t sfleak_alloc_hook(void* thiz, uint32_t w, uint32_t h,
                                     int32_t format, uint32_t layer_count,
                                     uint64_t usage, const void** handle,
                                     uint32_t* stride, uint64_t buffer_id,
                                     const void* requestor_name) {
    alloc_fn fn = real_alloc();
    if (fn == nullptr) {
        ALOGE("sfleak: GraphicBufferAllocator::allocate not resolvable");
        return -1;
    }
    int32_t rc = fn(thiz, w, h, format, layer_count, usage, handle, stride,
                    buffer_id, requestor_name);

    ensure_started();
    if (!g_enabled.load(std::memory_order_relaxed)) return rc;

    if (rc != 0 || handle == nullptr || *handle == nullptr) {
        g_alloc_fail.fetch_add(1, std::memory_order_relaxed);
        return rc;
    }
    g_allocs.fetch_add(1, std::memory_order_relaxed);

    Entry e;
    capture(&e.bt);
    e.width = w;
    e.height = h;
    e.layer_count = layer_count;
    e.stride = (stride != nullptr) ? *stride : 0;
    e.format = format;
    e.usage = usage;
    e.origin = ORIGIN_ALLOC;
    {
        std::lock_guard<std::mutex> guard(g_lock);
        g_live[*handle] = e;
    }
    return rc;
}

// ⚠ This hook deliberately does NOT erase from the table and does NOT do the fd
// forensics. GraphicBufferAllocator::free() calls mMapper.freeBuffer() as its
// FIRST statement (GraphicBufferAllocator.cpp:150), and that call is itself
// interposed by sfleak_free_hook above. Doing the work in both places would
// double-count every fd, and - worse - the erase here would run first, so the
// nested mapper hook would find the entry already gone and score it as a free
// of an untracked handle, silently poisoning the very control that is supposed
// to tell us the instrument is watching the wrong path.
//
// All this hook does is record that the ALLOCATOR path ran, which is what
// distinguishes "SF freed its own buffer" from "SF freed an imported one".
extern "C" int32_t sfleak_allocfree_hook(void* thiz, const void* handle) {
    if (g_enabled.load(std::memory_order_relaxed)) {
        g_alloc_frees.fetch_add(1, std::memory_order_relaxed);
    }
    allocfree_fn fn = real_allocfree();
    if (fn == nullptr) {
        ALOGE("sfleak: GraphicBufferAllocator::free not resolvable");
        return -1;
    }
    return fn(thiz, handle);
}

extern "C" int32_t sfleak_free_hook(void* thiz, const void* handle) {
    bool on = g_enabled.load(std::memory_order_relaxed);
    FdSnapshot snap;
    snap.count = 0;
    if (on) {
        g_frees.fetch_add(1, std::memory_order_relaxed);
        snapshot_fds(handle, &snap);   // must be read while the handle is valid
        std::lock_guard<std::mutex> guard(g_lock);
        if (g_live.erase(handle) == 0) {
            g_frees_untracked.fetch_add(1, std::memory_order_relaxed);
        }
    }
    free_fn fn = real_free();
    if (fn == nullptr) {
        ALOGE("sfleak: freeBuffer not resolvable via RTLD_NEXT");
        return -1;
    }
    int32_t rc = fn(thiz, handle);
    if (on) verify_fds(&snap);
    return rc;
}
