#!/system/bin/sh
# IMS / SMS restore
#
# Some crash workarounds disable org.codeaurora.ims and uninstall
# com.qti.phone for user 0. On KDDI (povo / au), SMS is delivered over IMS,
# so disabling the IMS stack can make incoming SMS stop working.
#
# This script restores both packages after boot. It does not patch the
# boot-order crash itself; the persistent IMS app may still crash once and
# then recover.

MODDIR=${0%/*}
LOG="$MODDIR/service.log"
: > "$LOG"

# pm needs system_server and the subscription database.
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 120 ]; do
    sleep 2
    i=$((i + 1))
done
sleep 3

# Harmless if the package is already enabled.
pm enable org.codeaurora.ims >>"$LOG" 2>&1

# install-existing is harmless if the package is already installed for user 0.
pm install-existing com.qti.phone >>"$LOG" 2>&1

# Optional: hide crash dialogs. This hides dialogs for all apps, not only IMS.
# settings put global hide_error_dialogs 1
