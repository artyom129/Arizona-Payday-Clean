local SCRIPT_VERSION = '2.0.25'

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

-- Хранилище защищает накопленные данные независимо от игрового интерфейса.
-- Вся логика собрана в одной таблице, чтобы не упереться в лимит LuaJIT
-- на 200 локальных переменных в основном блоке.
local STORAGE = {
    configBackup = CONFIG_DIR .. '\\ArizonaPaydayClean.backup.ini',
    configBackupOlder = CONFIG_DIR .. '\\ArizonaPaydayClean.backup.previous.ini',
    configPrevious = CONFIG_DIR .. '\\ArizonaPaydayClean.previous.ini',
    configTemp = CONFIG_DIR .. '\\ArizonaPaydayClean.saving.ini',
    configTempName = 'ArizonaPaydayClean.saving.ini',
    legacyDoubleConfig = CONFIG_DIR .. '\\ArizonaPaydayClean.ini.ini',
    historyBackup = CONFIG_DIR .. '\\ArizonaPaydayHistory.backup.csv',
    historyPrevious = CONFIG_DIR .. '\\ArizonaPaydayHistory.previous.csv',
    historyTemp = CONFIG_DIR .. '\\ArizonaPaydayHistory.saving.csv',
    rawIniSave = inicfg.save,
    startupSnapshotDone = false,
    recovered = false,
    recoveredSource = ''
}

function STORAGE.read(path)
    local file = io.open(path, 'rb')
    if not file then return nil end
    local data = file:read('*a') or ''
    file:close()
    return data
end

function STORAGE.copy(sourcePath, destinationPath)
    local data = STORAGE.read(sourcePath)
    if not data then return false end
    local file = io.open(destinationPath, 'wb')
    if not file then return false end
    file:write(data)
    file:close()
    return true
end

function STORAGE.parseIni(path)
    local data = STORAGE.read(path)
    if not data or data == '' then return nil end
    local result, section = {}, nil
    for rawLine in (data .. '\n'):gmatch('(.-)\r?\n') do
        local line = rawLine:match('^%s*(.-)%s*$') or ''
        if line ~= '' and line:sub(1, 1) ~= ';' and line:sub(1, 1) ~= '#' then
            local sectionName = line:match('^%[([^%]]+)%]$')
            if sectionName then
                section = sectionName
                result[section] = result[section] or {}
            elseif section then
                local key, value = line:match('^([^=]+)=(.*)$')
                if key then
                    key = key:match('^%s*(.-)%s*$') or key
                    value = value:match('^%s*(.-)%s*$') or value
                    if (#value >= 2) and ((value:sub(1, 1) == '"' and value:sub(-1) == '"')
                        or (value:sub(1, 1) == "'" and value:sub(-1) == "'")) then
                        value = value:sub(2, -2)
                    end
                    result[section][key] = value
                end
            end
        end
    end
    return next(result) and result or nil
end

function STORAGE.hasConfigData(config)
    if type(config) ~= 'table' then return false end
    local stats = type(config.stats) == 'table' and config.stats or {}
    local rank = type(config.rank) == 'table' and config.rank or {}
    local telegram = type(config.telegram) == 'table' and config.telegram or {}
    local tracked = {
        stats.paydays, stats.bank, stats.deposit, stats.az_balance, stats.ticket_balance,
        stats.total_salary, stats.total_deposit, stats.total_az, stats.total_tickets,
        rank.cost, rank.salary_x1, rank.repaid, rank.caught_paydays
    }
    for _, value in ipairs(tracked) do
        if (tonumber(value) or 0) > 0 then return true end
    end
    return tostring(telegram.token or '') ~= '' or tostring(telegram.chat_id or '') ~= ''
end

function STORAGE.snapshotConfig()
    if STORAGE.startupSnapshotDone then return false end
    STORAGE.startupSnapshotDone = true
    local current = STORAGE.parseIni(CONFIG_PATH)
    if not STORAGE.hasConfigData(current) then return false end

    if STORAGE.hasConfigData(STORAGE.parseIni(STORAGE.configBackup)) then
        STORAGE.copy(STORAGE.configBackup, STORAGE.configBackupOlder)
    end
    return STORAGE.copy(CONFIG_PATH, STORAGE.configBackup)
end

function STORAGE.bool(value)
    return value == true or value == 1 or value == '1' or value == 'true'
end

function STORAGE.timestampValue(value)
    local day, month, year, hour, minute, second = tostring(value or ''):match(
        '^(%d%d)%.(%d%d)%.(%d%d%d%d)%s+(%d%d):(%d%d):(%d%d)$'
    )
    if not day then return 0 end
    return os.time({
        day = tonumber(day), month = tonumber(month), year = tonumber(year),
        hour = tonumber(hour), min = tonumber(minute), sec = tonumber(second)
    }) or 0
end

function STORAGE.configCandidates(target)
    local result = { { data = target, path = 'текущий INI' } }
    local candidates = {
        CONFIG_PATH,
        STORAGE.configBackup,
        STORAGE.configBackupOlder,
        STORAGE.configPrevious,
        STORAGE.configTemp,
        BACKUP_FILE,
        STORAGE.legacyDoubleConfig
    }
    for _, path in ipairs(candidates) do
        local candidate = STORAGE.parseIni(path)
        if STORAGE.hasConfigData(candidate) then
            table.insert(result, {
                data = candidate,
                path = path:match('[^\\]+$') or path
            })
        end
    end
    return result
end

function STORAGE.rankIdentityMatches(config, rankNumber, rankCost, rankStarted)
    local rank = type(config.rank) == 'table' and config.rank or {}
    local number = tonumber(rank.number) or 0
    local cost = tonumber(rank.cost) or 0
    local candidateStarted = tostring(rank.started or '')
    local startedMatches = tostring(rankStarted or '') == '' or tostring(rankStarted) == 'Нет данных'
        or candidateStarted == '' or candidateStarted == 'Нет данных'
        or candidateStarted == tostring(rankStarted)
    return number == rankNumber and cost == rankCost and rankNumber > 0 and rankCost > 0
        and startedMatches
end

function STORAGE.projectedRankRepaid(config, history, rankNumber, rankCost, rankStarted)
    if not STORAGE.rankIdentityMatches(config, rankNumber, rankCost, rankStarted) then return 0 end
    local rank = config.rank or {}
    local stats = config.stats or {}
    local repaid = math.max(0, tonumber(rank.repaid) or 0)
    local lastPayday = STORAGE.timestampValue(stats.last_payday)
    local checkpointTime = lastPayday

    for _, row in ipairs((history or {}).records or {}) do
        if row.rank == rankNumber and row.rankRepaid > repaid
            and row.timestampValue >= checkpointTime then
            repaid = row.rankRepaid
            checkpointTime = row.timestampValue
        end
    end

    -- Проекция нужна только от живого контрольного снимка. Если отсчёт был
    -- выключен или у снимка нет времени Payday, ничего не додумываем.
    if STORAGE.bool(rank.tracking) and checkpointTime > 0 and history then
        local useDeposit = STORAGE.bool(rank.use_deposit)
        for _, row in ipairs(history.records or {}) do
            if row.timestampValue > checkpointTime and row.rank == rankNumber then
                repaid = repaid + row.salary + (useDeposit and row.deposit or 0)
            end
        end
    end
    return math.min(rankCost, repaid)
end

function STORAGE.mergeBestConfig(target, force)
    target.stats = target.stats or {}
    target.rank = target.rank or {}
    target.telegram = target.telegram or {}
    target.ui = target.ui or {}
    target.app = target.app or {}

    local statsReset = not force and (tonumber(target.app.stats_reset_at) or 0) > 0
    local rankReset = not force and (tonumber(target.app.rank_reset_at) or 0) > 0
    local targetHasData = STORAGE.hasConfigData(target)
    local currentParsed = STORAGE.parseIni(CONFIG_PATH)
    local currentConfigValid = type(currentParsed) == 'table'
        and type(currentParsed.stats) == 'table' and type(currentParsed.rank) == 'table'
    local candidates = STORAGE.configCandidates(target)
    local changed, sources = false, {}

    local function remember(item)
        sources[item.path] = true
    end
    local function setIfGreater(section, key, value, item)
        value = tonumber(value) or 0
        local current = tonumber(section[key]) or 0
        if value > current then
            section[key] = value
            changed = true
            remember(item)
        end
    end
    local function fillNumber(section, key, value, item)
        if (tonumber(section[key]) or 0) <= 0 and (tonumber(value) or 0) > 0 then
            section[key] = tonumber(value)
            changed = true
            remember(item)
        end
    end

    if not statsReset then
        for _, item in ipairs(candidates) do
            local stats = item.data.stats or {}
            for _, key in ipairs({ 'paydays', 'total_salary', 'total_deposit', 'total_az', 'total_tickets' }) do
                setIfGreater(target.stats, key, stats[key], item)
            end
        end
    end

    -- Нулевой баланс может быть настоящим результатом траты. Поэтому старые
    -- балансы поднимаются только при явном восстановлении либо когда весь текущий
    -- конфиг пуст/повреждён, а не при каждом обычном запуске.
    if force or (not targetHasData and not currentConfigValid) then
        for _, item in ipairs(candidates) do
            local stats = item.data.stats or {}
            for _, key in ipairs({ 'bank', 'deposit', 'az_balance', 'ticket_balance' }) do
                fillNumber(target.stats, key, stats[key], item)
            end
        end
    end

    -- Настройки ранга восстанавливаются единым комплектом только когда цена
    -- исчезла. Иначе номер из дефолта нельзя смешивать с ценой старой копии.
    if (tonumber(target.rank.cost) or 0) <= 0 then
        local bestItem, bestRepaid = nil, -1
        for _, item in ipairs(candidates) do
            local rank = item.data.rank or {}
            local cost = tonumber(rank.cost) or 0
            local repaid = tonumber(rank.repaid) or 0
            if cost > 0 and repaid > bestRepaid then
                bestItem, bestRepaid = item, repaid
            end
        end
        if bestItem then
            local rank = bestItem.data.rank or {}
            for _, key in ipairs({ 'number', 'cost', 'salary_x1', 'use_deposit', 'tracking',
                'repaid', 'caught_paydays', 'started', 'completed' }) do
                if rank[key] ~= nil then target.rank[key] = rank[key] end
            end
            changed = true
            remember(bestItem)
        end
    else
        for _, item in ipairs(candidates) do
            local rank = item.data.rank or {}
            if STORAGE.rankIdentityMatches(item.data, tonumber(target.rank.number) or 0,
                tonumber(target.rank.cost) or 0, target.rank.started) then
                fillNumber(target.rank, 'salary_x1', rank.salary_x1, item)
            end
        end
    end

    if not rankReset then
        local rankNumber = tonumber(target.rank.number) or 0
        local rankCost = tonumber(target.rank.cost) or 0
        local rankStarted = tostring(target.rank.started or '')
        local history = STORAGE.historySummary(HISTORY_FILE)
        for _, item in ipairs(candidates) do
            if STORAGE.rankIdentityMatches(item.data, rankNumber, rankCost, rankStarted) then
                local projected = STORAGE.projectedRankRepaid(item.data, history, rankNumber, rankCost, rankStarted)
                setIfGreater(target.rank, 'repaid', projected, item)
                setIfGreater(target.rank, 'caught_paydays', (item.data.rank or {}).caught_paydays, item)
                if tostring(target.rank.started or '') == '' or tostring(target.rank.started) == 'Нет данных' then
                    local started = tostring((item.data.rank or {}).started or '')
                    if started ~= '' and started ~= 'Нет данных' then
                        target.rank.started = started
                        changed = true
                        remember(item)
                    end
                end
            end
        end
        if rankCost > 0 and (tonumber(target.rank.repaid) or 0) >= rankCost then
            target.rank.repaid = rankCost
            target.rank.completed = true
            target.rank.tracking = false
        end
    end

    -- Удалённый пользователем token нельзя тайно возвращать из старой копии.
    -- Секрет восстанавливается только при ручном /payrecover или пустом конфиге.
    for _, item in ipairs(candidates) do
        local telegram = item.data.telegram or {}
        if (force or (not targetHasData and not currentConfigValid))
            and tostring(target.telegram.token or '') == ''
            and tostring(telegram.token or '') ~= '' then
            target.telegram.token = telegram.token
            target.telegram.chat_id = telegram.chat_id or target.telegram.chat_id
            target.telegram.enabled = telegram.enabled
            changed = true
            remember(item)
        end
        if target.ui.mini == nil and (item.data.ui or {}).mini ~= nil then
            target.ui.mini = item.data.ui.mini
            changed = true
            remember(item)
        end
    end

    if changed then
        local names = {}
        for name in pairs(sources) do table.insert(names, name) end
        table.sort(names)
        STORAGE.recovered = true
        STORAGE.recoveredSource = table.concat(names, ', ')
    end
    return changed
