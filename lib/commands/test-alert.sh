# shellcheck shell=bash
# aom test-alert — sends a test alert through every channel, ignoring the quiet hours,
# and tells you which ones work.
#   sudo aom test-alert          one alert
#   sudo aom test-alert --ring   the alarm that rings until you stop it (even if ALERT_UNTIL_ACK=no)

# shellcheck source=../aom-common.sh
. "$AOM_LIB/aom-common.sh"
if [ "${1:-}" = "--ring" ]; then
  if [ -z "$(aom_sessions)" ]; then
    L "Nobody is logged in to a graphical session: the alarm would wait for someone to log in." \
      "Nessuno è collegato a una sessione grafica: l'allarme aspetterebbe che qualcuno entri."; echo
    exit 1
  fi
  export AOM_FORCE_SOUND=1
  aom_ring_start "$(L 'Test alarm' 'Allarme di prova')" "$(L 'This alarm rings until you stop it. This is only a test.' 'Questo allarme suona finché non lo fermi. È solo una prova.')"
  Lf "🔔 The test alarm rings every %s seconds (quiet hours ignored).\n   Stop it by clicking \"Got it\" on the notification, or with:  aom ack\n" \
     "🔔 L'allarme di prova suona ogni %s secondi (ore di silenzio ignorate).\n   Fermalo cliccando \"Ho visto\" sulla notifica, oppure con:  aom ack\n" "$ALERT_RING_EVERY"
  exit 0
fi
ok()   { echo "  ✅ $1"; }
nope() { echo "  ❌ $1"; }
skip() { echo "  ➖ $1"; }

L "Sending a test alert..." "Mando un avviso di prova..."; echo; echo

# Telegram
if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
  skip "$(L 'Telegram: not configured (TELEGRAM_TOKEN, TELEGRAM_CHAT_ID)' 'Telegram: non configurato (TELEGRAM_TOKEN, TELEGRAM_CHAT_ID)')"
elif aom_telegram "🖥 $MACHINE_NAME — 🧪 $(L 'Test alert from Always on Mint. If you read this, Telegram works!' 'Avviso di prova da Always on Mint. Se leggi questo, Telegram funziona!')"; then
  ok "$(L 'Telegram: sent, check your phone' 'Telegram: mandato, guarda il telefono')"
else
  nope "$(L 'Telegram: not sent. Check token and chat id (see the README), and the internet connection' 'Telegram: non mandato. Controlla token e chat id (vedi il README) e la connessione')"
fi

# healthchecks.io
if [ -z "$HEALTHCHECKS_URL" ]; then
  skip "$(L 'healthchecks.io: not configured (HEALTHCHECKS_URL)' 'healthchecks.io: non configurato (HEALTHCHECKS_URL)')"
elif curl -fsS --max-time 15 -o /dev/null "${HEALTHCHECKS_URL%/}" 2>/dev/null; then
  ok "$(L 'healthchecks.io: heartbeat sent (the check turns green)' 'healthchecks.io: battito mandato (il check diventa verde)')"
else
  nope "$(L 'healthchecks.io: the address does not answer' 'healthchecks.io: l'"'"'indirizzo non risponde')"
fi

# desktop
if [ "$DESKTOP_ALERTS" != yes ]; then
  skip "$(L 'Desktop: turned off (DESKTOP_ALERTS)' 'Desktop: disattivato (DESKTOP_ALERTS)')"
else
  sessions=$(aom_sessions)
  if [ -z "$sessions" ]; then
    skip "$(L 'Desktop: nobody is logged in to a graphical session right now' 'Desktop: in questo momento nessuno è collegato a una sessione grafica')"
  else
    while read -r user _ _; do ok "$(Lf 'Desktop: notification sent to %s' 'Desktop: notifica mandata a %s' "$user")"; done <<<"$sessions"
    command -v notify-send >/dev/null || nope "$(L 'notify-send is missing: sudo apt install libnotify-bin' 'manca notify-send: sudo apt install libnotify-bin')"
    if [ "$ALERT_SOUND" = yes ]; then
      if { command -v paplay >/dev/null && ls /usr/share/sounds/freedesktop/stereo/*.oga >/dev/null 2>&1; } || command -v canberra-gtk-play >/dev/null; then ok "$(L 'Sound: you should hear an alarm (3 times, as for a critical problem)' 'Suono: dovresti sentire un allarme (3 volte, come per un problema critico)')"
      else nope "$(L 'Sound: missing: sudo apt install pulseaudio-utils sound-theme-freedesktop' 'Suono: manca: sudo apt install pulseaudio-utils sound-theme-freedesktop')"; fi
    else skip "$(L 'Sound: turned off (ALERT_SOUND)' 'Suono: disattivato (ALERT_SOUND)')"; fi
    if [ "$ALERT_VOICE" != no ]; then
      if command -v spd-say >/dev/null; then ok "$(L 'Voice: you should hear the message read aloud' 'Voce: dovresti sentire il messaggio letto ad alta voce')"
      else nope "$(L 'Voice: spd-say is missing: sudo apt install speech-dispatcher espeak-ng' 'Voce: manca spd-say: sudo apt install speech-dispatcher espeak-ng')"; fi
    else skip "$(L 'Voice: turned off (ALERT_VOICE)' 'Voce: disattivata (ALERT_VOICE)')"; fi
    if aom_quiet_now; then echo "  ℹ️ $(Lf 'Now it is quiet hours (%s): real alerts would stay silent until the morning' 'Adesso sono ore di silenzio (%s): gli avvisi veri resterebbero muti fino al mattino' "$QUIET_HOURS")"; fi
    case "$ALERT_UNTIL_ACK" in
      critical|all) echo "  ℹ️ $(Lf 'Real alerts (%s) ring every %ss until you stop them: try it with  sudo aom test-alert --ring' 'Gli avvisi veri (%s) suonano ogni %ss finché non li fermi: provalo con  sudo aom test-alert --ring' "$ALERT_UNTIL_ACK" "$ALERT_RING_EVERY")" ;;
    esac
    AOM_FORCE_SOUND=1 ALERT_UNTIL_ACK=no aom_desktop critical "$(L 'Test alert' 'Avviso di prova')" "$(L 'Always on Mint works. This is only a test.' 'Always on Mint funziona. Questa è solo una prova.')"
  fi
fi
echo
aom_log alerts "test alert"
