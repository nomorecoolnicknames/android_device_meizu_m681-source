#!/system/bin/sh

TAG=m681_conn_autostart
WPA_SOCKET=/data/misc/wifi/sockets/wlan0

log -t "$TAG" "begin"

# --- consys arm (BT lane, 2026-07-27) -------------------------------------
# Ported from the device-proven 15.1 kit (m681/wifi-framework/system-overlay/
# bin/m681-wifi-arm.sh), which the 16.0 /system reflash removed.
#
# Nothing else in this ROM creates /dev/stpwmt, /dev/wmtWifi or /dev/stpbt:
# they appear only inside do_connectivity_driver_init(), which runs only when
# wmt_loader issues COMBO_IOCTL_DO_MODULE_INIT. Until 2026-07-27 the service
# pointed at /system/bin/wmt_loader, which has never existed, so the whole
# connectivity stack was down -- no BT node and no wlan0.
STAGE=/sys/module/mtk_wcn_consys_hw/parameters/forge_conn_pwron_stage
EMI=/sys/module/mtk_wcn_consys_hw/parameters/forge_conn_emi
AUTO=/sys/module/wmt_dev/parameters/forge_conn_autopwr

# Idempotent: only kick the loader if the nodes are not already there. A second
# DO_MODULE_INIT pass re-enters MODULE_CLEANUP/sdio_detect_exit and re-runs
# BT_init, whose register_chrdev_region(major 192) then fails.
if [ ! -c /dev/wmtWifi ]; then
    setprop debug.m681.wmt.start 1
    n=0
    while [ ! -c /dev/wmtWifi ] && [ "$n" -lt 10 ]; do
        n=$((n + 1)); sleep 1
    done
    if [ ! -c /dev/wmtWifi ]; then
        /vendor/bin/wmt_loader &
        sleep 3
    fi
fi

# Suppress m681_wifi_kick.sh's start_wmt() (it re-triggers debug.m681.wmt.start
# and would cause exactly the duplicate pass described above).
[ -c /dev/wmtWifi ] && setprop debug.m681.wmt.ready 1

# The EMI knob only accepts writes once hw_init has run, i.e. after the loader.
n=0
while [ "$n" -lt 15 ]; do
    echo 7 > "$EMI" 2>/dev/null
    [ "`cat $EMI 2>/dev/null`" = "7" ] && break
    n=$((n + 1)); sleep 2
done
echo 4 > "$STAGE" 2>/dev/null

# --- PSM off, boot-effective (BT lane, 2026-07-28) -------------------------
# The chip does not answer the WMT sleep request: opfunc_pwr_sv reads 0 of the 6
# expected SLEEP_EVT bytes and the HOST then deliberately asserts the firmware
# ("host trigger firmware assert", reason 33). That assert becomes a whole-chip
# reset, which arrives at BT as a malformed HW_ERROR read and at WiFi as a
# wlan0 teardown -- device-measured at a hard ~15 s cadence, 6/6 asserts
# reason(33), 0 reason(40).
#
# ORDER MATTERS. The forge_conn_psm gate suppresses an ENABLE; it cannot stop a
# PSM state machine that is already running, which is why a runtime write after
# BT came up did nothing. Set it here, before this script enables Bluetooth
# below, so the HAL's first COMBO_IOCTL_BT_SET_PSM is suppressed and PSM never
# starts. wmt_exp.c:161 is evaluated per call, so this is a set-early problem,
# not an init-time-read problem -- no kernel change is needed.
#
# ⚠ Path is /sys/module/WMT_EXP/..., not mtk_wcn_consys_hw like the other forge
# knobs: it compiles as wmt_exp.forge_conn_psm. A wrong path fails silently.
PSM=/sys/module/wmt_exp/parameters/forge_conn_psm
[ -w "$PSM" ] && echo 0 > "$PSM"

# Belt: wmt_dbg opcode 0x0 with par2=0 calls wmt_lib_ps_ctrl(0) DIRECTLY,
# bypassing the gate above, so it disables a PSM that is already running --
# the exact state the earlier runtime test hit. Covers the residual race where
# the framework auto-enables BT from persisted bluetooth_on at the same moment
# this script runs.
echo "0 0" > /proc/driver/wmt_dbg 2>/dev/null

log -t "$TAG" "psm: gate=$(cat $PSM 2>/dev/null) (0 = suppressed); wmt_dbg disable issued"
# --- end PSM off ------------------------------------------------------------

