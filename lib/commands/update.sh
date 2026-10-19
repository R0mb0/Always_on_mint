# shellcheck shell=bash
# aom update — update the system SAFELY, while you are at the PC.
#   sudo aom update         updates, then asks whether to reboot (recommended: yes)
#   sudo aom update --yes   updates and reboots without asking
#
# Why by hand: an update installed silently and "tested" only at the reboot 100 days later
# is the classic way to end up with a PC that does not start. Instead:
#   1. checks the PC (no half-finished updates, enough disk space, also in /boot)
#   2. takes a Timeshift snapshot, if Timeshift is configured
#   3. updates
#   4. checks that the new kernel has its boot files and the boot menu knows it
#   5. reboots RIGHT AWAY: if something is wrong you find out now, while you are there
#      (and at boot you can pick the previous kernel: see the README)

# shellcheck source=../aom-common.sh
. "$AOM_LIB/aom-common.sh"
aom_need_root aom update
YES=0
[ "${1:-}" = "--yes" ] && YES=1
stop() {
  echo; echo "⛔ $1"; L "   Do not reboot until this is fixed." "   Non riavviare finché non è sistemato."; echo
  aom_alert critical "$(L 'Update stopped' 'Aggiornamento fermato')" "$1"
  exit 1
}
step() { echo; echo "── $1"; }
free_mb() { df -Pk "$1" | awk 'NR==2 {print int($4/1024)}'; }

step "$(L '1/5 Checking the PC' '1/5 Controllo del PC')"
if [ -n "$(dpkg --audit 2>/dev/null)" ]; then
  L "A previous update was left half-done: completing it." "Un aggiornamento precedente è rimasto a metà: provo a completarlo."; echo
  dpkg --configure -a || stop "$(L 'dpkg --configure -a cannot complete the previous update' 'dpkg --configure -a non riesce a completare l'"'"'aggiornamento precedente')"
fi
root_free=$(free_mb /)
if [ "$root_free" -lt 3000 ]; then
  Lf "Little space (%s MB): cleaning up first.\n" "Poco spazio (%s MB): prima faccio pulizia.\n" "$root_free"
  "$AOM_BIN" clean
  root_free=$(free_mb /)
fi
[ "$root_free" -lt 2000 ] && stop "$(Lf 'Only %s MB free on the disk: at least 2 GB are needed to update' 'Solo %s MB liberi sul disco: per aggiornare servono almeno 2 GB' "$root_free")"
if mountpoint -q /boot; then
  boot_free=$(free_mb /boot)
  if [ "$boot_free" -lt 250 ]; then DEBIAN_FRONTEND=noninteractive apt-get -y -q autoremove --purge; boot_free=$(free_mb /boot); fi
  [ "$boot_free" -lt 200 ] && stop "$(Lf '/boot has only %s MB free: a new kernel would not fit' '/boot ha solo %s MB liberi: un kernel nuovo non ci starebbe' "$boot_free")"
fi
Lf "ok: %s MB free\n" "ok: %s MB liberi\n" "$root_free"

step "$(L '2/5 Safety snapshot' '2/5 Istantanea di sicurezza')"
if command -v timeshift >/dev/null && [ -s /etc/timeshift/timeshift.json ] && grep -q '"backup_device_uuid" *: *"[^"]' /etc/timeshift/timeshift.json; then
  if ! timeshift --create --scripted --comments "before aom update"; then
    [ "$YES" -eq 1 ] && stop "$(L 'Timeshift could not take the snapshot' 'Timeshift non è riuscito a fare l'"'"'istantanea')"
    read -r -p "$(L 'Timeshift failed. Continue anyway? [y/N] ' 'Timeshift non è riuscito. Continuo lo stesso? [s/N] ')" r
    case "$r" in y|Y|s|S) ;; *) exit 1 ;; esac
  fi
else
  L "Timeshift is not configured: skipped (recommended, see the README)." "Timeshift non è configurato: salto (consigliato, vedi il README)."; echo
fi

step "$(L '3/5 Updating' '3/5 Aggiornamento')"
apt-get update -q || stop "$(L 'apt-get update fails (network? sources?)' 'apt-get update non riesce (rete? sorgenti?)')"
n=$(apt-get -s -q full-upgrade 2>/dev/null | grep -c '^Inst ')
if [ "$n" -eq 0 ]; then
  L "Nothing to update." "Niente da aggiornare."; echo
  mkdir -p "$AOM_STATE"; touch "$AOM_STATE/last-update"
  exit 0
fi
Lf "%s packages to update.\n" "%s pacchetti da aggiornare.\n" "$n"
if ! DEBIAN_FRONTEND=noninteractive apt-get -y -q -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef full-upgrade; then
  dpkg --configure -a
  [ -z "$(dpkg --audit)" ] || stop "$(L 'The update failed (see the messages above)' 'L'"'"'aggiornamento non è riuscito (vedi i messaggi qui sopra)')"
fi
[ -z "$(dpkg --audit 2>/dev/null)" ] || stop "$(L 'After the update some packages are not configured (sudo dpkg --configure -a)' 'Dopo l'"'"'aggiornamento ci sono pacchetti non configurati (sudo dpkg --configure -a)')"

step "$(L '4/5 Will the PC start again?' '4/5 Il PC saprà ripartire?')"
newest=$(find /boot -maxdepth 1 -name 'vmlinuz-*' -printf '%f\n' | sed 's/^vmlinuz-//' | sort -V | tail -1)
if [ -n "$newest" ] && [ ! -s "/boot/initrd.img-$newest" ]; then
  Lf "The boot file of kernel %s is missing: creating it.\n" "Manca il file di avvio del kernel %s: lo ricreo.\n" "$newest"
  update-initramfs -c -k "$newest" || stop "$(Lf 'Cannot create the boot file of kernel %s' 'Non riesco a creare il file di avvio del kernel %s' "$newest")"
fi
if [ -r /boot/grub/grub.cfg ] && ! grep -q "vmlinuz-$newest" /boot/grub/grub.cfg; then
  update-grub || stop "$(L 'update-grub fails: the boot menu does not know the new kernel' 'update-grub non riesce: il menu di avvio non conosce il kernel nuovo')"
fi
Lf "ok: newest kernel %s, boot files in place\n" "ok: kernel più recente %s, file di avvio presenti\n" "$newest"
mkdir -p "$AOM_STATE"; touch "$AOM_STATE/last-update"
aom_log updates "updated $n packages, newest kernel $newest"

step "$(L '5/5 Reboot' '5/5 Riavvio')"
if [ "$YES" -eq 0 ]; then
  read -r -p "$(L 'Reboot now, so that if something is wrong you find out right away? [Y/n] ' 'Riavvio adesso, così se qualcosa non va te ne accorgi subito? [S/n] ')" r
  case "$r" in n|N) L "OK. Reboot as soon as you can (the weekly reboot will do it at the latest)." "Va bene. Riavvia appena puoi (al più tardi lo fa il riavvio settimanale)."; echo; exit 0 ;; esac
fi
date +%s > "$AOM_STATE/update-reboot"
sync
systemctl reboot
