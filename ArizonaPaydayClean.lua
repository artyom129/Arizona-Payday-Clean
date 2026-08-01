local SCRIPT_VERSION = '2.0.13'

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
        last_payday = 'Нет данных',
        last_salary_received = true,
        last_payday_partial = false
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
        mini = true,
        mini_x = -1,
        mini_y = -1
    },
    telegram = {
        enabled = false,
        token = '',
        chat_id = '',
        commands_enabled = true,
        update_offset = 0,
        poll_interval = 2
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
    },
    update = {
        auto_check = true,
        auto_download = true,
        auto_install = false,
        check_interval_hours = 6,
        last_check = 0,
        latest_version = SCRIPT_VERSION,
        pending_version = '',
        pending_digest = '',
        pending_size = 0,
        pending_asset = '',
        last_error = ''
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
ini.update = ini.update or {}

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
setDefault(ini.stats, 'last_salary_received', true)
setDefault(ini.stats, 'last_payday_partial', false)

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
setDefault(ini.ui, 'mini_x', -1)
setDefault(ini.ui, 'mini_y', -1)
setDefault(ini.telegram, 'enabled', false)
setDefault(ini.telegram, 'token', '')
setDefault(ini.telegram, 'chat_id', '')
setDefault(ini.telegram, 'commands_enabled', true)
setDefault(ini.telegram, 'update_offset', 0)
setDefault(ini.telegram, 'poll_interval', 2)
setDefault(ini.app, 'schema', 2)
setDefault(ini.app, 'backup_done', false)
setDefault(ini.app, 'debug', false)
setDefault(ini.app, 'history_limit', 50)
setDefault(ini.afk, 'enabled', false)
setDefault(ini.afk, 'interval_minutes', 30)
setDefault(ini.afk, 'grace_minutes', 8)
setDefault(ini.afk, 'telegram_alerts', true)
setDefault(ini.update, 'auto_check', true)
setDefault(ini.update, 'auto_download', true)
setDefault(ini.update, 'auto_install', false)
setDefault(ini.update, 'check_interval_hours', 6)
setDefault(ini.update, 'last_check', 0)
setDefault(ini.update, 'latest_version', SCRIPT_VERSION)
setDefault(ini.update, 'pending_version', '')
setDefault(ini.update, 'pending_digest', '')
setDefault(ini.update, 'pending_size', 0)
setDefault(ini.update, 'pending_asset', '')
setDefault(ini.update, 'last_error', '')

ini.stats.ticket_balance = tonumber(ini.stats.ticket_balance) or 0
ini.stats.ticket_plus = tonumber(ini.stats.ticket_plus) or 0
ini.stats.total_tickets = tonumber(ini.stats.total_tickets) or 0
ini.ui.mini_x = tonumber(ini.ui.mini_x) or -1
ini.ui.mini_y = tonumber(ini.ui.mini_y) or -1
ini.stats.last_salary_received = ini.stats.last_salary_received == true
    or ini.stats.last_salary_received == 1
    or ini.stats.last_salary_received == '1'
    or ini.stats.last_salary_received == 'true'
ini.stats.last_payday_partial = ini.stats.last_payday_partial == true
    or ini.stats.last_payday_partial == 1
    or ini.stats.last_payday_partial == '1'
    or ini.stats.last_payday_partial == 'true'
ini.telegram.commands_enabled = ini.telegram.commands_enabled == true
    or ini.telegram.commands_enabled == 1
    or ini.telegram.commands_enabled == '1'
    or ini.telegram.commands_enabled == 'true'
ini.telegram.update_offset = math.max(0, math.floor(tonumber(ini.telegram.update_offset) or 0))
ini.telegram.poll_interval = math.min(10, math.max(2, tonumber(ini.telegram.poll_interval) or 2))
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
ini.update.auto_check = ini.update.auto_check == true
    or ini.update.auto_check == 1
    or ini.update.auto_check == '1'
    or ini.update.auto_check == 'true'
ini.update.auto_download = ini.update.auto_download == true
    or ini.update.auto_download == 1
    or ini.update.auto_download == '1'
    or ini.update.auto_download == 'true'
ini.update.auto_install = ini.update.auto_install == true
    or ini.update.auto_install == 1
    or ini.update.auto_install == '1'
    or ini.update.auto_install == 'true'
ini.update.check_interval_hours = math.min(168, math.max(1, tonumber(ini.update.check_interval_hours) or 6))
ini.update.last_check = math.max(0, tonumber(ini.update.last_check) or 0)
ini.update.latest_version = tostring(ini.update.latest_version or SCRIPT_VERSION)
ini.update.pending_version = tostring(ini.update.pending_version or '')
ini.update.pending_digest = tostring(ini.update.pending_digest or '')
ini.update.pending_size = math.max(0, tonumber(ini.update.pending_size) or 0)
ini.update.pending_asset = tostring(ini.update.pending_asset or '')
ini.update.last_error = tostring(ini.update.last_error or '')

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
local miniMoveMode = false
local miniDragging = false
local miniPositionInitialized = false
local miniPositionDirty = false
local miniPosX = tonumber(ini.ui.mini_x) or -1
local miniPosY = tonumber(ini.ui.mini_y) or -1
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
local lastServerActivity = 0
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
local paydayCaptureUpdatedAt = 0
local paydayFinalizeAt = 0
local paydaySignals = {
    bank = false,
    deposit = false,
    az = false,
    salary = false,
    marker = false
}
local recentTicketGain = 0
local recentTicketAt = 0
local lastTicketKey = ''
local lastTicketAtMs = 0
local TICKET_DUPLICATE_WINDOW_MS = 2500

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
local MINI_WIDTH = 300
local MINI_HEIGHT = 128
-- Окно двигается нашей drag-зоной. Встроенное перемещение ImGui здесь
-- ненадёжно: у NoDecoration нет заголовка, а некоторые сборки mimgui
-- разрешают перемещение только за заголовок.
local MINI_FLAGS = flags(W.NoDecoration, W.NoMove, W.NoResize, W.NoScrollbar, W.NoScrollWithMouse, W.NoSavedSettings)
local MINI_PASSIVE_FLAGS = flags(MINI_FLAGS, W.NoInputs)
local INPUT_FLAGS = imgui.InputTextFlags or {}
local TOKEN_INPUT_FLAGS = INPUT_FLAGS.Password or 0

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
    local value = tostring(text or '')
    value = value:gsub('{%x%x%x%x%x%x%x%x}', '')
    value = value:gsub('{%x%x%x%x%x%x}', '')
    value = value:gsub('\160', ' ')
    return value
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

local function elapsedAgoText(timestamp)
    timestamp = tonumber(timestamp) or 0
    if timestamp <= 0 then
        return 'данных ещё нет'
    end

    local elapsed = math.max(0, os.time() - timestamp)

    if elapsed < 5 then
        return 'только что'
    elseif elapsed < 60 then
        return string.format('%d сек. назад', elapsed)
    elseif elapsed < 3600 then
        local minutes = math.floor(elapsed / 60)
        local seconds = elapsed % 60
        return string.format('%d мин. %d сек. назад', minutes, seconds)
    elseif elapsed < 86400 then
        local hours = math.floor(elapsed / 3600)
        local minutes = math.floor((elapsed % 3600) / 60)
        return string.format('%d ч. %d мин. назад', hours, minutes)
    end

    local days = math.floor(elapsed / 86400)
    local hours = math.floor((elapsed % 86400) / 3600)
    return string.format('%d д. %d ч. назад', days, hours)
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
    if miniPositionInitialized then
        ini.ui.mini_x = math.floor(miniPosX + 0.5)
        ini.ui.mini_y = math.floor(miniPosY + 0.5)
    end
    inicfg.save(ini, CONFIG)
end

local function defaultMiniPosition()
    local screenWidth, screenHeight = getScreenResolution()
    local x = math.max(8, screenWidth - MINI_WIDTH - 20)
    local y = math.min(210, math.max(8, screenHeight - MINI_HEIGHT - 8))
    return x, y
end

local function clampMiniPosition(x, y)
    local screenWidth, screenHeight = getScreenResolution()
    local maxX = math.max(8, screenWidth - MINI_WIDTH - 8)
    local maxY = math.max(8, screenHeight - MINI_HEIGHT - 8)
    x = clampNumber(x, 8, maxX)
    y = clampNumber(y, 8, maxY)
    return x, y
end

local function saveMiniPosition()
    if not miniPositionInitialized then return end
    miniPosX, miniPosY = clampMiniPosition(miniPosX, miniPosY)
    ini.ui.mini = miniEnabled[0]
    ini.ui.mini_x = math.floor(miniPosX + 0.5)
    ini.ui.mini_y = math.floor(miniPosY + 0.5)
    miniPositionDirty = false
    inicfg.save(ini, CONFIG)
end

local function setCurrentWindowPosition(x, y)
    local pos = imgui.ImVec2(x, y)

    -- В актуальном mimgui перегрузка ImGui::SetWindowPos(ImVec2, cond)
    -- экспортируется как SetWindowPosVec2. Оставляем запасной вариант для
    -- старых сборок, в которых она доступна под коротким именем.
    if imgui.SetWindowPosVec2 then
        imgui.SetWindowPosVec2(pos, imgui.Cond.Always)
    elseif imgui.SetWindowPos then
        imgui.SetWindowPos(pos, imgui.Cond.Always)
    end
end

local function processMiniDrag(currentX, currentY)
    imgui.SetCursorPos(imgui.ImVec2(0, 0))
    imgui.InvisibleButton('##PaydayMiniDragArea', imgui.ImVec2(MINI_WIDTH, 30))

    local active = imgui.IsItemActive() and imgui.IsMouseDown(0)
    miniDragging = active

    if not active or not imgui.IsMouseDragging(0, 0.0) then
        return currentX, currentY
    end

    local delta = imgui.GetMouseDragDelta(0, 0.0)
    local dx = tonumber(delta.x) or 0
    local dy = tonumber(delta.y) or 0

    if math.abs(dx) < 0.01 and math.abs(dy) < 0.01 then
        return currentX, currentY
    end

    local nextX, nextY = clampMiniPosition(currentX + dx, currentY + dy)
    setCurrentWindowPosition(nextX, nextY)
    imgui.ResetMouseDragDelta(0)

    miniPositionDirty = true
    return nextX, nextY
end

local function setMiniMoveMode(state)
    state = state == true

    if state then
        if window[0] then
            saveRankInputs()
        end
        miniEnabled[0] = true
        ini.ui.mini = true
        window[0] = false
        miniMoveMode = true
        miniDragging = false
        pcall(function() lockPlayerControl(true) end)
        statusText = 'Перетащи мини-окно мышью и нажми «Готово»'
        sampAddChatMessage('{FFD34E}[PayDay Mini] {FFFFFF}Перетащи окно мышью. Для завершения нажми «Готово», ESC или введи /paymini.', -1)
    else
        miniMoveMode = false
        miniDragging = false
        saveMiniPosition()
        pcall(function() lockPlayerControl(false) end)
        statusText = 'Позиция мини-окна сохранена'
    end
end

local function resetMiniPosition()
    miniPosX, miniPosY = defaultMiniPosition()
    miniPositionInitialized = true
    miniPositionDirty = true
    saveMiniPosition()
    statusText = 'Позиция мини-окна сброшена'
end

local function rankStats()
    local cost = tonumber(ini.rank.cost) or 0
    local baseSalary = tonumber(ini.rank.salary_x1) or 0
    local realSalary = tonumber(ini.stats.salary) or 0
    local salaryReceived = asBool(ini.stats.last_salary_received)
    local deposit = asBool(ini.rank.use_deposit) and (tonumber(ini.stats.deposit_plus) or 0) or 0

    -- Для прогноза сохраняем старое безопасное поведение: если строка зарплаты
    -- не пришла, используем x1. Фактически полученная зарплата при этом остаётся 0.
    local currentSalary = salaryReceived and realSalary > 0 and realSalary or baseSalary
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
        salaryReceived = salaryReceived,
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
    local salaryReceived = asBool(ini.stats.last_salary_received)
    local paydayResult = salaryReceived and 'Начисление успешно'
        or 'Payday учтён без строки зарплаты'
    local salarySuffix = salaryReceived and '' or '  <i>(не распознана)</i>'
    local bonusText = salaryReceived and multiplierText(st.multiplier) or 'не определён'

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
        (salaryReceived and '<DONE>' or '<WARN>') .. ' <b>' .. paydayResult .. '</b>',
        '',
        '<MONEY> <b>ДОХОД</b>',
        '<MID> Зарплата: <b>' .. money(salary) .. '</b>' .. salarySuffix,
        '<MID> Депозит: <b>' .. money(depositPlus) .. '</b>',
        '<MID> Бонус: <b>' .. bonusText .. '</b>',
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
local telegramPollPauseUntil = 0

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
    { command = 'start', description = 'Открыть меню' },
    { command = 'status', description = 'Полный статус и статистика' },
    { command = 'history', description = 'Последние Payday' },
    { command = 'settings', description = 'Состояние настроек' },
    { command = 'help', description = 'Справка' }
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
    elseif telegramBusy and telegramStartedAt > 0 and os.time() - telegramStartedAt >= 20 then
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

    local item = {
        method = 'sendMessage',
        message = message,
        chatId = options.chatId,
        requiresNotifications = requiresNotifications,
        showResult = showResult == true
    }

    -- Пока идёт исходящая отправка, не запускаем новый long polling.
    -- Тест и ответы на команды ставятся вперед очереди, чтобы не ждать
    -- фонового обновления меню бота или обычных уведомлений.
    telegramPollPauseUntil = math.max(telegramPollPauseUntil, os.time() + 3)
    if showResult == true or options.priority == true then
        table.insert(telegramQueue, 1, item)
    else
        table.insert(telegramQueue, item)
    end

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

    -- Не плодим одинаковые setMyCommands: они задерживали тестовые сообщения.
    if telegramCurrent and telegramCurrent.method == 'setMyCommands' then
        return true
    end
    for _, queued in ipairs(telegramQueue) do
        if queued.method == 'setMyCommands' then
            return true
        end
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
        .. '/status — полный статус и статистика'
        .. string.char(10) .. '/history 5 — последние Payday'
        .. string.char(10) .. '/settings — состояние уведомлений и контроля'
        .. string.char(10) .. '/help — эта справка'
        .. string.char(10) .. string.char(10)
        .. '<i>Изменение настроек выполняется только внутри игры.</i>'
end

local function telegramBotStatusMessage()
    local paydayState = lastPaydayCatch > 0
        and elapsedAgoText(lastPaydayCatch)
        or 'ещё не обнаружен'
    local serverState = elapsedAgoText(lastServerActivity)
    local serverClock = lastServerActivity > 0
        and os.date('%H:%M:%S', lastServerActivity)
        or '—'

    return '<DONE> <b>СТАТУС СКРИПТА</b>'
        .. string.char(10) .. '<LINE>'
        .. string.char(10) .. string.char(10)
        .. '<MID> Версия: <b>' .. SCRIPT_VERSION .. '</b>'
        .. string.char(10) .. '<MID> Сессия: <b>' .. sessionDurationText() .. '</b>'
        .. string.char(10) .. '<MID> Последний Payday: <b>' .. paydayState .. '</b>'
        .. string.char(10) .. '<MID> Последняя строка сервера: <b>' .. serverState .. '</b>'
        .. string.char(10) .. '<MID> Время строки: <b>' .. serverClock .. '</b>'
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

local function telegramBotSettingsMessage()
    return '<TIME> <b>НАСТРОЙКИ</b>'
        .. string.char(10) .. '<LINE>'
        .. string.char(10) .. string.char(10)
        .. '<MID> Автоуведомления: <b>' .. (asBool(ini.telegram.enabled) and 'включены' or 'выключены') .. '</b>'
        .. string.char(10) .. '<MID> Команды бота: <b>' .. (telegramCommandsEnabled[0] and 'включены' or 'выключены') .. '</b>'
        .. string.char(10) .. '<END> Контроль Payday: <b>' .. (afkEnabled[0] and 'включён' or 'выключен') .. '</b>'
        .. string.char(10) .. string.char(10)
        .. '<i>Для безопасности изменение настроек доступно только в игре.</i>'
end

local function telegramReply(chatId, message)
    return sendTelegramMessage(message, false, {
        force = true,
        chatId = chatId,
        priority = true
    })
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
    elseif command == 'watch' then
        telegramReply(chatId, telegramBotWatchMessage())
    elseif command == 'version' then
        telegramReply(chatId, '<DIAMOND> <b>Arizona Payday Clean ' .. SCRIPT_VERSION .. '</b>')
    elseif command == 'history' then
        telegramReply(chatId, telegramBotHistoryMessage(argument:match('%d+')))
    elseif command == 'settings' then
        telegramReply(chatId, telegramBotSettingsMessage())
    elseif command == 'watch_on' or command == 'watch_off'
        or command == 'notify_on' or command == 'notify_off'
        or command == 'test' then
        telegramReply(chatId, '<WARN> <b>Удалённое изменение настроек отключено.</b>'
            .. string.char(10) .. 'Используй интерфейс или команды внутри игры.')
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
        and os.time() - telegramPollStartedAt >= 12 then
        telegramPollBusy = false
        telegramPollStartedAt = 0
        if telegramPollResponsePath and doesFileExist(telegramPollResponsePath) then os.remove(telegramPollResponsePath) end
        telegramPollResponsePath = nil
        telegramNextPollAt = os.time() + 10
        telegramLog('getUpdates request timeout')
    end

    if telegramPollBusy
        or telegramBusy
        or #telegramQueue > 0
        or not telegramCommandsEnabled[0]
        or not telegramCredentialsReady()
        or os.time() < telegramNextPollAt
        or os.time() < telegramPollPauseUntil then
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
        .. '&timeout=2&allowed_updates=%5B%22message%22%5D'

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
    local serverState = elapsedAgoText(lastServerActivity)
    local serverClock = lastServerActivity > 0
        and os.date('%H:%M:%S', lastServerActivity)
        or '—'

    return '<WARN> <b>КОНТРОЛЬ PAYDAY</b>'
        .. string.char(10) .. '<LINE>'
        .. string.char(10) .. string.char(10)
        .. 'Payday не обнаружен уже <b>' .. tostring(minutes) .. ' мин.</b>'
        .. string.char(10) .. 'Последняя строка сервера: <b>' .. serverState .. '</b>'
        .. string.char(10) .. 'Время строки: <b>' .. serverClock .. '</b>'
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

local function clearPaydaySignals()
    paydaySignals.bank = false
    paydaySignals.deposit = false
    paydaySignals.az = false
    paydaySignals.salary = false
    paydaySignals.marker = false
end

local function paydaySignalCount()
    local count = 0
    if paydaySignals.bank then count = count + 1 end
    if paydaySignals.deposit then count = count + 1 end
    if paydaySignals.az then count = count + 1 end
    if paydaySignals.salary then count = count + 1 end
    return count
end

local function paydayHasEnoughEvidence()
    if paydaySignals.salary or paydaySignals.marker then
        return true
    end

    if paydaySignalCount() >= 2 then
        return true
    end

    -- Даже если часть банковского чека потерялась, положительное начисление
    -- в одной из строк является достаточным признаком настоящего Payday.
    return (tonumber(ini.stats.bank_plus) or 0) > 0
        or (tonumber(ini.stats.deposit_plus) or 0) > 0
        or (tonumber(ini.stats.az_plus) or 0) > 0
end

local function schedulePaydayFinalize()
    paydaySequence = paydaySequence + 1
    paydayCaptureUpdatedAt = os.time()
    -- Старые 2.3 секунды иногда обрезали поздние строки. Семь секунд дают
    -- банковскому чеку, AZ и талонам успеть прийти, не блокируя игровой поток.
    paydayFinalizeAt = paydayCaptureUpdatedAt + 7
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

    sendTelegramMessage(preview, true, { priority = true })
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

local function beginPaydayCapture(signal)
    local now = os.time()

    if not paydayPending then
        ini.stats.bank_plus = 0
        ini.stats.deposit_plus = 0
        ini.stats.salary = 0
        ini.stats.az_plus = 0
        ini.stats.ticket_plus = 0

        clearPaydaySignals()
        paydayPending = true
        paydayCaptureStartedAt = now

        -- Талон иногда приходит немного раньше банковского чека.
        if recentTicketGain > 0 and now - recentTicketAt <= 12 then
            ini.stats.ticket_plus = recentTicketGain
            recentTicketGain = 0
            recentTicketAt = 0
        end
    end

    if signal and paydaySignals[signal] ~= nil then
        paydaySignals[signal] = true
    end

    schedulePaydayFinalize()
end

local function resetPaydayCapture(reason)
    paydayPending = false
    paydayCaptureStartedAt = 0
    paydayCaptureUpdatedAt = 0
    paydayFinalizeAt = 0
    paydaySequence = paydaySequence + 1
    clearPaydaySignals()

    if reason then
        debugLog('PAYDAY CAPTURE RESET: ' .. tostring(reason))
    end
end

local function updateLastHistoryTickets(delta, balance)
    delta = math.max(0, tonumber(delta) or 0)
    if delta <= 0 or not doesFileExist(HISTORY_FILE) then return false end

    local file = io.open(HISTORY_FILE, 'rb')
    if not file then return false end

    local lines = {}
    for line in file:lines() do table.insert(lines, line) end
    file:close()

    for index = #lines, 2, -1 do
        local parts = historyParts(lines[index])
        if parts[1] == tostring(ini.stats.last_payday or '') and parts[12] ~= nil then
            parts[5] = tostring((tonumber(parts[5]) or 0) + delta)
            parts[9] = tostring(tonumber(balance) or tonumber(parts[9]) or 0)
            lines[index] = table.concat(parts, ';')

            local output = io.open(HISTORY_FILE, 'wb')
            if not output then return false end
            output:write(table.concat(lines, '\r\n'), '\r\n')
            output:close()
            refreshHistoryCache()
            return true
        end
    end

    return false
end

local function parseTicketAmounts(text, nums)
    local source = stripColors(text)

    -- Основной формат Arizona RP:
    -- "Вам был добавлен предмет Талон: +1 AZ Coins (3 шт.)"
    local exactPlus, exactBalance = source:match(
        '[Тт][Аа][Лл][Оо][Нн]%s*:%s*%+%s*(%d+)%s*[Aa][Zz]%s*[Cc][Oo][Ii][Nn][Ss]?%s*%(%s*(%d+)%s*[Шш][Тт]%.?%s*%)'
    )

    local plusRaw = exactPlus
        or source:match('%+%s*(%d+)')
        or source:match('[Тт][Аа][Лл][Оо][Нн]%s*:%s*[%+xX]?%s*(%d+)')
        or source:match('(%d+)%s*[Aa][Zz]%s*[Cc][Oo][Ii][Nn][Ss]?')

    local balanceRaw = exactBalance
        or source:match('%(%s*(%d+)%s*[Шш][Тт]%.?%s*%)')
        or source:match('[Вв][Сс][Ее][Гг][Оо][^%d]*(%d+)')
        or source:match('[Бб][Аа][Лл][Аа][Нн][Сс][^%d]*(%d+)')

    local plus = plusRaw and cleanNumber(plusRaw) or 0
    local balance = balanceRaw and cleanNumber(balanceRaw) or 0

    if plus <= 0 and not balanceRaw and nums and #nums > 0 then
        plus = tonumber(nums[1]) or 0
    end
    if balance <= 0 and nums and #nums > 1 then
        balance = tonumber(nums[#nums]) or 0
    end

    return math.max(0, plus), math.max(0, balance)
end

local function isTicketNotification(text)
    local source = stripColors(text)
    local asciiLower = source:lower()

    -- string.lower не переводит кириллицу CP1251 в нижний регистр.
    -- Поэтому проверяем варианты "Талон" явно.
    local hasTicketWord = hasText(source, 'Талон')
        or hasText(source, 'талон')
        or hasText(source, 'ТАЛОН')

    local hasAzWord = asciiLower:find('az', 1, true) ~= nil
        and (asciiLower:find('coin', 1, true) ~= nil
            or asciiLower:find('coins', 1, true) ~= nil)

    local hasGainMarker = source:find('+', 1, true) ~= nil
        or hasText(source, 'добавлен')
        or hasText(source, 'Добавлен')
        or hasText(source, 'ДОБАВЛЕН')
        or hasText(source, 'получен')
        or hasText(source, 'Получен')
        or hasText(source, 'выдан')
        or hasText(source, 'Выдан')

    return hasTicketWord and hasAzWord and hasGainMarker
end

local function processTicketLine(text, nums, sourceName)
    local now = os.time()
    local nowMs = getGameTimer()
    local cleanText = stripColors(text):gsub('%s+', ' ')
    local plus, balance = parseTicketAmounts(cleanText, nums)
    local previousBalance = tonumber(ini.stats.ticket_balance) or 0

    -- Некоторые варианты уведомления показывают только новый баланс талонов.
    -- Раньше этот резервный расчёт стоял после раннего return и никогда не работал.
    if plus <= 0 and balance > previousBalance then
        plus = balance - previousBalance
    end

    if plus <= 0 then
        debugLog('TICKET PARSE FAILED [' .. tostring(sourceName or 'unknown') .. ']: ' .. cleanText)
        return false
    end

    -- Одна и та же серверная подсказка может одновременно попасть в чат,
    -- GameText и TextDraw. Блокируем только этот короткий межсобытийный дубль.
    local duplicateKey = tostring(plus) .. ':' .. tostring(balance)
    local duplicateElapsed = nowMs - lastTicketAtMs
    if duplicateKey == lastTicketKey
        and duplicateElapsed >= 0 and duplicateElapsed <= TICKET_DUPLICATE_WINDOW_MS then
        debugLog('TICKET CROSS-EVENT DUPLICATE SKIPPED ['
            .. tostring(sourceName or 'unknown') .. ']: ' .. cleanText)
        return false
    end

    lastTicketKey = duplicateKey
    lastTicketAtMs = nowMs

    if balance <= 0 and plus > 0 then
        balance = previousBalance + plus
    end

    if balance > 0 then
        ini.stats.ticket_balance = balance
    end

    ini.stats.total_tickets = (tonumber(ini.stats.total_tickets) or 0) + plus
    session.tickets = session.tickets + plus

    if paydayPending then
        ini.stats.ticket_plus = (tonumber(ini.stats.ticket_plus) or 0) + plus
        schedulePaydayFinalize()
    elseif lastPaydayCatch > 0 and now - lastPaydayCatch <= 12 then
        ini.stats.ticket_plus = (tonumber(ini.stats.ticket_plus) or 0) + plus
        updateLastHistoryTickets(plus, ini.stats.ticket_balance)
    else
        ini.stats.ticket_plus = plus
        if recentTicketGain > 0 and now - recentTicketAt > 12 then
            recentTicketGain = 0
        end
        recentTicketGain = recentTicketGain + plus
        recentTicketAt = now
    end

    inicfg.save(ini, CONFIG)
    statusText = 'Получено талонов AZ: +' .. tostring(plus)
    sampAddChatMessage('{55DD88}[PayDay] {FFFFFF}Талон AZ учтен: +' .. tostring(plus)
        .. ' | Всего: ' .. tostring(ini.stats.total_tickets), -1)
    debugLog('TICKET COUNTED [' .. tostring(sourceName or 'unknown') .. ']:'
        .. ' plus=' .. tostring(plus)
        .. ' balance=' .. tostring(ini.stats.ticket_balance)
        .. ' total=' .. tostring(ini.stats.total_tickets)
        .. ' source=' .. cleanText)
    return true
end

local function tryProcessTicketText(text, sourceName)
    local cleanText = stripColors(text)
    if cleanText == '' or not isTicketNotification(cleanText) then
        return false
    end

    local ok, result = pcall(processTicketLine, cleanText, extractNumbers(cleanText), sourceName)
    if not ok then
        debugLog('TICKET HANDLER ERROR [' .. tostring(sourceName or 'unknown') .. ']: '
            .. tostring(result) .. ' | ' .. cleanText)
        return false
    end
    return result == true
end

local function processPaydayCaptureTimeout()
    if not paydayPending or paydayCaptureStartedAt <= 0 then
        return
    end

    local now = os.time()

    if paydayFinalizeAt > 0 and now >= paydayFinalizeAt and paydayHasEnoughEvidence() then
        paydayPending = false
        paydayCaptureStartedAt = 0
        paydayCaptureUpdatedAt = 0
        paydayFinalizeAt = 0
        markPayday()
        clearPaydaySignals()
        return
    end

    if now - paydayCaptureStartedAt >= 25 then
        if paydayHasEnoughEvidence() then
            paydayPending = false
            paydayCaptureStartedAt = 0
            paydayCaptureUpdatedAt = 0
            paydayFinalizeAt = 0
            markPayday()
            clearPaydaySignals()
        else
            resetPaydayCapture('not enough evidence after 25 seconds')
        end
    end
end

markPayday = function()
    local now = os.time()
    if now - lastPaydayCatch < 10 then
        debugLog('PAYDAY DUPLICATE SKIPPED')
        return
    end
    lastPaydayCatch = now
    afkAlertSent = false

    local salary = tonumber(ini.stats.salary) or 0
    local deposit = tonumber(ini.stats.deposit_plus) or 0
    local az = tonumber(ini.stats.az_plus) or 0
    local tickets = tonumber(ini.stats.ticket_plus) or 0
    local salaryReceived = paydaySignals.salary == true

    ini.stats.last_salary_received = salaryReceived
    ini.stats.last_payday_partial = not salaryReceived
    ini.stats.paydays = (tonumber(ini.stats.paydays) or 0) + 1
    ini.stats.total_salary = (tonumber(ini.stats.total_salary) or 0) + salary
    ini.stats.total_deposit = (tonumber(ini.stats.total_deposit) or 0) + deposit
    ini.stats.total_az = (tonumber(ini.stats.total_az) or 0) + az
    ini.stats.last_payday = os.date('%d.%m.%Y %H:%M:%S')

    session.paydays = session.paydays + 1
    session.salary = session.salary + salary
    session.deposit = session.deposit + deposit
    session.az = session.az + az

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
        elseif salaryReceived then
            statusText = 'PayDay учтен в окупаемости'
        else
            statusText = 'PayDay учтен без строки зарплаты'
        end
    elseif salaryReceived then
        statusText = 'PayDay учтен'
    else
        statusText = 'PayDay учтен без строки зарплаты'
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
        multiplier = salaryReceived and st.multiplier or 1,
        total = salary + deposit
    })

    debugLog('PAYDAY FINALIZED: salary=' .. tostring(salary)
        .. ' salary_received=' .. tostring(salaryReceived)
        .. ' deposit=' .. tostring(deposit)
        .. ' az=' .. tostring(az)
        .. ' tickets=' .. tostring(tickets)
        .. ' signals=' .. tostring(paydaySignalCount()))

    if not salaryReceived then
        sampAddChatMessage('{FFB84D}[PayDay 2.0] {FFFFFF}Payday учтен, но строка зарплаты не пришла. Остальные данные сохранены.', -1)
    end

    if telegramReady() then
        sendTelegramMessage(telegramMessage(), false)
    end
end

function sampev.onServerMessage(color, text)
    text = stripColors(text)
    lastServerActivity = os.time()

    local nums = extractNumbers(text)
    local isPaydayMarker = hasText(text, 'Банковский чек')
        or hasText(text, 'Начисление за PayDay')
        or hasText(text, 'Начисление за Payday')

    local isBankLine = hasText(text, 'Текущая сумма в банке')
        or hasText(text, 'Сумма в банке')
        or hasText(text, 'Банковский счет')
        or hasText(text, 'Банковский счёт')
        or hasText(text, 'Сумма на банковском счете')
        or hasText(text, 'Сумма на банковском счёте')

    local isDepositLine = hasText(text, 'Текущая сумма на депозите')
        or hasText(text, 'Сумма на депозите')
        or hasText(text, 'Депозитный счет')
        or hasText(text, 'Депозитный счёт')
        or hasText(text, 'Баланс депозита')
        or (paydayPending and hasText(text, 'депозите'))

    local isAzBalanceLine = hasText(text, 'Баланс на донат-счет')
        or hasText(text, 'Баланс на донат-счёт')
        or hasText(text, 'Баланс на донат-счете')
        or hasText(text, 'Баланс на донат-счёте')
        or hasText(text, 'Баланс донат-счета')
        or hasText(text, 'Баланс донат-счёта')

    local isTicketLine = isTicketNotification(text)

    local isSalaryLine = hasText(text, 'Общая заработанная плата')
        or hasText(text, 'Общая заработная плата')
        or hasText(text, 'Зарплата организации')
        or hasText(text, 'Начислена зарплата')
        or hasText(text, 'Ваша зарплата')

    if debugEnabled[0] and (paydayPending or isPaydayMarker or isBankLine
        or isDepositLine or isAzBalanceLine or isTicketLine or isSalaryLine) then
        debugLog('SERVER: ' .. text)
    end

    if isTicketLine then
        tryProcessTicketText(text, 'server_message')
    end

    if isPaydayMarker then
        beginPaydayCapture('marker')
        statusText = 'Считываю Payday'
    end

    if isBankLine then
        beginPaydayCapture('bank')
        if nums[1] ~= nil then ini.stats.bank = nums[1] end
        if nums[2] ~= nil then ini.stats.bank_plus = nums[2] end
        statusText = 'Считываю банковский чек'
    end

    if isDepositLine then
        beginPaydayCapture('deposit')
        if nums[1] ~= nil then ini.stats.deposit = nums[1] end
        if nums[2] ~= nil then ini.stats.deposit_plus = nums[2] end
    end

    if isAzBalanceLine then
        beginPaydayCapture('az')
        if nums[1] ~= nil then ini.stats.az_balance = nums[1] end
        if nums[2] ~= nil then ini.stats.az_plus = nums[2] end
    end

    if isSalaryLine then
        beginPaydayCapture('salary')
        if nums[1] ~= nil then
            ini.stats.salary = nums[1]
        else
            ini.stats.salary = 0
        end
    end
end


-- На некоторых сборках Arizona уведомление о предмете приходит не в чат,
-- а через GameText/TextDraw. Эти обработчики используют тот же безопасный
-- парсер и общий антидубль.
function sampev.onDisplayGameText(style, time, text)
    tryProcessTicketText(text, 'game_text')
end

function sampev.onShowTextDraw(id, data)
    if type(data) == 'table' and data.text then
        tryProcessTicketText(data.text, 'textdraw_show')
    end
end

function sampev.onTextDrawSetString(id, text)
    tryProcessTicketText(text, 'textdraw_update')
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, dialogText)
    tryProcessTicketText(title, 'dialog_title')
    tryProcessTicketText(dialogText, 'dialog_text')