# forge_conn_autopwr deliberately left at 0. Its only effect is to let the
# fb-notifier work item WMT_init installs power consys spontaneously on screen
# blank/unblank (wmt_dev.c:264-269) -- the documented boot-reset-loop path. The
# BT HAL does not need it: opening /dev/stpbt drives mtk_wcn_wmt_func_on()
# directly. Flip to 1 here once consys power-on is proven green on 16.0.
log -t "$TAG" "knobs: stage=`cat $STAGE 2>/dev/null` emi=`cat $EMI 2>/dev/null` auto=`cat $AUTO 2>/dev/null`"

# Belt only. Device-verified 2026-07-27: ueventd.mt6755.rc:31 already brings the
# node up as bluetooth:bluetooth 0660, so this is not the 15.1-era perms fix.
if [ -c /dev/stpbt ]; then
    chown bluetooth:bluetooth /dev/stpbt 2>/dev/null || chown bluetooth.bluetooth /dev/stpbt 2>/dev/null
    chmod 0660 /dev/stpbt 2>/dev/null
fi
# --- end consys arm --------------------------------------------------------

wifi_status()
{
    /system/bin/wpa_cli -p/data/misc/wifi/sockets -iwlan0 status 2>/dev/null
}

wifi_has_ip()
{
    /system/bin/ip addr show wlan0 2>/dev/null | /system/bin/grep -q " inet "
}

wifi_connected()
{
    if [ ! -S "$WPA_SOCKET" ]; then
        return 1
    fi

    case "`wifi_status`" in
        *"wpa_state=COMPLETED"*)
            if wifi_has_ip; then
                return 0
            fi
            ;;
    esac

    return 1
}

wifi_reconnect()
{
    if [ -S "$WPA_SOCKET" ]; then
        if wifi_connected; then
            log -t "$TAG" "wifi already connected with ip; skip reconnect"
            return 0
        fi
        /system/bin/wpa_cli -p/data/misc/wifi/sockets -iwlan0 enable_network all >/dev/null 2>&1
        /system/bin/wpa_cli -p/data/misc/wifi/sockets -iwlan0 scan >/dev/null 2>&1
        sleep 4
        if wifi_connected; then
            /system/bin/wpa_cli -p/data/misc/wifi/sockets -iwlan0 save_config >/dev/null 2>&1
            log -t "$TAG" "wifi connected after scan; skip reconnect"
            return 0
        fi
        /system/bin/wpa_cli -p/data/misc/wifi/sockets -iwlan0 reconnect >/dev/null 2>&1
        /system/bin/wpa_cli -p/data/misc/wifi/sockets -iwlan0 save_config >/dev/null 2>&1
        log -t "$TAG" "requested wifi reconnect"
        return 0
    fi
    return 1
}

bluetooth_ready()
{
    case "`/system/bin/getprop service.wcn.driver.ready`:`/system/bin/getprop debug.m681.wmt.ready`" in
        yes:*|*:1)
            ;;
        *)
            return 1
            ;;
    esac

    [ -c /dev/stpbt ] || return 1
    return 0
}

# --- single gated Wi-Fi re-enable (kwifi, 2026-07-28) -----------------------
# THIS IS AN INSTRUMENT, NOT A FIX. See docs/M681_LANE_WIFI_LOS16_20260728.md.
#
# WHY IT EXISTS. The framework reads Settings.Global.WIFI_ON exactly ONCE, at
# boot phase 500, and there is no ContentObserver on that setting
# (WifiServiceImpl.java:2497-2505 registers one only for scan-always-available).
# Measured on this device, offsets from boot:
#     T+19.0s  phase 500, wifi_on read, CMD_WIFI_TOGGLED
#     T+20.7s  CMD_STA_START_FAILURE -- wlan0 does not exist yet
#     T+74.5s  wlan0 first exists
# The framework's single native attempt therefore always lands ~55 s early and
# nothing retries it. Without this, WifiNative.startSupplicant() is never
# reached at all, so nothing downstream of it can be tested.
#
# IDEMPOTENCE KEY: the property debug.m681.wifi.reenable, CLAIMED AT ENTRY.
# init restarts this service once per sys.boot_completed, i.e. once per
# system_server restart, so a second instance is expected; it sees a non-empty
# key and returns without enabling. The key is not ro.* and init does not clear
# it, so it survives a system_server restart -- deliberately: a restarting
# system_server is exactly the pre-phase-500 window in which an unguarded
# CMD_WIFI_TOGGLED killed system_server three times on 2026-07-28.
# Claim-at-entry is not atomic; the race window is the few ms between getprop
# and setprop, and the worst case is one extra FULLY GATED enable, which is
# safe by construction.
wifi_reenable_once()
{
    if [ -n "`getprop debug.m681.wifi.reenable`" ]; then
        return 0
    fi
    setprop debug.m681.wifi.reenable running

    # GATE 1 -- the interface must exist. Without it STA start fails in ~1 s.
    g1=absent
    n=0
    while [ "$n" -lt 60 ]; do
        if [ -d /sys/class/net/wlan0 ]; then g1=present; break; fi
        n=$((n + 1)); sleep 2
    done

    # GATE 2 -- WifiController must have STARTED. A StateMachine accumulates
    # records only inside SmHandler.handleMessage, which cannot run before
    # start(). On a half-started system_server this reads 0 and we refuse to
    # fire. FALSIFIER: if any boot ever logs
    #   FATAL EXCEPTION IN SYSTEM PROCESS: WifiService ... what=155656
    # AFTER this function's "FIRING" line, then records>0 did not imply start()
    # and this gate is invalid. An empty/failed dumpsys reads 0 and blocks,
    # which is the fail-safe direction.
    g2=0
    n=0
    while [ "$n" -lt 30 ]; do
        g2=`dumpsys wifi 2>/dev/null | grep -A1 "WifiController:" \
            | sed -n 's/.*total records=\([0-9][0-9]*\).*/\1/p'`
        [ -z "$g2" ] && g2=0
        if [ "$g2" -gt 0 ]; then break; fi
        n=$((n + 1)); sleep 2
    done

    if [ "$g1" = present ] && [ "$g2" -gt 0 ]; then
        setprop debug.m681.wifi.reenable done
        log -t "$TAG" "wifi re-enable FIRING: gate1 wlan0=$g1 gate2 WifiController_records=$g2"
        /system/bin/svc wifi enable
    else
        setprop debug.m681.wifi.reenable "blocked_g1_${g1}_g2_${g2}"
        log -t "$TAG" "wifi re-enable BLOCKED: gate1 wlan0=$g1 gate2 WifiController_records=$g2"
    fi
}
# --- end single gated Wi-Fi re-enable ---------------------------------------

