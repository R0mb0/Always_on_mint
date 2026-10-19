# shellcheck shell=bash
# shellcheck disable=SC2034  # configuration variables are used by the command scripts
#
# Always on Mint — shared functions. Installed in /usr/local/lib/always-on-mint/aom-common.sh
# Every command (lib/commands/*.sh) sources this file first.

AOM_VERSION="1.0.0"
AOM_CONF="${AOM_CONF:-/etc/always-on-mint.conf}"
AOM_LOG="${AOM_LOG:-/var/log/always-on-mint}"
AOM_STATE="${AOM_STATE:-/var/lib/always-on-mint}"
AOM_BACKUPS="${AOM_BACKUPS:-/var/backups/always-on-mint}"
AOM_BIN="${AOM_BIN:-aom}"

# ---------------------------------------------------------------- defaults
# (overridden by /etc/always-on-mint.conf; see always-on-mint.conf.example for what each one does)
MACHINE_NAME="$(hostname)"
MESSAGES_LANGUAGE="auto"
TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID=""
HEALTHCHECKS_URL=""
DESKTOP_ALERTS="yes"
ALERT_SOUND="yes"
ALERT_VOICE="critical"
QUIET_HOURS="23-08"
ALERT_UNTIL_ACK="no"
ALERT_RING_EVERY=60
ALERT_RING_MAX_MINUTES=0
REBOOT_SCHEDULE="Sun *-*-* 05:10:00"
WAIT_FOR_PROCESSES=""
DISK_WARN=85
DISK_CRITICAL=95
MAX_DAYS_WITHOUT_REBOOT=10
MAX_DAYS_WITHOUT_UPDATE=40
# casper-md5check checks the installation USB stick at every boot and always fails on an installed system
IGNORE_SERVICES="casper-md5check.service"
CLEAN_OLD_KERNELS="yes"
JOURNAL_MAX_SIZE="300M"
BACKUP_PATHS=""
BACKUP_COPY_TO=""
BACKUP_KEEP=4

# shellcheck source=/dev/null
[ -r "$AOM_CONF" ] && . "$AOM_CONF"

# ---------------------------------------------------------------- language
# Messages exist in English and Italian, side by side in the code: L "english" "italiano".
aom_detect_language() {
  local l="$MESSAGES_LANGUAGE" sys=""
  if [ "$l" = auto ] || [ -z "$l" ]; then
    # the language of your session (sudo keeps it); for automatic jobs, the system's
    sys="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
    case "$sys" in ""|C|C.*|POSIX) sys=$(sed -n 's/^ *LANG=["]\{0,1\}\([^"]*\).*/\1/p' /etc/default/locale 2>/dev/null | head -1) ;; esac
    l="${sys:-en}"
  fi
  case "$l" in it*) echo it ;; *) echo en ;; esac
}
AOM_LANG="$(aom_detect_language)"

