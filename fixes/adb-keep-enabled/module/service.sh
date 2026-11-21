#!/system/bin/sh
# ADB keep-enabled
#
# Some custom ROMs reset the Developer Options "USB debugging" toggle after
# boot. Re-apply it once the system has finished booting.

MODDIR=${0%/*}
LOG="$MODDIR/service.log"
: > "$LOG"

i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 120 ]; do
    sleep 2
    i=$((i + 1))
done

settings put global adb_enabled 1 >>"$LOG" 2>&1

# Optional: Wi-Fi ADB (uncomment to enable; port 5555)
# setprop persist.adb.tcp.port 5555
# setprop service.adb.tcp.port 5555
# stop adbd
# start adbd
