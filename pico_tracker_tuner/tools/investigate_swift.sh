#!/system/bin/sh
# Step 2 (READ-ONLY): close look at the pvrtrackingservice daemon and the
# "Swift" libraries (code name of the Pico Motion Trackers).
# Usage: su -c sh investigate_swift.sh > report.txt
# Note: the output contains tracker serial numbers.

sec() { echo; echo "================ $1 ================"; }

sec "DAEMON INIT DEFINITION"
grep -n -B2 -A14 -iE 'pvrtrackingservice' /vendor/etc/init/*.rc /system/etc/init/*.rc 2>/dev/null | head -n 80

sec "DAEMON BINARY AND LOADED LIBS"
PID=$(pidof pvrtrackingservice)
echo "pid=$PID exe=$(readlink /proc/$PID/exe)"
grep -oE '/[^ ]+\.so' /proc/$PID/maps 2>/dev/null | sort -u | grep -iE 'swift|slam|track|alg|pxr|pvr|pico|body|hand|fusion|imu'

sec "FILES OPENED BY THE DAEMON"
ls -l /proc/$PID/fd 2>/dev/null | sed 's/.*-> //' | grep -vE '^(socket|pipe|anon_inode|/dev/null)' | sort | uniq -c | sort -rn | head -n 60

BINS="$(readlink /proc/$PID/exe) /system/lib64/libAlgSwiftTracking.so /system/lib64/libAlgSwiftBodyPose.so /system/lib64/libAlgSwiftBodyPose1.0.so /system/lib64/libtrackerclient.pxr.so /system/bin/pvrtracking_swift_test /system/bin/tracker_test"

for f in $BINS; do
  [ -f "$f" ] || continue
  sec "$f ($(wc -c < "$f") bytes)"
  echo "--- referenced system properties"
  strings -n 6 "$f" | grep -E '^(persist|debug|sys|pxr|pvr|ro|vendor)\.[A-Za-z0-9_.]+$' | sort -u | head -n 120
  echo "--- referenced file paths"
  strings -n 6 "$f" | grep -E '^/(data|mnt|vendor|system|sdcard|persist|odm)/[A-Za-z0-9_./%-]+$|\.(json|cfg|yaml|yml|ini|conf|xml|txt)$' | sort -u | head -n 80
  echo "--- IR / LED / optical / fusion / weight strings"
  strings -n 5 "$f" | grep -iE 'ir[_ ]?led|led[_ ]|blob|optical|infrared|vision|visual|camera.*(weight|fps|rate)|fusion|weight|imu.*(only|noise|bias|weight)|drift|kalman|ekf|covariance|3dof|6dof|exposure' | sort -u | head -n 150
done

sec "WRITABLE SWIFT DATA"
ls -la /data/misc/pxr/ /data/misc/pxr/swift/ /data/misc/pxr/tracking/ /data/misc/pxr/tracking/swift/ /mnt/vendor/pvr/tracker/ 2>&1
for f in /data/misc/pxr/swift/*_bias.txt /data/misc/pxr/swift/*_magCoeff.txt; do
  echo "--- $f"; head -c 600 "$f"; echo
done
echo "--- /mnt/vendor/pvr/tracker/tracker_info_data.json"
head -c 3000 /mnt/vendor/pvr/tracker/tracker_info_data.json; echo

sec "LATEST MCUTracker LOG (tail)"
L=$(ls -t /data/misc/pxr/tracking/swift/MCUTracker.*.log 2>/dev/null | head -n 1)
echo "$L"; tail -n 60 "$L" 2>/dev/null

sec "com.pvr.swift APP PREFS"
for f in swift.sp.xml com.pvr.swift.v2.playerprefs.xml __local_settings_data.sp.xml; do
  echo "--- $f"; cat "/data/data/com.pvr.swift/shared_prefs/$f" 2>/dev/null; echo
done

sec "CURRENT SWIFT PROPS"
getprop | grep -iE 'swift|trackingservice|tracking\.|picoslam|trackingmode'

sec "DUMPSYS pvrtracking"
timeout 5 dumpsys pvrtracking 2>&1 | head -n 120
