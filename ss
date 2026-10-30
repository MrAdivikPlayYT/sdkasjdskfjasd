-- Безопасная загрузка WindUI
local success, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if not success or not WindUI then
    warn("[Error] WindUI не загрузился. Включи 'HTTP Requests' в настройках Cobalt.")
    return
end

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer or Players:GetPlayers()[1]

local CONFIG = { NAME = "Skibidi Defense", VERSION = "Dev 6.7.1-fix" }

local Events = RS:WaitForChild("Event")
local speedRemote = RS:WaitForChild("Game"):WaitForChild("Speed"):WaitForChild("Change")
local skipRemote = Events:WaitForChild("waveSkip")
local replayRemote = Events:WaitForChild("ReplayCore")
local abilityRemote = RS:WaitForChild("TowerScript"):WaitForChild("spawnTowerAbility")
local startRemote = RS:WaitForChild("Events"):WaitForChild("start")

local RemoteMap = {
    [Events:WaitForChild("placeTower")] = "placeTower",
    [Events:WaitForChild("UpgradeTower")] = "upgradeTower",
    [Events:WaitForChild("RemoveTower")] = "removeTower",
    [speedRemote] = "speedChange",
    [skipRemote] = "waveSkip",
    [abilityRemote] = "ability"
}

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
    gameEndedCount = 0
}

-- ============================================================
-- LOG SYSTEM
-- ============================================================
local UI_LogParagraph

local function AddLog(text)
    print(text)
    if State.logEnabled and UI_LogParagraph then
        pcall(function()
            local currentDesc = UI_LogParagraph.Desc
            local newDesc = text .. "\n" .. (currentDesc or "")
            local lines = {}
            for line in newDesc:gmatch("[^\r\n]+") do
                table.insert(lines, line)
            end
            if #lines > 15 then table.remove(lines) end
            UI_LogParagraph:SetDesc(table.concat(lines, "\n"))
        end)
    end
end

local function getMoney()
    local ls = LocalPlayer and LocalPlayer:FindFirstChild("leaderstats")
    return ls and ls:FindFirstChild("Money") and ls.Money.Value or 0
end

local function getTowerCount()
    local n = 0
    for _, e in ipairs(State.events) do
        if e.name == "placeTower" then n = n + 1 end
    end
    return n
end

-- HOOK
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if State.rec and (method == "FireServer" or method == "InvokeServer") and RemoteMap[self] then
        local args = {...}
        
        if RemoteMap[self] == "waveSkip" and State.autoSkip then
            return oldNamecall(self, ...)
        end
        
        local argsString = ""
        for i, v in ipairs(args) do
            if i > 1 then argsString = argsString .. ", " end
            argsString = argsString .. tostring(v)
        end
        
        if RemoteMap[self] == "speedChange" then 
            State.currentSpeed = args[1] 
        end
        
        table.insert(State.events, { name = RemoteMap[self], method = method, args = args, time = os.clock() - State.startTime })
        AddLog(("[Macro] %s #%d | Args: (%s) | %.2fs"):format(RemoteMap[self], #State.events, argsString, os.clock() - State.startTime))
    end
    return oldNamecall(self, ...)
end)
setreadonly(mt, true)

-- ============================================================
-- FOLDERS & CONFIG
-- ============================================================
local ROOT_FOLDER = "SkibidiDefenseMacroScript"
local MACROS_FOLDER = ROOT_FOLDER .. "/Macros"
local SETTINGS_FILE = ROOT_FOLDER .. "/config.json"

local function ensureFolders()
    if isfolder then
        if not isfolder(ROOT_FOLDER) then makefolder(ROOT_FOLDER) end
        if not isfolder(MACROS_FOLDER) then makefolder(MACROS_FOLDER) end
    end
end

local function saveSettings(extraName, extraSelected)
    ensureFolders()
    local data = {
        name = extraName or "",
        selected = extraSelected or "",
        autoSpeed = State.autoSpeed,
        selectedSpeed = State.selectedSpeed,
        speedDelay = State.speedDelay,
        autoSkip = State.autoSkip,
        autoReplay = State.autoReplay,
        autoStart = State.autoStart,
        autoLoad = State.autoLoad,
        autoReturn = State.autoReturn,
        returnRounds = State.returnRounds,
        loopCount = State.loopCount,
        currentRound = State.currentRound,
        gameEndedCount = State.gameEndedCount
    }
    pcall(function() writefile(SETTINGS_FILE, HttpService:JSONEncode(data)) end)
end

local function loadSettings()
    ensureFolders()
    if isfile(SETTINGS_FILE) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SETTINGS_FILE)) end)
        if ok and data then
            State.autoSpeed = data.autoSpeed or false
            State.selectedSpeed = data.selectedSpeed or 1
            State.speedDelay = data.speedDelay or 1
            State.autoSkip = data.autoSkip or false
            State.autoReplay = data.autoReplay or false
            State.autoStart = data.autoStart or false
            State.autoLoad = data.autoLoad ~= false
            State.autoReturn = data.autoReturn or false
            State.returnRounds = data.returnRounds or 2
            State.loopCount = data.loopCount or -1
            State.currentRound = data.currentRound or 1
            State.gameEndedCount = data.gameEndedCount or 0
            return data.name or "", data.selected or ""
        end
    end
    return "", ""
