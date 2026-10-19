# 🛡️ Always on Mint

**Always on Mint** is a small, dependency-free **Bash toolkit** that keeps an **always-on Linux Mint, Ubuntu or Debian PC** healthy for months — the old laptop that runs your bots, the mini PC that hosts your scripts, the desktop that never sleeps. It **checks the machine every hour**, **cleans and backs it up every week**, **reboots it carefully** (and **refuses** when the PC might not start again), and **tells you when something is wrong**: on **Telegram**, with a **healthchecks.io** heartbeat, and out loud on the **laptop's own speakers**.

<!-- badges -->

> 🇮🇹 **Italiano:** [README.it.md](README.it.md)

---

## 🤔 Why this project exists

You have a PC that is always on. It runs a couple of scripts: a Telegram bot, a scraper, something that pays a bill or renews a booking. Everything works, so you forget about it.

Then, one day — after 100 days, maybe more — you reboot it. And it **does not start any more**.

It is rarely Linux "breaking". It is things that **pile up silently** while the PC is running and all come out together at the first reboot:

| What piles up | What happens at the reboot |
|---|---|
| Logs, package caches, old kernels, `~/.xsession-errors`, Timeshift snapshots: **the disk fills up** | the system cannot write its boot or login files: black screen, or a login screen that sends you back |
| **Updates installed in the background**, never tested | the new kernel, installed badly (maybe with a full disk), does not boot |
| **Disk errors** growing slowly | at boot, the filesystem check finds all of them at once |
| Python packages installed with `sudo pip` | system tools written in Python stop working |
| The PC went to **sleep**, or **froze** | your scripts simply did not run, and nobody told you |

And the worst part: **nobody tells you**. You find out when the bot has already missed its job.

Always on Mint attacks each of these points. Above all, it **reboots once a week, carefully**: problems come out while they are still small — and only if it is safe to reboot.

---

## ✨ Features

- **Hourly health check**: disk space and inodes, read-only root filesystem, disk health (**SMART**), disk errors in the kernel log, **half-finished updates**, **boot files of the kernels**, failed services (yours too), memory, clock sync, days since the last reboot and the last update.
- **Careful weekly reboot**: before rebooting it runs the full check; if something could stop the PC from starting again, it **does not reboot** and alerts you. It also waits for your jobs to finish.
- **Alerts that reach you**: **Telegram** messages, a **healthchecks.io** heartbeat (the only way to know that the PC is *dead*), and on the PC itself a **desktop notification**, an **alarm sound** and a **voice** reading the problem.
- **Quiet hours**: no sound and no voice at night; what happened is played in the morning.
- **No spam**: an alert when a problem appears, once a day while it lasts, and a message when everything is fine again.
- **Weekly cleanup**: package cache, old kernels (always keeping the running one and the previous one), orphan packages, oversized logs, old crash reports.
- **Weekly backup**: `/etc`, crontabs, user services, the list of installed packages and the folders of your bots — with an optional second copy on a USB stick.
- **Watch your bots**: `aom run` in front of any script tells you when it **fails**, **hangs** or **does not start at all**.
- **Safe updates**: `aom update` takes a snapshot, updates, verifies the new kernel can boot, and reboots **while you are there**.
- **Never sleeps**: not with the lid closed, not with nobody logged in.
- **Restarts by itself** after a kernel panic, and through the **hardware watchdog** if the whole system freezes. **earlyoom** closes the biggest program instead of letting the PC freeze when memory runs out.
- **Visible boot menu**: 5 seconds at every start, to pick the previous kernel if a new one does not boot.
- **English and Italian**: every message follows the system language (or the one you choose).
- **Nothing hidden**: plain Bash, readable in a few minutes, `--dry-run` for the installer, a clean uninstaller.

---

## 📋 Requirements

- **Linux Mint** (any edition: Cinnamon, Xfce, MATE), **Ubuntu** or **Debian** — anything with `apt` and `systemd`.
- `sudo` access.
- An internet connection for the alerts (the checks work offline too).
- *Optional:* a Telegram account and a free healthchecks.io account.

---

## 🚀 Quick start

1. **Download** the project:

   ```bash
   git clone https://github.com/R0mb0/Always_on_mint.git
   cd Always_on_mint
   ```

