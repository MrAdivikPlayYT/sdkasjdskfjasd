-- ============================================================
-- LOADER + AUTH + SINGLE LOAD PROTECTION
-- ============================================================

repeat task.wait() until game:IsLoaded()
print("[Loader] Game loaded, starting script...")

-- ---------- Decrypt helper ----------
local function _decrypt(s)
    local r = ""
    for i = 1, #s do
        r = r .. string.char(string.byte(s, i) - 3)
    end
    return r
end

-- ---------- Allowed UserIDs (encrypted with +3) ----------
local _ALLOWED = {
    "6:8884<59<",
    "636;6635:",
    "5363<54474",
    "67::79;3;4",
    "443676<;39",
    "43;39638:53",
    "43;564599::",
    "4434494<498",
    "69;:9::356",
    "484;<99<;;",
}

-- ---------- Auth check ----------
local _allowed = false
local _myId = game.Players.LocalPlayer and game.Players.LocalPlayer.UserId
if _myId then
    for _, v in ipairs(_ALLOWED) do
        local num = tonumber(_decrypt(v))
        if num and num == _myId then
            _allowed = true
            break
        end
    end
end

if not _allowed then
    pcall(function() game.Players.LocalPlayer:Kick("No access") end)
    print("[Auth] Access denied for UserId: " .. tostring(_myId))
    return
end
print("[Auth] Access granted for UserId: " .. tostring(_myId))

-- ============================================================
-- LOCAL WINDUI LOADER (with cache fallback)
-- ============================================================

local WINDUI_DIR  = "SkibidiDefenseMacroScript/libs"
local WINDUI_PATH = WINDUI_DIR .. "/WindUI.lua"
local WINDUI_URL  = "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"

pcall(function()
    if not isfolder("SkibidiDefenseMacroScript") then makefolder("SkibidiDefenseMacroScript") end
    if not isfolder(WINDUI_DIR) then makefolder(WINDUI_DIR) end
end)

local function SafeLoadLibraryFromSource(src, label)
    local ok, result = pcall(function()
        if not src or src == "" then
            error("Empty source: " .. tostring(label))
        end
        local fn, err = loadstring(src)
        if not fn then
            error("Compile error: " .. tostring(err))
        end
        local callOk, lib = pcall(fn)
        if not callOk then
            error("Runtime error: " .. tostring(lib))
        end
        return lib
    end)
    if ok then
        return result
    else
        warn("[Loader] Failed to load library (" .. tostring(label) .. "): " .. tostring(result))
        return nil
    end
end

local function LoadWindUI()
    local src, sourceLabel

    if isfile and isfile(WINDUI_PATH) then
        local ok, data = pcall(readfile, WINDUI_PATH)
        if ok and data and data ~= "" then
            src = data
            sourceLabel = "local:" .. WINDUI_PATH
            print("[Loader] WindUI: using local file")
        end
    end

    if not src then
        print("[Loader] WindUI: downloading from URL...")
        local ok, data = pcall(game.HttpGet, game, WINDUI_URL)
        if ok and data and data ~= "" then
            src = data
            sourceLabel = "url"
            pcall(function() writefile(WINDUI_PATH, data) end)
            print("[Loader] WindUI: cached to " .. WINDUI_PATH)
        end
    end

    if not src then
        return nil, "no source (file missing and download failed)"
    end

    local lib = SafeLoadLibraryFromSource(src, sourceLabel)
    if not lib then
        return nil, "source found but failed to compile/run"
    end
    return lib, sourceLabel
end

-- ---------- Single load guard ----------
if _G.SkibidiDefenseLoaded then
    print("[Loader] Script already loaded, skipping...")
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Skibidi Defense",
            Text = "Script is already loaded!",
            Duration = 3
        })
    end)
    return
end
_G.SkibidiDefenseLoaded = true

-- ---------- Load WindUI ----------
local WindUI, windUiSource = LoadWindUI()
if not WindUI then
    _G.SkibidiDefenseLoaded = nil
    warn("[Loader] WindUI load failed: " .. tostring(windUiSource))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Skibidi Defense",
            Text = "Critical: UI failed to load!\nPlace WindUI.lua into " .. WINDUI_DIR,
            Duration = 10
        })
    end)
    return
end
print("[Loader] WindUI loaded successfully (" .. tostring(windUiSource) .. ")")

-- ============================================================
-- MAIN SCRIPT
-- ============================================================

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer or Players:GetPlayers()[1]

local CONFIG = {
    NAME = "Skibidi Defense",
    VERSION = "Dev 8.3 (Local UI + Lobby)"
}

-- ============================================================
-- MODE DETECTION
-- ============================================================

local _K1 = 14279693118

