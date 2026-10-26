#!/system/bin/sh
# Sony Cinema setup on Android TV 8. Run from authorized ADB shell. Never requires root.
BASE=/sdcard/Download/sony-cinema
B=$BASE/backup
STOCK=com.google.android.tvlauncher
NEW=com.gathin.tvhome
say() { echo "[sony-cinema] $*"; }
die() { say "ERROR: $*" >&2; exit 1; }
exists() { pm path "$1" >/dev/null 2>&1; }
enabled() { pm list packages -e | grep -Fqx "package:$1"; }
guard() {
  sdk=$(getprop ro.build.version.sdk)
  [ "$sdk" = 26 ] || die "Expected Android 8 / API 26, found $sdk."
}
backup_ready() {
  [ -s "$B/enabled.txt" ] || die "Enabled packages backup missing or empty; run check first."
  [ -f "$B/disabled.txt" ] || die "Disabled packages backup missing (an empty file is OK)."
  [ -s "$B/home.txt" ] && [ -s "$B/model.txt" ] && [ -s "$B/build.txt" ] \
    || die "Original Home/model/build backup incomplete."
  [ -f "$B/changed.txt" ] || die "Disabled-by-Cinema record is missing."
  grep -Fqx 'package:com.google.android.tvlauncher' "$B/enabled.txt" \
    || die "Stock Sony launcher absent from the enabled-package backup."
  grep -q '^package:' "$B/enabled.txt" || die "Enabled-package backup has no package entries."
  case "$(cat "$B/home.txt")" in
    "$STOCK"/*) ;;
    *) die "Original Home is not the expected stock launcher; refusing to proceed." ;;
  esac
}
home() { cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>/dev/null | tail -n 1; }
check() {
  guard
  mkdir -p "$B" || die "Cannot create backup."
  if [ ! -f "$B/enabled.txt" ]; then
    pm list packages -e > "$B/enabled.txt" || die "Cannot save enabled packages."
    pm list packages -d > "$B/disabled.txt"
    home > "$B/home.txt"
    getprop ro.product.model > "$B/model.txt"
    getprop ro.build.display.id > "$B/build.txt"
    for k in window_animation_scale transition_animation_scale animator_duration_scale; do
      settings get global "$k" > "$B/$k.txt"
    done
    : > "$B/changed.txt"
    say "Saved original state to $B"
  else say "Original backup already exists; not overwriting."; fi
  say "Model: $(getprop ro.product.model); firmware: $(getprop ro.build.version.incremental)"
  say "Original Home: $(cat "$B/home.txt"); current Home: $(home)"
  say "Stock Home enabled: $(enabled "$STOCK" && echo yes || echo no)"
}
try_home() {
  guard; backup_ready
  exists "$NEW" || die "Install Cinema APK in atvTools first."
  enabled "$STOCK" || die "Stock Home is not enabled; run restore first."
  out=$(am start -W -a android.intent.action.MAIN -c android.intent.category.HOME -n "$NEW/.MainActivity" 2>&1)
  echo "$out"
  echo "$out" | grep -Fq 'Status: ok' || die "New Home did not start; stock Home untouched."
  cmd package set-home-activity "$NEW/.MainActivity" || die "Android rejected Home selection; stock Home untouched."
  say "Press the PHYSICAL Sony Home button. If Cinema appears, run: sh $BASE/cyt.sh home finish"
}
finish_home() {
  backup_ready
  target=$(home)
  case "$target" in "$NEW"/*) ;; *) die "Cinema is not selected Home ($target).";; esac
  dumpsys activity activities | grep -E '(mResumedActivity|mFocusedActivity|mFocusedApp).*com.gathin.tvhome' >/dev/null \
    || die "Cinema not foreground after Home press; stock Home untouched."
  if enabled "$STOCK"; then
    out=$(pm disable-user --user 0 "$STOCK" 2>&1)
    echo "$out"
    echo "$out" | grep -Eq 'disabled-user|new state: disabled' || {
      pm enable --user 0 "$STOCK" >/dev/null 2>&1
      die "Failed to disable stock Home. Re-enabled it."
    }
  fi
  say "New Home selected. Stock Home is still installed for recovery."
}
# Android 8 on this Sony can return the stock Home even after set-home-activity says Success.
# After verifying the replacement launches, disable stock Home temporarily, select Cinema,
# check the resolved Home, and restore stock Home in the same command if selection fails.
switch_home() {
  guard
  backup_ready
  exists "$NEW" || die "Cinema APK is not installed."
  enabled "$STOCK" || die "Stock Home is not enabled. Use restore instead."
  before=$(home)
  case "$before" in "$STOCK"/*) ;; *) die "Current Home is unexpected ($before); refusing to disable any launcher.";; esac
  out=$(am start -W -a android.intent.action.MAIN -c android.intent.category.HOME -n "$NEW/.MainActivity" 2>&1)
  echo "$out"
  echo "$out" | grep -Fq 'Status: ok' || die "Cinema failed to start; Sony Home unchanged."
  echo "$out" | grep -q '^Error' && die "Cinema reported a launch error; Sony Home unchanged."
  say "Cinema opened. Switching Home with same-command rollback on failure."
  result=$(pm disable-user --user 0 "$STOCK" 2>&1)
  echo "$result"
  case "$result" in
    *disabled-user*|*'new state: disabled'*|*'new state: disabled-user'*) ;;
    *) pm enable --user 0 "$STOCK" >/dev/null 2>&1
       die "Android refused the Sony Home disable; restored original enabled state." ;;
  esac
  if ! cmd package set-home-activity --user 0 "$NEW/.MainActivity"; then
    say "Home preference refused. Restoring Sony Home."
    pm enable --user 0 "$STOCK" >/dev/null 2>&1
    cmd package set-home-activity --user 0 "$STOCK/.MainActivity" >/dev/null 2>&1
    die "Handover failed; Sony Home re-enabled."
  fi
  current=$(home)
  case "$current" in
    "$NEW"/*)
      say "SUCCESS: Cinema is the resolved Home ($current)."
      say "Press the physical Sony Home button. If it does not open Cinema, run: sh $BASE/cyt.sh restore"
      ;;
    *)
      say "Home still resolves to $current; restoring Sony Home."
      pm enable --user 0 "$STOCK" >/dev/null 2>&1
      cmd package set-home-activity --user 0 "$STOCK/.MainActivity" >/dev/null 2>&1
      die "Cinema handover failed. Stock Sony Home re-enabled; no reboot required."
      ;;
  esac
}
apply_theme() {
  backup_ready
  exists "$NEW" || die "APK is not installed."
  [ -f "$BASE/config.json" ] && [ -f "$BASE/wallpaper.jpg" ] || die "Upload the kit theme files first."
  D=/sdcard/Android/data/$NEW/files
  mkdir -p "$D" || die "Cannot create the app theme directory."
  cp "$BASE/config.json" "$D/config.json" || die "Cannot copy config (stop, do not force)."
  cp "$BASE/wallpaper.jpg" "$D/wallpaper.jpg" || die "Cannot copy wallpaper (stop, do not force)."
  am force-stop "$NEW"
  am start -a android.intent.action.MAIN -c android.intent.category.HOME >/dev/null 2>&1
  say "Cinema theme applied."
}
debloat() {
  backup_ready; guard
  [ "$1" = "--confirmed-x850d" ] || die "Verify XBR-55X850D on the retail label, then use debloat --confirmed-x850d."
  build="$(getprop ro.build.version.incremental) $(getprop ro.build.display.id)"
  case "$build" in *6.827*) ;; *) die "Firmware is not confirmed Sony 6.827; refuse model-specific debloat.";; esac
  # Documented OPTIONAL Sony packages only. Never target TVX, HDMI/CEC, streaming, Android core or stock Home here.
  for pkg in tv.samba.ssm com.sony.dtv.sonyselect com.sony.dtv.discovery com.sony.dtv.bivlinfo com.sony.dtv.tvlaunchercustomizer com.google.android.tvrecommendations android.autoinstalls.config.sony.bravia com.google.android.tv.bugreportsender com.google.android.feedback com.sony.dtv.smarthelp com.sony.dtv.imanual com.google.android.play.games com.crackle.androidtv; do
    exists "$pkg" || continue
    enabled "$pkg" || continue
    grep -Fqx "package:$pkg" "$B/enabled.txt" || continue
    grep -Fxq "$pkg" "$B/changed.txt" || echo "$pkg" >> "$B/changed.txt"
    say "$pkg: $(pm disable-user --user 0 "$pkg" 2>&1)"
  done
  say "Optional batch completed. Reversible with restore."
}
restore() {
  backup_ready
  pm enable --user 0 "$STOCK" || die "Cannot enable Sony Home; Cinema remains untouched."
  old=$(cat "$B/home.txt")
  case "$old" in "$STOCK"/*) cmd package set-home-activity "$old" >/dev/null 2>&1 || say "Choose Sony Home manually.";; *) say "Original Home was $old; choose Sony Home if prompted.";; esac
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    grep -Fqx "package:$pkg" "$B/enabled.txt" || continue
    pm enable --user 0 "$pkg" >/dev/null 2>&1 || say "Could not re-enable $pkg"
  done < "$B/changed.txt"
  for k in window_animation_scale transition_animation_scale animator_duration_scale; do
    [ -f "$B/$k.txt" ] || continue
    v=$(cat "$B/$k.txt")
    case "$v" in ''|null) ;; *) settings put global "$k" "$v";; esac
  done
  say "Stock Home and optional apps restored; Cinema remains installed but was not deleted."
}
case "$1" in
  check) check ;;
  home) case "$2" in try) try_home;; finish) finish_home;; switch) switch_home;; *) die "Usage: home try|finish|switch";; esac ;;
  theme) apply_theme ;;
  debloat) debloat "$2" ;;
  restore) restore ;;
  status) say "Current Home: $(home)"; say "Cinema APK: $(exists "$NEW" && echo installed || echo missing)"; say "Stock Home: $(enabled "$STOCK" && echo enabled || echo disabled)";;
  *) echo "Usage: sh cyt.sh check | home try | home switch | theme | debloat --confirmed-x850d | restore | status"; exit 2 ;;
esac