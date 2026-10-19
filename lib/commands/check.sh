# shellcheck shell=bash
# aom check — the health check. Runs by itself every hour (aom-check.timer).
#   sudo aom check            full report
#   sudo aom check --quiet    exit code only: 0 all good, 1 warnings, 2 critical problems
#
# Checks: disk space and inodes, root filesystem read-only, disk health (SMART), disk errors
# in the kernel log, half-finished updates, boot files of the kernels, failed services
# (system and users), memory, days since the last reboot and the last update, clock sync.
# Alerts (Telegram, desktop) only when the problems change, or once a day while they last,
# and when everything is fine again. Sends the hourly heartbeat to healthchecks.io.

# shellcheck source=../aom-common.sh
. "$AOM_LIB/aom-common.sh"
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1
mkdir -p "$AOM_STATE" "$AOM_LOG" 2>/dev/null
aom_replay_pending

CRIT=()
WARN=()
NOTE=()
crit() { CRIT+=("$1"); }
warn() { WARN+=("$1"); }
note() { NOTE+=("$1"); }
now=$(date +%s)

# ---------- 1. disk space ----------
seen=" "
for m in / /boot /boot/efi /home /var /tmp; do
  [ "$m" = / ] || mountpoint -q "$m" 2>/dev/null || continue
  dev=$(df -P "$m" 2>/dev/null | awk 'NR==2 {print $1}')
  case "$seen" in *" $dev "*) continue ;; esac
  seen="$seen$dev "
  use=$(aom_disk_use "$m")
  inodes=$(df -Pi "$m" 2>/dev/null | awk 'NR==2 { gsub("%","",$5); print $5 }')
  [ -n "$use" ] || continue
  if [ "$use" -ge "$DISK_CRITICAL" ]; then crit "$(Lf 'Disk %s is %s%% full' 'Disco %s pieno al %s%%' "$m" "$use")"
  elif [ "$use" -ge "$DISK_WARN" ]; then warn "$(Lf 'Disk %s is %s%% full' 'Disco %s pieno al %s%%' "$m" "$use")"; fi
  if [ -n "$inodes" ] && [ "$inodes" != "-" ] && [ "$inodes" -ge 90 ] 2>/dev/null; then
    warn "$(Lf 'Disk %s: %s%% of inodes used (too many small files)' 'Disco %s: usato il %s%% degli inode (troppi file piccoli)' "$m" "$inodes")"
  fi
done

# ---------- 2. read-only root (the filesystem found errors) ----------
if findmnt -no OPTIONS / 2>/dev/null | grep -qE '(^|,)ro(,|$)'; then
  crit "$(L 'The main disk is READ-ONLY: the filesystem found errors' 'Il disco principale è in SOLA LETTURA: il filesystem ha trovato errori')"
fi

