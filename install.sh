#!/usr/bin/env bash
# Always on Mint — installer.
#
#   sudo bash install.sh            install (safe to run again: it updates without breaking anything)
#   sudo bash install.sh --dry-run  show what it would do, without touching anything
#
# What it does (details in the README):
#   1. installs smartmontools, earlyoom, curl, logrotate, and what desktop alerts need
#   2. copies the "aom" command and creates /etc/always-on-mint.conf (if missing)
#   3. never sleeps: not even with the lid closed or nobody logged in
#   4. system logs with a ceiling, ~/.xsession-errors that cannot grow forever
#   5. if the system freezes, it restarts by itself (kernel panic, hardware watchdog)
#   6. boot menu (GRUB) always visible for 5 seconds, to pick the previous kernel
#   7. no silent automatic updates: you update with  sudo aom update
#   8. hourly check, weekly cleanup and backup, careful weekly reboot, message at every start

set -u
cd "$(dirname "$0")" || exit 1
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

# messages in the system language (the configuration may not exist yet)
AOM_CONF=/nonexistent
# shellcheck source=lib/aom-common.sh
. lib/aom-common.sh

if [ "$DRY" -eq 0 ] && [ "$(id -u)" -ne 0 ]; then
  L "Needs root:  sudo bash install.sh   (or: bash install.sh --dry-run to see what it would do)" \
    "Serve sudo:  sudo bash install.sh   (oppure: bash install.sh --dry-run per vedere cosa farebbe)"; echo
  exit 1
fi

title() { echo; echo "━━ $1"; }
run() {
  if [ "$DRY" -eq 1 ]; then echo "   [dry-run] $*"; return 0; fi
  "$@"
}
# writes a file from stdin (in dry-run it only shows it)
put() {
  local f="$1" content
  content=$(cat)
  if [ "$DRY" -eq 1 ]; then Lf "   [dry-run] I would write %s:\n" "   [dry-run] scriverei %s:\n" "$f"; sed 's/^/             /' <<<"$content"; return 0; fi
  mkdir -p "$(dirname "$f")"
  printf '%s\n' "$content" > "$f"
}

# ---------------------------------------------------------------- 0
title "$(L '0. Checks' '0. Controlli')"
# shellcheck source=/dev/null
. /etc/os-release 2>/dev/null
echo "   ${PRETTY_NAME:-?}"
case "${ID:-} ${ID_LIKE:-}" in
  *linuxmint*|*ubuntu*|*debian*) ;;
  *) L "   ✗ This kit is made for Linux Mint / Ubuntu / Debian." "   ✗ Questo kit è fatto per Linux Mint / Ubuntu / Debian."; echo; exit 1 ;;
esac
if [ "$(ps -p 1 -o comm= 2>/dev/null)" != systemd ] && [ "$DRY" -eq 0 ]; then
  L "   ✗ systemd is required." "   ✗ Serve systemd."; echo; exit 1
fi
for f in bin/aom lib/aom-common.sh lib/commands/check.sh always-on-mint.conf.example; do
  [ -e "$f" ] || { Lf "   ✗ %s is missing: run install.sh from its folder.\n" "   ✗ Manca %s: lancia install.sh dalla sua cartella.\n" "$f"; exit 1; }
done
echo "   ok"

# ---------------------------------------------------------------- 1
title "$(L '1. Packages' '1. Pacchetti')"
PKGS=(smartmontools earlyoom curl logrotate libnotify-bin pulseaudio-utils sound-theme-freedesktop speech-dispatcher espeak-ng)
run apt-get update -q >/dev/null 2>&1
if run env DEBIAN_FRONTEND=noninteractive apt-get install -y -q "${PKGS[@]}" >/dev/null 2>&1; then
  echo "   ${PKGS[*]}"
else
  L "   ⚠️ some packages could not be installed (internet?). Going on: you can run this again later." \
    "   ⚠️ non sono riuscito a installare tutti i pacchetti (internet?). Continuo: si può rilanciare dopo."; echo
fi