end

function STORAGE.historySummary(path)
    local data = STORAGE.read(path)
    local result = {
        rows = 0, salary = 0, deposit = 0, az = 0, tickets = 0,
        last = nil, records = {}, size = data and #data or 0,
        malformed = 0, checkpoints = 0
    }
    if not data or data == '' then return result end

    local firstLine = true
    for line in (data .. '\n'):gmatch('(.-)\r?\n') do
        local isHeader = firstLine and line:find('^timestamp;', 1, false) ~= nil
        firstLine = false
        if not isHeader and line ~= '' then
            local parts = {}
            for value in (line .. ';'):gmatch('(.-);') do table.insert(parts, value) end
            if parts[1] and parts[1] ~= '' and parts[12] ~= nil then
                result.rows = result.rows + 1
                result.salary = result.salary + (tonumber(parts[2]) or 0)
                result.deposit = result.deposit + (tonumber(parts[3]) or 0)
                result.az = result.az + (tonumber(parts[4]) or 0)
                result.tickets = result.tickets + (tonumber(parts[5]) or 0)
                result.last = parts
                if parts[13] ~= nil and tonumber(parts[13]) ~= nil then
                    result.checkpoints = result.checkpoints + 1
                end
                table.insert(result.records, {
                    timestamp = parts[1],
                    timestampValue = STORAGE.timestampValue(parts[1]),
                    salary = tonumber(parts[2]) or 0,
                    deposit = tonumber(parts[3]) or 0,
                    az = tonumber(parts[4]) or 0,
                    tickets = tonumber(parts[5]) or 0,
                    rank = tonumber(parts[10]) or 0,
                    rankRepaid = tonumber(parts[13]) or 0
                })
            elseif line ~= '' then
                result.malformed = result.malformed + 1
            end
        end
    end
    return result
end

function STORAGE.historyIsBetter(candidate, current)
    candidate = candidate or {}
    current = current or {}
    if (candidate.rows or 0) ~= (current.rows or 0) then
        return (candidate.rows or 0) > (current.rows or 0)
    end
    if (candidate.malformed or 0) ~= (current.malformed or 0) then
        return (candidate.malformed or 0) < (current.malformed or 0)
    end
    if (candidate.checkpoints or 0) ~= (current.checkpoints or 0) then
        return (candidate.checkpoints or 0) > (current.checkpoints or 0)
    end
    return (candidate.size or 0) > (current.size or 0)
end

function STORAGE.snapshotHistory()
    local current = STORAGE.historySummary(HISTORY_FILE)
    local backup = STORAGE.historySummary(STORAGE.historyBackup)
    if STORAGE.historyIsBetter(current, backup) then
        return current.rows > 0 and STORAGE.copy(HISTORY_FILE, STORAGE.historyBackup)
    end
    return false
end

function STORAGE.restoreHistory()
    local current = STORAGE.historySummary(HISTORY_FILE)
    local bestPath, best = '', current
    for _, path in ipairs({ STORAGE.historyBackup, STORAGE.historyPrevious, STORAGE.historyTemp }) do
        local candidate = STORAGE.historySummary(path)
        if STORAGE.historyIsBetter(candidate, best) then
            bestPath, best = path, candidate
        end
    end
    if bestPath ~= '' and STORAGE.historyIsBetter(best, current)
        and STORAGE.copy(bestPath, HISTORY_FILE) then
        STORAGE.recovered = true
        STORAGE.recoveredSource = bestPath:match('[^\\]+$') or bestPath
        return true
    end
    return false
end

function STORAGE.replaceHistory(data)
    if doesFileExist(STORAGE.historyTemp) then os.remove(STORAGE.historyTemp) end
    local output = io.open(STORAGE.historyTemp, 'wb')
    if not output then return false end
    output:write(tostring(data or ''))
    output:close()

    if doesFileExist(STORAGE.historyPrevious) then os.remove(STORAGE.historyPrevious) end
    if doesFileExist(HISTORY_FILE) and not os.rename(HISTORY_FILE, STORAGE.historyPrevious) then
        os.remove(STORAGE.historyTemp)
        return false
    end
    if not os.rename(STORAGE.historyTemp, HISTORY_FILE) then
        if doesFileExist(STORAGE.historyPrevious) then os.rename(STORAGE.historyPrevious, HISTORY_FILE) end
        return false
    end
    if doesFileExist(STORAGE.historyPrevious) then os.remove(STORAGE.historyPrevious) end
    STORAGE.snapshotHistory()
    return true
end

function STORAGE.mergeHistoryStats(target, force)
    local summary = STORAGE.historySummary(HISTORY_FILE)
    if summary.rows <= 0 then return false end
    if not force and (tonumber((target.app or {}).stats_reset_at) or 0) > 0 then return false end
    local stats = target.stats or {}
    local currentPaydays = tonumber(stats.paydays) or 0
    local emptyTotals = currentPaydays <= 0
        and (tonumber(stats.total_salary) or 0) <= 0
        and (tonumber(stats.total_deposit) or 0) <= 0
    if not force and not emptyTotals and summary.rows <= currentPaydays then return false end

    target.stats = stats
    stats.paydays = math.max(currentPaydays, summary.rows)
    stats.total_salary = math.max(tonumber(stats.total_salary) or 0, summary.salary)
    stats.total_deposit = math.max(tonumber(stats.total_deposit) or 0, summary.deposit)
    stats.total_az = math.max(tonumber(stats.total_az) or 0, summary.az)
    stats.total_tickets = math.max(tonumber(stats.total_tickets) or 0, summary.tickets)
    if summary.last then
        local historyTime = STORAGE.timestampValue(summary.last[1])
        local currentTime = STORAGE.timestampValue(stats.last_payday)
        local historyIsNewer = historyTime > currentTime
            or (currentTime <= 0 and historyTime > 0)

        if historyIsNewer then
            stats.last_payday = summary.last[1]
            stats.salary = tonumber(summary.last[2]) or 0
            stats.deposit_plus = tonumber(summary.last[3]) or 0
            stats.az_plus = tonumber(summary.last[4]) or 0
            stats.ticket_plus = tonumber(summary.last[5]) or 0
            stats.bank = tonumber(summary.last[6]) or 0
            stats.deposit = tonumber(summary.last[7]) or 0
            stats.az_balance = tonumber(summary.last[8]) or 0
            stats.ticket_balance = tonumber(summary.last[9]) or 0
        elseif historyTime == currentTime and historyTime > 0 then
            -- Одна и та же запись Payday не должна снова затирать уже
            -- восстановленное значение нулём. CSV заполняет только реально
            -- пропавшие поля и только ненулевыми данными этой же записи.
            local samePaydayFields = {
                salary = 2, deposit_plus = 3, az_plus = 4, ticket_plus = 5,
                bank = 6, deposit = 7, az_balance = 8, ticket_balance = 9
            }
            for key, index in pairs(samePaydayFields) do
                local value = tonumber(summary.last[index]) or 0
                if (tonumber(stats[key]) or 0) <= 0 and value > 0 then
                    stats[key] = value
                end
            end
        end
    end
    target.app = target.app or {}
    target.app.stats_reset_at = 0
    STORAGE.recovered = true
    STORAGE.recoveredSource = 'ArizonaPaydayHistory.csv'
    return true
end

