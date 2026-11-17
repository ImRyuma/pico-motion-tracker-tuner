#!/system/bin/sh
# Bootloop guard: if 3 consecutive boots never reach sys.boot_completed,
# the module disables itself (takes effect on the next boot).
MODDIR=${0%/*}
CNT="$MODDIR/.boot_count"

n=$(cat "$CNT" 2>/dev/null)
[ -z "$n" ] && n=0
n=$((n + 1))
echo "$n" > "$CNT"

if [ "$n" -ge 3 ]; then
  touch "$MODDIR/disable"
  echo "$(date): $n incomplete boots, module disabled" >> "$MODDIR/tuner.log"
fi
