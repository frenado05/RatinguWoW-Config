-- RatinguWoWx100Plus.lua
RatinguWoWx100DB = RatinguWoWx100DB or {}

-- Инициализация WinHistory с защитой от nil
if not RatinguWoWx100DB.WinHistory then
    RatinguWoWx100DB.WinHistory = {}
end
if not RatinguWoWx100DB.WinHistory.twosWins then
    RatinguWoWx100DB.WinHistory.twosWins = 0
end
if not RatinguWoWx100DB.WinHistory.soloWins then
    RatinguWoWx100DB.WinHistory.soloWins = 0
end

-- Инициализация хранилища токенов за победы (с защитой от старых сохранений)
if not RatinguWoWx100DB.WinTokens then
    RatinguWoWx100DB.WinTokens = {
        total = 0,
        byRating = {
            [1400] = 0,
            [1800] = 0,
            [2000] = 0,
            [2200] = 0,
            [2400] = 0,
        },
        history = {},
    }
else
    -- Если структура уже есть, но не хватает полей
    if not RatinguWoWx100DB.WinTokens.byRating then
        RatinguWoWx100DB.WinTokens.byRating = {
            [1400] = 0,
            [1800] = 0,
            [2000] = 0,
            [2200] = 0,
            [2400] = 0,
        }
    end
    if not RatinguWoWx100DB.WinTokens.history then
        RatinguWoWx100DB.WinTokens.history = {}
    end
end

-- Хранилище последних рейтингов для каждого персонажа (с защитой)
if not RatinguWoWx100DB.LastRatings then
    RatinguWoWx100DB.LastRatings = {}
end

-- Включаем дебаг режим (включено для тестирования)
local DEBUG_MODE = false

-- Жестко заданный реалм (только для этого сервера)
local TARGET_REALM = "x100 Plus Season"

-- В начале файла, после DEBUG_MODE
local successFont = "Fonts\\ARIALN.TTF"  -- значение по умолчанию

-- Хранилище для рейтинга соло
local SoloRatingData = {}

-- Функция для дебаг вывода
local function DebugPrint(...)
    if DEBUG_MODE then
        print("|cffff9900[RatinguWoW]|r", ...)
    end
end

-- Функция получения токенов за победу по текущему рейтингу
local function GetWinTokensByRating(rating)
    if rating >= 2400 then
        return 20
    elseif rating >= 2200 then
        return 15
    elseif rating >= 2000 then
        return 10
    elseif rating >= 1800 then
        return 7
    elseif rating >= 1400 then
        return 5
    else
        return 0
    end
end

-- Встроенные пороги по умолчанию
local DefaultThresholds = {
    [2] = {  -- 2х2
        { rating = 2595, reward = 4000, title = "Р1" },
        { rating = 2471, reward = 2500, title = "Гладиатор" },
        { rating = 1891, reward = 1500, title = "Дуэлянт" },
        { rating = 1568, reward = 1000, title = "Фаворит" },
        { rating = 1302, reward = 500,  title = "Претендент" },
    },
    [9] = {  -- Соло
        { rating = 2807, reward = 4000, title = "Р1" },
        { rating = 2645, reward = 2500, title = "Гладиатор" },
        { rating = 2320, reward = 1500, title = "Дуэлянт" },
        { rating = 2081, reward = 1000, title = "Фаворит" },
        { rating = 1638, reward = 500,  title = "Претендент" },
    },
}

-- Активные пороги (сначала встроенные)
local ActiveThresholds = DefaultThresholds

-- Проверяем наличие пользовательских порогов через 0.1 секунды после загрузки
C_Timer.After(0.1, function()
    if _G.CustomThresholds then
        ActiveThresholds = _G.CustomThresholds
        DebugPrint("Используются пороги из thresholds.lua")
        RefreshDisplay()
    else
        DebugPrint("Используются пороги по умолчанию")
    end
end)

local tokenIcon = "Interface\\Icons\\spell_animabastion_orb.blp"

-- Функция расчета бонуса за активность (только победы!)
local function GetActivityBonus(wins)
    if wins >= 800 then
        return 80
    elseif wins >= 700 then
        return 70
    elseif wins >= 600 then
        return 60
    elseif wins >= 500 then
        return 50
    elseif wins >= 400 then
        return 40
    elseif wins >= 300 then
        return 30
    elseif wins >= 200 then
        return 20
    elseif wins >= 100 then
        return 10
    else
        return 0
    end
end

-- Функции для токенов
local function GetTokensForRating(rating, mode)
    local thresholds = ActiveThresholds
    local modeThresholds = thresholds[mode] or thresholds[2]
    for _, t in ipairs(modeThresholds) do
        if rating >= t.rating then
            return t.reward, t.title
        end
    end
    return 0, nil
end

