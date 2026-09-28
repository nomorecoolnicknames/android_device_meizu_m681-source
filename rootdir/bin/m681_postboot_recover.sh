#!/system/bin/sh

log -t m681_postboot "begin"

# Keep Android's red StrictMode border disabled on this debug-heavy bring-up
# build. The physical panel now works; this prevents false display regressions.
setprop persist.sys.strictmode.visual 0
setprop persist.sys.strictmode.disable 1

dump_node()
{
    node="$1"
    tag="$2"
    limit="$3"
    [ -n "$limit" ] || limit=80
    if [ ! -e "$node" ]; then
        log -t m681_bootdiag "$tag missing $node"
        return
    fi

    log -t m681_bootdiag "$tag begin $node"
    n=0
    while IFS= read -r line; do
        log -t m681_bootdiag "$tag $line"
        n=$((n + 1))
        [ "$n" -ge "$limit" ] && break
    done < "$node"
    log -t m681_bootdiag "$tag end lines=$n"
}

log -t m681_bootdiag "props boot=$(getprop sys.boot_completed) sf=$(getprop init.svc.surfaceflinger) ril_mtk=$(getprop init.svc.ril-daemon-mtk) ril_aosp=$(getprop init.svc.ril-daemon) rilproxy=$(getprop init.svc.ril-proxy) md1=$(getprop mtk.md1.status)"

dump_node /proc/m681_txd1_diag txd1
dump_node /proc/m681_dsi_irq_diag dsi_irq 220
dump_node /proc/m681_disp_route_diag disp_route
dump_node /proc/m681_dsi_low_diag dsi_low
dump_node /proc/m681_disp_path_diag disp_path
dump_node /proc/m681_mtkfb_diag mtkfb
dump_node /proc/m681_battery_diag battery
dump_node /proc/m681_isp_diag isp
dump_node /proc/m681_camera_diag camera
dump_node /proc/fb fb

for bl in /sys/class/leds/lcd-backlight/brightness \
          /sys/devices/platform/leds-mt65xx/leds/lcd-backlight/brightness; do
    if [ -e "$bl" ]; then
        cur="$(cat "$bl" 2>/dev/null)"
        log -t m681_postboot "brightness observe-only $bl=$cur"
    fi
done

if [ -e /dev/goodix_fp_spi ]; then
    if [ -L /dev/goodix_fp ] || [ ! -e /dev/goodix_fp ]; then
        ln -sf /dev/goodix_fp_spi /dev/goodix_fp
    fi
    chown system system /dev/goodix_fp_spi /dev/goodix_fp
    chmod 0660 /dev/goodix_fp_spi /dev/goodix_fp
    restorecon /dev/goodix_fp_spi /dev/goodix_fp
    log -t m681_postboot "ensured /dev/goodix_fp -> /dev/goodix_fp_spi"
fi

if [ -e /proc/m681_cmdq_unblock_now ]; then
    echo 1 > /proc/m681_cmdq_unblock_now
    log -t m681_postboot "cmdq unblock requested"
fi

sleep 1

if [ -e /proc/m681_dsi_recover_now ]; then
    # 20260430 logs show this leaves DSI0 in CMD_MODE/HS=0 after Android is up.
    # Keep the proc node for manual testing, but do not auto-fire it at boot.
    log -t m681_postboot "dsi recover left manual"
fi

log -t m681_postboot "txd1 late refinit/panel wake disabled; v40 proved this stops DSI/DDP"

# The daemons are already started by init when the device node appears. A late
# restart kills the working session and shows up as IFingerprintDaemon death.
setprop debug.m681.postboot_recover done
log -t m681_postboot "end"
