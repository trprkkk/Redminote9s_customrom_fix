#!/system/bin/sh
# Set the SoftAP band/channel in the saved Wi-Fi configuration.
#
# Run as root on the device, with Wi-Fi and tethering OFF.
# Reboot (or restart the Wi-Fi service) after changing the value.
#
# Usage:
#   su -c 'sh set-softap-channel.sh 100'   # fixed channel 100 (5GHz, DFS, JP)
#   su -c 'sh set-softap-channel.sh auto'  # ACS (2.4GHz + 5GHz)

CH="${1:-100}"
CFG=/data/misc/apexdata/com.android.wifi/WifiConfigStoreSoftAp.xml

if [ ! -f "$CFG" ]; then
  echo "config not found: $CFG" >&2
  exit 1
fi

case "$CH" in
  auto)
    NEW=0
    ;;
  ''|*[!0-9]*)
    echo "usage: $0 <channel|auto>" >&2
    exit 1
    ;;
  *)
    NEW="$CH"
    ;;
esac

# Force 5GHz band (2) and the requested channel.
sed -i 's|<int name="Band" value="[0-9]*" />|<int name="Band" value="2" />|' "$CFG"
sed -i "s|<int name=\"Channel\" value=\"[0-9]*\" />|<int name=\"Channel\" value=\"$NEW\" />|" "$CFG"

grep -A2 BandChannel "$CFG"
echo
echo "reboot required for the change to take effect."
echo "note: channels 100-140 (W56) are DFS and require ~60s CAC on AP start."
