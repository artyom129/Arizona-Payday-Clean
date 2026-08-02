<div align="center">

# 💸 Arizona Payday Clean

### A MoonLoader script for automatic Payday tracking, income statistics, and rank payback calculation on Arizona RP

[![Lua](https://img.shields.io/badge/Lua-MoonLoader-2C2D72?style=for-the-badge&logo=lua&logoColor=white)](#)
[![Version](https://img.shields.io/badge/version-2.0.21-F59E0B?style=for-the-badge)](#)
[![License](https://img.shields.io/badge/license-free-22C55E?style=for-the-badge)](#)
[![Author](https://img.shields.io/badge/author-Artty-8B5CF6?style=for-the-badge)](#)

[Русская версия](README.md) · **English**

</div>

> [!NOTE]
> Sometimes the most useful projects are created simply to stop doing the same repetitive task every day.

---

## 📌 About the Project

**Arizona Payday Clean** is a free MoonLoader script for Arizona RP that:

- automatically reads Payday data;
- tracks lifetime and current-session statistics;
- calculates purchased-rank payback;
- tracks bank, deposit, regular AZ Coins, and AZ ticket items;
- stores Payday history in CSV;
- sends reports and answers Telegram bot commands;
- recovers data from safe backups;
- keeps working while the game is minimized.

| Parameter | Value |
|---|---|
| **Author** | Artty |
| **Version** | 2.0.21 |
| **Platform** | MoonLoader / SA:MP / Arizona RP |
| **Distribution** | Free |
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
- salary and deposit income;
- bank and deposit balances;
- regular AZ Coins;
- AZ ticket items;
- session and lifetime totals;
- CSV history;
- backup recovery.

</td>
<td width="50%" valign="top">

### 📈 Rank Payback

- rank price;
- x1 salary;
- multiplier detection;
- optional deposit income;
- repaid and remaining amounts;
- remaining Payday estimate;
- approximate payback time.

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🖥 Interface

- main `mimgui` window;
- compact fixed mini overlay;
- Telegram, analytics, and updater tabs;
- saved settings;
- minimized-game operation;
- adaptive background loop.

</td>
<td width="50%" valign="top">

### 📬 Telegram

- automatic Payday reports;
- test message;
- bot commands;
- configured `chat_id` authorization;
- asynchronous request queue;
- long polling;
- no external processes.

</td>
</tr>
</table>

---

## 🚑 Version 2.0.21 hotfix

- robust parsing for the exact bank, deposit, salary, AZ, and ticket lines shown in-game;
- timestamps and formatting bytes no longer break numeric extraction;
- a fast partial report is not sent from only one detected value;
- missing balances are no longer replaced with stale values in Telegram.

---

## ⚡ Performance changes from 2.0.20

Version 2.0.21 reduces background CPU usage:

- the main service loop no longer runs all tasks every rendered frame;
- approximately 10 ms delay while the window is open;
- approximately 50 ms while the game is active;
- approximately 250 ms while GTA is minimized;
- the mini overlay is not rendered while the game is inactive;
- overlay calculations are cached;
- Telegram uses long polling up to 20 seconds;
- Payday and ticket handling remains event-driven.

Actual CPU usage must be verified inside GTA because all MoonLoader scripts share the same game process.

---

## 🚀 Installation

1. Close GTA completely.
2. Download `ArizonaPaydayClean.lua` from the latest Release.
3. Keep only one copy in `moonloader`.
4. Replace the old Lua file.
5. Do not delete `moonloader/config/ArizonaPaydayClean.ini`.
6. Do not delete `moonloader/config/ArizonaPaydayHistory.csv`.
7. Start the game and use `/payday`.

---

## ⌨️ Commands

| Command | Purpose |
|---|---|
| `/payday` | Open or close the main window |
| `/paystats` | Show session statistics |
| `/payhistory` | Show recent Payday records |
| `/payrecover` | Recover available data |
| `/paydebug` | Toggle diagnostic logging |
| `/paywatch` | Toggle missed-Payday monitoring |
| `/paymini` | Show or hide the mini overlay |
| `/paytg TOKEN CHAT_ID` | Configure Telegram |
| `/paytgtest` | Send a test report |
| `/paybot` | Toggle Telegram bot commands |
| `/payupdate` | Check and install an update |
| `/payupdate rollback` | Restore the previous Lua file |

---

## 🤖 Telegram Bot Commands

`/start`, `/help`, `/status`, `/ping`, `/stats`, `/today`, `/rank`, `/history`, `/watch`, `/settings`, and `/version`.

Remote gameplay control and remote setting changes are disabled.

---

## 🔐 Security

- the bot token is stored only in the local INI;
- the token field is hidden in the interface;
- commands from other `chat_id` values are ignored;
- the bot cannot control the character;
- `os.execute`, `io.popen`, PowerShell, and `curl.exe` are not used.

---

## 📦 GitHub Release v2.0.21

```text
Tag: v2.0.21
Title: Arizona Payday Clean v2.0.21
Asset: ArizonaPaydayClean.lua
Size: 178384 bytes
SHA-256: a6d3565322d9d084376186084614ec94e54aa15a898996f515ea1bdb3bddc453
Encoding: CP1251
```

---

## 📄 License

The project is distributed free of charge. Keep the original author credit when publishing modified builds.

<div align="center">

### Take care. Good luck with everything you do.

**Artty**

</div>
