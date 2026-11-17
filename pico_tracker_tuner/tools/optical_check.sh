#!/system/bin/sh
# Measures, for N seconds (default 60), how often each tracker is seen by the
# headset's infrared cameras. Read-only (logs).
# Usage: su -c sh optical_check.sh [seconds]
# Useful to test a hip tracker placement: wear the trackers, play normally /
# look at your feet, then compare. Run during a session: Pico only assigns
# roles (hip, ankles) while a session is active.
DUR=${1:-60}
TMP=/data/local/tmp/optical_check.$$
echo "Capturing ${DUR}s..."
timeout "$DUR" logcat -T 1 -v brief -s SENSOR:I SWIFT2.0:I > "$TMP" 2>/dev/null

awk '
  /Swifter_StatusInfo/ {
    sn=$0; sub(/.*Swifter_StatusInfo /,"",sn); sub(/,.*/,"",sn)
    r=$0; sub(/.*Role:/,"",r); sub(/,.*/,"",r); role[sn]=r
    t=$0; sub(/.*m_bTrackInit:/,"",t); sub(/,.*/,"",t)
    n[sn]++; if (t=="1") ok[sn]++
  }
  /CQL_blob_/ {
    sn=$0; sub(/.*CQL_blob_/,"",sn); sub(/,.*/,"",sn); blob[sn]++
  }
  END {
    nm["0"]="pelvis/hip"; nm["7"]="left ankle"; nm["8"]="right ankle"
    printf "%-18s %-14s %14s %12s\n", "tracker", "role", "IR_detections", "optical_lock"
    for (s in n) {
      r=role[s]; label=(r in nm)?nm[r]:("role " r)
      printf "%-18s %-14s %14d %11d%%\n", s, label, blob[s]+0, (ok[s]+0)*100/n[s]
    }
  }' "$TMP"
rm -f "$TMP"
