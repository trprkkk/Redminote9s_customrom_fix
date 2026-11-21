#!/system/bin/sh
# WFD seccomp loop fix (experimental)
#
# Symptom:
#   wfdvndservice / wfdhdcphalservice die immediately with
#   "libminijail: blocked syscall: gettimeofday" and init restarts them
#   about every 5 seconds.
#
# This script copies the ROM's seccomp policy files, appends
# "gettimeofday: 1" if it is missing, and bind-mounts the patched copies.
#
# NOTE: This module is experimental. Seccomp policy paths and formats vary
# between ROMs. If your ROM stores policies elsewhere or uses a binary policy,
# this script will do nothing (or may need adjustment).

MODDIR=${0%/*}
LOG="$MODDIR/post-fs-data.log"
: > "$LOG"

patched=0

for dir in /vendor/etc/seccomp_policy /system/etc/seccomp_policy; do
    [ -d "$dir" ] || continue

    for src in "$dir"/*wfd*; do
        [ -f "$src" ] || continue

        name=$(basename "$src")
        dst="$MODDIR/$name"
        cp "$src" "$dst" 2>>"$LOG" || continue

        if grep -q '^gettimeofday:' "$dst"; then
            echo "gettimeofday already present in $src" >> "$LOG"
        else
            echo 'gettimeofday: 1' >> "$dst"
            echo "added gettimeofday to $src" >> "$LOG"
        fi

        # Preserve the original SELinux label when possible.
        ctx=$(stat -c %C "$src" 2>/dev/null)
        [ -n "$ctx" ] || ctx=$(ls -Z "$src" 2>/dev/null | awk '{print $1}')
        if [ -n "$ctx" ]; then
            chcon "$ctx" "$dst" 2>>"$LOG"
        else
            chcon u:object_r:vendor_seccomp_policy_file:s0 "$dst" 2>>"$LOG"
        fi

        mount -o bind "$dst" "$src" 2>>"$LOG" && patched=1
    done
done

if [ "$patched" = "1" ]; then
    # Restart the services only if they are already running.
    [ "$(getprop init.svc.wfdvndservice)" = "running" ] && setprop ctl.restart wfdvndservice
    [ "$(getprop init.svc.wfdhdcphalservice)" = "running" ] && setprop ctl.restart wfdhdcphalservice
fi