function STORAGE.safeIniSave(data, filename)
    if filename ~= CONFIG then return STORAGE.rawIniSave(data, filename) end
    STORAGE.snapshotConfig()
    if doesFileExist(STORAGE.configTemp) then os.remove(STORAGE.configTemp) end

    local ok = pcall(STORAGE.rawIniSave, data, STORAGE.configTempName)
    local parsed = ok and STORAGE.parseIni(STORAGE.configTemp) or nil
    if not parsed or type(parsed.stats) ~= 'table' or type(parsed.rank) ~= 'table' then
        if doesFileExist(STORAGE.configTemp) then os.remove(STORAGE.configTemp) end
        print('[Arizona Payday Clean] WARNING: rejected unsafe INI save.')
        return false
    end

    if doesFileExist(STORAGE.configPrevious) then os.remove(STORAGE.configPrevious) end
    if doesFileExist(CONFIG_PATH) and not os.rename(CONFIG_PATH, STORAGE.configPrevious) then
        os.remove(STORAGE.configTemp)
        return false
    end
    if not os.rename(STORAGE.configTemp, CONFIG_PATH) then
        if doesFileExist(STORAGE.configPrevious) then os.rename(STORAGE.configPrevious, CONFIG_PATH) end
        return false
    end
    if doesFileExist(STORAGE.configPrevious) then os.remove(STORAGE.configPrevious) end
    STORAGE.snapshotConfig()
    return true
end

inicfg.save = STORAGE.safeIniSave

local CONFIG_EXISTED_BEFORE_V2 = doesFileExist(CONFIG_PATH)

-- Снимок делается до inicfg.load и до любой миграции: даже если библиотека
-- не прочитает INI, последняя непустая версия останется восстановимой.
STORAGE.snapshotConfig()
STORAGE.snapshotHistory()

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
        poll_interval = 10
    },
    app = {
        schema = 2,
        backup_done = false,
        debug = false,
        history_limit = 50,
        stats_reset_at = 0,
        rank_reset_at = 0,
        last_payday_signature = '',
        last_payday_signature_at = 0
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
setDefault(ini.telegram, 'poll_interval', 10)
setDefault(ini.app, 'schema', 2)
setDefault(ini.app, 'backup_done', false)
setDefault(ini.app, 'debug', false)
setDefault(ini.app, 'history_limit', 50)
setDefault(ini.app, 'stats_reset_at', 0)
setDefault(ini.app, 'rank_reset_at', 0)
setDefault(ini.app, 'last_payday_signature', '')
setDefault(ini.app, 'last_payday_signature_at', 0)
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

-- Если загрузился пустой/default INI, поднимаем более содержательную копию.
-- Затем восстанавливаем агрегаты из полного CSV, если сам INI уже обнулился.
STORAGE.restoreHistory()
STORAGE.mergeBestConfig(ini)
STORAGE.mergeHistoryStats(ini)

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
ini.telegram.poll_interval = math.min(30, math.max(10, tonumber(ini.telegram.poll_interval) or 10))
ini.app.schema = tonumber(ini.app.schema) or 2
ini.app.debug = ini.app.debug == true or ini.app.debug == 1 or ini.app.debug == '1' or ini.app.debug == 'true'
ini.app.history_limit = math.min(500, math.max(10, tonumber(ini.app.history_limit) or 50))
ini.app.stats_reset_at = math.max(0, tonumber(ini.app.stats_reset_at) or 0)
ini.app.rank_reset_at = math.max(0, tonumber(ini.app.rank_reset_at) or 0)
ini.app.last_payday_signature = tostring(ini.app.last_payday_signature or '')
ini.app.last_payday_signature_at = math.max(0, tonumber(ini.app.last_payday_signature_at) or 0)
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

if not doesFileExist(CONFIG_PATH) or STORAGE.recovered then
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
local lastPaydayCatch = STORAGE.timestampValue(ini.stats.last_payday)
local paydayPending = false
local paydayCaptureStartedAt = 0
local paydayFinalizeAt = 0
local paydayPreviousStats = nil
local paydaySignals = {
    bank = false,
    deposit = false,
    az = false,
    salary = false,
    marker = false,
    values = {
        bank = nil,
        bankPlus = 0,
        deposit = nil,
        depositPlus = 0,
        azBalance = nil,
        azPlus = 0,
        salary = nil,
        ticketPlus = 0,
        ticketBalance = nil
    }
}
local recentTicketGain = 0
local recentTicketAt = 0
local ticketDedupe = {
    plus = 0, balance = 0, atMs = 0, source = '', text = '',
    captureGain = 0, captureAt = 0
}
local TICKET_DUPLICATE_WINDOW_MS = 5000

local W = imgui.WindowFlags or {}
local function flags(...)
    local total = 0
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        if v then total = total + v end
    end
    return total
end

local UI = {
    mainFlags = flags(W.NoDecoration, W.NoMove, W.NoResize, W.NoScrollbar, W.NoScrollWithMouse),
    panelFlags = flags(W.NoScrollbar, W.NoScrollWithMouse),
    tokenInputFlags = ((imgui.InputTextFlags or {}).Password or 0),
    forecastText = new.char[16](tostring(forecastPaydays[0])),
    controlLocked = false,
    rankIdentityNumber = tonumber(ini.rank.number) or 1,
    rankIdentityCost = tonumber(ini.rank.cost) or 0,
    rankIdentityStarted = tostring(ini.rank.started or 'Нет данных'),
    miniStats = nil,
    miniStatsAt = 0,
    shuttingDown = false,
    shutdownSaved = false
}
-- Мини-окно намеренно закреплено в исходной позиции и не принимает ввод.
-- Все параметры собраны в одной таблице, чтобы не превышать жёсткий лимит
-- LuaJIT/MoonLoader в 200 локальных переменных на один блок.
local MINI = {
    width = 300,
    height = 128,
    flags = flags(W.NoDecoration, W.NoMove, W.NoResize, W.NoScrollbar, W.NoScrollWithMouse, W.NoSavedSettings, W.NoInputs)
}
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
    value = value:gsub('{#%x%x%x%x%x%x%x%x}', '')
    value = value:gsub('{#%x%x%x%x%x%x}', '')
    value = value:gsub('{%x%x%x%x%x%x%x%x}', '')
    value = value:gsub('{%x%x%x%x%x%x}', '')
    value = value:gsub('~[%w_]+~', '')
    value = value:gsub('<[^>]->', '')
    value = value:gsub('%c', ' ')
    value = value:gsub('\194\160', ' ')
    value = value:gsub('\160', ' ')
    value = value:gsub('_', ' ')
    return value:gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''
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

-- Сообщения игроков проходят через тот же onServerMessage, что и системные
-- строки сервера. Определяем стандартный формат Nick_Name[ID]: и не даём
-- тексту из чатов запускать парсер Payday или начислений талонов.
local function isPlayerChatMessage(text)
    local source = tostring(text or '')
    source = source:gsub('{#%x%x%x%x%x%x%x%x}', '')
    source = source:gsub('{#%x%x%x%x%x%x}', '')
    source = source:gsub('{%x%x%x%x%x%x%x%x}', '')
    source = source:gsub('{%x%x%x%x%x%x}', '')
    source = source:gsub('~[%w_]+~', '')
    return source:match('[A-Za-z0-9_]+%[%d+%][^:\r\n]-:') ~= nil
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

local HISTORY_HEADER = 'timestamp;salary;deposit;az;tickets;bank;deposit_balance;az_balance;ticket_balance;rank;multiplier;total;rank_repaid'

local function ensureHistoryFile()
    STORAGE.restoreHistory()
    if doesFileExist(HISTORY_FILE) then
        local existing = io.open(HISTORY_FILE, 'rb')
        if existing then
            local size = existing:seek('end') or 0
            existing:close()
            if size > 0 then
                local data = STORAGE.read(HISTORY_FILE) or ''
                local firstLine, remainder = data:match('^([^\r\n]*)(.*)$')
                if firstLine and firstLine:find('^timestamp;', 1, false)
                    and firstLine ~= HISTORY_HEADER then
                    STORAGE.replaceHistory(HISTORY_HEADER .. tostring(remainder or ''))
                end
                return true
            end
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
                    total = tonumber(p[12]) or 0,
                    rankRepaid = tonumber(p[13]) or 0
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
        tostring(record.total or 0),
        tostring(record.rankRepaid or 0)
    }

    STORAGE.snapshotHistory()
    local existing = STORAGE.read(HISTORY_FILE) or (HISTORY_HEADER .. '\r\n')
    if existing ~= '' and not existing:find('[\r\n]$') then
        existing = existing .. '\r\n'
    end
    if not STORAGE.replaceHistory(existing .. table.concat(values, ';') .. '\r\n') then
        debugLog('HISTORY ERROR: atomic append failed')
        return false
    end
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

local function defaultMiniPosition()
    local screenWidth, screenHeight = getScreenResolution()
    local x = math.max(8, screenWidth - MINI.width - 20)
    local y = math.min(210, math.max(8, screenHeight - MINI.height - 8))
    return x, y
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

-- В фоне не держим ImGui-оверлей активным и не пересчитываем окупаемость
-- на каждом кадре. При отсутствии функции MoonLoader безопасно считаем окно активным.
function UI.gameWindowForeground()
    local ok, value = pcall(isGameWindowForeground)
    return not ok or value == true
end

function UI.cachedMiniStats()
    local now = getGameTimer()
    if not UI.miniStats or now < UI.miniStatsAt or now - UI.miniStatsAt >= 500 then
        UI.miniStats = rankStats()
        UI.miniStatsAt = now
    end
    return UI.miniStats
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

