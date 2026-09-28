#!/system/bin/sh

STAGE="$1"
[ -n "$STAGE" ] || STAGE="snapshot"
BOOTDIAG_ENABLED="$(getprop persist.m681.bootdiag 2>/dev/null)"
if [ "$BOOTDIAG_ENABLED" != "1" ]; then
    BOOTDIAG_ENABLED="$(getprop persist.l681.bootdiag 2>/dev/null)"
fi
[ "$BOOTDIAG_ENABLED" = "1" ] || exit 0
STAMP="$(date +%Y%m%d-%H%M%S 2>/dev/null)"
[ -n "$STAMP" ] || STAMP="20100104-000000"
OUTDIR=/cache/bootdiag-pstore
SNAPDIR="${OUTDIR}/${STAGE}-${STAMP}"
CACHE_BLK="/dev/block/mmcblk0p30"
CACHE_BLK_ALT="/dev/block/platform/mtk-msdc.0/11230000.msdc0/by-name/cache"

ensure_cache() {
    mkdir -p /cache 2>/dev/null || true
    if ! touch /cache/.m681_pstore_probe.$$ >/dev/null 2>&1; then
        mount /cache >/dev/null 2>&1 || true
        mount -t ext4 "$CACHE_BLK" /cache >/dev/null 2>&1 || true
        mount -t ext4 "$CACHE_BLK_ALT" /cache >/dev/null 2>&1 || true
    fi
    rm -f /cache/.m681_pstore_probe.$$ >/dev/null 2>&1 || true
}

ensure_cache
mkdir -p "${OUTDIR}" "${SNAPDIR}" 2>/dev/null || true

echo "${STAGE}" > "${OUTDIR}/last-preserve-stage.txt" 2>/dev/null || true
echo "${STAMP}" > "${OUTDIR}/last-preserve-stamp.txt" 2>/dev/null || true
echo "${SNAPDIR}" > "${OUTDIR}/last-preserve-path.txt" 2>/dev/null || true

cp -af /sys/fs/pstore/* "${SNAPDIR}"/ 2>/dev/null || true
cat /sys/fs/pstore/pmsg-ramoops-0 > "${SNAPDIR}/pmsg-ramoops-0.txt" 2>/dev/null || true
cat /sys/fs/pstore/console-ramoops > "${SNAPDIR}/console-ramoops.txt" 2>/dev/null || true
cat /sys/fs/pstore/console-ramoops-0 > "${SNAPDIR}/console-ramoops-0.txt" 2>/dev/null || true
cat /proc/last_kmsg > "${SNAPDIR}/last_kmsg.txt" 2>/dev/null || true
cat /proc/bootprof > "${SNAPDIR}/bootprof.txt" 2>/dev/null || true
cat /proc/cmdline > "${SNAPDIR}/cmdline.txt" 2>/dev/null || true
getprop > "${SNAPDIR}/getprop.txt" 2>/dev/null || true
mount > "${SNAPDIR}/mount.txt" 2>/dev/null || true
ps > "${SNAPDIR}/ps.txt" 2>/dev/null || true
ls -l /sys/fs/pstore > "${SNAPDIR}/pstore_listing.txt" 2>/dev/null || true

exit 0
