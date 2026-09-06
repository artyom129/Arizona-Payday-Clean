<a id="russian"></a>

<div align="center">

# 💸 Arizona Payday Clean

### MoonLoader-скрипт для автоматического учёта Payday, доходов и окупаемости ранга на Arizona RP

[![Lua](https://img.shields.io/badge/Lua-MoonLoader-2C2D72?style=for-the-badge&logo=lua&logoColor=white)](#)
[![Version](https://img.shields.io/badge/version-2.0.27-F59E0B?style=for-the-badge)](#)
[![License](https://img.shields.io/badge/license-free-22C55E?style=for-the-badge)](#)
[![Author](https://img.shields.io/badge/author-Artty-8B5CF6?style=for-the-badge)](#)

**🇷🇺 Русский** · [🇬🇧 English](#english)

</div>

> [!NOTE]
> Иногда самые полезные проекты появляются не из желания сделать что-то большое, а из желания перестать делать одну и ту же вещь каждый день.

---

## 📌 О проекте

**Arizona Payday Clean** — бесплатный MoonLoader-скрипт для Arizona RP, который:

- автоматически считывает данные после Payday;
- ведёт общую статистику и CSV-историю;
- рассчитывает окупаемость купленного ранга;
- показывает банк, депозит, AZ Coins и талоны AZ Coins;
- определяет множитель зарплаты;
- отправляет отчёты и отвечает на команды Telegram-бота;
- по команде `/screen` присылает актуальный скриншот GTA в Telegram;
- восстанавливает статистику из резервных копий;
- безопасно проверяет обновления через GitHub Releases;
- продолжает работать, когда GTA свёрнута;
- снижает фоновую нагрузку и корректно завершает работу вместе с игрой.

| Параметр | Значение |
|---|---|
| **Автор** | Artty |
| **Версия** | 2.0.27 |
| **Платформа** | MoonLoader / SA:MP / Arizona RP |
| **Распространение** | Бесплатно |
| **Основной файл** | `ArizonaPaydayClean.lua` |
| **Конфигурация** | `moonloader/config/ArizonaPaydayClean.ini` |
| **История** | `moonloader/config/ArizonaPaydayHistory.csv` |
| **Кодировка Lua-файла** | CP1251 |

---

<details open>
<summary><strong>👤 Немного от автора</strong></summary>

<br>

Привет.

Этот проект никогда не создавался как «идеальный» MoonLoader-скрипт, который должен удивлять анимациями или огромным количеством настроек.

Он создавался для одного человека — для меня.

Мне хотелось, чтобы скрипт просто работал: стабильно учитывал Payday, сохранял данные и не требовал постоянного внимания. Поэтому функциональность здесь важнее красивой картинки.

Репозиторий опубликован бесплатно как пример моего подхода к автоматизации, Telegram-интеграциям и решению практических задач.

</details>

---

## 🎯 Почему появился этот проект

Сейчас я провожу в игре намного меньше времени, чем раньше. Есть работа, семья, тренировки и обычная жизнь.

Поэтому игровой процесс часто выглядит так:

```text
Покупаю ранг → запускаю игру → сворачиваю окно → оставляю персонажа в AFK
```

Хотелось понимать:

- сколько уже заработано;
- окупился ли ранг;
- сколько осталось до полной окупаемости;
- какой был множитель зарплаты;
- сколько пришло на депозит;
- сколько получено AZ Coins и талонов;
- что произошло в игре, не разворачивая её.

Так появился **Arizona Payday Clean**.

---

## ✨ Возможности

<table>
<tr>
<td width="50%" valign="top">

### 📊 Статистика

- автоматическое определение Payday;
- банк и депозит;
- зарплата за последний Payday;
- доход с депозита;
- AZ Coins и талоны AZ Coins;
- количество Payday;
- общий доход;
- статистика текущей сессии;
- история в `ArizonaPaydayHistory.csv`;
- защита от повторного учёта;
- защита финансового парсера от сообщений игроков в VIP, обычном, семейном и других чатах;
- восстановление данных из резервных копий.

</td>
<td width="50%" valign="top">

### 📈 Окупаемость

- номер и цена купленного ранга;
- зарплата x1;
- автоматическое определение множителя;
- опциональный учёт дохода с депозита;
- возвращённая и оставшаяся сумма;
- оставшееся количество Payday;
- примерное время до окупаемости;
- мини-окно с текущим прогрессом.

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🖥 Интерфейс

- главное окно на `mimgui`;
- компактное мини-окно;
- вкладки статистики, ранга, Telegram, аналитики и обновлений;
- сохранение настроек;
- текстовые поля для больших игровых сумм;
- работа в свёрнутой игре;
- адаптивная частота фонового цикла.

</td>
<td width="50%" valign="top">

### 📬 Telegram

- автоматический отчёт после Payday;
- тестовое сообщение;
- включение и отключение уведомлений;
- команды `/status`, `/stats`, `/today`, `/screen`, `/rank`, `/history` и другие;
- доступ только для сохранённого `chat_id`;
- асинхронная очередь запросов;
- ограниченный по времени polling;
- защита от устаревших callback-ответов;
- удалённый скриншот GTA по команде `/screen`;
- отсутствие `curl.exe`, PowerShell, CMD и других внешних процессов.

</td>
</tr>
</table>

---

## 🚑 Что нового в версии 2.0.27

Версия **2.0.27** — небольшой стабильностный релиз после дополнительной проверки кода. Новых тяжёлых функций здесь нет: основная задача версии — убрать несколько скрытых ошибок, не меняя привычную логику Payday.

### Исправлено

- контроль пропущенного Payday больше не использует старое время из прошлой сессии как основание для тревоги сразу после входа;
- `/paywatch` и Telegram-команда `/watch` ждут **первый подтверждённый Payday текущего запуска**, и только после него начинают отсчёт следующего;
- защита от дублей корректнее ведёт себя, если системное время Windows было переведено назад;
- проверка резервной копии INI больше не прекращается на первом отсутствующем поле частично повреждённого конфига;
- исходящие Telegram-запросы и `getUpdates` не запускаются одновременно через один транспорт MoonLoader;
- CSV-строки нормализуются перед разбором и повторной записью, чтобы поздние начисления не накапливали лишние `\r`;
- значения ранга, введённые во вкладке окупаемости, используются как **предпросмотр** и не меняют активные расчёты до нажатия «Сохранить».

### Сохранено без изменений

- удалённый скриншот через `/screen` и `/payscreen`;
- `ArizonaPaydayScreen.dll` из версии 2.0.26;
- защита финансового парсера от поддельных сообщений игроков;
- учёт банка, депозита, зарплаты, AZ Coins и талонов;
- CSV-история, восстановление данных и расчёт окупаемости;
- безопасный выход через `/q` и работа в свёрнутом окне.

> [!IMPORTANT]
> **Eco / режим сна в 2.0.27 не добавлялся.** Windows Sleep останавливает игру и сетевое соединение, поэтому эта экспериментальная идея не входит в релиз.

> [!NOTE]
> Если у тебя уже установлена полноценная **2.0.26** с `moonloader/lib/ArizonaPaydayScreen.dll`, для обновления до 2.0.27 достаточно заменить `ArizonaPaydayClean.lua`. DLL в этом релизе не изменялась.

---

## 🕘 Изменения предыдущих версий

<details>
<summary><strong>Версия 2.0.26 — скриншот GTA через Telegram</strong></summary>

<br>

- добавлена Telegram-команда `/screen`;
- добавлена игровая команда `/payscreen`;
- новый PNG автоматически ищется в стандартных папках скриншотов SA:MP;
- отправка фотографии вынесена в `ArizonaPaydayScreen.dll`;
- ошибка или отсутствие DLL не останавливает учёт Payday;
- фото отправляется без `curl.exe`, PowerShell, CMD и BAT-файлов;
- при `/q` задача скриншота отменяется без ожидания сети.

</details>

<details>
<summary><strong>Версия 2.0.25 — стабильность, выход через /q и защита чатов</strong></summary>

<br>

- снижена фоновая нагрузка в активной и свёрнутой игре;
- сокращены тайм-ауты и частота Telegram polling;
- добавлен единый безопасный режим завершения работы;
- при `/q` прекращается создание новых запросов, очищаются очереди и сохраняются настройки;
- устранено двойное сохранение конфигурации;
- сообщения игроков формата `Nick_Name[ID]: текст` больше не могут подделать банк, депозит, AZ Coins, зарплату или талоны;
- реальные системные строки Payday продолжают обрабатываться прежней логикой.

</details>

<details>
<summary><strong>Версия 2.0.21 — парсер Payday</strong></summary>

<br>

- исправлена обработка реальных строк банка и депозита с разделителями;
- парсер перестал зависеть от точного положения `$`, пробелов и служебных символов;
- добавлена поддержка временной метки `[HH:MM:SS]`;
- исправлено распознавание строки `Общая заработная плата`;
- усилено распознавание талонов AZ Coins;
- неизвестные значения не подменяются старыми данными в Telegram;
- частичный отчёт не создаётся по единственной случайной строке.

</details>

<details>
<summary><strong>Версии 2.0.19–2.0.20 — талоны, дубли и фон</strong></summary>

<br>

- строгий разбор количества талонов после `+`;
- баланс талонов берётся из `(N шт.)`;
- AZ Coins не смешиваются с талонами;
- уведомления Chat, GameText и TextDraw объединяются;
- поздние начисления дописываются в последний Payday;
- одиночная строка банковского чека не создаёт пустую запись;
- добавлена адаптивная задержка фонового цикла;
- расчёты мини-окна кэшируются.

</details>

---

## 📱 Что приходит в Telegram

После Payday уведомление может содержать:

```text
💰 Зарплату
⚡ Определённый множитель
🏦 Доход с депозита
📊 Общий доход за Payday
💳 Текущий баланс банка
🏧 Текущую сумму на депозите
🪙 Баланс AZ Coins
🎟 Полученные талоны AZ Coins
📈 Прогресс окупаемости ранга
⏳ Оставшуюся сумму и количество Payday
🕒 Время последней серверной строки
```

---

## 🚀 Установка

### Требования

- GTA San Andreas;
- SA:MP или совместимая сборка Arizona RP;
- MoonLoader;
- `mimgui`;
- `lib.samp.events`;
- `inicfg`;
- стандартные библиотеки MoonLoader;

### Установка или обновление

1. Полностью закрой GTA.
2. Открой готовый архив версии 2.0.27.
3. Скопируй файл:

```text
ArizonaPaydayClean.lua → moonloader/ArizonaPaydayClean.lua
```

4. Скопируй модуль скриншотов:

```text
lib/ArizonaPaydayScreen.dll → moonloader/lib/ArizonaPaydayScreen.dll
```

5. Убедись, что в `moonloader` осталась только одна рабочая копия `ArizonaPaydayClean.lua`.
6. Не удаляй:

```text
moonloader/config/ArizonaPaydayClean.ini
moonloader/config/ArizonaPaydayHistory.csv
```

7. Запусти игру и проверь основной скрипт командой `/payday`.
8. Для проверки новой функции введи `/payscreen`, затем попробуй `/screen` в Telegram.

> [!IMPORTANT]
> Встроенный `/payupdate` обновляет Lua-файл. Модуль `ArizonaPaydayScreen.dll` нужно установить вручную хотя бы один раз из полного архива версии 2.0.27.

> [!CAUTION]
> Две версии скрипта в папке `moonloader` могут одновременно обрабатывать один Payday, дублировать уведомления и увеличивать нагрузку.

---

## ⌨️ Команды в игре

| Команда | Назначение |
|---|---|
| `/payday` | Открыть или закрыть главное окно |
| `/paycalc` | Альтернативная команда открытия окна |
| `/paystats` | Показать статистику текущей сессии |
| `/payhistory` | Показать последние записи Payday |
| `/payrecover` | Восстановить данные из резервных копий и CSV |
| `/paydebug` | Включить или выключить диагностический лог |
| `/paywatch` | Включить или выключить контроль пропущенного Payday |
| `/paymini` | Показать или скрыть мини-окно |
| `/paymini on` / `/paymini off` | Явно изменить состояние мини-окна |
| `/payscreen` | Сделать скриншот GTA и отправить его в настроенный Telegram |
| `/paytg TOKEN CHAT_ID` | Сохранить Telegram token и chat ID |
| `/paytgtest` | Отправить тестовый отчёт |
| `/paytgon` | Включить Telegram-уведомления |
| `/paytgoff` | Выключить Telegram-уведомления |
| `/paybot` | Включить или выключить команды Telegram-бота |
| `/paytgcommands` | Обновить меню команд Telegram-бота |
| `/payupdate` | Проверить и установить обновление |
| `/payupdate rollback` | Восстановить предыдущую версию Lua-файла |

### Пример настройки Telegram

```text
/paytg 1234567890:AAExampleBotTokenExample 123456789
```

Для группы или канала `chat_id` может быть отрицательным:

```text
/paytg 1234567890:AAExampleBotTokenExample -1001234567890
```

> [!CAUTION]
> Никогда не публикуй настоящий bot token в Issues, скриншотах, логах или открытом репозитории.

---

## 🤖 Команды Telegram-бота

| Команда | Назначение |
|---|---|
| `/start` / `/help` | Справка |
| `/status` / `/ping` | Статус игры, Payday и последней серверной строки |
| `/stats` | Общая статистика |
| `/today` | Статистика за текущую дату |
| `/screen` | Сделать новый скриншот GTA и прислать его в чат |
| `/rank` | Окупаемость ранга |
| `/history N` | Последние записи Payday |
| `/watch` | Состояние контроля Payday |
| `/settings` | Текущие переключатели |
| `/version` | Установленная версия |

Удалённое управление персонажем через Telegram не используется.

Bot token и `chat_id` не зашиты в публичный Lua-файл. Они сохраняются локально:

```text
moonloader/config/ArizonaPaydayClean.ini
```

Рекомендуемый `.gitignore`:

```gitignore
**/ArizonaPaydayClean.ini
**/ArizonaPaydayTelegramResponse_*.json
**/ArizonaPaydayTelegramUpdates_*.json
moonloader.log
```

---

## 🧩 Как работает скрипт

```mermaid
flowchart TD
    A[Сервер отправляет строки Payday и талонов] --> B[Фильтр отделяет системные строки от сообщений игроков]
    B --> C[Сбор банка, депозита, зарплаты, AZ Coins и талонов]
    C --> D[Проверка дублей и поздних начислений]
    D --> E[Обновление статистики, INI и CSV]
    E --> F[Telegram-отчёт через MoonLoader]
    S[Команда /screen или /payscreen] --> T[SA:MP создаёт новый PNG]
    T --> U[Модуль отправляет фото в Telegram]
```

---

## 🛠 Технические решения

### Без внешних процессов

Скрипт не запускает:

- `curl.exe`;
- PowerShell;
- CMD;
- BAT-файлы;
- `CreateProcessA`.

Текстовые Telegram-сообщения и обновления по-прежнему используют встроенный асинхронный загрузчик MoonLoader:

```lua
downloadUrlToFile(...)
```

За отправку фотографии отвечает `ArizonaPaydayScreen.dll`. Он лежит в папке `lib` и устанавливается один раз вместе с обновлением.

### Изолированный модуль скриншотов

Модуль не хранит token или `chat_id` и получает их только на время одной отправки. Если модуль отсутствует, не загрузился или Telegram отклонил фотографию, изменяется только состояние текущего запроса `/screen`; финансовая статистика не затрагивается.

### Защита от дублей

Сервер может отправлять связанные строки через Chat, GameText и TextDraw. Скрипт объединяет события в коротком окне сбора, проверяет сигнатуры и дописывает поздние начисления в уже созданный Payday.

### Большие суммы

Значения, которые могут превышать диапазон стандартного 32-битного `InputInt`, вводятся как текст и затем безопасно преобразуются в Lua-числа.

### Безопасное завершение

Версия 2.0.27 сохраняет единый безопасный обработчик событий завершения MoonLoader. После начала выхода скрипт закрывает меню, прекращает новые запросы, отменяет задачу скриншота без ожидания, освобождает управление и сохраняет состояние без повторной записи.

---

## 🐞 Возможные ошибки

Скрипт создавался прежде всего для личного использования, поэтому абсолютная совместимость с любой сборкой не гарантируется.

При создании **Issue** укажи:

- что произошло;
- после какого действия;
- была ли GTA свёрнута;
- был ли включён anti-AFK;
- были ли включены Telegram-уведомления и команды бота;
- использовалась ли команда `/screen` и появился ли PNG в папке SA:MP;
- какие другие MoonLoader-скрипты работали;
- последние строки из `moonloader.log`;
- пример неправильно обработанного серверного сообщения.

Лог MoonLoader:

```text
moonloader/moonloader.log
```

Если `gta_sa.exe` завис или закрылся без Lua-ошибки:

```text
Просмотр событий Windows → Журналы Windows → Приложение
```

---

## 🔐 Безопасность

Перед публикацией файлов проверь, что ты не прикладываешь:

- `ArizonaPaydayClean.ini`;
- `moonloader.log`;
- скриншоты с bot token;
- временные JSON-ответы Telegram;
- архив всей папки `moonloader/config`.

Публичный `ArizonaPaydayClean.lua` не содержит bot token и `chat_id`.

---

## 📦 GitHub Release v2.0.27

```text
Tag: v2.0.27
Name: Arizona Payday Clean v2.0.27 — Stability Audit
Main file: ArizonaPaydayClean.lua
Module: lib/ArizonaPaydayScreen.dll
Ready archive: ArizonaPaydayClean-v2.0.27.zip
```

Проверка файлов:

```text
ArizonaPaydayClean.lua
Size: 203683 bytes
SHA-256: 20aea201ec10273ae5a8828f0e79e733d47387cfcad1b98be0d3c94e5411ec22
Encoding: CP1251

ArizonaPaydayScreen.dll
Size: 10240 bytes
SHA-256: 5c3186cf2d5fc30c8de6e2ac6eaf6897b5eb7010bb58c603d86f63d6d0af0c87
```

> DLL совпадает с модулем из 2.0.26. Основные изменения 2.0.27 находятся в Lua-файле.

---

## 📄 Лицензия

Проект распространяется бесплатно.

Используй, изучай и изменяй под себя. При публикации изменённой версии будет правильно сохранить упоминание первоначального автора.

---

## ❤️ Спасибо

Спасибо моей семье, друзьям и людям, которые были рядом.

Когда-то SA:MP научил меня общаться с разными людьми, договариваться, принимать решения и брать ответственность. Эти навыки пригодились далеко за пределами игры.

> Человек может уйти из Arizona RP. Но Arizona RP из человека — уже вряд ли.

<div align="center">

### Берегите себя. И удачи во всём, чем бы вы ни занимались.

**Artty**

</div>

---

<a id="english"></a>

<div align="center">

# 💸 Arizona Payday Clean

### A MoonLoader script for automatic Payday, income, and rank payback tracking on Arizona RP

[![Lua](https://img.shields.io/badge/Lua-MoonLoader-2C2D72?style=for-the-badge&logo=lua&logoColor=white)](#)
[![Version](https://img.shields.io/badge/version-2.0.27-F59E0B?style=for-the-badge)](#)
[![License](https://img.shields.io/badge/license-free-22C55E?style=for-the-badge)](#)
[![Author](https://img.shields.io/badge/author-Artty-8B5CF6?style=for-the-badge)](#)

[🇷🇺 Русский](#russian) · **🇬🇧 English**

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
- sends a fresh GTA screenshot to Telegram with `/screen`;
- restores statistics from backups;
- checks GitHub Releases for updates safely;
- keeps working while GTA is minimized;
- reduces background CPU usage and shuts down correctly with the game.

| Parameter | Value |
|---|---|
| **Author** | Artty |
| **Version** | 2.0.27 |
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
- `/status`, `/stats`, `/today`, `/screen`, `/rank`, `/history`, and other commands;
- access limited to the saved `chat_id`;
- asynchronous request queue;
- time-limited polling;
- stale callback protection;
- remote GTA screenshot with `/screen`;
- no `curl.exe`, PowerShell, CMD, or other external processes.

</td>
</tr>
</table>

---

## 🚑 What is new in version 2.0.27

Version **2.0.27** is a small stability release after an additional code review. It intentionally avoids adding heavy features and focuses on fixing edge cases without changing the normal Payday workflow.

### Fixed

- the missed-Payday monitor no longer treats the saved Payday time from a previous session as a reason to alert immediately after login;
- `/paywatch` and the Telegram `/watch` command wait for the **first confirmed Payday of the current game session** before monitoring the next one;
- duplicate protection handles a backwards Windows clock adjustment more safely;
- INI backup detection no longer stops at the first missing field in a partially damaged configuration;
- outgoing Telegram requests and `getUpdates` are serialized instead of using the same MoonLoader transport at the same time;
- CSV rows are normalized before parsing and rewriting so late updates do not accumulate stray `\r` characters;
- rank values typed in the payback tab are now a **preview only** and do not affect active calculations until Save is pressed.

### Preserved

- remote screenshots through `/screen` and `/payscreen`;
- the same `ArizonaPaydayScreen.dll` used by v2.0.26;
- protection against fake financial lines posted by players;
- bank, deposit, salary, AZ Coins, and ticket tracking;
- CSV history, recovery, and rank payback calculations;
- safe `/q` shutdown and minimized-game operation.

> [!IMPORTANT]
> **No Eco / sleep-mode feature is included in v2.0.27.** Windows Sleep suspends the game and its network connection, so that experimental idea is not part of this release.

> [!NOTE]
> If a complete **v2.0.26** is already installed with `moonloader/lib/ArizonaPaydayScreen.dll`, updating to v2.0.27 only requires replacing `ArizonaPaydayClean.lua`. The DLL did not change.

---

## 🕘 Previous version highlights

<details>
<summary><strong>Version 2.0.26 — GTA screenshot through Telegram</strong></summary>

<br>

- added the Telegram `/screen` command;
- added the in-game `/payscreen` command;
- new SA:MP PNG files are detected automatically in the standard screenshot folders;
- photo upload is isolated in `ArizonaPaydayScreen.dll`;
- a missing or failed DLL does not stop Payday tracking;
- photo delivery does not use `curl.exe`, PowerShell, CMD, or BAT files;
- an active screenshot job is cancelled without waiting for the network during `/q`.

</details>

<details>
<summary><strong>Version 2.0.25 — stability, /q shutdown, and chat protection</strong></summary>

<br>

- reduced background workload while the game is active or minimized;
- shorter Telegram polling timeouts and a lower polling frequency;
- one safe shutdown path for `/q` and MoonLoader termination;
- new requests stop, queues are cleared, and settings are saved during shutdown;
- duplicate configuration saves were removed;
- player messages matching `Nick_Name[ID]: text` can no longer fake bank, deposit, AZ Coins, salary, or ticket lines;
- genuine system Payday lines still use the previous parser logic.

</details>

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
- SA:MP or a compatible Arizona RP client;
- MoonLoader;
- `mimgui`;
- `lib.samp.events`;
- `inicfg`;
- standard MoonLoader libraries;

### Install or update

1. Fully close GTA.
2. Open the complete v2.0.27 archive.
3. Copy:

```text
ArizonaPaydayClean.lua → moonloader/ArizonaPaydayClean.lua
```

4. Copy the screenshot module:

```text
lib/ArizonaPaydayScreen.dll → moonloader/lib/ArizonaPaydayScreen.dll
```

5. Keep only one active `ArizonaPaydayClean.lua` in `moonloader`.
6. Do not delete:

```text
moonloader/config/ArizonaPaydayClean.ini
moonloader/config/ArizonaPaydayHistory.csv
```

7. Start the game and verify the core script with `/payday`.
8. Test the new feature with `/payscreen`, then send `/screen` to the Telegram bot.

> [!IMPORTANT]
> The built-in `/payupdate` updates the Lua file. Install `ArizonaPaydayScreen.dll` manually at least once from the complete v2.0.27 archive.

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
| `/payscreen` | Create a GTA screenshot and send it to the configured Telegram chat |
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
| `/screen` | Create a fresh GTA screenshot and send it to the chat |
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
    A[Server sends Payday and ticket lines] --> B[Filter separates system lines from player chat]
    B --> C[Collect bank, deposit, salary, AZ Coins, and tickets]
    C --> D[Duplicate and late-income checks]
    D --> E[Update statistics, INI, and CSV]
    E --> F[Telegram report through MoonLoader]
    S[/screen or /payscreen] --> T[SA:MP creates a new PNG]
    T --> U[Helper module uploads the photo to Telegram]
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

Text Telegram messages and updates still use MoonLoader's built-in asynchronous downloader:

```lua
downloadUrlToFile(...)
```

`ArizonaPaydayScreen.dll` handles photo delivery. It is stored in the `lib` folder and only needs to be installed once with the update.

### Isolated screenshot module

The module does not store the bot token or `chat_id`; it receives them only for one upload job. A missing DLL, load failure, or rejected photo changes only the current `/screen` request and never modifies financial statistics.

### Duplicate protection

The server may send related information through Chat, GameText, and TextDraw. The script combines those events within a short collection window, checks signatures, and appends late values to the existing Payday record.

### Large values

Values that may exceed a standard 32-bit `InputInt` range are entered as text and then converted safely to Lua numbers.

### Safe shutdown

Version 2.0.27 keeps the unified safe MoonLoader shutdown path. Once shutdown begins, the script closes the menu, stops new requests, cancels the screenshot job without waiting, unlocks controls, and saves the current state without duplicate writes.

---

## 🐞 Reporting a problem

The script was primarily created for personal use, so compatibility with every MoonLoader build or third-party script cannot be guaranteed.

When opening an **Issue**, include:

- what happened;
- which action triggered it;
- whether GTA was minimized;
- whether anti-AFK was enabled;
- whether Telegram notifications and bot commands were enabled;
- whether `/screen` was used and a new PNG appeared in the SA:MP folder;
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

## 📦 GitHub Release v2.0.27

```text
Tag: v2.0.27
Name: Arizona Payday Clean v2.0.27 — Stability Audit
Main file: ArizonaPaydayClean.lua
Module: lib/ArizonaPaydayScreen.dll
Ready archive: ArizonaPaydayClean-v2.0.27.zip
```

File verification:

```text
ArizonaPaydayClean.lua
Size: 203683 bytes
SHA-256: 20aea201ec10273ae5a8828f0e79e733d47387cfcad1b98be0d3c94e5411ec22
Encoding: CP1251

ArizonaPaydayScreen.dll
Size: 10240 bytes
SHA-256: 5c3186cf2d5fc30c8de6e2ac6eaf6897b5eb7010bb58c603d86f63d6d0af0c87
```

> The DLL is identical to the module shipped with v2.0.26. The v2.0.27 changes are in the Lua file.

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
