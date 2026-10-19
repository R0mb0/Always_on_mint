# shellcheck shell=bash
# aom run — runs a script (a bot) and tells you if it fails or does not start.
# No sudo needed: put it in front of the command in the crontab or in the bot's service.
#
#   aom run --name report --ping https://hc-ping.com/xxxx --minutes 30 -- python3 /home/me/bot/report.py
#
#   --name NAME     how it appears in alerts and logs (default: the command's name)
#   --ping URL      its own check on healthchecks.io: if the script does NOT START on time
#                   (PC off, broken cron...) or fails, healthchecks.io emails you
#   --minutes N     if it has not finished after N minutes it is stopped and counted as failed
#   --              everything after this is the command to run
#
# If it fails (exit code other than 0) you also get a Telegram message and a desktop
# notification with its last lines. Each bot's log is ~/.local/state/always-on-mint/NAME.log
# (kept short automatically). The command's exit code is returned unchanged.

# shellcheck source=../aom-common.sh
. "$AOM_LIB/aom-common.sh"
name="" ping="" minutes=""
while [ $# -gt 0 ]; do
  case "$1" in
    --name) name="$2"; shift 2 ;;
    --ping) ping="$2"; shift 2 ;;
    --minutes) minutes="$2"; shift 2 ;;
    --) shift; break ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) break ;;
  esac
done
if [ $# -eq 0 ]; then
  L "usage: aom run [--name NAME] [--ping URL] [--minutes N] -- command ..." "uso: aom run [--name NOME] [--ping URL] [--minutes N] -- comando ..." >&2
  echo >&2
  exit 2
fi
[ -n "$name" ] || name=$(basename "$1")

dir="${XDG_STATE_HOME:-$HOME/.local/state}/always-on-mint"
mkdir -p "$dir"
log="$dir/$name.log"
out=$(mktemp)
trap 'rm -f "$out"' EXIT

[ -n "$ping" ] && aom_ping start "" "$ping"     # the bot's own heartbeat, not the PC's
start=$(date +%s)
echo "===== $(date '+%F %T') start: $*" >> "$log"
# the output is shown on screen too (when you run it by hand) and goes into the log
if [ -n "$minutes" ]; then
  timeout --kill-after=30 "$((minutes * 60))" "$@" 2>&1 | tee "$out"
else
  "$@" 2>&1 | tee "$out"
fi
rc=${PIPESTATUS[0]}
cat "$out" >> "$log"
took=$(( $(date +%s) - start ))
echo "===== $(date '+%F %T') end: code $rc, ${took}s" >> "$log"

# the log never grows forever: keeps the last 5000 lines
if [ "$(wc -l < "$log")" -gt 6000 ]; then
  tail -n 5000 "$log" > "$log.tmp" && mv "$log.tmp" "$log"
fi

if [ "$rc" -eq 0 ]; then
  [ -n "$ping" ] && aom_ping "" "$(tail -n 20 "$out")" "$ping"
else
  if [ "$rc" -eq 124 ]; then why=$(Lf 'did not finish within %s minutes and was stopped' 'non ha finito entro %s minuti ed è stato fermato' "$minutes")
  else why=$(Lf 'ended with code %s' 'è finito con il codice %s' "$rc"); fi
  [ -n "$ping" ] && aom_ping "$rc" "$(tail -n 40 "$out")" "$ping"
  aom_alert critical "$(Lf '%s failed' '%s non è andato a buon fine' "$name")" \
    "$(Lf '%s after %ss. Last lines:' '%s dopo %ss. Ultime righe:' "$why" "$took")"$'\n'"$(tail -n 15 "$out")"$'\n'"$(Lf 'Full log: %s' 'Log completo: %s' "$log")"
fi
exit "$rc"
