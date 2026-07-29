local SCRIPT_VERSION = '2.0.1'

script_name('Arizona Payday Clean')
script_author('Artty')
script_version(SCRIPT_VERSION)
script_properties('work-in-pause')

require 'lib.moonloader'

local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local sampev = require 'lib.samp.events'
local inicfg = require 'inicfg'

local ffi = require 'ffi'
local dlstatus = require('moonloader').download_status

-- Telegram отправляется через встроенный асинхронный загрузчик MoonLoader.
-- Никаких curl.exe, PowerShell, BAT-файлов и CreateProcessA.

local CONFIG = 'ArizonaPaydayClean.ini'
local CONFIG_DIR = getWorkingDirectory() .. '\\config'
local CONFIG_PATH = CONFIG_DIR .. '\\' .. CONFIG
local HISTORY_FILE = CONFIG_DIR .. '\\ArizonaPaydayHistory.csv'
local DEBUG_FILE = CONFIG_DIR .. '\\ArizonaPaydayDebug.log'
local BACKUP_FILE = CONFIG_DIR .. '\\ArizonaPaydayClean_v1_backup.ini'
local CONFIG_EXISTED_BEFORE_V2 = doesFileExist(CONFIG_PATH)

local ini = inicfg.load({
    stats = {
        bank = 0,
        bank_plus = 0,
        deposit = 0,
        deposit_plus = 0,
        salary = 0,
        az_balance = 0,
        az_plus = 0,
        ticket_balance = 0,
        ticket_plus = 0,
        paydays = 0,
        total_salary = 0,
        total_deposit = 0,
        total_az = 0,
        total_tickets = 0,
        last_payday = 'Нет данных'
    },
    rank = {
        number = 1,
        cost = 0,
        salary_x1 = 0,
        use_deposit = false,
        tracking = false,
        repaid = 0,
        caught_paydays = 0,
        started = 'Нет данных',
        completed = false
    },
    ui = {
        mini = true
    },
    telegram = {
        enabled = false,
        token = '',
        chat_id = '',
        commands_enabled = true,
        update_offset = 0,
        poll_interval = 1
    },
    app = {
        schema = 2,
        backup_done = false,
        debug = false,
        history_limit = 50
    },
    afk = {
        enabled = false,
        interval_minutes = 30,
        grace_minutes = 8,
        telegram_alerts = true
    }
}, CONFIG)

-- Защита для старых или частично поврежденных INI.
-- В 2.0 отсутствующие секции и значения восстанавливаются без удаления старых данных.
ini = ini or {}
ini.stats = ini.stats or {}
ini.rank = ini.rank or {}
ini.ui = ini.ui or {}
ini.telegram = ini.telegram or {}
ini.app = ini.app or {}
ini.afk = ini.afk or {}

local function setDefault(section, key, value)
    if section[key] == nil then
        section[key] = value
    end
end

setDefault(ini.stats, 'bank', 0)
setDefault(ini.stats, 'bank_plus', 0)
setDefault(ini.stats, 'deposit', 0)
setDefault(ini.stats, 'deposit_plus', 0)
setDefault(ini.stats, 'salary', 0)
setDefault(ini.stats, 'az_balance', 0)
setDefault(ini.stats, 'az_plus', 0)
setDefault(ini.stats, 'ticket_balance', 0)
setDefault(ini.stats, 'ticket_plus', 0)
setDefault(ini.stats, 'paydays', 0)
setDefault(ini.stats, 'total_salary', 0)
setDefault(ini.stats, 'total_deposit', 0)
setDefault(ini.stats, 'total_az', 0)
setDefault(ini.stats, 'total_tickets', 0)
setDefault(ini.stats, 'last_payday', 'Нет данных')

setDefault(ini.rank, 'number', 1)
setDefault(ini.rank, 'cost', 0)
setDefault(ini.rank, 'salary_x1', 0)
setDefault(ini.rank, 'use_deposit', false)
setDefault(ini.rank, 'tracking', false)
setDefault(ini.rank, 'repaid', 0)
setDefault(ini.rank, 'caught_paydays', 0)
setDefault(ini.rank, 'started', 'Нет данных')
setDefault(ini.rank, 'completed', false)

setDefault(ini.ui, 'mini', true)
setDefault(ini.telegram, 'enabled', false)
setDefault(ini.telegram, 'token', '')
setDefault(ini.telegram, 'chat_id', '')
setDefault(ini.telegram, 'commands_enabled', true)
setDefault(ini.telegram, 'update_offset', 0)
setDefault(ini.telegram, 'poll_interval', 1)
setDefault(ini.app, 'schema', 2)
setDefault(ini.app, 'backup_done', false)
setDefault(ini.app, 'debug', false)
setDefault(ini.app, 'history_limit', 50)
setDefault(ini.afk, 'enabled', false)
setDefault(ini.afk, 'interval_minutes', 30)
setDefault(ini.afk, 'grace_minutes', 8)
setDefault(ini.afk, 'telegram_alerts', true)

ini.stats.ticket_balance = tonumber(ini.stats.ticket_balance) or 0
ini.stats.ticket_plus = tonumber(ini.stats.ticket_plus) or 0
ini.stats.total_tickets = tonumber(ini.stats.total_tickets) or 0
ini.telegram.commands_enabled = ini.telegram.commands_enabled == true
    or ini.telegram.commands_enabled == 1
    or ini.telegram.commands_enabled == '1'
    or ini.telegram.commands_enabled == 'true'
ini.telegram.update_offset = math.max(0, math.floor(tonumber(ini.telegram.update_offset) or 0))
ini.telegram.poll_interval = math.min(10, math.max(1, tonumber(ini.telegram.poll_interval) or 1))
ini.app.schema = tonumber(ini.app.schema) or 2
ini.app.debug = ini.app.debug == true or ini.app.debug == 1 or ini.app.debug == '1' or ini.app.debug == 'true'
ini.app.history_limit = math.min(500, math.max(10, tonumber(ini.app.history_limit) or 50))
ini.afk.enabled = ini.afk.enabled == true or ini.afk.enabled == 1 or ini.afk.enabled == '1' or ini.afk.enabled == 'true'
ini.afk.interval_minutes = math.max(1, tonumber(ini.afk.interval_minutes) or 30)
ini.afk.grace_minutes = math.max(1, tonumber(ini.afk.grace_minutes) or 8)
ini.afk.telegram_alerts = ini.afk.telegram_alerts == true
    or ini.afk.telegram_alerts == 1
    or ini.afk.telegram_alerts == '1'
    or ini.afk.telegram_alerts == 'true'

if not doesDirectoryExist(CONFIG_DIR) then
    createDirectory(CONFIG_DIR)
end

if not doesFileExist(CONFIG_PATH) then
    inicfg.save(ini, CONFIG)
end

local function asBool(value)
    return value == true or value == 1 or value == '1' or value == 'true'
end

local function copyFile(sourcePath, destinationPath)
    local source = io.open(sourcePath, 'rb')
    if not source then return false end

    local data = source:read('*a')
    source:close()

    local destination = io.open(destinationPath, 'wb')
    if not destination then return false end

    destination:write(data or '')
    destination:close()
    return true
end

-- Версия 2.0 использует тот же INI и дописывает только новые поля.
-- Перед первой миграцией сохраняется резервная копия конфигурации 1.x.
if not asBool(ini.app.backup_done) then
    local backupReady = true

    if CONFIG_EXISTED_BEFORE_V2 and doesFileExist(CONFIG_PATH) and not doesFileExist(BACKUP_FILE) then
        local ok, copied = pcall(copyFile, CONFIG_PATH, BACKUP_FILE)
        backupReady = ok and copied == true
    end

    ini.app.schema = 2
    if backupReady then
        ini.app.backup_done = true
    else
        print('[Arizona Payday Clean] WARNING: could not create INI backup. The script will retry on the next launch.')
    end
    inicfg.save(ini, CONFIG)
end

local new = imgui.new
local window = new.bool(false)
local miniEnabled = new.bool(asBool(ini.ui.mini))
local useDeposit = new.bool(asBool(ini.rank.use_deposit))
local debugEnabled = new.bool(asBool(ini.app.debug))
local afkEnabled = new.bool(asBool(ini.afk.enabled))
local afkTelegramAlerts = new.bool(asBool(ini.afk.telegram_alerts))
local telegramCommandsEnabled = new.bool(asBool(ini.telegram.commands_enabled))

local session = {
    startedAt = os.time(),
    paydays = 0,
    salary = 0,
    deposit = 0,
    az = 0,
    tickets = 0
}

local historyCache = {}
local lastServerActivity = os.time()
local afkAlertSent = false
local lastWatchdogCheck = 0
local statsResetConfirmUntil = 0
local rankResetConfirmUntil = 0

-- Эти значения не передаются напрямую в ImGui, поэтому храним их как Lua-числа.
-- Так цены выше 2 147 483 647 не переполняют 32-битный imgui.new.int.
local rankNumber = { [0] = tonumber(ini.rank.number) or 1 }
local rankCost = { [0] = tonumber(ini.rank.cost) or 0 }
local rankSalary = { [0] = tonumber(ini.rank.salary_x1) or 0 }
local forecastPaydays = new.int(10)

-- Текстовые поля используются вместо InputInt:
-- InputInt в mimgui реагирует на перетаскивание мышью и из-за этого дергает курсор.
local rankNumberText = new.char[16](tostring(rankNumber[0]))
local rankCostText = new.char[32](tostring(rankCost[0]))
local rankSalaryText = new.char[32](tostring(rankSalary[0]))
local telegramTokenText = new.char[128](tostring(ini.telegram.token or ''))
local telegramChatIdText = new.char[32](tostring(ini.telegram.chat_id or ''))

local activeTab = 1
local statusText = 'Ожидаю ближайший PayDay'
local lastPaydayCatch = 0
local paydaySequence = 0
local paydayPending = false
local paydayCaptureStartedAt = 0

local W = imgui.WindowFlags or {}
local function flags(...)
    local total = 0
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        if v then total = total + v end
    end
    return total
end

local MAIN_FLAGS = flags(W.NoDecoration, W.NoMove, W.NoResize, W.NoScrollbar, W.NoScrollWithMouse)
local PANEL_FLAGS = flags(W.NoScrollbar, W.NoScrollWithMouse)
local MINI_FLAGS = flags(W.NoDecoration, W.NoMove, W.NoResize, W.NoScrollbar, W.NoScrollWithMouse, W.AlwaysAutoResize)

local function clampNumber(value, minValue, maxValue)
    value = tonumber(value) or 0
    if value < minValue then return minValue end
    if maxValue and value > maxValue then return maxValue end
    return value
end

local function formatNumber(value)
    value = math.floor(tonumber(value) or 0)
    local sign = ''
    if value < 0 then
        sign = '-'
        value = math.abs(value)
    end

    local text = tostring(value)
    local result = ''

    while #text > 3 do
        result = '.' .. text:sub(-3) .. result
        text = text:sub(1, -4)
    end

    return sign .. text .. result
end

local function money(value)
    return '$ ' .. formatNumber(value)
end

local function stripColors(text)
    return (text or ''):gsub('{%x%x%x%x%x%x}', '')
end

local function cleanNumber(value)
    local cleaned = tostring(value or ''):gsub('[^%d%-]', '')
    return tonumber(cleaned) or 0
end

local function extractNumbers(text)
    local values = {}
    local source = tostring(text or '')
    for raw in source:gmatch('%d[%d%s%.,]*') do
        local num = cleanNumber(raw)
        if type(num) == 'number' and num >= 0 then
            table.insert(values, num)
        end
    end
    return values
end

local function hasText(text, needle)
    return tostring(text or ''):find(needle, 1, true) ~= nil
end

local function detectMultiplier(baseSalary, realSalary)
    baseSalary = tonumber(baseSalary) or 0
    realSalary = tonumber(realSalary) or 0

    if baseSalary <= 0 or realSalary <= 0 then
        return 1
    end

    local ratio = realSalary / baseSalary
    local rounded = math.floor(ratio + 0.5)

    if rounded >= 1 and rounded <= 10 and math.abs(ratio - rounded) <= 0.06 then
        return rounded
    end

    return ratio
end

local function multiplierText(value)
    value = tonumber(value) or 1
    local rounded = math.floor(value + 0.5)

    if math.abs(value - rounded) < 0.01 then
        return 'x' .. tostring(rounded)
    end

    return 'x' .. string.format('%.2f', value)
end

local function paydayIncome()
    return (tonumber(ini.stats.salary) or 0) + (tonumber(ini.stats.deposit_plus) or 0)
