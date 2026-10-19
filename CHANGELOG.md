# Changelog

## 1.0.0 — unreleased

First public version.

- `aom` command: `check`, `status`, `test-alert`, `update`, `clean`, `backup`, `reboot`, `schedule`, `run`.
- Hourly health check: disk space and inodes, read-only root, SMART, disk errors in the kernel log, half-finished updates, kernel boot files, failed services, memory, days without reboot or update, clock sync.
- Careful weekly reboot that refuses to reboot when the PC might not start again.
- Weekly cleanup and backup.
- Alerts on Telegram, healthchecks.io heartbeat, desktop notification, sound and voice with quiet hours.
- `aom run` wrapper for scripts and bots.
- Never sleeps, logs with a ceiling, kernel panic auto-reboot, hardware watchdog, earlyoom, visible boot menu, no silent automatic updates.
- Messages in English and Italian.
- `IGNORE_SERVICES`: failed services not to report (default: `casper-md5check.service`, a harmless leftover of the Linux Mint installer).
- Fixed before release: the SMART check mistook the `WHEN_FAILED` column of the attribute table for a failing disk.
