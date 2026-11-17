#!/system/bin/sh
# late_start service: applies overrides.conf once the system has booted,
# then starts the smart mode daemon.
MODDIR=${0%/*}
CONF="$MODDIR/overrides.conf"
LOG="$MODDIR/tuner.log"

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

# Keep the log small
[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 200000 ] && mv -f "$LOG" "$LOG.old"

# Wait for boot to finish (max ~5 min)
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 150 ]; do
  sleep 2
  i=$((i + 1))
done
if [ "$(getprop sys.boot_completed)" != "1" ]; then
  log "boot not completed after 5 min, giving up"
  exit 0
fi

# Successful boot: reset the bootloop counter
echo 0 > "$MODDIR/.boot_count"
log "boot OK - $(getprop ro.product.model) / $(getprop ro.build.display.id)"

# Smart mode (background daemon, driven by smart.conf)
rm -f "$MODDIR/.smart.pid"
nohup sh "$MODDIR/smart.sh" >/dev/null 2>&1 &

RESTARTS=""
[ -f "$CONF" ] && while IFS= read -r line || [ -n "$line" ]; do
  line=$(echo "$line" | tr -d '\r')
  case "$line" in
    ''|\#*) continue ;;
    prop:*=*)
      kv=${line#prop:}
      k=${kv%%=*}
      v=${kv#*=}
      old=$(getprop "$k")
      if resetprop -n "$k" "$v"; then
        log "prop $k: '$old' -> '$v'"
      else
        log "FAILED prop $k"
      fi
      ;;
    setting:*:*=*)
      # setting:<global|secure|system>:<key>=<value>
      rest=${line#setting:}
      ns=${rest%%:*}
      kv=${rest#*:}
      k=${kv%%=*}
      v=${kv#*=}
      old=$(settings get "$ns" "$k" 2>/dev/null)
      settings put "$ns" "$k" "$v" && log "setting $ns/$k: '$old' -> '$v'" || log "FAILED setting $ns/$k"
      ;;
    exec:*)
      # exec:<command> -> run as root, 20 s max, output logged
      c=${line#exec:}
      out=$(timeout 20 sh -c "$c" 2>&1 | tail -n 5)
      log "exec '$c' -> $out"
      ;;
    restart:*)
      RESTARTS="$RESTARTS ${line#restart:}"
      ;;
    *)
      log "ignored line: $line"
      ;;
  esac
done < "$CONF"

# Restart the requested init services so they reload props/config
for s in $RESTARTS; do
  if [ -n "$(getprop "init.svc.$s")" ]; then
    stop "$s"; sleep 1; start "$s"
    log "init service restarted: $s (state: $(getprop "init.svc.$s"))"
  else
    log "unknown init service: $s"
  fi
done

log "done"
