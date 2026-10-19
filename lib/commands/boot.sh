# shellcheck shell=bash
# aom boot — runs at every start (aom-boot.service).
# Tells you on Telegram that the PC is up again, and whether it had restarted BY ITSELF
# (power cut, freeze, crash): exactly what you want to know.

# shellcheck source=../aom-common.sh
. "$AOM_LIB/aom-common.sh"
mkdir -p "$AOM_STATE"

# the network may need a few seconds
for _ in $(seq 1 24); do
  curl -fsS --max-time 5 -o /dev/null "${TELEGRAM_API:-https://api.telegram.org}" 2>/dev/null && break
  sleep 5
done

if [ -e "$AOM_STATE/planned-reboot" ]; then
  rm -f "$AOM_STATE/planned-reboot"
  msg="🔄 $(L 'Weekly reboot done, I am up again.' 'Riavvio settimanale fatto, sono di nuovo acceso.')"
  aom_log reboots "up after the weekly reboot"
elif [ -e "$AOM_STATE/update-reboot" ]; then
  rm -f "$AOM_STATE/update-reboot"
  msg="🔄 $(Lf 'Up again after the update: kernel %s.' 'Riacceso dopo l'"'"'aggiornamento: kernel %s.' "$(uname -r)")"
  aom_log reboots "up after the update"
else
  # how did the previous run end? A normal shutdown leaves a trace in the log.
  if journalctl -b -1 -n 300 -o cat 2>/dev/null | grep -qE 'Reached target .*(Power-Off|Reboot|Halt|System Reboot|System Power Off)|systemd-shutdown|Shutting down'; then
    msg="🔌 $(L 'Up (it had been shut down or restarted by hand).' 'Acceso (era stato spento o riavviato a mano).')"
    aom_log reboots "up after a normal shutdown"
  else
    msg="⚠️ $(L 'I restarted BY MYSELF: power cut, freeze or crash. If it happens often: sudo aom check, and check power supply and temperature.' 'Mi sono riavviato DA SOLO: mancanza di corrente, blocco o crash. Se succede spesso: sudo aom check, e controlla alimentatore e temperatura.')"
    aom_log reboots "up after an UNEXPECTED stop"
  fi
fi
aom_telegram "🖥 $MACHINE_NAME — $msg"
exit 0
