#!/system/bin/sh
# Magisk app "Action" button: cycles the smart mode
# auto -> always -> off -> auto and shows the current state.
MODDIR=${0%/*}
CONF="$MODDIR/smart.conf"

cur=$(sed -n 's/^MODE=//p' "$CONF" | head -n 1)
case "$cur" in
  auto) new=always ;;
  always) new=off ;;
  *) new=auto ;;
esac
sed -i "s/^MODE=.*/MODE=$new/" "$CONF"
echo "Smart mode: $cur -> $new"

# Restart the daemon if it is no longer running
if ! { [ -f "$MODDIR/.smart.pid" ] && kill -0 "$(cat "$MODDIR/.smart.pid")" 2>/dev/null; }; then
  nohup sh "$MODDIR/smart.sh" >/dev/null 2>&1 &
  echo "Daemon restarted"
fi

sleep 7
echo "State: $(cat "$MODDIR/.smart.state" 2>/dev/null)"
echo
echo "Log:"
tail -n 8 "$MODDIR/tuner.log"
