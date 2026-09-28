#!/system/bin/sh

STAGE="$1"
[ -n "$STAGE" ] || STAGE="unknown"
BOOTDIAG_ENABLED="$(getprop persist.m681.bootdiag 2>/dev/null)"
if [ "$BOOTDIAG_ENABLED" != "1" ]; then
    BOOTDIAG_ENABLED="$(getprop persist.l681.bootdiag 2>/dev/null)"
fi
[ "$BOOTDIAG_ENABLED" = "1" ] || exit 0

case "$STAGE" in
    late-45)
        sleep 45
        ;;
esac

CACHE_BLK="/dev/block/mmcblk0p30"
CACHE_BLK_ALT="/dev/block/platform/mtk-msdc.0/11230000.msdc0/by-name/cache"
STAMP="$(date +%Y%m%d-%H%M%S 2>/dev/null)"
[ -n "$STAMP" ] || STAMP="20100104-000000"
MSG="m681-bootdiag:${STAMP}:${STAGE}"
OUTDIR="/cache/bootdiag-pstore"

ensure_cache() {
    mkdir -p /cache 2>/dev/null || true
    if ! touch /cache/.m681_bootdiag_probe.$$ >/dev/null 2>&1; then
        mount /cache >/dev/null 2>&1 || true
        mount -t ext4 "$CACHE_BLK" /cache >/dev/null 2>&1 || true
        mount -t ext4 "$CACHE_BLK_ALT" /cache >/dev/null 2>&1 || true
    fi
    rm -f /cache/.m681_bootdiag_probe.$$ >/dev/null 2>&1 || true
}

