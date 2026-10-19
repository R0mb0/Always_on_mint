# shellcheck shell=bash
# aom status — what is scheduled, the last report, how alerts are set up (no secrets shown).
#   sudo aom status

# shellcheck source=../aom-common.sh
. "$AOM_LIB/aom-common.sh"
yesno() { if [ -n "$1" ]; then L "configured" "configurato"; else L "NOT configured" "NON configurato"; fi; }

echo "Always on Mint $AOM_VERSION — $MACHINE_NAME"
echo
L "Alerts" "Avvisi"; echo
echo "  Telegram:         $(yesno "$TELEGRAM_TOKEN$TELEGRAM_CHAT_ID")"
echo "  healthchecks.io:  $(yesno "$HEALTHCHECKS_URL")"
echo "  $(L 'Desktop' 'Desktop'):          $DESKTOP_ALERTS  ($(L 'sound' 'suono') $ALERT_SOUND, $(L 'voice' 'voce') $ALERT_VOICE, $(L 'quiet hours' 'ore di silenzio') ${QUIET_HOURS:-$(L none nessuna)})"
echo
L "Schedule" "Programma"; echo
systemctl list-timers --all 'aom-*' --no-pager 2>/dev/null | sed 's/^/  /'
echo
L "Last report" "Ultimo rapporto"; echo
if [ -r "$AOM_STATE/report.txt" ]; then sed 's/^/  /' "$AOM_STATE/report.txt"
else echo "  $(L 'none yet: sudo aom check' 'ancora nessuno: sudo aom check')"; fi
echo
L "Last backups" "Ultimi backup"; echo
find "$AOM_BACKUPS" -maxdepth 1 -name '*.tar.gz' -printf '  %TF %TH:%TM  %s bytes  %f\n' 2>/dev/null | sort -r | head -5