2. **See what it would do**, without touching anything:

   ```bash
   bash install.sh --dry-run
   ```

3. **Install**:

   ```bash
   sudo bash install.sh
   ```

   It can be run again at any time (for example after `git pull`): it never overwrites your configuration.

4. **Configure** the alerts (Telegram and healthchecks.io: see the next sections) and the folders to back up:

   ```bash
   sudo nano /etc/always-on-mint.conf
   ```

5. **Test** the alerts:

   ```bash
   sudo aom test-alert
   ```

6. **Check** that the weekly reboot would be safe:

   ```bash
   sudo aom reboot --dry-run
   ```

7. **Reboot once**, to activate everything (lid settings, watchdog).

From now on the PC looks after itself. Once a month, when you are at the PC, run `sudo aom update`.

---

## 📲 Telegram alerts (step by step)

Telegram is the most useful channel: a message on your phone, wherever you are, a few seconds after something happens. You need a **bot** (it takes a minute and it is free) and your **chat id**.

### 1. Create your bot

1. In Telegram, search for **@BotFather** (the official one, with the blue tick) and open the chat.
2. Send `/newbot`.
3. Choose a **name** (anything, e.g. `My PC alerts`) and a **username** that ends in `bot` (e.g. `my_pc_alerts_bot`).
4. BotFather answers with a **token**, something like:

   ```
   123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw
   ```

   That token is the **password** of your bot: keep it private.

### 2. Find your chat id

1. Open the chat with **your new bot** (BotFather gives you the link `t.me/your_bot`) and press **Start**, or send it any message. *This step matters: a bot cannot write to you until you write to it first.*
2. In a browser, open this address, with your token instead of `<TOKEN>`:

   ```
   https://api.telegram.org/bot<TOKEN>/getUpdates
   ```

3. Look for `"chat":{"id":` in the page. The number after it is your **chat id**:

   ```json
   "chat":{"id":123456789,"first_name":"Francesco","type":"private"}
   ```

   If the page shows only `{"ok":true,"result":[]}`, send another message to your bot and reload.

### 3. Put them in the configuration

```bash
sudo nano /etc/always-on-mint.conf
```

```bash
TELEGRAM_TOKEN="123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw"
TELEGRAM_CHAT_ID="123456789"
```

Save with **Ctrl+O**, **Enter**, exit with **Ctrl+X**.

### 4. Test

```bash
sudo aom test-alert
```

Within a few seconds you get: *"🧪 Test alert from Always on Mint. If you read this, Telegram works!"*

### What you will receive

| When | Message |
|---|---|
| A problem appears (and once a day while it lasts) | ⚠️ *Something is not right* or ⛔ *PROBLEM*, with the list |
| Everything is fine again | ✅ *All good again* |
| The weekly reboot is cancelled because it is not safe | ⛔ *Weekly reboot CANCELLED*, with the reason |
| The PC starts after the weekly reboot / after an update / after you switched it off | 🔄 / 🔌 *I am up again* |
| The PC restarted **by itself** (power cut, freeze, crash) | ⚠️ *I restarted BY MYSELF* |
| A script started with `aom run` fails or hangs | ⛔ *taxes failed*, with its last lines |
| The backup could not be done or copied | ⛔ / ⚠️ *Backup* |

### Tips

- **Several PCs, one bot**: use the same token and chat id on all of them. Each message starts with the name of the PC (`MACHINE_NAME`).
- **A group instead of a private chat**: add the bot to a group, write something in the group, and use the group's id from `getUpdates` — it is a **negative** number (e.g. `-1001234567890`).
- **You already have a bot** for your projects: you can use its token. Always on Mint only *sends* messages, it never reads them.

### Troubleshooting

| What happens | Why, and what to do |
|---|---|
| `test-alert` says ❌ *not sent* | Wrong token or chat id. Open the `getUpdates` address again: if it says `Unauthorized`, the token is wrong. |
| Nothing arrives, no error | You never pressed **Start** in the chat with your bot. Do it and test again. |
| `getUpdates` is always empty | Another program is reading the bot's messages (a webhook). Use a new bot just for alerts. |
| It worked, then stopped | The token was revoked in BotFather (`/revoke`), or the PC has no internet: `sudo aom check` works offline and shows the rest. |

