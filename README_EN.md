<div align="center">

# 💸 Arizona Payday Clean

### A MoonLoader script for automatic Payday, income, and rank payback tracking on Arizona RP

[![Lua](https://img.shields.io/badge/Lua-MoonLoader-2C2D72?style=for-the-badge&logo=lua&logoColor=white)](#)
[![Version](https://img.shields.io/badge/version-2.0.25-F59E0B?style=for-the-badge)](#)
[![License](https://img.shields.io/badge/license-free-22C55E?style=for-the-badge)](#)
[![Author](https://img.shields.io/badge/author-Artty-8B5CF6?style=for-the-badge)](#)

[Русский](README.md) · **English**

</div>

> [!NOTE]
> Some of the most useful projects do not begin with the desire to build something huge. They begin with the desire to stop repeating the same task every day.

---

## 📌 About the project

**Arizona Payday Clean** is a free MoonLoader script for Arizona RP that:

- automatically reads Payday data;
- keeps total statistics and a CSV history;
- calculates the payback of a purchased organization rank;
- tracks bank, deposit, AZ Coins, and AZ Coin tickets;
- detects the salary multiplier;
- sends reports and responds to Telegram bot commands;
- restores statistics from backups;
- checks GitHub Releases for updates safely;
- keeps working while GTA is minimized;
- reduces background CPU usage and shuts down correctly with the game.

| Parameter | Value |
|---|---|
| **Author** | Artty |
| **Version** | 2.0.25 |
| **Platform** | MoonLoader / SA:MP / Arizona RP |
| **Distribution** | Free |
| **Main file** | `ArizonaPaydayClean.lua` |
| **Configuration** | `moonloader/config/ArizonaPaydayClean.ini` |
| **History** | `moonloader/config/ArizonaPaydayHistory.csv` |
| **Lua file encoding** | CP1251 |

---

<details open>
<summary><strong>👤 A note from the author</strong></summary>

<br>

Hello.

This project was never intended to be a “perfect” MoonLoader script with complex animations or hundreds of settings.

It was originally created for one person — me.

I wanted the script to do its job reliably: track Payday, preserve the data, and require as little attention as possible. Functionality matters more here than visual effects.

The repository is published for free as an example of my approach to automation, Telegram integrations, and practical problem solving.

</details>

---

## 🎯 Why this project exists

I spend much less time in the game than I used to. There is work, family, training, and everyday life.

My gameplay often looks like this:

```text
Buy a rank → start the game → minimize the window → leave the character AFK
```

I wanted to know:

- how much had already been earned;
- whether the rank had paid for itself;
- how much remained until full payback;
- which salary multiplier was active;
- how much deposit income was received;
- how many AZ Coins and tickets were received;
- what happened in the game without opening its window.

That is how **Arizona Payday Clean** appeared.

---

## ✨ Features

<table>
<tr>
<td width="50%" valign="top">

### 📊 Statistics

- automatic Payday detection;
- bank and deposit balances;
- salary from the latest Payday;
- deposit income;
- AZ Coins and AZ Coin tickets;
- total Payday count;
- total income;
- current session statistics;
- history in `ArizonaPaydayHistory.csv`;
- duplicate protection;
- recovery from backups.

</td>
<td width="50%" valign="top">

### 📈 Rank payback

- purchased rank number and price;
- base x1 salary;
- automatic multiplier detection;
- optional deposit income accounting;
- repaid and remaining amounts;
- remaining Payday count;
- estimated payback time;
- compact progress overlay.

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🖥 Interface

- `mimgui` main window;
- compact mini overlay;
- statistics, rank, Telegram, analytics, and update tabs;
- persistent settings;
- text-based inputs for large in-game values;
- minimized-game operation;
- adaptive background loop frequency.

</td>
<td width="50%" valign="top">

### 📬 Telegram

- automatic report after Payday;
- test message;
- notification toggle;
- `/status`, `/stats`, `/today`, `/rank`, `/history`, and other commands;
- access limited to the saved `chat_id`;
- asynchronous request queue;
- time-limited polling;
- stale callback protection;
- no `curl.exe`, PowerShell, CMD, or other external processes.

</td>
</tr>
</table>

---

## 🚑 What is new in version 2.0.25

Version **2.0.25** originally focused on two issues: excessive background load and GTA freezing when leaving through `/q`. The current build also includes a targeted financial-parser hotfix.

### Hotfix: protection against fake chat lines

- player messages in the `Nick_Name[ID]: text` format are rejected before the financial parser runs;
- VIP, regular, family, and other player chats can no longer imitate bank, deposit, AZ Coins, salary, or ticket lines;
- a built-in test covers the VIP-chat line `Баланс на донат-счёте: 861958 AZ (+105 AZ)`;
- genuine system Payday lines continue to use the existing parser logic;
- Telegram, CSV history, INI data, rank payback, the interface, and `/q` shutdown behavior were not changed by this hotfix.

### Previously fixed in 2.0.25

- the background service loop now runs less frequently:
  - approximately **25 ms** while the main window is open;
  - approximately **100 ms** while GTA is active;
  - approximately **500 ms** while GTA is minimized;
- Telegram `getUpdates` no longer holds a 20-second request;
- Telegram polling timeout was reduced to **5 seconds**;
- the default interval between Telegram checks was increased to **10 seconds**;
- a unified shutdown state was added;
- when `/q` is used, MoonLoader exits, or the script is terminated:
  - no new Telegram requests are created;
  - the Telegram queue is cleared;
  - stale callbacks are ignored;
  - the updater is stopped;
  - player controls are unlocked;
  - settings are saved once;
- duplicate configuration saving during shutdown was removed;
- the interface and background handlers stop after shutdown begins;
- Payday calculations, history, Telegram reports, and rank payback logic remain unchanged.

> [!IMPORTANT]
> Telegram bot commands may now arrive with a delay of approximately 15 seconds. This is intentional and reduces background load while making GTA shutdown safer.

> [!NOTE]
> MoonLoader cannot forcibly cancel every download that has already started. The script marks such a request as stale, does not start another one, and ignores its callback after shutdown begins.

---

## 🕘 Previous version highlights

<details>
<summary><strong>Version 2.0.21 — Payday parser</strong></summary>

<br>

- fixed real bank and deposit lines containing formatted values;
- parser no longer depends on the exact `$` position or spacing;
- added support for `[HH:MM:SS]` prefixes;
- fixed the total salary line;
- improved AZ Coin ticket recognition;
- unknown values are no longer replaced with old data in Telegram;
- a partial report is not created from one unrelated line.

</details>

<details>
<summary><strong>Versions 2.0.19–2.0.20 — tickets, duplicates, and background work</strong></summary>

<br>

- strict parsing of ticket gain after `+`;
- ticket balance is read from `(N pcs.)`;
- AZ Coins are not mixed with tickets;
- Chat, GameText, and TextDraw notifications are merged;
- late income values are appended to the latest Payday;
- a single bank line does not create an empty Payday;
- adaptive background delay was introduced;
- mini-overlay calculations are cached.

</details>

---

## 📱 Telegram report contents

A Payday notification may include:

```text
💰 Salary
⚡ Detected multiplier
🏦 Deposit income
📊 Total Payday income
💳 Current bank balance
🏧 Current deposit balance
🪙 AZ Coins balance
🎟 Received AZ Coin tickets
📈 Rank payback progress
⏳ Remaining amount and Payday count
🕒 Time of the latest server line
```

---

## 🚀 Installation

### Requirements

- GTA San Andreas;
- SA:MP or a compatible Arizona RP build;
- MoonLoader;
- `mimgui`;
- `lib.samp.events`;
- `inicfg`;
- standard MoonLoader libraries.

### Install or update

1. Close GTA completely.
2. Download `ArizonaPaydayClean.lua` from **Releases**.
3. Make sure there is no second copy of the script in the `moonloader` directory.
4. Replace the previous file:

```text
moonloader/ArizonaPaydayClean.lua
```

5. Do not delete:

```text
moonloader/config/ArizonaPaydayClean.ini
moonloader/config/ArizonaPaydayHistory.csv
```

6. Start the game.
7. Enter:

```text
/payday
```

> [!CAUTION]
> Two copies of the script may process the same Payday, duplicate Telegram reports, and increase CPU usage.

---

## ⌨️ In-game commands

| Command | Purpose |
|---|---|
| `/payday` | Open or close the main window |
| `/paycalc` | Alternative main window command |
| `/paystats` | Show current session statistics |
| `/payhistory` | Show recent Payday records |
| `/payrecover` | Recover data from backups and CSV |
| `/paydebug` | Toggle the diagnostic log |
| `/paywatch` | Toggle missed-Payday monitoring |
| `/paymini` | Show or hide the mini overlay |
| `/paymini on` / `/paymini off` | Set the mini-overlay state explicitly |
| `/paytg TOKEN CHAT_ID` | Save the Telegram token and chat ID |
| `/paytgtest` | Send a test report |
| `/paytgon` | Enable Telegram notifications |
| `/paytgoff` | Disable Telegram notifications |
| `/paybot` | Enable or disable Telegram bot commands |
| `/paytgcommands` | Refresh the Telegram command menu |
| `/payupdate` | Check for and install an update |
| `/payupdate rollback` | Restore the previous Lua version |

### Telegram setup example

```text
/paytg 1234567890:AAExampleBotTokenExample 123456789
```

A group or channel `chat_id` may be negative:

```text
/paytg 1234567890:AAExampleBotTokenExample -1001234567890
```

> [!CAUTION]
> Never publish a real bot token in Issues, screenshots, logs, or a public repository.

---

## 🤖 Telegram bot commands

| Command | Purpose |
|---|---|
| `/start` / `/help` | Help |
| `/status` / `/ping` | Game, Payday, and server activity status |
| `/stats` | Total statistics |
| `/today` | Statistics for the current date |
| `/rank` | Rank payback |
| `/history N` | Recent Payday records |
| `/watch` | Missed-Payday monitor status |
| `/settings` | Current toggles |
| `/version` | Installed version |

Remote character control through Telegram is not implemented.

The bot token and `chat_id` are not embedded in the public Lua file. They are stored locally in:

```text
moonloader/config/ArizonaPaydayClean.ini
```

Recommended `.gitignore`:

```gitignore
**/ArizonaPaydayClean.ini
**/ArizonaPaydayTelegramResponse_*.json
**/ArizonaPaydayTelegramUpdates_*.json
moonloader.log
```

---

## 🧩 How it works

```mermaid
flowchart TD
    A[Server sends Payday and ticket lines] --> B[Script reads bank, deposit, salary, AZ Coins, and tickets]
    B --> C[Short collection window for related lines]
    C --> D[Duplicate and late-income checks]
    D --> E[Update total and session statistics]
    E --> F[Recalculate rank payback]
    F --> G[Atomic INI and CSV save]
    G --> H{Telegram enabled?}
    H -- No --> I[Wait for the next event]
    H -- Yes --> J[Asynchronous MoonLoader request]
    J --> I
```

---

## 🛠 Technical decisions

### No external processes

The script does not launch:

- `curl.exe`;
- PowerShell;
- CMD;
- BAT files;
- `CreateProcessA`.

Telegram and update downloads use MoonLoader's asynchronous downloader:

```lua
downloadUrlToFile(...)
```

### Duplicate protection

The server may send related information through Chat, GameText, and TextDraw. The script combines those events within a short collection window, checks signatures, and appends late values to the existing Payday record.

### Large values

Values that may exceed a standard 32-bit `InputInt` range are entered as text and then converted safely to Lua numbers.

### Safe shutdown

Version 2.0.25 handles multiple MoonLoader termination events. Once shutdown begins, the script closes the menu, stops background work, unlocks controls, and saves the current state without duplicate writes.

---

## 🐞 Reporting a problem

The script was primarily created for personal use, so compatibility with every MoonLoader build or third-party script cannot be guaranteed.

When opening an **Issue**, include:

- what happened;
- which action triggered it;
- whether GTA was minimized;
- whether anti-AFK was enabled;
- whether Telegram notifications and bot commands were enabled;
- which other MoonLoader scripts were running;
- the latest lines from `moonloader.log`;
- an example of a server message parsed incorrectly.

MoonLoader log:

```text
moonloader/moonloader.log
```

When `gta_sa.exe` freezes or closes without a Lua error:

```text
Windows Event Viewer → Windows Logs → Application
```

---

## 🔐 Security

Before publishing files, make sure you are not uploading:

- `ArizonaPaydayClean.ini`;
- `moonloader.log`;
- screenshots containing a bot token;
- temporary Telegram JSON responses;
- the entire `moonloader/config` directory.

The public `ArizonaPaydayClean.lua` contains no bot token or `chat_id`.

---

## 📦 GitHub Release v2.0.25

```text
Tag: v2.0.25
Title: Arizona Payday Clean v2.0.25
Asset: ArizonaPaydayClean.lua
Build: v2.0.25 + player-chat protection hotfix
```

Asset verification:

```text
Size: 188856 bytes
SHA-256: ef475e9a1b24b94fc5fd50fe6596aae10fc1ee5793272cce871c76541b94b2af
Encoding: CP1251
```

The ready-to-paste release description is available in `releases/v2.0.25.md`.

---

## 📄 License

The project is distributed free of charge.

You may use, study, and modify it. When publishing a modified build, keeping credit to the original author is appreciated.

---

## ❤️ Thanks

Thanks to my family, friends, and everyone who has been around.

SA:MP once taught me how to communicate with different people, negotiate, make decisions, and take responsibility. Those skills became useful far beyond the game.

> A person can leave Arizona RP. But Arizona RP probably never completely leaves the person.

<div align="center">

### Take care, and good luck with everything you do.

**Artty**

</div>