# ---------- 3. disk health (SMART) ----------
if command -v smartctl >/dev/null; then
  while read -r d type; do
    [ "$type" = disk ] || continue
    case "$d" in /dev/zram*|/dev/loop*|/dev/sr*) continue ;; esac
    out=$(smartctl -H -A "$d" 2>/dev/null); rc=$?
    (( rc & 2 )) && continue                       # cannot be read (USB stick...)
    # only the verdict line counts: the attribute table always has a column called WHEN_FAILED
    if (( rc & 8 )) || grep -qE 'self-assessment test result: *FAILED|SMART Health Status: *(FAILED|.*FAILURE)' <<<"$out"; then
      crit "$(Lf 'Disk %s: SMART says it is FAILING. Back up now and replace it' 'Disco %s: SMART dice che si sta GUASTANDO. Fai subito un backup e cambialo' "$d")"
    fi
    (( rc & 16 )) && crit "$(Lf 'Disk %s: some SMART values are past the failure threshold' 'Disco %s: alcuni valori SMART hanno superato la soglia di guasto' "$d")"
    for a in Reallocated_Sector_Ct Current_Pending_Sector Offline_Uncorrectable; do
      v=$(awk -v a="$a" '$2==a {print $10}' <<<"$out" | head -1)
      if [ -n "$v" ] && [ "$v" -gt 0 ] 2>/dev/null; then
        warn "$(Lf 'Disk %s: %s = %s (damaged sectors: keep an eye on it)' 'Disco %s: %s = %s (settori rovinati: tienilo d'"'"'occhio)' "$d" "$a" "$v")"
      fi
    done
    used=$(awk -F: '/Percentage Used/ { gsub(/[ %]/,"",$2); print $2 }' <<<"$out")
    if [ -n "$used" ] && [ "$used" -ge 90 ] 2>/dev/null; then
      warn "$(Lf 'Disk %s: %s%% worn out (SSD close to end of life)' 'Disco %s: consumato al %s%% (SSD vicino a fine vita)' "$d" "$used")"
    fi
    cw=$(awk -F: '/Critical Warning/ { gsub(/ /,"",$2); print $2 }' <<<"$out")
    if [ -n "$cw" ] && [ "$cw" != "0x00" ]; then
      crit "$(Lf 'Disk %s: the SSD reports a critical warning (%s)' 'Disco %s: l'"'"'SSD segnala un allarme critico (%s)' "$d" "$cw")"
    fi
    (( rc & 128 )) && warn "$(Lf 'Disk %s: the last SMART self-test found errors' 'Disco %s: l'"'"'ultimo test SMART ha trovato errori' "$d")"
  done < <(lsblk -dnpo NAME,TYPE 2>/dev/null)
else
  note "$(L 'smartctl not installed: disk health not checked' 'smartctl non installato: salute del disco non controllata')"
fi

# ---------- 4. disk errors in the kernel log (since the last check) ----------
since=$(cat "$AOM_STATE/last-check" 2>/dev/null || echo $((now - 3600)))
n=$(journalctl -k --since "@$since" -o cat 2>/dev/null \
  | grep -ciE 'EXT4-fs error|I/O error|Buffer I/O error|blk_update_request|critical medium error|nvme.*(timeout|resetting)|ata[0-9.]+: (failed command|exception)|btrfs.*error' || true)
if [ "${n:-0}" -gt 0 ]; then
  crit "$(Lf 'The kernel logged %s disk errors in the last hour (see: journalctl -k -p err)' 'Il kernel ha registrato %s errori del disco nell'"'"'ultima ora (vedi: journalctl -k -p err)' "$n")"
fi
echo "$now" > "$AOM_STATE/last-check" 2>/dev/null

# ---------- 5. half-finished updates ----------
if [ -n "$(dpkg --audit 2>/dev/null)" ]; then
  crit "$(L 'An update was left HALF-DONE (unconfigured packages). Fix it with: sudo dpkg --configure -a' 'Un aggiornamento è rimasto A METÀ (pacchetti non configurati). Sistemalo con: sudo dpkg --configure -a')"
fi

# ---------- 6. can the PC still boot? ----------
running=$(uname -r)
newest=$(find /boot -maxdepth 1 -name 'vmlinuz-*' -printf '%f\n' 2>/dev/null | sed 's/^vmlinuz-//' | sort -V | tail -1)
for k in $(printf '%s\n%s\n' "$running" "$newest" | sort -u); do
  [ -n "$k" ] && [ -e "/boot/vmlinuz-$k" ] || continue
  f="/boot/initrd.img-$k"
  if [ ! -s "$f" ]; then
    crit "$(Lf 'Boot file %s is missing: at the next reboot that kernel would NOT start' 'Manca il file di avvio %s: al prossimo riavvio quel kernel NON partirebbe' "$f")"
  elif [ "$(stat -c %s "$f")" -lt 5000000 ]; then
    crit "$(Lf 'Boot file %s is too small (incomplete?): the next reboot might fail' 'Il file di avvio %s è troppo piccolo (incompleto?): il prossimo riavvio potrebbe fallire' "$f")"
  fi
  if [ -r /boot/grub/grub.cfg ] && ! grep -q "vmlinuz-$k" /boot/grub/grub.cfg; then
    warn "$(Lf 'The boot menu (GRUB) does not know kernel %s. Fix it with: sudo update-grub' 'Il menu di avvio (GRUB) non conosce il kernel %s. Sistemalo con: sudo update-grub' "$k")"
  fi
