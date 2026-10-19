# shellcheck shell=bash
# aom clean — weekly cleanup (aom-clean.timer, before the reboot).
#   sudo aom clean
#
# Removes what piles up by itself and fills the disk:
#   - the cache of downloaded packages (apt clean)
#   - old kernels and orphan packages (apt autoremove; it always keeps the running kernel
#     and the previous one, so you can pick it at boot)
#   - system logs above JOURNAL_MAX_SIZE
#   - ~/.xsession-errors above 50 MB (on Xfce it can grow until the disk is full)
#   - crash reports older than a week
# If an update is half-done or apt is busy, packages are left alone.

# shellcheck source=../aom-common.sh
. "$AOM_LIB/aom-common.sh"
aom_need_root aom clean
free_before=$(df -Pk / | awk 'NR==2 {print $4}')
done_list=()

if [ -n "$(dpkg --audit 2>/dev/null)" ]; then
  done_list+=("$(L 'packages NOT touched: an update is half-done' 'pacchetti NON toccati: c'"'"'è un aggiornamento a metà')")
elif fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock >/dev/null 2>&1; then
  done_list+=("$(L 'packages NOT touched: apt was busy' 'pacchetti NON toccati: apt era occupato')")
else
  apt-get clean && done_list+=("$(L 'package cache emptied' 'cache dei pacchetti svuotata')")
  if [ "$CLEAN_OLD_KERNELS" = yes ]; then
    if LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get -y -q autoremove --purge >"$AOM_STATE/autoremove.log" 2>&1; then
      n=$(grep -c '^Removing' "$AOM_STATE/autoremove.log" || true)
      done_list+=("$(Lf 'old packages removed: %s' 'pacchetti vecchi tolti: %s' "${n:-0}")")
    else
      done_list+=("$(Lf 'autoremove failed (see %s)' 'autoremove non riuscito (vedi %s)' "$AOM_STATE/autoremove.log")")
    fi
  fi
fi

journalctl --vacuum-size="$JOURNAL_MAX_SIZE" --vacuum-time=2months >/dev/null 2>&1 \
  && done_list+=("$(Lf 'system logs below %s' 'log di sistema sotto %s' "$JOURNAL_MAX_SIZE")")

for f in /home/*/.xsession-errors /home/*/.xsession-errors.old; do
  [ -f "$f" ] || continue
  if [ "$(stat -c %s "$f")" -gt 50000000 ]; then
    truncate -s 0 "$f" && done_list+=("$(Lf 'emptied %s' 'svuotato %s' "$f")")
  fi
done

find /var/crash -type f -mtime +7 -delete 2>/dev/null

free_after=$(df -Pk / | awk 'NR==2 {print $4}')
line="$(Lf 'cleanup: %s MB freed' 'pulizia: liberati %s MB' "$(( (free_after - free_before) / 1024 ))"); $(IFS=';'; echo "${done_list[*]}")"
aom_log clean "$line"
echo "$line"
