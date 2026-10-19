# shellcheck shell=bash
# The alarm that rings until someone intervenes (internal: started by aom_ring_start).
#   ring.sh <state dir>
#
# Every ALERT_RING_EVERY seconds: the alarm sound (and, every 5 rounds, the voice) for each
# user logged in to a graphical session. During the quiet hours it stays silent and waits.
# One notification per user, with a "Got it" button; if the notification is closed without
# the button, it comes back at the next round.
# It stops when: the button is clicked, "aom ack" is run, the health check finds that the
# problem is gone, or ALERT_RING_MAX_MINUTES have passed (0 = never give up).

# shellcheck source=../aom-common.sh
. "$AOM_LIB/aom-common.sh"
dir="$1"
[ -n "$dir" ] && [ -e "$dir/ringing" ] || exit 0
echo $$ > "$dir/ringing.pid"
start=$(cat "$dir/ringing" 2>/dev/null || date +%s)
round=0
declare -A shown=()   # user → pid of the notify-send waiting for the button

finish() {
  local p
  for p in "${shown[@]}"; do kill "$p" 2>/dev/null; done
  rm -f "$dir/ringing" "$dir/ringing.pid" "$dir/ringing.msg" "$dir/ack" "$dir"/action-*
  aom_log alerts "alarm stopped: $1"
  exit 0
}
trap 'finish signal' TERM INT

acknowledged() {
  local f
  [ -e "$dir/ack" ] && return 0
  grep -qs '^ack' "$dir"/action-* && return 0
  # an alarm started by root also listens to "aom ack" run by a normal user
  if [ "$(id -u)" -eq 0 ]; then
    for f in /run/user/*/always-on-mint/ack; do
      [ -e "$f" ] && [ "$(stat -c %Y "$f")" -ge "$start" ] && return 0
    done
  fi
  return 1
}

# does this notify-send have buttons (--action)? (libnotify 0.7.10 and later)
has_actions=0
notify-send --help 2>&1 | grep -q -- '--action' && has_actions=1
stop_hint=$(L 'To stop the alarm: click "Got it", or run  aom ack' 'Per fermare l'"'"'allarme: clicca "Ho visto", oppure lancia  aom ack')

aom_log alerts "alarm started"
while [ -e "$dir/ringing" ]; do
  acknowledged && finish "acknowledged"
  if [ "${ALERT_RING_MAX_MINUTES:-0}" -gt 0 ] && [ $(( $(date +%s) - start )) -ge $(( ALERT_RING_MAX_MINUTES * 60 )) ]; then
    finish "gave up after $ALERT_RING_MAX_MINUTES minutes"
  fi
  title=$(sed -n 1p "$dir/ringing.msg" 2>/dev/null)
  body=$(sed -n '2,$p' "$dir/ringing.msg" 2>/dev/null)
  quiet=0
  [ "${AOM_FORCE_SOUND:-0}" = 1 ] || { aom_quiet_now && quiet=1; }

  while read -r user uid display; do
    [ -n "$user" ] || continue
    # the notification (again, if it was closed without pressing the button)
    pid="${shown[$user]:-}"
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
      if command -v notify-send >/dev/null; then
        if [ "$has_actions" -eq 1 ]; then
          aom_as_user "$user" "$uid" "$display" notify-send -u critical -a "Always on Mint" -i dialog-warning \
            --action="ack=$(L 'Got it, stop the alarm' 'Ho visto, ferma l'"'"'allarme')" --wait \
            "$title" "$body"$'\n\n'"$stop_hint" > "$dir/action-$user" 2>/dev/null &
          shown[$user]=$!
        elif [ -z "$pid" ]; then
          aom_as_user "$user" "$uid" "$display" notify-send -u critical -a "Always on Mint" -i dialog-warning \
            "$title" "$body"$'\n\n'"$stop_hint" 2>/dev/null
          shown[$user]=0
        fi
      fi
    fi
    [ "$quiet" -eq 1 ] && continue
    [ "$ALERT_SOUND" = yes ] && aom_play_sound "$user" "$uid" "$display" critical
    if [ "$ALERT_VOICE" != no ] && [ $(( round % 5 )) -eq 0 ]; then
      aom_say "$user" "$uid" "$display" "$title. $(head -1 <<<"$body")"
    fi
  done < <(aom_sessions)

  round=$((round + 1))
  # wait for the next round, reacting within a couple of seconds to the button or "aom ack"
  waited=0
  while [ "$waited" -lt "${ALERT_RING_EVERY:-60}" ]; do
    [ -e "$dir/ringing" ] || break
    acknowledged && finish "acknowledged"
    sleep 2
    waited=$((waited + 2))
  done
done
finish "ringing file removed"
