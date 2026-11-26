#!/system/bin/sh
# pd-auth-bypass: stop Xiaomi batterysecret, keep PD authentication forced,
# and select a 9V PDO when the charger falls back to a 5V contract.
#
# Verified on curtana / ResurrectedOS Neuve CN V1.0.24.3.25
# with an Anker 30W USB PD charger. ROM-dependent.
# See README.md for the trade-offs.

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 1; done

# batterysecret is the userspace service that fails the PD data-role-swap
# authentication and requests PDO 1 (5V). Stop it so it cannot fight the
# 9V selection. setprop ctl.stop works from the Magisk domain; the
# /system/bin/stop binary does not.
setprop ctl.stop batterysecret

LOG=/data/local/tmp/pd_auth_bypass.log
log() { echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG"; }

log "start; batterysecret=$(getprop init.svc.batterysecret)"
last_log=0

while true; do
  if [ "$(cat /sys/class/power_supply/usb/present 2>/dev/null)" = "1" ]; then
    # Override any late batterysecret failure.
    echo 1 > /sys/class/power_supply/usb/pd_authentication 2>/dev/null

    pd=$(cat /sys/class/power_supply/usb/pd_active 2>/dev/null)
    v=$(cat /sys/class/power_supply/usb/voltage_now 2>/dev/null)
    temp=$(cat /sys/class/power_supply/battery/temp 2>/dev/null)
    lvl=$(cat /sys/class/power_supply/battery/system_temp_level 2>/dev/null)
    cap=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)

    # Only force fixed-PD 9V when the phone is not thermally limited,
    # the battery is below 45 C and below 90% capacity.
    if [ "$pd" = "1" ] && [ -n "$v" ] && [ "$v" -lt 7000000 ] \
       && [ "$lvl" = "0" ] && [ -n "$temp" ] && [ "$temp" -lt 450 ] \
       && [ -n "$cap" ] && [ "$cap" -lt 90 ]; then
      for n in 1 2 3 4 5 6 7; do
        p=$(cat "/sys/class/usbpd/usbpd0/pdo$n" 2>/dev/null)
        [ -z "$p" ] && continue
        [ "$p" = "00000000" ] && continue
        d=$((0x$p))
        mv=$(( (d >> 10) * 50 ))
        if [ "$mv" = "9000" ]; then
          echo "$n" > /sys/class/usbpd/usbpd0/select_pdo 2>/dev/null
          now=$(date +%s)
          if [ $((now - last_log)) -ge 60 ]; then
            log "select_pdo=$n v_before=$v cap=$cap temp=$temp"
            last_log=$now
          fi
          break
        fi
      done
    fi
  fi

  # Some ROMs start batterysecret just after boot_completed, and may
  # restart it on charger events. Keep it stopped with a 2 s check.
  if [ "$(getprop init.svc.batterysecret)" != "stopped" ]; then
    setprop ctl.stop batterysecret
    log "stopped batterysecret again"
  fi

  sleep 2
done