clean_stale_bootdiag_once() {
    case "$STAGE" in
        early-init)
            rm -rf "$OUTDIR"/* /tmp/bootdiag/* 2>/dev/null || true
            echo "$MSG cleaned stale bootdiag cache" > "$OUTDIR/bootdiag-clean-marker.txt" 2>/dev/null || true
            ;;
    esac
}

write_prop_snapshot() {
    local dst="$1"
    {
        echo "stage=$STAGE"
        echo "stamp=$STAMP"
        echo "ro.bootmode=$(getprop ro.bootmode 2>/dev/null)"
        echo "sys.boot_completed=$(getprop sys.boot_completed 2>/dev/null)"
        echo "dev.bootcomplete=$(getprop dev.bootcomplete 2>/dev/null)"
        echo "vold.decrypt=$(getprop vold.decrypt 2>/dev/null)"
        echo "init.svc.servicemanager=$(getprop init.svc.servicemanager 2>/dev/null)"
        echo "init.svc.vold=$(getprop init.svc.vold 2>/dev/null)"
        echo "init.svc.installd=$(getprop init.svc.installd 2>/dev/null)"
        echo "init.svc.surfaceflinger=$(getprop init.svc.surfaceflinger 2>/dev/null)"
        echo "init.svc.system_server=$(getprop init.svc.system_server 2>/dev/null)"
        echo "init.svc.adbd=$(getprop init.svc.adbd 2>/dev/null)"
        echo "init.svc.cameraserver=$(getprop init.svc.cameraserver 2>/dev/null)"
        echo "init.svc.pq=$(getprop init.svc.pq 2>/dev/null)"
        echo "init.svc.guiext-server=$(getprop init.svc.guiext-server 2>/dev/null)"
        echo "init.svc.zygote=$(getprop init.svc.zygote 2>/dev/null)"
        echo "init.svc.zygote_secondary=$(getprop init.svc.zygote_secondary 2>/dev/null)"
        echo "init.svc.bootanim=$(getprop init.svc.bootanim 2>/dev/null)"
        echo "init.svc.mobicore=$(getprop init.svc.mobicore 2>/dev/null)"
        echo "init.svc.wmt_loader=$(getprop init.svc.wmt_loader 2>/dev/null)"
        echo "init.svc.wmt_launcher=$(getprop init.svc.wmt_launcher 2>/dev/null)"
        echo "init.svc.wpa_supplicant=$(getprop init.svc.wpa_supplicant 2>/dev/null)"
        echo "init.svc.p2p_supplicant=$(getprop init.svc.p2p_supplicant 2>/dev/null)"
        echo "init.svc.fuelgauged=$(getprop init.svc.fuelgauged 2>/dev/null)"
        echo "init.svc.batterywarning=$(getprop init.svc.batterywarning 2>/dev/null)"
        echo "init.svc.goodixfpd=$(getprop init.svc.goodixfpd 2>/dev/null)"
        echo "init.svc.fingerprintd=$(getprop init.svc.fingerprintd 2>/dev/null)"
        echo "init.svc.ril-proxy=$(getprop init.svc.ril-proxy 2>/dev/null)"
        echo "init.svc.ril-daemon=$(getprop init.svc.ril-daemon 2>/dev/null)"
        echo "init.svc.ril-daemon-mtk=$(getprop init.svc.ril-daemon-mtk 2>/dev/null)"
        echo "init.svc.ril-daemon-md2=$(getprop init.svc.ril-daemon-md2 2>/dev/null)"
        echo "service.bootanim.exit=$(getprop service.bootanim.exit 2>/dev/null)"
        echo "service.nvram_init=$(getprop service.nvram_init 2>/dev/null)"
        echo "wlan.driver.status=$(getprop wlan.driver.status 2>/dev/null)"
        echo "service.wcn.driver.ready=$(getprop service.wcn.driver.ready 2>/dev/null)"
        echo "persist.mtk.wcn.combo.chipid=$(getprop persist.mtk.wcn.combo.chipid 2>/dev/null)"
        echo "persist.mtk.wcn.patch.version=$(getprop persist.mtk.wcn.patch.version 2>/dev/null)"
        echo "debug.m681.wmt.ready=$(getprop debug.m681.wmt.ready 2>/dev/null)"
        echo "debug.m681.wmt.start=$(getprop debug.m681.wmt.start 2>/dev/null)"
        echo "debug.sf.force_fbdev=$(getprop debug.sf.force_fbdev 2>/dev/null)"
        echo "debug.sf.force_screen_on=$(getprop debug.sf.force_screen_on 2>/dev/null)"
        echo "debug.sf.internal_fbdev=$(getprop debug.sf.internal_fbdev 2>/dev/null)"
        echo "debug.sf.internal_fbdev_marker=$(getprop debug.sf.internal_fbdev_marker 2>/dev/null)"
        echo "debug.sf.fb_force_bl=$(getprop debug.sf.fb_force_bl 2>/dev/null)"
        echo "debug.sf.internal_fbdev_keep_on=$(getprop debug.sf.internal_fbdev_keep_on 2>/dev/null)"
        echo "debug.sf.internal_fbdev_blank=$(getprop debug.sf.internal_fbdev_blank 2>/dev/null)"
        echo "debug.sf.internal_fbdev_last=$(getprop debug.sf.internal_fbdev_last 2>/dev/null)"
        echo "debug.sf.mtkfb_kick=$(getprop debug.sf.mtkfb_kick 2>/dev/null)"
        echo "debug.sf.internal_fbdev_wait=$(getprop debug.sf.internal_fbdev_wait 2>/dev/null)"
        echo "debug.sf.disable_hwc=$(getprop debug.sf.disable_hwc 2>/dev/null)"
        echo "debug.sf.disable_hwc_vds=$(getprop debug.sf.disable_hwc_vds 2>/dev/null)"
        echo "debug.sf.no_hw_fences=$(getprop debug.sf.no_hw_fences 2>/dev/null)"
        echo "debug.sf.no_hw_vsync=$(getprop debug.sf.no_hw_vsync 2>/dev/null)"
        echo "debug.sf.hwc_set_diag=$(getprop debug.sf.hwc_set_diag 2>/dev/null)"
        echo "debug.sf.internal_fbdev_write=$(getprop debug.sf.internal_fbdev_write 2>/dev/null)"
        echo "debug.sf.intfb_copy_all=$(getprop debug.sf.intfb_copy_all 2>/dev/null)"
        echo "debug.sf.intfb_sync_period=$(getprop debug.sf.intfb_sync_period 2>/dev/null)"
        echo "debug.sf.nobootanimation=$(getprop debug.sf.nobootanimation 2>/dev/null)"
        echo "ro.sf.hwvsync.disable=$(getprop ro.sf.hwvsync.disable 2>/dev/null)"
        echo "ro.sf.triplebuf.disable=$(getprop ro.sf.triplebuf.disable 2>/dev/null)"
        m681_force_fbdev="$(getprop debug.sf.force_fbdev 2>/dev/null)"
        m681_disable_hwc="$(getprop debug.sf.disable_hwc 2>/dev/null)"
        m681_no_fences="$(getprop debug.sf.no_hw_fences 2>/dev/null)"
        m681_no_vsync="$(getprop debug.sf.no_hw_vsync 2>/dev/null)"
        m681_keep_on="$(getprop debug.sf.internal_fbdev_keep_on 2>/dev/null)"
        m681_hwvsync_disable="$(getprop ro.sf.hwvsync.disable 2>/dev/null)"
        m681_triple_disable="$(getprop ro.sf.triplebuf.disable 2>/dev/null)"
        if [ "$m681_force_fbdev" = "1" ] && [ "$m681_disable_hwc" = "1" ] && [ "$m681_no_fences" = "1" ] && [ "$m681_no_vsync" = "1" ] && [ "$m681_keep_on" = "1" ] && [ "$m681_hwvsync_disable" = "1" ] && [ "$m681_triple_disable" = "1" ]; then
            echo "m681.display.profile=v103-visible-forced-fbdev"
        elif [ "$m681_force_fbdev" = "0" ] && [ "$m681_disable_hwc" = "0" ] && [ "$m681_no_fences" = "0" ] && [ "$m681_no_vsync" = "0" ] && [ "$m681_hwvsync_disable" = "0" ]; then
            echo "m681.display.profile=hwc-first-transition"
        else
            echo "m681.display.profile=mixed-display-props"
        fi
        echo "persist.sys.usb.config=$(getprop persist.sys.usb.config 2>/dev/null)"
        echo "sys.usb.config=$(getprop sys.usb.config 2>/dev/null)"
        echo "sys.usb.state=$(getprop sys.usb.state 2>/dev/null)"
        echo "ro.adb.secure=$(getprop ro.adb.secure 2>/dev/null)"
        echo "ro.debuggable=$(getprop ro.debuggable 2>/dev/null)"
        echo "ro.hardware=$(getprop ro.hardware 2>/dev/null)"
        echo "ro.hardware.camera=$(getprop ro.hardware.camera 2>/dev/null)"
        echo "ro.hardware.fingerprint=$(getprop ro.hardware.fingerprint 2>/dev/null)"
        echo "ro.hardware.gralloc=$(getprop ro.hardware.gralloc 2>/dev/null)"
        echo "ro.hardware.hwcomposer=$(getprop ro.hardware.hwcomposer 2>/dev/null)"
        echo "ro.hardware.sensors=$(getprop ro.hardware.sensors 2>/dev/null)"
        echo "qemu.hw.mainkeys=$(getprop qemu.hw.mainkeys 2>/dev/null)"
        echo "ps_boot_begin"
        ps 2>/dev/null | grep -E 'bootanim|surfaceflinger|system_server|zygote|wmt_|wpa_|fuelgauged|goodix|fingerprintd|cameraserver|ril|ccci' 2>/dev/null || echo "<unavailable>"
        echo "ps_boot_end"
    } > "$dst" 2>/dev/null || true
}

should_capture_runtime_artifacts() {
    case "$STAGE" in
        boot-complete)
            return 0
            ;;
        surfaceflinger-running|bootanim-running|late-45)
            [ "$(getprop persist.m681.bootdiag.runtime 2>/dev/null)" = "1" ] && return 0
            [ "$(getprop persist.l681.bootdiag.runtime 2>/dev/null)" = "1" ] && return 0
            ;;
    esac
    return 1
}

write_runtime_artifacts() {
    local prefix="$1"
    should_capture_runtime_artifacts || return 0

    if [ -x /system/bin/screencap ]; then
        /system/bin/screencap -p "${prefix}-screencap.png" >/dev/null 2>&1 || true
    fi

    if [ -x /system/bin/dumpsys ]; then
        /system/bin/dumpsys SurfaceFlinger > "${prefix}-sf.txt" 2>&1 || true
        /system/bin/dumpsys display > "${prefix}-displaydump.txt" 2>&1 || true
        /system/bin/dumpsys power > "${prefix}-power.txt" 2>&1 || true
        /system/bin/dumpsys battery > "${prefix}-battery.txt" 2>&1 || true
    fi

    # `service list` probes every registered binder service from init context.
    # On v38 it generated radio/camera/netd binder traffic right before the
    # fragile rilproxy/camera bring-up window, so keep it opt-in.
    if [ "$(getprop persist.m681.bootdiag.service_list 2>/dev/null)" = "1" ] && \
            [ -x /system/bin/service ]; then
        /system/bin/service list > "${prefix}-service-list.txt" 2>&1 || true
    fi

    if [ -r /dev/graphics/fb0 ]; then
        dd if=/dev/graphics/fb0 bs=4 count=64 2>/dev/null | od -An -tx4 \
            > "${prefix}-fb0-head.txt" 2>/dev/null || true
    fi

    {
        echo "dev_connectivity_begin"
        ls -l /dev/wmtWifi /dev/stp* /dev/ttyMT* 2>/dev/null || echo "<unavailable>"
        echo "dev_connectivity_end"
        echo "dev_input_begin"
        ls -l /dev/input /dev/input/event* 2>/dev/null || echo "<unavailable>"
        cat /proc/bus/input/devices 2>/dev/null || echo "<unavailable>"
        echo "dev_input_end"
        echo "dev_radio_begin"
        ls -l /dev/ccci* /dev/ttyC* /dev/ccmni* 2>/dev/null || echo "<unavailable>"
        ls -l /sys/class/net/ccmni* 2>/dev/null || echo "<unavailable>"
        echo "dev_radio_end"
        echo "dev_camera_begin"
        ls -l \
            /dev/camera-* \
            /dev/kd_camera_hw \
            /dev/kd_camera_hw_bus2 \
            /dev/kd_camera_flashlight \
            /dev/CAM_CAL_DRV* \
            /dev/MAINAF \
            /dev/MAINAF2 \
            /dev/SUBAF \
            /dev/DW9718AF \
            /dev/FM50AF 2>/dev/null || echo "<unavailable>"
        echo "dev_camera_end"
        echo "dev_fingerprint_begin"
        ls -l /dev/goodix_fp /dev/fingerprint* 2>/dev/null || echo "<unavailable>"
        echo "dev_fingerprint_end"
        echo "sys_class_net_begin"
        ls -l /sys/class/net 2>/dev/null || echo "<unavailable>"
        echo "sys_class_net_end"
        echo "wifi_nvram_begin"
        ls -l /data/nvram/APCFG/APRDEB/WIFI* /nvdata/APCFG/APRDEB/WIFI* 2>/dev/null || echo "<unavailable>"
        for path in /data/nvram/APCFG/APRDEB/WIFI /nvdata/APCFG/APRDEB/WIFI; do
            [ -r "$path" ] || continue
            echo "wifi_nvram_head=$path"
            dd if="$path" bs=1 count=64 2>/dev/null | od -An -tx1 2>/dev/null || true
        done
        echo "wifi_nvram_end"
        echo "power_supply_begin"
        for path in /sys/class/power_supply/*; do
            [ -d "$path" ] || continue
            echo "power_supply=$path"
            for name in type status capacity voltage_now current_now online present health temp; do
                [ -e "$path/$name" ] || continue
                printf "%s/%s=" "$path" "$name"
                cat "$path/$name" 2>/dev/null || echo "<unavailable>"
            done
        done
        echo "power_supply_end"
    } > "${prefix}-runtime-hw.txt" 2>&1 || true
}

write_display_snapshot() {
    local dst="$1"
    {
        echo "stage=$STAGE"
        echo "stamp=$STAMP"
        echo "proc_fb_begin"
        cat /proc/fb 2>/dev/null || echo "<unavailable>"
        echo "proc_fb_end"
        echo "proc_devices_fb_begin"
        grep -i "fb" /proc/devices 2>/dev/null || echo "<unavailable>"
        echo "proc_devices_fb_end"
        echo "proc_m681_fbdiag_begin"
        cat /proc/m681_fbdiag 2>/dev/null || echo "<unavailable>"
        echo "proc_m681_fbdiag_end"
        for node in \
            /proc/m681_dsi_irq_diag \
            /proc/m681_txd1_diag \
            /proc/m681_disp_path_diag \
            /proc/m681_dsi_low_diag \
            /proc/m681_dsi_decode_diag \
            /proc/m681_disp_timeseries \
            /proc/m681_disp_trace \
            /proc/m681_mtkfb_diag \
            /proc/m681_primary_diag; do
            tag="$(basename "$node")"
            echo "${tag}_begin"
            cat "$node" 2>/dev/null || echo "<unavailable>"
            echo "${tag}_end"
        done
        echo "sys_class_graphics_begin"
        ls -l /sys/class/graphics 2>/dev/null || echo "<unavailable>"
        ls -l /sys/class/graphics/fb* 2>/dev/null || echo "<unavailable>"
        for path in /sys/class/graphics/fb*/name; do
            [ -e "$path" ] || continue
            printf "%s=" "$path"
            cat "$path" 2>/dev/null || echo "<unavailable>"
        done
        for path in \
            /sys/class/graphics/fb0/bits_per_pixel \
            /sys/class/graphics/fb0/modes \
            /sys/class/graphics/fb0/blank; do
            [ -e "$path" ] || continue
            printf "%s=" "$path"
            cat "$path" 2>/dev/null || echo "<unavailable>"
        done
        echo "sys_class_graphics_end"
        echo "sys_platform_devices_mtkfb_begin"
        ls -l /sys/bus/platform/devices/*mtkfb* 2>/dev/null || echo "<unavailable>"
        for path in /sys/bus/platform/devices/*mtkfb*; do
            [ -e "$path" ] || continue
            echo "platform_dev=$path"
            ls -l "$path/driver" 2>/dev/null || echo "$path/driver=<unavailable>"
            if [ -e "$path/of_node/compatible" ]; then
                printf "%s/of_node/compatible=" "$path"
                cat "$path/of_node/compatible" 2>/dev/null || echo "<unavailable>"
            else
                echo "$path/of_node/compatible=<unavailable>"
            fi
            if [ -e "$path/modalias" ]; then
                printf "%s/modalias=" "$path"
                cat "$path/modalias" 2>/dev/null || echo "<unavailable>"
            else
                echo "$path/modalias=<unavailable>"
            fi
        done
        echo "sys_platform_devices_mtkfb_end"
        echo "sys_platform_driver_mtkfb_begin"
        ls -l /sys/bus/platform/drivers/mtkfb 2>/dev/null || echo "<unavailable>"
        echo "sys_platform_driver_mtkfb_end"
        echo "dev_graphics_begin"
        ls -l /dev/graphics/fb* 2>/dev/null || echo "<unavailable>"
        echo "dev_graphics_end"
        echo "dev_fb_begin"
        ls -l /dev/fb* 2>/dev/null || echo "<unavailable>"
        echo "dev_fb_end"
        echo "backlight_begin"
        for path in \
            /sys/class/leds/lcd-backlight/brightness \
            /sys/class/leds/lcd-backlight/max_brightness \
            /sys/class/backlight/lcd-backlight/brightness \
            /sys/class/backlight/lcd-backlight/max_brightness \
            /sys/class/backlight/panel/brightness \
            /sys/class/backlight/panel/max_brightness; do
            [ -e "$path" ] || continue
            printf "%s=" "$path"
            cat "$path" 2>/dev/null || echo "<unavailable>"
        done
        echo "backlight_end"
    } > "$dst" 2>/dev/null || true
}

should_capture_kernel_artifacts() {
    case "$STAGE" in
        early-init|init|late-init|post-fs|post-fs-data|boot|late-45|nonencrypted|restart-framework|servicemanager-running|vold-running|installd-running|surfaceflinger-running|bootanim-running|zygote-running|mobicore-running|boot-complete)
            return 0
            ;;
    esac
    return 1
}

write_kernel_log_snapshot() {
    local prefix="$1"
    local dmesg_file="${prefix}-dmesg.txt"
    local kernel_logcat_file="${prefix}-logcat-kernel.txt"
    local all_logcat_file="${prefix}-logcat-all.txt"
    local filtered_file="${prefix}-display-kernel-filter.txt"

    should_capture_kernel_artifacts || return 0

    dmesg > "$dmesg_file" 2>&1 || true

    if [ -x /system/bin/logcat ]; then
        /system/bin/logcat -b kernel -d -v threadtime > "$kernel_logcat_file" 2>&1 || true
        if [ "$STAGE" = "boot-complete" ]; then
            /system/bin/logcat -b all -d -v threadtime > "$all_logcat_file" 2>&1 || true
        fi
    fi

    {
        echo "stage=$STAGE"
        echo "stamp=$STAMP"
        echo "display_kernel_filter_begin"
        grep -E -i \
            'M681|TXD1|ili9885|LCM|tps65132|primary_display|disp_lcm|mtkfb|fb0|DSI|ddp|MIPI|AAL|ESD|wlan|wifi|WMT|CONSYS|ccci|modem|md1|md3|ccmni|goodix|fingerprint|tpd|touch|msg2838|gt1151|camera|kd_camera|flashlight' \
            "$dmesg_file" "$kernel_logcat_file" 2>/dev/null || echo "<no matches>"
        echo "display_kernel_filter_end"
    } > "$filtered_file" 2>&1 || true
}

echo "$MSG" > /dev/kmsg 2>/dev/null || true
echo "$MSG" > /dev/pmsg0 2>/dev/null || true
echo "$MSG" > /proc/bootprof 2>/dev/null || true

mkdir -p /tmp/bootdiag 2>/dev/null || true
echo "$MSG" > "/tmp/bootdiag/${STAGE}.txt" 2>/dev/null || true
write_prop_snapshot "/tmp/bootdiag/${STAGE}.props.txt"
write_display_snapshot "/tmp/bootdiag/${STAGE}.display.txt"
write_runtime_artifacts "/tmp/bootdiag/${STAMP}-${STAGE}"
write_kernel_log_snapshot "/tmp/bootdiag/${STAMP}-${STAGE}"

ensure_cache
mkdir -p "$OUTDIR" 2>/dev/null || true
clean_stale_bootdiag_once
echo "$MSG" >> "$OUTDIR/bootdiag-markers.txt" 2>/dev/null || true
echo "$STAGE" > "$OUTDIR/last-stage.txt" 2>/dev/null || true
echo "$STAMP" > "$OUTDIR/last-stage-stamp.txt" 2>/dev/null || true
write_prop_snapshot "$OUTDIR/props-${STAMP}-${STAGE}.txt"
write_display_snapshot "$OUTDIR/display-${STAMP}-${STAGE}.txt"
write_runtime_artifacts "$OUTDIR/${STAMP}-${STAGE}"
write_kernel_log_snapshot "$OUTDIR/${STAMP}-${STAGE}"

exit 0
