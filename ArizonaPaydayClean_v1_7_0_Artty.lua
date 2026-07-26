local SCRIPT_VERSION = '1.7.0'

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

local ini = inicfg.load({
    stats = {
        bank = 0,
        bank_plus = 0,
        deposit = 0,
        deposit_plus = 0,
        salary = 0,
        az_balance = 0,
        az_plus = 0,
        paydays = 0,
        total_salary = 0,
        total_deposit = 0,
        total_az = 0,
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
        chat_id = ''
    }
}, CONFIG)

if not doesDirectoryExist(getWorkingDirectory() .. '\\config') then
    createDirectory(getWorkingDirectory() .. '\\config')
end

if not doesFileExist(getWorkingDirectory() .. '\\config\\' .. CONFIG) then
    inicfg.save(ini, CONFIG)
end

local function asBool(value)
    return value == true or value == 1 or value == '1' or value == 'true'
end

local new = imgui.new
local window = new.bool(false)
local miniEnabled = new.bool(asBool(ini.ui.mini))
local useDeposit = new.bool(asBool(ini.rank.use_deposit))

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

local function telegramReady()
    return ini.telegram
        and asBool(ini.telegram.enabled)
        and telegramCredentialsValid(ini.telegram.token, ini.telegram.chat_id)
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
    local totalPayday = salary + depositPlus
    local rankNumberValue = tonumber(ini.rank.number) or 1
    local progressPercent = st.progress * 100

    local azText = formatNumber(azBalance)
    if azPlus > 0 then
        azText = azText .. '  <b>+' .. formatNumber(azPlus) .. ' AZ</b>'
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
        '<END> AZ Coins: <b>' .. azText .. '</b>',
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

local function finishTelegramRequest(success, description)
    local item = telegramCurrent

    telegramBusy = false
    telegramCurrent = nil
    telegramFinished = nil
    telegramStartedAt = 0

    if success then
        telegramLog('Message sent successfully.')
        if item and item.showResult then
            sampAddChatMessage('{55DD88}[PayDay TG] {FFFFFF}Сообщение отправлено.', -1)
        end
    else
        telegramLog('Send failed: ' .. tostring(description or 'unknown error'))
        if item and item.showResult then
            sampAddChatMessage('{FF6666}[PayDay TG] {FFFFFF}Не удалось отправить сообщение. Причина записана в moonloader.log.', -1)
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
    if not telegramReady() then
        telegramCurrent = item
        finishTelegramRequest(false, 'Telegram is disabled or not configured.')
        return
    end

    local token = safeTelegramValue(ini.telegram.token)
    local chatId = safeTelegramValue(ini.telegram.chat_id)
    if token == '' or chatId == '' then
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

    local url = 'https://api.telegram.org/bot'
        .. token
        .. '/sendMessage?chat_id='
        .. urlEncodeUtf8(chatId)
        .. '&parse_mode=HTML'
        .. '&disable_web_page_preview=true'
        .. '&text='
        .. urlEncodeUtf8(item.message)

    item.responsePath = responsePath
    item.requestId = requestId
    telegramCurrent = item
    telegramBusy = true
    telegramStartedAt = os.time()

    telegramLog('Starting request #' .. tostring(requestId) .. '.')

    local ok, result = pcall(downloadUrlToFile, url, responsePath, function(id, status, p1, p2)
        if status == dlstatus.STATUSEX_ENDDOWNLOAD
            and telegramBusy
            and telegramCurrent
            and telegramCurrent.requestId == requestId then
            telegramFinished = {
                path = responsePath,
                requestId = requestId
            }
        end
    end)

    if not ok or not result then
        finishTelegramRequest(false, ok and 'downloadUrlToFile returned false or nil.' or tostring(result))
    end
end

