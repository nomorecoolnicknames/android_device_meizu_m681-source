#include <android/log.h>
#include <cutils/properties.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#define LOG_TAG "m681_nvram_wifi_repair"
#define WIFI_REC_SIZE 514
#define WIFI_MAC_OFFSET 4
#define WIFI_TAIL_MARKER 512
#define SCAN_CHUNK_SIZE 65536

static const char *const wifi_paths[] = {
    "/nvdata/APCFG/APRDEB/WIFI",
    "/data/nvram/APCFG/APRDEB/WIFI",
};

static const char *const wifi_candidate_paths[] = {
    "/nvdata/APCFG/APRDEB/WIFI",
    "/data/nvram/APCFG/APRDEB/WIFI",
    "/nvdata/APCFG/APRDEB/WIFI.m681bak",
    "/data/nvram/APCFG/APRDEB/WIFI.m681bak",
    "/nvdata/APCFG/APRDEB/WIFI.l681bak",
    "/data/nvram/APCFG/APRDEB/WIFI.l681bak",
    "/protect_f/APCFG/APRDEB/WIFI",
    "/protect_s/APCFG/APRDEB/WIFI",
    "/protect_f/nvram/APCFG/APRDEB/WIFI",
    "/protect_s/nvram/APCFG/APRDEB/WIFI",
};

static const char *const raw_paths[] = {
    "/dev/block/bootdevice/by-name/nvram",
    "/dev/block/platform/bootdevice/by-name/nvram",
    "/dev/block/platform/mtk-msdc.0/11230000.msdc0/by-name/nvram",
    "/dev/block/platform/mtk-msdc.0/by-name/nvram",
    "/dev/block/by-name/nvram",
    "/dev/nvram",
    "/dev/block/bootdevice/by-name/nvdata",
    "/dev/block/platform/bootdevice/by-name/nvdata",
    "/dev/block/platform/mtk-msdc.0/11230000.msdc0/by-name/nvdata",
    "/dev/block/platform/mtk-msdc.0/by-name/nvdata",
    "/dev/block/by-name/nvdata",
    "/dev/block/bootdevice/by-name/protect1",
    "/dev/block/platform/bootdevice/by-name/protect1",
    "/dev/block/platform/mtk-msdc.0/11230000.msdc0/by-name/protect1",
    "/dev/block/platform/mtk-msdc.0/by-name/protect1",
    "/dev/block/by-name/protect1",
    "/dev/block/bootdevice/by-name/protect2",
    "/dev/block/platform/bootdevice/by-name/protect2",
    "/dev/block/platform/mtk-msdc.0/11230000.msdc0/by-name/protect2",
    "/dev/block/platform/mtk-msdc.0/by-name/protect2",
    "/dev/block/by-name/protect2",
};

static void log_msg(int prio, const char *fmt, ...)
{
    va_list ap;

    va_start(ap, fmt);
    __android_log_vprint(prio, LOG_TAG, fmt, ap);
    va_end(ap);
}

static void set_state(const char *state)
{
    property_set("debug.m681.wifi_nvram_repair", state);
}

static int valid_mac(const uint8_t *mac)
{
    int all_zero = 1;
    int all_ff = 1;
    size_t i;

    if (mac[0] & 0x01)
        return 0;

    for (i = 0; i < 6; ++i) {
        if (mac[i] != 0x00)
            all_zero = 0;
        if (mac[i] != 0xff)
            all_ff = 0;
    }

    if (all_zero || all_ff)
        return 0;

    if (mac[0] == 0x02 && mac[1] == 0x00 && mac[2] == 0x00 &&
        mac[3] == 0x00 && mac[4] == 0x00 && mac[5] == 0x00)
        return 0;

    return 1;
}

static int plausible_wifi_record(const uint8_t *rec)
{
    if (rec[0] != 0x04 || rec[1] != 0x01)
        return 0;
    if (rec[2] != 0x00 || rec[3] != 0x00)
        return 0;
    if (rec[WIFI_TAIL_MARKER] != 0xaa)
        return 0;

    return 1;
}

static int valid_wifi_record(const uint8_t *rec)
{
    return plausible_wifi_record(rec) &&
           valid_mac(rec + WIFI_MAC_OFFSET);
}

