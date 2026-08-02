<div align="center">

# 💸 Arizona Payday Clean

A MoonLoader script for automatic Payday, income, AZ Coins, ticket, and rank-payback tracking on Arizona RP.

**Version 2.0.19 · Author Artty**

[Русская версия](README.md)

</div>

## Features

- automatic Payday detection;
- salary, bank, deposit, AZ Coins, and AZ ticket tracking;
- CSV history in `moonloader/config/ArizonaPaydayHistory.csv`;
- purchased-rank payback calculation;
- Telegram reports and commands;
- minimized-game operation;
- safer INI saving and backups;
- built-in GitHub Releases updater.

## Installation

1. Close GTA San Andreas completely.
2. Download `ArizonaPaydayClean.lua`.
3. Place it in the `moonloader` directory.
4. Keep only one copy of the script.
5. Do not delete `moonloader/config/ArizonaPaydayClean.ini` while updating.
6. Start the game and use `/payday`.

## Main commands

| Command | Purpose |
|---|---|
| `/payday` | Open or close the main window |
| `/paystats` | Current-session statistics |
| `/payhistory` | Recent Payday records |
| `/paydebug` | Diagnostic logging |
| `/payrecover` | Restore data from backups and CSV |
| `/paytgtest` | Test Telegram |
| `/payupdate` | Check and install an update |

## Version 2.0.19 fixes

- stricter AZ ticket parsing without capturing unrelated numbers;
- legitimate identical rewards received in sequence are no longer dropped;
- one reward repeated through chat, GameText, and TextDraw is counted once;
- late salary, deposit, AZ, and ticket lines are attached to the correct Payday;
- a lone bank-check heading no longer creates an empty Payday;
- reduced Telegram polling delay;
- removed additional cursor-flicker sources;
- backups no longer restore spent balances or a deliberately removed Telegram token;
- a new rank does not inherit the previous rank's progress;
- history is refreshed before `/payhistory` output.

Full release notes: [`releases/v2.0.19.md`](releases/v2.0.19.md).

## Data and security

Do not publish your `ArizonaPaydayClean.ini`; it may contain a Telegram token. Configuration, history, and backups are stored in `moonloader/config`.

## Compatibility

MoonLoader, mimgui, `lib.samp.events`, inicfg, Windows, SA:MP, and Arizona RP.

## Validation note

The 2.0.19 Lua file is stored in CP1251. Static checks do not replace a real MoonLoader run, so checking the first Payday with `/paydebug` is recommended.