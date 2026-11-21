#!/system/bin/sh
# Thermal CP panic fix (runtime patcher)
#
# Removes the [BATTERY_CHARGING_STL] section from thermal-engine configs so
# thermal-engine never writes a non-zero battery cooling-device level.
#
# This works around a NULL dereference in smblib_set_prop_system_temp_level()
# on Japan-market curtana devices when the SMB1398 charge pump is active.
#
# The patched files are generated from the ROM's own config files at boot and
# bind-mounted over the originals. No vendor files are shipped in this module.

MODDIR=${0%/*}
LOG="$MODDIR/post-fs-data.log"
: > "$LOG"

patch_conf() {
    src="$1"
    [ -f "$src" ] || return 0

    name=$(basename "$src")
    dst="$MODDIR/$name"

    # Drop the whole [BATTERY_CHARGING_STL] section, up to the next [section].
    awk '
        /^\[/ { in_batt = ($0 ~ /^\[BATTERY_CHARGING_STL\]/) }
        in_batt { next }
        { print }
    ' "$src" > "$dst" 2>>"$LOG" || return 0

    if cmp -s "$src" "$dst"; then
        echo "no BATTERY_CHARGING_STL in $src" >> "$LOG"
        return 0
    fi

    chcon u:object_r:vendor_configs_file:s0 "$dst" 2>>"$LOG"
    mount -o bind "$dst" "$src" 2>>"$LOG"
    echo "patched $src -> $dst" >> "$LOG"
}

patch_conf /vendor/etc/thermal-engine-normal.conf
patch_conf /vendor/etc/thermal-engine-camera.conf

# If thermal-engine was already started, restart it so it reloads the config.
if [ "$(getprop init.svc.thermal-engine)" = "running" ]; then
    setprop ctl.restart thermal-engine
fi
