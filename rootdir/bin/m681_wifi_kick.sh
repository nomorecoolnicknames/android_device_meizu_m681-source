#!/system/bin/sh

TAG=m681_wifi_kick
WMT_NODE=/dev/stpwmt
WIFI_NODE=/dev/wmtWifi
WLAN_NODE=/sys/class/net/wlan0
MAX_ATTEMPTS=4
WLAN_WAIT=30
WMT_WAIT=30
WMT_SETTLE=5
POSTBOOT_DELAY=10
NVRAM_WAIT=30

node_state()
{
    if [ -d "$1" ]; then
        echo dir
    elif [ -e "$1" ]; then
        echo present
    else
        echo missing
    fi
}

log_status()
{
    log -t "$TAG" "$1: stpwmt=$(node_state "$WMT_NODE") wmtWifi=$(node_state "$WIFI_NODE") wlan0=$(node_state "$WLAN_NODE") nvram=$(getprop service.nvram_init) wcn=$(getprop service.wcn.driver.ready) chipid=$(getprop persist.mtk.wcn.combo.chipid) loader=$(getprop init.svc.wmt_loader) launcher=$(getprop init.svc.wmt_launcher) wlan_status=$(getprop wlan.driver.status)"
}

start_wmt()
{
    setprop debug.m681.wmt.start 0
    sleep 1
    setprop debug.m681.wmt.start 1
}

wait_nvram()
{
    wait_count=0
    while [ "$(getprop service.nvram_init)" != "Ready" ] && \
          [ "$wait_count" -lt "$NVRAM_WAIT" ]; do
        setprop debug.m681.wifi.kick wait_nvram
        wait_count=$((wait_count + 1))
        sleep 1
    done
    if [ "$(getprop service.nvram_init)" != "Ready" ]; then
        setprop debug.m681.wifi.kick nvram_not_ready
        log_status "NVRAM not ready"
        return 1
    fi
    return 0
}

if [ "$1" = "postboot" ]; then
    setprop debug.m681.wifi.kick postboot_delay
    log_status "postboot delay"
    sleep "$POSTBOOT_DELAY"
fi

log_status "begin"
wait_nvram || exit 1

if [ -d "$WLAN_NODE" ]; then
    setprop debug.m681.wifi.kick wlan0_present
    setprop wlan.driver.status ok
    log_status "wlan0 already present"
    exit 0
fi

if [ "$(getprop service.wcn.driver.ready)" = "yes" ]; then
    setprop debug.m681.wmt.ready 1
fi

if [ "$(getprop debug.m681.wmt.ready)" != "1" ]; then
    setprop debug.m681.wifi.kick start_wmt
    start_wmt
    log_status "WMT not ready; starting on demand"
    wait_count=0
    while [ "$wait_count" -lt "$WMT_WAIT" ]; do
        if [ "$(getprop debug.m681.wmt.ready)" = "1" ] || \
           [ "$(getprop service.wcn.driver.ready)" = "yes" ]; then
            setprop debug.m681.wmt.ready 1
            break
        fi
        wait_count=$((wait_count + 1))
        sleep 1
    done
    if [ "$wait_count" -ge "$WMT_WAIT" ]; then
        setprop debug.m681.wifi.kick wmt_not_ready
        setprop wlan.driver.status failed
        log_status "WMT did not become ready"
        exit 1
    fi
fi

setprop wlan.driver.status loading
log_status "settling WMT launcher before Wi-Fi power-on"
sleep "$WMT_SETTLE"

attempt=0
while [ "$attempt" -lt "$MAX_ATTEMPTS" ]; do
    if [ -e "$WMT_NODE" ] && [ -e "$WIFI_NODE" ]; then
        echo 1 > "$WIFI_NODE"
        rc=$?
        setprop debug.m681.wifi.kick "write_${attempt}_${rc}"
        if [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ]; then
            wait_count=0
            while [ "$wait_count" -lt "$WLAN_WAIT" ]; do
                if [ -d "$WLAN_NODE" ]; then
                    setprop debug.m681.wifi.kick wlan0_ready
                    setprop wlan.driver.status ok
                    log_status "wmtWifi power rc=$rc, wlan0 ready"
                    exit 0
                fi
                wait_count=$((wait_count + 1))
                sleep 1
            done
            setprop debug.m681.wifi.kick "no_wlan0_${attempt}"
            log_status "wmtWifi write rc=$rc but wlan0 missing"
            # Reset powered state so the next attempt re-runs wlanProbe.
            echo 0 > "$WIFI_NODE" 2>/dev/null
        else
            log_status "wmtWifi power write rc=$rc attempt=$attempt"
        fi
    else
        setprop debug.m681.wifi.kick "no_node_${attempt}"
        log_status "missing WMT/Wi-Fi node attempt=$attempt"
    fi

    attempt=$((attempt + 1))
    sleep 2
done

setprop debug.m681.wifi.kick failed
setprop wlan.driver.status failed
log_status "failed to power Wi-Fi or create wlan0"
exit 1