# Let system_server, SettingsProvider and the MTK connectivity services settle.
sleep 12

/system/bin/settings put global wifi_on 1
/system/bin/settings put global wifi_saved_state 1 2>/dev/null
/system/bin/setprop debug.m681.wifi.power 1
# NO `svc wifi enable` HERE, OR ANYWHERE BELOW -- this is deliberate, do not
# restore it. Persisting wifi_on above is the ordering-safe equivalent:
# WifiServiceImpl.checkAndStartWifi() reads that setting and enables Wi-Fi
# itself at :619-621, immediately AFTER mWifiController.start() at :615.
# Device-verified 2026-07-28: on a healthy boot the framework logs
#   I WifiService: WifiService starting up with Wi-Fi enabled
#   D WifiService: setWifiEnabled: true pid=679, uid=1000, package=android
# one boot phase (500) after registration, with no help from this script.
#
# An `svc wifi enable` is not merely redundant, it is unsafe. It reaches
# WifiServiceImpl.setWifiEnabled() -> :907 mWifiController.sendMessage(
# CMD_WIFI_TOGGLED), which is UNGUARDED. If it lands before start() -- which
# happens whenever system_server is restarting, because this service re-runs on
# every sys.boot_completed and its retry ladder then fires into a half-started
# incarnation -- WifiController throws
#   RuntimeException: StateMachine.handleMessage: The start method not called,
#                     received msg: { what=155656 ... }
# and takes system_server (and SystemUI) down with it. That converts a single
# recoverable restart into a crash loop. Measured 2026-07-28: 3 such deaths in
# one boot, each 2 ms after this script's `svc` call.
# Full record: docs/LANE_WIFI_LOS16_20260728.md in the m681 repo.
log -t "$TAG" "wifi_on persisted; framework enables Wi-Fi at boot phase 500"

wait_count=0
while [ "$wait_count" -lt 30 ]; do
    if wifi_reconnect; then
        break
    fi
    wait_count=$((wait_count + 1))
    sleep 2
done

if bluetooth_ready; then
    /system/bin/settings put global bluetooth_on 1
    # svc, not `service call bluetooth_manager 6`: that transaction number is
    # Oreo-era and unverified on Pie. svc bluetooth exists in this tree
    # (frameworks/base/cmds/svc/.../BluetoothCommand.java).
    /system/bin/svc bluetooth enable >/dev/null 2>&1
    log -t "$TAG" "requested bluetooth enable"
else
    /system/bin/settings put global bluetooth_on 0 2>/dev/null
    log -t "$TAG" "skip bluetooth enable: wmt/stpbt not ready"
fi

wifi_reenable_once

sleep 8
wifi_reconnect

for delay in 10 20 35; do
    sleep "$delay"
    if wifi_connected; then
        log -t "$TAG" "wifi stable; stop retry loop"
        break
    fi
    wifi_reconnect
done

log -t "$TAG" "end"
