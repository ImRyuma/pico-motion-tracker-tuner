#!/system/bin/sh
# READ-ONLY investigation of Pico Motion Tracker handling.
# Usage (root): su -c sh investigate.sh [output_folder]
# Ideally: trackers powered on, paired and visible to the headset.

OUT=${1:-/data/local/tmp/pico_tracker_investigation}
REP="$OUT/report.txt"
mkdir -p "$OUT/files"

# Broad keywords (props, packages, processes) and narrow ones (files, libs)
KW='pico|pvr|pxr|swift|tracker|tracking|bodytrack|body_track|motion|slam|6dof|fusion|imu|controller|hmd'
KWN='swift|tracker|bodytrack|body_track|motiontrack|motion_track|fusion|slam|6dof|vio'
# Tuning keys searched for in binaries and configs
KEYS='weight|fusion|optical|infrared|ir_|_ir|led|blob|imu|drift|predict|kalman|ekf|noise|covar|rate|freq|fps|exposure|interval'

[ "$(id -u)" = "0" ] || echo "WARNING: not root, partial results"

sec() { echo; echo "================ $1 ================"; }

{
sec "DEVICE"
for p in ro.product.brand ro.product.manufacturer ro.product.model ro.product.device \
         ro.build.display.id ro.build.version.release ro.build.version.sdk \
         ro.board.platform ro.boot.slot_suffix; do
  echo "$p=$(getprop $p)"
done
echo "magisk=$(magisk -v 2>/dev/null) ($(magisk -V 2>/dev/null))"
echo "selinux=$(getenforce 2>/dev/null)"

sec "SYSTEM PROPERTIES (filtered)"
getprop | grep -iE "$KW"

sec "INIT SERVICES (init.svc.*)"
getprop | grep -E '^\[init\.svc\.' | sort

sec "PACKAGES (pm list packages -f)"
pm list packages -f 2>/dev/null | grep -iE "$KW" | sort

sec "PROCESSES"
ps -A -o PID,PPID,USER,NAME,ARGS 2>/dev/null | grep -iE "$KW" | grep -v grep

sec "BINDER SERVICES (service list)"
service list 2>/dev/null | grep -iE "$KW"

sec "HAL SERVICES (lshal / vndservice)"
lshal 2>/dev/null | grep -iE "$KW" | head -n 60
vndservice list 2>/dev/null | grep -iE "$KW"

sec ".rc FILES MENTIONING TRACKING"
for d in /system/etc/init /vendor/etc/init /odm/etc/init /product/etc/init /system_ext/etc/init; do
  [ -d "$d" ] && grep -ilE "$KWN" "$d"/*.rc 2>/dev/null
done

sec "CANDIDATE CONFIG FILES (read-only partitions)"
find /vendor /odm /system /system_ext /product -type f \
  \( -iname '*.json' -o -iname '*.xml' -o -iname '*.conf' -o -iname '*.cfg' \
     -o -iname '*.ini' -o -iname '*.yaml' -o -iname '*.yml' -o -iname '*.txt' \
     -o -iname '*.bin' -o -iname '*.dat' \) 2>/dev/null \
  | grep -iE "$KWN" | head -n 300

sec "CANDIDATE FILES (writable data)"
find /data/misc /data/vendor /data/system /data/local /mnt/vendor /persist /data/pvr /data/pico \
  -type f 2>/dev/null | grep -iE "$KWN" | head -n 300

sec "CANDIDATE NATIVE LIBRARIES / BINARIES"
LIBS=$(find /vendor /odm /system /system_ext /product -type f \
  \( -name '*.so' -o -path '*/bin/*' \) 2>/dev/null | grep -iE "$KWN" | head -n 80)
echo "$LIBS"

sec "TUNING STRINGS IN THESE BINARIES (potential key names)"
for f in $LIBS; do
  hits=$(strings -n 6 "$f" 2>/dev/null | grep -iE "$KEYS" | grep -iE 'track|swift|body|fusion|imu|ir|led|optical|persist\.|ro\.|\.json|\.xml|\.cfg|\.conf|/data/|/vendor/' | sort -u | head -n 60)
  if [ -n "$hits" ]; then
    echo "--- $f"
    echo "$hits"
  fi
done

sec "PROPERTIES READ BY THESE BINARIES (persist.* / ro.* / vendor.* / debug.*)"
for f in $LIBS; do
  strings -n 8 "$f" 2>/dev/null | grep -E '^(persist|ro|vendor|debug|sys|pvr|pico|pxr)\.[a-zA-Z0-9_.]+$'
done | sort -u | head -n 300

sec "SETTINGS (global/secure/system)"
for ns in global secure system; do
  settings list $ns 2>/dev/null | grep -iE "$KW" | sed "s/^/$ns: /"
done

sec "TRACKER-RELATED PACKAGE DETAILS"
PKGS=$(pm list packages 2>/dev/null | sed 's/^package://' | grep -iE "$KWN|motion")
for p in $PKGS; do
  echo "--- $p"
  pm path "$p" 2>/dev/null
  dumpsys package "$p" 2>/dev/null | grep -E 'versionName|versionCode|sharedUser|codePath|nativeLibrary|flags=' | head -n 12
  ls -la "/data/data/$p/shared_prefs" "/data/data/$p/files" 2>/dev/null | head -n 40
done

sec "RELATED RUNNING ANDROID SERVICES (dumpsys activity services)"
dumpsys activity services 2>/dev/null | grep -iE 'ServiceRecord' | grep -iE "$KW" | head -n 80

sec "DUMPSYS OF RELATED BINDER SERVICES"
for s in $(service list 2>/dev/null | grep -iE "$KWN|pvr|pxr|pico" | sed -E 's/^[0-9]+[[:space:]]+([^:]+):.*/\1/'); do
  echo "--- dumpsys $s"
  timeout 5 dumpsys "$s" 2>/dev/null | head -n 80
done

sec "BLUETOOTH / INPUT DEVICES (tracker link)"
dumpsys bluetooth_manager 2>/dev/null | grep -iE 'name|address|bond|connected|swift|tracker|pico' | head -n 60
grep -iE 'Name=|Handlers=' /proc/bus/input/devices 2>/dev/null
ls /dev | grep -iE 'hidraw|ttyHS|ttyACM|ttyUSB|spidev'

sec "CAMERAS (optical tracking source)"
dumpsys media.camera 2>/dev/null | grep -iE 'Camera ID|Device .* is|Facing|fps|client' | head -n 60

sec "RECENT LOGCAT (tracking)"
logcat -d -t 20000 2>/dev/null | grep -iE "$KWN|motiontracker|motion tracker" | tail -n 400

sec "END"
date
} > "$REP" 2>&1

# Copy the small text config files found (for analysis on a PC)
find /vendor /odm /system /system_ext /product /data/misc /data/vendor /data/pvr /data/pico \
  -type f -size -512k \
  \( -iname '*.json' -o -iname '*.xml' -o -iname '*.conf' -o -iname '*.cfg' -o -iname '*.ini' -o -iname '*.yaml' -o -iname '*.rc' \) \
  2>/dev/null | grep -iE "$KWN" | head -n 100 | while read -r f; do
    dst="$OUT/files$(dirname "$f")"
    mkdir -p "$dst" && cp -f "$f" "$dst/" 2>/dev/null
done

chmod -R a+rX "$OUT" 2>/dev/null
chcon -R u:object_r:shell_data_file:s0 "$OUT" 2>/dev/null

echo "Report: $REP ($(wc -l < "$REP") lines)"
echo "Copied configs: $OUT/files"
echo "Retrieve with: adb pull $OUT"
echo "Note: the report contains device and tracker serial numbers."
