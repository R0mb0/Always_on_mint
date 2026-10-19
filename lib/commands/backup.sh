# shellcheck shell=bash
# aom backup — weekly backup (aom-backup.timer).
#   sudo aom backup
#
# Saves to /var/backups/always-on-mint/<name>-<date>.tar.gz:
#   - /etc (the whole system configuration, /etc/always-on-mint.conf included)
#   - every user's crontab and systemd user services (~/.config/systemd)
#   - the list of installed packages (to reinstall them: see the README)
#   - the folders in BACKUP_PATHS (your bots), without virtual environments,
#     node_modules and caches, which can be rebuilt
# and, if BACKUP_COPY_TO is a reachable folder (USB stick, external disk), there too.
# Keeps BACKUP_KEEP of them. The archive contains passwords and tokens: root only.

# shellcheck source=../aom-common.sh
. "$AOM_LIB/aom-common.sh"
aom_need_root aom backup
dest="$AOM_BACKUPS"
mkdir -p "$dest" && chmod 700 "$dest"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

info="$tmp/aom-info"
mkdir -p "$info"
dpkg --get-selections > "$info/packages.txt" 2>/dev/null
apt-mark showmanual > "$info/packages-installed-by-hand.txt" 2>/dev/null
{ uname -a; lsblk -f; df -h; } > "$info/system.txt" 2>/dev/null
for h in /home/*; do
  u=$(basename "$h")
  crontab -l -u "$u" > "$info/crontab-$u.txt" 2>/dev/null || rm -f "$info/crontab-$u.txt"
done

what=(/etc)
[ -d /var/spool/cron/crontabs ] && what+=(/var/spool/cron/crontabs)
for h in /home/*/.config/systemd; do [ -d "$h" ] && what+=("$h"); done
for p in $BACKUP_PATHS; do
  if [ -e "$p" ]; then what+=("$p")
  else aom_alert warning "$(L 'Backup' 'Backup')" "$(Lf 'The folder %s (BACKUP_PATHS) does not exist any more' 'La cartella %s (BACKUP_PATHS) non esiste più' "$p")"; fi
done
EXCL=(--exclude=node_modules --exclude=venv --exclude=.venv --exclude=__pycache__ --exclude=.cache)

# never fill the disk with the backup
need=$(du -sk "${EXCL[@]}" "${what[@]}" "$info" 2>/dev/null | awk '{s+=$1} END {print s+0}')
free=$(df -Pk "$dest" | awk 'NR==2 {print $4}')
if [ "$need" -gt $((free / 3)) ]; then
  aom_alert critical "$(L 'Backup NOT done' 'Backup NON fatto')" \
    "$(Lf 'It would need %s MB, but only %s MB are left on the disk.' 'Servirebbero %s MB, ma sul disco ne restano solo %s.' "$((need / 1024))" "$((free / 1024))")"
  exit 1
fi

file="$dest/${MACHINE_NAME// /_}-$(date +%F).tar.gz"
tar --warning=no-file-changed --ignore-failed-read "${EXCL[@]}" \
    -czf "$file" -C "$tmp" aom-info -C / "${what[@]#/}" 2>"$tmp/errors.txt"
rc=$?
# tar exits with 1 if some file changed while being copied: fine. 2 is a real error.
if [ "$rc" -ge 2 ]; then
  aom_alert critical "$(L 'Backup failed' 'Backup fallito')" "$(tail -5 "$tmp/errors.txt")"
  rm -f "$file"
  exit 1
fi
chmod 600 "$file"
find "$dest" -maxdepth 1 -name '*.tar.gz' -printf '%T@ %p\n' | sort -rn | tail -n +$((BACKUP_KEEP + 1)) | cut -d' ' -f2- | xargs -r rm -f
line="$(Lf 'backup: %s (%s MB)' 'backup: %s (%s MB)' "$file" "$(( $(stat -c %s "$file") / 1048576 ))")"

if [ -n "$BACKUP_COPY_TO" ]; then
  if [ -d "$BACKUP_COPY_TO" ] && [ -w "$BACKUP_COPY_TO" ] && cp "$file" "$BACKUP_COPY_TO/"; then
    find "$BACKUP_COPY_TO" -maxdepth 1 -name "${MACHINE_NAME// /_}-*.tar.gz" -printf '%T@ %p\n' | sort -rn | tail -n +$((BACKUP_KEEP + 1)) | cut -d' ' -f2- | xargs -r rm -f
    line="$line, $(Lf 'copied to %s too' 'copiato anche in %s' "$BACKUP_COPY_TO")"
  else
    aom_alert warning "$(L 'Backup' 'Backup')" \
      "$(Lf 'Done on the PC, but %s is not reachable (USB stick unplugged?).' 'Fatto sul PC, ma %s non è raggiungibile (chiavetta scollegata?).' "$BACKUP_COPY_TO")"
  fi
fi
aom_log backup "$line"
echo "$line"
