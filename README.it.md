# 🛡️ Always on Mint

**Always on Mint** è un piccolo **kit di script Bash**, senza dipendenze, che tiene in salute per mesi un **PC con Linux Mint, Ubuntu o Debian sempre acceso**: il vecchio portatile che fa girare i tuoi bot, il mini PC con i tuoi script, il fisso che non dorme mai. **Controlla la macchina ogni ora**, **la pulisce e ne fa il backup ogni settimana**, **la riavvia con prudenza** (e **si rifiuta** quando il PC potrebbe non ripartire), e **ti avvisa quando qualcosa non va**: su **Telegram**, con il "battito" di **healthchecks.io**, e ad alta voce dagli **altoparlanti del portatile**.

<!-- badges -->

> 🇬🇧 **English:** [README.md](README.md)

---

## 🤔 Perché esiste questo progetto

Hai un PC sempre acceso. Fa girare un paio di script: un bot Telegram, uno scraper, qualcosa che paga una bolletta o rinnova una prenotazione. Tutto funziona, quindi te ne dimentichi.

Poi un giorno, dopo 100 giorni o anche più, lo riavvii. E **non parte più**.

Raramente è Linux che "si rompe". Sono cose che **si accumulano in silenzio** mentre il PC è acceso, e vengono fuori tutte insieme al primo riavvio:

| Cosa si accumula | Cosa succede al riavvio |
|---|---|
| Log, cache dei pacchetti, kernel vecchi, `~/.xsession-errors`, snapshot di Timeshift: **il disco si riempie** | il sistema non riesce a scrivere i file di avvio o di login: schermo nero, o un login che ti rimanda indietro |
| **Aggiornamenti installati in sottofondo**, mai provati | il kernel nuovo, installato male (magari a disco pieno), non parte |
| **Errori del disco** che crescono piano piano | all'avvio, il controllo del filesystem li trova tutti insieme |
| Pacchetti Python installati con `sudo pip` | gli strumenti di sistema scritti in Python smettono di funzionare |
| Il PC è andato in **sospensione**, o si è **bloccato** | i tuoi script semplicemente non sono partiti, e nessuno te l'ha detto |

E la cosa peggiore: **nessuno ti avvisa**. Lo scopri quando il bot ha già saltato il suo lavoro.

Always on Mint attacca ognuno di questi punti. Soprattutto, **riavvia una volta alla settimana, con prudenza**: i problemi escono quando sono ancora piccoli, e solo se riavviare è sicuro.

---

## ✨ Cosa fa