static int read_full(const char *path, uint8_t *buf, size_t size)
{
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    ssize_t n;
    size_t off = 0;

    if (fd < 0)
        return -1;

    while (off < size) {
        n = read(fd, buf + off, size - off);
        if (n < 0) {
            if (errno == EINTR)
                continue;
            close(fd);
            return -1;
        }
        if (n == 0)
            break;
        off += (size_t)n;
    }

    close(fd);
    return off == size ? 0 : -1;
}

static int write_full_fd(int fd, const uint8_t *buf, size_t size)
{
    ssize_t n;
    size_t off = 0;

    while (off < size) {
        n = write(fd, buf + off, size - off);
        if (n < 0) {
            if (errno == EINTR)
                continue;
            return -1;
        }
        off += (size_t)n;
    }

    return 0;
}

static int backup_current(const char *path, const uint8_t *rec)
{
    char backup[160];
    int fd;

    snprintf(backup, sizeof(backup), "%s.m681bak", path);
    if (access(backup, F_OK) == 0)
        return 0;

    fd = open(backup, O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC, 0660);
    if (fd < 0)
        return -1;

    if (write_full_fd(fd, rec, WIFI_REC_SIZE) < 0) {
        close(fd);
        return -1;
    }

    fsync(fd);
    close(fd);
    chmod(backup, 0660);
    chown(backup, 1000, 1000);
    return 0;
}

static int write_record(const char *path, const uint8_t *rec)
{
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0660);

    if (fd < 0)
        return -1;

    if (write_full_fd(fd, rec, WIFI_REC_SIZE) < 0) {
        close(fd);
        return -1;
    }

    fsync(fd);
    close(fd);
    chmod(path, 0660);
    chown(path, 1000, 1000);
    return 0;
}

static int path_seen_before(const struct stat *st, const struct stat *seen,
                            size_t seen_count)
{
    size_t i;

    for (i = 0; i < seen_count; ++i) {
        if (st->st_dev == seen[i].st_dev && st->st_ino == seen[i].st_ino)
            return 1;
    }

    return 0;
}

static int scan_buffer_for_record(const uint8_t *buf, size_t len, uint8_t *out)
{
    size_t i;

    if (len < WIFI_REC_SIZE)
        return -1;

    for (i = 0; i <= len - WIFI_REC_SIZE; ++i) {
        if (valid_wifi_record(buf + i)) {
            memcpy(out, buf + i, WIFI_REC_SIZE);
            return 0;
        }
    }

    return -1;
}

static int scan_raw_for_record(const char *path, uint8_t *out)
{
    uint8_t buf[SCAN_CHUNK_SIZE + WIFI_REC_SIZE];
    size_t carry = 0;
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    ssize_t n;

    if (fd < 0)
        return -1;

    while ((n = read(fd, buf + carry, SCAN_CHUNK_SIZE)) > 0) {
        size_t total = carry + (size_t)n;

        if (scan_buffer_for_record(buf, total, out) == 0) {
            close(fd);
            return 0;
        }

        carry = total < WIFI_REC_SIZE - 1 ? total : WIFI_REC_SIZE - 1;
        memmove(buf, buf + total - carry, carry);
    }

    close(fd);
    return -1;
}

static int find_candidate(uint8_t *candidate, const char **source)
{
    uint8_t rec[WIFI_REC_SIZE];
    size_t i;

    for (i = 0; i < sizeof(wifi_candidate_paths) / sizeof(wifi_candidate_paths[0]); ++i) {
        if (read_full(wifi_candidate_paths[i], rec, sizeof(rec)) == 0 &&
            valid_wifi_record(rec)) {
            memcpy(candidate, rec, sizeof(rec));
            *source = wifi_candidate_paths[i];
            return 0;
        }
    }

    for (i = 0; i < sizeof(raw_paths) / sizeof(raw_paths[0]); ++i) {
        if (scan_raw_for_record(raw_paths[i], candidate) == 0) {
            *source = raw_paths[i];
            return 0;
        }
    }

    return -1;
}

static uint64_t fnv1a64(const char *s, uint64_t h)
{
    while (*s) {
        h ^= (uint8_t)*s++;
        h *= 1099511628211ULL;
    }
    return h;
}

