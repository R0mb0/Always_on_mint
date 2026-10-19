# shellcheck shell=bash
# aom reboot — the careful weekly reboot (aom-reboot.timer).
#   sudo aom reboot --dry-run    tells what it would do, without rebooting
#
# Before rebooting:
#   1. runs the full health check. If something could stop the PC from starting again
#      (half-finished update, missing boot files, full or failing disk, read-only disk),
#      it does NOT reboot and alerts you: a running PC with a problem is better than a PC
#      that does not come back.
#   2. waits (up to 60 minutes) for the programs in WAIT_FOR_PROCESSES to finish.
# After the reboot, "aom boot" tells you that everything is up again.

# shellcheck source=../aom-common.sh
. "$AOM_LIB/aom-common.sh"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1
[ "$DRY" -eq 1 ] || aom_need_root aom reboot

"$AOM_BIN" check --quiet
rc=$?
if [ "$rc" -gt 2 ]; then
  aom_log reboots "reboot cancelled: the health check does not run (code $rc)"
  [ "$DRY" -eq 1 ] && { Lf "I would NOT reboot: the health check cannot run (code %s)\n" "NON riavvierei: il controllo di salute non riesce a girare (codice %s)\n" "$rc"; exit 1; }
  aom_alert critical "$(L 'Weekly reboot CANCELLED' 'Riavvio settimanale ANNULLATO')" \
    "$(Lf 'The health check cannot run (code %s). Try: sudo aom check' 'Il controllo di salute non riesce a girare (codice %s). Prova: sudo aom check' "$rc")"
  exit 1
fi
if [ "$rc" -eq 2 ]; then
  why=$(grep '^⛔' "$AOM_STATE/report.txt")
  aom_log reboots "reboot cancelled: ${why//$'\n'/ / }"
  [ "$DRY" -eq 1 ] && { L "I would NOT reboot, because:" "NON riavvierei, perché:"; echo; echo "$why"; exit 1; }
  aom_alert critical "$(L 'Weekly reboot CANCELLED' 'Riavvio settimanale ANNULLATO')" \
    "$why"$'\n'"$(L 'Fix these problems before rebooting (sudo aom check for the report).' 'Sistema questi problemi prima di riavviare (sudo aom check per il rapporto).')"
  exit 1
fi

# wait for work in progress
for _ in $(seq 1 60); do
  busy=""
  for p in $WAIT_FOR_PROCESSES; do
    pgrep -f -- "$p" >/dev/null 2>&1 && busy="$busy $p"
  done
  [ -z "$busy" ] && break
  [ "$DRY" -eq 1 ] && { Lf "I would wait for:%s\n" "Aspetterei che finisca:%s\n" "$busy"; break; }
  aom_log reboots "waiting for:$busy"
  sleep 60
done

if [ "$DRY" -eq 1 ]; then
  if [ "$rc" -eq 0 ]; then L "I would reboot now (health check: all good)" "Riavvierei adesso (controllo: tutto a posto)"
  else L "I would reboot now (health check: only warnings, nothing critical)" "Riavvierei adesso (controllo: solo avvisi, niente di critico)"; fi
  echo
  exit 0
fi
mkdir -p "$AOM_STATE"
date +%s > "$AOM_STATE/planned-reboot"
aom_log reboots "weekly reboot"
sync
systemctl reboot