- **Controllo ogni ora**: spazio e inode del disco, filesystem in sola lettura, salute del disco (**SMART**), errori del disco nel log del kernel, **aggiornamenti rimasti a metà**, **file di avvio dei kernel**, servizi falliti (anche i tuoi), memoria, orologio, giorni dall'ultimo riavvio e dall'ultimo aggiornamento.
- **Riavvio settimanale prudente**: prima di riavviare fa il controllo completo; se qualcosa potrebbe impedire al PC di ripartire, **non riavvia** e ti avvisa. Aspetta anche che finiscano i tuoi lavori.
- **Avvisi che ti raggiungono**: messaggi **Telegram**, il "battito" su **healthchecks.io** (l'unico modo di sapere che il PC è *morto*) e, sul PC stesso, una **notifica**, un **suono di allarme** e una **voce** che legge il problema.
- **Ore di silenzio**: niente suono né voce di notte; quello che è successo te lo dice la mattina.
- **Niente spam**: un avviso quando nasce un problema, uno al giorno finché resta, e un messaggio quando torna tutto a posto.
- **Pulizia settimanale**: cache dei pacchetti, kernel vecchi (tiene sempre quello in uso e il precedente), pacchetti orfani, log troppo grandi, vecchi rapporti di crash.
- **Backup settimanale**: `/etc`, crontab, servizi utente, l'elenco dei pacchetti installati e le cartelle dei tuoi bot, con una seconda copia facoltativa su chiavetta.
- **Sorveglia i tuoi bot**: `aom run` davanti a qualsiasi script ti dice quando **fallisce**, **si blocca** o **non parte proprio**.
- **Aggiornamenti sicuri**: `aom update` fa un'istantanea, aggiorna, verifica che il kernel nuovo possa partire e riavvia **mentre sei lì**.
- **Non va mai in sospensione**: né col coperchio chiuso, né senza nessuno collegato.
- **Si riavvia da solo** dopo un kernel panic, e tramite il **watchdog hardware** se il sistema si congela del tutto. **earlyoom** chiude il programma più grosso invece di bloccare il PC quando la memoria finisce.
- **Menu di avvio visibile**: 5 secondi a ogni accensione, per scegliere il kernel precedente se quello nuovo non parte.
- **Italiano e inglese**: ogni messaggio segue la lingua del sistema (o quella che scegli tu).
- **Niente di nascosto**: Bash semplice, si legge in pochi minuti, `--dry-run` per l'installatore, un disinstallatore pulito.

---

## 📋 Requisiti

- **Linux Mint** (qualsiasi edizione: Cinnamon, Xfce, MATE), **Ubuntu** o **Debian**: qualsiasi sistema con `apt` e `systemd`.
- Accesso con `sudo`.
- Una connessione a internet per gli avvisi (i controlli funzionano anche offline).
- *Facoltativo:* un account Telegram e un account gratuito su healthchecks.io.

---

## 🚀 Partenza veloce

1. **Scarica** il progetto:

   ```bash
   git clone https://github.com/R0mb0/Always_on_mint.git
   cd Always_on_mint
   ```

2. **Guarda cosa farebbe**, senza toccare niente:

   ```bash
   bash install.sh --dry-run
   ```

3. **Installa**:

   ```bash
   sudo bash install.sh
   ```

   Si può rilanciare quando vuoi (per esempio dopo un `git pull`): non sovrascrive mai la tua configurazione.

4. **Configura** gli avvisi (Telegram e healthchecks.io: vedi le sezioni qui sotto) e le cartelle da salvare:

   ```bash
   sudo nano /etc/always-on-mint.conf
   ```

5. **Prova** gli avvisi:

   ```bash
   sudo aom test-alert
   ```

6. **Controlla** che il riavvio settimanale sarebbe sicuro:

   ```bash
   sudo aom reboot --dry-run
   ```

7. **Riavvia una volta**, per attivare tutto (coperchio, watchdog).

Da qui in poi il PC si sorveglia da solo. Una volta al mese, quando sei davanti al PC, lancia `sudo aom update`.

---

## 📲 Avvisi su Telegram (passo passo)

Telegram è il canale più utile: un messaggio sul telefono, ovunque tu sia, pochi secondi dopo che succede qualcosa. Ti servono un **bot** (un minuto, gratis) e il tuo **chat id**.

### 1. Crea il tuo bot

1. Su Telegram cerca **@BotFather** (quello ufficiale, con la spunta blu) e apri la chat.
2. Scrivi `/newbot`.
3. Scegli un **nome** (quello che vuoi, per esempio `Avvisi del mio PC`) e un **username** che finisca con `bot` (per esempio `avvisi_mio_pc_bot`).
4. BotFather ti risponde con un **token**, una cosa così:

   ```
   123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw
   ```

   Quel token è la **password** del tuo bot: tienilo per te.

### 2. Trova il tuo chat id

1. Apri la chat con **il tuo bot nuovo** (BotFather ti dà il link `t.me/tuo_bot`) e premi **Avvia**, oppure mandagli un messaggio qualsiasi. *Questo passo è importante: un bot non può scriverti finché non gli scrivi tu per primo.*
2. Nel browser apri questo indirizzo, mettendo il tuo token al posto di `<TOKEN>`:

   ```
   https://api.telegram.org/bot<TOKEN>/getUpdates
   ```

3. Cerca `"chat":{"id":` nella pagina. Il numero che segue è il tuo **chat id**:

   ```json
   "chat":{"id":123456789,"first_name":"Francesco","type":"private"}
   ```

   Se la pagina mostra solo `{"ok":true,"result":[]}`, manda un altro messaggio al bot e ricarica.

### 3. Mettili nella configurazione

```bash
sudo nano /etc/always-on-mint.conf
```

```bash
TELEGRAM_TOKEN="123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw"
TELEGRAM_CHAT_ID="123456789"
```

Salva con **Ctrl+O** e **Invio**, esci con **Ctrl+X**.

### 4. Prova

```bash
sudo aom test-alert
```

In pochi secondi ti arriva: *"🧪 Avviso di prova da Always on Mint. Se leggi questo, Telegram funziona!"*

### Cosa riceverai

| Quando | Messaggio |
|---|---|
| Nasce un problema (e una volta al giorno finché resta) | ⚠️ *Qualcosa non va* oppure ⛔ *PROBLEMA*, con l'elenco |
| Torna tutto a posto | ✅ *Tutto di nuovo a posto* |
| Il riavvio settimanale viene annullato perché non è sicuro | ⛔ *Riavvio settimanale ANNULLATO*, con il motivo |
| Il PC riparte dopo il riavvio settimanale / dopo un aggiornamento / dopo che l'hai spento tu | 🔄 / 🔌 *Sono di nuovo acceso* |
| Il PC si è riavviato **da solo** (corrente, blocco, crash) | ⚠️ *Mi sono riavviato DA SOLO* |
| Uno script lanciato con `aom run` fallisce o si blocca | ⛔ *tasse non è andato a buon fine*, con le ultime righe |
| Il backup non si è potuto fare o copiare | ⛔ / ⚠️ *Backup* |

### Consigli

- **Più PC, un solo bot**: usa lo stesso token e lo stesso chat id su tutti. Ogni messaggio inizia con il nome del PC (`MACHINE_NAME`).
- **Un gruppo invece della chat privata**: aggiungi il bot a un gruppo, scrivi qualcosa nel gruppo e usa l'id del gruppo che trovi in `getUpdates`: è un numero **negativo** (per esempio `-1001234567890`).
- **Hai già un bot** per i tuoi progetti: puoi usare il suo token. Always on Mint i messaggi li *manda* soltanto, non li legge mai.

### Se qualcosa non va

| Cosa succede | Perché, e cosa fare |
|---|---|
| `test-alert` dice ❌ *non mandato* | Token o chat id sbagliati. Riapri l'indirizzo `getUpdates`: se dice `Unauthorized`, il token è sbagliato. |
| Non arriva niente, nessun errore | Non hai mai premuto **Avvia** nella chat con il tuo bot. Fallo e riprova. |
| `getUpdates` è sempre vuoto | Un altro programma sta leggendo i messaggi del bot (un webhook). Usa un bot nuovo solo per gli avvisi. |
| Funzionava, poi ha smesso | Il token è stato revocato da BotFather (`/revoke`), oppure il PC non ha internet: `sudo aom check` funziona anche offline e ti mostra il resto. |

---

## 💓 healthchecks.io: sapere che il PC è morto

Un PC spento, bloccato o che non si avvia **non può mandarti niente**. healthchecks.io funziona al contrario: il PC dice *"ci sono"* ogni ora e, quando **smette**, è healthchecks.io a scriverti.

1. Crea un account gratuito su [healthchecks.io](https://healthchecks.io).
2. **Add Check** → dagli un nome (per esempio `PC dei bot`).
3. Imposta **Period: 1 hour** e **Grace: 1 hour**.
4. Copia il **ping URL** (`https://hc-ping.com/xxxxxxxx-xxxx-...`) nella configurazione:

   ```bash
   HEALTHCHECKS_URL="https://hc-ping.com/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   ```

5. In **Integrations** scegli come essere avvisato: la mail è attiva di serie, e healthchecks.io sa scrivere anche su **Telegram**.
6. `sudo aom test-alert`: il check diventa **verde**.

Quando il controllo trova un problema **critico**, il battito viene mandato come **fallimento**, così healthchecks.io segna il PC come *giù* anche se è ancora acceso.

---

## 🔊 Avvisi sul PC stesso: notifica, suono, voce

Linux Mint sta spesso sui **portatili**, e i portatili hanno gli **altoparlanti**. Se qualcuno è collegato, Always on Mint:

- mostra una **notifica** sullo schermo (urgente per i problemi critici);
- fa un **suono di allarme**: una volta per un avviso, **tre volte** per un problema critico;
- **legge il problema ad alta voce** (di serie solo per i problemi critici).

```bash
DESKTOP_ALERTS="yes"     # yes | no
ALERT_SOUND="yes"        # yes | no
ALERT_VOICE="critical"   # no | critical | all
QUIET_HOURS="23-08"      # niente suono né voce dalle 23 alle 8 ("" = mai silenzio)
```

Durante le **ore di silenzio** la notifica compare lo stesso, senza rumore. Quello che è successo di notte viene **suonato una volta al mattino**, al primo controllo dopo le ore di silenzio, come *"Durante la notte: ..."*.

La voce parla la lingua del sistema (italiano o inglese). Se gli altoparlanti sono muti non si sente niente: per quello c'è Telegram.

> Il suono funziona solo quando qualcuno è collegato a una sessione grafica: completa Telegram e healthchecks.io, non li sostituisce.

---

## 🤖 Sorvegliare i tuoi script e bot (`aom run`)

Metti `aom run` davanti al comando di qualsiasi script, soprattutto di quelli importanti:

```
aom run --name NOME --ping URL-HEALTHCHECKS --minutes MAX -- comando ...
```

| Opzione | Cosa fa |
|---|---|
| `--name` | Come compare negli avvisi. Il suo log va in `~/.local/state/always-on-mint/NOME.log` (tenuto alle ultime 5000 righe). |
| `--ping` | Un check di healthchecks.io **solo per quello script**. È la protezione più forte: se lo script **non parte** all'ora giusta (PC spento, crontab rotto, utente sbagliato...), healthchecks.io se ne accorge e ti scrive. |
| `--minutes` | Se lo script si blocca, dopo tanti minuti viene fermato e considerato fallito. |

Non serve `sudo`. Il codice d'uscita del tuo comando viene restituito uguale. Quando fallisce ricevi un **messaggio Telegram** con le ultime righe, una **notifica**, il **suono** e la **voce**.

### Nel crontab (`crontab -e`)

Prima:

```
0 9 * * * /home/io/bot/tasse/venv/bin/python /home/io/bot/tasse/main.py
```

Dopo:

```
0 9 * * * /usr/local/bin/aom run --name tasse --ping https://hc-ping.com/yyyy --minutes 30 -- /home/io/bot/tasse/venv/bin/python /home/io/bot/tasse/main.py
```

Su healthchecks.io crea il check dello script con **Schedule → Cron**, la stessa espressione (`0 9 * * *`), il tuo fuso orario e una tolleranza di 30–60 minuti.

### Come servizio sempre acceso (bot Telegram, server...)

Per un bot che deve girare sempre è meglio un **servizio systemd**: **riparte da solo** se cade, e parte all'accensione. Per esempio `/etc/systemd/system/bot-tasse.service`:

```ini
[Unit]
Description=Bot delle tasse
Wants=network-online.target
After=network-online.target

[Service]
User=io
WorkingDirectory=/home/io/bot/tasse
ExecStart=/home/io/bot/tasse/venv/bin/python main.py
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now bot-tasse
```

Se continua a cadere, il controllo orario lo segnala tra i **servizi falliti**.

### Due regole d'oro per i bot in Python

- **Un ambiente virtuale per ogni bot**: `python3 -m venv venv && venv/bin/pip install -r requirements.txt`. **Mai `sudo pip install`**: mescola i tuoi pacchetti con quelli del sistema e può rompere gli strumenti di Linux Mint. Il controllo ti dice se ce ne sono.
- **I log non devono crescere all'infinito**: se il tuo bot scrive un suo log, fallo ruotare (`logging.handlers.RotatingFileHandler`).

> Per le cose che contano davvero (un pagamento, una scadenza) tieni anche un **promemoria in calendario**. Nessun automatismo vale un'occhiata.

---

## 🔧 Aggiornare in sicurezza (`aom update`)

L'installatore spegne gli aggiornamenti automatici silenziosi. Una volta al mese, quando sei davanti al PC:

```bash
sudo aom update
```

1. **Controlla il PC**: completa un eventuale aggiornamento rimasto a metà, verifica che ci sia spazio (anche in `/boot`).
2. **Fa un'istantanea con Timeshift**, se Timeshift è configurato (consigliato, su un **altro** disco).
3. **Aggiorna** il sistema.
4. **Verifica** che il kernel più recente abbia i suoi file di avvio e che il menu di avvio lo conosca.
5. **Riavvia subito** (prima te lo chiede): se qualcosa non va lo scopri **adesso**, mentre sei lì, e puoi scegliere il kernel precedente dal menu di avvio.

Il controllo orario te lo ricorda dopo `MAX_DAYS_WITHOUT_UPDATE` giorni (40 di serie).

---

## 🗓️ Cosa succede, e quando

| Quando | Cosa | Comando |
|---|---|---|
| Ogni ora (il primo 10 minuti dopo l'accensione) | Controllo, avvisi, battito | `aom check` |
| A ogni accensione | Messaggio *"Sono di nuovo acceso"* (o *"Mi sono riavviato da solo"*) | `aom boot` |
| Domenica 04:20 | Pulizia | `aom clean` |
| Domenica 04:40 | Backup | `aom backup` |
| Domenica 05:10 (`REBOOT_SCHEDULE`) | Riavvio prudente | `aom reboot` |
| Una volta al mese, da te | Aggiornamento sicuro | `aom update` |

Se domenica mattina il PC era spento, pulizia e backup partono appena lo accendi. Il riavvio no: aspetta la settimana dopo.

---

## 🔍 Come funziona

### Il controllo orario

| Controllo | Livello |
|---|---|
| Disco oltre `DISK_CRITICAL` (95%) / oltre `DISK_WARN` (85%) | ⛔ / ⚠️ |
| Filesystem principale in **sola lettura** | ⛔ |
| SMART dice che il disco **si sta guastando**, o valori oltre la soglia | ⛔ |
| Settori riallocati o in attesa, SSD consumato oltre il 90% | ⚠️ |
| Errori del disco nel log del kernel dall'ultimo controllo | ⛔ |
| **Aggiornamento rimasto a metà** (`dpkg --audit`) | ⛔ |
| Kernel in uso o più recente **senza il suo file di avvio** (`initrd`) | ⛔ |
| Menu di avvio che non conosce un kernel | ⚠️ |
| Servizi di sistema o dell'utente falliti | ⚠️ |
| Memoria o swap quasi piene | ⚠️ |
| Nessun riavvio da `MAX_DAYS_WITHOUT_REBOOT` giorni | ⚠️ |
| Nessun aggiornamento da `MAX_DAYS_WITHOUT_UPDATE` giorni | ⚠️ |
| Orologio non sincronizzato | ⚠️ |
| Pacchetti installati con `sudo pip`, `~/.xsession-errors` enorme | ℹ️ (solo nel rapporto) |

Il rapporto sta in `/var/log/always-on-mint/status.txt`; `sudo aom check` lo stampa.

### Il riavvio settimanale prudente

1. Fa il controllo completo.
2. Se c'è **qualcosa di critico**, cioè proprio le cose che potrebbero impedire al PC di ripartire, **non riavvia** e manda ⛔ *Riavvio settimanale ANNULLATO* con il motivo.
3. Se il controllo stesso non riesce a girare, non riavvia nemmeno: *nel dubbio, non fare niente*.
4. Aspetta (al massimo 60 minuti) i programmi elencati in `WAIT_FOR_PROCESSES`.
5. Riavvia. Alla riaccensione, `aom boot` manda *"Riavvio settimanale fatto"*.

`sudo aom reboot --dry-run` ti dice cosa farebbe in questo momento.

### Avvisi senza spam

Un avviso parte quando **l'elenco dei problemi cambia** (uno nuovo, o un avviso che diventa critico), poi **una volta al giorno** finché resta, e arriva un ✅ quando torna tutto a posto. Nel confronto i numeri non contano (il disco che passa dall'86% all'87% non è un problema nuovo).

### Cosa cambia l'installatore nel tuo sistema

Tutto sta in file separati, così si toglie in modo pulito:

| File | Perché |
|---|---|
| `/usr/local/bin/aom`, `/usr/local/lib/always-on-mint/` | Il comando |
| `/etc/always-on-mint.conf` | La tua configurazione (mai sovrascritta) |
| `/etc/systemd/system/aom-*.service`, `aom-*.timer` | I lavori programmati |
| `/etc/systemd/logind.conf.d/50-always-on-mint.conf` + `sleep.target`, `suspend.target`... disattivati | Mai in sospensione, coperchio ignorato |
| `/etc/systemd/journald.conf.d/50-always-on-mint.conf` | Log persistenti, al massimo 300 MB / 2 mesi |
| `/etc/logrotate.d/always-on-mint` | `~/.xsession-errors` al massimo 20 MB |
| `/etc/sysctl.d/90-always-on-mint.conf` | Riavvio 20 secondi dopo un kernel panic |
| `/etc/systemd/system.conf.d/50-always-on-mint.conf` | Watchdog hardware (solo se il PC ce l'ha) |
| `/etc/default/grub.d/50-always-on-mint.cfg` | Menu di avvio visibile per 5 secondi |
| `mintupdate-automation upgrade disable`, `/etc/apt/apt.conf.d/99-always-on-mint-no-unattended` | Niente aggiornamenti silenziosi |
| Pacchetti: `smartmontools`, `earlyoom`, `curl`, `logrotate`, `libnotify-bin`, `pulseaudio-utils`, `sound-theme-freedesktop`, `speech-dispatcher`, `espeak-ng` | Salute del disco, memoria, avvisi, suono, voce |

---

## ⚙️ Tutte le impostazioni

Stanno tutte in `/etc/always-on-mint.conf`, ognuna spiegata nel file. Le modifiche valgono dal controllo successivo; dopo aver cambiato `REBOOT_SCHEDULE`, lancia `sudo aom schedule`.

| Impostazione | Predefinito | Cosa fa |
|---|---|---|
| `MACHINE_NAME` | il nome del PC | Nome del PC negli avvisi |
| `MESSAGES_LANGUAGE` | `auto` | `auto`, `en` o `it` |
| `TELEGRAM_TOKEN` | — | Il token del tuo bot |
| `TELEGRAM_CHAT_ID` | — | Il tuo chat id (o quello di un gruppo, negativo) |
| `HEALTHCHECKS_URL` | — | Il ping URL del check del PC |
| `DESKTOP_ALERTS` | `yes` | Notifiche sullo schermo |
| `ALERT_SOUND` | `yes` | Suono di allarme |
| `ALERT_VOICE` | `critical` | `no`, `critical` o `all` |
| `QUIET_HOURS` | `23-08` | Niente suono né voce in queste ore; `""` = mai silenzio |
| `REBOOT_SCHEDULE` | `Sun *-*-* 05:10:00` | Quando fare il riavvio prudente ([formato systemd](https://www.freedesktop.org/software/systemd/man/systemd.time.html#Calendar%20Events)); `off` per disattivarlo (sconsigliato) |
| `WAIT_FOR_PROCESSES` | — | Parole nella riga di comando dei programmi da aspettare prima di riavviare |
| `DISK_WARN` / `DISK_CRITICAL` | `85` / `95` | Soglie del disco, in % |
| `MAX_DAYS_WITHOUT_REBOOT` | `10` | Avvisa se il PC non si riavvia da più giorni |
| `MAX_DAYS_WITHOUT_UPDATE` | `40` | Promemoria per `aom update` |
| `CLEAN_OLD_KERNELS` | `yes` | Toglie i kernel vecchi e i pacchetti orfani |
| `JOURNAL_MAX_SIZE` | `300M` | Tetto per i log di sistema |
| `BACKUP_PATHS` | — | Cartelle da salvare, separate da spazi |
| `BACKUP_COPY_TO` | — | Una seconda copia fuori dal PC (chiavetta, disco esterno) |
| `BACKUP_KEEP` | `4` | Quanti backup tenere |

---

## 🧰 Comandi

| Comando | Cosa fa |
|---|---|
| `sudo aom check` | Rapporto sulla salute, adesso |
| `sudo aom status` | Lavori programmati, ultimo rapporto, impostazioni degli avvisi, ultimi backup |
| `sudo aom test-alert` | Avviso di prova su tutti i canali (ignora le ore di silenzio) |
| `sudo aom update` | Aggiornamento sicuro, poi riavvio |
| `sudo aom clean` | Pulizia, adesso |
| `sudo aom backup` | Backup, adesso |
| `sudo aom reboot --dry-run` | Il riavvio settimanale si farebbe adesso? Perché? |
| `sudo aom schedule` | Applica un nuovo `REBOOT_SCHEDULE` |
| `aom run ... -- comando` | Fa girare uno script e ti avvisa se fallisce |
| `aom help`, `aom version` | Aiuto, versione |

Log: `/var/log/always-on-mint/` (`alerts.log`, `reboots.log`, `clean.log`, `backup.log`, `updates.log`, `status.txt`).

---

## 🆘 Quando il PC non parte

Con Always on Mint il **menu di avvio** compare per 5 secondi a ogni accensione. Guarda **cosa vedi**:

| Cosa vedi | Cosa fare |
|---|---|
| Il menu di avvio, poi si blocca o lo schermo resta nero | Riavvia, scegli **Opzioni avanzate** → il **kernel precedente** (quello con il numero più basso). Se parte, il problema è il kernel nuovo: lancia `sudo aom update`. |
| Parte, ma il login continua a rimandarti indietro | Quasi sempre **disco pieno**. Premi **Ctrl+Alt+F2**, entra, lancia `df -h`. Se `/` è al 100%: `sudo aom clean`, poi `sudo reboot`. |
| Un prompt `(initramfs)` | Il filesystem ha errori: `fsck -y /dev/sda2` (o la partizione indicata nel messaggio sopra), poi `reboot`. |
| `grub rescue>` | Il menu di avvio non trova il sistema: avvia una chiavetta live di Linux Mint e usa **boot-repair**. |
| Rumori dal disco, messaggi *I/O error*, lentezza estrema | Il disco sta morendo: **smetti** di provare. Da una chiavetta live copia subito i tuoi dati; il backup ha la tua configurazione. |
| **Opzioni avanzate → Recovery mode** | Dal menu di recupero: `fsck` (controlla il disco), `dpkg` (ripara gli aggiornamenti rotti), `clean` (libera spazio), `root` (un terminale). |

Da una chiavetta live puoi sempre controllare il disco: `sudo apt install smartmontools && sudo smartctl -a /dev/sda`.

---

## ♻️ Ripartire su un PC nuovo

1. Installa Linux Mint.
2. Copia l'ultimo backup (dalla chiavetta) e aprilo:

   ```bash
   mkdir /tmp/ripristino
   sudo tar xzf NOME-DATA.tar.gz -C /tmp/ripristino
   ```

3. **Pacchetti**: `sudo apt install $(cat /tmp/ripristino/aom-info/packages-installed-by-hand.txt)` (togli dall'elenco i pacchetti che non esistono più).
4. **Bot**: copia le loro cartelle da `/tmp/ripristino/home/...` e ricrea i loro ambienti virtuali.
5. **Crontab**: `crontab /tmp/ripristino/aom-info/crontab-TUONOME.txt`.
6. **Servizi**: copia i tuoi `/tmp/ripristino/etc/systemd/system/bot-*.service` in `/etc/systemd/system/`, poi `sudo systemctl daemon-reload && sudo systemctl enable --now bot-...`.
7. **Always on Mint**: `sudo bash install.sh`, poi `sudo cp /tmp/ripristino/etc/always-on-mint.conf /etc/`.

---

## 🌍 Lingue supportate

| Codice | Lingua |
|---|---|
| `en` | English |
| `it` | Italiano |

Con `MESSAGES_LANGUAGE="auto"` si usa la lingua della tua sessione e, per i lavori automatici, quella del sistema (`/etc/default/locale`). Ogni messaggio sta nel codice in entrambe le lingue, una accanto all'altra (`L "english" "italiano"`): aggiungere una lingua vuol dire aggiungere una colonna. I contributi sono benvenuti.

---

## 🗑️ Disinstallare

```bash
sudo bash uninstall.sh          # tiene configurazione, backup e log
sudo bash uninstall.sh --all    # toglie anche quelli
```

Gli aggiornamenti automatici di Linux Mint non vengono riattivati: se li vuoi, usa il **Gestore aggiornamenti**. Dagli script lanciati con `aom run` va tolto `aom run` dal loro comando.

---

## ⚠️ Note di sicurezza

- Always on Mint gira come **root**: guarda prima cosa fa con `bash install.sh --dry-run`. Gli script sono Bash semplice, fatti per essere letti.
- Cambia **impostazioni di sistema** (sospensione, log, menu di avvio, watchdog, aggiornamenti automatici), ognuna in un suo file elencato sopra, tutte tolte da `uninstall.sh`.
- Il **riavvio settimanale è vero**. Se il tuo PC fa girare qualcosa che non deve mai essere interrotto, mettilo in `WAIT_FOR_PROCESSES`, scegli un `REBOOT_SCHEDULE` tranquillo, oppure mettilo a `off`.
- **I backup contengono segreti** (la tua configurazione, token, password in `/etc`): sono leggibili solo da root. Tieni la copia sulla chiavetta in un posto sicuro.
- Provalo sul PC a cui tieni **mentre sei nei paraggi**, per una o due settimane, prima di affidargli qualcosa di importante.
- I controlli del disco hanno bisogno di **SMART**: alcuni dischi USB e le macchine virtuali non lo forniscono (il rapporto te lo dice).
- Non può aggiustare un alimentatore che muore o un lungo blackout. Per questo c'è il **battito su healthchecks.io**: almeno lo saprai.

---

## 🤝 Contribuire

Segnalazioni, idee e pull request sono benvenute: vedi [CONTRIBUTING.md](CONTRIBUTING.md). I problemi di sicurezza vanno segnalati in privato, come spiegato in [SECURITY.md](SECURITY.md).

Rilasciato con [licenza MIT](LICENSE).