static void synthesize_mac(uint8_t *mac)
{
    char serial[PROPERTY_VALUE_MAX];
    uint64_t h = 1469598103934665603ULL;

    property_get("ro.serialno", serial, "");
    h = fnv1a64("m681-wifi-fallback-v1", h);
    h = fnv1a64(serial, h);
    property_get("ro.boot.serialno", serial, "");
    h = fnv1a64(serial, h);
    property_get("ro.boot.serialno.psn", serial, "");
    h = fnv1a64(serial, h);

    mac[0] = 0x02;
    mac[1] = 0x68;
    mac[2] = 0x1d;
    mac[3] = (uint8_t)(h >> 16);
    mac[4] = (uint8_t)(h >> 8);
    mac[5] = (uint8_t)h;
}

static int synthesize_candidate(uint8_t *candidate, const char **source)
{
    static char synthetic_source[192];
    uint8_t rec[WIFI_REC_SIZE];
    size_t i;

    for (i = 0; i < sizeof(wifi_candidate_paths) / sizeof(wifi_candidate_paths[0]); ++i) {
        if (read_full(wifi_candidate_paths[i], rec, sizeof(rec)) == 0 &&
            plausible_wifi_record(rec)) {
            memcpy(candidate, rec, sizeof(rec));
            synthesize_mac(candidate + WIFI_MAC_OFFSET);
            snprintf(synthetic_source, sizeof(synthetic_source),
                     "synthetic:%s", wifi_candidate_paths[i]);
            *source = synthetic_source;
            return valid_wifi_record(candidate) ? 0 : -1;
        }
    }

    return -1;
}

static int repair_targets(const uint8_t *candidate, const char *source)
{
    uint8_t current[WIFI_REC_SIZE];
    struct stat seen[sizeof(wifi_paths) / sizeof(wifi_paths[0])];
    size_t seen_count = 0;
    size_t repaired = 0;
    size_t valid = 0;
    size_t i;

    for (i = 0; i < sizeof(wifi_paths) / sizeof(wifi_paths[0]); ++i) {
        struct stat st;
        int have_stat = stat(wifi_paths[i], &st) == 0;
        int have_file = read_full(wifi_paths[i], current, sizeof(current)) == 0;

        if (have_stat && path_seen_before(&st, seen, seen_count))
            continue;
        if (have_stat && seen_count < sizeof(seen) / sizeof(seen[0]))
            seen[seen_count++] = st;

        if (have_file && valid_wifi_record(current)) {
            ++valid;
            continue;
        }

        if (have_file)
            backup_current(wifi_paths[i], current);

        if (write_record(wifi_paths[i], candidate) == 0) {
            ++repaired;
            log_msg(ANDROID_LOG_INFO,
                    "repaired %s from %s mac=%02x:%02x:%02x:%02x:%02x:%02x",
                    wifi_paths[i], source, candidate[4], candidate[5],
                    candidate[6], candidate[7], candidate[8], candidate[9]);
        } else {
            log_msg(ANDROID_LOG_WARN, "failed to write %s: %s", wifi_paths[i],
                    strerror(errno));
        }
    }

    if (repaired > 0)
        return 1;
    if (valid > 0)
        return 0;
    return -1;
}

int main(void)
{
    uint8_t candidate[WIFI_REC_SIZE];
    const char *source = NULL;
    int rc;

    memset(candidate, 0, sizeof(candidate));

    if (find_candidate(candidate, &source) < 0) {
        if (synthesize_candidate(candidate, &source) < 0) {
            set_state("no_candidate");
            log_msg(ANDROID_LOG_WARN,
                    "no valid or plausible WIFI nvram record found; not writing fallback MAC");
            return 1;
        }
        set_state("synthetic_candidate");
        log_msg(ANDROID_LOG_WARN,
                "no valid WIFI nvram MAC found; synthesized fallback mac=%02x:%02x:%02x:%02x:%02x:%02x source=%s",
                candidate[4], candidate[5], candidate[6], candidate[7],
                candidate[8], candidate[9], source);
    }

    rc = repair_targets(candidate, source);
    if (rc > 0) {
        set_state("repaired");
        return 0;
    }
    if (rc == 0) {
        set_state("valid");
        log_msg(ANDROID_LOG_INFO,
                "mounted WIFI record already valid mac=%02x:%02x:%02x:%02x:%02x:%02x source=%s",
                candidate[4], candidate[5], candidate[6], candidate[7],
                candidate[8], candidate[9], source);
        return 0;
    }

    set_state("write_failed");
    return 1;
}