local function telegramMessage(useLastKnown)
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

    useLastKnown = useLastKnown == true
    local bankKnown = paydaySignals.bank or useLastKnown
    local depositKnown = paydaySignals.deposit or useLastKnown
    local azKnown = paydaySignals.az or useLastKnown

    local paydayResult = salaryReceived and 'Начисление успешно'
        or 'Payday учтён без строки зарплаты'
    local salaryText = salaryReceived and money(salary) or '$ 0'
    local salarySuffix = salaryReceived and '' or '  <i>(не распознана)</i>'
    local bonusText = salaryReceived and multiplierText(st.multiplier) or 'не определён'

    local bankText = bankKnown
        and ('<b>' .. money(ini.stats.bank) .. '</b>')
        or '<i>не распознан</i>'
    local depositBalanceText = depositKnown
        and ('<b>' .. money(ini.stats.deposit) .. '</b>')
        or '<i>не распознан</i>'

    local azText = azKnown
        and ('<b>' .. formatNumber(azBalance) .. '</b>')
        or '<i>не распознан</i>'
    if azKnown and azPlus > 0 then
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
        '<MID> Зарплата: <b>' .. salaryText .. '</b>' .. salarySuffix,
        '<MID> Депозит: <b>' .. money(depositPlus) .. '</b>',
        '<MID> Бонус: <b>' .. bonusText .. '</b>',
        '<END> Итого: <b>' .. money(totalPayday) .. '</b>',
        '',
        '<BANK> <b>БАЛАНС</b>',
        '<MID> Банк: ' .. bankText,
        '<MID> Депозит: ' .. depositBalanceText,
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
        '<SESSION> Сессия: <b>' .. tostring(session.paydays)
            .. ' Payday  <DOT>  ' .. money(session.salary + session.deposit) .. '</b>',
        '',
        '<TIME> <i>' .. os.date('%d.%m.%Y  <DOT>  %H:%M:%S') .. '</i>'
    }

    if asBool(ini.rank.completed) then
        table.insert(lines, '')
        table.insert(lines, '<DONE> <b>РАНГ ПОЛНОСТЬЮ ОКУПЛЕН</b>')
    elseif not asBool(ini.rank.tracking) then
        table.insert(lines, '')
        table.insert(lines, '<WARN> <b>Отсчёт окупаемости выключен</b>')
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

-- MoonLoader отправляет Telegram-запросы через downloadUrlToFile (GET).
-- Обычный Payday-отчёт отправляем целиком. Только действительно длинные
-- ответы делятся между строками, где HTML-теги уже закрыты.
-- Красивый Payday-отчёт занимает около 2300–2500 encoded-байт.
-- До 3000 байт отправляем его одним запросом. Более длинные ответы
-- (например, большая история) по-прежнему безопасно делятся по строкам.
local TELEGRAM_MAX_ENCODED_TEXT = 3000

local function splitTelegramMessage(message)
    local parts = {}
    local current = ''

    for line in (tostring(message or '') .. string.char(10)):gmatch('(.-)' .. string.char(10)) do
        local candidate = current == '' and line or (current .. string.char(10) .. line)
        if current == '' or #urlEncodeUtf8(candidate) <= TELEGRAM_MAX_ENCODED_TEXT then
            current = candidate
        else
            table.insert(parts, current)
            current = line
        end
    end

    if current ~= '' then table.insert(parts, current) end
    if #parts == 0 then table.insert(parts, tostring(message or '')) end
    return parts
end


