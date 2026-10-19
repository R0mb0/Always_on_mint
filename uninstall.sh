#!/usr/bin/env bash
# Always on Mint — removes everything install.sh added.
#   sudo bash uninstall.sh           keeps /etc/always-on-mint.conf, the backups and the logs
#   sudo bash uninstall.sh --all     removes those too
# Linux Mint automatic updates are NOT turned back on: if you want them, use the Update Manager.
set -u
cd "$(dirname "$0")" || exit 1
AOM_CONF=/etc/always-on-mint.conf
# shellcheck source=lib/aom-common.sh
. lib/aom-common.sh
aom_need_root bash uninstall.sh

for u in aom-check.timer aom-clean.timer aom-backup.timer aom-reboot.timer aom-boot.service; do
  systemctl disable --now "$u" >/dev/null 2>&1
done
rm -f /etc/systemd/system/aom-*.service /etc/systemd/system/aom-*.timer
systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target >/dev/null 2>&1
rm -f /etc/systemd/logind.conf.d/50-always-on-mint.conf /etc/systemd/journald.conf.d/50-always-on-mint.conf \
      /etc/systemd/system.conf.d/50-always-on-mint.conf /etc/sysctl.d/90-always-on-mint.conf \
      /etc/default/grub.d/50-always-on-mint.cfg /etc/logrotate.d/always-on-mint \
      /etc/apt/apt.conf.d/99-always-on-mint-no-unattended
systemctl daemon-reload
systemctl restart systemd-journald
update-grub >/dev/null 2>&1
rm -f /usr/local/bin/aom
rm -rf /usr/local/lib/always-on-mint /var/lib/always-on-mint
if [ "${1:-}" = "--all" ]; then
  rm -rf /etc/always-on-mint.conf /var/backups/always-on-mint /var/log/always-on-mint
  L "Everything removed, configuration and backups included." "Tolto tutto, anche configurazione e backup."; echo
else
  L "Removed. Kept: /etc/always-on-mint.conf, the backups in /var/backups/always-on-mint and the logs in /var/log/always-on-mint." \
    "Tolto. Restano /etc/always-on-mint.conf, i backup in /var/backups/always-on-mint e i log in /var/log/always-on-mint."; echo
fi
L "The packages installed (smartmontools, earlyoom...) stay: they are harmless." \
  "I pacchetti installati (smartmontools, earlyoom...) restano: sono innocui."; echo
L "Careful: scripts started with \"aom run\" will not start any more until you remove it from their command." \
  "Attenzione: gli script lanciati con \"aom run\" non partiranno più finché non lo togli dal loro comando."; echo