end

local savedName, savedSelected = loadSettings()
local inputName = savedName 

local function serializeArg(v)
    if typeof(v) == "CFrame" then 
        local p = v.Position 
        return { __type = "CFrame", pos = {p.X, p.Y, p.Z} }
    elseif typeof(v) == "Vector3" then 
        return { __type = "Vector3", vec = {v.X, v.Y, v.Z} } 
    end
    return v
end

local function deserializeArg(v)
    if type(v) == "table" and v.__type == "CFrame" then 
        return CFrame.new(v.pos[1], v.pos[2], v.pos[3])
    elseif type(v) == "table" and v.__type == "Vector3" then 
        return Vector3.new(v.vec[1], v.vec[2], v.vec[3]) 
    end
    return v
end

local function saveMacro(name)
    ensureFolders()
    local data = { events = {} }
    for _, e in ipairs(State.events) do
        local args = {}
        for i, v in ipairs(e.args) do args[i] = serializeArg(v) end
        table.insert(data.events, { name = e.name, method = e.method, args = args, time = e.time })
    end
    writefile(MACROS_FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    AddLog("[Macro] Saved: " .. name)
end

local function loadMacro(name)
    local path = MACROS_FOLDER .. "/" .. name .. ".json"
    if not isfile(path) then 
        AddLog("[Macro] File not found: " .. name)
        return false 
    end
    local data = HttpService:JSONDecode(readfile(path))
    State.events = {}
    for _, e in ipairs(data.events or {}) do
        local args = {}
        for i, v in ipairs(e.args) do args[i] = deserializeArg(v) end
        table.insert(State.events, { name = e.name, method = e.method or "FireServer", args = args, time = e.time })
    end
    State.lastLoadedMacro = name
    AddLog("[Macro] Loaded: " .. name)
    return true
end

local function deleteMacro(name)
    local path = MACROS_FOLDER .. "/" .. name .. ".json"
    if isfile(path) then
        delfile(path)
        AddLog("[Macro] Deleted: " .. name)
        return true
    end
    return false
end

local function listMacros()
    ensureFolders()
    local names = {}
    for _, p in ipairs(listfiles(MACROS_FOLDER)) do
        local n = p:match("([^/\\]+)%.json$")
        if n then table.insert(names, n) end
    end
    table.sort(names)
    return names
end

-- AUTO SPAM FUNCTIONS
local function startSpeedSpam()
    if State.spamSpeed then return end
    State.spamSpeed = true
    task.spawn(function()
        while State.spamSpeed do
            pcall(function() speedRemote:FireServer(State.selectedSpeed) end)
            task.wait(State.speedDelay)
        end
    end)
end
local function stopSpeedSpam() State.spamSpeed = false end

local function startSkipSpam()
    if State.spamSkip then return end
    State.spamSkip = true
    task.spawn(function()
        while State.spamSkip do
            pcall(function() skipRemote:FireServer(true) end)
            task.wait(0.1)
        end
    end)
end
local function stopSkipSpam() State.spamSkip = false end

local function startReplaySpam()
    if State.spamReplay then return end
    State.spamReplay = true
    task.spawn(function()
        while State.spamReplay do
            pcall(function() replayRemote:FireServer() end)
            task.wait(1)
        end
    end)
end
local function stopReplaySpam() State.spamReplay = false end

-- UNLOAD FUNCTION
local function unloadAll()
    AddLog("[Script] Unloading...")
    State.autoSpeed = false
    State.autoSkip = false
    State.autoReplay = false
    State.autoPlay = false
    State.rec = false
    State.isPlaying = false
    State.loop = false
    
    stopSpeedSpam()
    stopSkipSpam()
    stopReplaySpam()
    AddLog("[Script] Unloaded.")
end

-- ============================================================
-- ROUND TRACKING
-- ============================================================
task.spawn(function()
    while task.wait(0.5) do
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            local ge = pg:FindFirstChild("GameEnded")
            if ge then
                if ge.Enabled and not State.lastGameEndedState then
                    State.gameEndedCount = State.gameEndedCount + 1
                    AddLog("[Round] GameEnded detected. Endings: " .. State.gameEndedCount)
                    
                    if State.autoReturn and State.gameEndedCount >= State.returnRounds then
                        AddLog("[Round] Limit reached. Returning to lobby...")
                        State.gameEndedCount = 0
                        saveSettings(inputName, savedSelected)
                        task.spawn(function()
                            task.wait(1)
                            if pg then
                                local ge2 = pg:FindFirstChild("GameEnded")
                                if ge2 and ge2:FindFirstChild("Frame") then
                                    local btn = ge2.Frame:FindFirstChild("back TextButton") or ge2.Frame:FindFirstChild("back") or ge2.Frame:FindFirstChild("Back")
                                    if btn and btn.Visible then
                                        AddLog("[Lobby] Clicking Back")
                                        pcall(function()
                                            local conns = getconnections(btn.MouseButton1Click)
                                            if conns and #conns > 0 then
                                                for _, c in ipairs(conns) do c:Fire() end
                                            else
                                                btn:Activate()
                                            end
                                        end)
                                    end
                                end
                            end
                        end)
                    else
                        State.currentRound = State.gameEndedCount
                        saveSettings(inputName, savedSelected)
                    end
                end
                State.lastGameEndedState = ge.Enabled
            end
        end
    end
end)

-- ============================================================
-- PLAYBACK & AUTO START
-- ============================================================
local selectedMacro = savedSelected
local macroList = listMacros()
if not table.find(macroList, selectedMacro) then selectedMacro = macroList[1] or "" end

local function play()
    if State.autoLoad and selectedMacro ~= "" and State.lastLoadedMacro ~= selectedMacro then
        loadMacro(selectedMacro)
    end

    if #State.events == 0 then return end

    State.isPlaying = true
    State.totalEvents = #State.events
    State.currentEventIndex = 0

    local startT = os.clock()
    for i, e in ipairs(State.events) do
        local waitT = e.time - (os.clock() - startT)
        if waitT > 0 then task.wait(waitT) end
        
        State.currentEventIndex = i
        
        local remote = nil
        for rem, name in pairs(RemoteMap) do
            if name == e.name then remote = rem break end
        end
        
        if remote then
            if e.name == "speedChange" and State.autoSpeed then
            elseif e.name == "waveSkip" and State.autoSkip then
            else
                if e.method == "InvokeServer" then 
                    remote:InvokeServer(table.unpack(e.args))
                else 
                    remote:FireServer(table.unpack(e.args)) 
                end
            end
        end
    end
    
    State.isPlaying = false
    State.currentEventIndex = 0
    -- Убираем вызов updateStatus() отсюда, так как она глобальная
end

local function startAutoStart()
    task.spawn(function()
        while State.autoStart do
            AddLog("[AutoStart] Trying to start via remote...")
            local success = pcall(function()
                startRemote:FireServer(true)
            end)
            
            if success then
                AddLog("[AutoStart] Remote fired. Waiting 3 sec...")
                task.wait(3)
                AddLog("[AutoStart] Running macro...")
                play()
                
                State.autoStart = false
                if UI_AutoStartToggle then pcall(function() UI_AutoStartToggle:Set(false) end) end
                break
            else
                AddLog("[AutoStart] Remote failed. Retrying...")
                task.wait(1)
            end
        end
    end)
end

local function startLoop()
    if State.loop then return end
    
    if selectedMacro ~= "" then
        loadMacro(selectedMacro)
    end
    
    State.loop = true
    task.spawn(function()
        local count = 0
        while State.loop do
            if selectedMacro ~= "" then
                play()
                count = count + 1
                if State.loopCount ~= -1 and count >= State.loopCount then
                    State.loop = false
                    if UI_AutoPlayToggle then pcall(function() UI_AutoPlayToggle:Set(false) end) end
                    break
                end
            end
            if State.loop then task.wait(0.5) end
        end
    end)
end

local function stopLoop()
    State.loop = false
end

-- UI
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
    Window:Tag({ Title = CONFIG.VERSION, Color = Color3.fromRGB(80, 180, 120), Radius = 8 })
end)

