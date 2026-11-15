<div align="center">

# Arizona Payday Clean

**A MoonLoader script for Arizona RP that counts every Payday on its own, tells you when your rank pays for itself and sends the report to Telegram while the game is minimized.**

English · [Русский](README.ru.md) · [Қазақша](README.kk.md)

[![Lua](https://img.shields.io/badge/Lua-MoonLoader-2C2D72?logo=lua&logoColor=white)](#)
[![Version](https://img.shields.io/badge/version-2.0.28-F59E0B)](CHANGELOG.md)
[![License](https://img.shields.io/badge/license-MIT-22C55E)](LICENSE)

**[Download the latest release](https://github.com/artyom129/Arizona-Payday-Clean/releases/latest)**

</div>

## What it does

You buy a rank, leave the character AFK and minimize the game. The script answers the questions people usually open the window for: what came in this Payday, which multiplier applied, how much of the rank has paid back and how long is left.

- reads Payday lines from the server and separates them from player messages, so text typed in chat cannot fake a bank balance or a salary
- keeps overall stats, session stats and a CSV history
- calculates rank payback with x2, x3 and x4 multipliers and, if you want, the deposit
- shows bank, deposit, AZ Coins and coupons
- sends a Telegram report after every Payday and answers bot commands, including a fresh game screenshot on `/screen`
- restores stats from backups
- updates through GitHub Releases with a SHA-256 check and rollback
- keeps working while the game is minimized and shuts down cleanly with it

| | |
| --- | --- |
| Platform | MoonLoader, SA:MP, Arizona RP |
| Main file | `ArizonaPaydayClean.lua` (CP1251) |
| Settings | `moonloader/config/ArizonaPaydayClean.ini` |
| History | `moonloader/config/ArizonaPaydayHistory.csv` |

## Features

**Stats.** Payday is detected automatically: bank and deposit, salary and deposit income for the last Payday, AZ Coins and coupons, the Payday count, total income and the current session. Nothing is counted twice, and late credits are added to the Payday they belong to.

**Payback.** Rank number and price, the x1 salary, the multiplier detected on its own. You see what has come back, how much money and how many Paydays are left and roughly how long that is. A mini window keeps the progress on screen.

**Interface.** A `mimgui` window with Bank, Payback, Telegram, Analytics and Updates sections, a compact mini window, saved settings and text inputs for large sums.

**Telegram.** A report after each Payday, a test message, bot commands, access only for the saved `chat_id`, an async request queue. No `curl.exe`, PowerShell, CMD or other external processes.

## What's new

**2.0.28.** A new look for the window. Graphite surfaces and one amber accent that stays with money, progress and the active section. A quiet sidebar instead of bright orange buttons, large figures on the bank and deposit cards, headings without caps. Counting logic is unchanged. This version is in the repository; it goes into a release archive after an in-game check.

**2.0.27.** The missed-Payday watch waits for the first confirmed Payday of the current launch. Duplicate protection copes with the system clock moving back. The INI backup check goes through every field even when some are missing. Telegram sends and `getUpdates` no longer share one transport. CSV lines are normalized before they are written. Rank fields act as a preview until you press Save.

Full history in [CHANGELOG.md](CHANGELOG.md).

## Install

You need GTA San Andreas, SA:MP or an Arizona RP build, MoonLoader, `mimgui`, `lib.samp.events` and `inicfg`.

1. Close GTA.
2. Download the [latest release](https://github.com/artyom129/Arizona-Payday-Clean/releases/latest) archive.
3. Copy `ArizonaPaydayClean.lua` to `moonloader/`.
4. Copy `lib/ArizonaPaydayScreen.dll` to `moonloader/lib/`. It powers `/screen`; without it Payday tracking still works, screenshots do not.
5. Keep one copy of the script in `moonloader`, otherwise two versions count the same Payday twice.
6. Do not delete `ArizonaPaydayClean.ini` and `ArizonaPaydayHistory.csv` in `moonloader/config/`.
7. Start the game and open the window with `/payday`.

From then on `/payupdate` updates the Lua file by itself. The DLL is installed by hand once.

## In-game commands

| Command | What it does |
| --- | --- |
| `/payday`, `/paycalc` | Open or close the window |
| `/paystats` | Current session stats |
| `/payhistory` | Recent Payday records |
| `/payrecover` | Restore data from backups and CSV |
| `/paydebug` | Diagnostic log |
| `/paywatch` | Missed-Payday watch |
| `/paymini`, `/paymini on`, `/paymini off` | Mini window |
| `/payscreen` | Game screenshot to Telegram |
| `/paytg TOKEN CHAT_ID` | Save the bot token and chat ID |
| `/paytgtest` | Test report |
| `/paytgon`, `/paytgoff` | Turn notifications on or off |
| `/paybot` | Turn bot commands on or off |
| `/paytgcommands` | Refresh the bot command menu |
| `/payupdate`, `/payupdate rollback` | Update or roll back |

Example: `/paytg 1234567890:AAExampleBotTokenExample 123456789`. For a group or channel the `chat_id` can be negative, for example `-1001234567890`.

## Bot commands

| Command | What it does |
| --- | --- |
| `/start`, `/help` | Help |
| `/status`, `/ping` | Game, Payday and last server line status |
| `/stats` | Overall stats |
| `/today` | Today's stats |
| `/screen` | Fresh game screenshot |
| `/rank` | Rank payback |
| `/history N` | Recent Paydays |
| `/watch` | Payday watch status |
| `/settings` | Current switches |
| `/version` | Installed version |

The bot cannot control your character. The token and `chat_id` live only in `moonloader/config/ArizonaPaydayClean.ini` on your machine; the public script file contains neither.

After a Payday, Telegram gets the salary, multiplier, deposit income, total income, bank and deposit balance, AZ Coins, coupons, payback progress and the time of the last server line.

## How it works

```mermaid
flowchart TD
    A[Server sends Payday and coupon lines] --> B[Filter separates system lines from player messages]
    B --> C[Bank, deposit, salary, AZ Coins, coupons]
    C --> D[Duplicate and late-credit check]
    D --> E[Stats, INI and CSV]
    E --> F[Telegram report]
    S[/screen or /payscreen] --> T[SA:MP saves a PNG]
    T --> U[Module sends the photo]
```

- **No external processes.** Text and updates go through MoonLoader's built-in async `downloadUrlToFile`.
- **Isolated screenshots.** `ArizonaPaydayScreen.dll` gets the token only for one send. If the module is missing or Telegram rejects the photo, only that request fails; stats are not touched.
- **No duplicates.** The server sends related lines through Chat, GameText and TextDraw. The script collects them in a short window, compares signatures and adds late credits to the current Payday.
- **Large sums.** Values beyond a 32-bit `InputInt` are typed as text and converted safely.
- **Clean exit.** On `/q` the window closes, no new requests start, the screenshot task is cancelled and state is saved once.

## If something goes wrong

Open an Issue with: what happened and after what, whether the game was minimized, whether anti-AFK was on, whether notifications and bot commands were on, which other scripts were running, the last lines of `moonloader/moonloader.log` and an example of a server line the script misread. If `gta_sa.exe` closed without a Lua error, check Windows Event Viewer → Windows Logs → Application.

Do not attach `ArizonaPaydayClean.ini`, temporary Telegram JSON files, a zip of `moonloader/config` or screenshots that show the token.

## Author and license

[Koncha Artyom](https://github.com/artyom129). [MIT](LICENSE) license: use it, change it and share it, keeping the author credit.
