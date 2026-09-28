#!/system/bin/sh

MDTYPE_DATA=/data/nvram/APCFG/APRDCL/MD_Type
MDTYPE_NVDATA=/nvdata/APCFG/APRDCL/MD_Type
WORKDIR=/dev
RECORD_SIZE=4
TAIL_SIZE=0
TOTAL_SIZE=4

log -t m681_mdtype_fix "begin mode=$1 service.nvram_init=$(getprop service.nvram_init)"
mode="$1"
nvram_state="$(getprop service.nvram_init)"
md1_state="$(getprop mtk.md1.status)"

if [ -d /data/misc ]; then
    WORKDIR=/data/misc/m681
    mkdir -p "$WORKDIR"
    chown system system "$WORKDIR"
    chmod 0770 "$WORKDIR"
    restorecon "$WORKDIR"
elif [ ! -d "$WORKDIR" ]; then
    WORKDIR=/data
fi

if [ ! -f /vendor/firmware/modem_1_ulwctg_n.img ] && \
   [ ! -f /system/vendor/firmware/modem_1_ulwctg_n.img ]; then
    setprop debug.m681.mdtype.ready 0
    setprop debug.m681.mdtype_fix no_ulwctg
    log -t m681_mdtype_fix "ulwctg modem image missing; leave MD_Type untouched"
    exit 0
fi

hex_head() {
    dd if="$1" bs=1 count=8 2>/dev/null | od -An -tx1 2>/dev/null
}

mdtype_ok() {
    path="$1"
    [ -f "$path" ] || return 1
    tmp="$WORKDIR/MD_Type.check.$$"
    ref="$WORKDIR/MD_Type.ref.$$"
    printf '\014\000\000\000' > "$ref"
    dd if="$path" of="$tmp" bs=1 count=4 >/dev/null 2>&1 || {
        rm -f "$tmp" "$ref"
        return 1
    }
    cmp -s "$ref" "$tmp"
    ret=$?
    rm -f "$tmp" "$ref"
    return "$ret"
}

verify_only=0
if [ "$mode" = "early" ] && [ "$nvram_state" != "Ready" ]; then
    verify_only=1
fi
if [ "$md1_state" = "bootup" ] || [ "$md1_state" = "ready" ]; then
    verify_only=1
fi

if [ "$verify_only" = "1" ]; then
    data_ok=0
    nvdata_ok=0
    mdtype_ok "$MDTYPE_DATA" && data_ok=1
    mdtype_ok "$MDTYPE_NVDATA" && nvdata_ok=1
    setprop debug.m681.mdtype.data "$(hex_head "$MDTYPE_DATA")"
    setprop debug.m681.mdtype.nvdata "$(hex_head "$MDTYPE_NVDATA")"
    if [ "$data_ok" = "1" ] || [ "$nvdata_ok" = "1" ]; then
        setprop debug.m681.mdtype.ready 1
        setprop debug.m681.mdtype_fix verified_readonly
        log -t m681_mdtype_fix "MD_Type already ulwctg 12; readonly path mode=$mode nvram=$nvram_state md1=$md1_state"
        exit 0
    fi
    setprop debug.m681.mdtype.ready 0
    setprop debug.m681.mdtype_fix readonly_not_ready
    log -t m681_mdtype_fix "readonly skip: mode=$mode nvram=$nvram_state md1=$md1_state data_ok=$data_ok nvdata_ok=$nvdata_ok"
    exit 0
fi

file_size() {
    wc -c "$1" 2>/dev/null | awk '{print $1}'
}

write_mdtype() {
    path="$1"
    label="$2"
    dir="${path%/*}"
    tmp="$WORKDIR/MD_Type.$label.m681"
    tail="$WORKDIR/MD_Type.$label.m681.tail"
    head="$WORKDIR/MD_Type.$label.m681.head"
    check="$WORKDIR/MD_Type.$label.m681.check"

    if [ ! -d "$dir" ]; then
        log -t m681_mdtype_fix "$label directory missing at $dir"
        return 2
    fi

    if [ ! -f "$path" ]; then
        log -t m681_mdtype_fix "$label missing at $path; creating $TOTAL_SIZE-byte protected record"
        : > "$path" || return 1
    fi

    before_size="$(file_size "$path")"
    before_hex="$(hex_head "$path")"
    log -t m681_mdtype_fix "$label before size=$before_size head=$before_hex path=$path"
    if mdtype_ok "$path"; then
        log -t m681_mdtype_fix "$label already ulwctg 12; skip rewrite"
        return 0
    fi

    rm -f "$tmp" "$tail" "$head" "$check"
    tail_size=0
    if [ "$TAIL_SIZE" -gt 0 ]; then
        dd if="$path" of="$tail" bs=1 skip="$RECORD_SIZE" count="$TAIL_SIZE" >/dev/null 2>&1
        tail_size="$(file_size "$tail")"
        if [ -z "$tail_size" ]; then
            tail_size=0
        fi

        while [ "$tail_size" -lt "$TAIL_SIZE" ]; do
            dd if=/dev/zero bs=1 count=1 >> "$tail" 2>/dev/null
            tail_size=$((tail_size + 1))
        done
    fi

    printf '\014\000\000\000' > "$head"
    cat "$head" > "$tmp"
    if [ "$TAIL_SIZE" -gt 0 ]; then
        cat "$tail" >> "$tmp"
    fi
    if ! cat "$tmp" > "$path"; then
        log -t m681_mdtype_fix "$label write failed"
        rm -f "$tmp" "$tail" "$head" "$check"
        return 1
    fi

    chown system system "$path"
    chmod 0660 "$path"
    restorecon "$path"

    after_size="$(file_size "$path")"
    after_hex="$(hex_head "$path")"
    if dd if="$path" of="$check" bs=1 count=4 >/dev/null 2>&1 && \
       cmp -s "$head" "$check"; then
        log -t m681_mdtype_fix "$label forced to ulwctg 12 ok size=$after_size head=$after_hex data_record=$RECORD_SIZE tail=$tail_size total=$TOTAL_SIZE"
        rm -f "$tmp" "$tail" "$head" "$check"
        return 0
    fi

    log -t m681_mdtype_fix "$label readback failed size=$after_size head=$after_hex"
    rm -f "$tmp" "$tail" "$head" "$check"
    return 1
}

ok=1
attempted=0
write_mdtype "$MDTYPE_DATA" data
ret=$?
if [ "$ret" = "0" ]; then
    ok=0
fi
if [ "$ret" != "2" ]; then
    attempted=1
fi

write_mdtype "$MDTYPE_NVDATA" nvdata
ret=$?
if [ "$ret" = "0" ]; then
    ok=0
fi
if [ "$ret" != "2" ]; then
    attempted=1
fi

setprop debug.m681.mdtype.data "$(hex_head "$MDTYPE_DATA")"
setprop debug.m681.mdtype.nvdata "$(hex_head "$MDTYPE_NVDATA")"

if [ "$ok" = "0" ]; then
    setprop debug.m681.mdtype.ready 1
    setprop debug.m681.mdtype_fix ulwctg_12_table4_verified
    log -t m681_mdtype_fix "MD_Type verified/updated as ulwctg 12 with exact 4-byte NVRAM table record"
    exit 0
fi

setprop debug.m681.mdtype.ready 0
if [ "$attempted" = "0" ]; then
    setprop debug.m681.mdtype_fix no_file
    log -t m681_mdtype_fix "MD_Type missing at both data and nvdata paths"
    exit 0
fi

setprop debug.m681.mdtype_fix write_or_readback_failed
exit 1