-- MATCH TAB
local MatchTab = Window:Tab({ Title = "Match" })
MatchTab:Section({ Title = "Auto Speed" })

local UI_SpeedToggle = MatchTab:Toggle({
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
    Value = { Min = 0.1, Max = 10, Default = State.speedDelay },
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

UI_AutoStartToggle = MatchTab:Toggle({
    Title = "Auto Start Match", 
    Desc = "Использует Events.start:FireServer(true)",
    Value = State.autoStart,
    Callback = function(s) 
        State.autoStart = s
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
        State.returnRounds = tonumber(v) or 2
        saveSettings(inputName, selectedMacro)
    end
})

MatchTab:Button({
    Title = "Reset Rounds",
    Desc = "Resets round counter to 0",
    Callback = function()
        State.gameEndedCount = 0
        State.currentRound = 1
        State.lastGameEndedState = false
        saveSettings(inputName, selectedMacro)
        AddLog("[Round] Counter reset to 0")
    end
})

local UI_SkipToggle = MatchTab:Toggle({
    Title = "Enable Auto Skip", 
    Value = State.autoSkip,
    Callback = function(s) 
        State.autoSkip = s
        saveSettings(inputName, selectedMacro)
        if s then startSkipSpam() else stopSkipSpam() end
    end
})

local UI_ReplayToggle = MatchTab:Toggle({
    Title = "Enable Auto Replay", 
    Value = State.autoReplay,
    Callback = function(s) 
        State.autoReplay = s
        saveSettings(inputName, selectedMacro)
        if s then startReplaySpam() else stopReplaySpam() end
    end
})

-- MACRO TAB
local MacroTab = Window:Tab({ Title = "Macro" })
MacroTab:Section({ Title = "Status" })

local UI_StatusParagraph = MacroTab:Paragraph({ 
    Title = "● STOP", 
    Desc = "Events: 0 • Towers: 0\nMoney: 0 • Speed: 1x\nRound: 1 / 2" 
})

local function updateStatus()
    pcall(function()
        local status = ""
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

        local spdText = State.autoSpeed and (tostring(State.selectedSpeed) .. "x [AUTO]") or (tostring(State.currentSpeed) .. "x")
        
        if UI_StatusParagraph then
            UI_StatusParagraph:SetTitle(status)
            UI_StatusParagraph:SetDesc(string.format(
                "Events: %d • Towers: %d\nMoney: %s • Speed: %s\nRound: %d / %d", 
                #State.events, getTowerCount(), tostring(getMoney()), spdText, State.gameEndedCount, State.returnRounds
            ))
        end
    end)
end
updateStatus()

MacroTab:Section({ Title = "Recording" })
MacroTab:Toggle({ 
    Title = "Record", 
    Value = false, 
    Callback = function(s)
        State.rec = s
        if s then 
            State.events = {}
            State.startTime = os.clock()
            State.currentSpeed = 1
            AddLog("[Macro] Recording started.")
        end
    end 
})

MacroTab:Button({ 
    Title = "Clear", 
    Callback = function() 
        State.events = {}
        State.startTime = os.clock()
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

local UI_MacroDropdown
local function rebuildDropdown()
    if UI_MacroDropdown then pcall(function() UI_MacroDropdown:Destroy() end) end
    UI_MacroDropdown = MacroTab:Dropdown({ 
        Title = "Saved", 
        Values = macroList, 
        Value = selectedMacro, 
        Callback = function(v) 
            selectedMacro = v 
            saveSettings(inputName, selectedMacro)
        end 
    })
end
rebuildDropdown()

MacroTab:Button({ 
    Title = "Save Manually", 
    Callback = function()
        if inputName ~= "" then 
            saveMacro(inputName)
            selectedMacro = inputName
            State.lastLoadedMacro = inputName
            macroList = listMacros()
            if not table.find(macroList, selectedMacro) then selectedMacro = macroList[1] or "" end
            rebuildDropdown()
            saveSettings(inputName, selectedMacro)
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
        if selectedMacro ~= "" then 
            if deleteMacro(selectedMacro) then
                macroList = listMacros()
                selectedMacro = macroList[1] or ""
                State.lastLoadedMacro = ""
                rebuildDropdown()
                saveSettings(inputName, selectedMacro)
            end
        end 
    end 
})

MacroTab:Section({ Title = "Playback" })

MacroTab:Button({ 
    Title = "Play Once", 
    Desc = "Проигрывает макрос 1 раз",
    Callback = function() 
        task.spawn(play) 
    end 
})

UI_AutoPlayToggle = MacroTab:Toggle({ 
    Title = "Auto Play", 
    Desc = "Автоматически загружает и запускает макрос",
    Value = State.autoPlay, 
    Callback = function(s) 
        State.autoPlay = s
        if s then startLoop() else stopLoop() end
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

-- OTHER TAB
local OtherTab = Window:Tab({ Title = "Other" })
OtherTab:Section({ Title = "Developer Tools" })

OtherTab:Toggle({
    Title = "Enable Logs",
    Desc = "Shows system messages in UI",
    Value = State.logEnabled,
    Callback = function(s)
        State.logEnabled = s
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
        if UI_LogParagraph then UI_LogParagraph:SetDesc("Cleared.") end
    end
})

OtherTab:Section({ Title = "Danger Zone" })
OtherTab:Button({
    Title = "Unload Script",
    Desc = "Disables all functions (hook remains)",
    Callback = function()
        unloadAll()
        if UI_AutoPlayToggle then pcall(function() UI_AutoPlayToggle:Set(false) end) end
        if UI_SpeedToggle then pcall(function() UI_SpeedToggle:Set(false) end) end
        if UI_SkipToggle then pcall(function() UI_SkipToggle:Set(false) end) end
        if UI_ReplayToggle then pcall(function() UI_ReplayToggle:Set(false) end) end
        if UI_AutoStartToggle then pcall(function() UI_AutoStartToggle:Set(false) end) end
    end
})

-- F2
local CoreGui = game:GetService("CoreGui")
local gui = CoreGui:FindFirstChild("WindUI") or CoreGui:FindFirstChild("SkibidiDefense")
local guiVisible = true
local function toggleGui(v)
    guiVisible = v
    if gui then 
        gui.Enabled = v 
    else 
        pcall(function() 
            if v then Window:Open() else Window:Close() end 
        end) 
    end
end

OtherTab:Button({ Title = "Minimize", Desc = "Press F2 to restore", Callback = function() toggleGui(false) end })
UIS.InputBegan:Connect(function(input, processed) 
    if not processed and input.KeyCode == Enum.KeyCode.F2 then toggleGui(not guiVisible) end 
end)

-- ============================================================
-- ИНИЦИАЛИЗАЦИЯ ФУНКЦИЙ ПРИ ЗАГРУЗКЕ
-- ============================================================
if State.autoSpeed then startSpeedSpam() end
if State.autoSkip then startSkipSpam() end
if State.autoReplay then startReplaySpam() end

task.spawn(function() 
    while task.wait(0.5) do updateStatus() end 
end)

AddLog("[Config] " .. CONFIG.NAME .. " | " .. CONFIG.VERSION .. " loaded.")