local function sendTelegramMessage(message, showResult)
    message = tostring(message or '')
    if message == '' then
        telegramLog('Empty message was not queued.')
        return false
    end

    if not telegramReady() then
        if showResult then
            sampAddChatMessage('{FF6666}[PayDay TG] {FFFFFF}Telegram не настроен. Используй /paytg TOKEN CHAT_ID', -1)
        end
        return false
    end

    if #telegramQueue >= 10 then
        telegramLog('Queue is full; message dropped.')
        if showResult then
            sampAddChatMessage('{FF6666}[PayDay TG] {FFFFFF}Очередь отправки переполнена.', -1)
        end
        return false
    end

    table.insert(telegramQueue, {
        message = message,
        showResult = showResult == true
    })

    processTelegramTransport()
    return true
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
    inicfg.save(ini, CONFIG)

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
    sampAddChatMessage('{55DD88}[PayDay TG] {FFFFFF}Уведомления включены.', -1)
end

local function telegramDisableCommand()
    ini.telegram.enabled = false
    telegramQueue = {}
    inicfg.save(ini, CONFIG)
    sampAddChatMessage('{FFB84D}[PayDay TG] {FFFFFF}Уведомления выключены. Очередь очищена.', -1)
end

markPayday = function()
    local now = os.time()
    if now - lastPaydayCatch < 10 then
        return
    end
    lastPaydayCatch = now

    local salary = tonumber(ini.stats.salary) or 0
    local deposit = tonumber(ini.stats.deposit_plus) or 0
    local az = tonumber(ini.stats.az_plus) or 0

    ini.stats.paydays = (tonumber(ini.stats.paydays) or 0) + 1
    ini.stats.total_salary = (tonumber(ini.stats.total_salary) or 0) + salary
    ini.stats.total_deposit = (tonumber(ini.stats.total_deposit) or 0) + deposit
    ini.stats.total_az = (tonumber(ini.stats.total_az) or 0) + az
    ini.stats.last_payday = os.date('%d.%m.%Y %H:%M:%S')

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

    if telegramReady() then
        sendTelegramMessage(telegramMessage(), false)
    end
end

function sampev.onServerMessage(color, text)
    text = stripColors(text)
    local nums = extractNumbers(text)

    local isBankLine = hasText(text, 'Текущая сумма в банке')
        or hasText(text, 'Сумма в банке')
        or hasText(text, 'Банковский счет')

    if isBankLine then
        -- Повторная строка банковского чека не должна стирать уже считанные части PayDay.
        if not paydayPending then
            ini.stats.bank_plus = 0
            ini.stats.deposit_plus = 0
            ini.stats.salary = 0
            ini.stats.az_plus = 0
        end
        paydayPending = true

        if nums[1] ~= nil then ini.stats.bank = nums[1] end
        if nums[2] ~= nil then ini.stats.bank_plus = nums[2] end
        statusText = 'Считываю банковский чек'
    end

    local isDepositLine = hasText(text, 'Текущая сумма на депозите')
        or hasText(text, 'Сумма на депозите')
        or hasText(text, 'Депозитный счет')
        or (paydayPending and hasText(text, 'депозите'))

    if isDepositLine then
        if nums[1] ~= nil then ini.stats.deposit = nums[1] end
        if nums[2] ~= nil then ini.stats.deposit_plus = nums[2] end
    end

    -- Учитываем только строку баланса донат-счёта.
    -- Сообщения о VIP-талонах тоже содержат "AZ Coins", но это предметы,
    -- поэтому они не должны попадать в статистику обычных AZ.
    local isAzBalanceLine = hasText(text, 'Баланс на донат-счет')
        or hasText(text, 'Баланс на донат-счёт')
        or hasText(text, 'Баланс донат-счета')
        or hasText(text, 'Баланс донат-счёта')

    if isAzBalanceLine then
        if nums[1] ~= nil then ini.stats.az_balance = nums[1] end
        if nums[2] ~= nil then ini.stats.az_plus = nums[2] end
    end

    if hasText(text, 'Общая заработанная плата') or hasText(text, 'Общая заработная плата') or hasText(text, 'Зарплата организации') then
        if nums[1] ~= nil then
            ini.stats.salary = nums[1]
            paydayPending = true
            schedulePaydayFinalize()
        end
    end
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

    beginPanel('stats_panel', 260, 348, 700, 110)
    textMuted('СТАТИСТИКА')
    row('Количество PayDay', tostring(ini.stats.paydays), 0, 420)
    row('Общий доход', money((tonumber(ini.stats.total_salary) or 0) + (tonumber(ini.stats.total_deposit) or 0)), 2, 420)
    row('Получено AZ Coins', tostring(ini.stats.total_az) .. ' AZ', 1, 420)
    endPanel()

    beginPanel('forecast_panel', 260, 476, 700, 78)
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

    imgui.SetCursorPos(imgui.ImVec2(260, 575))
    if imgui.Button(u8'Сбросить статистику', imgui.ImVec2(220, 36)) then
        ini.stats.paydays = 0
        ini.stats.total_salary = 0
        ini.stats.total_deposit = 0
        ini.stats.total_az = 0
        ini.stats.last_payday = 'Нет данных'
        inicfg.save(ini, CONFIG)
        statusText = 'Статистика сброшена'
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

    if imgui.Button(u8'Сброс прогресса', imgui.ImVec2(170, 36)) then
        ini.rank.tracking = false
        ini.rank.repaid = 0
        ini.rank.caught_paydays = 0
        ini.rank.started = 'Нет данных'
        ini.rank.completed = false
        inicfg.save(ini, CONFIG)
        statusText = 'Прогресс сброшен'
    end
