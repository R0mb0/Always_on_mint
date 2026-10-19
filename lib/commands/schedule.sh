# shellcheck shell=bash
# aom schedule — (re)writes the weekly reboot timer from REBOOT_SCHEDULE and shows what is planned.
#   sudo aom schedule      (after changing REBOOT_SCHEDULE in /etc/always-on-mint.conf)

# shellcheck source=../aom-common.sh
. "$AOM_LIB/aom-common.sh"
aom_need_root aom schedule
if [ "$REBOOT_SCHEDULE" = off ]; then
  systemctl disable --now aom-reboot.timer >/dev/null 2>&1
  L "Weekly reboot turned off (REBOOT_SCHEDULE=off). Not recommended." "Riavvio settimanale disattivato (REBOOT_SCHEDULE=off). Sconsigliato."; echo
  exit 0
fi
if ! systemd-analyze calendar "$REBOOT_SCHEDULE" >/dev/null 2>&1; then
  Lf 'REBOOT_SCHEDULE="%s" is not a valid time (example: "Sun *-*-* 05:10:00")\n' 'REBOOT_SCHEDULE="%s" non è un orario valido (esempio: "Sun *-*-* 05:10:00")\n' "$REBOOT_SCHEDULE" >&2
  exit 1
fi
cat > /etc/systemd/system/aom-reboot.timer <<EOF
[Unit]
Description=Always on Mint: careful weekly reboot

[Timer]
OnCalendar=$REBOOT_SCHEDULE
# if the PC was off at that time, do NOT reboot as soon as it starts: wait for next week
Persistent=false

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable aom-reboot.timer >/dev/null 2>&1
systemctl restart aom-reboot.timer
systemctl list-timers --all 'aom-*' --no-pager