local function GetNextRequiredRating(rating, mode)
    local thresholds = ActiveThresholds
    local modeThresholds = thresholds[mode] or thresholds[2]
    if rating < modeThresholds[#modeThresholds].rating then
        return modeThresholds[#modeThresholds].rating
    end
    for i = #modeThresholds, 1, -1 do
        if rating < modeThresholds[i].rating then
            return modeThresholds[i].rating
        end
    end
    return nil
end

local function GetNextRankInfo(rating, mode)
    local thresholds = ActiveThresholds
    local modeThresholds = thresholds[mode] or thresholds[2]
    for i = #modeThresholds, 1, -1 do
        local th = modeThresholds[i]
        if rating < th.rating then
            return th.title, (th.rating - rating), th.reward
        end
    end
    return nil, nil, nil
end

local function GetCurrentRankInfo(rating, mode)
    local thresholds = ActiveThresholds
    local modeThresholds = thresholds[mode] or thresholds[2]
    for _, t in ipairs(modeThresholds) do
        if rating >= t.rating then
            return t.title, t.rating
        end
    end
    return nil, 0
end

-- Получение уникального ключа персонажа
local function GetCharIdentifier()
    return (UnitName("player") or "Unknown").."-"..(GetRealmName() or "Unknown")
end

-- Получение имени текущего игрока
local function GetPlayerName()
    return UnitName("player") or "Unknown"
end

-- Получение/установка состояния чекбокса
local function IsZeroRatingHidden()
    RatinguWoWx100DB["Settings"] = RatinguWoWx100DB["Settings"] or {}
    return RatinguWoWx100DB["Settings"].hideZeroRating or false
end

local function SetZeroRatingHidden(value)
    RatinguWoWx100DB["Settings"] = RatinguWoWx100DB["Settings"] or {}
    RatinguWoWx100DB["Settings"].hideZeroRating = value
end

-- Парсинг сообщения с рейтингом из UISMSG_UCUSTOM_BRACKET (СОЛО)
local function ParseCustomBracketMessage(prefix, text, sender)
    -- Проверяем реалм
    local currentRealm = GetRealmName() or ""
    if currentRealm ~= TARGET_REALM then
        return  -- игнорируем другие реалмы
    end
    if not text or not string.find(text, "UISMSG_UCUSTOM_BRACKET:") then return end
    
    local dataText = text:gsub("UISMSG_UCUSTOM_BRACKET:", "")
    
    local bracketStrings = {}
    for match in string.gmatch(dataText, "([^:]+):") do
        table.insert(bracketStrings, match)
    end
    
    for idx, bracketStr in ipairs(bracketStrings) do
        local parts = {}
        for match in string.gmatch(bracketStr, "[^|]+") do
            table.insert(parts, match)
        end
        
        if #parts >= 9 then
            local bracketType = tonumber(parts[1]) or 0
            local rating = tonumber(parts[2]) or 0
            local wins = tonumber(parts[3]) or 0
            local gameCount = tonumber(parts[5]) or 0
            local losses = gameCount - wins
            if losses < 0 then losses = 0 end
            
            -- Нам нужен только брекет типа 9 (соло)
            if bracketType == 9 then
                local playerName = GetPlayerName()
                local key = GetCharIdentifier()
                
                -- Получаем предыдущий рейтинг для этого персонажа (с защитой)
                local prevRating = 0
                if RatinguWoWx100DB.LastRatings and RatinguWoWx100DB.LastRatings[key] then
                    prevRating = RatinguWoWx100DB.LastRatings[key].solo or 0
                end
                
                -- Если рейтинг изменился и был больше 0
                if prevRating > 0 and rating ~= prevRating then
                    if rating > prevRating then
                        -- ПОБЕДА! Начисляем токены
                        local tokens = GetWinTokensByRating(rating) -- TODO было prevRating
                        if tokens > 0 and RatinguWoWx100DB.WinTokens then
                            RatinguWoWx100DB.WinTokens.total = (RatinguWoWx100DB.WinTokens.total or 0) + tokens
                            
                            -- Сохраняем статистику по рейтингу
                            if not RatinguWoWx100DB.WinTokens.byRating then
                                RatinguWoWx100DB.WinTokens.byRating = {}
                            end
                            
                            if prevRating >= 2400 then
                                RatinguWoWx100DB.WinTokens.byRating[2400] = (RatinguWoWx100DB.WinTokens.byRating[2400] or 0) + tokens
                            elseif prevRating >= 2200 then
                                RatinguWoWx100DB.WinTokens.byRating[2200] = (RatinguWoWx100DB.WinTokens.byRating[2200] or 0) + tokens
                            elseif prevRating >= 2000 then
                                RatinguWoWx100DB.WinTokens.byRating[2000] = (RatinguWoWx100DB.WinTokens.byRating[2000] or 0) + tokens
                            elseif prevRating >= 1800 then
                                RatinguWoWx100DB.WinTokens.byRating[1800] = (RatinguWoWx100DB.WinTokens.byRating[1800] or 0) + tokens
                            elseif prevRating >= 1400 then
                                RatinguWoWx100DB.WinTokens.byRating[1400] = (RatinguWoWx100DB.WinTokens.byRating[1400] or 0) + tokens
                            end
                            
                            -- Сохраняем в историю
                            if not RatinguWoWx100DB.WinTokens.history then
                                RatinguWoWx100DB.WinTokens.history = {}
                            end
                            table.insert(RatinguWoWx100DB.WinTokens.history, {
                                time = time(),
                                mode = "SOLO",
                                rating = prevRating,
                                tokens = tokens,
                                total = RatinguWoWx100DB.WinTokens.total
                            })
                            
                            -- Выводим сообщение
                            print(string.format("|cff00ff00[RatinguWoW] СОЛО: Победа! +%d токенов (рейтинг: %d). Всего: %d|r", 
                                tokens, prevRating, RatinguWoWx100DB.WinTokens.total))
                            
                            RefreshDisplay()
                        end
                    elseif rating < prevRating then
                        DebugPrint("СОЛО: Поражение! Рейтинг упал с", prevRating, "до", rating)
                    end
                end
                
                -- Сохраняем новый рейтинг для этого персонажа (с защитой)
                if not RatinguWoWx100DB.LastRatings then
                    RatinguWoWx100DB.LastRatings = {}
                end
                if not RatinguWoWx100DB.LastRatings[key] then
                    RatinguWoWx100DB.LastRatings[key] = {}
                end
                RatinguWoWx100DB.LastRatings[key].solo = rating
                
                -- Сохраняем данные соло рейтинга как обычно
                SoloRatingData[playerName] = {
                    rating = rating,
                    wins = wins,
                    losses = losses,
                    gameCount = gameCount,
                    bracketType = bracketType,
                    timestamp = time()
                }
                DebugPrint("Сохранен соло рейтинг для", playerName, ":", rating)
            end
        end
    end
end

-- Обновление данных текущего персонажа
local function UpdateCharacterData()
    -- Проверяем реалм
    local currentRealm = GetRealmName() or ""
    if currentRealm ~= TARGET_REALM then
        return  -- не сохраняем персонажей с других реалмов
    end
    
    local key = GetCharIdentifier()
    RatinguWoWx100DB[key] = RatinguWoWx100DB[key] or {}
    
    -- Убеждаемся что WinTokens существует
    if not RatinguWoWx100DB.WinTokens then
        RatinguWoWx100DB.WinTokens = {
            total = 0,
            byRating = {
                [1400] = 0,
                [1800] = 0,
                [2000] = 0,
                [2200] = 0,
                [2400] = 0,
            },
            history = {},
        }
    end

    -- Рейтинг + статистика 2х2
    local rating, seasonPlayed, seasonWon = 0, 0, 0
    if type(GetPersonalRatedInfo) == "function" then
        rating, _, _, seasonPlayed, seasonWon = GetPersonalRatedInfo(1)
        rating = rating or 0
        seasonPlayed = seasonPlayed or 0
        seasonWon = seasonWon or 0
    end

    -- Получаем предыдущий рейтинг для этого персонажа (с защитой)
    local prevTwosRating = 0
    if RatinguWoWx100DB.LastRatings and RatinguWoWx100DB.LastRatings[key] then
        prevTwosRating = RatinguWoWx100DB.LastRatings[key].twos or 0
    end
    
    -- Проверяем изменение рейтинга для 2х2
    if prevTwosRating > 0 and rating ~= prevTwosRating then
        if rating > prevTwosRating then
            -- ПОБЕДА! Начисляем токены
            local tokens = GetWinTokensByRating(rating) -- TODO было prevTwosRating
            if tokens > 0 and RatinguWoWx100DB.WinTokens then
                RatinguWoWx100DB.WinTokens.total = (RatinguWoWx100DB.WinTokens.total or 0) + tokens
                
                -- Сохраняем статистику по рейтингу
                if not RatinguWoWx100DB.WinTokens.byRating then
                    RatinguWoWx100DB.WinTokens.byRating = {}
                end
                
                if prevTwosRating >= 2400 then
                    RatinguWoWx100DB.WinTokens.byRating[2400] = (RatinguWoWx100DB.WinTokens.byRating[2400] or 0) + tokens
                elseif prevTwosRating >= 2200 then
                    RatinguWoWx100DB.WinTokens.byRating[2200] = (RatinguWoWx100DB.WinTokens.byRating[2200] or 0) + tokens
                elseif prevTwosRating >= 2000 then
                    RatinguWoWx100DB.WinTokens.byRating[2000] = (RatinguWoWx100DB.WinTokens.byRating[2000] or 0) + tokens
                elseif prevTwosRating >= 1800 then
                    RatinguWoWx100DB.WinTokens.byRating[1800] = (RatinguWoWx100DB.WinTokens.byRating[1800] or 0) + tokens
                elseif prevTwosRating >= 1400 then
                    RatinguWoWx100DB.WinTokens.byRating[1400] = (RatinguWoWx100DB.WinTokens.byRating[1400] or 0) + tokens
                end
                
                -- Сохраняем в историю
                if not RatinguWoWx100DB.WinTokens.history then
                    RatinguWoWx100DB.WinTokens.history = {}
                end
                table.insert(RatinguWoWx100DB.WinTokens.history, {
                    time = time(),
                    mode = "2x2",
                    rating = prevTwosRating,
                    tokens = tokens,
                    total = RatinguWoWx100DB.WinTokens.total
                })
                
                -- Выводим сообщение
                print(string.format("|cff00ff00[RatinguWoW] 2х2: Победа! +%d токенов (рейтинг: %d). Всего: %d|r", 
                    tokens, prevTwosRating, RatinguWoWx100DB.WinTokens.total))
                
                RefreshDisplay()
            end
        elseif rating < prevTwosRating then
            DebugPrint("2х2: Поражение! Рейтинг упал с", prevTwosRating, "до", rating)
        end
    end
    
    -- Сохраняем новый рейтинг для этого персонажа (с защитой)
    if not RatinguWoWx100DB.LastRatings then
        RatinguWoWx100DB.LastRatings = {}
    end
    if not RatinguWoWx100DB.LastRatings[key] then
        RatinguWoWx100DB.LastRatings[key] = {}
    end
    RatinguWoWx100DB.LastRatings[key].twos = rating

    -- Обновляем общее количество побед для 2х2 (только победы!)
    if seasonWon > 0 then
        if not RatinguWoWx100DB.WinHistory then
            RatinguWoWx100DB.WinHistory = {}
        end
        RatinguWoWx100DB.WinHistory.twosWins = seasonWon
    end

    -- Соло рейтинг
    local playerName = GetPlayerName()
    local soloRating = 0
    local soloWins = 0
    local soloLosses = 0
    local soloGameCount = 0
    local soloWinrate = 0
    
    if SoloRatingData[playerName] then
        soloRating = SoloRatingData[playerName].rating or 0
        soloWins = SoloRatingData[playerName].wins or 0
        soloLosses = SoloRatingData[playerName].losses or 0
        soloGameCount = SoloRatingData[playerName].gameCount or 0
        
        -- Обновляем количество побед для соло (только победы!)
        if soloWins > 0 then
            if not RatinguWoWx100DB.WinHistory then
                RatinguWoWx100DB.WinHistory = {}
            end
            RatinguWoWx100DB.WinHistory.soloWins = soloWins
            soloWinrate = (soloWins / soloGameCount) * 100
        end
    end

    local seasonLost = seasonPlayed - seasonWon
    local winrate = 0
    if seasonPlayed > 0 then
        winrate = (seasonWon / seasonPlayed) * 100
    end

    -- Спек
    local specIcon
    local specIndex = GetSpecialization()
    if specIndex and specIndex > 0 then
        specIcon = select(4, GetSpecializationInfo(specIndex))
    end

    -- Класс и цвет
    local _, classFile = UnitClass("player")
    local classColor = "ffffffff"
    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        classColor = RAID_CLASS_COLORS[classFile].colorStr
    end

    -- Валюты
    local _, honorAmount = GetCurrencyInfo(392)
    local _, conquestAmount = GetCurrencyInfo(390)
    local _, warResources = GetCurrencyInfo(1175)

    -- Фракция для иконок
    local faction = UnitFactionGroup("player")
    local honorIcon, conquestIcon
    
    if faction == "Horde" then
        honorIcon = "Interface\\Icons\\pvpcurrency-honor-horde.blp"
        conquestIcon = "Interface\\Icons\\pvpcurrency-conquest-horde.blp"
    else
        honorIcon = "Interface\\Icons\\pvpcurrency-honor-alliance.blp"
        conquestIcon = "Interface\\Icons\\pvpcurrency-conquest-alliance.blp"
    end

    -- Сохраняем
    RatinguWoWx100DB[key].name = playerName
    RatinguWoWx100DB[key].realm = GetRealmName()
    RatinguWoWx100DB[key].rating = rating
    RatinguWoWx100DB[key].wins = seasonWon
    RatinguWoWx100DB[key].losses = seasonLost
    RatinguWoWx100DB[key].winrate = winrate
    RatinguWoWx100DB[key].soloRating = soloRating
    RatinguWoWx100DB[key].soloWins = soloWins
    RatinguWoWx100DB[key].soloLosses = soloLosses
    RatinguWoWx100DB[key].soloWinrate = soloWinrate
    RatinguWoWx100DB[key].specIcon = specIcon
    RatinguWoWx100DB[key].classColor = classColor
    RatinguWoWx100DB[key].classFile = classFile
    RatinguWoWx100DB[key].currencyHonor = {amount = honorAmount, icon = honorIcon}
    RatinguWoWx100DB[key].currencyConquest = {amount = conquestAmount, icon = conquestIcon}
    RatinguWoWx100DB[key].currencyResources = {amount = warResources, icon = "Interface\\Icons\\Inv_misc_herb_goldclover.blp"}
end

-- Создание чекбокса
local function CreateZeroRatingCheckbox()
    if not PVEFrame then return end
    if PVEFrame.RatinguWoWCheckbox then return PVEFrame.RatinguWoWCheckbox end

    local cb = CreateFrame("CheckButton", nil, PVEFrame, "UICheckButtonTemplate")
    cb:SetPoint("TOPRIGHT", PVEFrame, "TOPRIGHT", 335, 25)
    cb.text:SetText("Скрыть 0 рейта")
    
    -- Используем тот же шрифт, что и для основного текста
    cb.text:SetFont(successFont, 12, "OUTLINE")
    
    cb:SetChecked(IsZeroRatingHidden())

    cb:SetScript("OnClick", function(self)
        SetZeroRatingHidden(self:GetChecked())
        RefreshDisplay()
    end)

    PVEFrame.RatinguWoWCheckbox = cb
    return cb
end

-- Функция для получения цвета винрейта
local function GetWinrateColor(winrate)
    if winrate < 50 then
        return "|cffff0000"
    elseif winrate < 70 then
        return "|cffffff00"
    else
        return "|cff00ff00"
    end
end

-- Обновление текста внутри PVEFrame
function RefreshDisplay()
    UpdateCharacterData()
    
    -- В функции RefreshDisplay(), после проверки PVEFrame
    if not PVEFrame.RatinguWoWTexts then
        PVEFrame.RatinguWoWTexts = {}
        
        -- Проверяем наличие шрифта в папке аддона
        local fontPath = "Interface\\AddOns\\RatinguWoWx100Plus\\Fonts\\FRIZQT__.TTF"
        
        -- Пытаемся создать тестовый фрейм и установить шрифт
        local testFrame = CreateFrame("Frame")
        local testString = testFrame:CreateFontString()
        
        -- Если шрифт не существует, SetFont вызовет ошибку, используем pcall
        local success, _ = pcall(function()
            testString:SetFont(fontPath, 12)
        end)
        
        if success then
            successFont = fontPath  -- Изменяем глобальную переменную
            DebugPrint("Используется шрифт из папки аддона")
        else
            DebugPrint("Используется стандартный шрифт")
        end
        
        for i = 1, 10 do
            local t = PVEFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            t:SetJustifyH("LEFT")
            t:SetJustifyV("TOP")
            t:SetFont(successFont, 12, "OUTLINE")
            t:SetWidth(850)
            t:SetNonSpaceWrap(true)
            t:Hide()
            PVEFrame.RatinguWoWTexts[i] = t
        end
    end

    -- Собираем данные
	local list = {}
	for _, v in pairs(RatinguWoWx100DB) do
		if type(v) == "table" and v.name and v.realm == TARGET_REALM then
			if not IsZeroRatingHidden() or (v.rating or 0) > 0 or (v.soloRating or 0) > 0 then
				table.insert(list, v)
			end
		end
	end
    table.sort(list, function(a, b) return (a.rating or 0) > (b.rating or 0) end)

    -- Считаем общие токены и бонусы для заголовка
    local totalTwosTokens = 0
    local totalSoloTokens = 0
    local totalTwosBonusTokens = 0
    local totalSoloBonusTokens = 0
    
    for _, v in ipairs(list) do
        local twosTokens = GetTokensForRating(v.rating or 0, 2)
        local soloTokens = GetTokensForRating(v.soloRating or 0, 9)
        
        -- Считаем бонусы для каждого персонажа индивидуально (только победы!)
        local twosBonus = GetActivityBonus(v.wins or 0)
        local soloBonus = GetActivityBonus(v.soloWins or 0)
        
        totalTwosTokens = totalTwosTokens + twosTokens
        totalSoloTokens = totalSoloTokens + soloTokens
        totalTwosBonusTokens = totalTwosBonusTokens + math.floor(twosTokens * twosBonus / 100)
        totalSoloBonusTokens = totalSoloBonusTokens + math.floor(soloTokens * soloBonus / 100)
    end

    -- Получаем бонусы для текущего игрока (только победы!)
    local twosWins = RatinguWoWx100DB.WinHistory.twosWins or 0
    local soloWins = RatinguWoWx100DB.WinHistory.soloWins or 0
    local twosBonus = GetActivityBonus(twosWins)
    local soloBonus = GetActivityBonus(soloWins)
    
    local totalBonusTokens = totalTwosBonusTokens + totalSoloBonusTokens

    local parts = {}
    local linesPerPart = 15
    local totalParts = math.ceil(#list / linesPerPart)

    for partIndex = 1, totalParts do
        local partText = ""
			if partIndex == 1 then
			-- Заголовок с разделителями
			partText = "|cffffff00--------------------------------------------------------------------|r\n"
			
			-- Итоговые суммы с бонусом
			local twosTotal = totalTwosTokens + totalTwosBonusTokens
			local soloTotal = totalSoloTokens + totalSoloBonusTokens
			
			partText = partText .. string.format("|cffffff00Токи 2х2:|r |T%s:16:16:0:0|t |cff00ff00%d|r", tokenIcon, twosTotal)
			if totalTwosBonusTokens > 0 then
				partText = partText .. string.format(" |cff00ff00(%d + %d бонус)|r", totalTwosTokens, totalTwosBonusTokens)
			end
			partText = partText .. string.format("  |cffffff00Токи соло:|r |T%s:16:16:0:0|t |cff00ff00%d|r", tokenIcon, soloTotal)
			if totalSoloBonusTokens > 0 then
				partText = partText .. string.format(" |cff00ff00(%d + %d бонус)|r", totalSoloTokens, totalSoloBonusTokens)
			end
			partText = partText .. "\n"
			
			if totalTwosBonusTokens > 0 or totalSoloBonusTokens > 0 then
				partText = partText .. "|cffffff00Бонус активности:|r"
				if totalTwosBonusTokens > 0 then
					partText = partText .. string.format(" |cff00ff002х2: +%d токенов|r", totalTwosBonusTokens)
				end
				if totalSoloBonusTokens > 0 then
					partText = partText .. string.format(" |cff00ff00Соло: +%d токенов|r", totalSoloBonusTokens)
				end
				partText = partText .. "\n"
			end
			
			-- Добавляем информацию о накопленных токенах за победы и табличку
			if RatinguWoWx100DB.WinTokens and RatinguWoWx100DB.WinTokens.total then
				partText = partText .. string.format("|cffffff00Накоплено токенов за победы:|r |cff00ff00%d|r\n", 
					RatinguWoWx100DB.WinTokens.total)
				
				-- Табличка по рейтингам в столбик
				if RatinguWoWx100DB.WinTokens.byRating then
					partText = partText .. string.format("2400+:     |cff00ff00%d|r\n", RatinguWoWx100DB.WinTokens.byRating[2400] or 0)
					partText = partText .. string.format("2200-2399: |cff00ff00%d|r\n", RatinguWoWx100DB.WinTokens.byRating[2200] or 0)
					partText = partText .. string.format("2000-2199: |cff00ff00%d|r\n", RatinguWoWx100DB.WinTokens.byRating[2000] or 0)
					partText = partText .. string.format("1800-1999: |cff00ff00%d|r\n", RatinguWoWx100DB.WinTokens.byRating[1800] or 0)
					partText = partText .. string.format("1400-1799: |cff00ff00%d|r\n", RatinguWoWx100DB.WinTokens.byRating[1400] or 0)
				end
			end
			
			-- Общая сумма с учетом токенов за победы
			local winTokensTotal = 0
			if RatinguWoWx100DB.WinTokens and RatinguWoWx100DB.WinTokens.total then
				winTokensTotal = RatinguWoWx100DB.WinTokens.total
			end
			
			local allTokensTotal = twosTotal + soloTotal + winTokensTotal
			
			partText = partText .. string.format("|cffffff00Всего токенов:|r |cff00ff00%d|r |cffffffff(база: %d + бонус: %d + победы: %d)|r\n", 
				allTokensTotal, totalTwosTokens + totalSoloTokens, totalBonusTokens, winTokensTotal)
			
			partText = partText .. "|cffffff00--------------------------------------------------------------------|r\n\n"
		end
        
        local startIdx = (partIndex - 1) * linesPerPart + 1
        local endIdx = math.min(partIndex * linesPerPart, #list)
        
        for i = startIdx, endIdx do
            local v = list[i]
            
            -- Иконка спека
            local icon = ""
            if v.specIcon then
                icon = ("|T%d:14:14:0:0|t "):format(v.specIcon)
            end

            -- Цветное имя
            local nameColored = v.classColor and ("|c"..v.classColor..(v.name or "??").."|r") or (v.name or "??")
            local realmText = v.realm and ("-"..v.realm) or ""

            -- Валюты
            local honorCurrency = v.currencyHonor and ("|T"..v.currencyHonor.icon..":14:14:0:0|t "..v.currencyHonor.amount) or ""
            local conquestCurrency = v.currencyConquest and ("|T"..v.currencyConquest.icon..":14:14:0:0|t "..v.currencyConquest.amount) or ""
            local resourceCurrency = v.currencyResources and ("|T"..v.currencyResources.icon..":14:14:0:0|t "..v.currencyResources.amount) or ""

            -- 2х2 статистика
            local winsVal, lossesVal = v.wins or 0, v.losses or 0
            local wins, losses
            if winsVal + lossesVal == 0 then
                wins = string.format("|cffffffff%d|r", winsVal)
                losses = string.format("|cffffffff%d|r", lossesVal)
            else
                wins = string.format("|cff00ff00%d|r", winsVal)
                losses = string.format("|cffff0000%d|r", lossesVal)
            end

            -- Винрейт 2х2
            local wrText = ""
            if winsVal + lossesVal > 0 then
                local wr = v.winrate or 0
                local wrColor = GetWinrateColor(wr)
                wrText = string.format(" %s%.1f%%|r", wrColor, wr)
            end

            -- Токены для 2х2
            local twosTokens, twosTitle = GetTokensForRating(v.rating or 0, 2)
            local twosTokenText = ""
            if twosTokens > 0 then
                twosTokenText = string.format(" |T%s:14:14:0:0|t |cff00ff00%d (%s)|r", tokenIcon, twosTokens, twosTitle)
                -- Добавляем бонус если есть победы
                local twosBonus = GetActivityBonus(v.wins or 0)
                if twosBonus > 0 then
                    local bonusTokens = math.floor(twosTokens * twosBonus / 100)
                    twosTokenText = twosTokenText .. string.format(" |cff00ff00+%d (%d%%)|r", bonusTokens, twosBonus)
                end
            else
                local nextReq = GetNextRequiredRating(v.rating or 0, 2)
                if nextReq then
                    twosTokenText = string.format(" |T%s:14:14:0:0|t |cffff0000До: %d|r", tokenIcon, nextReq - (v.rating or 0))
                end
            end

            -- Следующий ранг для 2х2
            local nextRankText = ""
            if twosTokens > 0 then
                local nextTitle, toNext, nextReward = GetNextRankInfo(v.rating or 0, 2)
                if nextTitle and toNext and nextReward then
                    nextRankText = string.format("  |cffff0000%s: %d|r |T%s:14:14:0:0|t %d", nextTitle, toNext, tokenIcon, nextReward)
                    -- Добавляем бонус к следующему рангу если есть победы
                    local twosBonus = GetActivityBonus(v.wins or 0)
                    if twosBonus > 0 then
                        local bonusNextReward = math.floor(nextReward * twosBonus / 100)
                        nextRankText = nextRankText .. string.format(" |cff00ff00+%d|r", bonusNextReward)
                    end
                end
            end

            -- Основная строка для 2х2
            local line = string.format("%s%s%s - 2v2 %d [%s / %s]%s%s%s", 
                icon, nameColored, realmText, v.rating or 0, wins, losses, wrText, twosTokenText, nextRankText)

            -- Добавляем валюты в конец строки
            if conquestCurrency ~= "" or honorCurrency ~= "" or resourceCurrency ~= "" then
                line = line .. "  " .. conquestCurrency .. " " .. honorCurrency .. " " .. resourceCurrency
            end
            line = line .. "\n"
            
            -- Соло строка (если есть)
            if v.soloRating and v.soloRating > 0 then
                local soloWinsVal, soloLossesVal = v.soloWins or 0, v.soloLosses or 0
                local soloWins, soloLosses
                if soloWinsVal + soloLossesVal == 0 then
                    soloWins = string.format("|cffffffff%d|r", soloWinsVal)
                    soloLosses = string.format("|cffffffff%d|r", soloLossesVal)
                else
                    soloWins = string.format("|cff00ff00%d|r", soloWinsVal)
                    soloLosses = string.format("|cffff0000%d|r", soloLossesVal)
                end

                -- Винрейт соло
                local soloWrText = ""
                if soloWinsVal + soloLossesVal > 0 then
                    local soloWr = v.soloWinrate or 0
                    local soloWrColor = GetWinrateColor(soloWr)
                    soloWrText = string.format(" %s%.1f%%|r", soloWrColor, soloWr)
                end

                -- Токены для соло
                local soloTokens, soloTitle = GetTokensForRating(v.soloRating or 0, 9)
                local soloTokenText = ""
                if soloTokens > 0 then
                    soloTokenText = string.format(" |T%s:14:14:0:0|t |cff00ff00%d (%s)|r", tokenIcon, soloTokens, soloTitle)
                    -- Добавляем бонус если есть победы
                    local soloBonus = GetActivityBonus(v.soloWins or 0)
                    if soloBonus > 0 then
                        local soloBonusTokens = math.floor(soloTokens * soloBonus / 100)
                        soloTokenText = soloTokenText .. string.format(" |cff00ff00+%d (%d%%)|r", soloBonusTokens, soloBonus)
                    end
                else
                    local soloNextReq = GetNextRequiredRating(v.soloRating or 0, 9)
                    if soloNextReq then
                        soloTokenText = string.format(" |T%s:14:14:0:0|t |cffff0000До: %d|r", tokenIcon, soloNextReq - (v.soloRating or 0))
                    end
                end

                -- Следующий ранг для соло
                local soloNextRankText = ""
                if soloTokens > 0 then
                    local soloNextTitle, soloToNext, soloNextReward = GetNextRankInfo(v.soloRating or 0, 9)
                    if soloNextTitle and soloToNext and soloNextReward then
                        soloNextRankText = string.format("  |cffff0000%s: %d|r |T%s:14:14:0:0|t %d", soloNextTitle, soloToNext, tokenIcon, soloNextReward)
                        -- Добавляем бонус к следующему рангу если есть победы
                        local soloBonus = GetActivityBonus(v.soloWins or 0)
                        if soloBonus > 0 then
                            local soloBonusNextReward = math.floor(soloNextReward * soloBonus / 100)
                            soloNextRankText = soloNextRankText .. string.format(" |cff00ff00+%d|r", soloBonusNextReward)
                        end
                    end
                end

                line = line .. string.format("  [SoloQ2x2: %d [%s / %s]%s%s%s\n", 
                    v.soloRating, soloWins, soloLosses, soloWrText, soloTokenText, soloNextRankText)
            end
            
            partText = partText .. line
        end
        
        table.insert(parts, partText)
    end

    -- Отображаем
    for i, textField in ipairs(PVEFrame.RatinguWoWTexts) do
        if parts[i] then
            textField:SetText(parts[i])
            textField:Show()
            if i == 1 then
                textField:SetPoint("TOPLEFT", PVEFrame, "BOTTOMLEFT", 870, 420)
            else
                textField:SetPoint("TOPLEFT", PVEFrame.RatinguWoWTexts[i-1], "BOTTOMLEFT", 0, 15)
            end
        else
            textField:Hide()
        end
    end

    CreateZeroRatingCheckbox()
end

-- Отслеживание CHAT_MSG_ADDON
local addonDebugFrame = CreateFrame("Frame")
addonDebugFrame:RegisterEvent("CHAT_MSG_ADDON")
addonDebugFrame:SetScript("OnEvent", function(self, event, prefix, text, channel, sender, ...)
    if prefix == "UISMSG_TO_CLIENT" and text then
        if string.find(text, "UISMSG_UCUSTOM_BRACKET") then
            ParseCustomBracketMessage("UISMSG_UCUSTOM_BRACKET", text, sender)
            RefreshDisplay()
        end
    end
end)

-- Команда для просмотра статистики токенов (с защитой)
SLASH_WINTOKENS1 = "/wintokens"
SlashCmdList["WINTOKENS"] = function()
    print("|cffff9900[RatinguWoW] Накоплено токенов за победы:|r")
    if not RatinguWoWx100DB.WinTokens then
        print("  Нет данных")
        return
    end
    
    print("  Всего: " .. (RatinguWoWx100DB.WinTokens.total or 0))
    print("  По рейтингу:")
    print("    2400+: " .. ((RatinguWoWx100DB.WinTokens.byRating and RatinguWoWx100DB.WinTokens.byRating[2400]) or 0))
    print("    2200-2399: " .. ((RatinguWoWx100DB.WinTokens.byRating and RatinguWoWx100DB.WinTokens.byRating[2200]) or 0))
    print("    2000-2199: " .. ((RatinguWoWx100DB.WinTokens.byRating and RatinguWoWx100DB.WinTokens.byRating[2000]) or 0))
    print("    1800-1999: " .. ((RatinguWoWx100DB.WinTokens.byRating and RatinguWoWx100DB.WinTokens.byRating[1800]) or 0))
    print("    1400-1799: " .. ((RatinguWoWx100DB.WinTokens.byRating and RatinguWoWx100DB.WinTokens.byRating[1400]) or 0))
    
    if DEBUG_MODE and RatinguWoWx100DB.WinTokens.history and #RatinguWoWx100DB.WinTokens.history > 0 then
        print("|cffff9900Последние 5 побед:|r")
        local start = math.max(1, #RatinguWoWx100DB.WinTokens.history - 4)
        for i = start, #RatinguWoWx100DB.WinTokens.history do
            local h = RatinguWoWx100DB.WinTokens.history[i]
            print(string.format("  %s: рейтинг %d, +%d токенов (всего: %d)", 
                h.mode or "?", h.rating or 0, h.tokens or 0, h.total or 0))
        end
    end
end

-- Команды
SLASH_RATINGUPLUS1 = "/ratinguplus"
SLASH_RATINGUPLUS2 = "/rwow"
SlashCmdList["RATINGUPLUS"] = RefreshDisplay

SLASH_RATINGDEBUG1 = "/ratingdebug"
SlashCmdList["RATINGDEBUG"] = function()
    DEBUG_MODE = not DEBUG_MODE
    print("|cffff9900[RatinguWoW]|r Дебаг режим:", DEBUG_MODE and "|cff00ff00ВКЛ|r" or "|cffff0000ВЫКЛ|r")
end

-- События
local eventHandler = CreateFrame("Frame")
eventHandler:RegisterEvent("PLAYER_LOGIN")
eventHandler:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventHandler:RegisterEvent("PVP_RATED_STATS_UPDATE")
eventHandler:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
eventHandler:SetScript("OnEvent", function()
    UpdateCharacterData()
    RefreshDisplay()
end)

-- print("|cffff9900[RatinguWoWx100Plus]|r Загружен. Используйте /wintokens для просмотра накопленных токенов")