local TELEGRAM_BOT_COMMANDS = {
    -- ASCII-описания держат единый setMyCommands GET-запрос коротким.
    { command = 'start', description = 'Open menu' },
    { command = 'status', description = 'Script status' },
    { command = 'stats', description = 'All-time stats' },
    { command = 'today', description = 'Today stats' },
    { command = 'history', description = 'Recent Payday history' },
    { command = 'rank', description = 'Rank payback' },
    { command = 'watch', description = 'Payday monitor' },
    { command = 'settings', description = 'Current settings' },
    { command = 'version', description = 'Script version' },
    { command = 'help', description = 'Command help' }
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
    if UI.shuttingDown then return end

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

        if not UI.shuttingDown
            and telegramBusy
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

    local parts = splitTelegramMessage(message)
    if #telegramQueue + #parts > 20 then
        telegramLog('Queue is full; message dropped.')
        if showResult then
            sampAddChatMessage('{FF6666}[PayDay TG] {FFFFFF}Очередь отправки переполнена.', -1)
        end
        return false
    end

    -- Пока идёт исходящая отправка, не запускаем новый long polling.
    -- Тест и ответы на команды ставятся вперед очереди, чтобы не ждать
    -- фонового обновления меню бота или обычных уведомлений.
    telegramPollPauseUntil = math.max(telegramPollPauseUntil, os.time() + 3)
    local priority = showResult == true or options.priority == true
    local first, last, step = 1, #parts, 1
    if priority then first, last, step = #parts, 1, -1 end

    for index = first, last, step do
        local item = {
            method = 'sendMessage',
            message = parts[index],
            chatId = options.chatId,
            requiresNotifications = requiresNotifications,
            -- Подтверждение показываем после последней части, а не после каждой.
            showResult = showResult == true and index == #parts
        }
        if priority then
            table.insert(telegramQueue, 1, item)
        else
            table.insert(telegramQueue, item)
        end
    end

    if #parts > 1 then
        telegramLog('Long message split into ' .. tostring(#parts) .. ' safe requests.')
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
        .. string.char(10) .. '/stats — общая статистика'
        .. string.char(10) .. '/today — статистика за сегодня'
        .. string.char(10) .. '/history 5 — последние Payday'
        .. string.char(10) .. '/rank — окупаемость ранга'
        .. string.char(10) .. '/watch — контроль пропущенного Payday'
        .. string.char(10) .. '/settings — состояние уведомлений и контроля'
        .. string.char(10) .. '/version — версия скрипта'
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
    if UI.shuttingDown then return end

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
        and os.time() - telegramPollStartedAt >= 15 then
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
        .. '&timeout=5&allowed_updates=%5B%22message%22%5D'

    telegramPollBusy = true
    telegramPollStartedAt = os.time()
    local bootstrap = telegramPollBootstrap

    local ok, result = pcall(downloadUrlToFile, url, responsePath, function(id, status, p1, p2)
        if status ~= dlstatus.STATUSEX_ENDDOWNLOAD then return end
        if not UI.shuttingDown and telegramPollBusy and requestId == telegramPollRequestNumber then
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
    if not afkEnabled[0] or lastPaydayCatch <= 0 or afkAlertSent
        or os.time() - session.startedAt < 60 then
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
    paydaySignals.values = {
        bank = nil,
        bankPlus = 0,
        deposit = nil,
        depositPlus = 0,
        azBalance = nil,
        azPlus = 0,
        salary = nil,
        ticketPlus = 0,
        ticketBalance = nil
    }
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
    local signalCount = paydaySignalCount()
    if paydaySignals.salary or signalCount >= 2 then return true end

    -- Заголовок «Банковский чек» без единой строки данных больше не создаёт
    -- пустой Payday. Заголовка вместе с одним реальным показателем достаточно.
    if paydaySignals.marker and (signalCount >= 1
        or (tonumber(ticketDedupe.captureGain) or 0) > 0) then
        return true
    end

    -- Даже если часть банковского чека потерялась, положительное начисление
    -- в одной из строк является достаточным признаком настоящего Payday.
    return (tonumber(ini.stats.bank_plus) or 0) > 0
        or (tonumber(ini.stats.deposit_plus) or 0) > 0
        or (tonumber(ini.stats.az_plus) or 0) > 0
end

local function schedulePaydayFinalize()
    -- Таймер считается от последней полезной строки, а не от заголовка.
    -- Это не даёт отправить Telegram-отчёт до банка, депозита или зарплаты.
    paydayFinalizeAt = os.time() + 12
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
    -- Тест отправляет тот же шаблон, что и настоящий Payday, одним сообщением.
    sendTelegramMessage(telegramMessage(true), true, { priority = true })
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
        paydayPreviousStats = {
            bank = ini.stats.bank,
            bank_plus = ini.stats.bank_plus,
            deposit = ini.stats.deposit,
            deposit_plus = ini.stats.deposit_plus,
            salary = ini.stats.salary,
            az_balance = ini.stats.az_balance,
            az_plus = ini.stats.az_plus,
            ticket_plus = ini.stats.ticket_plus
        }
        ini.stats.bank_plus = 0
        ini.stats.deposit_plus = 0
        ini.stats.salary = 0
        ini.stats.az_plus = 0
        ini.stats.ticket_plus = 0

        clearPaydaySignals()
        paydayPending = true
        paydayCaptureStartedAt = now

        ticketDedupe.captureGain = 0
        ticketDedupe.captureAt = 0

        -- Талон иногда приходит немного раньше банковского чека.
        if recentTicketGain > 0 and now - recentTicketAt <= 20 then
            ini.stats.ticket_plus = recentTicketGain
            paydaySignals.values.ticketPlus = recentTicketGain
            paydaySignals.values.ticketBalance = tonumber(ini.stats.ticket_balance) or 0
            ticketDedupe.captureGain = recentTicketGain
            ticketDedupe.captureAt = recentTicketAt
            recentTicketGain = 0
            recentTicketAt = 0
        end
    end

    if signal and paydaySignals[signal] ~= nil then
        paydaySignals[signal] = true
    end

    schedulePaydayFinalize()
end

local function restorePaydaySnapshot()
    -- Если захват оказался ложным или дублированным, уже пойманные талоны
    -- возвращаются в короткий буфер и не пропадают из ближайшего Payday.
    if (tonumber(ticketDedupe.captureGain) or 0) > 0 then
        recentTicketGain = recentTicketGain + ticketDedupe.captureGain
        recentTicketAt = math.max(recentTicketAt, ticketDedupe.captureAt or os.time())
        ticketDedupe.captureGain = 0
        ticketDedupe.captureAt = 0
    end

    if not paydayPreviousStats then return end
    for key, value in pairs(paydayPreviousStats) do
        ini.stats[key] = value
    end
    paydayPreviousStats = nil
end

local function resetPaydayCapture(reason)
    restorePaydaySnapshot()
    paydayPending = false
    paydayCaptureStartedAt = 0
    paydayFinalizeAt = 0
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
            ini.app.last_payday_signature = paydaySignals.makeSignature(
                parts[6], parts[7], parts[8], parts[2], parts[3], parts[4], parts[5], parts[9])
            ini.app.last_payday_signature_at = os.time()

            STORAGE.snapshotHistory()
            if not STORAGE.replaceHistory(table.concat(lines, '\r\n') .. '\r\n') then
                debugLog('TICKET HISTORY UPDATE FAILED: atomic replace')
                return false
            end
            refreshHistoryCache()
            return true
        end
    end

    debugLog('TICKET HISTORY UPDATE FAILED: last Payday row not found')
    return false
end

local function parseTicketAmounts(text, nums)
    local source = stripColors(text)
    source = source:gsub('^%s*%[%d%d:%d%d:%d%d%]%s*', '')

    -- Количество берём только между «+» и «AZ Coin(s)», а баланс — только
    -- из числа перед «шт.» внутри скобок. Остальные цифры строки игнорируются.
    local plusRaw = source:match('%+%s*(%d[%d%s%.,]*)%s*[Aa][Zz]%s*%-?%s*[Cc][Oo][Ii][Nn][Ss]?')
    local bracket = source:match('%((.-)%)') or ''
    local balanceRaw = bracket:match('(%d[%d%s%.,]*)%s*[Шш][Тт]%.?')
    local plus = plusRaw and cleanNumber(plusRaw) or 0
    local balance = balanceRaw and cleanNumber(balanceRaw) or 0

    if plus < 0 or plus > 1000000 then plus = 0 end
    if balance < 0 or balance > 1000000000 then balance = 0 end
    if balance > 0 and balance < plus then balance = 0 end
    if plus <= 0 then return 0, 0 end
    return plus, balance
end

local function isTicketNotification(text)
    local source = stripColors(text)
    source = source:gsub('^%s*%[%d%d:%d%d:%d%d%]%s*', '')
    local ticketPattern = '[Тт][Аа][Лл][Оо][Нн]'
    local hasAwardPhrase = hasText(source, 'Вам был добавлен предмет')
        or hasText(source, 'вам был добавлен предмет')
        or hasText(source, 'Вы получили предмет')
        or hasText(source, 'вы получили предмет')
    local hasTicketWord = source:match(ticketPattern) ~= nil
    local plus = parseTicketAmounts(source, nil)

    -- Обычный донат-баланс и сообщения игроков больше не могут выдать
    -- случайные талоны: требуется именно серверная фраза о выдаче предмета.
    return hasAwardPhrase and hasTicketWord and plus > 0
end

local function processTicketLine(text, nums, sourceName)
    local now = os.time()
    local nowMs = tonumber(getGameTimer()) or 0
    local cleanText = stripColors(text)
        :gsub('^%s*%[%d%d:%d%d:%d%d%]%s*', '')
        :gsub('%s+', ' ')
    local plus, balance = parseTicketAmounts(cleanText, nums)
    local previousBalance = math.max(0, tonumber(ini.stats.ticket_balance) or 0)

    if plus <= 0 then
        debugLog('TICKET PARSE FAILED [' .. tostring(sourceName or 'unknown') .. ']: ' .. cleanText)
        return false
    end

    local ticketSource = tostring(sourceName or 'unknown')
    local duplicateElapsed = nowMs - (tonumber(ticketDedupe.atMs) or 0)
    if duplicateElapsed < 0 then duplicateElapsed = math.huge end

    local sameAward = plus == tonumber(ticketDedupe.plus)
    local sameText = cleanText == tostring(ticketDedupe.text or '')
    local crossSource = ticketSource ~= tostring(ticketDedupe.source or '')
    local sameKnownBalance = balance > 0 and balance == tonumber(ticketDedupe.balance)
    local sameSourceReplay = not crossSource and sameText
        and duplicateElapsed <= 500
    local crossSourceReplay = crossSource and sameAward
        and duplicateElapsed <= TICKET_DUPLICATE_WINDOW_MS
        and (balance <= 0 or ticketDedupe.balance <= 0 or sameKnownBalance)
    local staleKnownBalance = balance > 0 and balance == previousBalance
        and sameAward and duplicateElapsed <= 30000
    local repeatedVisual = ticketSource ~= 'server_message' and sameAward and sameText
        and balance <= 0 and duplicateElapsed <= 5000

    if sameAward and (sameSourceReplay or crossSourceReplay
        or staleKnownBalance or repeatedVisual) then
        debugLog('TICKET DUPLICATE SKIPPED [' .. ticketSource .. ']: ' .. cleanText)
        return false
    end

    -- Без серверного баланса допустимо только точное +N к последнему значению.
    -- Разницу между случайным числом и прошлым балансом больше не угадываем.
    if balance <= 0 then balance = previousBalance + plus end

    ticketDedupe.plus = plus
    ticketDedupe.balance = balance
    ticketDedupe.atMs = nowMs
    ticketDedupe.source = ticketSource
    ticketDedupe.text = cleanText

    ini.stats.ticket_balance = balance
    ini.stats.total_tickets = (tonumber(ini.stats.total_tickets) or 0) + plus
    session.tickets = session.tickets + plus

    if paydayPending then
        ini.stats.ticket_plus = (tonumber(ini.stats.ticket_plus) or 0) + plus
        paydaySignals.values.ticketPlus = (tonumber(paydaySignals.values.ticketPlus) or 0) + plus
        paydaySignals.values.ticketBalance = balance
        ticketDedupe.captureGain = (tonumber(ticketDedupe.captureGain) or 0) + plus
        ticketDedupe.captureAt = now
        schedulePaydayFinalize()
    elseif lastPaydayCatch > 0 and now - lastPaydayCatch <= 20 then
        ini.stats.ticket_plus = (tonumber(ini.stats.ticket_plus) or 0) + plus
        updateLastHistoryTickets(plus, ini.stats.ticket_balance)
    else
        if recentTicketGain > 0 and now - recentTicketAt > 20 then
            recentTicketGain = 0
        end
        recentTicketGain = recentTicketGain + plus
        recentTicketAt = now
    end

    inicfg.save(ini, CONFIG)
    statusText = 'Получено талонов AZ: +' .. tostring(plus)
    if debugEnabled[0] then
        sampAddChatMessage('{55DD88}[PayDay Debug] {FFFFFF}Талон AZ учтен: +' .. tostring(plus)
            .. ' | Баланс: ' .. tostring(ini.stats.ticket_balance), -1)
    end
    debugLog('TICKET COUNTED: plus=' .. tostring(plus)
        .. ' balance=' .. tostring(ini.stats.ticket_balance)
        .. ' source=' .. ticketSource .. ' text=' .. cleanText)
    return true
end

local function tryProcessTicketText(text, sourceName)
    local cleanText = stripColors(text)
    if cleanText == '' or not isTicketNotification(cleanText) then return false end

    local ok, result = pcall(processTicketLine, cleanText, nil, sourceName)
    if not ok then
        debugLog('TICKET HANDLER ERROR [' .. tostring(sourceName or 'unknown') .. ']: '
            .. tostring(result) .. ' | ' .. cleanText)
        return false
    end
    return result == true
end

-- Удаляем клиентскую метку времени, затем берём данные после двоеточия
-- в названии показателя. Баланс и начисление разбираются раздельно:
-- сумма до скобок — текущий баланс, сумма внутри скобок — прибавка.
-- Это не позволяет перепутать $47.250.356 с (+$904.545).
function paydaySignals.payload(text)
    local source = stripColors(text)
    source = source:gsub('^%s*%[%d%d:%d%d:%d%d%]%s*', '')
    return source:match('^[^:]-:%s*(.-)%s*$') or source
end

function paydaySignals.firstAmount(value)
    local raw = tostring(value or ''):match('([%+%-]?%s*%d[%d%s%.,]*)')
    if not raw then return nil end
    local amount = cleanNumber(raw)
    if amount < 0 or amount > 9007199254740991 then return nil end
    return amount
end

function paydaySignals.parsePair(text)
    local payload = paydaySignals.payload(text)
    local balancePart, gainPart = payload:match('^(.-)%s*%((.-)%)')
    if not balancePart then
        balancePart, gainPart = payload, ''
    end

    local balance = paydaySignals.firstAmount(balancePart)
    local gain = paydaySignals.firstAmount(gainPart) or 0
    if balance == nil then return nil, nil end
    return balance, gain
end

function paydaySignals.parseSingle(text)
    local payload = paydaySignals.payload(text)
    local beforeBracket = payload:match('^(.-)%s*%(') or payload
    return paydaySignals.firstAmount(beforeBracket)
end

function paydaySignals.makeSignature(bank, deposit, azBalance, salary,
    depositPlus, azPlus, ticketPlus, ticketBalance)
    return table.concat({
        tostring(tonumber(bank) or -1),
        tostring(tonumber(deposit) or -1),
        tostring(tonumber(azBalance) or -1),
        tostring(tonumber(salary) or -1),
        tostring(tonumber(depositPlus) or 0),
        tostring(tonumber(azPlus) or 0),
        tostring(tonumber(ticketPlus) or 0),
        tostring(tonumber(ticketBalance) or -1)
    }, '|')
end

-- Строка, пришедшая сразу после финализации, относится к уже записанному
-- Payday, а не запускает второй Payday. Исправляем последнюю CSV-строку и
-- агрегаты только на фактическую разницу.
function paydaySignals.mergeLate(kind, balance, gain)
    local now = os.time()
    if paydayPending or lastPaydayCatch <= 0 or now - lastPaydayCatch > 25 then return false end

    local file = io.open(HISTORY_FILE, 'rb')
    local lines = {}
    if file then
        for line in file:lines() do table.insert(lines, line) end
        file:close()
    end

    local parts, rowIndex
    for index = #lines, 2, -1 do
        local candidate = historyParts(lines[index])
        if candidate[1] == tostring(ini.stats.last_payday or '') and candidate[12] ~= nil then
            parts, rowIndex = candidate, index
            break
        end
    end

    local delta = 0
    if kind == 'bank' then
        ini.stats.bank = tonumber(balance) or ini.stats.bank
        ini.stats.bank_plus = tonumber(gain) or ini.stats.bank_plus
        if parts then parts[6] = tostring(ini.stats.bank) end
    elseif kind == 'deposit' then
        local old = parts and (tonumber(parts[3]) or 0) or (tonumber(ini.stats.deposit_plus) or 0)
        ini.stats.deposit = tonumber(balance) or ini.stats.deposit
        ini.stats.deposit_plus = tonumber(gain) or ini.stats.deposit_plus
        delta = math.max(0, (tonumber(ini.stats.deposit_plus) or 0) - old)
        ini.stats.total_deposit = (tonumber(ini.stats.total_deposit) or 0) + delta
        session.deposit = session.deposit + delta
        if asBool(ini.rank.use_deposit) and (asBool(ini.rank.tracking) or asBool(ini.rank.completed)) then
            ini.rank.repaid = math.min(((tonumber(ini.rank.cost) or 0) > 0) and tonumber(ini.rank.cost) or math.huge,
                (tonumber(ini.rank.repaid) or 0) + delta)
        end
        if parts then parts[3], parts[7] = tostring(ini.stats.deposit_plus), tostring(ini.stats.deposit) end
    elseif kind == 'az' then
        local old = parts and (tonumber(parts[4]) or 0) or (tonumber(ini.stats.az_plus) or 0)
        ini.stats.az_balance = tonumber(balance) or ini.stats.az_balance
        ini.stats.az_plus = tonumber(gain) or ini.stats.az_plus
        delta = math.max(0, (tonumber(ini.stats.az_plus) or 0) - old)
        ini.stats.total_az = (tonumber(ini.stats.total_az) or 0) + delta
        session.az = session.az + delta
        if parts then parts[4], parts[8] = tostring(ini.stats.az_plus), tostring(ini.stats.az_balance) end
    elseif kind == 'salary' then
        local old = parts and (tonumber(parts[2]) or 0) or (tonumber(ini.stats.salary) or 0)
        ini.stats.salary = tonumber(balance) or ini.stats.salary
        delta = math.max(0, (tonumber(ini.stats.salary) or 0) - old)
        ini.stats.total_salary = (tonumber(ini.stats.total_salary) or 0) + delta
        session.salary = session.salary + delta
        ini.stats.last_salary_received = true
        ini.stats.last_payday_partial = false
        if asBool(ini.rank.tracking) or asBool(ini.rank.completed) then
            ini.rank.repaid = math.min(((tonumber(ini.rank.cost) or 0) > 0) and tonumber(ini.rank.cost) or math.huge,
                (tonumber(ini.rank.repaid) or 0) + delta)
        end
        if parts then parts[2] = tostring(ini.stats.salary) end
    else
        return false
    end

    local cost = tonumber(ini.rank.cost) or 0
    if cost > 0 and (tonumber(ini.rank.repaid) or 0) >= cost then
        ini.rank.repaid = cost
        ini.rank.completed = true
        ini.rank.tracking = false
    end

    if parts then
        parts[11] = tostring(detectMultiplier(tonumber(ini.rank.salary_x1) or 0, tonumber(parts[2]) or 0))
        parts[12] = tostring((tonumber(parts[2]) or 0) + (tonumber(parts[3]) or 0))
        parts[13] = tostring(tonumber(ini.rank.repaid) or tonumber(parts[13]) or 0)
        lines[rowIndex] = table.concat(parts, ';')
        ini.app.last_payday_signature = paydaySignals.makeSignature(
            parts[6], parts[7], parts[8], parts[2], parts[3], parts[4], parts[5], parts[9])
        ini.app.last_payday_signature_at = now
        STORAGE.snapshotHistory()
        if not STORAGE.replaceHistory(table.concat(lines, '\r\n') .. '\r\n') then
            debugLog('LATE PAYDAY HISTORY UPDATE FAILED: ' .. tostring(kind))
        else
            refreshHistoryCache()
        end
    end

    inicfg.save(ini, CONFIG)
    statusText = 'Поздняя строка Payday добавлена: ' .. tostring(kind)
    debugLog('LATE PAYDAY MERGED: kind=' .. tostring(kind) .. ' delta=' .. tostring(delta))
    return true
end

local function processPaydayCaptureTimeout()
    if not paydayPending or paydayCaptureStartedAt <= 0 then
        return
    end

    local now = os.time()

    local signalCount = paydaySignalCount()
    local completeEnough = paydaySignals.salary and paydaySignals.bank and paydaySignals.deposit
    local substantialEnough = signalCount >= 3
        and (paydaySignals.bank or paydaySignals.deposit)
        and (paydaySignals.salary or paydaySignals.marker
            or (paydaySignals.bank and paydaySignals.deposit and paydaySignals.az))

    -- Одна зарплата или две строки баланса больше не завершают Payday рано.
    -- Быстрый отчёт формируется только после полноценного набора данных.
    if paydayFinalizeAt > 0 and now >= paydayFinalizeAt
        and (completeEnough or substantialEnough) and paydayHasEnoughEvidence() then
        paydayPending = false
        paydayCaptureStartedAt = 0
        paydayFinalizeAt = 0
        markPayday()
        clearPaydaySignals()
        return
    end

    if now - paydayCaptureStartedAt >= 40 then
        if paydayHasEnoughEvidence() then
            paydayPending = false
            paydayCaptureStartedAt = 0
            paydayFinalizeAt = 0
            markPayday()
            clearPaydaySignals()
        else
            resetPaydayCapture('not enough evidence after 40 seconds')
        end
    end
end

markPayday = function()
    local now = os.time()
    if now - lastPaydayCatch < 10 then
        restorePaydaySnapshot()
        debugLog('PAYDAY DUPLICATE SKIPPED')
        return
    end

    -- Поздняя повторная строка банковского чека или перезагрузка скрипта не
    -- должны создавать второй Payday. Балансы образуют устойчивую подпись;
    -- через две минуты защита снимается задолго до следующего серверного Payday.
    local captured = paydaySignals.values or {}
    local signature = paydaySignals.makeSignature(
        captured.bank, captured.deposit, captured.azBalance, captured.salary,
        captured.depositPlus, captured.azPlus, captured.ticketPlus, captured.ticketBalance)
    local previousSignature = tostring(ini.app.last_payday_signature or '')
    local previousSignatureAt = tonumber(ini.app.last_payday_signature_at) or 0
    if signature == previousSignature and previousSignatureAt > 0
        and now - previousSignatureAt >= 0 and now - previousSignatureAt <= 120 then
        restorePaydaySnapshot()
        debugLog('PAYDAY PERSISTENT DUPLICATE SKIPPED: ' .. signature)
        return
    end
    lastPaydayCatch = now
    afkAlertSent = false
    ini.app.last_payday_signature = signature
    ini.app.last_payday_signature_at = now
    paydayPreviousStats = nil
    ticketDedupe.captureGain = 0
    ticketDedupe.captureAt = 0

    local salary = math.max(0, tonumber(captured.salary) or 0)
    local deposit = math.max(0, tonumber(captured.depositPlus) or 0)
    local az = math.max(0, tonumber(captured.azPlus) or 0)
    local tickets = math.max(0, tonumber(captured.ticketPlus) or 0)
    local salaryReceived = paydaySignals.salary == true and salary > 0

    -- Последний Payday в INI хранит только данные текущего захвата.
    ini.stats.salary = salary
    ini.stats.deposit_plus = deposit
    ini.stats.az_plus = az
    ini.stats.ticket_plus = tickets

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
        ini.app.rank_reset_at = 0

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
        bank = captured.bank or 0,
        depositBalance = captured.deposit or 0,
        azBalance = captured.azBalance or 0,
        ticketBalance = captured.ticketBalance or ini.stats.ticket_balance or 0,
        rank = ini.rank.number,
        multiplier = salaryReceived and st.multiplier or 1,
        total = salary + deposit,
        rankRepaid = ini.rank.repaid
    })

    debugLog('PAYDAY FINALIZED: salary=' .. tostring(salary)
        .. ' salary_received=' .. tostring(salaryReceived)
        .. ' deposit=' .. tostring(deposit)
        .. ' az=' .. tostring(az)
        .. ' tickets=' .. tostring(tickets)
        .. ' signals=' .. tostring(paydaySignalCount()))

    if not salaryReceived then
        sampAddChatMessage('{FFB84D}[PayDay ' .. SCRIPT_VERSION .. '] {FFFFFF}Payday учтен, но строка зарплаты не пришла. Остальные данные сохранены.', -1)
    end

    if telegramReady() then
        sendTelegramMessage(telegramMessage(false), false)
    end
end

function sampev.onSendCommand(command)
    local normalized = tostring(command or ''):lower():match('^%s*(.-)%s*$') or ''
    if normalized == '/q' or normalized == 'q' or normalized == '/quit' or normalized == 'quit' then
        if UI.beginShutdown then UI.beginShutdown() end
    end
end

function sampev.onServerMessage(color, text)
    local rawText = tostring(text or '')
    text = stripColors(rawText)
    lastServerActivity = os.time()

    -- VIP, обычный, семейный и другие чаты могут содержать текст, похожий
    -- на банковский чек. Такие строки принадлежат игрокам и не должны менять
    -- статистику, дописывать последний Payday или запускать новый захват.
    if isPlayerChatMessage(rawText) then
        if debugEnabled[0] and (hasText(text, 'Банковский чек')
            or hasText(text, 'Сумма в банке')
            or hasText(text, 'Сумма на депозите')
            or hasText(text, 'Баланс на донат-счет')
            or hasText(text, 'Баланс на донат-счёт')
            or hasText(text, 'Зарплата')
            or isTicketNotification(text)) then
            debugLog('PLAYER CHAT FINANCIAL SPOOF IGNORED: ' .. text)
        end
        return
    end

    local isPaydayMarker = hasText(text, 'Банковский чек')
        or hasText(text, 'Начисление за PayDay')
        or hasText(text, 'Начисление за Payday')

    local bankLabel = hasText(text, 'Текущая сумма в банке')
        or hasText(text, 'Сумма в банке')
        or hasText(text, 'Банковский счет')
        or hasText(text, 'Банковский счёт')
        or hasText(text, 'Сумма на банковском счете')
        or hasText(text, 'Сумма на банковском счёте')
    local depositLabel = hasText(text, 'Текущая сумма на депозите')
        or hasText(text, 'Сумма на депозите')
        or hasText(text, 'Депозитный счет')
        or hasText(text, 'Депозитный счёт')
        or hasText(text, 'Баланс депозита')
    local azLabel = hasText(text, 'Баланс на донат-счет')
        or hasText(text, 'Баланс на донат-счёт')
        or hasText(text, 'Баланс на донат-счете')
        or hasText(text, 'Баланс на донат-счёте')
        or hasText(text, 'Баланс донат-счета')
        or hasText(text, 'Баланс донат-счёта')
    local salaryLabel = hasText(text, 'Общая заработанная плата')
        or hasText(text, 'Общая заработная плата')
        or hasText(text, 'Зарплата организации')
        or hasText(text, 'Начислена зарплата')
        or hasText(text, 'Ваша зарплата')

    local bank, bankPlus = nil, nil
    if bankLabel then bank, bankPlus = paydaySignals.parsePair(text) end
    local deposit, depositPlus = nil, nil
    if depositLabel then deposit, depositPlus = paydaySignals.parsePair(text) end
    local azBalance, azPlus = nil, nil
    if azLabel then azBalance, azPlus = paydaySignals.parsePair(text) end
    local salary = salaryLabel and paydaySignals.parseSingle(text) or nil
    local isBankLine = bankLabel and bank ~= nil
        and ((tonumber(bankPlus) or 0) > 0 or paydayPending)
    local isDepositLine = depositLabel and deposit ~= nil
        and ((tonumber(depositPlus) or 0) > 0 or paydayPending)
    local isAzBalanceLine = azLabel and azBalance ~= nil
        and ((tonumber(azPlus) or 0) > 0 or paydayPending)
    local isSalaryLine = salaryLabel and (tonumber(salary) or 0) > 0
    local isTicketLine = isTicketNotification(text)

    if debugEnabled[0] and (paydayPending or isPaydayMarker or isBankLine
        or isDepositLine or isAzBalanceLine or isTicketLine or isSalaryLine) then
        debugLog('SERVER: ' .. text)
    end

    if isTicketLine then tryProcessTicketText(text, 'server_message') end

    if isPaydayMarker then
        if lastPaydayCatch > 0 and os.time() - lastPaydayCatch <= 25 then
            debugLog('LATE PAYDAY MARKER IGNORED')
        else
            beginPaydayCapture('marker')
            statusText = 'Считываю Payday'
        end
    end

    if isBankLine then
        if not paydaySignals.mergeLate('bank', bank, bankPlus) then
            beginPaydayCapture('bank')
            ini.stats.bank = bank
            ini.stats.bank_plus = bankPlus or 0
            paydaySignals.values.bank = bank
            paydaySignals.values.bankPlus = bankPlus or 0
            statusText = 'Считываю банковский чек'
        end
    end

    if isDepositLine then
        if not paydaySignals.mergeLate('deposit', deposit, depositPlus) then
            beginPaydayCapture('deposit')
            ini.stats.deposit = deposit
            ini.stats.deposit_plus = depositPlus or 0
            paydaySignals.values.deposit = deposit
            paydaySignals.values.depositPlus = depositPlus or 0
        end
    end

    if isAzBalanceLine then
        if not paydaySignals.mergeLate('az', azBalance, azPlus) then
            beginPaydayCapture('az')
            ini.stats.az_balance = azBalance
            ini.stats.az_plus = azPlus or 0
            paydaySignals.values.azBalance = azBalance
            paydaySignals.values.azPlus = azPlus or 0
        end
    end

    if isSalaryLine then
        if not paydaySignals.mergeLate('salary', salary, 0) then
            beginPaydayCapture('salary')
            ini.stats.salary = salary
            paydaySignals.values.salary = salary
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
    local cases = {
        { 'Вам был добавлен предмет Талон: +1 AZ Coins (3 шт.)', 1, 3, true },
        { 'Вам был добавлен предмет Талон: +2 AZ Coin (15 шт.)', 2, 15, true },
        { 'Вам был добавлен предмет талон: +1 AZ Coins', 1, 0, true },
        { '{FFFFFF}Вам был добавлен предмет {FFD700}ТАЛОН: +3 AZ Coins (20 шт.)', 3, 20, true },
        { 'Баланс на донат-счет: 3664 AZ (+2 AZ)', 0, 0, false },
        { '[18:00:02] Вам был добавлен предмет @Талон: +1 AZ Coins (9 шт.). Откройте инвентарь.', 1, 9, true },
        { '[18:00:02] Вам был добавлен предмет Гражданский талон (3 шт.). Откройте инвентарь.', 0, 0, false },
        { 'Игрок написал: продам Талон +999 AZ Coins (777 шт.)', 999, 0, false },
        { 'Вам был добавлен предмет Талон: +2 AZ-Coins (11 шт.)', 2, 11, true },
        { 'Вам был добавлен предмет Талон: +1 AZ Coins (баланс 9 шт.)', 1, 9, true },
        { 'Вам был добавлен предмет Талон: +999999999 AZ Coins (9 шт.)', 0, 0, false }
    }

    for index, case in ipairs(cases) do
        local plus, balance = parseTicketAmounts(case[1], nil)
        local detected = isTicketNotification(case[1])
        if plus ~= case[2] or balance ~= case[3] or detected ~= case[4] then
            print('[Arizona Payday Clean] WARNING: ticket parser test #' .. tostring(index)
                .. ' failed: ' .. tostring(plus) .. '/' .. tostring(balance)
                .. '/' .. tostring(detected))
            return false
        end
    end

    local chatCases = {
        { '[VIP чат] Pavel_Eir[258]: | Баланс на донат-счет: 861958 AZ (+105 AZ)', true },
        { '{00AAFF}[VIP ЧАТ] {FFFFFF}Pavel_Eir[258] {FFAA00}: | Баланс на донат-счёте: 861958 AZ (+105 AZ)', true },
        { '[16:30:02] Текущая сумма на депозите: $ 295.391.104 (+$ 689.244)', false },
        { 'Баланс на донат-счет: 1578 AZ (+6 AZ)', false }
    }
    for index, case in ipairs(chatCases) do
        local detected = isPlayerChatMessage(case[1])
        if detected ~= case[2] then
            print('[Arizona Payday Clean] WARNING: player chat filter test #' .. tostring(index)
                .. ' failed: ' .. tostring(detected))
            return false
        end
    end

    local pairCases = {
        { 'Текущая сумма в банке: $ 44.466.721 (+$ 904.545)', 44466721, 904545 },
        { '[16:30:02] Текущая сумма на депозите: $ 295.391.104 (+$ 689.244)', 295391104, 689244 },
        { '[18:00:02] I Текущая сумма в банке: $ 47.250.356 (+$ 904.545)', 47250356, 904545 },
        { '[18:00:02] I Текущая сумма на депозите: $ 297.458.836 (+$ 689.244)', 297458836, 689244 },
        { 'Баланс на донат-счет: 1578 AZ (+6 AZ)', 1578, 6 },
        { 'Текущая сумма в банке: $ 47.250.356 (+$ 904.545) ID 405', 47250356, 904545 },
        { 'Текущая сумма на депозите: $ 0 (+$ 689.244)', 0, 689244 }
    }
    for index, case in ipairs(pairCases) do
        local balance, gain = paydaySignals.parsePair(case[1])
        if balance ~= case[2] or gain ~= case[3] then
            print('[Arizona Payday Clean] WARNING: Payday pair parser test #' .. tostring(index)
                .. ' failed: ' .. tostring(balance) .. '/' .. tostring(gain))
            return false
        end
    end

    if paydaySignals.parseSingle('Общая заработная плата: $ 904.545 (x3)') ~= 904545 then
        print('[Arizona Payday Clean] WARNING: salary parser screenshot test failed')
        return false
    end
    return true
end

local function paydayStatsCommand()
    local income = session.salary + session.deposit
    local average = session.paydays > 0 and math.floor(income / session.paydays) or 0

    sampAddChatMessage('{FFD34E}[PayDay ' .. SCRIPT_VERSION .. '] {FFFFFF}Сессия: ' .. sessionDurationText()
        .. ' | Payday: ' .. tostring(session.paydays), -1)
    sampAddChatMessage('{FFD34E}[PayDay ' .. SCRIPT_VERSION .. '] {FFFFFF}Доход: ' .. money(income)
        .. ' | Средний: ' .. money(average)
        .. ' | AZ: ' .. tostring(session.az)
        .. ' | Талоны: ' .. tostring(session.tickets), -1)
end

local function paydayHistoryCommand()
    refreshHistoryCache()
    if #historyCache == 0 then
        sampAddChatMessage('{FFB84D}[PayDay ' .. SCRIPT_VERSION .. '] {FFFFFF}История пока пуста.', -1)
        return
    end

    sampAddChatMessage('{FFD34E}[PayDay ' .. SCRIPT_VERSION .. '] {FFFFFF}Последние Payday:', -1)
    local first = math.max(1, #historyCache - 4)
    for i = #historyCache, first, -1 do
        local row = historyCache[i]
        sampAddChatMessage('{AAAAAA}' .. tostring(row.timestamp)
            .. ' {FFFFFF}| ' .. money(row.total)
            .. ' | +' .. tostring(row.az) .. ' AZ'
            .. ' | +' .. tostring(row.tickets) .. ' тал.', -1)
    end
end

local function paydayRecoverCommand()
    local changed = STORAGE.restoreHistory()
    if STORAGE.mergeBestConfig(ini, true) then changed = true end
    if STORAGE.mergeHistoryStats(ini, true) then changed = true end

    if changed then
        ini.app.stats_reset_at = 0
        ini.app.rank_reset_at = 0
        rankNumber[0] = tonumber(ini.rank.number) or 1
        rankCost[0] = tonumber(ini.rank.cost) or 0
        rankSalary[0] = tonumber(ini.rank.salary_x1) or 0
        useDeposit[0] = asBool(ini.rank.use_deposit)
        setBuffer(rankNumberText, rankNumber[0])
        setBuffer(rankCostText, rankCost[0])
        setBuffer(rankSalaryText, rankSalary[0])
        UI.rankIdentityNumber = rankNumber[0]
        UI.rankIdentityCost = rankCost[0]
        UI.rankIdentityStarted = tostring(ini.rank.started or 'Нет данных')
        inicfg.save(ini, CONFIG)
        refreshHistoryCache()
        statusText = 'Данные восстановлены'
        sampAddChatMessage('{55DD88}[PayDay Recovery] {FFFFFF}Статистика и история восстановлены. Записей: '
            .. tostring(STORAGE.historySummary(HISTORY_FILE).rows) .. '.', -1)
    else
        sampAddChatMessage('{FFB84D}[PayDay Recovery] {FFFFFF}Подходящая резервная копия не найдена.', -1)
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
    if window[0] and not state then
        saveRankInputs()
    end

    window[0] = state

    -- Курсором управляет mimgui. Управление персонажем меняем только при
    -- реальном переходе состояния, чтобы не оставлять его заблокированным.
    if UI.controlLocked ~= state then
        pcall(function() lockPlayerControl(state) end)
        UI.controlLocked = state
    end
end

local function paydayMiniCommand(argument)
    local action = tostring(argument or ''):match('^%s*(.-)%s*$'):lower()

    if action == 'off' or action == 'hide' then
        miniEnabled[0] = false
        ini.ui.mini = false
        inicfg.save(ini, CONFIG)
        sampAddChatMessage('{FFB84D}[PayDay Mini] {FFFFFF}Мини-окно выключено.', -1)
    elseif action == 'on' or action == 'show' then
        miniEnabled[0] = true
        ini.ui.mini = true
        inicfg.save(ini, CONFIG)
        sampAddChatMessage('{55DD88}[PayDay Mini] {FFFFFF}Мини-окно включено.', -1)
    elseif action == '' then
        miniEnabled[0] = not miniEnabled[0]
        ini.ui.mini = miniEnabled[0]
        inicfg.save(ini, CONFIG)
        local state = miniEnabled[0] and 'включено' or 'выключено'
        sampAddChatMessage('{FFD34E}[PayDay Mini] {FFFFFF}Фиксированное мини-окно ' .. state .. '.', -1)
    else
        sampAddChatMessage('{FFD34E}[PayDay Mini] {FFFFFF}/paymini — показать/скрыть | /paymini on | /paymini off', -1)
    end
end

local function beginPanel(id, x, y, w, h)
    imgui.SetCursorPos(imgui.ImVec2(x, y))
    imgui.BeginChild(id, imgui.ImVec2(w, h), true, UI.panelFlags)
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
    if imgui.InputText('##forecastPaydays', UI.forecastText, ffi.sizeof(UI.forecastText)) then
        forecastPaydays[0] = math.max(1, numberFromBuffer(UI.forecastText))
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
            ini.app.stats_reset_at = os.time()
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
    imgui.SetCursorPos(imgui.ImVec2(470, 124))
    textMuted('Положение фиксировано')
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
            local identityChanged = UI.rankIdentityNumber ~= rankNumber[0]
                or UI.rankIdentityCost ~= rankCost[0]
            saveRankInputs()

            if rankCost[0] > 0 and rankSalary[0] > 0 then
                if tostring(ini.rank.started) == 'Нет данных' or asBool(ini.rank.completed)
                    or identityChanged then
                    ini.rank.repaid = 0
                    ini.rank.caught_paydays = 0
                    ini.rank.started = os.date('%d.%m.%Y %H:%M:%S')
                    ini.rank.completed = false
                    ini.app.rank_reset_at = os.time()
                    UI.rankIdentityNumber = rankNumber[0]
                    UI.rankIdentityCost = rankCost[0]
                    UI.rankIdentityStarted = ini.rank.started
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
            ini.app.rank_reset_at = os.time()
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
    imgui.InputText('##telegram_token', telegramTokenText, ffi.sizeof(telegramTokenText), UI.tokenInputFlags)
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
        if doesFileExist(replacementFile) then pcall(os.remove, replacementFile) end
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
            if not UI.shuttingDown and busy and current and current.requestId==requestId then finished={requestId=requestId,kind=item.kind,path=path,item=item}
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
        if UI.shuttingDown then return end

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

    function M.shutdown()
        requestNumber = requestNumber + 1
        busy = false
        finished = nil
        startedAt = 0
        queued = nil
        afterCheck = nil
        installAfterDownload = false
    end

    function M.cleanup()
        local activePath = current and current.path or nil
        M.shutdown()
        current = nil
        if activePath and doesFileExist(activePath) then pcall(os.remove, activePath) end
        if doesFileExist(apiFile) then pcall(os.remove, apiFile) end
        if doesFileExist(replacementFile) then pcall(os.remove, replacementFile) end
    end

    return M
end)()

local miniFrame = imgui.OnFrame(function()
    if UI.shuttingDown or not miniEnabled[0] or window[0] then return false end
    if not UI.gameWindowForeground() then return false end
    local st = UI.cachedMiniStats()

    -- Не рисуем мини-окно одновременно с главным меню и при свёрнутой игре.
    -- Это убирает постоянный ImGui-рендер и расчёты в фоне.
    return st.cost > 0 and st.baseSalary > 0
end, function()
    local st = UI.cachedMiniStats()
    local miniX, miniY = defaultMiniPosition()
    imgui.SetNextWindowPos(imgui.ImVec2(miniX, miniY), imgui.Cond.Always)
    imgui.SetNextWindowSize(imgui.ImVec2(MINI.width, MINI.height), imgui.Cond.Always)
    imgui.Begin('##PaydayMiniWindow', nil, MINI.flags)

    imgui.SetCursorPos(imgui.ImVec2(14, 10))
    textValue('PAYDAY RANK', 1)
    imgui.SetCursorPos(imgui.ImVec2(246, 10))
    textValue(multiplierText(st.multiplier), 2)

    imgui.SetCursorPos(imgui.ImVec2(14, 32))
    imgui.ProgressBar(st.progress, imgui.ImVec2(272, 18), u8(string.format('%.1f%%', st.progress * 100)))

    imgui.SetCursorPos(imgui.ImVec2(14, 58))
    imgui.Text(u8('Осталось: ' .. tostring(st.remainingX1) .. ' ПД x1'))

    imgui.SetCursorPos(imgui.ImVec2(14, 78))
    textMuted('Реально: ' .. tostring(st.remainingReal) .. ' ПД | ' .. money(st.remaining))

    imgui.SetCursorPos(imgui.ImVec2(14, 104))
    textMuted('/paymini — скрыть')

    imgui.End()
end)
miniFrame.HideCursor = true

local mainFrame = imgui.OnFrame(function() return window[0] and not UI.shuttingDown end, function()
    local sx, sy = getScreenResolution()
    local winW, winH = 1000, 660

    imgui.SetNextWindowPos(imgui.ImVec2(sx / 2, sy / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(winW, winH), imgui.Cond.Always)
    imgui.Begin('##ArizonaPaydayCleanWindow', window, UI.mainFlags)

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
    sampRegisterChatCommand('payrecover', paydayRecoverCommand)
    sampRegisterChatCommand('paydebug', paydayDebugCommand)
    sampRegisterChatCommand('paywatch', paydayWatchCommand)
    sampRegisterChatCommand('payafk', paydayWatchCommand) -- старый псевдоним beta-версии
    sampRegisterChatCommand('paymini', paydayMiniCommand)
    sampRegisterChatCommand('payupdate', updater.command)

    print('[Arizona Payday Clean ' .. SCRIPT_VERSION .. '] Main commands: /payday /paytg /paytgtest /paymini /payrecover /payupdate')

    sampAddChatMessage('{FFD34E}[PayDay ' .. SCRIPT_VERSION .. '] {FFFFFF}Версия ' .. SCRIPT_VERSION .. ' загружена. Настройки сохранены.', -1)
    if STORAGE.recovered then
        sampAddChatMessage('{55DD88}[PayDay Recovery] {FFFFFF}Старые данные восстановлены из '
            .. tostring(STORAGE.recoveredSource or 'резервной копии') .. '.', -1)
    end

    -- Telegram сохраняет меню команд на своей стороне. На каждом запуске
    -- повторно регистрировать его не нужно: это задерживало первые сообщения.

    local lastMiniState = miniEnabled[0]

    while true do
        -- Раньше цикл выполнялся каждый кадр через wait(0), даже в свёрнутой игре.
        -- События SA:MP обрабатываются отдельно, поэтому служебные задачи можно
        -- безопасно опрашивать реже без потери Payday и талонов.
        if window[0] then
            wait(25)
        elseif UI.gameWindowForeground() then
            wait(100)
        else
            wait(500)
        end

        if UI.shuttingDown then break end

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

        if UI.controlLocked and not window[0] then
            pcall(function() lockPlayerControl(false) end)
            UI.controlLocked = false
        end

        if window[0] and isKeyJustPressed(0x1B) then
            setMenuState(false)
            wait(150)
        end
    end
end

function UI.saveShutdownState()
    if UI.shutdownSaved then return end

    syncRankValuesFromText()
    ini.rank.number = rankNumber[0]
    ini.rank.cost = rankCost[0]
    ini.rank.salary_x1 = rankSalary[0]
    ini.rank.use_deposit = useDeposit[0]
    ini.app.debug = debugEnabled[0]
    ini.afk.enabled = afkEnabled[0]
    ini.afk.telegram_alerts = afkTelegramAlerts[0]
    ini.telegram.commands_enabled = telegramCommandsEnabled[0]
    ini.ui.mini = miniEnabled[0]
    updater.saveSettings()
    if inicfg.save(ini, CONFIG) ~= false then
        UI.shutdownSaved = true
    end
end

function UI.beginShutdown()
    if UI.shuttingDown then return end
    UI.shuttingDown = true
    window[0] = false

    telegramRequestNumber = telegramRequestNumber + 1
    telegramPollRequestNumber = telegramPollRequestNumber + 1
    telegramQueue = {}
    telegramBusy = false
    telegramFinished = nil
    telegramStartedAt = 0
    telegramPollBusy = false
    telegramPollFinished = nil
    telegramPollStartedAt = 0
    telegramNextPollAt = math.huge
    telegramPollPauseUntil = math.huge
    updater.shutdown()

    if UI.controlLocked then
        pcall(function() lockPlayerControl(false) end)
        UI.controlLocked = false
    end
end

function onQuitGame()
    UI.beginShutdown()
    pcall(UI.saveShutdownState)
end

function onExitScript(quitGame)
    UI.beginShutdown()
    pcall(UI.saveShutdownState)
end

function onScriptTerminate(script, quitGame)
    if script ~= thisScript() then return end

    UI.beginShutdown()
    pcall(UI.saveShutdownState)
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