done
[ -e /var/run/reboot-required ] && note "$(L 'An update asks for a reboot (the weekly reboot will do it)' 'Un aggiornamento chiede un riavvio (lo farà il riavvio settimanale)')"

# ---------- 7. failed services (system and users) ----------
# services known to fail harmlessly (IGNORE_SERVICES) are left out
ignored() { local u="$1" i; for i in $IGNORE_SERVICES; do [ "$u" = "$i" ] && return 0; done; return 1; }
failed=""
for u in $(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}'); do
  ignored "$u" || failed="$failed$u "
done
[ -n "${failed// /}" ] && warn "$(Lf 'Failed system services: %s' 'Servizi di sistema falliti: %s' "$failed")"
for dir in /run/user/*; do
  [ -d "$dir" ] || continue
  uid=$(basename "$dir")
  [ "$uid" -ge 1000 ] 2>/dev/null || continue
  user=$(id -nu "$uid" 2>/dev/null) || continue
  fu=$(runuser -u "$user" -- env XDG_RUNTIME_DIR="$dir" systemctl --user --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | tr '\n' ' ')
  [ -n "${fu// /}" ] && warn "$(Lf 'Failed services of %s: %s' 'Servizi di %s falliti: %s' "$user" "$fu")"
done

# ---------- 8. memory ----------
read -r mt ma st sf < <(awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} /^SwapTotal/{st=$2} /^SwapFree/{sf=$2} END{print t,a,st,sf}' /proc/meminfo)
if [ "${mt:-0}" -gt 0 ] && [ $((ma * 100 / mt)) -lt 5 ]; then
  warn "$(Lf 'Memory almost full: %s%% free (is a program using more and more?)' 'Memoria quasi finita: libera il %s%% (qualche programma ne consuma sempre di più?)' "$((ma * 100 / mt))")"
fi
if [ "${st:-0}" -gt 0 ] && [ $(( (st - sf) * 100 / st )) -gt 80 ]; then
  warn "$(Lf 'Swap %s%% used' 'Swap usata al %s%%' "$(( (st - sf) * 100 / st ))")"
fi

# ---------- 9. days since the last reboot and the last update ----------
days_up=$(awk '{print int($1/86400)}' /proc/uptime)
if [ "$days_up" -ge "$MAX_DAYS_WITHOUT_REBOOT" ]; then
  warn "$(Lf 'No reboot for %s days: is the weekly reboot working? (systemctl list-timers aom-reboot.timer)' 'Il PC non si riavvia da %s giorni: il riavvio settimanale funziona? (systemctl list-timers aom-reboot.timer)' "$days_up")"
fi
stamp="$AOM_STATE/last-update"
if [ -e "$stamp" ]; then last=$(stat -c %Y "$stamp"); else last=$(stat -c %Y /var/log/apt/history.log 2>/dev/null || echo "$now"); fi
days_upd=$(( (now - last) / 86400 ))
if [ "$days_upd" -ge "$MAX_DAYS_WITHOUT_UPDATE" ]; then
  warn "$(Lf 'No updates for %s days: when you are at the PC run  sudo aom update' 'Sono %s giorni che non aggiorni: quando sei davanti al PC lancia  sudo aom update' "$days_upd")"
fi

# ---------- 10. clock ----------
if [ "$(timedatectl show -p NTPSynchronized --value 2>/dev/null)" = "no" ]; then
  warn "$(L 'The clock is not synchronized (scheduled scripts may run at the wrong time)' 'L'"'"'orologio non è sincronizzato (gli script programmati potrebbero partire all'"'"'ora sbagliata)')"
fi

# ---------- 11. good to know (report only, no alert) ----------
pipsys=$(find /usr/local/lib/python3*/dist-packages -maxdepth 1 -mindepth 1 2>/dev/null | wc -l)
[ "$pipsys" -gt 0 ] && note "$(Lf '%s Python packages installed with "sudo pip" in /usr/local/lib: better one virtual environment per bot' '%s pacchetti Python installati con "sudo pip" in /usr/local/lib: meglio un ambiente virtuale per ogni bot' "$pipsys")"
for f in /home/*/.xsession-errors; do
  [ -f "$f" ] || continue
  s=$(stat -c %s "$f")
  [ "$s" -gt 100000000 ] && note "$(Lf '%s is %s MB (the weekly cleanup empties it)' '%s è grande %s MB (la pulizia settimanale lo svuota)' "$f" "$((s / 1000000))")"
done

# ---------- report ----------
report="$AOM_STATE/report.txt"
{
  Lf 'Always on Mint — %s — %s — up %s days\n' 'Always on Mint — %s — %s — acceso da %s giorni\n' "$MACHINE_NAME" "$(date '+%F %T')" "$days_up"
  if [ ${#CRIT[@]} -eq 0 ] && [ ${#WARN[@]} -eq 0 ]; then echo "✅ $(L 'all good' 'tutto a posto')"; fi
  for x in "${CRIT[@]}"; do echo "⛔ $x"; done
  for x in "${WARN[@]}"; do echo "⚠️ $x"; done
  for x in "${NOTE[@]}"; do echo "ℹ️ $x"; done
} > "$report"
[ "$QUIET" -eq 1 ] || cat "$report"
cp "$report" "$AOM_LOG/status.txt" 2>/dev/null

# ---------- alerts: only when something changes, or once a day while it lasts ----------
# (the level is part of the key: a warning that becomes critical is a new alert)
problems=$( { [ ${#CRIT[@]} -gt 0 ] && printf 'C %s\n' "${CRIT[@]}"; [ ${#WARN[@]} -gt 0 ] && printf 'W %s\n' "${WARN[@]}"; } | sed -E 's/[0-9]+/N/g' | sort)
key=$(printf '%s' "$problems" | md5sum | cut -c1-12)
prev=$(cat "$AOM_STATE/last-alert" 2>/dev/null)
prev_key=${prev%% *}
prev_time=${prev##* }
if [ -n "$problems" ]; then
  if [ "$key" != "$prev_key" ] || [ $((now - ${prev_time:-0})) -ge 86400 ]; then
    if [ ${#CRIT[@]} -gt 0 ]; then aom_alert critical "$(L 'PROBLEM' 'PROBLEMA')" "$(grep -E '^(⛔|⚠️)' "$report")"
    else aom_alert warning "$(L 'Something is not right' 'Qualcosa non va')" "$(grep -E '^⚠️' "$report")"; fi
    echo "$key $now" > "$AOM_STATE/last-alert"
  fi
elif [ -n "$prev_key" ]; then
  aom_alert ok "$(L 'All good again' 'Tutto di nuovo a posto')" "$(L 'The problems reported before are gone.' 'I problemi segnalati prima sono spariti.')"
  rm -f "$AOM_STATE/last-alert"
fi

# heartbeat: "I'm alive" (and if something is critical, healthchecks.io knows it too)
if [ ${#CRIT[@]} -gt 0 ]; then aom_ping fail "$(cat "$report")"
else aom_ping "" "$(cat "$report")"; fi

[ ${#CRIT[@]} -gt 0 ] && exit 2
[ ${#WARN[@]} -gt 0 ] && exit 1
exit 0
