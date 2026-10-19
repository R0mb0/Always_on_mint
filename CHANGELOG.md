# Changelog

## 1.0.0 — unreleased

First public version.

- `aom` command: `check`, `status`, `test-alert`, `update`, `clean`, `backup`, `reboot`, `schedule`, `run`, `ack`.
- Hourly health check: disk space and inodes, read-only root, SMART, disk errors in the kernel log, half-finished updates, kernel boot files, failed services, memory, days without reboot or update, clock sync.
- Careful weekly reboot that refuses to reboot when the PC might not start again.
- Weekly cleanup and backup.
- Alerts on Telegram, healthchecks.io heartbeat, desktop notification, sound and voice with quiet hours.
- `aom run` wrapper for scripts and bots.
- Optional alarm that rings until someone intervenes (`ALERT_UNTIL_ACK`, `ALERT_RING_EVERY`, `ALERT_RING_MAX_MINUTES`): stopped by the notification's "Got it" button, `aom ack`, or when the problem goes away. `aom test-alert --ring` to try it.
- Desktop alerts that arrive while nobody is logged in (e.g. "I restarted by myself" at boot) wait until someone is there to hear them.
- Never sleeps, logs with a ceiling, kernel panic auto-reboot, hardware watchdog, earlyoom, visible boot menu, no silent automatic updates.
- Messages in English and Italian.
- `IGNORE_SERVICES`: failed services not to report (default: `casper-md5check.service`, a harmless leftover of the Linux Mint installer).
- Fixed before release: the SMART check mistook the `WHEN_FAILED` column of the attribute table for a failing disk.