end

local function ticketParserSelfTest()
    local sample = 'Вам был добавлен предмет Талон: +1 AZ Coins (3 шт.)'
    local plus, balance = parseTicketAmounts(sample, extractNumbers(sample))
    if plus ~= 1 or balance ~= 3 or not isTicketNotification(sample) then
        print('[Arizona Payday Clean] WARNING: ticket parser self-test failed: '
            .. tostring(plus) .. '/' .. tostring(balance))
        return false
    end
    return true
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
    state = state == true
    if state and miniMoveMode then
        setMiniMoveMode(false)
    end
    if window[0] and not state then
        saveRankInputs()
    end

    window[0] = state

    -- Курсором управляет только mimgui через mainFrame.HideCursor=false.
    -- Дополнительный sampSetCursorMode конфликтовал с ImGui и давал мигание.
    pcall(function()
        lockPlayerControl(state)
    end)
end

local function paydayMiniCommand(argument)
    local action = tostring(argument or ''):match('^%s*(.-)%s*$'):lower()

    if action == 'reset' then
        resetMiniPosition()
        miniEnabled[0] = true
        ini.ui.mini = true
        inicfg.save(ini, CONFIG)
        sampAddChatMessage('{55DD88}[PayDay Mini] {FFFFFF}Позиция мини-окна сброшена.', -1)
    elseif action == 'off' or action == 'hide' then
        if miniMoveMode then setMiniMoveMode(false) end
        miniEnabled[0] = false
        ini.ui.mini = false
        inicfg.save(ini, CONFIG)
        sampAddChatMessage('{FFB84D}[PayDay Mini] {FFFFFF}Мини-окно выключено.', -1)
    elseif action == 'on' or action == 'show' then
        miniEnabled[0] = true
        ini.ui.mini = true
        inicfg.save(ini, CONFIG)
        sampAddChatMessage('{55DD88}[PayDay Mini] {FFFFFF}Мини-окно включено.', -1)
    elseif action == '' or action == 'move' then
        setMiniMoveMode(not miniMoveMode)
    else
        sampAddChatMessage('{FFD34E}[PayDay Mini] {FFFFFF}/paymini — перемещение | /paymini reset | /paymini on | /paymini off', -1)
    end
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
            ini.stats.last_salary_received = true
            ini.stats.last_payday_partial = false
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
    imgui.SetCursorPos(imgui.ImVec2(470, 116))
    if imgui.Button(u8'Переместить мини-окно', imgui.ImVec2(205, 30)) then
        setMiniMoveMode(true)
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
    row('Получено за последний PayDay',
        st.salaryReceived and money(st.realSalary) or 'строка не распознана', 1, 430)
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
    imgui.InputText('##telegram_token', telegramTokenText, ffi.sizeof(telegramTokenText), TOKEN_INPUT_FLAGS)
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