end


local function drawTelegramTab()
    imgui.SetCursorPos(imgui.ImVec2(260, 100))
    imgui.SetWindowFontScale(1.15)
    imgui.Text('TELEGRAM')
    imgui.SetWindowFontScale(1.0)

    imgui.SetCursorPos(imgui.ImVec2(260, 126))
    textMuted('Вставь token и chat ID сюда. Игровой чат больше не нужен.')

    beginPanel('telegram_panel', 260, 160, 700, 260)

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
            inicfg.save(ini, CONFIG)
            statusText = 'Telegram сохранен и включен'
            sampAddChatMessage('{55DD88}[PayDay TG] {FFFFFF}Telegram сохранен и включен.', -1)
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

    imgui.SetCursorPos(imgui.ImVec2(18, 220))
    if asBool(ini.telegram.enabled) then
        textValue('Статус: включено', 2)
    else
        textMuted('Статус: выключено')
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
    imgui.Text(u8'PAYDAY HELPER')
    imgui.SetWindowFontScale(1.0)
    textMuted('Arizona RP - зарплата, депозит и окупаемость ранга')
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
    else
        drawTelegramTab()
    end

    imgui.End()
end)
mainFrame.HideCursor = false

function main()
    while not isSampAvailable() do wait(50) end

    setBuffer(rankNumberText, rankNumber[0])
    setBuffer(rankCostText, rankCost[0])
    setBuffer(rankSalaryText, rankSalary[0])

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

    print('[Arizona Payday Clean] Commands registered: /payday /paycalc /paytg /paytgtest /paytgon /paytgoff')

    sampAddChatMessage('{FFD34E}[PayDay Helper] {FFFFFF}Версия ' .. SCRIPT_VERSION .. ' загружена. Telegram работает через MoonLoader без внешних файлов', -1)

    local lastMiniState = miniEnabled[0]

    while true do
        wait(0)

        processTelegramTransport()

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
        pcall(function() sampSetCursorMode(0) end)
        pcall(function() lockPlayerControl(false) end)
        pcall(function()
            if telegramCurrent and telegramCurrent.responsePath and doesFileExist(telegramCurrent.responsePath) then
                os.remove(telegramCurrent.responsePath)
            end
        end)
    end
end
