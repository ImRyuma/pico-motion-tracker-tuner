#!/system/bin/sh
# Props set with resetprop -n and overlaid files disappear on reboot.
# Only "setting:" overrides persist: restore them by hand if you used any
# (original values are in tuner.log).
[ -f /data/adb/modules/pico_tracker_tuner/.smart.pid ] && kill "$(cat /data/adb/modules/pico_tracker_tuner/.smart.pid)" 2>/dev/null
rm -rf /data/local/tmp/pico_tracker_investigation