# ---------------------------------------------------------------- 2
title "$(L '2. The aom command and the configuration' '2. Il comando aom e la configurazione')"
run install -d -m 755 /usr/local/lib/always-on-mint/commands /var/lib/always-on-mint /var/log/always-on-mint
run install -m 644 lib/aom-common.sh /usr/local/lib/always-on-mint/aom-common.sh
for c in lib/commands/*.sh; do run install -m 644 "$c" /usr/local/lib/always-on-mint/commands/; done
run install -m 755 bin/aom /usr/local/bin/aom
if [ -e /etc/always-on-mint.conf ]; then
  L "   /etc/always-on-mint.conf already exists: left as it is" "   /etc/always-on-mint.conf c'è già: lo lascio com'è"; echo
else
  run install -m 644 always-on-mint.conf.example /etc/always-on-mint.conf
  L "   created /etc/always-on-mint.conf  ← to complete (Telegram, healthchecks.io, folders to back up)" \
    "   creato /etc/always-on-mint.conf  ← da completare (Telegram, healthchecks.io, cartelle da salvare)"; echo
fi

# ---------------------------------------------------------------- 3
title "$(L '3. Never sleep' '3. Niente sospensione, mai')"
run systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target >/dev/null 2>&1
put /etc/systemd/logind.conf.d/50-always-on-mint.conf <<'EOF'
# Always on Mint: this PC stays on
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
IdleAction=ignore
EOF
L "   suspend and hibernation off; closing the lid does nothing (from the next reboot)" \
  "   sospensione e ibernazione disattivate; chiudere il coperchio non fa niente (dal prossimo riavvio)"; echo

# ---------------------------------------------------------------- 4
title "$(L '4. Logs that cannot fill the disk' '4. Log che non riempiono il disco')"
put /etc/systemd/journald.conf.d/50-always-on-mint.conf <<'EOF'
# Always on Mint: system logs survive a reboot (to understand what happened), with a ceiling
[Journal]
Storage=persistent
SystemMaxUse=300M
SystemKeepFree=1G
MaxRetentionSec=2month
EOF
run mkdir -p /var/log/journal
run systemctl restart systemd-journald
put /etc/logrotate.d/always-on-mint <<'EOF'
# Always on Mint
/home/*/.xsession-errors {
    size 20M
    rotate 1
    copytruncate
    compress
    missingok
    notifempty
}
/var/log/always-on-mint/*.log {
    monthly
    rotate 6
    compress
    missingok
    notifempty
}
EOF
L "   system logs: at most 300 MB and 2 months; ~/.xsession-errors: at most 20 MB" \
  "   log di sistema: al massimo 300 MB e 2 mesi; ~/.xsession-errors: al massimo 20 MB"; echo

# ---------------------------------------------------------------- 5
title "$(L '5. If it freezes, it restarts by itself' '5. Se si blocca, si riavvia da solo')"
put /etc/sysctl.d/90-always-on-mint.conf <<'EOF'
# Always on Mint: after a kernel panic, reboot after 20 seconds (instead of staying frozen forever)
kernel.panic = 20
EOF
run sysctl -q --system
if ls /dev/watchdog* >/dev/null 2>&1; then
  put /etc/systemd/system.conf.d/50-always-on-mint.conf <<'EOF'
# Always on Mint: hardware watchdog. If the whole system freezes, the motherboard restarts it.
[Manager]
RuntimeWatchdogSec=60s
RebootWatchdogSec=5min
EOF
  run systemctl daemon-reexec
  L "   hardware watchdog on" "   watchdog hardware attivo"; echo
else
  L "   this PC has no hardware watchdog: only the reboot after a kernel panic" \
    "   questo PC non ha un watchdog hardware: solo il riavvio dopo un kernel panic"; echo
fi
run systemctl enable --now earlyoom >/dev/null 2>&1 && \
  { L "   earlyoom: when memory runs out it closes the biggest program instead of freezing everything" \
      "   earlyoom: quando la memoria finisce chiude il programma più grosso invece di bloccare tutto"; echo; }

# ---------------------------------------------------------------- 6
title "$(L '6. Boot menu always visible' '6. Menu di avvio sempre visibile')"
put /etc/default/grub.d/50-always-on-mint.cfg <<'EOF'
# Always on Mint: the boot menu stays visible for 5 seconds. If a new kernel does not start:
# "Advanced options" → the previous kernel.
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=5
GRUB_RECORDFAIL_TIMEOUT=5
EOF
run update-grub >/dev/null 2>&1 && { L "   GRUB updated" "   GRUB aggiornato"; echo; }

# ---------------------------------------------------------------- 7
title "$(L '7. Updates: only when you are there' '7. Aggiornamenti: solo quando ci sei')"
if command -v mintupdate-automation >/dev/null; then
  run mintupdate-automation upgrade disable >/dev/null 2>&1
  run mintupdate-automation autoremove disable >/dev/null 2>&1
  L "   Linux Mint automatic updates turned off (aom clean does the cleanup)" \
    "   aggiornamenti automatici di Linux Mint disattivati (la pulizia la fa aom clean)"; echo
fi
if grep -qs 'Unattended-Upgrade "1"' /etc/apt/apt.conf.d/*; then
  put /etc/apt/apt.conf.d/99-always-on-mint-no-unattended <<'EOF'
// Always on Mint: no silent updates. Update with: sudo aom update
APT::Periodic::Unattended-Upgrade "0";
EOF
  L "   unattended-upgrades turned off" "   unattended-upgrades disattivato"; echo
fi
L "   from now on: sudo aom update (once a month; the check reminds you)" \
  "   d'ora in poi: sudo aom update (una volta al mese; te lo ricorda il controllo)"; echo

# ---------------------------------------------------------------- 8
title "$(L '8. Disk and clock' '8. Disco e orologio')"
run systemctl enable --now smartmontools >/dev/null 2>&1 || run systemctl enable --now smartd >/dev/null 2>&1
run systemctl enable --now systemd-timesyncd >/dev/null 2>&1
L "   smartd watches the disks; clock synchronized" "   smartd sorveglia i dischi; orologio sincronizzato"; echo

# ---------------------------------------------------------------- 9
title "$(L '9. Automatic jobs' '9. Lavori automatici')"
service() { # name, description, command
  put "/etc/systemd/system/$1.service" <<EOF
[Unit]
Description=Always on Mint: $2

[Service]
Type=oneshot
ExecStart=$3
# 1 = warnings, 2 = critical problems: already reported by aom, not failures of the service
SuccessExitStatus=1 2
Nice=10
EOF
}
timer() { # name, description, [Timer] lines
  put "/etc/systemd/system/$1.timer" <<EOF
[Unit]
Description=Always on Mint: $2

[Timer]
$3

[Install]
WantedBy=timers.target
EOF
}
service aom-check  "health check" "/usr/local/bin/aom check --quiet"
timer   aom-check  "hourly health check" $'OnBootSec=10min\nOnUnitActiveSec=1h\nRandomizedDelaySec=2min'
service aom-clean  "weekly cleanup" "/usr/local/bin/aom clean"
timer   aom-clean  "cleanup on Sunday" $'OnCalendar=Sun *-*-* 04:20:00\nPersistent=true'
service aom-backup "weekly backup" "/usr/local/bin/aom backup"
timer   aom-backup "backup on Sunday" $'OnCalendar=Sun *-*-* 04:40:00\nPersistent=true'
service aom-reboot "careful weekly reboot" "/usr/local/bin/aom reboot"
put /etc/systemd/system/aom-boot.service <<'EOF'
[Unit]
Description=Always on Mint: message at every start
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/aom boot
TimeoutStartSec=3min

[Install]
WantedBy=multi-user.target
EOF
run systemctl daemon-reload
run systemctl enable --now aom-check.timer aom-clean.timer aom-backup.timer >/dev/null 2>&1
run systemctl enable aom-boot.service >/dev/null 2>&1
run /usr/local/bin/aom schedule >/dev/null
run touch /var/lib/always-on-mint/installed
L "   hourly check; Sunday 04:20 cleanup, 04:40 backup; reboot as set in REBOOT_SCHEDULE" \
  "   controllo ogni ora; domenica 04:20 pulizia, 04:40 backup; riavvio come da REBOOT_SCHEDULE"; echo

# ---------------------------------------------------------------- done
title "$(L 'Done' 'Fatto')"
if [ "$DRY" -eq 0 ]; then
  /usr/local/bin/aom check
  echo
fi
L "Now:
  1. complete the configuration:    sudo nano /etc/always-on-mint.conf
     - TELEGRAM_TOKEN and TELEGRAM_CHAT_ID   (alerts on your phone)
     - HEALTHCHECKS_URL                      (know when the PC is dead)
     - BACKUP_PATHS                          (the folders of your bots)
  2. test the alerts:               sudo aom test-alert
  3. test the reboot, without doing it: sudo aom reboot --dry-run
  4. put \"aom run\" in front of your bots (see the README)
  5. reboot once, to activate everything
" "Adesso:
  1. completa la configurazione:     sudo nano /etc/always-on-mint.conf
     - TELEGRAM_TOKEN e TELEGRAM_CHAT_ID     (gli avvisi sul telefono)
     - HEALTHCHECKS_URL                      (sapere se il PC è morto)
     - BACKUP_PATHS                          (le cartelle dei tuoi bot)
  2. prova gli avvisi:               sudo aom test-alert
  3. prova il riavvio, senza farlo:  sudo aom reboot --dry-run
  4. metti \"aom run\" davanti ai tuoi bot (vedi il README)
  5. riavvia una volta, per attivare tutto
"
