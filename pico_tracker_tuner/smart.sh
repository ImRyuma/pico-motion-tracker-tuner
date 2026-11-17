#!/system/bin/sh
# Pico Motion Tracker smart mode v0.3.
#
# Finding (capture of 2026-11-17): during a SteamVR session, as soon as the
# trackers move, Pico OS already puts them at full frequency (tracking_mode
# condition). Holding brings nothing while moving: it only prevents sleep
# when the trackers stay still (lying down).
#
# Strategy:
#   - moving: hands off, stock behavior (= v0.1);
#   - still for STILL_HOLD s during a session: hold full frequency,
#     released as soon as they move again;
#   - outside a session: stock behavior.
# Light polling: a single dumpsys pvrtracking, spaced out while moving.
MODDIR=${0%/*}
CONF="$MODDIR/smart.conf"
LOG="$MODDIR/tuner.log"
PIDF="$MODDIR/.smart.pid"
STATE="$MODDIR/.smart.state"
BIN=/system/bin/pvrtracking_swift_test

log() { echo "$(date '+%F %T') [smart] $*" >> "$LOG"; }

if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  exit 0
fi
echo $$ > "$PIDF"

HPID=""
hold_alive() { [ -n "$HPID" ] && kill -0 "$HPID" 2>/dev/null; }
hold_stop() {
  if hold_alive; then kill "$HPID" 2>/dev/null; wait "$HPID" 2>/dev/null; fi
  HPID=""
}
hold_start() {
  hold_stop
  "$BIN" setKeepTrackerFullFrequencyFlag 1 "$HOLD_MS" >/dev/null 2>&1 &
  HPID=$!
}
cleanup() { hold_stop; rm -f "$PIDF" "$STATE"; log "stopped"; exit 0; }
trap cleanup TERM INT HUP

num() { echo "$D" | sed -n "s/.*$1 \([0-9][0-9]*\).*/\1/p" | head -n 1; }

last_session=0
last_pkg_check=0
last_want=-1
last_reason=""
log "starting v0.3 (pid $$)"

while true; do
  MODE=auto; STILL_HOLD=20; SESSION_LINGER=300
  POLL_MOVE=15; POLL_STILL=5; POLL_HOLD=10; HOLD_MS=3600000
  STREAM_PKGS="picostreamassistant bstreamassistant"
  [ -f "$CONF" ] && . "$CONF"

  D=$(dumpsys pvrtracking 2>/dev/null)
  now=$(date +%s)
  online=$(num 'TrackerConnectCount:'); : "${online:=0}"
  keep=$(num 'keepTrackerFullFreq');    : "${keep:=0}"
  charging=$(num 'hasTrackerCharging'); : "${charging:=0}"
  body=$(num 'bodyTrackingMode');       : "${body:=0}"
  motion=$(num 'currentTrackerMotionState'); : "${motion:=0}"
  freq=$(num 'currentFreq');            : "${freq:=-1}"
  cond=$(echo "$D" | grep -m 1 'ConditionValue')
  still=$(echo "$D" | sed -n 's/.*trackerEnterStillTime.* diff \(-\{0,1\}[0-9][0-9]*\)s.*/\1/p' | head -n 1)
  : "${still:=-1}"
  # Seconds of stillness: 0 if moving, large if already asleep
  case "$motion" in
    2) idle=0 ;;
    1) [ "$still" -ge 0 ] && idle=$still || idle=0 ;;
    *) idle=99999 ;;
  esac

  # Session: an app is consuming tracking (tracking_mode condition of the
  # Pico daemon, or body tracking). Infrequent fallback on the foreground app.
  case "$cond" in *tracking_mode*) last_session=$now ;; esac
  [ "$body" = "1" ] && last_session=$now
  if [ $((now - last_session)) -ge "$SESSION_LINGER" ] && [ $((now - last_pkg_check)) -ge 60 ]; then
    last_pkg_check=$now
    fg=$(dumpsys activity activities 2>/dev/null | grep -m 1 mResumedActivity)
    for p in $STREAM_PKGS; do
      case "$fg" in *"$p"*) last_session=$now ;; esac
    done
  fi
  session=0
  [ $((now - last_session)) -lt "$SESSION_LINGER" ] && session=1

  want=0; reason="no session"
  if [ "$MODE" = "off" ]; then
    reason="mode off"
  elif [ "$online" -eq 0 ]; then
    reason="no tracker connected"
  elif [ "$charging" = "1" ]; then
    reason="tracker charging"
  elif [ "$MODE" = "always" ]; then
    want=1; reason="mode always"
  elif [ "$session" = "1" ] && [ "$idle" -ge "$STILL_HOLD" ]; then
    want=1; reason="session, still ${idle}s"
  elif [ "$session" = "1" ]; then
    reason="session, moving (stock)"
  fi

  if [ "$want" = "1" ]; then
    if ! hold_alive || [ "$keep" != "1" ]; then hold_start; fi
    poll=$POLL_HOLD
  else
    hold_stop
    if [ "$idle" -eq 0 ]; then poll=$POLL_MOVE; else poll=$POLL_STILL; fi
  fi

  # Log only decision changes (not the stillness counter going up)
  rkey=${reason%% still*}
  if [ "$want" != "$last_want" ] || [ "$rkey" != "$last_reason" ]; then
    log "hold=$want ($reason) trackers=$online motion=$motion freq=$freq session=$session"
    last_want=$want; last_reason=$rkey
  fi
  echo "mode=$MODE hold=$want reason=\"$reason\" trackers=$online motion=$motion still=${idle}s freq=$freq session=$session updated=$(date '+%T')" > "$STATE"

  sleep "$poll"
done
