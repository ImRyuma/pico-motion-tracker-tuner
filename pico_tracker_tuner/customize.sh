# Run by the Magisk installer (sourced, not executed). $MODPATH = module folder.

BRAND="$(getprop ro.product.brand) $(getprop ro.product.manufacturer) $(getprop ro.product.model)"
ui_print "- Device: $BRAND"
case "$(echo "$BRAND" | tr 'A-Z' 'a-z')" in
  *pico*) ui_print "- Pico headset detected" ;;
  *) ui_print "! Device not recognized as a Pico headset: installing anyway,"
     ui_print "  but this module was only designed for Pico OS." ;;
esac

# Keep the settings of a previous install
OLD=/data/adb/modules/pico_tracker_tuner
if [ -f "$OLD/overrides.conf" ]; then
  cp -f "$OLD/overrides.conf" "$MODPATH/overrides.conf"
  ui_print "- Existing overrides.conf kept"
fi

if [ -f "$OLD/smart.conf" ]; then
  # New smart.conf (new keys), but keep the chosen MODE
  m=$(sed -n 's/^MODE=//p' "$OLD/smart.conf" | head -n 1)
  [ -n "$m" ] && sed -i "s/^MODE=.*/MODE=$m/" "$MODPATH/smart.conf"
  ui_print "- MODE kept: $m"
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/smart.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/tools/investigate.sh" 0 0 0755
set_perm "$MODPATH/tools/investigate_swift.sh" 0 0 0755
set_perm "$MODPATH/tools/optical_check.sh" 0 0 0755

ui_print "- Smart mode starts after reboot (settings: smart.conf)."
ui_print "- The Action button in Magisk cycles auto -> always -> off."
ui_print "- No overrides are active by default (overrides.conf)."
