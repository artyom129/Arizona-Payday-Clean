<div align="center">

# 💸 Arizona Payday Clean

A MoonLoader script for automatic Payday, income, AZ Coins, ticket, and rank-payback tracking on Arizona RP.

**Version 2.0.19 · Author Artty**

[Русская версия](README.md)

</div>

## Features

- automatic Payday detection and storage;
- salary, bank, deposit, and AZ Coins tracking;
- separate AZ Coins ticket tracking;
- CSV history in `ArizonaPaydayHistory.csv`;
- purchased-rank payback calculation;
- Telegram reports and commands;
- minimized-game operation;
- safe INI and history recovery;
- built-in update checks through GitHub Releases.

## Installation

1. Close GTA San Andreas completely.
2. Download `ArizonaPaydayClean.lua`.
3. Copy it into the `moonloader` directory.
4. Replace the old version and keep only one copy of the script.
5. Do not delete `moonloader/config/ArizonaPaydayClean.ini` or `ArizonaPaydayHistory.csv`.
6. Start the game and use `/payday`.

## Main commands

| Command | Purpose |
|---|---|
| `/payday` | open or close the main window |
| `/paystats` | show current-session statistics |
| `/payhistory` | show recent Payday records |
| `/paydebug` | toggle diagnostic mode |
| `/payrecover` | recover data from backups and CSV |
| `/paytgtest` | test Telegram delivery |
| `/payupdate` | check for and install an update |
| `/paymini` | show or hide the mini window |

## Version 2.0.19

This is a stabilization release with no new required dependencies. It improves ticket counting, late Payday-line handling, duplicate protection, Telegram polling, persisted status, cursor behavior, balance recovery, and rank-progress isolation.

Full changelog: [`releases/v2.0.19.md`](releases/v2.0.19.md).

## User data

The script stores user data under `moonloader/config`. Never publish `ArizonaPaydayClean.ini`, because it may contain a Telegram token.

## Requirements

- MoonLoader;
- `mimgui`;
- `lib.samp.events`;
- `inicfg`;
- Windows and an Arizona RP SA:MP-compatible build.

## Validation note

Static checks do not replace a real GTA and MoonLoader run. After updating, enable `/paydebug` for one Payday and inspect `moonloader.log` if anything looks wrong.
