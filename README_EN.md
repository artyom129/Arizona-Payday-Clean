# Arizona Payday Clean v2.0.20

A stabilization build of the MoonLoader script for Arizona RP.

## Version 2.0.20

- reduced CPU usage while the game is minimized;
- the service loop no longer runs every frame;
- the ImGui mini overlay is not rendered while GTA is in the background;
- mini-window calculations are cached for 500 ms;
- Telegram now uses real long polling instead of starting a new HTTPS request every second;
- Payday, ticket, history, Telegram, and updater features remain available;
- existing `ArizonaPaydayClean.ini` files remain compatible.

## Installation

Close GTA, replace `moonloader/ArizonaPaydayClean.lua`, keep only one script copy, and do not delete files in `moonloader/config`.

Author: Artty