end

local function timeFromPaydays(count)
    count = tonumber(count) or 0
    local minutes = count * 30
    local days = math.floor(minutes / 1440)
    minutes = minutes - days * 1440
    local hours = math.floor(minutes / 60)
    minutes = minutes - hours * 60

    if days > 0 then
        return string.format('%d д. %d ч. %d мин.', days, hours, minutes)
    end

    if hours > 0 then
        return string.format('%d ч. %d мин.', hours, minutes)
    end

    return string.format('%d мин.', minutes)
end

local function durationFromSeconds(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local days = math.floor(seconds / 86400)
    seconds = seconds - days * 86400
    local hours = math.floor(seconds / 3600)
    seconds = seconds - hours * 3600
    local minutes = math.floor(seconds / 60)

    if days > 0 then
        return string.format('%d д. %d ч. %d мин.', days, hours, minutes)
    elseif hours > 0 then
        return string.format('%d ч. %d мин.', hours, minutes)
    end

    return string.format('%d мин.', minutes)
end

local function sessionDurationText()
    local elapsed = math.max(0, os.time() - session.startedAt)
    local hours = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)

    if hours > 0 then
        return string.format('%d ч. %d мин.', hours, minutes)
    end

    return string.format('%d мин.', minutes)
end

local function debugLog(message)
    if not debugEnabled[0] then return end

    local file = io.open(DEBUG_FILE, 'ab')
    if not file then return end

    file:write(os.date('[%d.%m.%Y %H:%M:%S] '), tostring(message or ''), '\r\n')
    file:close()
end

local function historyParts(line)
    local parts = {}
    for value in (tostring(line or '') .. ';'):gmatch('(.-);') do
        table.insert(parts, value)
    end
    return parts
end

local HISTORY_HEADER = 'timestamp;salary;deposit;az;tickets;bank;deposit_balance;az_balance;ticket_balance;rank;multiplier;total'

local function ensureHistoryFile()
    if doesFileExist(HISTORY_FILE) then
        local existing = io.open(HISTORY_FILE, 'rb')
        if existing then
            local size = existing:seek('end') or 0
            existing:close()
            if size > 0 then return true end
        end
    end

    local file = io.open(HISTORY_FILE, 'wb')
    if not file then return false end

    file:write(HISTORY_HEADER, '\r\n')
    file:close()
    return true
end

local function refreshHistoryCache()
    historyCache = {}
    local limit = math.min(500, math.max(10, tonumber(ini.app.history_limit) or 50))
    local file = io.open(HISTORY_FILE, 'rb')
    if not file then return end

    local firstLine = true
    for line in file:lines() do
        local isHeader = firstLine and line:find('^timestamp;', 1, false) ~= nil
        firstLine = false

        if not isHeader and line ~= '' then
            local p = historyParts(line)
            if p[1] and p[1] ~= '' and p[2] ~= nil and p[12] ~= nil then
                local row = {
                    timestamp = p[1],
                    salary = tonumber(p[2]) or 0,
                    deposit = tonumber(p[3]) or 0,
                    az = tonumber(p[4]) or 0,
                    tickets = tonumber(p[5]) or 0,
                    bank = tonumber(p[6]) or 0,
                    depositBalance = tonumber(p[7]) or 0,
                    azBalance = tonumber(p[8]) or 0,
                    ticketBalance = tonumber(p[9]) or 0,
                    rank = tonumber(p[10]) or 1,
                    multiplier = tonumber(p[11]) or 1,
                    total = tonumber(p[12]) or 0
                }

                table.insert(historyCache, row)
                if #historyCache > limit then
                    table.remove(historyCache, 1)
                end
            else
                debugLog('HISTORY SKIP: malformed line')
            end
        end
    end

    file:close()
end

local function appendHistory(record)
    if not ensureHistoryFile() then
        debugLog('HISTORY ERROR: cannot create history file')
        return false
    end

    local file = io.open(HISTORY_FILE, 'ab')
    if not file then
        debugLog('HISTORY ERROR: cannot open history file')
        return false
    end

    local values = {
        tostring(record.timestamp or ''),
        tostring(record.salary or 0),
        tostring(record.deposit or 0),
        tostring(record.az or 0),
        tostring(record.tickets or 0),
        tostring(record.bank or 0),
        tostring(record.depositBalance or 0),
        tostring(record.azBalance or 0),
        tostring(record.ticketBalance or 0),
        tostring(record.rank or 1),
        tostring(record.multiplier or 1),
        tostring(record.total or 0)
    }

    file:write(table.concat(values, ';'), '\r\n')
    file:close()
    refreshHistoryCache()
    return true
end