local updater = (function()
    local M = {}
    local bit = require 'bit'
    local scriptPath = thisScript().path
    local apiUrl = 'https://api.github.com/repos/artyom129/Arizona-Payday-Clean/releases/latest'
    local apiFile = CONFIG_DIR .. '\\ArizonaPaydayClean_release.json'
    local downloadFile = CONFIG_DIR .. '\\ArizonaPaydayClean.update.lua'
    local replacementFile = CONFIG_DIR .. '\\ArizonaPaydayClean.installing.lua'
    local backupFile = CONFIG_DIR .. '\\ArizonaPaydayClean.previous.lua'
    local failedFile = CONFIG_DIR .. '\\ArizonaPaydayClean.failed.lua'
    local repositoryPrefix = 'https://github.com/artyom129/Arizona-Payday-Clean/releases/download/'
    -- Один понятный режим вместо трёх зависимых галочек.
    -- Старые параметры INI сохраняются для обратной совместимости.
    local autoUpdate = new.bool(asBool(ini.update.auto_install))
    local statusText = 'Обновления ещё не проверялись'
    local latestVersion = tostring(ini.update.latest_version or SCRIPT_VERSION)
    local latestAsset = nil
    local busy = false
    local finished = nil
    local startedAt = 0
    local requestNumber = 0
    local current = nil
    local queued = nil
    local afterCheck = nil
    local installAfterDownload = false
    local nextAutoCheckAt = os.time() + 8

    local constants = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    }

    local function add32(...)
        local sum = 0
        for index = 1, select('#', ...) do sum = sum + (select(index, ...) or 0) end
        return bit.band(sum, 0xffffffff)
    end

    local function processBlock(state, block)
        local words = {}
        for index = 0, 15 do
            local offset = index * 4 + 1
            words[index] = bit.bor(
                bit.lshift(block:byte(offset), 24),
                bit.lshift(block:byte(offset + 1), 16),
                bit.lshift(block:byte(offset + 2), 8),
                block:byte(offset + 3)
            )
        end
        for index = 16, 63 do
            local v15, v2 = words[index - 15], words[index - 2]
            local s0 = bit.bxor(bit.ror(v15, 7), bit.ror(v15, 18), bit.rshift(v15, 3))
            local s1 = bit.bxor(bit.ror(v2, 17), bit.ror(v2, 19), bit.rshift(v2, 10))
            words[index] = add32(words[index - 16], s0, words[index - 7], s1)
        end
        local a,b,c,d,e,f,g,h = state[1],state[2],state[3],state[4],state[5],state[6],state[7],state[8]
        for index = 0, 63 do
            local s1 = bit.bxor(bit.ror(e, 6), bit.ror(e, 11), bit.ror(e, 25))
            local choice = bit.bxor(bit.band(e, f), bit.band(bit.bnot(e), g))
            local t1 = add32(h, s1, choice, constants[index + 1], words[index])
            local s0 = bit.bxor(bit.ror(a, 2), bit.ror(a, 13), bit.ror(a, 22))
            local majority = bit.bxor(bit.band(a, b), bit.band(a, c), bit.band(b, c))
            local t2 = add32(s0, majority)
            h,g,f,e,d,c,b,a = g,f,e,add32(d,t1),c,b,a,add32(t1,t2)
        end
        state[1],state[2],state[3],state[4] = add32(state[1],a),add32(state[2],b),add32(state[3],c),add32(state[4],d)
        state[5],state[6],state[7],state[8] = add32(state[5],e),add32(state[6],f),add32(state[7],g),add32(state[8],h)
    end

    local function pack32(value)
        return string.char(
            bit.band(bit.rshift(value,24),0xff), bit.band(bit.rshift(value,16),0xff),
            bit.band(bit.rshift(value,8),0xff), bit.band(value,0xff)
        )
    end

    local function sha256File(path)
        local file = io.open(path, 'rb')
        if not file then return nil, 'Не удалось открыть файл для SHA-256.' end
        local state = {0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
        local buffer, totalBytes = '', 0
        while true do
            local chunk = file:read(65536)
            if not chunk then break end
            totalBytes = totalBytes + #chunk
            buffer = buffer .. chunk
            while #buffer >= 64 do processBlock(state, buffer:sub(1,64)); buffer = buffer:sub(65) end
        end
        file:close()
        local totalBits = totalBytes * 8
        local high, low = math.floor(totalBits / 4294967296), totalBits % 4294967296
        local padding = (56 - ((#buffer + 1) % 64)) % 64
        buffer = buffer .. string.char(0x80) .. string.rep(string.char(0), padding) .. pack32(high) .. pack32(low)
        while #buffer >= 64 do processBlock(state, buffer:sub(1,64)); buffer = buffer:sub(65) end
        local result = {}
        for index=1,8 do result[index]=bit.tohex(state[index],8) end
        return table.concat(result)
    end

    local function normalizeVersion(value)
        return tostring(value or ''):gsub('^[vV]',''):match('^(%d+%.%d+%.%d+)')
    end

    local function isNewer(candidate,currentVersion)
        local candidateNormalized = normalizeVersion(candidate)
        local currentNormalized = normalizeVersion(currentVersion)
        if not candidateNormalized or not currentNormalized then return false end
        local ca,cb,cc = candidateNormalized:match('^(%d+)%.(%d+)%.(%d+)$')
        local aa,ab,ac = currentNormalized:match('^(%d+)%.(%d+)%.(%d+)$')
        ca,cb,cc,aa,ab,ac = tonumber(ca),tonumber(cb),tonumber(cc),tonumber(aa),tonumber(ab),tonumber(ac)
        if ca ~= aa then return ca > aa end
        if cb ~= ab then return cb > ab end
        return cc > ac
    end

    local function log(message) print('[Arizona Payday Clean][Updater] ' .. tostring(message or '')) end
    local function readFile(path)
        local file=io.open(path,'rb'); if not file then return nil end
        local data=file:read('*a') or ''; file:close(); return data
    end
    local function validDigest(value)
        if type(value)~='string' then return nil end
        local hash=value:match('^sha256:([0-9a-fA-F]+)$')
        return hash and #hash==64 and hash:lower() or nil
    end

    local function verify(path, expectedVersion, expectedSize, expectedDigest)
        if not doesFileExist(path) then return false,'Скачанный файл не найден.' end
        local data=readFile(path); if not data then return false,'Не удалось прочитать скачанный файл.' end
        if #data<20000 or #data>2097152 then return false,'Подозрительный размер Lua-файла.' end
        expectedSize=tonumber(expectedSize) or 0
        if expectedSize>0 and #data~=expectedSize then return false,'Размер файла не совпал с GitHub Release.' end
        if data:find(string.char(0),1,true) then return false,'В Lua-файле обнаружены нулевые байты.' end
        local declared=data:match("local%s+SCRIPT_VERSION%s*=%s*['\"]([^'\"]+)['\"]")
        if normalizeVersion(declared)~=normalizeVersion(expectedVersion) then return false,'Версия внутри Lua-файла не совпадает с тегом.' end
        if not data:find("script_name('Arizona Payday Clean')",1,true) or not data:find("script_author('Artty')",1,true) then
            return false,'Файл не похож на официальный Arizona Payday Clean.'
        end
        local chunk,syntaxError=loadfile(path); if not chunk then return false,'Синтаксическая ошибка: '..tostring(syntaxError) end
        chunk=nil
        local digest=validDigest(expectedDigest); if not digest then return false,'GitHub не предоставил SHA-256 digest.' end
        local actual,digestError=sha256File(path); if not actual then return false,digestError end
        if actual:lower()~=digest then return false,'SHA-256 скачанного файла не совпал с GitHub.' end
        return true
    end

    local function selectAsset(payload,version)
        if type(payload)~='table' or type(payload.assets)~='table' then return nil,'В Release нет списка файлов.' end
        local normalized=normalizeVersion(version); if not normalized then return nil,'Некорректный тег версии.' end
        local preferred='ArizonaPaydayClean_v'..normalized:gsub('%.','_')..'_Artty.lua'
        local best,bestScore=nil,-1
        for _,asset in ipairs(payload.assets) do
            if type(asset)=='table' then
                local name,url,size=tostring(asset.name or ''),tostring(asset.browser_download_url or ''),tonumber(asset.size) or 0
                local score=-1
                if name=='ArizonaPaydayClean.lua' then score=100
                elseif name==preferred then score=90
                elseif name:match('^ArizonaPaydayClean.*%.lua$') and not name:lower():find('beta',1,true) then score=50 end
                if score>bestScore and url:sub(1,#repositoryPrefix)==repositoryPrefix and size>=20000 and size<=2097152 and validDigest(asset.digest) then
                    best={name=name,url=url,size=size,digest=tostring(asset.digest),version=normalized}; bestScore=score
                end
            end
        end
        return best, best and nil or 'В Release нет подходящего Lua-файла с SHA-256 digest.'
    end

    local function networkBusy() return telegramBusy or telegramPollBusy or #telegramQueue>0 end
    local function queueCheck(showResult,nextAction)
        if busy or queued then
            statusText='Операция обновления уже выполняется'
            if showResult then
                sampAddChatMessage('{FFB84D}[PayDay Update] {FFFFFF}Подожди завершения текущей операции.',-1)
            end
            return false
        end
        afterCheck=nextAction
        queued={kind='check',showResult=showResult==true}
        statusText='Ожидаю проверку GitHub...'
        return true
    end

    local function queueDownload(showResult)
        if busy or queued then
            statusText='Операция обновления уже выполняется'
            if showResult then
                sampAddChatMessage('{FFB84D}[PayDay Update] {FFFFFF}Подожди завершения текущей операции.',-1)
            end
            return false
        end
        if not latestAsset then return queueCheck(showResult,'install') end
        queued={kind='download',showResult=showResult==true,asset=latestAsset}
        statusText='Ожидаю загрузку обновления...'
        return true
    end
    local function clearPending()
        ini.update.pending_version=''; ini.update.pending_digest=''; ini.update.pending_size=0; ini.update.pending_asset=''
        if doesFileExist(downloadFile) then os.remove(downloadFile) end; inicfg.save(ini,CONFIG)
    end

    local function replaceScript(sourcePath,backupPath)
        if doesFileExist(replacementFile) then os.remove(replacementFile) end
        if not copyFile(sourcePath,replacementFile) then return false,'Не удалось подготовить файл установки.' end
        local chunk,syntaxError=loadfile(replacementFile)
        if not chunk then os.remove(replacementFile); return false,'Проверка установки не пройдена: '..tostring(syntaxError) end
        chunk=nil
        if backupPath and doesFileExist(backupPath) then os.remove(backupPath) end
        if backupPath and not copyFile(scriptPath,backupPath) then
            os.remove(replacementFile)
            return false,'Не удалось создать резервную копию.'
        end
        if backupPath then
            local backupChunk,backupError=loadfile(backupPath)
            if not backupChunk then
                os.remove(replacementFile)
                os.remove(backupPath)
                return false,'Резервная копия не прошла проверку: '..tostring(backupError)
            end
            backupChunk=nil
        end
        if not os.remove(scriptPath) then
            os.remove(replacementFile)
            return false,'MoonLoader не разрешил заменить текущий Lua-файл.'
        end
        local renamed,renameError=os.rename(replacementFile,scriptPath)
        if not renamed then
            if backupPath and doesFileExist(backupPath) then copyFile(backupPath,scriptPath) end
            os.remove(replacementFile)
            return false,'Не удалось установить файл: '..tostring(renameError)
        end
        local installedChunk,installedError=loadfile(scriptPath)
        if not installedChunk then
            os.remove(scriptPath)
            if backupPath and doesFileExist(backupPath) then copyFile(backupPath,scriptPath) end
            return false,'Установленный файл не прошёл повторную проверку: '..tostring(installedError)
        end
        installedChunk=nil
        return true
    end

    local function install(showResult)
        local version=tostring(ini.update.pending_version or '')
        if version=='' or not doesFileExist(downloadFile) then
            statusText='Нет скачанного обновления'
            if showResult then sampAddChatMessage('{FFB84D}[PayDay Update] {FFFFFF}Сначала скачай обновление.',-1) end
            return false
        end
        if not isNewer(version,SCRIPT_VERSION) then
            clearPending()
            statusText='Скачанный файл уже не новее установленной версии'
            if showResult then sampAddChatMessage('{FFB84D}[PayDay Update] {FFFFFF}Старый файл обновления удалён.',-1) end
            return false
        end
        local ok,errorText=verify(downloadFile,version,ini.update.pending_size,ini.update.pending_digest)
        if not ok then
            ini.update.last_error=tostring(errorText); statusText='Проверка не пройдена'; clearPending()
            if showResult then sampAddChatMessage('{FF6666}[PayDay Update] {FFFFFF}'..tostring(errorText),-1) end
            return false
        end
        local installed,installError=replaceScript(downloadFile,backupFile)
        if not installed then
            ini.update.last_error=tostring(installError); statusText='Установка не выполнена'; inicfg.save(ini,CONFIG)
            if showResult then sampAddChatMessage('{FF6666}[PayDay Update] {FFFFFF}'..tostring(installError),-1) end
            return false
        end
        ini.update.pending_version=''; ini.update.pending_digest=''; ini.update.pending_size=0; ini.update.pending_asset=''
        ini.update.latest_version=version; ini.update.last_error=''; inicfg.save(ini,CONFIG)
        if doesFileExist(downloadFile) then os.remove(downloadFile) end
        statusText='Установлена версия '..version..'. Перезагрузка...'
        sampAddChatMessage('{55DD88}[PayDay Update] {FFFFFF}Версия '..version..' установлена. Перезагружаю скрипт.',-1)
        lua_thread.create(function() wait(1200); local reloadOk,reloadError=pcall(function() thisScript():reload() end); if not reloadOk then log(reloadError) end end)
        return true
    end

    local function rollback(showResult)
        if not doesFileExist(backupFile) then
            statusText='Резервная копия отсутствует'; if showResult then sampAddChatMessage('{FFB84D}[PayDay Update] {FFFFFF}Предыдущая версия не найдена.',-1) end; return false
        end
        local chunk,syntaxError=loadfile(backupFile)
        if not chunk then statusText='Резервная копия повреждена'; if showResult then sampAddChatMessage('{FF6666}[PayDay Update] {FFFFFF}'..tostring(syntaxError),-1) end; return false end
        chunk=nil
        if doesFileExist(failedFile) then os.remove(failedFile) end
        local ok,errorText=replaceScript(backupFile,failedFile)
        if not ok then statusText='Откат не выполнен'; if showResult then sampAddChatMessage('{FF6666}[PayDay Update] {FFFFFF}'..tostring(errorText),-1) end; return false end
        statusText='Предыдущая версия восстановлена. Перезагрузка...'; sampAddChatMessage('{55DD88}[PayDay Update] {FFFFFF}Предыдущая версия восстановлена.',-1)
        lua_thread.create(function() wait(1200); pcall(function() thisScript():reload() end) end); return true
    end

    local function startRequest(item)
        if not item or networkBusy() then return false end
        requestNumber=requestNumber+1
        local requestId=requestNumber
        local path=item.kind=='check' and apiFile or downloadFile
        local url=item.kind=='check' and apiUrl or item.asset.url
        if doesFileExist(path) then os.remove(path) end
        busy=true; startedAt=os.time(); current=item; current.requestId=requestId; current.path=path
        statusText=item.kind=='check' and 'Проверяю GitHub Release...' or 'Скачиваю обновление...'
        local callOk,result=pcall(downloadUrlToFile,url,path,function(id,status,p1,p2)
            if status~=dlstatus.STATUSEX_ENDDOWNLOAD then return end
            if busy and current and current.requestId==requestId then finished={requestId=requestId,kind=item.kind,path=path,item=item}
            elseif doesFileExist(path) then os.remove(path) end
        end)
        if not callOk or not result then
            if item.kind=='check' then afterCheck=nil else installAfterDownload=false end
            busy=false; startedAt=0; current=nil; if doesFileExist(path) then os.remove(path) end
            statusText='Не удалось запустить запрос GitHub'; ini.update.last_error=tostring(callOk and result or result); inicfg.save(ini,CONFIG); return false
        end
        return true
    end

    local function finishCheck(result)
        local requestedAction=afterCheck
        afterCheck=nil
        local raw=readFile(result.path) or ''; if doesFileExist(result.path) then os.remove(result.path) end
        local payload,decodeError=jsonDecode(raw)
        ini.update.last_check=os.time(); nextAutoCheckAt=os.time()+math.floor((tonumber(ini.update.check_interval_hours) or 6)*3600)
        if not payload then
            local errorText=tostring(decodeError or 'Некорректный JSON.'); ini.update.last_error=errorText; statusText='Ошибка проверки GitHub'; inicfg.save(ini,CONFIG)
            if result.item.showResult then sampAddChatMessage('{FF6666}[PayDay Update] {FFFFFF}'..errorText,-1) end; return
        end
        if payload.message and not payload.tag_name then
            local errorText='GitHub API: '..tostring(payload.message); ini.update.last_error=errorText; statusText='Ошибка GitHub API'; inicfg.save(ini,CONFIG)
            if result.item.showResult then sampAddChatMessage('{FF6666}[PayDay Update] {FFFFFF}'..errorText,-1) end; return
        end
        local latest=normalizeVersion(payload.tag_name)
        if not latest or payload.draft==true or payload.prerelease==true then ini.update.last_error='Некорректный Release.'; statusText='Некорректный GitHub Release'; inicfg.save(ini,CONFIG); return end
        latestVersion=latest; ini.update.latest_version=latest; ini.update.last_error=''
        if not isNewer(latest,SCRIPT_VERSION) then
            latestAsset=nil; installAfterDownload=false; statusText='Установлена последняя версия '..SCRIPT_VERSION; inicfg.save(ini,CONFIG)
            if result.item.showResult then sampAddChatMessage('{55DD88}[PayDay Update] {FFFFFF}Установлена последняя версия '..SCRIPT_VERSION..'.',-1) end; return
        end
        local asset,assetError=selectAsset(payload,latest)
        if not asset then
            ini.update.last_error=tostring(assetError); statusText='Release найден, но файл не подходит'; latestAsset=nil; installAfterDownload=false; inicfg.save(ini,CONFIG)
            if result.item.showResult then sampAddChatMessage('{FF6666}[PayDay Update] {FFFFFF}'..tostring(assetError),-1) end; return
        end
        latestAsset=asset; statusText='Доступна версия '..latest; inicfg.save(ini,CONFIG)
        sampAddChatMessage('{FFD34E}[PayDay Update] {FFFFFF}Доступна версия '..latest..'.',-1)
        local shouldInstall=requestedAction=='install' or autoUpdate[0]
        if shouldInstall then
            installAfterDownload=true
            queueDownload(result.item.showResult)
        end
    end

    local function finishDownload(result)
        local asset=result.item.asset
        local ok,errorText=verify(result.path,asset.version,asset.size,asset.digest)
        if not ok then
            installAfterDownload=false
            if doesFileExist(result.path) then os.remove(result.path) end
            ini.update.last_error=tostring(errorText); statusText='Обновление отклонено проверкой'; inicfg.save(ini,CONFIG)
            if result.item.showResult then sampAddChatMessage('{FF6666}[PayDay Update] {FFFFFF}'..tostring(errorText),-1) end; return
        end
        ini.update.pending_version=asset.version; ini.update.pending_digest=asset.digest; ini.update.pending_size=asset.size; ini.update.pending_asset=asset.name; ini.update.last_error=''; inicfg.save(ini,CONFIG)
        statusText='Версия '..asset.version..' скачана и проверена'
        if result.item.showResult then sampAddChatMessage('{55DD88}[PayDay Update] {FFFFFF}Версия '..asset.version..' скачана и проверена.',-1) end
        local shouldInstall=installAfterDownload or autoUpdate[0]
        installAfterDownload=false
        if shouldInstall then install(false) end
    end

    function M.process()
        if finished then
            local result=finished; finished=nil
            if current and result.requestId==current.requestId then
                busy=false; startedAt=0; current=nil
                if result.kind=='check' then finishCheck(result) else finishDownload(result) end
            elseif result.path and doesFileExist(result.path) then os.remove(result.path) end
        elseif busy and startedAt>0 and os.time()-startedAt>=45 then
            local timedOutKind=current and current.kind or nil
            local path=current and current.path or nil
            if timedOutKind=='check' then afterCheck=nil else installAfterDownload=false end
            busy=false; startedAt=0; current=nil
            if path and doesFileExist(path) then os.remove(path) end
            statusText='Тайм-аут запроса GitHub'; ini.update.last_error=statusText; inicfg.save(ini,CONFIG)
        end
        local now=os.time()
        if autoUpdate[0] and not busy and not queued and now>=nextAutoCheckAt then
            local interval=math.floor((tonumber(ini.update.check_interval_hours) or 6)*3600)
            if now-(tonumber(ini.update.last_check) or 0)>=interval then queueCheck(false,'install')
            else nextAutoCheckAt=(tonumber(ini.update.last_check) or now)+interval end
        end
        if queued and not busy and not networkBusy() then local item=queued; queued=nil; startRequest(item) end
    end

    local function smartUpdate(showResult)
        if busy or queued then
            statusText='Операция обновления уже выполняется'
            if showResult then
                sampAddChatMessage('{FFB84D}[PayDay Update] {FFFFFF}Подожди завершения текущей операции.',-1)
            end
            return false
        end

        local pending=tostring(ini.update.pending_version or '')
        if pending~='' and doesFileExist(downloadFile) then
            if isNewer(pending,SCRIPT_VERSION) then
                return install(showResult)
            end
            clearPending()
        end

        if latestAsset and isNewer(latestAsset.version,SCRIPT_VERSION) then
            installAfterDownload=true
            return queueDownload(showResult)
        end

        return queueCheck(showResult,'install')
    end

    function M.command(argument)
        local action=tostring(argument or ''):match('^%s*(.-)%s*$'):lower()
        if action=='rollback' then
            rollback(true)
        elseif action=='status' then
            sampAddChatMessage('{FFD34E}[PayDay Update] {FFFFFF}'..tostring(statusText),-1)
        else
            smartUpdate(true)
        end
    end

    function M.draw()
        local pending=tostring(ini.update.pending_version or '')
        local lastCheck=tonumber(ini.update.last_check) or 0
        local lastCheckText=lastCheck>0 and os.date('%d.%m.%Y %H:%M:%S',lastCheck) or 'никогда'
        imgui.SetCursorPos(imgui.ImVec2(260,100)); imgui.SetWindowFontScale(1.15); imgui.Text(u8'Обновления'); imgui.SetWindowFontScale(1.0)
        imgui.SetCursorPos(imgui.ImVec2(260,126)); textMuted('Одна кнопка: проверить, скачать, проверить и установить')
        card('update_current',260,160,215,78,'Установлена',SCRIPT_VERSION,2)
        card('update_latest',492,160,215,78,'Последняя на GitHub',tostring(latestVersion),1)
        card('update_pending',724,160,236,78,'Готова к установке',pending~='' and pending or 'нет',pending~='' and 2 or 0)

        beginPanel('update_status',260,254,700,124)
        textMuted('СТАТУС')
        imgui.SetCursorPos(imgui.ImVec2(16,42)); imgui.PushTextWrapPos(665); textValue(statusText,busy and 1 or 0); imgui.PopTextWrapPos()
        imgui.SetCursorPos(imgui.ImVec2(16,90)); textMuted('Последняя проверка: '..lastCheckText)
        endPanel()

        beginPanel('update_simple',260,394,700,112)
        textMuted('РЕЖИМ')
        imgui.SetCursorPos(imgui.ImVec2(16,42))
        if imgui.Checkbox(u8'Автообновление',autoUpdate) then
            ini.update.auto_check=autoUpdate[0]
            ini.update.auto_download=autoUpdate[0]
            ini.update.auto_install=autoUpdate[0]
            nextAutoCheckAt=os.time()+2
            inicfg.save(ini,CONFIG)
        end
        imgui.SameLine(210); textMuted('Проверка раз в 6 часов, SHA-256, резервная копия и откат.')
        imgui.SetCursorPos(imgui.ImVec2(16,76)); textMuted('При выключенной галочке обновление запускается одной кнопкой ниже.')
        endPanel()

        beginPanel('update_actions',260,522,700,114)
        textMuted('ДЕЙСТВИЯ')
        imgui.SetCursorPos(imgui.ImVec2(16,42))
        if imgui.Button(u8'Проверить и обновить',imgui.ImVec2(300,40)) then smartUpdate(true) end
        imgui.SameLine()
        if imgui.Button(u8'Вернуть предыдущую версию',imgui.ImVec2(250,40)) then rollback(true) end
        imgui.SetCursorPos(imgui.ImVec2(16,88)); textMuted('Команда /payupdate делает то же самое, без аргументов.')
        endPanel()
    end

    function M.saveSettings()
        ini.update.auto_check=autoUpdate[0]
        ini.update.auto_download=autoUpdate[0]
        ini.update.auto_install=autoUpdate[0]
    end

    function M.cleanup()
        if current and current.path and doesFileExist(current.path) then os.remove(current.path) end
        if doesFileExist(apiFile) then os.remove(apiFile) end
        if doesFileExist(replacementFile) then os.remove(replacementFile) end
    end

    return M
end)()

local miniFrame = imgui.OnFrame(function()
    local st = rankStats()

    -- Не рисуем мини-окно одновременно с главным меню.
    -- Иначе miniFrame.HideCursor=true и mainFrame.HideCursor=false
    -- каждый кадр спорят между собой, из-за чего курсор мигает при вводе текста.
    return miniEnabled[0] and not window[0]
        and (miniMoveMode or (st.cost > 0 and st.baseSalary > 0))
end, function()
    local st = rankStats()

    local forcePosition = false
    if not miniPositionInitialized then
        if miniPosX < 0 or miniPosY < 0 then
            miniPosX, miniPosY = defaultMiniPosition()
        end
        miniPosX, miniPosY = clampMiniPosition(miniPosX, miniPosY)
        miniPositionInitialized = true
        miniPositionDirty = true
        forcePosition = true
    else
        local safeX, safeY = clampMiniPosition(miniPosX, miniPosY)
        if math.abs(safeX - miniPosX) > 0.5 or math.abs(safeY - miniPosY) > 0.5 then
            miniPosX, miniPosY = safeX, safeY
            miniPositionDirty = true
            forcePosition = true
        end
    end

    if forcePosition then
        imgui.SetNextWindowPos(imgui.ImVec2(miniPosX, miniPosY), imgui.Cond.Always)
    end
    imgui.SetNextWindowSize(imgui.ImVec2(MINI_WIDTH, MINI_HEIGHT), imgui.Cond.Always)
    imgui.Begin('##PaydayMiniWindow', miniEnabled, miniMoveMode and MINI_FLAGS or MINI_PASSIVE_FLAGS)

    local currentPosition = imgui.GetWindowPos()
    if currentPosition then
        local currentX = tonumber(currentPosition.x) or miniPosX
        local currentY = tonumber(currentPosition.y) or miniPosY

        if miniMoveMode then
            currentX, currentY = processMiniDrag(currentX, currentY)
        end

        if math.abs(currentX - miniPosX) > 0.5 or math.abs(currentY - miniPosY) > 0.5 then
            miniPosX, miniPosY = currentX, currentY
            miniPositionDirty = true
        end
    end

    imgui.SetCursorPos(imgui.ImVec2(14, 10))
    textValue(miniMoveMode and (miniDragging and 'ПЕРЕМЕЩЕНИЕ...' or 'ЗАЖМИ И ТАЩИ ЗДЕСЬ') or 'PAYDAY RANK', 1)
    imgui.SetCursorPos(imgui.ImVec2(246, 10))
    textValue(multiplierText(st.multiplier), 2)

    imgui.SetCursorPos(imgui.ImVec2(14, 32))
    imgui.ProgressBar(st.progress, imgui.ImVec2(272, 18), u8(string.format('%.1f%%', st.progress * 100)))

    imgui.SetCursorPos(imgui.ImVec2(14, 58))
    imgui.Text(u8('Осталось: ' .. tostring(st.remainingX1) .. ' ПД x1'))

    imgui.SetCursorPos(imgui.ImVec2(14, 78))
    textMuted('Реально: ' .. tostring(st.remainingReal) .. ' ПД | ' .. money(st.remaining))

    if miniMoveMode then
        imgui.SetCursorPos(imgui.ImVec2(14, 104))
        textMuted('Позиция сохранится')
        imgui.SetCursorPos(imgui.ImVec2(204, 99))
        if imgui.Button(u8'Готово', imgui.ImVec2(82, 24)) then
            setMiniMoveMode(false)
        end
    else
        imgui.SetCursorPos(imgui.ImVec2(14, 104))
        textMuted('/paymini — переместить')
    end

    imgui.End()
end)
miniFrame.HideCursor = true
miniFrame.LockPlayer = false

local mainFrame = imgui.OnFrame(function() return window[0] end, function()
    local sx, sy = getScreenResolution()
    local winW, winH = 1000, 660

    imgui.SetNextWindowPos(imgui.ImVec2(sx / 2, sy / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(winW, winH), imgui.Cond.Always)
    imgui.Begin('##ArizonaPaydayCleanWindow', window, MAIN_FLAGS)

    beginPanel('topbar', 12, 10, 976, 62)
    imgui.SetWindowFontScale(1.22)
    imgui.Text(u8('PAYDAY CENTER ' .. SCRIPT_VERSION))
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
    tabButton('Обновления', 5, 16, 234)

    imgui.SetCursorPos(imgui.ImVec2(16, 278))
    imgui.Separator()
    imgui.SetCursorPos(imgui.ImVec2(16, 296))
    textMuted('СТАТУС')
    imgui.SetCursorPos(imgui.ImVec2(16, 320))
    imgui.PushTextWrapPos(190)
    textValue(statusText, 1)
    imgui.PopTextWrapPos()

    imgui.SetCursorPos(imgui.ImVec2(16, 374))
    textMuted('PayDay: ' .. tostring(ini.stats.paydays))
    imgui.SetCursorPos(imgui.ImVec2(16, 398))
    textMuted('Последний:')
    imgui.SetCursorPos(imgui.ImVec2(16, 420))
    imgui.PushTextWrapPos(190)
    textMuted(tostring(ini.stats.last_payday))
    imgui.PopTextWrapPos()

    local st = rankStats()
    if st.cost > 0 and st.baseSalary > 0 then
        imgui.SetCursorPos(imgui.ImVec2(16, 458))
        imgui.Separator()
        imgui.SetCursorPos(imgui.ImVec2(16, 474))
        if asBool(ini.rank.tracking) then
            textValue('Счетчик активен', 2)
        elseif asBool(ini.rank.completed) then
            textValue('Ранг окуплен', 2)
        else
            textMuted('Счетчик на паузе')
        end

        imgui.SetCursorPos(imgui.ImVec2(16, 500))
        textValue('Осталось: ' .. tostring(st.remainingX1) .. ' ПД x1', 1)
        imgui.SetCursorPos(imgui.ImVec2(16, 524))
        textMuted('Реально: ' .. tostring(st.remainingReal) .. ' ПД')
    end
    endPanel()

    if activeTab == 1 then
        drawBankTab()
    elseif activeTab == 2 then
        drawRankTab()
    elseif activeTab == 3 then
        drawTelegramTab()
    elseif activeTab == 4 then
        drawAnalyticsTab()
    else
        updater.draw()
    end

    imgui.End()
end)
mainFrame.HideCursor = false
mainFrame.LockPlayer = true

function main()
    while not isSampAvailable() do wait(50) end

    setBuffer(rankNumberText, rankNumber[0])
    setBuffer(rankCostText, rankCost[0])
    setBuffer(rankSalaryText, rankSalary[0])
    ensureHistoryFile()
    refreshHistoryCache()

    ticketParserSelfTest()

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
    sampRegisterChatCommand('paymini', paydayMiniCommand)
    sampRegisterChatCommand('payupdate', updater.command)

    print('[Arizona Payday Clean ' .. SCRIPT_VERSION .. '] Main commands: /payday /paytg /paytgtest /paymini /payupdate')

    sampAddChatMessage('{FFD34E}[PayDay ' .. SCRIPT_VERSION .. '] {FFFFFF}Версия ' .. SCRIPT_VERSION .. ' загружена. Настройки сохранены.', -1)

    -- Telegram сохраняет меню команд на своей стороне. На каждом запуске
    -- повторно регистрировать его не нужно: это задерживало первые сообщения.

    local lastMiniState = miniEnabled[0]

    while true do
        wait(0)

        -- Явно разводим режимы курсора: мини-окно скрывает его только
        -- когда главное окно действительно закрыто.
        miniFrame.HideCursor = not miniMoveMode
        miniFrame.LockPlayer = miniMoveMode
        mainFrame.HideCursor = false

        processTelegramTransport()
        processTelegramBotPolling()
        updater.process()

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

        if miniPositionDirty and not miniMoveMode then
            saveMiniPosition()
        end

        if miniMoveMode and isKeyJustPressed(0x1B) then
            setMiniMoveMode(false)
            wait(150)
        elseif window[0] and isKeyJustPressed(0x1B) then
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
            if miniPositionInitialized then
                miniPosX, miniPosY = clampMiniPosition(miniPosX, miniPosY)
                ini.ui.mini_x = math.floor(miniPosX + 0.5)
                ini.ui.mini_y = math.floor(miniPosY + 0.5)
            end
            ini.ui.mini = miniEnabled[0]
            updater.saveSettings()
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
            updater.cleanup()
        end)
    end
end
