#!/system/bin/sh
# forge: bring telephony up after boot on m681.
#
# Workaround for two defects that are still open; both are documented in
# docs/M681_DAILY_DRIVER_STATUS.md sections 11.240 and 11.241. Delete the
# matching block here when its defect is fixed, do not leave it to rot.
#
#  1. rild deadlocks during its first start on AT channel contention
#     ("E/AT: Occupied Thread: AT+CPIN? send on RIL_CMD_READER_3") and then
#     sits idle for minutes. One restart clears it - but only if the modem is
#     already up. v1 of this script restarted it 20 s after boot_completed,
#     which is BEFORE gsm0710muxd has opened the AT channels, and the fresh
#     rild parked exactly like the deadlocked one: two boots logged
#     "sim.state= after 40 polls". So wait for the mux to exist first, and
#     wait on states rather than on guessed delays.
#  2. DcTracker builds no APN list (EF_ICCID unreadable -> no ICCID -> no
#     active subscription) and feeds the modem AOSP's "this_is_an_invalid_apn"
#     placeholder, which the network refuses, so the LTE attach never
#     completes. Writing the real APN straight to the modem lets it through.

LOG=/data/local/tmp/forge-ril-kick.log
exec >>"$LOG" 2>&1
echo "=== $(date) forge-ril-kick start (v2)"

# never outlive the boot it was started for
( sleep 900; echo "=== self-kill at 900s"; kill $$ 2>/dev/null ) &

wait_for() {                 # wait_for <label> <max-polls> <interval> <test-cmd...>
    label=$1; max=$2; iv=$3; shift 3
    i=0
    while [ $i -lt "$max" ]; do
        if "$@" >/dev/null 2>&1; then echo "$label: ready after ${i} polls"; return 0; fi
        sleep "$iv"; i=$((i+1))
    done
    echo "$label: TIMED OUT after ${i} polls"; return 1
}

prop_is() { [ "$(getprop "$1")" = "$2" ]; }

wait_for boot_completed 120 5 prop_is sys.boot_completed 1

# defect 1: the AT channels must exist before rild is restarted, otherwise the
# restart reproduces the very race it is meant to clear.
wait_for at_channels 60 5 test -e /dev/radio/pttycmd1
sleep 20
# defect 3 stopgap: let the radio group create /dev/socket/rild-mal.
# rild is already uid 1001 by the time any of its libraries load - measured,
# "MAL-EARLY: constructor running as uid=1001" - so libril cannot bind in a
# root-only directory, and init does not create this service's socket even
# though the line is byte-clean in /vendor/etc/init/rild.rc and init makes
# mal-mfi for mal-daemon from the same directory. Why init skips it is NOT
# established; this widens one tmpfs directory by one group instead of
# guessing. Remove it the moment the init side is understood.
chown root:radio /dev/socket 2>/dev/null
chmod 0775 /dev/socket 2>/dev/null
echo "dev/socket now: $(ls -ld /dev/socket)"

echo "restarting ril-daemon-mtk (defect 1); muxd=$(getprop init.svc.gsm0710muxd)"
setprop ctl.restart ril-daemon-mtk

wait_for sim_loaded 60 5 prop_is gsm.sim.state LOADED
echo "sim.state=$(getprop gsm.sim.state) radio=$(getprop init.svc.ril-daemon-mtk)"

APN=$(getprop persist.m681.ril.attach_apn)
[ -z "$APN" ] && APN=internet.mts.ru
if [ -e /dev/radio/atci1 ]; then
    echo "writing attach apn '$APN' to the modem (defect 2)"
    printf 'AT+ES3G=1,7\r'                   > /dev/radio/atci1
    sleep 3
    printf 'AT+CGDCONT=0,"IP","%s"\r' "$APN" > /dev/radio/atci1
    sleep 3
    printf 'AT+COPS=0\r'                     > /dev/radio/atci1
else
    echo "no /dev/radio/atci1 - skipped"
fi

wait_for registered 40 5 sh -c '[ -n "$(getprop gsm.operator.numeric)" ] && [ "$(getprop gsm.operator.numeric)" != "000000" ]'
echo "result: op=$(getprop gsm.operator.alpha) num=$(getprop gsm.operator.numeric) net=$(getprop gsm.network.type)"
echo "=== done"
