#!/system/bin/sh
# Force the Wi-Fi country code to JP after boot.
# This is required because the patched jar no longer derives the SoftAP band
# from the SIM/locale country, but hostapd still needs JP regulatory rules
# to allow 5GHz DFS channels (100-140) for AP mode.
(
  while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done
  sleep 5
  cmd wifi force-country-code enabled JP
) &
