<div align="center">

# 💸 Arizona Payday Clean

### A MoonLoader script for automatic Payday tracking, income statistics, and rank payback calculation on Arizona RP

[![Lua](https://img.shields.io/badge/Lua-MoonLoader-2C2D72?style=for-the-badge&logo=lua&logoColor=white)](https://github.com/artyom129/Arizona-Payday-Clean)
[![Version](https://img.shields.io/badge/version-2.0.20-F59E0B?style=for-the-badge)](https://github.com/artyom129/Arizona-Payday-Clean/releases/latest)
[![License](https://img.shields.io/badge/license-free-22C55E?style=for-the-badge)](#)
[![Author](https://img.shields.io/badge/author-Artty-8B5CF6?style=for-the-badge)](https://github.com/artyom129/Arizona-Payday-Clean)

[Русская версия](README.md) · **English**

<br>

[![Download](https://img.shields.io/badge/DOWNLOAD_LATEST_VERSION-2.0.20-22C55E?style=for-the-badge&logo=github)](https://github.com/artyom129/Arizona-Payday-Clean/releases/latest)

</div>

> [!NOTE]
> Some of the most useful projects are created simply to stop doing the same repetitive task every day.

---

## 📌 About

**Arizona Payday Clean** is a free MoonLoader script for Arizona RP. It automatically tracks Payday data, income, rank payback, regular AZ Coins, AZ ticket items, history, Telegram reports, and missed-Payday monitoring.

| Parameter | Value |
|---|---|
| **Author** | Artty |
| **Version** | 2.0.20 |
| **Platform** | MoonLoader / SA:MP / Arizona RP |
| **Main file** | `ArizonaPaydayClean.lua` |
| **Configuration** | `moonloader/config/ArizonaPaydayClean.ini` |
| **History** | `moonloader/config/ArizonaPaydayHistory.csv` |

---

## ✨ Features

<table>
<tr>
<td width="50%" valign="top">

### 📊 Statistics

- automatic Payday detection;
- bank, deposit, salary, and balances;
- lifetime and current-session statistics;
- CSV history;
- safe INI and history backups;
- recovery tools.

</td>
<td width="50%" valign="top">

### 📈 Rank Payback

- rank price and x1 salary;
- multiplier detection;
- optional deposit income;
- repaid and remaining amounts;
- Payday and time forecast;
- fixed mini overlay.

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🪙 AZ Coins

- regular AZ Coins tracking;
- separate AZ ticket tracking;
- duplicate-event protection;
- late rewards added to the latest Payday;
- INI, CSV, UI, and Telegram synchronization.

</td>
<td width="50%" valign="top">

### 📬 Telegram

- formatted HTML reports;
- asynchronous request queue;
- bot commands restricted to the configured `chat_id`;
- missed-Payday alerts;
- long polling without external processes.

</td>
</tr>
</table>

---

## ⚡ Version 2.0.20

Version 2.0.20 reduces background CPU usage:

- the service loop no longer performs all work every rendered frame;
- approximately 10 ms delay while the main window is open;
- approximately 50 ms while the game is active;
- approximately 250 ms while the game is minimized;
- the mini overlay is not rendered while GTA is inactive;
- mini-overlay calculations are cached;
- Telegram uses long polling with a timeout of up to 20 seconds;
- server event handlers for Payday and ticket items remain event-driven.

Actual CPU usage must be verified inside GTA because MoonLoader and other installed scripts share the same process.

---

## 🚀 Installation

1. Close GTA completely.
2. Download `ArizonaPaydayClean.lua` from the latest GitHub Release.
3. Keep only one script copy in `moonloader`.
4. Copy the file to:

```text
GTA San Andreas/
└── moonloader/
    └── ArizonaPaydayClean.lua
```

5. Do not delete:

```text
moonloader/config/ArizonaPaydayClean.ini
moonloader/config/ArizonaPaydayHistory.csv
```

6. Start the game and use `/payday`.

---

## ⌨️ Main Commands

| Command | Purpose |
|---|---|
| `/payday` | open or close the main window |
| `/paystats` | current-session statistics |
| `/payhistory` | recent Payday records |
| `/payrecover` | recover available data |
| `/paydebug` | toggle diagnostic logging |
| `/paywatch` | toggle missed-Payday monitoring |
| `/paymini` | show or hide the mini overlay |
| `/paytg TOKEN CHAT_ID` | configure Telegram |
| `/paytgtest` | send a test report |
| `/paybot` | toggle Telegram bot commands |
| `/payupdate` | check and install an update |
| `/payupdate rollback` | restore the previous Lua file |

---

## 🤖 Telegram Bot Commands

`/start`, `/help`, `/status`, `/ping`, `/stats`, `/today`, `/rank`, `/history`, `/watch`, `/settings`, and `/version`.

Remote gameplay control and remote setting changes are intentionally disabled.

---

## 🔄 Updater Safety

The updater downloads to a temporary file, verifies the version and size, checks SHA-256 when a digest is available, creates a backup, rejects downgrades, and supports rollback. It does not use `os.execute`, `io.popen`, PowerShell, or `curl.exe`.

---

## 📦 GitHub Release Asset

Upload this file to the release:

```text
ArizonaPaydayClean.lua
```

Verification:

```text
Size: 178384 bytes
SHA-256: a6d3565322d9d084376186084614ec94e54aa15a898996f515ea1bdb3bddc453
Encoding: CP1251
```

Release notes are stored in `releases/v2.0.20.md`.

---

## 📜 Author

Created by **Artty** and distributed for free.