# L "english" "italiano"  → prints the one for the current language
L() { if [ "$AOM_LANG" = it ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
# Lf "english %s" "italiano %s" args...  → printf with the right format
Lf() {
  local f
  f=$(L "$1" "$2"); shift 2
  # shellcheck disable=SC2059  # the format string is ours, chosen by language
  printf "$f" "$@"
}

# ---------------------------------------------------------------- helpers
aom_log() {
  # aom_log <file without .log> <message...>
  local f="$1"; shift
  mkdir -p "$AOM_LOG" 2>/dev/null
  printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$AOM_LOG/$f.log" 2>/dev/null || true
}

aom_need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    Lf "This needs root: sudo %s\n" "Serve sudo: sudo %s\n" "$*" >&2
    exit 1
  fi
}

# percentage used of a mount point (empty if it does not exist)
aom_disk_use() {
  df -P "$1" 2>/dev/null | awk 'NR==2 { gsub("%","",$5); print $5 }'
}

# ---------------------------------------------------------------- Telegram
aom_telegram() {
  [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ] || return 0
  local text="${1:0:3900}"
  curl -fsS --max-time 20 -o /dev/null \
    --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" \
    --data-urlencode "text=$text" \
    --data-urlencode "disable_web_page_preview=true" \
    "${TELEGRAM_API:-https://api.telegram.org}/bot$TELEGRAM_TOKEN/sendMessage" 2>/dev/null \
    || { aom_log alerts "Telegram not reachable"; return 1; }
}

# ---------------------------------------------------------------- healthchecks.io
# aom_ping [status] [body] [url]   status: "" (all good) | start | fail | an exit code
aom_ping() {
  local status="${1:-}" body="${2:-}" base="${3:-$HEALTHCHECKS_URL}" url
  [ -n "$base" ] || return 0
  url="${base%/}"
  [ -n "$status" ] && url="$url/$status"
  curl -fsS --max-time 15 --retry 2 -o /dev/null --data-raw "${body:0:9000}" "$url" 2>/dev/null || true
}

# ---------------------------------------------------------------- desktop: notification, sound, voice
# Quiet hours "23-08": no sound and no voice in that window (the notification still appears,
# silently). What happened during the night is played once when the quiet hours end.
aom_quiet_now() {
  [ -n "$QUIET_HOURS" ] || return 1
  local from to h
  from=$((10#${QUIET_HOURS%-*})); to=$((10#${QUIET_HOURS#*-})); h=$((10#$(date +%H)))
  if [ "$from" -le "$to" ]; then [ "$h" -ge "$from" ] && [ "$h" -lt "$to" ]
  else [ "$h" -ge "$from" ] || [ "$h" -lt "$to" ]; fi
}

# active graphical sessions: "user uid display" (as a normal user: only your own)
aom_sessions() {
  local sid uid user _ type active display
  loginctl list-sessions --no-legend 2>/dev/null | while read -r sid uid user _; do
    type=$(loginctl show-session "$sid" -p Type --value 2>/dev/null)
    active=$(loginctl show-session "$sid" -p Active --value 2>/dev/null)
    display=$(loginctl show-session "$sid" -p Display --value 2>/dev/null)
    case "$type" in x11|wayland) ;; *) continue ;; esac
    [ "$active" = yes ] || continue
    [ "$(id -u)" -eq 0 ] || [ "$uid" = "$(id -u)" ] || continue
    echo "$user $uid ${display:-:0}"
  done | sort -u
}

# run a command inside a user's desktop session
aom_as_user() {
  local user="$1" uid="$2" display="$3"; shift 3
  local envs=(env "DISPLAY=$display" "XDG_RUNTIME_DIR=/run/user/$uid" "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus")
  if [ "$(id -u)" -eq 0 ]; then runuser -u "$user" -- "${envs[@]}" "$@"
  else "${envs[@]}" "$@"; fi
}

aom_play_sound() { # user uid display level
  local f times=1
  [ "$4" = critical ] && times=3
  for f in /usr/share/sounds/freedesktop/stereo/{dialog-warning,alarm-clock-elapsed,bell}.oga; do
    [ -r "$f" ] && break
  done
  for _ in $(seq 1 "$times"); do
    if [ -r "$f" ] && command -v paplay >/dev/null; then aom_as_user "$1" "$2" "$3" paplay "$f" 2>/dev/null
    elif command -v canberra-gtk-play >/dev/null; then aom_as_user "$1" "$2" "$3" canberra-gtk-play -i dialog-warning 2>/dev/null
    else break; fi
  done
}

aom_say() { # user uid display text
  command -v spd-say >/dev/null || return 0
  local text
  text=$(sed 's/⛔\|⚠️\|⚠\|✅\|ℹ️\|❌\|🖥\|🔄\|🔌\|🧪//g' <<<"$4")   # emoji are not read well
  aom_as_user "$1" "$2" "$3" timeout 60 spd-say -l "$AOM_LANG" -w "$text" 2>/dev/null
}

# aom_desktop <level: critical|warning|info> <title> <body>
aom_desktop() {
  [ "$DESKTOP_ALERTS" = yes ] || return 0
  local level="$1" title="$2" body="$3" quiet=0 urgency=normal user uid display noisy=0
  # ring until someone intervenes? (ALERT_UNTIL_ACK) — the alarm handles notification, sound,
  # voice and quiet hours by itself, also when nobody is logged in yet
  if aom_ring_wanted "$level"; then
    aom_ring_start "$title" "$body" && return 0
  fi
  aom_quiet_now && quiet=1
  [ "${AOM_FORCE_SOUND:-0}" = 1 ] && quiet=0
  [ "$level" = critical ] && urgency=critical
  { [ "$ALERT_SOUND" = yes ] || [ "$ALERT_VOICE" = all ] || { [ "$ALERT_VOICE" = critical ] && [ "$level" = critical ]; }; } && noisy=1
  while read -r user uid display; do
    [ -n "$user" ] || continue
    command -v notify-send >/dev/null && \
      aom_as_user "$user" "$uid" "$display" notify-send -u "$urgency" -a "Always on Mint" -i dialog-warning "$title" "$body" 2>/dev/null
    [ "$quiet" -eq 1 ] && continue
    [ "$ALERT_SOUND" = yes ] && [ "$level" != info ] && aom_play_sound "$user" "$uid" "$display" "$level"
    if [ "$ALERT_VOICE" = all ] || { [ "$ALERT_VOICE" = critical ] && [ "$level" = critical ]; }; then
      aom_say "$user" "$uid" "$display" "$title. $(head -1 <<<"$body")"
    fi
  done < <(aom_sessions)
  # during quiet hours: keep it for the morning
  if [ "$quiet" -eq 1 ] && [ "$noisy" -eq 1 ] && [ "$level" != info ] && [ -w "$AOM_STATE" ]; then
    printf '%s\n%s\n%s\n' "$level" "$title" "$body" > "$AOM_STATE/pending-sound"
  fi
}

# the quiet hours are over: play what was kept from the night (once)
aom_replay_pending() {
  local f="$AOM_STATE/pending-sound" level title body
  [ -r "$f" ] || return 0
  aom_quiet_now && return 0
  [ "$DESKTOP_ALERTS" = yes ] || return 0
  [ -n "$(aom_sessions)" ] || return 0   # nobody to hear it yet: keep it for when someone logs in
  level=$(sed -n 1p "$f"); title=$(sed -n 2p "$f"); body=$(sed -n '3,$p' "$f")
  rm -f "$f"
  aom_desktop "$level" "$(L "During the night" "Durante la notte"): $title" "$body"
}

# ---------------------------------------------------------------- the alarm that rings until you intervene
# ALERT_UNTIL_ACK: no | critical | all. The alarm runs as its own small background job
# (lib/commands/ring.sh): it rings every ALERT_RING_EVERY seconds (silently during the quiet
# hours) until you click "Got it" on the notification, run "aom ack", the problem goes away,
# or ALERT_RING_MAX_MINUTES pass (0 = never give up).

aom_ring_wanted() {
  case "$ALERT_UNTIL_ACK" in
    all) [ "$1" != info ] ;;
    critical) [ "$1" = critical ] ;;
    *) return 1 ;;
  esac
}

