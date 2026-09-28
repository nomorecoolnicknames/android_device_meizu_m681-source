#!/system/bin/sh

SRC="/vendor/etc/mcRegistry"
DST="/data/misc/mcRegistry"

mkdir -p "$DST" "$DST/TbStorage" 2>/dev/null || true

log_msg() {
    log -t m681_mcregistry "$*" 2>/dev/null || echo "m681_mcregistry: $*" > /dev/kmsg 2>/dev/null || true
}

hash_file() {
    for tool in sha256sum md5sum; do
        if command -v "$tool" >/dev/null 2>&1; then
            "$tool" "$1" 2>/dev/null | awk '{print $1}'
            return
        fi
    done
    echo no_hash_tool
}

if [ -d "$SRC" ]; then
    for file in "$SRC"/*; do
        [ -f "$file" ] || continue
        cp "$file" "$DST/" 2>/dev/null || true
    done
fi

# Goodix asks mobicore for 070505..., while the stock registry extracted for
# this device only ships the adjacent 070500... TA. Materialize the requested
# name from that source file so the lookup resolves without inventing a fake TA.
GOODIX_SRC="$DST/07050000000000000000000000000000.tlbin"
GOODIX_DST="$DST/07050500000000000000000000000000.tlbin"
if [ -f "$GOODIX_SRC" ] && [ ! -f "$GOODIX_DST" ]; then
    cp "$GOODIX_SRC" "$GOODIX_DST" 2>/dev/null && \
        log_msg "created Goodix mcRegistry alias 070505 from 070500 src=$(hash_file "$GOODIX_SRC") dst=$(hash_file "$GOODIX_DST")"
fi

chown -R system:system "$DST" 2>/dev/null || true
chmod 0775 "$DST" "$DST/TbStorage" 2>/dev/null || true
chmod 0664 "$DST"/* 2>/dev/null || true
restorecon "$GOODIX_DST" 2>/dev/null || true