local function historyAverageIncome()
    if #historyCache == 0 then return 0 end

    local total = 0
    for _, row in ipairs(historyCache) do
        total = total + (tonumber(row.total) or 0)
    end
    return math.floor(total / #historyCache)
end

local function stringFromBuffer(buffer)
    return ffi.string(buffer)
end

local function numberFromBuffer(buffer)
    local raw = ffi.string(buffer)
    local cleaned = raw:gsub('[^%d]', '')
    return tonumber(cleaned) or 0
end

local function setBuffer(buffer, value)
    local str = tostring(value or 0)
    ffi.fill(buffer, ffi.sizeof(buffer), 0)
    ffi.copy(buffer, str, math.min(#str, ffi.sizeof(buffer) - 1))
end

local function syncRankValuesFromText()
    rankNumber[0] = numberFromBuffer(rankNumberText)
    rankCost[0] = numberFromBuffer(rankCostText)
    rankSalary[0] = numberFromBuffer(rankSalaryText)

    if rankNumber[0] < 1 then rankNumber[0] = 1 end
    if rankCost[0] < 0 then rankCost[0] = 0 end
    if rankSalary[0] < 0 then rankSalary[0] = 0 end
end

local function saveRankInputs()
    syncRankValuesFromText()
    if rankNumber[0] < 1 then rankNumber[0] = 1 end
    if rankCost[0] < 0 then rankCost[0] = 0 end
    if rankSalary[0] < 0 then rankSalary[0] = 0 end

    ini.rank.number = rankNumber[0]
    ini.rank.cost = rankCost[0]
    ini.rank.salary_x1 = rankSalary[0]
    ini.rank.use_deposit = useDeposit[0]
    ini.ui.mini = miniEnabled[0]
    inicfg.save(ini, CONFIG)
end

local function rankStats()
    local cost = tonumber(ini.rank.cost) or 0
    local baseSalary = tonumber(ini.rank.salary_x1) or 0
    local realSalary = tonumber(ini.stats.salary) or 0
    local deposit = asBool(ini.rank.use_deposit) and (tonumber(ini.stats.deposit_plus) or 0) or 0

    local currentSalary = realSalary > 0 and realSalary or baseSalary
    local currentIncome = currentSalary + deposit
    local baseIncome = baseSalary + deposit
    local repaid = clampNumber(ini.rank.repaid, 0, cost > 0 and cost or nil)
    local remaining = math.max(0, cost - repaid)
    local progress = 0

    if cost > 0 then
        progress = clampNumber(repaid / cost, 0, 1)
    end

    local remainingX1 = 0
    if baseIncome > 0 then
        remainingX1 = math.ceil(remaining / baseIncome)
    end

    local remainingReal = 0
    if currentIncome > 0 then
        remainingReal = math.ceil(remaining / currentIncome)
    end

    local x1Done = 0
    if baseIncome > 0 then
        x1Done = repaid / baseIncome
    end

    return {
        cost = cost,
        baseSalary = baseSalary,
        realSalary = realSalary,
        deposit = deposit,
        currentSalary = currentSalary,
        currentIncome = currentIncome,
        baseIncome = baseIncome,
        multiplier = detectMultiplier(baseSalary, currentSalary),
        repaid = repaid,
        remaining = remaining,
        progress = progress,
        remainingX1 = remainingX1,
        remainingReal = remainingReal,
        x1Done = x1Done
    }
end


local markPayday

local function safeTelegramValue(value)
    value = tostring(value or '')
    return value:gsub('[^%w_:%-]', '')
end

local function telegramCredentialsValid(token, chatId)
    token = tostring(token or '')
    chatId = tostring(chatId or '')

    return token:match('^%d+:[%w_%-]+$') ~= nil
        and chatId:match('^%-?%d+$') ~= nil
end

local function telegramCredentialsReady()
    return ini.telegram
        and telegramCredentialsValid(ini.telegram.token, ini.telegram.chat_id)
end

local function telegramReady()
    return telegramCredentialsReady() and asBool(ini.telegram.enabled)
end

local function telegramProgressBar(progress, width)
    progress = clampNumber(progress, 0, 1)
    width = math.max(6, math.floor(tonumber(width) or 14))

    local exact = progress * width
    local full = math.floor(exact)
    local fraction = exact - full
    local partial = math.floor(fraction * 8 + 0.5)

    if partial >= 8 then
        full = full + 1
        partial = 0
    end

    if full > width then
        full = width
        partial = 0
    end

    local parts = {}

    if full > 0 then
        table.insert(parts, string.rep('<FULL>', full))
    end

    if partial > 0 and full < width then
        table.insert(parts, '<P' .. tostring(partial) .. '>')
    end

    local used = full + (partial > 0 and 1 or 0)
    if used < width then
        table.insert(parts, string.rep('<EMPTY>', width - used))
    end

    return table.concat(parts)
end

local function telegramProgressStatus(progress)
    progress = clampNumber(progress, 0, 1)

    if progress >= 1 then
        return 'Цель достигнута'
    elseif progress >= 0.75 then
        return 'Финишная прямая'
    elseif progress >= 0.50 then
        return 'Больше половины'
    elseif progress >= 0.25 then
        return 'Хороший темп'
    end

    return 'Начало пути'
end

local function telegramMessage()
    local st = rankStats()
    local salary = tonumber(ini.stats.salary) or 0
    local depositPlus = tonumber(ini.stats.deposit_plus) or 0
    local azBalance = tonumber(ini.stats.az_balance) or 0
    local azPlus = tonumber(ini.stats.az_plus) or 0
    local ticketBalance = tonumber(ini.stats.ticket_balance) or 0
    local ticketPlus = tonumber(ini.stats.ticket_plus) or 0
    local totalPayday = salary + depositPlus
    local rankNumberValue = tonumber(ini.rank.number) or 1
    local progressPercent = st.progress * 100

    local azText = '<b>' .. formatNumber(azBalance) .. '</b>'
    if azPlus > 0 then
        azText = azText .. '  <b>+' .. formatNumber(azPlus) .. ' AZ</b>'
    end

    local ticketText = '<b>' .. formatNumber(ticketBalance) .. '</b>'
    if ticketPlus > 0 then
        ticketText = ticketText .. '  <b>+' .. formatNumber(ticketPlus) .. ' шт.</b>'
    end

    local lines = {
        '<DIAMOND> <b>ARIZONA PAYDAY</b>',
        '<LINE>',
        '<DONE> <b>Начисление успешно</b>',
        '',
        '<MONEY> <b>ДОХОД</b>',
        '<MID> Зарплата: <b>' .. money(salary) .. '</b>',
        '<MID> Депозит: <b>' .. money(depositPlus) .. '</b>',
        '<MID> Бонус: <b>' .. multiplierText(st.multiplier) .. '</b>',
        '<END> Итого: <b>' .. money(totalPayday) .. '</b>',
        '',
        '<BANK> <b>БАЛАНС</b>',
        '<MID> Банк: <b>' .. money(ini.stats.bank) .. '</b>',
        '<MID> Депозит: <b>' .. money(ini.stats.deposit) .. '</b>',
        '<MID> AZ Coins: ' .. azText,
        '<END> Талоны AZ: ' .. ticketText,
        '',
        '<RANK> <b>РАНГ №' .. tostring(rankNumberValue) .. '</b>',
        '<b>' .. string.format('%.1f%%', progressPercent)
            .. '  <DOT>  ' .. telegramProgressStatus(st.progress) .. '</b>',
        telegramProgressBar(st.progress, 14),
        '<MID> Возвращено: <b>' .. money(st.repaid) .. '</b>',
        '<MID> Осталось: <b>' .. money(st.remaining) .. '</b>',
        '<MID> Прогноз x1: <b>' .. tostring(st.remainingX1) .. ' Payday</b>',
        '<END> По текущему доходу: <b>' .. tostring(st.remainingReal) .. ' Payday</b>',
        '<HOUR> Примерно: <b>' .. timeFromPaydays(st.remainingReal) .. '</b>',
        '<SESSION> Сессия: <b>' .. tostring(session.paydays) .. ' Payday  <DOT>  ' .. money(session.salary + session.deposit) .. '</b>',
        '',
        '<TIME> <i>' .. os.date('%d.%m.%Y  <DOT>  %H:%M:%S') .. '</i>'
    }

    if asBool(ini.rank.completed) then
        table.insert(lines, '')
        table.insert(lines, '<DONE> <b>РАНГ ПОЛНОСТЬЮ ОКУПЛЕН</b>')
    elseif not asBool(ini.rank.tracking) then
        table.insert(lines, '')
        table.insert(lines, '<WARN> <b>Отсчет окупаемости выключен</b>')
    end

    return table.concat(lines, string.char(10))
end

local telegramQueue = {}
local telegramBusy = false
local telegramFinished = nil
local telegramStartedAt = 0
local telegramCurrent = nil
local telegramRequestNumber = 0

local function telegramLog(message)
    print('[Arizona Payday Clean][Telegram] ' .. tostring(message or ''))
end

local TELEGRAM_SYMBOLS = {
    ['<DIAMOND>'] = string.char(240, 159, 146, 142),
    ['<PAYDAY>'] = string.char(240, 159, 146, 184),
    ['<MONEY>'] = string.char(240, 159, 146, 176),
    ['<BANK>'] = string.char(240, 159, 143, 166),
    ['<RANK>'] = string.char(240, 159, 147, 136),
    ['<TIME>'] = string.char(240, 159, 149, 146),
    ['<HOUR>'] = string.char(226, 143, 179),
    ['<SESSION>'] = string.char(240, 159, 149, 185),
    ['<DONE>'] = string.char(226, 156, 133),
    ['<WARN>'] = string.char(226, 154, 160, 239, 184, 143),
    ['<MID>'] = string.char(226, 148, 156),
    ['<END>'] = string.char(226, 148, 148),
    ['<DOT>'] = string.char(226, 128, 162),
    ['<FULL>'] = string.char(226, 150, 136),
    ['<P1>'] = string.char(226, 150, 143),
    ['<P2>'] = string.char(226, 150, 142),
    ['<P3>'] = string.char(226, 150, 141),
    ['<P4>'] = string.char(226, 150, 140),
    ['<P5>'] = string.char(226, 150, 139),
    ['<P6>'] = string.char(226, 150, 138),
    ['<P7>'] = string.char(226, 150, 137),
    ['<EMPTY>'] = string.char(226, 150, 145),
    ['<LINE>'] = string.rep(string.char(226, 148, 129), 18)
}

local function addTelegramSymbols(text)
    for marker, symbol in pairs(TELEGRAM_SYMBOLS) do
        text = text:gsub(marker, function()
            return symbol
        end)
    end
    return text
end

local function urlEncodeUtf8(value)
    local utf8Text = addTelegramSymbols(u8(tostring(value or '')))
    return (utf8Text:gsub('[^%w%-%._~]', function(char)
        return string.format('%%%02X', string.byte(char))
    end))
end


local TELEGRAM_BOT_COMMANDS = {
    { command = 'start', description = 'Открыть меню команд' },
    { command = 'status', description = 'Состояние игры и Payday' },
    { command = 'stats', description = 'Общая статистика' },
    { command = 'today', description = 'Доход за сегодня' },
    { command = 'rank', description = 'Окупаемость ранга' },
    { command = 'history', description = 'Последние Payday' },
    { command = 'watch', description = 'Статус контроля Payday' },
    { command = 'watch_on', description = 'Включить контроль Payday' },
    { command = 'watch_off', description = 'Выключить контроль Payday' },
    { command = 'notify_on', description = 'Включить автоуведомления' },
    { command = 'notify_off', description = 'Выключить автоуведомления' },
    { command = 'test', description = 'Тестовый Payday-отчёт' },
    { command = 'version', description = 'Версия скрипта' },
    { command = 'help', description = 'Справка по командам' }
}

local function jsonEscape(value)
    value = tostring(value or '')
    value = value:gsub('\\', '\\\\')
    value = value:gsub('"', '\\"')
    value = value:gsub('\r', '\\r')
    value = value:gsub('\n', '\\n')
    value = value:gsub('\t', '\\t')
    return value
end

local function telegramCommandsJson()
    local result = {}
    for _, item in ipairs(TELEGRAM_BOT_COMMANDS) do
        table.insert(result, '{"command":"' .. jsonEscape(item.command)
            .. '","description":"' .. jsonEscape(item.description) .. '"}')
    end
    return '[' .. table.concat(result, ',') .. ']'
end

local JSON_NULL = {}

local function utf8FromCodepoint(code)
    code = tonumber(code) or 0
    if code <= 0x7F then
        return string.char(code)
    elseif code <= 0x7FF then
        return string.char(
            0xC0 + math.floor(code / 0x40),
            0x80 + (code % 0x40)
        )
    elseif code <= 0xFFFF then
        return string.char(
            0xE0 + math.floor(code / 0x1000),
            0x80 + (math.floor(code / 0x40) % 0x40),
            0x80 + (code % 0x40)
        )
    end

    return string.char(
        0xF0 + math.floor(code / 0x40000),
        0x80 + (math.floor(code / 0x1000) % 0x40),
        0x80 + (math.floor(code / 0x40) % 0x40),
        0x80 + (code % 0x40)
    )
end

-- Небольшой встроенный JSON-декодер нужен только для ответов getUpdates.
-- Внешняя JSON-библиотека не требуется, поэтому обновление не добавляет зависимостей.
local function jsonDecode(source)
    source = tostring(source or '')
    local position = 1
    local length = #source
    local parseValue

    local function fail(message)
        error('JSON error at byte ' .. tostring(position) .. ': ' .. tostring(message), 0)
    end

    local function skipWhitespace()
        while position <= length do
            local byte = source:byte(position)
            if byte == 32 or byte == 9 or byte == 10 or byte == 13 then
                position = position + 1
            else
                break
            end
        end
    end

    local function readHex(count)
        local raw = source:sub(position, position + count - 1)
        if #raw ~= count or raw:find('[^0-9a-fA-F]') then
            fail('invalid unicode escape')
        end
        position = position + count
        return tonumber(raw, 16)
    end

    local function parseString()
        if source:sub(position, position) ~= '"' then
            fail('string expected')
        end
        position = position + 1
        local parts = {}

        while position <= length do
            local char = source:sub(position, position)
            if char == '"' then
                position = position + 1
                return table.concat(parts)
            elseif char == '\\' then
                position = position + 1
                local escaped = source:sub(position, position)
                if escaped == '' then fail('unfinished escape') end
                position = position + 1

                local replacements = {
                    ['"'] = '"', ['\\'] = '\\', ['/'] = '/',
                    ['b'] = '\b', ['f'] = '\f', ['n'] = '\n',
                    ['r'] = '\r', ['t'] = '\t'
                }

                if replacements[escaped] then
                    table.insert(parts, replacements[escaped])
                elseif escaped == 'u' then
                    local code = readHex(4)
                    if code >= 0xD800 and code <= 0xDBFF
                        and source:sub(position, position + 1) == '\\u' then
                        position = position + 2
                        local low = readHex(4)
                        if low >= 0xDC00 and low <= 0xDFFF then
                            code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
                        else
                            fail('invalid low surrogate')
                        end
                    elseif code >= 0xDC00 and code <= 0xDFFF then
                        fail('unexpected low surrogate')
                    end
                    table.insert(parts, utf8FromCodepoint(code))
                else
                    fail('invalid escape')
                end
            else
                if char:byte() < 32 then fail('control character in string') end
                table.insert(parts, char)
                position = position + 1
            end
        end

        fail('unfinished string')
    end

    local function parseNumber()
        local start = position
        if source:sub(position, position) == '-' then position = position + 1 end

        if source:sub(position, position) == '0' then
            position = position + 1
        else
            if not source:sub(position, position):match('%d') then fail('number expected') end
            while source:sub(position, position):match('%d') do position = position + 1 end
        end

        if source:sub(position, position) == '.' then
            position = position + 1
            if not source:sub(position, position):match('%d') then fail('fraction expected') end
            while source:sub(position, position):match('%d') do position = position + 1 end
        end

        local exponent = source:sub(position, position)
        if exponent == 'e' or exponent == 'E' then
            position = position + 1
            local sign = source:sub(position, position)
            if sign == '+' or sign == '-' then position = position + 1 end
            if not source:sub(position, position):match('%d') then fail('exponent expected') end
            while source:sub(position, position):match('%d') do position = position + 1 end
        end

        local value = tonumber(source:sub(start, position - 1))
        if value == nil then fail('invalid number') end
        return value
    end

    local function parseArray()
        position = position + 1
        skipWhitespace()
        local result = {}
        if source:sub(position, position) == ']' then
            position = position + 1
            return result
        end

        while true do
            table.insert(result, parseValue())
            skipWhitespace()
            local char = source:sub(position, position)
            if char == ']' then
                position = position + 1
                return result
            elseif char ~= ',' then
                fail('comma or closing bracket expected')
            end
            position = position + 1
            skipWhitespace()
        end
    end

    local function parseObject()
        position = position + 1
        skipWhitespace()
        local result = {}
        if source:sub(position, position) == '}' then
            position = position + 1
            return result
        end

        while true do
            local key = parseString()
            skipWhitespace()
            if source:sub(position, position) ~= ':' then fail('colon expected') end
            position = position + 1
            skipWhitespace()
            result[key] = parseValue()
            skipWhitespace()
            local char = source:sub(position, position)
            if char == '}' then
                position = position + 1
                return result
            elseif char ~= ',' then
                fail('comma or closing brace expected')
            end
            position = position + 1
            skipWhitespace()
        end
    end

    parseValue = function()
        skipWhitespace()
        local char = source:sub(position, position)
        if char == '"' then return parseString() end
        if char == '{' then return parseObject() end
        if char == '[' then return parseArray() end
        if char == '-' or char:match('%d') then return parseNumber() end
        if source:sub(position, position + 3) == 'true' then position = position + 4 return true end
        if source:sub(position, position + 4) == 'false' then position = position + 5 return false end
        if source:sub(position, position + 3) == 'null' then position = position + 4 return JSON_NULL end
        fail('unexpected value')
    end

    local ok, result = pcall(parseValue)
    if not ok then return nil, result end
    skipWhitespace()
    if position <= length then
        return nil, 'JSON error: trailing data at byte ' .. tostring(position)
    end
    return result
end

local function finishTelegramRequest(success, description)
    local item = telegramCurrent

    telegramBusy = false
    telegramCurrent = nil
    telegramFinished = nil
    telegramStartedAt = 0

    local kind = item and item.method or 'sendMessage'
    if success then
        telegramLog(kind == 'setMyCommands' and 'Bot command menu updated.' or 'Message sent successfully.')
        if item and item.showResult then
            sampAddChatMessage(kind == 'setMyCommands'
                and '{55DD88}[PayDay TG] {FFFFFF}Меню команд Telegram обновлено.'
                or '{55DD88}[PayDay TG] {FFFFFF}Сообщение отправлено.', -1)
        end
    else
        telegramLog(kind .. ' failed: ' .. tostring(description or 'unknown error'))
        if item and item.showResult then
            sampAddChatMessage(kind == 'setMyCommands'
                and '{FF6666}[PayDay TG] {FFFFFF}Не удалось обновить меню команд. Проверь moonloader.log.'
                or '{FF6666}[PayDay TG] {FFFFFF}Не удалось отправить сообщение. Причина записана в moonloader.log.', -1)
        end
    end
end

local function processTelegramTransport()
    if telegramFinished then
        local result = telegramFinished

        -- Поздний callback от запроса, который уже завершился по тайм-ауту,
        -- не должен сбрасывать состояние следующей отправки.
        if not telegramCurrent or result.requestId ~= telegramCurrent.requestId then
            if result.path and doesFileExist(result.path) then
                os.remove(result.path)
            end
            telegramFinished = nil
            return
        end

        local response = ''

        if doesFileExist(result.path) then
            local file = io.open(result.path, 'rb')
            if file then
                response = file:read('*a') or ''
                file:close()
            end
            os.remove(result.path)
        end

        local success = response:find('"ok"%s*:%s*true') ~= nil
        local description = response:match('"description"%s*:%s*"(.-)"')

        if response == '' then
            description = 'MoonLoader did not create a Telegram response file.'
        elseif not success and (not description or description == '') then
            description = response:sub(1, 500)
        end

        finishTelegramRequest(success, description)
    elseif telegramBusy and telegramStartedAt > 0 and os.time() - telegramStartedAt >= 40 then
        local timedOutPath = telegramCurrent and telegramCurrent.responsePath
        if timedOutPath and doesFileExist(timedOutPath) then
            os.remove(timedOutPath)
        end
        finishTelegramRequest(false, 'request timeout')
    end

    if telegramBusy or #telegramQueue == 0 then
        return
    end

    local item = table.remove(telegramQueue, 1)
    local requiresNotifications = item.requiresNotifications ~= false
    if not telegramCredentialsReady() or (requiresNotifications and not telegramReady()) then
        telegramCurrent = item
        finishTelegramRequest(false, requiresNotifications
            and 'Telegram notifications are disabled or not configured.'
            or 'Telegram credentials are not configured.')
        return
    end

    local token = safeTelegramValue(ini.telegram.token)
    local chatId = safeTelegramValue(item.chatId or ini.telegram.chat_id)
    if token == '' or (item.method ~= 'setMyCommands' and chatId == '') then
        telegramCurrent = item
        finishTelegramRequest(false, 'Empty token or chat_id.')
        return
    end

    telegramRequestNumber = telegramRequestNumber + 1
    local requestId = telegramRequestNumber
    local responsePath = getWorkingDirectory()
        .. '\\config\\ArizonaPaydayTelegramResponse_'
        .. tostring(requestId)
        .. '.json'

    if doesFileExist(responsePath) then
        os.remove(responsePath)
    end

    local url
    if item.method == 'setMyCommands' then
        local commandScope = '{"type":"chat","chat_id":' .. chatId .. '}'
        url = 'https://api.telegram.org/bot'
            .. token
            .. '/setMyCommands?commands='
            .. urlEncodeUtf8(telegramCommandsJson())
            .. '&scope='
            .. urlEncodeUtf8(commandScope)
    else
        url = 'https://api.telegram.org/bot'
            .. token
            .. '/sendMessage?chat_id='
            .. urlEncodeUtf8(chatId)
            .. '&parse_mode=HTML'
            .. '&disable_web_page_preview=true'
            .. '&text='
            .. urlEncodeUtf8(item.message)
    end

    item.responsePath = responsePath
    item.requestId = requestId
    telegramCurrent = item
    telegramBusy = true
    telegramStartedAt = os.time()

    telegramLog('Starting request #' .. tostring(requestId) .. '.')

    local ok, result = pcall(downloadUrlToFile, url, responsePath, function(id, status, p1, p2)
        if status ~= dlstatus.STATUSEX_ENDDOWNLOAD then
            return
        end

        if telegramBusy
            and telegramCurrent
            and telegramCurrent.requestId == requestId then
            telegramFinished = {
                path = responsePath,
                requestId = requestId
            }
        elseif doesFileExist(responsePath) then
            -- Ответ от уже завершившегося по тайм-ауту запроса.
            os.remove(responsePath)
        end
    end)

    if not ok or not result then
        finishTelegramRequest(false, ok and 'downloadUrlToFile returned false or nil.' or tostring(result))
    end
end

local function sendTelegramMessage(message, showResult, options)
    options = options or {}
    message = tostring(message or '')
    if message == '' then
        telegramLog('Empty message was not queued.')
        return false
    end

    local requiresNotifications = options.force ~= true
    if not telegramCredentialsReady() or (requiresNotifications and not telegramReady()) then
        if showResult then
            sampAddChatMessage('{FF6666}[PayDay TG] {FFFFFF}Telegram не настроен. Используй /paytg TOKEN CHAT_ID', -1)
        end
        return false
    end

    if #telegramQueue >= 20 then
        telegramLog('Queue is full; message dropped.')
        if showResult then
            sampAddChatMessage('{FF6666}[PayDay TG] {FFFFFF}Очередь отправки переполнена.', -1)
        end
        return false
    end

    table.insert(telegramQueue, {
        method = 'sendMessage',
        message = message,
        chatId = options.chatId,
        requiresNotifications = requiresNotifications,
        showResult = showResult == true
    })

    processTelegramTransport()
    return true
end

local function queueTelegramCommandRegistration(showResult)
    if not telegramCredentialsReady() then
        if showResult then
            sampAddChatMessage('{FF6666}[PayDay TG] {FFFFFF}Сначала настрой Telegram.', -1)
        end
        return false
    end

    if #telegramQueue >= 20 then
        if showResult then
            sampAddChatMessage('{FF6666}[PayDay TG] {FFFFFF}Очередь Telegram переполнена.', -1)
        end
        return false
    end

    table.insert(telegramQueue, {
        method = 'setMyCommands',
        requiresNotifications = false,
        showResult = showResult == true
    })
    processTelegramTransport()
    return true
end

local telegramPollBusy = false
local telegramPollFinished = nil
local telegramPollStartedAt = 0
local telegramPollRequestNumber = 0
local telegramPollResponsePath = nil
local telegramNextPollAt = 0
local telegramPollBootstrap = (tonumber(ini.telegram.update_offset) or 0) <= 0
local telegramPollError = ''
local telegramPollErrorShown = false

local function telegramIntegerString(value)
    local number = tonumber(value)
    if number then return string.format('%.0f', number) end
    return tostring(value or '')
end


local function telegramHtmlEscape(value)
    value = tostring(value or '')
    value = value:gsub('&', '&amp;')
    value = value:gsub('<', '&lt;')
    value = value:gsub('>', '&gt;')
    return value
end

local function telegramBotHelpMessage()
    return '<DIAMOND> <b>ARIZONA PAYDAY BOT</b>'
        .. string.char(10) .. '<LINE>'
        .. string.char(10) .. string.char(10)
        .. '/status — состояние игры и Payday'
        .. string.char(10) .. '/stats — общая статистика'
        .. string.char(10) .. '/today — доход за сегодня'
        .. string.char(10) .. '/rank — окупаемость ранга'
        .. string.char(10) .. '/history 5 — последние Payday'
        .. string.char(10) .. '/watch — статус контроля Payday'
        .. string.char(10) .. '/watch_on и /watch_off — переключить контроль'
        .. string.char(10) .. '/notify_on и /notify_off — автоотчёты'
        .. string.char(10) .. '/test — тестовый Payday-отчёт'
        .. string.char(10) .. '/version — версия скрипта'
end

local function telegramBotStatusMessage()
    local paydayState = lastPaydayCatch > 0
        and (durationFromSeconds(os.time() - lastPaydayCatch) .. ' назад')
        or 'ещё не обнаружен'
    local serverState = durationFromSeconds(os.time() - lastServerActivity) .. ' назад'

    return '<DONE> <b>СТАТУС СКРИПТА</b>'
        .. string.char(10) .. '<LINE>'
        .. string.char(10) .. string.char(10)
        .. '<MID> Версия: <b>' .. SCRIPT_VERSION .. '</b>'
        .. string.char(10) .. '<MID> Сессия: <b>' .. sessionDurationText() .. '</b>'
        .. string.char(10) .. '<MID> Последний Payday: <b>' .. paydayState .. '</b>'
        .. string.char(10) .. '<MID> Серверная активность: <b>' .. serverState .. '</b>'
        .. string.char(10) .. '<MID> Контроль Payday: <b>' .. (afkEnabled[0] and 'включён' or 'выключен') .. '</b>'
        .. string.char(10) .. '<END> Автоуведомления: <b>' .. (asBool(ini.telegram.enabled) and 'включены' or 'выключены') .. '</b>'
end

local function telegramBotStatsMessage()
    local totalPaydays = tonumber(ini.stats.paydays) or 0
    local totalIncome = (tonumber(ini.stats.total_salary) or 0) + (tonumber(ini.stats.total_deposit) or 0)
    local average = totalPaydays > 0 and math.floor(totalIncome / totalPaydays) or 0

    return '<MONEY> <b>ОБЩАЯ СТАТИСТИКА</b>'
        .. string.char(10) .. '<LINE>'
        .. string.char(10) .. string.char(10)
        .. '<MID> Payday: <b>' .. formatNumber(totalPaydays) .. '</b>'
        .. string.char(10) .. '<MID> Зарплата: <b>' .. money(ini.stats.total_salary) .. '</b>'
        .. string.char(10) .. '<MID> Депозит: <b>' .. money(ini.stats.total_deposit) .. '</b>'
        .. string.char(10) .. '<MID> Общий доход: <b>' .. money(totalIncome) .. '</b>'
        .. string.char(10) .. '<MID> Средний Payday: <b>' .. money(average) .. '</b>'
        .. string.char(10) .. '<MID> AZ Coins: <b>' .. formatNumber(ini.stats.total_az) .. '</b>'
        .. string.char(10) .. '<END> Талоны AZ: <b>' .. formatNumber(ini.stats.total_tickets) .. '</b>'
end

local function telegramBotTodayMessage()
    refreshHistoryCache()
    local prefix = os.date('%d.%m.%Y')
    local count, salary, deposit, az, tickets = 0, 0, 0, 0, 0
    for _, row in ipairs(historyCache) do
        if tostring(row.timestamp or ''):sub(1, #prefix) == prefix then
            count = count + 1
            salary = salary + (tonumber(row.salary) or 0)
            deposit = deposit + (tonumber(row.deposit) or 0)
            az = az + (tonumber(row.az) or 0)
            tickets = tickets + (tonumber(row.tickets) or 0)
        end
    end

    return '<TIME> <b>СЕГОДНЯ — ' .. prefix .. '</b>'
        .. string.char(10) .. '<LINE>'
        .. string.char(10) .. string.char(10)
        .. '<MID> Payday: <b>' .. tostring(count) .. '</b>'
        .. string.char(10) .. '<MID> Зарплата: <b>' .. money(salary) .. '</b>'
        .. string.char(10) .. '<MID> Депозит: <b>' .. money(deposit) .. '</b>'
        .. string.char(10) .. '<MID> Всего: <b>' .. money(salary + deposit) .. '</b>'
        .. string.char(10) .. '<MID> AZ Coins: <b>' .. formatNumber(az) .. '</b>'
        .. string.char(10) .. '<END> Талоны AZ: <b>' .. formatNumber(tickets) .. '</b>'
end

local function telegramBotRankMessage()
    local st = rankStats()
    return '<RANK> <b>ОКУПАЕМОСТЬ РАНГА №' .. tostring(tonumber(ini.rank.number) or 1) .. '</b>'
        .. string.char(10) .. '<LINE>'
        .. string.char(10) .. string.char(10)
        .. '<b>' .. string.format('%.1f%%', st.progress * 100) .. '  <DOT>  '
        .. telegramProgressStatus(st.progress) .. '</b>'
        .. string.char(10) .. telegramProgressBar(st.progress, 14)
        .. string.char(10) .. '<MID> Цена: <b>' .. money(st.cost) .. '</b>'
        .. string.char(10) .. '<MID> Возвращено: <b>' .. money(st.repaid) .. '</b>'
        .. string.char(10) .. '<MID> Осталось: <b>' .. money(st.remaining) .. '</b>'
        .. string.char(10) .. '<MID> Прогноз x1: <b>' .. tostring(st.remainingX1) .. ' Payday</b>'
        .. string.char(10) .. '<END> Текущий прогноз: <b>' .. tostring(st.remainingReal) .. ' Payday</b>'
end

local function telegramBotHistoryMessage(limit)
    refreshHistoryCache()
    limit = math.min(10, math.max(1, math.floor(tonumber(limit) or 5)))
    if #historyCache == 0 then
        return '<WARN> <b>История Payday пока пуста.</b>'
    end

    local lines = {
        '<TIME> <b>ПОСЛЕДНИЕ PAYDAY</b>',
        '<LINE>',
        ''
    }
    local first = math.max(1, #historyCache - limit + 1)
    for index = #historyCache, first, -1 do
        local row = historyCache[index]
        table.insert(lines, '<b>' .. telegramHtmlEscape(row.timestamp or '—') .. '</b>')
        table.insert(lines, '<MID> Доход: <b>' .. money(row.total) .. '</b>  <DOT>  '
            .. multiplierText(row.multiplier))
        table.insert(lines, '<END> AZ: <b>+' .. formatNumber(row.az) .. '</b>  Талоны: <b>+'
            .. formatNumber(row.tickets) .. '</b>')
        if index > first then table.insert(lines, '') end
    end
    return table.concat(lines, string.char(10))
end

local function telegramBotWatchMessage()
    local state
    if not afkEnabled[0] then
        state = 'Контроль выключен'
    elseif lastPaydayCatch <= 0 then
        state = 'Жду первый Payday'
    else
        local remaining = ((tonumber(ini.afk.interval_minutes) or 30)
            + (tonumber(ini.afk.grace_minutes) or 8)) * 60
            - math.max(0, os.time() - lastPaydayCatch)
        state = remaining <= 0 and 'Payday просрочен'
            or ('До проверки: ' .. durationFromSeconds(remaining))
    end

    return '<TIME> <b>КОНТРОЛЬ PAYDAY</b>'
        .. string.char(10) .. '<LINE>'
        .. string.char(10) .. string.char(10)
        .. '<MID> Состояние: <b>' .. state .. '</b>'
        .. string.char(10) .. '<MID> Интервал: <b>' .. tostring(ini.afk.interval_minutes) .. ' мин.</b>'
        .. string.char(10) .. '<END> Запас: <b>' .. tostring(ini.afk.grace_minutes) .. ' мин.</b>'
end

local function telegramReply(chatId, message)
    return sendTelegramMessage(message, false, { force = true, chatId = chatId })
end

local function handleTelegramBotCommand(chatId, text)
    local first, argument = tostring(text or ''):match('^%s*(/%S+)%s*(.-)%s*$')
    if not first then return end
    local command = first:lower():match('^/([^@]+)')
    if not command then return end

    if command == 'start' or command == 'help' then
        telegramReply(chatId, telegramBotHelpMessage())
    elseif command == 'status' or command == 'ping' then
        telegramReply(chatId, telegramBotStatusMessage())
    elseif command == 'stats' then
        telegramReply(chatId, telegramBotStatsMessage())
    elseif command == 'today' then
        telegramReply(chatId, telegramBotTodayMessage())
    elseif command == 'rank' then
        telegramReply(chatId, telegramBotRankMessage())
    elseif command == 'history' then
        telegramReply(chatId, telegramBotHistoryMessage(argument:match('%d+')))
    elseif command == 'watch' then
        telegramReply(chatId, telegramBotWatchMessage())
    elseif command == 'watch_on' then
        afkEnabled[0] = true
        ini.afk.enabled = true
        afkAlertSent = false
        inicfg.save(ini, CONFIG)
        telegramReply(chatId, '<DONE> <b>Контроль Payday включён.</b>')
    elseif command == 'watch_off' then
        afkEnabled[0] = false
        ini.afk.enabled = false
        afkAlertSent = false
        inicfg.save(ini, CONFIG)
        telegramReply(chatId, '<WARN> <b>Контроль Payday выключен.</b>')
    elseif command == 'notify_on' then
        ini.telegram.enabled = true
        inicfg.save(ini, CONFIG)
        telegramReply(chatId, '<DONE> <b>Автоматические Payday-уведомления включены.</b>')
    elseif command == 'notify_off' then
        ini.telegram.enabled = false
        telegramQueue = {}
        inicfg.save(ini, CONFIG)
        telegramReply(chatId, '<WARN> <b>Автоматические Payday-уведомления выключены.</b>')
    elseif command == 'test' then
        telegramReply(chatId, '<DIAMOND> <b>ТЕСТОВЫЙ ПРЕДПРОСМОТР</b>'
            .. string.char(10) .. string.char(10) .. telegramMessage())
    elseif command == 'version' then
        telegramReply(chatId, '<DIAMOND> <b>Arizona Payday Clean ' .. SCRIPT_VERSION .. '</b>')
    else
        telegramReply(chatId, '<WARN> <b>Неизвестная команда.</b>'
            .. string.char(10) .. 'Используй /help')
    end
end

local function processTelegramUpdates(payload, discardCommands)
    if type(payload) ~= 'table' or payload.ok ~= true or type(payload.result) ~= 'table' then
        return false, type(payload) == 'table' and tostring(payload.description or 'Telegram returned an error')
            or 'Invalid Telegram response'
    end

    local highestOffset = tonumber(ini.telegram.update_offset) or 0
    for _, update in ipairs(payload.result) do
        local updateId = tonumber(update.update_id)
        if updateId and updateId + 1 > highestOffset then
            highestOffset = updateId + 1
        end

        if not discardCommands and type(update.message) == 'table' then
            local message = update.message
            local chat = type(message.chat) == 'table' and message.chat or nil
            local sender = type(message.from) == 'table' and message.from or nil
            local incomingChatId = chat and telegramIntegerString(chat.id) or ''
            local configuredChatId = safeTelegramValue(ini.telegram.chat_id)

            if incomingChatId == configuredChatId and not (sender and sender.is_bot == true) then
                local messageText = type(message.text) == 'string' and message.text or ''
                if messageText:sub(1, 1) == '/' then
                    local commandOk, commandError = pcall(handleTelegramBotCommand, incomingChatId, messageText)
                    if not commandOk then
                        telegramLog('Command handler error: ' .. tostring(commandError))
                        debugLog('TELEGRAM COMMAND ERROR: ' .. tostring(commandError))
                        telegramReply(incomingChatId, '<WARN> <b>Ошибка обработки команды.</b>'
                            .. string.char(10) .. 'Подробности записаны в moonloader.log.')
                    end
                end
            elseif incomingChatId ~= '' then
                debugLog('TELEGRAM COMMAND REJECTED: chat_id=' .. incomingChatId)
            end
        end
    end

    if highestOffset ~= (tonumber(ini.telegram.update_offset) or 0) then
        ini.telegram.update_offset = highestOffset
        inicfg.save(ini, CONFIG)
    end
    return true
end

local function processTelegramBotPolling()
    if telegramPollFinished then
        local result = telegramPollFinished
        telegramPollFinished = nil
        telegramPollBusy = false
        telegramPollStartedAt = 0

        local response = ''
        telegramPollResponsePath = nil
        if result.path and doesFileExist(result.path) then
            local file = io.open(result.path, 'rb')
            if file then
                response = file:read('*a') or ''
                file:close()
            end
            os.remove(result.path)
        end

        local payload, decodeError = jsonDecode(response)
        local ok, processError = false, decodeError
        if payload then
            local callOk, processed, errorText = pcall(processTelegramUpdates, payload, result.bootstrap == true)
            if callOk then
                ok, processError = processed, errorText
            else
                processError = processed
            end
        end

        if ok then
            telegramPollError = ''
            telegramPollErrorShown = false
            if result.bootstrap then telegramPollBootstrap = false end
            telegramNextPollAt = os.time() + (tonumber(ini.telegram.poll_interval) or 1)
        else
            telegramPollError = tostring(processError or 'unknown polling error')
            telegramLog('getUpdates failed: ' .. telegramPollError)
            local retryAfter = payload and payload.parameters and tonumber(payload.parameters.retry_after) or nil
            telegramNextPollAt = os.time() + math.max(5, retryAfter or 10)
            if telegramPollError:lower():find('webhook', 1, true) and not telegramPollErrorShown then
                telegramPollErrorShown = true
                sampAddChatMessage('{FF6666}[PayDay TG] {FFFFFF}Команды бота не работают: у бота установлен webhook. Подробности в moonloader.log.', -1)
            end
        end
    elseif telegramPollBusy and telegramPollStartedAt > 0
        and os.time() - telegramPollStartedAt >= 35 then
        telegramPollBusy = false
        telegramPollStartedAt = 0
        if telegramPollResponsePath and doesFileExist(telegramPollResponsePath) then os.remove(telegramPollResponsePath) end
        telegramPollResponsePath = nil
        telegramNextPollAt = os.time() + 10
        telegramLog('getUpdates request timeout')
    end

    if telegramPollBusy
        or not telegramCommandsEnabled[0]
        or not telegramCredentialsReady()
        or os.time() < telegramNextPollAt then
        return
    end

    telegramPollRequestNumber = telegramPollRequestNumber + 1
    local requestId = telegramPollRequestNumber
    local responsePath = CONFIG_DIR .. '\\ArizonaPaydayTelegramUpdates_' .. tostring(requestId) .. '.json'
    telegramPollResponsePath = responsePath
    if doesFileExist(responsePath) then os.remove(responsePath) end

    local offset = telegramPollBootstrap and -1 or math.max(0, tonumber(ini.telegram.update_offset) or 0)
    local url = 'https://api.telegram.org/bot' .. safeTelegramValue(ini.telegram.token)
        .. '/getUpdates?offset=' .. tostring(offset)
        .. '&limit=' .. (telegramPollBootstrap and '1' or '20')
        .. '&timeout=20&allowed_updates=%5B%22message%22%5D'

    telegramPollBusy = true
    telegramPollStartedAt = os.time()
    local bootstrap = telegramPollBootstrap

    local ok, result = pcall(downloadUrlToFile, url, responsePath, function(id, status, p1, p2)
        if status ~= dlstatus.STATUSEX_ENDDOWNLOAD then return end
        if telegramPollBusy and requestId == telegramPollRequestNumber then
            telegramPollFinished = {
                path = responsePath,
                requestId = requestId,
                bootstrap = bootstrap
            }
        elseif doesFileExist(responsePath) then
            os.remove(responsePath)
        end
    end)

    if not ok or not result then
        telegramPollBusy = false
        telegramPollStartedAt = 0
        if telegramPollResponsePath and doesFileExist(telegramPollResponsePath) then
            os.remove(telegramPollResponsePath)
        end
        telegramPollResponsePath = nil
        telegramNextPollAt = os.time() + 10
        telegramLog('Could not start getUpdates: ' .. tostring(ok and result or result))
    end
end

local function afkDeadlineSeconds()
    local interval = math.max(1, tonumber(ini.afk.interval_minutes) or 30)
    local grace = math.max(1, tonumber(ini.afk.grace_minutes) or 8)
    return (interval + grace) * 60
end

local function afkStatusText()
    if not afkEnabled[0] then
        return 'Контроль выключен'
    end

    if lastPaydayCatch <= 0 then
        return 'Жду первый Payday'
    end

    local elapsed = math.max(0, os.time() - lastPaydayCatch)
    local remaining = afkDeadlineSeconds() - elapsed

    if remaining <= 0 then
        return 'Payday просрочен'
    end

    return 'До проверки: ' .. durationFromSeconds(remaining)
end

local function afkAlertMessage()
    local minutes = math.floor(math.max(0, os.time() - lastPaydayCatch) / 60)
    return '<WARN> <b>КОНТРОЛЬ PAYDAY</b>'
        .. string.char(10) .. '<LINE>'
        .. string.char(10) .. string.char(10)
        .. 'Payday не обнаружен уже <b>' .. tostring(minutes) .. ' мин.</b>'
        .. string.char(10) .. 'Последняя активность сервера: <b>'
        .. os.date('%H:%M:%S', lastServerActivity) .. '</b>'
        .. string.char(10) .. string.char(10)
        .. '<i>Проверь подключение, персонажа и anti-AFK.</i>'
end

local function processAfkWatchdog()
    if not afkEnabled[0] or lastPaydayCatch <= 0 or afkAlertSent then
        return
    end

    if os.time() - lastPaydayCatch < afkDeadlineSeconds() then
        return
    end

    afkAlertSent = true
    statusText = 'Внимание: Payday просрочен'
    sampAddChatMessage('{FF6666}[PayDay Watch] {FFFFFF}Payday не обнаружен вовремя. Проверь игру и соединение.', -1)
    debugLog('PAYDAY WATCH ALERT: Payday is overdue')

    if afkTelegramAlerts[0] and telegramReady() then
        sendTelegramMessage(afkAlertMessage(), false)
    end
end

local function schedulePaydayFinalize()
    paydaySequence = paydaySequence + 1
    local mySequence = paydaySequence

    lua_thread.create(function()
        wait(2300)
        if mySequence ~= paydaySequence or not paydayPending then
            return
        end

        paydayPending = false
        paydayCaptureStartedAt = 0
        markPayday()
    end)
end

local function telegramCommand(arg)
    arg = tostring(arg or '')
    local token, chatId = arg:match('^%s*(%S+)%s+(%-?%d+)%s*$')

    if not token or not chatId then
        sampAddChatMessage('{FFB84D}[PayDay TG] {FFFFFF}Настройка: /paytg TOKEN CHAT_ID', -1)
        sampAddChatMessage('{FFB84D}[PayDay TG] {FFFFFF}Тест: /paytgtest | Вкл: /paytgon | Выкл: /paytgoff', -1)
        return
    end

    token = safeTelegramValue(token)
    chatId = safeTelegramValue(chatId)

    if not telegramCredentialsValid(token, chatId) then
        sampAddChatMessage('{FF6666}[PayDay TG] {FFFFFF}Некорректный token или chat ID.', -1)
        return
    end

    ini.telegram.token = token
    ini.telegram.chat_id = chatId
    ini.telegram.enabled = true
    ini.telegram.commands_enabled = true
    ini.telegram.update_offset = 0
    telegramCommandsEnabled[0] = true
    telegramPollBootstrap = true
    telegramNextPollAt = 0
    setBuffer(telegramTokenText, token)
    setBuffer(telegramChatIdText, chatId)
    inicfg.save(ini, CONFIG)
    queueTelegramCommandRegistration(false)

    statusText = 'Telegram сохранен и включен'
    sampAddChatMessage('{55DD88}[PayDay TG] {FFFFFF}Telegram сохранен и включен. Проверка: /paytgtest', -1)
end

local function telegramTestCommand()
    local preview = '<DIAMOND> <b>ТЕСТОВЫЙ ПРЕДПРОСМОТР</b>'
        .. string.char(10) .. string.char(10)
        .. telegramMessage()

    sendTelegramMessage(preview, true)
end

local function telegramEnableCommand()
    if not telegramCredentialsValid(ini.telegram.token, ini.telegram.chat_id) then
        sampAddChatMessage('{FF6666}[PayDay TG] {FFFFFF}Сначала настрой: /paytg TOKEN CHAT_ID', -1)
        return
    end

    ini.telegram.enabled = true
    inicfg.save(ini, CONFIG)
    statusText = 'Telegram включен'
    sampAddChatMessage('{55DD88}[PayDay TG] {FFFFFF}Уведомления включены.', -1)
end

local function telegramDisableCommand()
    ini.telegram.enabled = false
    telegramQueue = {}
    inicfg.save(ini, CONFIG)
    statusText = 'Telegram выключен'
    sampAddChatMessage('{FFB84D}[PayDay TG] {FFFFFF}Уведомления выключены. Очередь очищена.', -1)
end


local function telegramBotToggleCommand()
    telegramCommandsEnabled[0] = not telegramCommandsEnabled[0]
    ini.telegram.commands_enabled = telegramCommandsEnabled[0]
    telegramNextPollAt = 0
    inicfg.save(ini, CONFIG)

    if telegramCommandsEnabled[0] then
        telegramPollBootstrap = (tonumber(ini.telegram.update_offset) or 0) <= 0
        queueTelegramCommandRegistration(false)
        sampAddChatMessage('{55DD88}[PayDay TG] {FFFFFF}Команды Telegram-бота включены.', -1)
    else
        sampAddChatMessage('{FFB84D}[PayDay TG] {FFFFFF}Команды Telegram-бота выключены. Автоуведомления не изменены.', -1)
    end
end

local function telegramRegisterCommandsCommand()
    queueTelegramCommandRegistration(true)
end

local function beginPaydayCapture()
    if not paydayPending then
        ini.stats.bank_plus = 0
        ini.stats.deposit_plus = 0
        ini.stats.salary = 0
        ini.stats.az_plus = 0
        ini.stats.ticket_plus = 0
    end

    paydayPending = true
    paydayCaptureStartedAt = os.time()
end

local function processPaydayCaptureTimeout()
    if paydayPending and paydayCaptureStartedAt > 0
        and os.time() - paydayCaptureStartedAt >= 15 then
        paydayPending = false
        paydayCaptureStartedAt = 0
        paydaySequence = paydaySequence + 1
        debugLog('PAYDAY CAPTURE RESET: timeout before salary finalization')
    end
end

markPayday = function()
    local now = os.time()
    if now - lastPaydayCatch < 10 then
        return
    end
    lastPaydayCatch = now
    afkAlertSent = false

    local salary = tonumber(ini.stats.salary) or 0
    local deposit = tonumber(ini.stats.deposit_plus) or 0
    local az = tonumber(ini.stats.az_plus) or 0
    local tickets = tonumber(ini.stats.ticket_plus) or 0

    ini.stats.paydays = (tonumber(ini.stats.paydays) or 0) + 1
    ini.stats.total_salary = (tonumber(ini.stats.total_salary) or 0) + salary
    ini.stats.total_deposit = (tonumber(ini.stats.total_deposit) or 0) + deposit
    ini.stats.total_az = (tonumber(ini.stats.total_az) or 0) + az
    ini.stats.total_tickets = (tonumber(ini.stats.total_tickets) or 0) + tickets
    ini.stats.last_payday = os.date('%d.%m.%Y %H:%M:%S')

    session.paydays = session.paydays + 1
    session.salary = session.salary + salary
    session.deposit = session.deposit + deposit
    session.az = session.az + az
    session.tickets = session.tickets + tickets

    if asBool(ini.rank.tracking) and not asBool(ini.rank.completed) then
        local incomeForRank = salary
        if asBool(ini.rank.use_deposit) then
            incomeForRank = incomeForRank + deposit
        end

        ini.rank.repaid = (tonumber(ini.rank.repaid) or 0) + incomeForRank
        ini.rank.caught_paydays = (tonumber(ini.rank.caught_paydays) or 0) + 1

        local cost = tonumber(ini.rank.cost) or 0
        if cost > 0 and ini.rank.repaid >= cost then
            ini.rank.repaid = cost
            ini.rank.completed = true
            ini.rank.tracking = false
            statusText = 'Ранг окуплен'
            sampAddChatMessage('{55DD88}[PayDay Helper] {FFFFFF}Ранг окуплен. Красавчик.', -1)
        else
            statusText = 'PayDay учтен в окупаемости'
        end
    else
        statusText = 'PayDay учтен'
    end

    inicfg.save(ini, CONFIG)

    local st = rankStats()
    appendHistory({
        timestamp = ini.stats.last_payday,
        salary = salary,
        deposit = deposit,
        az = az,
        tickets = tickets,
        bank = ini.stats.bank,
        depositBalance = ini.stats.deposit,
        azBalance = ini.stats.az_balance,
        ticketBalance = ini.stats.ticket_balance,
        rank = ini.rank.number,
        multiplier = st.multiplier,
        total = salary + deposit
    })

    debugLog('PAYDAY FINALIZED: salary=' .. tostring(salary)
        .. ' deposit=' .. tostring(deposit)
        .. ' az=' .. tostring(az)
        .. ' tickets=' .. tostring(tickets))

    if telegramReady() then
        sendTelegramMessage(telegramMessage(), false)
    end
end

function sampev.onServerMessage(color, text)
    text = stripColors(text)
    lastServerActivity = os.time()

    local nums = extractNumbers(text)
    local isBankLine = hasText(text, 'Текущая сумма в банке')
        or hasText(text, 'Сумма в банке')
        or hasText(text, 'Банковский счет')

    local isDepositLine = hasText(text, 'Текущая сумма на депозите')
        or hasText(text, 'Сумма на депозите')
        or hasText(text, 'Депозитный счет')
        or (paydayPending and hasText(text, 'депозите'))

    local isAzBalanceLine = hasText(text, 'Баланс на донат-счет')
        or hasText(text, 'Баланс на донат-счёт')
        or hasText(text, 'Баланс донат-счета')
        or hasText(text, 'Баланс донат-счёта')

    local isTicketLine = hasText(text, 'Талон:') and hasText(text, 'AZ Coins')
    local isSalaryLine = hasText(text, 'Общая заработанная плата')
        or hasText(text, 'Общая заработная плата')
        or hasText(text, 'Зарплата организации')

    if debugEnabled[0] and (paydayPending or isBankLine or isDepositLine or isAzBalanceLine or isTicketLine or isSalaryLine) then
        debugLog('SERVER: ' .. text)
    end

    if isTicketLine then
        beginPaydayCapture()
        if nums[1] ~= nil then ini.stats.ticket_plus = nums[1] end
        if nums[2] ~= nil then ini.stats.ticket_balance = nums[2] end
    end

    if isBankLine then
        beginPaydayCapture()
        if nums[1] ~= nil then ini.stats.bank = nums[1] end
        if nums[2] ~= nil then ini.stats.bank_plus = nums[2] end
        statusText = 'Считываю банковский чек'
    end

    if isDepositLine then
        beginPaydayCapture()
        if nums[1] ~= nil then ini.stats.deposit = nums[1] end
        if nums[2] ~= nil then ini.stats.deposit_plus = nums[2] end
    end

    if isAzBalanceLine then
        beginPaydayCapture()
        if nums[1] ~= nil then ini.stats.az_balance = nums[1] end
        if nums[2] ~= nil then ini.stats.az_plus = nums[2] end
    end

    if isSalaryLine and nums[1] ~= nil then
        beginPaydayCapture()
        ini.stats.salary = nums[1]
        schedulePaydayFinalize()
    end
end

local function paydayStatsCommand()
    local income = session.salary + session.deposit
    local average = session.paydays > 0 and math.floor(income / session.paydays) or 0

    sampAddChatMessage('{FFD34E}[PayDay 2.0] {FFFFFF}Сессия: ' .. sessionDurationText()
        .. ' | Payday: ' .. tostring(session.paydays), -1)
    sampAddChatMessage('{FFD34E}[PayDay 2.0] {FFFFFF}Доход: ' .. money(income)
        .. ' | Средний: ' .. money(average)
        .. ' | AZ: ' .. tostring(session.az)
        .. ' | Талоны: ' .. tostring(session.tickets), -1)
end

local function paydayHistoryCommand()
    if #historyCache == 0 then
        sampAddChatMessage('{FFB84D}[PayDay 2.0] {FFFFFF}История пока пуста.', -1)
        return
    end

    sampAddChatMessage('{FFD34E}[PayDay 2.0] {FFFFFF}Последние Payday:', -1)
    local first = math.max(1, #historyCache - 4)
    for i = #historyCache, first, -1 do
        local row = historyCache[i]
        sampAddChatMessage('{AAAAAA}' .. tostring(row.timestamp)
            .. ' {FFFFFF}| ' .. money(row.total)
            .. ' | +' .. tostring(row.az) .. ' AZ'
            .. ' | +' .. tostring(row.tickets) .. ' тал.', -1)
    end
end

local function paydayDebugCommand()
    debugEnabled[0] = not debugEnabled[0]
    ini.app.debug = debugEnabled[0]
    inicfg.save(ini, CONFIG)

    local state = debugEnabled[0] and 'включена' or 'выключена'
    sampAddChatMessage('{FFD34E}[PayDay Debug] {FFFFFF}Диагностика ' .. state .. '.', -1)
    if debugEnabled[0] then
        debugLog('DEBUG ENABLED')
    end
end

local function paydayWatchCommand()
    afkEnabled[0] = not afkEnabled[0]
    ini.afk.enabled = afkEnabled[0]
    afkAlertSent = false
    inicfg.save(ini, CONFIG)

    local state = afkEnabled[0] and 'включен' or 'выключен'
    sampAddChatMessage('{FFD34E}[PayDay Watch] {FFFFFF}Контроль пропущенного Payday ' .. state .. '.', -1)
end

local function setMenuState(state)
    if window[0] and not state then
        saveRankInputs()
    end

    window[0] = state

    -- Передаем управление курсором интерфейсу, чтобы камера игры не дергала мышь.
    pcall(function()
        if state then
            sampSetCursorMode(2)
        else
            sampSetCursorMode(0)
        end
    end)

    pcall(function()
        lockPlayerControl(state)
    end)
end

local function beginPanel(id, x, y, w, h)
    imgui.SetCursorPos(imgui.ImVec2(x, y))
    imgui.BeginChild(id, imgui.ImVec2(w, h), true, PANEL_FLAGS)
    imgui.SetCursorPos(imgui.ImVec2(16, 12))
end

local function endPanel()
    imgui.EndChild()
end

local function textMuted(text)
    imgui.TextDisabled(u8(text))
end

local function textValue(text, mode)
    if mode == 1 then
        imgui.TextColored(imgui.ImVec4(1.0, 0.72, 0.18, 1.0), u8(text))
    elseif mode == 2 then
        imgui.TextColored(imgui.ImVec4(0.35, 0.92, 0.50, 1.0), u8(text))
    else
        imgui.Text(u8(text))
    end
end

local function tabButton(label, tab, x, y)
    imgui.SetCursorPos(imgui.ImVec2(x, y))

    if activeTab == tab then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.95, 0.50, 0.08, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1.00, 0.58, 0.12, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(1.00, 0.42, 0.05, 1.00))
    else
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.10, 0.115, 0.145, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.20, 0.25, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.22, 0.24, 0.29, 1.00))
    end

    if imgui.Button(u8(label), imgui.ImVec2(180, 38)) then
        activeTab = tab
    end

    imgui.PopStyleColor(3)
end

local function card(id, x, y, w, h, title, value, mode)
    beginPanel(id, x, y, w, h)
    textMuted(title)
    imgui.SetCursorPosX(16)
    imgui.SetCursorPosY(38)
    textValue(value, mode)
    endPanel()
end

local function row(label, value, mode, x)
    imgui.Text(u8(label))
    imgui.SameLine(x or 390)
    textValue(value, mode)
end

local function drawBankTab()
    imgui.SetCursorPos(imgui.ImVec2(260, 100))
    imgui.SetWindowFontScale(1.15)
    imgui.Text(u8'Банковский чек')
    imgui.SetWindowFontScale(1.0)

    imgui.SetCursorPos(imgui.ImVec2(260, 126))
    textMuted('Автоматически обновляется после PayDay')

    card('bank_now', 260, 160, 340, 78, 'Банк сейчас', money(ini.stats.bank), 0)
    card('deposit_now', 620, 160, 340, 78, 'Депозит сейчас', money(ini.stats.deposit), 0)

    card('salary_total', 260, 252, 340, 78, 'Всего зарплаты', money(ini.stats.total_salary), 1)
    card('deposit_total', 620, 252, 340, 78, 'Всего с депозита', money(ini.stats.total_deposit), 1)

    beginPanel('stats_panel', 260, 348, 700, 130)
    textMuted('СТАТИСТИКА')
    row('Количество PayDay', tostring(ini.stats.paydays), 0, 420)
    row('Общий доход', money((tonumber(ini.stats.total_salary) or 0) + (tonumber(ini.stats.total_deposit) or 0)), 2, 420)
    row('Получено AZ Coins', tostring(ini.stats.total_az) .. ' AZ', 1, 420)
    row('Получено талонов', tostring(ini.stats.total_tickets) .. ' шт.', 1, 420)
    endPanel()

    beginPanel('forecast_panel', 260, 492, 700, 78)
    textMuted('ПРОГНОЗ')
    imgui.PushItemWidth(80)
    if imgui.InputInt('##forecastPaydays', forecastPaydays, 1, 10) then
        if forecastPaydays[0] < 1 then forecastPaydays[0] = 1 end
    end
    imgui.PopItemWidth()
    imgui.SameLine()
    imgui.Text(u8'PayDay')
    imgui.SameLine(250)
    textValue('Итого: ' .. money(paydayIncome() * forecastPaydays[0]), 1)
    imgui.SameLine(520)
    textMuted(timeFromPaydays(forecastPaydays[0]))
    endPanel()

    imgui.SetCursorPos(imgui.ImVec2(260, 588))
    local statsResetPending = os.time() <= statsResetConfirmUntil
    local statsResetLabel = statsResetPending and 'Подтвердить сброс статистики' or 'Сбросить статистику'
    if imgui.Button(u8(statsResetLabel), imgui.ImVec2(250, 36)) then
        if statsResetPending then
            ini.stats.paydays = 0
            ini.stats.total_salary = 0
            ini.stats.total_deposit = 0
            ini.stats.total_az = 0
            ini.stats.total_tickets = 0
            ini.stats.last_payday = 'Нет данных'
            statsResetConfirmUntil = 0
            inicfg.save(ini, CONFIG)
            statusText = 'Статистика сброшена'
        else
            statsResetConfirmUntil = os.time() + 5
            statusText = 'Нажми сброс еще раз в течение 5 секунд'
        end
    end
end

local function inputTextLine(id, label, buffer, y)
    imgui.SetCursorPos(imgui.ImVec2(18, y))
    textMuted(label)

    imgui.SetCursorPos(imgui.ImVec2(205, y - 4))
    imgui.PushItemWidth(210)
    local changed = imgui.InputText('##' .. id, buffer, ffi.sizeof(buffer))
    imgui.PopItemWidth()

    local value = numberFromBuffer(buffer)
    imgui.SetCursorPos(imgui.ImVec2(440, y))
    textMuted(formatNumber(value))

    return changed
end

local function drawRankTab()
    imgui.SetCursorPos(imgui.ImVec2(260, 100))
    imgui.SetWindowFontScale(1.15)
    imgui.Text(u8'Окупаемость ранга')
    imgui.SetWindowFontScale(1.0)

    imgui.SetCursorPos(imgui.ImVec2(260, 126))
    textMuted('Введи цену ранга и обычную зарплату x1. Бонус x2/x3/x4 определяется автоматически.')

    beginPanel('rank_input_panel', 260, 160, 700, 158)
    inputTextLine('rank_number', 'Номер ранга', rankNumberText, 18)
    inputTextLine('rank_cost', 'Цена покупки, $', rankCostText, 54)
    inputTextLine('rank_salary', 'Зарплата x1, $', rankSalaryText, 90)

    imgui.SetCursorPos(imgui.ImVec2(18, 124))
    if imgui.Checkbox(u8'Учитывать депозит', useDeposit) then
        ini.rank.use_deposit = useDeposit[0]
        inicfg.save(ini, CONFIG)
    end
    imgui.SetCursorPos(imgui.ImVec2(250, 124))
    if imgui.Checkbox(u8'Мини-окно в игре', miniEnabled) then
        ini.ui.mini = miniEnabled[0]
        inicfg.save(ini, CONFIG)
    end
    endPanel()

    -- Для живого расчета читаем буферы, но не пишем INI на каждую цифру.
    syncRankValuesFromText()
    ini.rank.number = rankNumber[0]
    ini.rank.cost = rankCost[0]
    ini.rank.salary_x1 = rankSalary[0]

    local st = rankStats()

    beginPanel('rank_now_panel', 260, 330, 700, 122)
    textMuted('ТЕКУЩИЙ РАСЧЕТ ЗАРПЛАТЫ')
    row('Обычная зарплата x1', money(st.baseSalary), 0, 430)
    row('Получено за последний PayDay', money(st.currentSalary), 1, 430)
    row('Определенный бонус', multiplierText(st.multiplier), 1, 430)
    row('Доход в окупаемость за PayDay', money(st.currentIncome), 2, 430)
    endPanel()

    beginPanel('rank_result_panel', 260, 464, 700, 126)
    if st.cost > 0 and st.baseSalary > 0 then
        imgui.ProgressBar(st.progress, imgui.ImVec2(660, 18), u8(string.format('%.1f%%', st.progress * 100)))

        imgui.SetCursorPos(imgui.ImVec2(16, 46))
        textValue('Осталось: ' .. tostring(st.remainingX1) .. ' ПД x1', 1)
        imgui.SetCursorPos(imgui.ImVec2(16, 72))
        imgui.Text(u8('Реальных ПД сейчас: ' .. tostring(st.remainingReal)))
        imgui.SetCursorPos(imgui.ImVec2(16, 94))
        imgui.Text(u8('Время примерно: ' .. timeFromPaydays(st.remainingReal)))

        imgui.SetCursorPos(imgui.ImVec2(360, 46))
        imgui.Text(u8('Осталось денег: ' .. money(st.remaining)))
        imgui.SetCursorPos(imgui.ImVec2(360, 72))
        textValue('Уже возвращено: ' .. money(st.repaid), 2)
        imgui.SetCursorPos(imgui.ImVec2(360, 94))
        imgui.Text(u8(string.format('Зачтено: %.1f ПД x1', st.x1Done)))
    else
        textMuted('Заполни цену ранга и зарплату x1.')
    end
    endPanel()

    imgui.SetCursorPos(imgui.ImVec2(260, 604))
    if imgui.Button(u8'Сохранить', imgui.ImVec2(140, 36)) then
        saveRankInputs()
        statusText = 'Данные ранга сохранены'
    end

    imgui.SameLine()

    if asBool(ini.rank.tracking) then
        if imgui.Button(u8'Пауза', imgui.ImVec2(140, 36)) then
            saveRankInputs()
            ini.rank.tracking = false
            inicfg.save(ini, CONFIG)
            statusText = 'Счетчик остановлен'
        end
    else
        local label = 'Начать отсчет'
        if tostring(ini.rank.started) ~= 'Нет данных' and not asBool(ini.rank.completed) then
            label = 'Продолжить'
        end
        if asBool(ini.rank.completed) then
            label = 'Заново'
        end

        if imgui.Button(u8(label), imgui.ImVec2(160, 36)) then
            saveRankInputs()

            if rankCost[0] > 0 and rankSalary[0] > 0 then
                if tostring(ini.rank.started) == 'Нет данных' or asBool(ini.rank.completed) then
                    ini.rank.repaid = 0
                    ini.rank.caught_paydays = 0
                    ini.rank.started = os.date('%d.%m.%Y %H:%M:%S')
                    ini.rank.completed = false
                end

                ini.rank.tracking = true
                inicfg.save(ini, CONFIG)
                statusText = 'Отсчет окупаемости запущен'
                sampAddChatMessage('{55DD88}[PayDay Helper] {FFFFFF}Отсчет окупаемости запущен.', -1)
            else
                statusText = 'Укажи цену и зарплату x1'
            end
        end
    end

    imgui.SameLine()

    local rankResetPending = os.time() <= rankResetConfirmUntil
    local rankResetLabel = rankResetPending and 'Подтвердить сброс' or 'Сброс прогресса'
    if imgui.Button(u8(rankResetLabel), imgui.ImVec2(180, 36)) then
        if rankResetPending then
            ini.rank.tracking = false
            ini.rank.repaid = 0
            ini.rank.caught_paydays = 0
            ini.rank.started = 'Нет данных'
            ini.rank.completed = false
            rankResetConfirmUntil = 0
            inicfg.save(ini, CONFIG)
            statusText = 'Прогресс сброшен'
        else
            rankResetConfirmUntil = os.time() + 5
            statusText = 'Нажми сброс еще раз в течение 5 секунд'
        end
    end
end


local function drawAnalyticsTab()
    local sessionIncome = session.salary + session.deposit
    local sessionAverage = session.paydays > 0 and math.floor(sessionIncome / session.paydays) or 0

    imgui.SetCursorPos(imgui.ImVec2(260, 100))
    imgui.SetWindowFontScale(1.15)
    imgui.Text(u8'Аналитика 2.0')
    imgui.SetWindowFontScale(1.0)

    imgui.SetCursorPos(imgui.ImVec2(260, 126))
    textMuted('Статистика текущего запуска и последние Payday')

    card('session_time', 260, 154, 160, 72, 'Сессия', sessionDurationText(), 0)
    card('session_pd', 435, 154, 160, 72, 'Payday', tostring(session.paydays), 1)
    card('session_income', 610, 154, 160, 72, 'Доход', money(sessionIncome), 2)
    card('session_az', 785, 154, 175, 72, 'AZ / талоны', tostring(session.az) .. ' / ' .. tostring(session.tickets), 1)

    beginPanel('analytics_summary', 260, 240, 700, 108)
    textMuted('АНАЛИТИКА')
    row('Средний доход в сессии', money(sessionAverage), 2, 455)
    row('Средний доход по истории', money(historyAverageIncome()), 1, 455)
    row('Записей в истории', tostring(#historyCache), 0, 455)
    row('Контроль Payday', afkStatusText(), afkEnabled[0] and 2 or 0, 455)
    endPanel()

    beginPanel('history_panel', 260, 362, 700, 178)
    textMuted('ПОСЛЕДНИЕ PAYDAY')

    if #historyCache == 0 then
        imgui.SetCursorPos(imgui.ImVec2(16, 42))
        textMuted('История появится после следующего Payday.')
    else
        local first = math.max(1, #historyCache - 5)
        local y = 38
        for i = #historyCache, first, -1 do
            local item = historyCache[i]
            imgui.SetCursorPos(imgui.ImVec2(16, y))
            imgui.Text(u8(tostring(item.timestamp)
                .. '  |  ' .. money(item.total)
                .. '  |  +' .. tostring(item.az) .. ' AZ'
                .. '  |  +' .. tostring(item.tickets) .. ' тал.'))
            y = y + 22
        end
    end
    endPanel()

    beginPanel('analytics_settings', 260, 554, 700, 82)
    textMuted('КОНТРОЛЬ И ДИАГНОСТИКА')

    imgui.SetCursorPos(imgui.ImVec2(16, 42))
    if imgui.Checkbox(u8'Контроль Payday', afkEnabled) then
        ini.afk.enabled = afkEnabled[0]
        afkAlertSent = false
        inicfg.save(ini, CONFIG)
    end

    imgui.SameLine(190)
    if imgui.Checkbox(u8'Тревога в Telegram', afkTelegramAlerts) then
        ini.afk.telegram_alerts = afkTelegramAlerts[0]
        inicfg.save(ini, CONFIG)
    end

    imgui.SameLine(410)
    if imgui.Checkbox(u8'Диагностический лог', debugEnabled) then
        ini.app.debug = debugEnabled[0]
        inicfg.save(ini, CONFIG)
        if debugEnabled[0] then debugLog('DEBUG ENABLED FROM UI') end
    end
    endPanel()
end

local function drawTelegramTab()
    imgui.SetCursorPos(imgui.ImVec2(260, 100))
    imgui.SetWindowFontScale(1.15)
    imgui.Text('TELEGRAM')
    imgui.SetWindowFontScale(1.0)

    imgui.SetCursorPos(imgui.ImVec2(260, 126))
    textMuted('Вставь token и chat ID сюда. Игровой чат больше не нужен.')

    beginPanel('telegram_panel', 260, 160, 700, 305)

    imgui.SetCursorPos(imgui.ImVec2(18, 20))
    textMuted('Bot token')
    imgui.SetCursorPos(imgui.ImVec2(18, 44))
    imgui.PushItemWidth(650)
    imgui.InputText('##telegram_token', telegramTokenText, ffi.sizeof(telegramTokenText))
    imgui.PopItemWidth()

    imgui.SetCursorPos(imgui.ImVec2(18, 92))
    textMuted('Chat ID')
    imgui.SetCursorPos(imgui.ImVec2(18, 116))
    imgui.PushItemWidth(300)
    imgui.InputText('##telegram_chat_id', telegramChatIdText, ffi.sizeof(telegramChatIdText))
    imgui.PopItemWidth()

    imgui.SetCursorPos(imgui.ImVec2(18, 166))
    if imgui.Button(u8'Сохранить и включить', imgui.ImVec2(210, 38)) then
        local token = safeTelegramValue(stringFromBuffer(telegramTokenText))
        local chatId = safeTelegramValue(stringFromBuffer(telegramChatIdText))

        if not telegramCredentialsValid(token, chatId) then
            statusText = 'Ошибка: проверь token и chat ID'
            sampAddChatMessage('{FF6666}[PayDay TG] {FFFFFF}Некорректный token или chat ID.', -1)
        else
            ini.telegram.token = token
            ini.telegram.chat_id = chatId
            ini.telegram.enabled = true
            ini.telegram.commands_enabled = true
            ini.telegram.update_offset = 0
            telegramCommandsEnabled[0] = true
            telegramPollBootstrap = true
            telegramNextPollAt = 0
            inicfg.save(ini, CONFIG)
            queueTelegramCommandRegistration(false)
            statusText = 'Telegram сохранен и включен'
            sampAddChatMessage('{55DD88}[PayDay TG] {FFFFFF}Telegram и команды бота включены.', -1)
        end
    end

    imgui.SameLine()
    if imgui.Button(u8'Тест', imgui.ImVec2(110, 38)) then
        telegramTestCommand()
    end

    imgui.SameLine()
    if imgui.Button(asBool(ini.telegram.enabled) and u8'Выключить' or u8'Включить', imgui.ImVec2(120, 38)) then
        if asBool(ini.telegram.enabled) then
            telegramDisableCommand()
        else
            telegramEnableCommand()
        end
    end

    imgui.SetCursorPos(imgui.ImVec2(18, 218))
    if imgui.Checkbox(u8'Команды Telegram-бота', telegramCommandsEnabled) then
        ini.telegram.commands_enabled = telegramCommandsEnabled[0]
        telegramNextPollAt = 0
        if telegramCommandsEnabled[0] then
            telegramPollBootstrap = (tonumber(ini.telegram.update_offset) or 0) <= 0
            queueTelegramCommandRegistration(false)
        end
        inicfg.save(ini, CONFIG)
    end

    imgui.SameLine(300)
    if imgui.Button(u8'Обновить меню команд', imgui.ImVec2(190, 30)) then
        telegramRegisterCommandsCommand()
    end

    imgui.SetCursorPos(imgui.ImVec2(18, 262))
    local notificationsState = asBool(ini.telegram.enabled) and 'уведомления включены' or 'уведомления выключены'
    local commandsState = telegramCommandsEnabled[0] and 'команды включены' or 'команды выключены'
    if telegramCredentialsReady() then
        textValue('Статус: ' .. notificationsState .. ', ' .. commandsState, 2)
    else
        textMuted('Статус: Telegram не настроен')
    end

    endPanel()
end

local miniFrame = imgui.OnFrame(function()
    local st = rankStats()

    -- Не рисуем мини-окно одновременно с главным меню.
    -- Иначе miniFrame.HideCursor=true и mainFrame.HideCursor=false
    -- каждый кадр спорят между собой, из-за чего курсор мигает при вводе текста.
    return miniEnabled[0] and not window[0] and st.cost > 0 and st.baseSalary > 0
end, function()
    local sx, sy = getScreenResolution()
    local st = rankStats()

    imgui.SetNextWindowPos(imgui.ImVec2(sx - 300, 210), imgui.Cond.Always)
    imgui.SetNextWindowSize(imgui.ImVec2(280, 112), imgui.Cond.Always)
    imgui.Begin('##PaydayMiniWindow', miniEnabled, MINI_FLAGS)

    imgui.SetCursorPos(imgui.ImVec2(14, 10))
    textValue('PAYDAY RANK', 1)
    imgui.SameLine(218)
    textValue(multiplierText(st.multiplier), 2)

    imgui.SetCursorPos(imgui.ImVec2(14, 32))
    imgui.ProgressBar(st.progress, imgui.ImVec2(252, 18), u8(string.format('%.1f%%', st.progress * 100)))

    imgui.SetCursorPos(imgui.ImVec2(14, 58))
    imgui.Text(u8('Осталось: ' .. tostring(st.remainingX1) .. ' ПД x1'))

    imgui.SetCursorPos(imgui.ImVec2(14, 78))
    textMuted('Реально: ' .. tostring(st.remainingReal) .. ' ПД | ' .. money(st.remaining))

    imgui.End()
end)
miniFrame.HideCursor = true

local mainFrame = imgui.OnFrame(function() return window[0] end, function()
    local sx, sy = getScreenResolution()
    local winW, winH = 1000, 660

    imgui.SetNextWindowPos(imgui.ImVec2(sx / 2, sy / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(winW, winH), imgui.Cond.Always)
    imgui.Begin('##ArizonaPaydayCleanWindow', window, MAIN_FLAGS)

    beginPanel('topbar', 12, 10, 976, 62)
    imgui.SetWindowFontScale(1.22)
    imgui.Text(u8'PAYDAY CENTER 2.0')
    imgui.SetWindowFontScale(1.0)
    textMuted('Arizona RP - экономика, история, контроль Payday и Telegram')
    imgui.SetCursorPos(imgui.ImVec2(926, 10))
    if imgui.Button('X##close_main', imgui.ImVec2(34, 32)) then
        setMenuState(false)
    end
    endPanel()

    beginPanel('sidebar', 20, 92, 210, 548)
    textMuted('МЕНЮ')
    tabButton('Банковский чек', 1, 16, 42)
    tabButton('Окупаемость', 2, 16, 90)
    tabButton('Telegram', 3, 16, 138)
    tabButton('Аналитика', 4, 16, 186)

    imgui.SetCursorPos(imgui.ImVec2(16, 228))
    imgui.Separator()
    imgui.SetCursorPos(imgui.ImVec2(16, 248))
    textMuted('СТАТУС')
    imgui.SetCursorPos(imgui.ImVec2(16, 272))
    imgui.PushTextWrapPos(190)
    textValue(statusText, 1)
    imgui.PopTextWrapPos()

    imgui.SetCursorPos(imgui.ImVec2(16, 334))
    textMuted('PayDay: ' .. tostring(ini.stats.paydays))
    imgui.SetCursorPos(imgui.ImVec2(16, 360))
    textMuted('Последний:')
    imgui.SetCursorPos(imgui.ImVec2(16, 382))
    imgui.PushTextWrapPos(190)
    textMuted(tostring(ini.stats.last_payday))
    imgui.PopTextWrapPos()

    local st = rankStats()
    if st.cost > 0 and st.baseSalary > 0 then
        imgui.SetCursorPos(imgui.ImVec2(16, 420))
        imgui.Separator()
        imgui.SetCursorPos(imgui.ImVec2(16, 440))
        if asBool(ini.rank.tracking) then
            textValue('Счетчик активен', 2)
        elseif asBool(ini.rank.completed) then
            textValue('Ранг окуплен', 2)
        else
            textMuted('Счетчик на паузе')
        end

        imgui.SetCursorPos(imgui.ImVec2(16, 468))
        textValue('Осталось: ' .. tostring(st.remainingX1) .. ' ПД x1', 1)
        imgui.SetCursorPos(imgui.ImVec2(16, 494))
        textMuted('Реально: ' .. tostring(st.remainingReal) .. ' ПД')
    end
    endPanel()

    if activeTab == 1 then
        drawBankTab()
    elseif activeTab == 2 then
        drawRankTab()
    elseif activeTab == 3 then
        drawTelegramTab()
    else
        drawAnalyticsTab()
    end

    imgui.End()
end)
mainFrame.HideCursor = false

function main()
    while not isSampAvailable() do wait(50) end

    setBuffer(rankNumberText, rankNumber[0])
    setBuffer(rankCostText, rankCost[0])
    setBuffer(rankSalaryText, rankSalary[0])
    ensureHistoryFile()
    refreshHistoryCache()

    sampRegisterChatCommand('payday', function()
        setMenuState(not window[0])
    end)

    sampRegisterChatCommand('paycalc', function()
        setMenuState(not window[0])
    end)

    sampRegisterChatCommand('paytg', telegramCommand)
    sampRegisterChatCommand('paytgtest', telegramTestCommand)
    sampRegisterChatCommand('paytgon', telegramEnableCommand)
    sampRegisterChatCommand('paytgoff', telegramDisableCommand)
    sampRegisterChatCommand('paybot', telegramBotToggleCommand)
    sampRegisterChatCommand('paytgcommands', telegramRegisterCommandsCommand)
    sampRegisterChatCommand('paystats', paydayStatsCommand)
    sampRegisterChatCommand('payhistory', paydayHistoryCommand)
    sampRegisterChatCommand('paydebug', paydayDebugCommand)
    sampRegisterChatCommand('paywatch', paydayWatchCommand)
    sampRegisterChatCommand('payafk', paydayWatchCommand) -- старый псевдоним beta-версии

    print('[Arizona Payday Clean] Commands: /payday /paycalc /paytg /paytgtest /paytgon /paytgoff /paybot /paytgcommands /paystats /payhistory /paydebug /paywatch')

    sampAddChatMessage('{FFD34E}[PayDay 2.0] {FFFFFF}Версия ' .. SCRIPT_VERSION .. ' загружена. Настройки 1.7 сохранены.', -1)

    if telegramCommandsEnabled[0] and telegramCredentialsReady() then
        queueTelegramCommandRegistration(false)
    end

    local lastMiniState = miniEnabled[0]

    while true do
        wait(0)

        processTelegramTransport()
        processTelegramBotPolling()

        local now = os.time()
        if now ~= lastWatchdogCheck then
            lastWatchdogCheck = now
            processAfkWatchdog()
            processPaydayCaptureTimeout()
        end

        if miniEnabled[0] ~= lastMiniState then
            lastMiniState = miniEnabled[0]
            ini.ui.mini = miniEnabled[0]
            inicfg.save(ini, CONFIG)
        end

        if window[0] and isKeyJustPressed(0x1B) then
            setMenuState(false)
            wait(150)
        end
    end
end

function onScriptTerminate(script, quitGame)
    if script == thisScript() then
        pcall(saveRankInputs)
        pcall(function()
            ini.app.debug = debugEnabled[0]
            ini.afk.enabled = afkEnabled[0]
            ini.afk.telegram_alerts = afkTelegramAlerts[0]
            ini.telegram.commands_enabled = telegramCommandsEnabled[0]
            inicfg.save(ini, CONFIG)
        end)
        pcall(function() sampSetCursorMode(0) end)
        pcall(function() lockPlayerControl(false) end)
        pcall(function()
            if telegramCurrent and telegramCurrent.responsePath and doesFileExist(telegramCurrent.responsePath) then
                os.remove(telegramCurrent.responsePath)
            end
            if telegramPollResponsePath and doesFileExist(telegramPollResponsePath) then
                os.remove(telegramPollResponsePath)
            end
        end)
    end
end