---

## 💓 healthchecks.io: know when the PC is dead

A PC that is switched off, frozen, or does not boot **cannot send you anything**. healthchecks.io works the other way round: the PC says *"I'm alive"* every hour, and when it **stops**, healthchecks.io writes to you.

1. Create a free account on [healthchecks.io](https://healthchecks.io).
2. **Add Check** → give it a name (e.g. `Bot PC`).
3. Set **Period: 1 hour** and **Grace: 1 hour**.
4. Copy the **ping URL** (`https://hc-ping.com/xxxxxxxx-xxxx-...`) into the configuration:

   ```bash
   HEALTHCHECKS_URL="https://hc-ping.com/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   ```

5. In **Integrations** choose how to be notified: email is on by default, and healthchecks.io can also write to **Telegram**.
6. `sudo aom test-alert`: the check turns **green**.

When the check finds a **critical** problem, the heartbeat is sent as a **failure**, so healthchecks.io marks the PC as *down* even if it is still running.

---

## 🔊 Alerts on the PC itself: notification, sound, voice

Linux Mint is often installed on **laptops**, and laptops have **speakers**. If someone is logged in, Always on Mint also:

- shows a **desktop notification** (urgent for critical problems);
- plays an **alarm sound** — once for a warning, **three times** for a critical problem;
- **reads the problem aloud** (by default only critical problems).

```bash
DESKTOP_ALERTS="yes"     # yes | no
ALERT_SOUND="yes"        # yes | no
ALERT_VOICE="critical"   # no | critical | all
QUIET_HOURS="23-08"      # no sound and no voice from 23:00 to 08:00 ("" = never quiet)
```

During the **quiet hours** the notification still appears, silently. What happened during the night is **played once in the morning**, at the first check after the quiet hours, as *"During the night: ..."*.

The voice speaks the system language (English or Italian). If the speakers are muted, nothing can be heard: Telegram is there for that.

> The sound only works when a user is logged in to a graphical session — it complements Telegram and healthchecks.io, it does not replace them.

---

## 🤖 Watching your scripts and bots (`aom run`)

Put `aom run` in front of the command of any script, especially the important ones:

```
aom run --name NAME --ping HEALTHCHECKS-URL --minutes MAX -- command ...
```

| Option | What it does |
|---|---|
| `--name` | How it appears in alerts. Its log goes to `~/.local/state/always-on-mint/NAME.log` (kept to the last 5000 lines). |
| `--ping` | A healthchecks.io check **for that script only**. The strongest protection: if the script **does not start** on time (PC off, broken crontab, wrong user...), healthchecks.io notices and writes to you. |
| `--minutes` | If the script hangs, after that many minutes it is stopped and counted as failed. |

It needs no `sudo`. The exit code of your command is returned unchanged. When it fails you get a **Telegram message** with its last lines, a **desktop notification**, the **sound** and the **voice**.

### In the crontab (`crontab -e`)

Before:

```
0 9 * * * /home/me/bots/taxes/venv/bin/python /home/me/bots/taxes/main.py
```

After:

```
0 9 * * * /usr/local/bin/aom run --name taxes --ping https://hc-ping.com/yyyy --minutes 30 -- /home/me/bots/taxes/venv/bin/python /home/me/bots/taxes/main.py
```

On healthchecks.io, create the script's check with **Schedule → Cron**, the same expression (`0 9 * * *`), your time zone, and a grace time of 30–60 minutes.

### As a service that is always running (Telegram bots, servers...)

For a bot that must run all the time, a **systemd service** is better: it **restarts by itself** if it crashes, and starts at boot. For example `/etc/systemd/system/bot-taxes.service`:

```ini
[Unit]
Description=Taxes bot
Wants=network-online.target
After=network-online.target

[Service]
User=me
WorkingDirectory=/home/me/bots/taxes
ExecStart=/home/me/bots/taxes/venv/bin/python main.py
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now bot-taxes
```

If it keeps crashing, the hourly check reports it among the **failed services**.

### Two golden rules for Python bots

- **One virtual environment per bot**: `python3 -m venv venv && venv/bin/pip install -r requirements.txt`. **Never `sudo pip install`**: it mixes your packages with the system's and can break Linux Mint's own tools. The check tells you if there are any.
- **Logs must not grow forever**: if your bot writes its own log, rotate it (`logging.handlers.RotatingFileHandler`).

> For things that really matter (a payment, a deadline), keep a **calendar reminder** too. No automation is worth more than a glance.

---

## 🔧 Updating safely (`aom update`)

Silent automatic updates are turned off by the installer. Once a month, when you are at the PC:

```bash
sudo aom update
```

1. **Checks the PC**: completes any half-finished update, makes sure there is enough space (also in `/boot`).
2. **Takes a Timeshift snapshot**, if Timeshift is configured (recommended, on **another** disk).
3. **Updates** the system.
4. **Verifies** that the newest kernel has its boot files and that the boot menu knows it.
5. **Reboots right away** (it asks first): if something is wrong you find out **now**, while you are there — and you can pick the previous kernel from the boot menu.

The hourly check reminds you after `MAX_DAYS_WITHOUT_UPDATE` days (40 by default).

---

## 🗓️ What happens, and when

| When | What | Command |
|---|---|---|
| Every hour (first one 10 minutes after boot) | Health check, alerts, heartbeat | `aom check` |
| At every start | Message *"I am up again"* (or *"I restarted by myself"*) | `aom boot` |
| Sunday 04:20 | Cleanup | `aom clean` |
| Sunday 04:40 | Backup | `aom backup` |
| Sunday 05:10 (`REBOOT_SCHEDULE`) | Careful reboot | `aom reboot` |
| Once a month, by you | Safe update | `aom update` |

If the PC was off on Sunday morning, cleanup and backup run as soon as it starts. The reboot does not: it waits for the next week.

---

## 🔍 How it works

### The hourly check

| Check | Level |
|---|---|
| Disk over `DISK_CRITICAL` (95%) / over `DISK_WARN` (85%) | ⛔ / ⚠️ |
| Root filesystem mounted **read-only** | ⛔ |
| SMART says the disk is **failing**, or values past the threshold | ⛔ |
| Reallocated / pending sectors, SSD over 90% worn | ⚠️ |
| Disk errors in the kernel log since the last check | ⛔ |
| **Half-finished update** (`dpkg --audit`) | ⛔ |
| Running or newest kernel **without its boot file** (`initrd`) | ⛔ |
| Boot menu that does not know a kernel | ⚠️ |
| Failed system or user services | ⚠️ |
| Memory or swap almost full | ⚠️ |
| No reboot for `MAX_DAYS_WITHOUT_REBOOT` days | ⚠️ |
| No update for `MAX_DAYS_WITHOUT_UPDATE` days | ⚠️ |
| Clock not synchronized | ⚠️ |
| Packages installed with `sudo pip`, huge `~/.xsession-errors` | ℹ️ (report only) |

The report is in `/var/log/always-on-mint/status.txt`; `sudo aom check` prints it.

### The careful weekly reboot

1. Runs the full check.
2. If there is **anything critical** — the very things that could stop the PC from starting again — it **does not reboot**, and sends ⛔ *Weekly reboot CANCELLED* with the reason.
3. If the check itself cannot run, it does not reboot either: *when in doubt, do nothing*.
4. Waits (up to 60 minutes) for the programs listed in `WAIT_FOR_PROCESSES`.
5. Reboots. At the next start, `aom boot` sends *"Weekly reboot done"*.

`sudo aom reboot --dry-run` tells you what it would do right now.

### Alerts without spam

An alert is sent when the **list of problems changes** (a new one, or a warning that becomes critical), then **once a day** while it lasts, and a ✅ when everything is fine again. Numbers are ignored when comparing (the disk going from 86% to 87% is not a new problem).

### What the installer changes on your system

Everything is in separate files, so it can be removed cleanly:

| File | Why |
|---|---|
| `/usr/local/bin/aom`, `/usr/local/lib/always-on-mint/` | The command |
| `/etc/always-on-mint.conf` | Your configuration (never overwritten) |
| `/etc/systemd/system/aom-*.service`, `aom-*.timer` | The scheduled jobs |
| `/etc/systemd/logind.conf.d/50-always-on-mint.conf` + masked `sleep.target`, `suspend.target`... | Never sleep, lid ignored |
| `/etc/systemd/journald.conf.d/50-always-on-mint.conf` | Persistent logs, at most 300 MB / 2 months |
| `/etc/logrotate.d/always-on-mint` | `~/.xsession-errors` at most 20 MB |
| `/etc/sysctl.d/90-always-on-mint.conf` | Reboot 20 s after a kernel panic |
| `/etc/systemd/system.conf.d/50-always-on-mint.conf` | Hardware watchdog (only if the PC has one) |
| `/etc/default/grub.d/50-always-on-mint.cfg` | Boot menu visible for 5 seconds |
| `mintupdate-automation upgrade disable`, `/etc/apt/apt.conf.d/99-always-on-mint-no-unattended` | No silent updates |
| Packages: `smartmontools`, `earlyoom`, `curl`, `logrotate`, `libnotify-bin`, `pulseaudio-utils`, `sound-theme-freedesktop`, `speech-dispatcher`, `espeak-ng` | Disk health, memory, alerts, sound, voice |

---

## ⚙️ Configuration reference

All settings live in `/etc/always-on-mint.conf`, each one explained in the file. Changes apply from the next check; after changing `REBOOT_SCHEDULE`, run `sudo aom schedule`.

| Setting | Default | What it does |
|---|---|---|
| `MACHINE_NAME` | the hostname | Name of the PC in the alerts |
| `MESSAGES_LANGUAGE` | `auto` | `auto`, `en` or `it` |
| `TELEGRAM_TOKEN` | — | The token of your bot |
| `TELEGRAM_CHAT_ID` | — | Your chat id (or a group's, negative) |
| `HEALTHCHECKS_URL` | — | The ping URL of the PC's check |
| `DESKTOP_ALERTS` | `yes` | Desktop notifications |
| `ALERT_SOUND` | `yes` | Alarm sound |
| `ALERT_VOICE` | `critical` | `no`, `critical` or `all` |
| `QUIET_HOURS` | `23-08` | No sound and voice in these hours; `""` = never quiet |
| `REBOOT_SCHEDULE` | `Sun *-*-* 05:10:00` | When the careful reboot happens ([systemd format](https://www.freedesktop.org/software/systemd/man/systemd.time.html#Calendar%20Events)); `off` to disable (not recommended) |
| `WAIT_FOR_PROCESSES` | — | Words in the command line of programs to wait for before rebooting |
| `DISK_WARN` / `DISK_CRITICAL` | `85` / `95` | Disk thresholds, % |
| `MAX_DAYS_WITHOUT_REBOOT` | `10` | Warn if the PC has not rebooted for longer |
| `MAX_DAYS_WITHOUT_UPDATE` | `40` | Reminder to run `aom update` |
| `CLEAN_OLD_KERNELS` | `yes` | Remove old kernels and orphan packages |
| `JOURNAL_MAX_SIZE` | `300M` | Ceiling for system logs |
| `BACKUP_PATHS` | — | Folders to back up, separated by spaces |
| `BACKUP_COPY_TO` | — | A second copy outside the PC (USB stick, external disk) |
| `BACKUP_KEEP` | `4` | How many backups to keep |

---

## 🧰 Commands

| Command | What it does |
|---|---|
| `sudo aom check` | Health report, now |
| `sudo aom status` | Scheduled jobs, last report, alert settings, last backups |
| `sudo aom test-alert` | Test alert on every channel (ignores the quiet hours) |
| `sudo aom update` | Safe update, then reboot |
| `sudo aom clean` | Cleanup, now |
| `sudo aom backup` | Backup, now |
| `sudo aom reboot --dry-run` | Would the weekly reboot happen now? Why? |
| `sudo aom schedule` | Apply a new `REBOOT_SCHEDULE` |
| `aom run ... -- command` | Run a script and get an alert if it fails |
| `aom help`, `aom version` | Help, version |

Logs: `/var/log/always-on-mint/` (`alerts.log`, `reboots.log`, `clean.log`, `backup.log`, `updates.log`, `status.txt`).

---

## 🆘 When the PC does not start

With Always on Mint the **boot menu** appears for 5 seconds at every start. Look at **what you see**:

| What you see | What to do |
|---|---|
| The boot menu, then it hangs or the screen stays black | Restart, choose **Advanced options** → the **previous kernel** (the lower number). If it starts, the new kernel is the problem: run `sudo aom update`. |
| It starts, but the login screen keeps sending you back | Almost always a **full disk**. Press **Ctrl+Alt+F2**, log in, run `df -h`. If `/` is at 100%: `sudo aom clean`, then `sudo reboot`. |
| An `(initramfs)` prompt | The filesystem has errors: `fsck -y /dev/sda2` (or the partition named in the message above), then `reboot`. |
| `grub rescue>` | The boot menu cannot find the system: boot a Linux Mint live USB and use **boot-repair**. |
| Clicking noises, *I/O error* messages, extreme slowness | The disk is dying: **stop** trying. From a live USB, copy your data right away; the backup has your configuration. |
| **Advanced options → Recovery mode** | From the recovery menu: `fsck` (check the disk), `dpkg` (repair broken updates), `clean` (free space), `root` (a terminal). |

From a live USB you can always check the disk: `sudo apt install smartmontools && sudo smartctl -a /dev/sda`.

---

## ♻️ Starting again on a new PC

1. Install Linux Mint.
2. Copy the latest backup (from the USB stick) and unpack it:

   ```bash
   mkdir /tmp/restore
   sudo tar xzf NAME-DATE.tar.gz -C /tmp/restore
   ```

3. **Packages**: `sudo apt install $(cat /tmp/restore/aom-info/packages-installed-by-hand.txt)` (remove from the list any package that no longer exists).
4. **Bots**: copy their folders from `/tmp/restore/home/...` and rebuild their virtual environments.
5. **Crontab**: `crontab /tmp/restore/aom-info/crontab-YOURNAME.txt`.
6. **Services**: copy your `/tmp/restore/etc/systemd/system/bot-*.service` to `/etc/systemd/system/`, then `sudo systemctl daemon-reload && sudo systemctl enable --now bot-...`.
7. **Always on Mint**: `sudo bash install.sh`, then `sudo cp /tmp/restore/etc/always-on-mint.conf /etc/`.

---

## 🌍 Supported languages

| Code | Language |
|---|---|
| `en` | English |
| `it` | Italiano |

With `MESSAGES_LANGUAGE="auto"` the language of your session is used, and for the automatic jobs the system language (`/etc/default/locale`). Every message lives in the code in both languages, side by side (`L "english" "italiano"`): adding a language means adding a column — contributions are welcome.

---

## 🗑️ Uninstall

```bash
sudo bash uninstall.sh          # keeps configuration, backups and logs
sudo bash uninstall.sh --all    # removes those too
```

Linux Mint's automatic updates are not turned back on: if you want them, use the **Update Manager**. Scripts started with `aom run` need `aom run` removed from their command.

---

## ⚠️ Safety notes

- Always on Mint runs as **root**: read what it does first with `bash install.sh --dry-run`. The scripts are plain Bash, meant to be read.
- It changes **system settings** (sleep, logs, boot menu, watchdog, automatic updates), each one in its own file listed above, all removed by `uninstall.sh`.
- The **weekly reboot is real**. If your PC runs something that must never be interrupted, list it in `WAIT_FOR_PROCESSES`, choose a quiet `REBOOT_SCHEDULE`, or set it to `off`.
- **Backups contain secrets** (your configuration, tokens, passwords in `/etc`): they are readable by root only. Keep the USB copy somewhere safe.
- Test it on the PC you care about **while you are around**, for a week or two, before trusting it with something important.
- Disk checks need **SMART**: some USB disks and virtual machines do not provide it (the report tells you).
- It cannot fix a dying power supply or a long power cut. That is what the **healthchecks.io heartbeat** is for: you will know.

---

## 🤝 Contributing

Bug reports, ideas and pull requests are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md). Please report security problems privately, as explained in [SECURITY.md](SECURITY.md).

Released under the [MIT License](LICENSE).
