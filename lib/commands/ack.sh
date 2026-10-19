# shellcheck shell=bash
# aom ack — "I've seen it": stops the alarm that rings until someone intervenes.
#   aom ack          stops your alarms (with sudo: every alarm on the PC)
# Clicking "Got it" on the alarm's notification does the same.

# shellcheck source=../aom-common.sh
. "$AOM_LIB/aom-common.sh"
ringing=0
dirs=("$(aom_ring_dir)")
[ "$(id -u)" -eq 0 ] && for d in /run/user/*/always-on-mint; do [ -d "$d" ] && dirs+=("$d"); done
for d in "${dirs[@]}"; do aom_ring_running "$d" && ringing=1; done
# a normal user can also stop the alarm started by the system (it listens for this file)
[ "$(id -u)" -ne 0 ] && [ -e "${AOM_RUN:-/run/always-on-mint}/ringing" ] && ringing=1
aom_ring_stop all
if [ "$ringing" -eq 1 ]; then
  L "🔕 Alarm stopped. The problem is still there until you fix it: sudo aom check" \
    "🔕 Allarme fermato. Il problema resta finché non lo sistemi: sudo aom check"
else
  L "No alarm is ringing." "Nessun allarme sta suonando."
fi
echo