# where the alarm keeps its state: /run/always-on-mint for root, your runtime folder otherwise
aom_ring_dir() {
  if [ "$(id -u)" -eq 0 ]; then echo "${AOM_RUN:-/run/always-on-mint}"
  else echo "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/always-on-mint"; fi
}

aom_ring_running() { # dir
  [ -r "$1/ringing.pid" ] && kill -0 "$(cat "$1/ringing.pid" 2>/dev/null)" 2>/dev/null
}

# aom_ring_start <title> <body>  — starts the alarm, or updates its message if it is already ringing
aom_ring_start() {
  local dir envs=()
  dir=$(aom_ring_dir)
  mkdir -p "$dir" 2>/dev/null || return 1
  printf '%s\n%s\n' "$1" "$2" > "$dir/ringing.msg"
  aom_ring_running "$dir" && return 0
  rm -f "$dir/ack" "$dir"/action-*
  date +%s > "$dir/ringing"
  local v
  for v in AOM_LIB AOM_CONF AOM_STATE AOM_LOG AOM_RUN AOM_FORCE_SOUND PATH; do
    [ -n "${!v:-}" ] && envs+=("--setenv=$v=${!v}")
  done
  if [ "$(id -u)" -eq 0 ] && command -v systemd-run >/dev/null && [ -d /run/systemd/system ]; then
    # its own service: the hourly check finishes, the alarm keeps ringing
    systemd-run --quiet --collect --unit "aom-ring-$(date +%s)" "${envs[@]}" bash "$AOM_LIB/commands/ring.sh" "$dir" >/dev/null 2>&1 && return 0
  fi
  setsid nohup bash "$AOM_LIB/commands/ring.sh" "$dir" >/dev/null 2>&1 < /dev/null &
  return 0
}

# aom_ring_stop [all]  — stops your own alarm; with "all" (and root) every alarm on the PC
aom_ring_stop() {
  local d
  d=$(aom_ring_dir); mkdir -p "$d" 2>/dev/null && touch "$d/ack" 2>/dev/null
  if [ "${1:-}" = all ] && [ "$(id -u)" -eq 0 ]; then
    for d in /run/user/*/always-on-mint; do [ -d "$d" ] && touch "$d/ack"; done
  fi
  return 0
}

# ---------------------------------------------------------------- one alert: log + Telegram + desktop
# aom_alert <level: critical|warning|info|ok> <title> <body>
aom_alert() {
  local icon="⚠️"
  [ "$1" = critical ] && icon="⛔"
  [ "$1" = info ] && icon="ℹ️"
  [ "$1" = ok ] && icon="✅"
  aom_log alerts "$1 | $2 | ${3//$'\n'/ / }"
  aom_telegram "🖥 $MACHINE_NAME — $icon $2"$'\n'"$3"
  case "$1" in ok|info) aom_desktop info "$2" "$3" ;; *) aom_desktop "$1" "$2" "$3" ;; esac
  return 0
}
