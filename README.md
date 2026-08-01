# Arizona Payday Clean

MoonLoader-скрипт для Arizona RP, который автоматически считает Payday, доход, окупаемость ранга, AZ Coins, статистику сессии и при необходимости отправляет отчеты в Telegram.

## Версия

Актуальная версия: **2.0.11**

Основной файл:

```text
ArizonaPaydayClean.lua
```

## Возможности

- автоматически определяет Payday и записывает доход;
- считает банк, депозит, зарплату, AZ Coins и талоны;
- показывает прогресс окупаемости ранга и прогноз;
- сохраняет историю Payday в CSV;
- умеет отправлять отчеты и тревоги в Telegram;
- продолжает работать, когда игра свернута;
- использует встроенную загрузку MoonLoader без `curl`, PowerShell, CMD и BAT-файлов.

## Установка

1. Установи MoonLoader для GTA San Andreas / SA:MP.
2. Скачай последнюю версию на странице GitHub Releases.
3. Помести `ArizonaPaydayClean.lua` в папку `moonloader`.
4. Запусти игру.

Конфиг создается автоматически:

```text
moonloader/config/ArizonaPaydayClean.ini
```

История Payday сохраняется здесь:

```text
moonloader/config/ArizonaPaydayHistory.csv
```

## Команды

```text
/paydayclean
/paystats
/payhistory
/payrank
/paytg
/paytgtest
/paybot
/paydebug
```

Часть команд работает только после настройки Telegram.

## Telegram

Токен Telegram-бота и `chat_id` хранятся только в локальном конфиге. В публичный репозиторий они не входят.

Перед публикацией или отправкой файлов не добавляй:

- `ArizonaPaydayClean.ini`;
- `moonloader.log`;
- скриншоты с токеном бота;
- временные ответы Telegram;
- всю папку `moonloader/config`.

## Что нового в 2.0.11

- обновлен основной файл скрипта;
- улучшено отслеживание состояния Payday;
- изменены стандартные настройки Telegram polling;
- репозиторий очищен до минимального набора файлов.

## Лицензия

Проект распространяется бесплатно. Можно использовать, изучать и изменять под себя.