local function _safe(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return nil
end

local function _pid()
    return _safe(function() return game.PlaceId end)
end

local function IsLobby()
    local p = _pid()
    if not p then return false end
    return p == _K1
end

local function IsMatch()
    local p = _pid()
    if not p then return false end
    return p ~= _K1
end

local function GetMode()
    local p = _pid()
    if not p then return "UNKNOWN" end
    return p == _K1 and "LOBBY" or "MATCH"
end

local function _child(parent, name)
    return _safe(function()
        if parent then return parent:FindFirstChild(name) end
        return nil
    end)
end

-- ============================================================
-- SERVER NAMES
-- ============================================================

local SERVER_NAMES = {
    Story = {
        "Chapter 1", "Chapter 1.5", "Chapter 2", "Chapter 3",
        "Chapter 4", "Chapter 5", "Chapter 6", "Chapter 7",
        "Chapter 8", "Chapter 9",
    },
    MULTIVERSE = {
        "Multiverse Chapter 1",
        "Multiverse Chapter 1-3",
    },
    NIGHTMARE = {
        "Suspicious Detections", "Rise Of The Corruption",
        "Spreaded Corruption", "A Fight From the Past",
        "Land Of Creation", "The Final Showdown",
        "The Last Base", "Civil War", "Void",
    },
    EVENT = {
        "Act 1 2026", "Act 2 2026", "Act 3 2026",
        "Act -1", "Act -2", "Partner Takeover", "Skibi Trials",
    },
    VERSUS = {
        "Versus 1v1", "Versus 2v2", "Versus 3v3", "Versus 4v4",
    },
    Endless = {
        "Normal", "Roguelite",
    },
    EPISODES = {
        "Episode 79", "Humble Beginnings",
    },
}

local SERVER_TYPES = {
    "Story", "MULTIVERSE", "NIGHTMARE", "EVENT",
    "VERSUS", "Endless", "EPISODES", "ALL",
}

local function _getChapters(lobbyType)
    if not lobbyType then return {} end
    if lobbyType == "ALL" then
        local result, seen = {}, {}
        for _, key in ipairs({"Story", "MULTIVERSE", "NIGHTMARE", "EVENT", "VERSUS", "Endless", "EPISODES"}) do
            for _, name in ipairs(SERVER_NAMES[key] or {}) do
                if not seen[name] then
                    seen[name] = true
                    table.insert(result, name)
                end
            end
        end
        return result
    end
    if SERVER_NAMES[lobbyType] then return SERVER_NAMES[lobbyType] end
    local lower = string.lower(lobbyType)
    for key, list in pairs(SERVER_NAMES) do
        if string.lower(key) == lower then return list end
    end
    return {}
end

-- ============================================================
-- REMOTES
-- ============================================================

local Events
local LobbyEvents
local speedRemote
local skipRemote
local replayRemote
local abilityRemote

local _createServerRemote
local _lobbyStartRemote
local readyButtonRemote

local RemoteMap = {}

local function refreshRemotes()
    _safe(function()
        Events = _child(RS, "Event")
        LobbyEvents = _child(RS, "Events")

        local gameFolder = _child(RS, "Game")
        local speedFolder = _child(gameFolder, "Speed")

        speedRemote = _child(speedFolder, "Change")
        skipRemote = _child(Events, "waveSkip")
        replayRemote = _child(Events, "ReplayCore")

        local towerScript = _child(RS, "TowerScript")
        abilityRemote = _child(towerScript, "spawnTowerAbility")

        _createServerRemote = _child(LobbyEvents, "createServer")
        _lobbyStartRemote = _child(LobbyEvents, "start")

        local gameStart = _child(RS, "GAME_START")
        readyButtonRemote = _child(gameStart, "readyButton")
    end)

    RemoteMap = {}

    _safe(function()
        if Events then
            local placeTower = _child(Events, "placeTower")
            local upgradeTower = _child(Events, "UpgradeTower")
            local removeTower = _child(Events, "RemoveTower")

            if placeTower then RemoteMap[placeTower] = "placeTower" end
            if upgradeTower then RemoteMap[upgradeTower] = "upgradeTower" end
            if removeTower then RemoteMap[removeTower] = "removeTower" end
        end

        if speedRemote then RemoteMap[speedRemote] = "speedChange" end
        if skipRemote then RemoteMap[skipRemote] = "waveSkip" end
        if abilityRemote then RemoteMap[abilityRemote] = "ability" end
    end)
end

refreshRemotes()

-- ============================================================
-- STATE
-- ============================================================

local State = {
    rec = false,
    events = {},
    startTime = 0,

    currentSpeed = 1,
    autoSpeed = false,
    selectedSpeed = 1,
    speedDelay = 1,

    autoPlay = false,
    loopCount = -1,

    spamSpeed = false,
    autoSkip = false,
    spamSkip = false,

    autoReplay = false,
    spamReplay = false,

    autoStart = false,
    autoLoad = true,

    autoReturn = false,
    returnRounds = 2,
    currentRound = 1,

    logEnabled = false,

    lastLoadedMacro = "",
    currentEventIndex = 0,
    totalEvents = 0,

    isPlaying = false,
    loop = false,

    lastGameEndedState = false,
    gameEndedCount = 0,

    lobbyType = "Story",
    lobbyChapter = "Chapter 1",
    useDirectRemotes = true,
    autoCreateParty = false,
    autoStartLobby = false
}

-- ============================================================
-- LOG SYSTEM
-- ============================================================

local UI_LogParagraph
local recordToggle
local updateStatus
local autoPlayToggle

local function AddLog(message)
    _safe(function() print(message) end)
    if State.logEnabled and UI_LogParagraph then
        _safe(function()
            local currentDesc = UI_LogParagraph.Desc or ""
            local newDesc = message .. "\n" .. currentDesc
            local lines = {}
            for line in newDesc:gmatch("[^\r\n]+") do
                table.insert(lines, line)
            end
            while #lines > 15 do
                table.remove(lines)
            end
            UI_LogParagraph:SetDesc(table.concat(lines, "\n"))
        end)
    end
end

local function getMoney()
    return _safe(function()
        local ls = LocalPlayer and LocalPlayer:FindFirstChild("leaderstats")
        local money = ls and ls:FindFirstChild("Money")
        return money and money.Value or 0
    end) or 0
end

local function getTowerCount()
    local count = 0
    for _, event in ipairs(State.events) do
        if event.name == "placeTower" then count += 1 end
    end
    return count
end

local function isGameEnded()
    if not IsMatch() then return false end
    return _safe(function()
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        local ge = pg and pg:FindFirstChild("GameEnded")
        return ge ~= nil and ge.Enabled == true
    end) or false
end

-- ============================================================
-- HOOK via OTH
-- ============================================================

local hookInstalled = false
local othHookedFn = nil
local othOriginal = nil
local unhookNamecall
local installHook

installHook = function()
    if hookInstalled then return end
    _safe(function()
        local mt = getrawmetatable(game)
        othOriginal = mt.__namecall

        local function hookLogic(self, ...)
            local method = getnamecallmethod()

            if IsMatch()
                and State.rec
                and (method == "FireServer" or method == "InvokeServer")
                and RemoteMap[self]
            then
                local args = {...}
                if RemoteMap[self] == "waveSkip" and State.autoSkip then
                    return othOriginal(self, ...)
                end

                local argsString = ""
                for i, v in ipairs(args) do
                    if i > 1 then argsString = argsString .. ", " end
                    argsString = argsString .. tostring(v)
                end

                if RemoteMap[self] == "speedChange" then
                    State.currentSpeed = args[1]
                end

                table.insert(State.events, {
                    name = RemoteMap[self],
                    method = method,
                    args = args,
                    time = os.clock() - State.startTime
                })

                AddLog(("[Macro] %s #%d | Args: (%s) | %.2fs"):format(
                    RemoteMap[self], #State.events, argsString,
                    os.clock() - State.startTime
                ))
            end

            return othOriginal(self, ...)
        end

        local othOk = false
        if type(oth) == "table" and type(oth.hook) == "function" then
            othOk = pcall(function()
                othHookedFn = oth.hook(othOriginal, function(self, ...)
                    return hookLogic(self, ...)
                end)
            end)
        end

        if othOk and othHookedFn then
            hookInstalled = true
            AddLog("[Hook] OTH hook installed (Match only)")
        else
            local fallbackOk = pcall(function()
                hookmetamethod(game, "__namecall", newcclosure(hookLogic))
            end)
            if fallbackOk then
                hookInstalled = true
                AddLog("[Hook] hookmetamethod fallback installed")
            else
                AddLog("[Hook] FAILED to install hook")
            end
        end
    end)
end

unhookNamecall = function()
    if not hookInstalled then return end
    _safe(function()
        if othHookedFn and type(oth) == "table" and type(oth.unhook) == "function" then
            pcall(function() oth.unhook(othHookedFn) end)
            AddLog("[Hook] OTH unhook done (Returning to Lobby)")
        end
    end)
    hookInstalled = false
    othHookedFn = nil
end

-- ============================================================
-- FOLDERS & CONFIG
-- ============================================================

local ROOT_FOLDER = "SkibidiDefenseMacroScript"
local MACROS_FOLDER = ROOT_FOLDER .. "/Macros"
local SETTINGS_FILE = ROOT_FOLDER .. "/config.json"

local inputName = ""
local selectedMacro = ""

local function ensureFolders()
    _safe(function()
        if not isfolder or not makefolder then return end
        if not isfolder(ROOT_FOLDER) then makefolder(ROOT_FOLDER) end
        if not isfolder(MACROS_FOLDER) then makefolder(MACROS_FOLDER) end
        if not isfolder(WINDUI_DIR) then makefolder(WINDUI_DIR) end
    end)
end

local function saveSettings(extraName, extraSelected)
    _safe(function()
        ensureFolders()
        local data = {
            name = extraName or inputName or "",
            selected = extraSelected or selectedMacro or "",
            autoSpeed = State.autoSpeed,
            selectedSpeed = State.selectedSpeed,
            speedDelay = State.speedDelay,
            currentSpeed = State.currentSpeed,
            autoPlay = State.autoPlay,
            autoSkip = State.autoSkip,
            autoReplay = State.autoReplay,
            autoStart = State.autoStart,
            autoLoad = State.autoLoad,
            autoReturn = State.autoReturn,
            returnRounds = State.returnRounds,
            loopCount = State.loopCount,
            currentRound = State.currentRound,
            gameEndedCount = State.gameEndedCount,
            logEnabled = State.logEnabled,
            lobbyType = State.lobbyType,
            lobbyChapter = State.lobbyChapter,
            useDirectRemotes = State.useDirectRemotes,
            autoCreateParty = State.autoCreateParty,
            autoStartLobby = State.autoStartLobby
        }
        writefile(SETTINGS_FILE, HttpService:JSONEncode(data))
    end)
end

local function loadSettings()
    ensureFolders()
    if not _safe(function() return isfile and isfile(SETTINGS_FILE) end) then
        return "", ""
    end
    local success, data = pcall(function()
        return HttpService:JSONDecode(readfile(SETTINGS_FILE))
    end)
    if not success or type(data) ~= "table" then
        return "", ""
    end

    State.autoSpeed = data.autoSpeed == true
    State.selectedSpeed = tonumber(data.selectedSpeed) or 1
    State.speedDelay = tonumber(data.speedDelay) or 1
    State.currentSpeed = tonumber(data.currentSpeed) or 1
    State.autoPlay = data.autoPlay == true
    State.autoSkip = data.autoSkip == true
    State.autoReplay = data.autoReplay == true
    State.autoStart = data.autoStart == true
    State.autoLoad = data.autoLoad ~= false
    State.autoReturn = data.autoReturn == true
    State.returnRounds = math.max(1, tonumber(data.returnRounds) or 2)
    State.loopCount = tonumber(data.loopCount) or -1
    State.currentRound = tonumber(data.currentRound) or 1
    State.gameEndedCount = tonumber(data.gameEndedCount) or 0
    State.logEnabled = data.logEnabled == true

    State.lobbyType = data.lobbyType or "Story"
    State.lobbyChapter = data.lobbyChapter or "Chapter 1"
    State.useDirectRemotes = data.useDirectRemotes ~= false
    State.autoCreateParty = data.autoCreateParty == true
    State.autoStartLobby = data.autoStartLobby == true

    return data.name or "", data.selected or ""
end

local savedName, savedSelected = loadSettings()
inputName = savedName
selectedMacro = savedSelected

-- ============================================================
-- SERIALIZATION / MACRO FILES
-- ============================================================

local function serializeArg(v)
    local t = _safe(function() return typeof(v) end)
    if t == "CFrame" then
        local p = v.Position
        return { __type = "CFrame", pos = {p.X, p.Y, p.Z} }
    elseif t == "Vector3" then
        return { __type = "Vector3", vec = {v.X, v.Y, v.Z} }
    end
    return v
end

local function deserializeArg(v)
    if type(v) == "table" and v.__type == "CFrame" then
        return _safe(function() return CFrame.new(v.pos[1], v.pos[2], v.pos[3]) end) or v
    elseif type(v) == "table" and v.__type == "Vector3" then
        return _safe(function() return Vector3.new(v.vec[1], v.vec[2], v.vec[3]) end) or v
    end
    return v
end

local function saveMacro(name)
    if not name or name == "" then
        AddLog("[Macro] Name is empty")
        return false
    end
    ensureFolders()
    local data = { events = {} }
    for _, event in ipairs(State.events) do
        local args = {}
        for i, value in ipairs(event.args) do
            args[i] = serializeArg(value)
        end
        table.insert(data.events, {
            name = event.name,
            method = event.method,
            args = args,
            time = event.time
        })
    end
    local success, err = pcall(function()
        writefile(MACROS_FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    end)
    if success then
        State.lastLoadedMacro = name
        AddLog("[Macro] Saved: " .. name)
        return true
    end
    AddLog("[Macro] Save error: " .. tostring(err))
    return false
end

local function loadMacro(name)
    local path = MACROS_FOLDER .. "/" .. name .. ".json"
    if not _safe(function() return isfile and isfile(path) end) then
        AddLog("[Macro] File not found: " .. name)
        return false
    end
    local success, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not success or type(data) ~= "table" then
        AddLog("[Macro] Invalid macro file")
        return false
    end
    State.events = {}
    for _, event in ipairs(data.events or {}) do
        local args = {}
        for i, value in ipairs(event.args or {}) do
            args[i] = deserializeArg(value)
        end
        table.insert(State.events, {
            name = event.name,
            method = event.method or "FireServer",
            args = args,
            time = event.time or 0
        })
    end
    State.lastLoadedMacro = name
    AddLog("[Macro] Loaded: " .. name)
    return true
end

local function deleteMacro(name)
    local path = MACROS_FOLDER .. "/" .. name .. ".json"
    if _safe(function() return isfile and isfile(path) end) then
        _safe(function() delfile(path) end)
        AddLog("[Macro] Deleted: " .. name)
        return true
    end
    return false
end

local function listMacros()
    ensureFolders()
    local names = {}
    _safe(function()
        if not listfiles then return end
        for _, path in ipairs(listfiles(MACROS_FOLDER)) do
            local name = path:match("([^/\\]+)%.json$")
            if name then table.insert(names, name) end
        end
    end)
    table.sort(names)
    return names
end

-- ============================================================
-- LOBBY ACTIONS (create party / start)
-- ============================================================

local _lobbySelectedType = "Story"
local _lobbySelectedChapter = "Chapter 1"

local function _tryRemoteVariants(remote, variants, label)
    if not remote then
        AddLog("[Lobby] " .. label .. ": remote not found")
        return false
    end
    for _, args in ipairs(variants) do
        local ok = pcall(function()
            remote:FireServer(table.unpack(args))
        end)
        if ok then
            AddLog("[Lobby] " .. label .. ": sent (variant with " .. #args .. " args)")
            return true
        end
    end
    AddLog("[Lobby] " .. label .. ": all variants failed")
    return false
end

function directCreateParty()
    refreshRemotes()
    if not _createServerRemote then
        AddLog("[Lobby] createServer remote missing")
        return false
    end

    local t = _lobbySelectedType or State.lobbyType or "Story"
    local c = _lobbySelectedChapter or State.lobbyChapter or "Chapter 1"

    -- Пробуем разные варианты сигнатуры, чтобы зацепиться за реальную
    local variants = {
        {t, c},         -- (type, chapter)
        {c},            -- (chapter)
        {t},            -- (type)
        {},             -- ()
    }
    return _tryRemoteVariants(_createServerRemote, variants, "Create Party")
end

function directStart()
    refreshRemotes()
    if not _lobbyStartRemote then
        AddLog("[Lobby] lobby start remote missing")
        return false
    end
    local variants = {
        {},
        {true},
        {_lobbySelectedType or State.lobbyType or "Story"},
    }
    return _tryRemoteVariants(_lobbyStartRemote, variants, "Start")
end

-- ============================================================
-- AUTO SPEED / SKIP / REPLAY
-- ============================================================

local function startSpeedSpam()
    if State.spamSpeed then return end
    State.spamSpeed = true
    task.spawn(function()
        while State.spamSpeed do
            if IsMatch() then
                refreshRemotes()
                if speedRemote then
                    pcall(function() speedRemote:FireServer(State.selectedSpeed) end)
                end
            end
            task.wait(math.max(0.5, State.speedDelay))
        end
    end)
end

local function stopSpeedSpam() State.spamSpeed = false end

local function startSkipSpam()
    if State.spamSkip then return end
    State.spamSkip = true
    task.spawn(function()
        while State.spamSkip do
            if IsMatch() then
                refreshRemotes()
                if skipRemote then
                    pcall(function() skipRemote:FireServer(true) end)
                end
            end
            task.wait(0.5)
        end
    end)
end

local function stopSkipSpam() State.spamSkip = false end

local returningToLobby = false

local function startReplaySpam()
    if State.spamReplay then return end
    State.spamReplay = true
    task.spawn(function()
        while State.spamReplay do
            if IsMatch() then
                refreshRemotes()
                if not returningToLobby and isGameEnded() and replayRemote then
                    pcall(function() replayRemote:FireServer() end)
                end
            end
            task.wait(1)
        end
    end)
end

local function stopReplaySpam() State.spamReplay = false end

-- ============================================================
-- UNLOAD / AUTO LOAD / START
-- ============================================================

local function unloadAll()
    AddLog("[Script] Unloading...")
    State.autoSpeed = false
    State.autoSkip = false
    State.autoReplay = false
    State.autoPlay = false
    State.autoStart = false
    State.rec = false
    State.isPlaying = false
    State.loop = false
    stopSpeedSpam()
    stopSkipSpam()
    stopReplaySpam()
    _safe(unhookNamecall)
    saveSettings(inputName, selectedMacro)
    AddLog("[Script] Unloaded.")
end

local macroList = listMacros()
if not table.find(macroList, selectedMacro) then
    selectedMacro = macroList[1] or ""
end
if State.autoLoad and selectedMacro ~= "" then
    loadMacro(selectedMacro)
end

local autoStartRunning = false
local autoStartSent = false

local function startAutoStart()
    if autoStartRunning or autoStartSent or not State.autoStart then return end
    autoStartRunning = true
    task.spawn(function()
        while State.autoStart and not autoStartSent do
            if IsMatch() then
                refreshRemotes()
                if readyButtonRemote then
                    local success = pcall(function()
                        readyButtonRemote:FireServer(true)
                    end)
                    if success then
                        autoStartSent = true
                        AddLog("[AutoStart] Start request sent")
                        break
                    end
                end
            end
            task.wait(2)
        end
        autoStartRunning = false
    end)
end

-- ============================================================
-- PLAYBACK
-- ============================================================

local function play()
    if not IsMatch() then return end
    refreshRemotes()

    if State.autoLoad and selectedMacro ~= "" and State.lastLoadedMacro ~= selectedMacro then
        loadMacro(selectedMacro)
    end

    if #State.events == 0 then return end

    State.isPlaying = true
    State.totalEvents = #State.events
    State.currentEventIndex = 0

    local startT = os.clock()

    for i, event in ipairs(State.events) do
        if not State.isPlaying or not IsMatch() then break end
        local waitT = event.time - (os.clock() - startT)
        if waitT > 0 then task.wait(waitT) end
        if not State.isPlaying or not IsMatch() then break end

        refreshRemotes()
        State.currentEventIndex = i

        local remote = nil
        for rem, name in pairs(RemoteMap) do
            if name == event.name then
                remote = rem
                break
            end
        end

        if remote then
            if event.name == "speedChange" and State.autoSpeed then
            elseif event.name == "waveSkip" and State.autoSkip then
            else
                pcall(function()
                    if event.method == "InvokeServer" then
                        remote:InvokeServer(table.unpack(event.args))
                    else
                        remote:FireServer(table.unpack(event.args))
                    end
                end)
            end
        end
    end

    State.isPlaying = false
    State.currentEventIndex = 0
    if updateStatus then updateStatus() end
end

local function startLoop()
    if State.loop then return end
    if selectedMacro ~= "" then loadMacro(selectedMacro) end
    State.loop = true
    task.spawn(function()
        local count = 0
        while State.loop do
            if IsMatch() and selectedMacro ~= "" then
                play()
                if not State.loop then break end
                count += 1
                if State.loopCount ~= -1 and count >= State.loopCount then
                    State.loop = false
                    State.autoPlay = false
                    if autoPlayToggle then pcall(function() autoPlayToggle:Set(false) end) end
                    saveSettings(inputName, selectedMacro)
                    break
                end
            end
            task.wait(0.5)
        end
    end)
end

local function stopLoop()
    State.loop = false
    State.isPlaying = false
end

-- ============================================================
-- ROUND TRACKING helpers
-- ============================================================

local roundActionRunning = false

local function findGameButton(buttonNames)
    if not IsMatch() or not isGameEnded() then return nil end
    return _safe(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local ge = pg and pg:FindFirstChild("GameEnded")
        local frame = ge and ge:FindFirstChild("Frame")
        if not frame then return nil end
        local wanted = {}
        for _, name in ipairs(buttonNames) do wanted[string.lower(name)] = true end
        for _, obj in ipairs(frame:GetDescendants()) do
            if obj:IsA("GuiButton") then
                local objectName = string.lower(obj.Name)
                local buttonText = ""
                pcall(function() buttonText = string.lower(obj.Text) end)
                if wanted[objectName] or wanted[buttonText] then
                    if obj.Visible then return obj end
                end
            end
        end
        return nil
    end)
end

local function waitForGameButton(buttonNames, timeout)
    local started = os.clock()
    while os.clock() - started < timeout do
        if not IsMatch() or not isGameEnded() then return nil end
        local button = findGameButton(buttonNames)
        if button then return button end
        task.wait(0.25)
    end
    return nil
end

local function clickGameButton(button, buttonName)
    if not IsMatch() or not isGameEnded() or not button or not button.Visible then return false end
    local success = false
    _safe(function()
        local connections = getconnections(button.MouseButton1Click)
        if connections and #connections > 0 then
            for _, connection in ipairs(connections) do
                if connection.Enabled ~= false then
                    local fired = pcall(function() connection:Fire() end)
                    if fired then success = true; break end
                end
            end
        end
    end)
    if not success and IsMatch() and isGameEnded() then
        _safe(function() button:Activate(); success = true end)
    end
    return success
end

-- ============================================================
-- ROUND TRACKING LOOP
-- ============================================================

task.spawn(function()
    while task.wait(0.5) do
        local inMatch = IsMatch()

        if not inMatch then
            if hookInstalled then
                unhookNamecall()
                AddLog("[Safety] Hook removed: Entered Lobby")
            end
                        continue
        end

        if not hookInstalled then
            installHook()
        end

        local pg = _safe(function() return LocalPlayer:FindFirstChild("PlayerGui") end)
        local ge = _safe(function() return pg and pg:FindFirstChild("GameEnded") end)
        if not ge then continue end

        if ge.Enabled and State.rec then
            State.rec = false
            if recordToggle then pcall(function() recordToggle:Set(false) end) end
            if inputName ~= "" then
                saveMacro(inputName)
                selectedMacro = inputName
                saveSettings(inputName, selectedMacro)
            end
            if updateStatus then updateStatus() end
            AddLog("[Macro] Recording automatically stopped")
        end

        if not ge.Enabled then
            State.lastGameEndedState = false
            roundActionRunning = false
            if returningToLobby then
                returningToLobby = false
                AddLog("[Match] Lobby return confirmed")
                if State.autoStart then
                    autoStartSent = false
                    task.wait(1)
                    startAutoStart()
                end
            end
            continue
        end

        if State.lastGameEndedState or roundActionRunning then continue end

        State.lastGameEndedState = true
        roundActionRunning = true
        State.gameEndedCount += 1
        AddLog("[Round] GameEnded detected: " .. State.gameEndedCount)

        if State.autoReturn and State.gameEndedCount >= State.returnRounds then
            returningToLobby = true
            stopReplaySpam()
            AddLog("[Match] Round limit reached. Preparing return...")
            State.gameEndedCount = 0
            State.currentRound = 1
            saveSettings(inputName, selectedMacro)

            task.spawn(function()
                task.wait(1)
                if not IsMatch() or not isGameEnded() then
                    returningToLobby = false; roundActionRunning = false; return
                end
                local backButton = waitForGameButton({
                    "back TextButton", "back", "Back",
                    "return to lobby", "Return to Lobby",
                    "returntolobby", "ReturnToLobby"
                }, 15)
                if not IsMatch() or not isGameEnded() then
                    returningToLobby = false; roundActionRunning = false; return
                end
                if backButton then
                    if clickGameButton(backButton, "Back / Return to Lobby") then
                        AddLog("[Match] Return request sent")
                    else
                        returningToLobby = false; roundActionRunning = false
                    end
                else
                    AddLog("[Match] Return button not found")
                    returningToLobby = false; roundActionRunning = false
                end
            end)
        else
            AddLog("[Round] Replay: " .. State.gameEndedCount .. "/" .. State.returnRounds)
            State.currentRound = State.gameEndedCount
            saveSettings(inputName, selectedMacro)

            task.spawn(function()
                task.wait(1)
                if not IsMatch() or not isGameEnded() then
                    roundActionRunning = false; return
                end
                local replayButton = waitForGameButton({
                    "replay TextButton", "replay", "Replay"
                }, 10)
                if not IsMatch() or not isGameEnded() then
                    roundActionRunning = false; return
                end
                if replayButton then
                    if clickGameButton(replayButton, "Replay") then
                        AddLog("[Replay] Click request sent")
                    else
                        roundActionRunning = false
                    end
                else
                    AddLog("[Replay] Button not found")
                    roundActionRunning = false
                end
            end)
        end
    end
end)

-- ============================================================
-- UI WINDOW
-- ============================================================

local Window = WindUI:CreateWindow({
    Title = CONFIG.NAME,
    Author = "Private Script",
    Folder = "SkibidiDefense",
    Size = UDim2.fromOffset(500, 480),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 150
})

pcall(function()
    Window:Tag({
        Title = CONFIG.VERSION,
        Color = Color3.fromRGB(80, 180, 120),
        Radius = 8
    })
end)

-- ============================================================
-- LOBBY TAB
-- ============================================================

local _selectedLobbyType = State.lobbyType or "Story"
local _selectedChapter = State.lobbyChapter or "Chapter 1"
local _useDirectRemotes = true

if IsLobby() then
    _useDirectRemotes = true
    State.useDirectRemotes = true
end

local LobbyTab = Window:Tab({ Title = "Lobby" })

LobbyTab:Section({ Title = "Party Settings" })

local function _getChaptersSafe(lobbyType)
    if not lobbyType then return {} end
    if lobbyType == "ALL" then
        local result, seen = {}, {}
        for _, key in ipairs({"Story", "MULTIVERSE", "NIGHTMARE", "EVENT", "VERSUS", "Endless", "EPISODES"}) do
            for _, name in ipairs(SERVER_NAMES[key] or {}) do
                if not seen[name] then
                    seen[name] = true
                    table.insert(result, name)
                end
            end
        end
        return result
    end
    if SERVER_NAMES[lobbyType] then return SERVER_NAMES[lobbyType] end
    local lower = string.lower(lobbyType)
    for key, list in pairs(SERVER_NAMES) do
        if string.lower(key) == lower then return list end
    end
    return {}
end

local _initialChapters = _getChaptersSafe(State.lobbyType or "Story")
if #_initialChapters == 0 then _initialChapters = {"Chapter 1"} end

local _initialChapter = State.lobbyChapter or "Chapter 1"
if not table.find(_initialChapters, _initialChapter) then
    _initialChapter = _initialChapters[1]
end

local _chapterDropdown = nil

local _typeDropdown = LobbyTab:Dropdown({
    Title = "Type",
    Values = SERVER_TYPES,
    Value = State.lobbyType or "Story",
    Callback = function(value)
        _selectedLobbyType = value
        _lobbySelectedType = value
        State.lobbyType = value
        saveSettings(inputName, selectedMacro)
        AddLog("[Lobby] Type: " .. tostring(value))

        if _chapterDropdown then
            local chapters = _getChaptersSafe(value)
            if #chapters > 0 then
                pcall(function() _chapterDropdown:Refresh(chapters) end)
                local toSelect = State.lobbyChapter
                if not table.find(chapters, toSelect) then
                    toSelect = chapters[1]
                end
                _selectedChapter = toSelect
                _lobbySelectedChapter = toSelect
                State.lobbyChapter = toSelect
                pcall(function() _chapterDropdown:Select(toSelect) end)
                saveSettings(inputName, selectedMacro)
            end
        end
    end
})

_chapterDropdown = LobbyTab:Dropdown({
    Title = "Chapter",
    Values = _initialChapters,
    Value = _initialChapter,
    Callback = function(v)
        _selectedChapter = v
        _lobbySelectedChapter = v
        State.lobbyChapter = v
        saveSettings(inputName, selectedMacro)
        AddLog("[Lobby] Chapter: " .. tostring(v))
    end
})

_lobbySelectedType = _selectedLobbyType
_lobbySelectedChapter = _initialChapter

LobbyTab:Toggle({
    Title = "Use Direct Remotes",
    Desc = "LOCKED: always ON in Lobby",
    Value = true,
    Callback = function(s)
        if IsLobby() then
            _useDirectRemotes = true
            State.useDirectRemotes = true
            saveSettings(inputName, selectedMacro)
            AddLog("[Lobby] Direct Remotes LOCKED to true in Lobby")
        else
            _useDirectRemotes = s
            State.useDirectRemotes = s
            saveSettings(inputName, selectedMacro)
        end
    end
})

LobbyTab:Section({ Title = "Controls" })

LobbyTab:Button({
    Title = "Create Party",
    Callback = function()
        directCreateParty()
    end
})

local _startBusy = false

LobbyTab:Button({
    Title = "Start",
    Callback = function()
        if _startBusy then return end
        _startBusy = true
        task.spawn(function()
            task.wait(5)
            directStart()
            task.wait(2)
            _startBusy = false
        end)
    end
})

LobbyTab:Section({ Title = "Auto Lobby" })

local autoCreateParty = State.autoCreateParty == true
local autoStartLobby = State.autoStartLobby == true

LobbyTab:Toggle({
    Title = "Auto Create Party",
    Value = State.autoCreateParty == true,
    Callback = function(s)
        autoCreateParty = s
        State.autoCreateParty = s
        saveSettings(inputName, selectedMacro)
        if s then
            task.spawn(function()
                while autoCreateParty do
                    directCreateParty()
                    autoCreateParty = false
                    State.autoCreateParty = false
                    saveSettings(inputName, selectedMacro)
                    break
                end
            end)
        end
    end
})

LobbyTab:Toggle({
    Title = "Auto Start Lobby",
    Value = State.autoStartLobby == true,
    Callback = function(s)
        autoStartLobby = s
        State.autoStartLobby = s
        saveSettings(inputName, selectedMacro)
        if s then
            task.spawn(function()
                task.wait(5)
                if autoStartLobby then
                    directStart()
                    autoStartLobby = false
                    State.autoStartLobby = false
                    saveSettings(inputName, selectedMacro)
                end
            end)
        end
    end
})

-- ============================================================
-- MATCH TAB
-- ============================================================

local MatchTab = Window:Tab({ Title = "Match" })

MatchTab:Section({ Title = "Auto Speed" })

local speedToggle = MatchTab:Toggle({
    Title = "Enable Auto Speed",
    Value = State.autoSpeed,
    Callback = function(s)
        State.autoSpeed = s
        saveSettings(inputName, selectedMacro)
        if s then startSpeedSpam() else stopSpeedSpam() end
    end
})

MatchTab:Dropdown({
    Title = "Speed",
    Values = {"1x", "2x", "3x", "4x", "5x", "6x"},
    Value = tostring(State.selectedSpeed) .. "x",
    Callback = function(v)
        State.selectedSpeed = tonumber(v:match("%d+")) or 1
        saveSettings(inputName, selectedMacro)
    end
})

MatchTab:Slider({
    Title = "Delay (sec)",
    Value = { Min = 0.5, Max = 10, Default = State.speedDelay },
    Step = 0.1,
    Callback = function(v)
        State.speedDelay = v
        saveSettings(inputName, selectedMacro)
    end
})

MatchTab:Section({ Title = "Auto Settings" })

MatchTab:Toggle({
    Title = "Auto Load Macro",
    Value = State.autoLoad,
    Callback = function(s)
        State.autoLoad = s
        saveSettings(inputName, selectedMacro)
    end
})

local autoStartToggle

autoStartToggle = MatchTab:Toggle({
    Title = "Auto Start Match",
    Desc = "Работает только в Match",
    Value = State.autoStart,
    Callback = function(s)
        State.autoStart = s
        if not s then autoStartSent = false end
        saveSettings(inputName, selectedMacro)
        if s then startAutoStart() end
    end
})

MatchTab:Toggle({
    Title = "Auto Return (X Rounds)",
    Desc = "Returns to lobby after X rounds",
    Value = State.autoReturn,
    Callback = function(s)
        State.autoReturn = s
        saveSettings(inputName, selectedMacro)
    end
})

MatchTab:Input({
    Title = "Rounds to Return",
    Placeholder = "2",
    Value = tostring(State.returnRounds),
    Callback = function(v)
        State.returnRounds = math.max(1, tonumber(v) or 2)
        saveSettings(inputName, selectedMacro)
    end
})

MatchTab:Button({
    Title = "Reset Rounds",
    Desc = "Resets round counter",
    Callback = function()
        State.gameEndedCount = 0
        State.currentRound = 1
        State.lastGameEndedState = false
        roundActionRunning = false
        returningToLobby = false
        saveSettings(inputName, selectedMacro)
        AddLog("[Round] Counter reset")
        if updateStatus then updateStatus() end
    end
})

local skipToggle = MatchTab:Toggle({
    Title = "Enable Auto Skip",
    Value = State.autoSkip,
    Callback = function(s)
        State.autoSkip = s
        saveSettings(inputName, selectedMacro)
        if s then startSkipSpam() else stopSkipSpam() end
    end
})

local replayToggle = MatchTab:Toggle({
    Title = "Enable Auto Replay",
    Value = State.autoReplay,
    Callback = function(s)
        State.autoReplay = s
        saveSettings(inputName, selectedMacro)
        if s then startReplaySpam() else stopReplaySpam() end
    end
})

MatchTab:Button({
    Title = "Force Return to Lobby",
    Desc = "Кликает Back в GameEnded",
    Callback = function()
        if not isGameEnded() then
            AddLog("[Match] Вы не на экране GameEnded.")
            return
        end
        task.spawn(function()
            local btn = waitForGameButton({
                "back TextButton", "back", "Back",
                "return to lobby", "Return to Lobby",
                "returntolobby", "ReturnToLobby"
            }, 10)
            if btn then clickGameButton(btn, "Back / Return to Lobby")
            else AddLog("[Match] Кнопка Back не найдена") end
        end)
    end
})

-- ============================================================
-- MACRO TAB
-- ============================================================

local MacroTab = Window:Tab({ Title = "Macro" })

MacroTab:Section({ Title = "Status" })

local statusParagraph = MacroTab:Paragraph({
    Title = "● STOP",
    Desc = "Events: 0 • Towers: 0\nMoney: 0 • Speed: 1x\nRound: 0 / 2"
})

updateStatus = function()
    _safe(function()
        local status
        if State.rec then
            status = "● REC"
        elseif State.loop or State.isPlaying then
            if State.isPlaying then
                status = string.format("● PLAY %d / %d", State.currentEventIndex, State.totalEvents)
            else
                status = "● PLAY"
            end
        else
            status = "● STOP"
        end

        local speedText = State.autoSpeed
            and (tostring(State.selectedSpeed) .. "x [AUTO]")
            or (tostring(State.currentSpeed) .. "x")

        statusParagraph:SetTitle(status)
        statusParagraph:SetDesc(string.format(
            "Mode: %s\nEvents: %d • Towers: %d\nMoney: %s • Speed: %s\nRound: %d / %d\nServer: %s",
            GetMode(), #State.events, getTowerCount(),
            tostring(getMoney()), speedText,
            State.gameEndedCount, State.returnRounds,
            tostring(_selectedChapter)
        ))
    end)
end

updateStatus()

MacroTab:Section({ Title = "Recording" })

recordToggle = MacroTab:Toggle({
    Title = "Record",
    Value = false,
    Callback = function(s)
        State.rec = s
        if s then
            if not IsMatch() then
                AddLog("[Macro] Recording enabled. Waiting for Match.")
            else
                State.events = {}
                State.startTime = os.clock()
                State.currentSpeed = 1
                AddLog("[Macro] Recording started: " .. inputName)
            end
        else
            AddLog("[Macro] Recording stopped. Events: " .. #State.events)
            if inputName ~= "" then
                if saveMacro(inputName) then
                    selectedMacro = inputName
                    saveSettings(inputName, selectedMacro)
                    macroList = listMacros()
                end
            end
        end
        updateStatus()
    end
})

MacroTab:Button({
    Title = "Clear",
    Callback = function()
        State.events = {}
        State.startTime = os.clock()
        updateStatus()
        AddLog("[Macro] Events cleared")
    end
})

MacroTab:Section({ Title = "Files" })

MacroTab:Input({
    Title = "Macro Name",
    Placeholder = "test",
    Value = inputName,
    Callback = function(v)
        inputName = v
        saveSettings(inputName, selectedMacro)
    end
})

local macroDropdown

local function rebuildDropdown()
    if macroDropdown then
        pcall(function() macroDropdown:Destroy() end)
    end
    macroDropdown = MacroTab:Dropdown({
        Title = "Saved",
        Values = macroList,
        Value = selectedMacro,
        Callback = function(v)
            selectedMacro = v
            saveSettings(inputName, selectedMacro)
            updateStatus()
        end
    })
end

rebuildDropdown()

MacroTab:Button({
    Title = "Save Manually",
    Callback = function()
        if inputName ~= "" then
            if saveMacro(inputName) then
                selectedMacro = inputName
                macroList = listMacros()
                rebuildDropdown()
                saveSettings(inputName, selectedMacro)
            end
        else
            AddLog("[Macro] Enter a name first")
        end
    end
})

MacroTab:Button({
    Title = "Load",
    Callback = function()
        if selectedMacro ~= "" and loadMacro(selectedMacro) then
            updateStatus()
        end
    end
})

MacroTab:Button({
    Title = "Delete",
    Callback = function()
        if selectedMacro ~= "" and deleteMacro(selectedMacro) then
            macroList = listMacros()
            selectedMacro = macroList[1] or ""
            State.lastLoadedMacro = ""
            rebuildDropdown()
            saveSettings(inputName, selectedMacro)
            updateStatus()
        end
    end
})

MacroTab:Section({ Title = "Playback" })

MacroTab:Button({
    Title = "Play Once",
    Desc = "Проигрывает макрос только в Match",
    Callback = function()
        if not IsMatch() then
            AddLog("[Macro] Play Once доступен только в Match")
            return
        end
        task.spawn(function() play() end)
    end
})

autoPlayToggle = MacroTab:Toggle({
    Title = "Auto Play",
    Desc = "Ожидает Match, не сбрасывая переключатель",
    Value = State.autoPlay,
    Callback = function(s)
        State.autoPlay = s
        saveSettings(inputName, selectedMacro)
        if s then startLoop() else stopLoop() end
        updateStatus()
    end
})

MacroTab:Input({
    Title = "Loop Count",
    Value = tostring(State.loopCount),
    Callback = function(v)
        State.loopCount = tonumber(v) or -1
        saveSettings(inputName, selectedMacro)
    end
})

-- ============================================================
-- OTHER TAB
-- ============================================================

local OtherTab = Window:Tab({ Title = "Other" })

OtherTab:Section({ Title = "Developer Tools" })

OtherTab:Toggle({
    Title = "Enable Logs",
    Desc = "Shows system messages in UI",
    Value = State.logEnabled,
    Callback = function(s)
        State.logEnabled = s
        saveSettings(inputName, selectedMacro)
        AddLog("[System] Logs enabled: " .. tostring(s))
    end
})

UI_LogParagraph = OtherTab:Paragraph({
    Title = "Logs",
    Desc = "Waiting for events..."
})

OtherTab:Button({
    Title = "Clear Logs",
    Callback = function()
        if UI_LogParagraph then
            UI_LogParagraph:SetDesc("Cleared.")
        end
    end
})

OtherTab:Section({ Title = "Danger Zone" })

OtherTab:Button({
    Title = "Unload Script",
    Desc = "Disables all functions (hook remains)",
    Callback = function()
        unloadAll()
        if autoPlayToggle then pcall(function() autoPlayToggle:Set(false) end) end
        if speedToggle then pcall(function() speedToggle:Set(false) end) end
        if skipToggle then pcall(function() skipToggle:Set(false) end) end
        if replayToggle then pcall(function() replayToggle:Set(false) end) end
        if autoStartToggle then pcall(function() autoStartToggle:Set(false) end) end
        _G.SkibidiDefenseLoaded = nil
    end
})

-- ============================================================
-- F2 MINIMIZE
-- ============================================================

local gui = _safe(function()
    return CoreGui:FindFirstChild("WindUI") or CoreGui:FindFirstChild("SkibidiDefense")
end)

local guiVisible = true

local function toggleGui(value)
    guiVisible = value
    if gui then
        _safe(function() gui.Enabled = value end)
    else
        pcall(function()
            if value then Window:Open() else Window:Close() end
        end)
    end
end

OtherTab:Button({
    Title = "Minimize",
    Desc = "Press F2 to restore",
    Callback = function() toggleGui(false) end
})

_safe(function()
    UIS.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.F2 then
            toggleGui(not guiVisible)
        end
    end)
end)

-- ============================================================
-- MODE STATUS
-- ============================================================

local lastMode = GetMode()

task.spawn(function()
    while task.wait(1) do
        _safe(function()
            local newMode = GetMode()
            if newMode ~= lastMode then
                lastMode = newMode
                AddLog("[Mode] Changed to " .. newMode)

                if newMode == "MATCH" then
                    AddLog("[Mode] Match functions are now available")
                    if State.autoStart then
                        autoStartSent = false
                        startAutoStart()
                    end
                    if State.autoPlay and not State.loop then
                        startLoop()
                    end
                else
                    AddLog("[Mode] Match functions paused")
                    if IsLobby() then
                        _useDirectRemotes = true
                        State.useDirectRemotes = true
                        saveSettings(inputName, selectedMacro)
                    end
                end
                updateStatus()
            end
        end)
    end
end)

-- ============================================================
-- INITIALIZATION
-- ============================================================

local initDone = false

_safe(function()
    RunService.Heartbeat:Connect(function()
        if initDone then return end
        initDone = true

        task.wait(0.5)
        refreshRemotes()

        if State.autoSpeed then
            startSpeedSpam()
            AddLog("[Init] Auto Speed restored")
        end
        if State.autoSkip then
            startSkipSpam()
            AddLog("[Init] Auto Skip restored")
        end
        if State.autoReplay then
            startReplaySpam()
            AddLog("[Init] Auto Replay restored")
        end
        if State.autoStart then
            startAutoStart()
            AddLog("[Init] Auto Start restored")
        end
        if State.autoPlay and selectedMacro ~= "" then
            startLoop()
            AddLog("[Init] Auto Play restored")
        end

        if IsLobby() then
            _useDirectRemotes = true
            State.useDirectRemotes = true
            if State.autoCreateParty then
                directCreateParty()
                State.autoCreateParty = false
                saveSettings(inputName, selectedMacro)
            end
            if State.autoStartLobby then
                task.spawn(function()
                    task.wait(5)
                    directStart()
                    State.autoStartLobby = false
                    saveSettings(inputName, selectedMacro)
                end)
            end
        end

        updateStatus()
        AddLog("[Init] All functions initialized")
    end)
end)

-- Refresh remotes periodically
task.spawn(function()
    while task.wait(2) do
        _safe(refreshRemotes)
    end
end)

-- Save settings periodically
task.spawn(function()
    while task.wait(10) do
        _safe(function() saveSettings(inputName, selectedMacro) end)
    end
end)

-- Update status periodically
task.spawn(function()
    while task.wait(0.5) do
        if updateStatus then _safe(updateStatus) end
    end
end)

-- Force useDirectRemotes = true в Lobby (watchdog)
task.spawn(function()
    while task.wait(1) do
        if IsLobby() and not _useDirectRemotes then
            _useDirectRemotes = true
            State.useDirectRemotes = true
            saveSettings(inputName, selectedMacro)
            AddLog("[Lobby] useDirectRemotes force-reset to true")
        end
    end
end)

AddLog("[Config] " .. CONFIG.NAME .. " | " .. CONFIG.VERSION .. " loaded.")
AddLog("[Place] PlaceId: " .. tostring(_pid()))
AddLog("[Mode] Current mode: " .. GetMode())
AddLog("[Mode] Lobby PlaceId: " .. tostring(_K1))
