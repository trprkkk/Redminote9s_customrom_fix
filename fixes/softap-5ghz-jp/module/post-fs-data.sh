#!/system/bin/sh
# Bind-mount the patched miui-wifi-service.jar over the read-only system_ext file.
MODDIR=${0%/*}
SRC="$MODDIR/system_ext/framework/miui-wifi-service.jar"
DST=/system_ext/framework/miui-wifi-service.jar

[ -f "$SRC" ] || exit 0

chcon u:object_r:system_file:s0 "$SRC"
chmod 644 "$SRC"

if ! grep -qs "$DST" /proc/mounts; then
  mount -o bind "$SRC" "$DST"
fi
