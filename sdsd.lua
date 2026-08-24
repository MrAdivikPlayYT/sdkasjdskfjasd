repeat task.wait() until game:IsLoaded()
print("[Loader] Game loaded, starting script...")

-- Защита от повторного запуска
if _G.SkibidiDefenseLoaded then
    print("[Loader] Script already loaded, skipping...")
    return
end
_G.SkibidiDefenseLoaded = true

local function decrypt(s)
    local r=""
    for i=1,#s do
        r=r..string.char(string.byte(s,i)-3)
    end
    return r
end

local allowed=false
for _,v in ipairs({"6:8884<59<", "636;6635:", "5363<54474", "67::79;3;4", "443676<;39", "43;39638:53", "43;564599::", "4434494<498", "69;:9::356"}) do
    local decrypted = decrypt(v)
    local num = tonumber(decrypted)
    if num and num == game.Players.LocalPlayer.UserId then
        allowed=true
        break
    end
end

if not allowed then
    game.Players.LocalPlayer:Kick("No access")
    return
end
print("[Loader] Access check passed")

if _G.SkibidiGUI then pcall(function() _G.SkibidiGUI:Destroy() end) end
if type(getgenv) == "function" then
    local env = getgenv()
    if env and env.SkibidiGUI then pcall(function() env.SkibidiGUI:Destroy() end) end
end
pcall(function()
    local oldBlur = game:GetService("Lighting"):FindFirstChild("MenuBlur")
    if oldBlur then oldBlur:Destroy() end
end)

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer

local Fluent = nil
local loadSuccess, loadErr = pcall(function()
    Fluent = loadstring(game:HttpGet("https://github.com/1dontgiveaf/Fluent/releases/latest/download/main.lua"))()
end)
if not loadSuccess or not Fluent then
    print("[Loader] Fluent UI failed, retrying...")
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Skibidi Defense",
            Text = "Failed to load UI module. Retrying...",
            Duration = 5
        })
    end)
    task.wait(2)
    local retrySuccess, retryResult = pcall(function()
        Fluent = loadstring(game:HttpGet("https://github.com/1dontgiveaf/Fluent/releases/latest/download/main.lua"))()
    end)
    if retrySuccess then Fluent = retryResult end
end
if not Fluent then
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Skibidi Defense",
            Text = "Critical: UI module failed to load!",
            Duration = 10
        })
    end)
    return
end
print("[Loader] Fluent UI loaded successfully")

local Settings = {
    ShowAllTowers = false,
    BlackMarket = false,
    AntiMacro = false,
    AntiAFK = false,
    NotificationsEnabled = true,
    InstantProxMount = false,
    PotatoGraphics = false,
    GameSpeed = 1,
    SelectedBoostType = "DMG",
    WebhookEnabled = false,
    WebhookURL = "",
    WebhookMatchTracking = false,
    ShowLogInWebhook = true,
    WebhookMatchFields = {"Result", "Streak", "Kills", "Survived", "Time", "Items", "Credits", "Crystals", "Spent", "Player", "TotalCredits"},
    WalkChance = 40,
    JumpChance = 15,
    MoveDurationMin = 0.8,
    MoveDurationMax = 2.5,
    PauseMin = 0.05,
    PauseMax = 0.3,
    MacroModes = {},
    AutoRestoreCam = true,
    MacroLoop = false,
    MacroCompensateInset = false,
    MacroDebugClicks = true,
    MacroAutoLoadOnStart = true,
    MacroAutoLoadDelay = 2,
    MacroAutoStartPlayback = false,
    MacroAutoStartDelay = 2,
    AutoSaveEnabled = false,
    AutoLoadEnabled = true,
}

local winStreak = 0
local totalCredits = 0
local matchTrackingActive = false
local endedConnection = nil
local endedBoolValue = nil
local currentConfig = "default"

local function notifyUser(title, content, duration)
    pcall(function()
        if Settings.NotificationsEnabled then
            Fluent:Notify({
                Title = title,
                Content = content,
                Duration = duration or 3
            })
        end
    end)
end

local function setButtonText(btn, text)
    notifyUser("Info", text, 2)
end

local showAllTowersConnection = nil
local originalVisibility = {}
local isUpdating = false

local originalBoosts = {}
local createdSpecial = {}
local createdBoostsList = {}

local function getValueAfterColon(text)
    if not text or text == "" then return "N/A" end
    local colonPos = text:find(":")
    if colonPos then
        local value = text:sub(colonPos + 1)
        value = value:gsub("^%s*(.-)%s*$", "%1")
        return value
    end
    return text
end

local function toNumber(value)
    if not value or value == "N/A" then return 0 end
    local num = tonumber(value:gsub("[^%d]", ""))
    return num or 0
end

local function formatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    end
    return tostring(num)
end

local function getGameResult()
    local player = Players.LocalPlayer
    if not player then return "Unknown" end
    
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return "Unknown" end
    
    local gameEnded = playerGui:FindFirstChild("GameEnded")
    if not gameEnded then return "Unknown" end
    
    local frame = gameEnded:FindFirstChild("Frame")
    if not frame then return "Unknown" end
    
    local tping = frame:FindFirstChild("tping")
    if not tping then return "Unknown" end
    
    local resultText = tping.Text
    local lowerText = resultText:lower()
    
    if lowerText:find("win") or lowerText:find("victory") or lowerText:find("побед") or
       lowerText:find("defeated") then
        return "WIN"
    end
    
    if lowerText:find("lose") or lowerText:find("defeat") or lowerText:find("destroyed") or
       lowerText:find("пораж") or lowerText:find("уничтож") then
        return "LOSE"
    end
    
    return "Unknown"
end

local function collectMatchStats()
    local stats = {
        kills = "N/A",
        survived = "N/A",
        timeelapsed = "N/A",
        items = "N/A",
        clock = "N/A",
        credits = "N/A",
        crystals = "N/A",
        spent = "N/A"
    }
    
    local player = Players.LocalPlayer
    if not player then return stats end
    
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return stats end
    
    local gameEnded = playerGui:FindFirstChild("GameEnded")
    if not gameEnded then return stats end
    
    local frame = gameEnded:FindFirstChild("Frame")
    if not frame then return stats end
    
    local main = frame:FindFirstChild("main")
    if not main then return stats end
    
    local killsLabel = main:FindFirstChild("kills")
    if killsLabel then
        stats.kills = getValueAfterColon(killsLabel.Text)
    end
    
    local survivedLabel = main:FindFirstChild("survived")
    if survivedLabel then
        stats.survived = getValueAfterColon(survivedLabel.Text)
    end
    
    local timeLabel = main:FindFirstChild("timeelapsed")
    if timeLabel then
        stats.timeelapsed = getValueAfterColon(timeLabel.Text)
    end
    
    local itemsLabel = main:FindFirstChild("itemsearned")
    if itemsLabel then
        stats.items = getValueAfterColon(itemsLabel.Text)
    end
    
    local clockLabel = main:FindFirstChild("clockearned")
    if clockLabel then
        stats.clock = getValueAfterColon(clockLabel.Text)
    end
    
    local creditsLabel = main:FindFirstChild("creditsearned")
    if creditsLabel then
        stats.credits = getValueAfterColon(creditsLabel.Text)
    end
    
    local crystalsLabel = main:FindFirstChild("crystalsearned")
    if crystalsLabel then
        stats.crystals = getValueAfterColon(crystalsLabel.Text)
    end
    
    local spentLabel = main:FindFirstChild("spent")
    if spentLabel then
        stats.spent = getValueAfterColon(spentLabel.Text)
    end
    
    return stats
end

local function sendMatchWebhook(fieldsData)
    if not Settings.WebhookEnabled or Settings.WebhookURL == "" then return end
    if not Settings.WebhookMatchTracking then return end
    
    local timeNow = os.date("%H:%M:%S")
    
    local function darkCode(v) return "```fix\n"..tostring(v).."\n```" end
    
    local fields = {}
    for _, field in ipairs(fieldsData) do
        table.insert(fields, {
            name = field.name,
            value = darkCode(field.value),
            inline = field.inline or false
        })
    end
    
    if Settings.ShowLogInWebhook then
        table.insert(fields, {
            name = "Log",
            value = darkCode(timeNow),
            inline = false
        })
    end
    
    local data = {
        username = "Skibidi Defense Match Tracker",
        avatar_url = "https://cdn.discordapp.com/embed/avatars/0.png",
        embeds = {{
            author = { name = "Skibidi Defense Script", icon_url = "https://cdn.discordapp.com/embed/avatars/0.png" },
            title = "Skibidi Defense (Private)",
            color = 65280,
            fields = fields,
            footer = { text = "Нажмите на значение чтобы скопировать" }
        }}
    }
    
    local json = HttpService:JSONEncode(data)
    local request = http_request or request or (syn and syn.request) or (fluxus and fluxus.request)
    if request then
        pcall(function()
            request({ Url = Settings.WebhookURL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = json })
        end)
    end
end

local function onGameEnded()
    task.wait(1.5)
    
    local result = getGameResult()
    local stats = collectMatchStats()
    local currentCredits = toNumber(stats.credits)
    
    if result == "WIN" then
        winStreak = winStreak + 1
        totalCredits = totalCredits + currentCredits
    elseif result == "LOSE" then
        winStreak = 0
        totalCredits = 0
    end
    
    local fields = {}
    for _, field in ipairs(Settings.WebhookMatchFields) do
        if field == "Result" then
            fields[#fields+1] = { name = "Результат", value = result, inline = false }
        elseif field == "Streak" then
            fields[#fields+1] = { name = "Win Streak", value = tostring(winStreak), inline = true }
        elseif field == "Kills" then
            fields[#fields+1] = { name = "Убийств", value = stats.kills, inline = true }
        elseif field == "Survived" then
            fields[#fields+1] = { name = "Выжил", value = stats.survived, inline = true }
        elseif field == "Time" then
            fields[#fields+1] = { name = "Время", value = stats.timeelapsed, inline = true }
        elseif field == "Items" then
            fields[#fields+1] = { name = "Предметов", value = stats.items, inline = true }
        elseif field == "Credits" then
            fields[#fields+1] = { name = "Кредитов", value = stats.credits, inline = true }
        elseif field == "Crystals" then
            fields[#fields+1] = { name = "Кристаллов", value = stats.crystals, inline = true }
        elseif field == "Spent" then
            fields[#fields+1] = { name = "Потрачено", value = stats.spent, inline = false }
        elseif field == "Player" then
            fields[#fields+1] = { name = "Игрок", value = Players.LocalPlayer.Name, inline = true }
        elseif field == "TotalCredits" then
            fields[#fields+1] = { name = "Total Credits", value = formatNumber(totalCredits), inline = false }
        end
    end
    
    sendMatchWebhook(fields)
end

local function setupTracking()
    if endedConnection then
        endedConnection:Disconnect()
        endedConnection = nil
    end
    
    if not endedBoolValue then return end
    
    endedConnection = endedBoolValue:GetPropertyChangedSignal("Value"):Connect(function()
        if not Settings.WebhookMatchTracking then return end
        if endedBoolValue.Value == true then
            onGameEnded()
        end
    end)
    
    if endedBoolValue.Value == true and Settings.WebhookMatchTracking then
        onGameEnded()
    end
end

local function findAndTrackEndedBool()
    local replicatedStorage = game:GetService("ReplicatedStorage")
    
    for _, child in ipairs(replicatedStorage:GetChildren()) do
        if child:IsA("BoolValue") and string.lower(child.Name) == "ended" then
            endedBoolValue = child
            break
        end
    end
    
    if endedBoolValue then
        setupTracking()
    else
        local connection
        connection = game.DescendantAdded:Connect(function(desc)
            if desc:IsA("BoolValue") and string.lower(desc.Name) == "ended" then
                endedBoolValue = desc
                setupTracking()
                connection:Disconnect()
            end
        end)
    end
end

local function startMatchTracking()
    if matchTrackingActive then return end
    matchTrackingActive = true
    winStreak = 0
    totalCredits = 0
    task.spawn(findAndTrackEndedBool)
end

local function stopMatchTracking()
    matchTrackingActive = false
    if endedConnection then
        endedConnection:Disconnect()
        endedConnection = nil
    end
end

local function getTowerData()
    local scripted = workspace:FindFirstChild("Scripted")
    if not scripted then return nil end
    return scripted:FindFirstChild("TowerData")
end

local boostTypes = {"DMG", "CASH", "COST", "HD", "RNG", "SKIP", "SPA"}

local function ensureAllBoosts(tower, special)
    createdBoostsList[tower] = createdBoostsList[tower] or {}
    originalBoosts[tower] = originalBoosts[tower] or {}
    for _, boostName in ipairs(boostTypes) do
        local boost = special:FindFirstChild(boostName)
        if not boost then
            local boostType = (boostName == "DMG") and "NumberValue" or "IntValue"
            boost = Instance.new(boostType)
            boost.Name = boostName
            boost.Value = 0
            boost.Parent = special
            createdBoostsList[tower][boostName] = true
        else
            if originalBoosts[tower][boostName] == nil then
                originalBoosts[tower][boostName] = boost.Value
            end
        end
    end
end

local function saveOriginalBoosts()
    originalBoosts = {}
    createdSpecial = {}
    createdBoostsList = {}
    local towerData = getTowerData()
    if not towerData then return end
    for _, tower in ipairs(towerData:GetChildren()) do
        if tower:IsA("Folder") then
            local boosters = tower:FindFirstChild("Boosters")
            if boosters then
                local special = boosters:FindFirstChild("Special")
                if not special then
                    special = Instance.new("Folder")
                    special.Name = "Special"
                    special.Parent = boosters
                    createdSpecial[tower] = true
                end
                ensureAllBoosts(tower, special)
            end
        end
    end
end

local function applyBoost(boostType, value)
    local towerData = getTowerData()
    if not towerData then return end
    local count = 0
    for _, tower in ipairs(towerData:GetChildren()) do
        if tower:IsA("Folder") then
            local boosters = tower:FindFirstChild("Boosters")
            if boosters then
                local special = boosters:FindFirstChild("Special")
                if not special then
                    special = Instance.new("Folder")
                    special.Name = "Special"
                    special.Parent = boosters
                    createdSpecial[tower] = true
                end
                ensureAllBoosts(tower, special)
                local boost = special:FindFirstChild(boostType)
                if boost then
                    boost.Value = value
                    count = count + 1
                end
            end
        end
    end
    notifyUser("Tower Boosts", boostType .. " = " .. tostring(value) .. " (" .. count .. " towers)", 2)
end

local function applyBoostSafe(boostType, value)
    if boostType == "DMG" then applyBoost("DMG", value)
    elseif boostType == "CASH" then applyBoost("CASH", math.floor(value))
    elseif boostType == "COST" then applyBoost("COST", math.floor(value))
    elseif boostType == "HD" then applyBoost("HD", math.floor(value))
    elseif boostType == "RNG" then applyBoost("RNG", math.floor(value))
    elseif boostType == "SKIP" then applyBoost("SKIP", math.floor(value))
    elseif boostType == "SPA" then applyBoost("SPA", math.floor(value))
    end
end

local function resetBoosts()
    local towerData = getTowerData()
    if not towerData then return end
    for _, tower in ipairs(towerData:GetChildren()) do
        if tower:IsA("Folder") then
            local boosters = tower:FindFirstChild("Boosters")
            if boosters then
                local special = boosters:FindFirstChild("Special")
                if special then
                    if originalBoosts[tower] then
                        for boostName, originalValue in pairs(originalBoosts[tower]) do
                            local boost = special:FindFirstChild(boostName)
                            if boost then boost.Value = originalValue end
                        end
                    end
                    if createdBoostsList[tower] then
                        for boostName, _ in pairs(createdBoostsList[tower]) do
                            local boost = special:FindFirstChild(boostName)
                            if boost then boost:Destroy() end
                        end
                    end
                    if createdSpecial[tower] then special:Destroy() end
                end
            end
        end
    end
    originalBoosts = {}
    createdSpecial = {}
    createdBoostsList = {}
    notifyUser("Tower Boosts", "All boosts reset to original values", 2)
end

task.spawn(function()
    task.wait(2)
    saveOriginalBoosts()
end)

local function setGameSpeed(speed)
    pcall(function()
        local replicatedStorage = game:GetService("ReplicatedStorage")
        local gameFolder = replicatedStorage:FindFirstChild("Game")
        if gameFolder then
            local speedValue = gameFolder:FindFirstChild("Speed")
            if speedValue and speedValue:IsA("NumberValue") then
                speedValue.Value = speed
            else
                local newSpeed = Instance.new("NumberValue")
                newSpeed.Name = "Speed"
                newSpeed.Value = speed
                newSpeed.Parent = gameFolder
            end
        else
            local newGameFolder = Instance.new("Folder")
            newGameFolder.Name = "Game"
            newGameFolder.Parent = replicatedStorage
            local newSpeed = Instance.new("NumberValue")
            newSpeed.Name = "Speed"
            newSpeed.Value = speed
            newSpeed.Parent = newGameFolder
        end
        notifyUser("Game Speed", "Set to: " .. speed .. "x", 1)
    end)
end

local potatoGraphicsActive = false
local savedSettings = {}
local savedMaterials = {}
local savedParticles = {}
local savedLights = {}
local savedEffects = {}
local savedPostEffects = {}
local descendantConnection = nil

local function saveGameSettings()
    local Lighting = game:GetService("Lighting")
    local Terrain = workspace:FindFirstChildOfClass("Terrain")
    savedSettings = {
        QualityLevel = settings().Rendering.QualityLevel,
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        Brightness = Lighting.Brightness,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
        Ambient = Lighting.Ambient,
        ExposureCompensation = Lighting.ExposureCompensation,
        ClockTime = Lighting.ClockTime,
        GeographicLatitude = Lighting.GeographicLatitude,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        ShadowSoftness = Lighting.ShadowSoftness,
        ColorShift_Top = Lighting.ColorShift_Top,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
        WaterWaveSize = Terrain and Terrain.WaterWaveSize or nil,
        WaterWaveSpeed = Terrain and Terrain.WaterWaveSpeed or nil,
        WaterReflectance = Terrain and Terrain.WaterReflectance or nil,
        WaterTransparency = Terrain and Terrain.WaterTransparency or nil
    }
    for _, v in ipairs(Lighting:GetChildren()) do
        pcall(function()
            if v:IsA("PostEffect") or v:IsA("Atmosphere") or v:IsA("BloomEffect") or 
               v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or
               v:IsA("DepthOfFieldEffect") then
                savedPostEffects[v] = v.Enabled
            end
        end)
    end
end

local function saveMaterial(obj) if not savedMaterials[obj] then savedMaterials[obj] = obj.Material end end
local function saveEffect(obj)
    if obj:IsA("ParticleEmitter") and not savedParticles[obj] then savedParticles[obj] = obj.Enabled
    elseif (obj:IsA("Trail") or obj:IsA("Beam")) and not savedEffects[obj] then savedEffects[obj] = obj.Enabled
    elseif (obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles")) and not savedEffects[obj] then savedEffects[obj] = obj.Enabled
    elseif (obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight")) and not savedLights[obj] then savedLights[obj] = obj.Enabled
    end
end

local function optimizeObject(obj)
    pcall(function()
        if obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
            saveMaterial(obj)
            obj.Material = Enum.Material.Plastic
            obj.Reflectance = 0
        elseif obj:IsA("ParticleEmitter") then
            saveEffect(obj)
            obj.Enabled = false
            obj.Rate = 0
        elseif obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            saveEffect(obj)
            obj.Enabled = false
        elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
            saveEffect(obj)
            obj.Enabled = false
        end
    end)
end

local function restoreEverything()
    pcall(function()
        for obj, material in pairs(savedMaterials) do if obj and obj.Parent then obj.Material = material end end
        for obj, enabled in pairs(savedParticles) do if obj and obj.Parent then obj.Enabled = enabled; if enabled and obj:IsA("ParticleEmitter") then obj.Rate = 10 end end end
        for obj, enabled in pairs(savedEffects) do if obj and obj.Parent then obj.Enabled = enabled end end
        for obj, enabled in pairs(savedLights) do if obj and obj.Parent then obj.Enabled = enabled end end
        savedMaterials = {}; savedParticles = {}; savedEffects = {}; savedLights = {}
    end)
end

local function restorePostEffects()
    local Lighting = game:GetService("Lighting")
    for v, enabled in pairs(savedPostEffects) do pcall(function() if v and v.Parent then v.Enabled = enabled end end) end
    savedPostEffects = {}
end

local function enablePotatoGraphics()
    if potatoGraphicsActive then return end
    potatoGraphicsActive = true
    pcall(function()
        saveGameSettings()
        local Lighting = game:GetService("Lighting")
        local Terrain = workspace:FindFirstChildOfClass("Terrain")
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 500
        Lighting.FogStart = 500
        Lighting.Brightness = 1
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        Lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
        Lighting.ExposureCompensation = 0
        for _, v in ipairs(Lighting:GetChildren()) do
            pcall(function()
                if v.Name ~= "MenuBlur" and (v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or 
                   v:IsA("ColorCorrectionEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("Atmosphere")) then
                    v.Enabled = false
                end
            end)
        end
        if Terrain then
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 1
        end
        local objects = game:GetDescendants()
        for i = 1, #objects do
            optimizeObject(objects[i])
            if i % 500 == 0 then task.wait() end
        end
        descendantConnection = game.DescendantAdded:Connect(optimizeObject)
        notifyUser("Potato Graphics", "ON - FPS Boost", 2)
    end)
end

local function disablePotatoGraphics()
    if not potatoGraphicsActive then return end
    potatoGraphicsActive = false
    pcall(function()
        if descendantConnection then descendantConnection:Disconnect(); descendantConnection = nil end
        restoreEverything()
        restorePostEffects()
        local Lighting = game:GetService("Lighting")
        local Terrain = workspace:FindFirstChildOfClass("Terrain")
        settings().Rendering.QualityLevel = savedSettings.QualityLevel or Enum.QualityLevel.Level08
        Lighting.GlobalShadows = savedSettings.GlobalShadows
        Lighting.FogEnd = savedSettings.FogEnd
        Lighting.FogStart = savedSettings.FogStart or 0
        Lighting.Brightness = savedSettings.Brightness
        Lighting.EnvironmentDiffuseScale = savedSettings.EnvironmentDiffuseScale
        Lighting.EnvironmentSpecularScale = savedSettings.EnvironmentSpecularScale
        Lighting.Ambient = savedSettings.Ambient
        Lighting.ExposureCompensation = savedSettings.ExposureCompensation
        Lighting.ClockTime = savedSettings.ClockTime
        Lighting.GeographicLatitude = savedSettings.GeographicLatitude
        Lighting.OutdoorAmbient = savedSettings.OutdoorAmbient
        Lighting.ShadowSoftness = savedSettings.ShadowSoftness
        Lighting.ColorShift_Top = savedSettings.ColorShift_Top
        Lighting.ColorShift_Bottom = savedSettings.ColorShift_Bottom
        if Terrain and savedSettings.WaterWaveSize then
            Terrain.WaterWaveSize = savedSettings.WaterWaveSize
            Terrain.WaterWaveSpeed = savedSettings.WaterWaveSpeed
            Terrain.WaterReflectance = savedSettings.WaterReflectance
            Terrain.WaterTransparency = savedSettings.WaterTransparency
        end
        notifyUser("Potato Graphics", "OFF - Effects Restored", 2)
    end)
end

local function togglePotatoGraphics(enabled)
    Settings.PotatoGraphics = enabled
    if enabled then enablePotatoGraphics() else disablePotatoGraphics() end
end

local function showAllTowers()
    if isUpdating then return end
    isUpdating = true
    pcall(function()
        local player = Players.LocalPlayer
        local playerGui = player:FindFirstChild("PlayerGui")
        if not playerGui then return end
        local main = playerGui:FindFirstChild("Main")
        if not main then return end
        for _, grid in ipairs(main:GetDescendants()) do
            if grid.Name == "Grid" then
                for _, button in ipairs(grid:GetDescendants()) do
                    if button:IsA("TextButton") or button:IsA("ImageButton") then
                        if originalVisibility[button] == nil then originalVisibility[button] = button.Visible end
                        if button.Visible ~= true then button.Visible = true end
                    end
                end
                if grid.Visible ~= true then grid.Visible = true end
            end
        end
    end)
    isUpdating = false
end

local function restoreOriginalTowers()
    for button, visible in pairs(originalVisibility) do pcall(function() if button.Visible ~= visible then button.Visible = visible end end) end
    originalVisibility = {}
end

local function startShowAllTowers()
    if showAllTowersConnection then return end
    showAllTowers()
    showAllTowersConnection = RunService.Stepped:Connect(function()
        if Settings.ShowAllTowers then showAllTowers() end
    end)
end

local function stopShowAllTowers()
    if showAllTowersConnection then showAllTowersConnection:Disconnect(); showAllTowersConnection = nil end
    restoreOriginalTowers()
end

local blackMarketConnection = nil
local function showBlackMarket()
    pcall(function()
        local player = Players.LocalPlayer
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return end
        local sg = pg:FindFirstChild("BLACKMARKET")
        if not sg then return end
        sg.Enabled = true
        local main = sg:FindFirstChild("Main")
        if main then main.Visible = true end
    end)
end

local function startBlackMarket()
    if blackMarketConnection then return end
    showBlackMarket()
    blackMarketConnection = RunService.Stepped:Connect(function()
        if Settings.BlackMarket then showBlackMarket() end
    end)
end

local function stopBlackMarket()
    if blackMarketConnection then blackMarketConnection:Disconnect(); blackMarketConnection = nil end
    pcall(function()
        local player = Players.LocalPlayer
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return end
        local sg = pg:FindFirstChild("BLACKMARKET")
        if not sg then return end
        sg.Enabled = false
        local main = sg:FindFirstChild("Main")
        if main then main.Visible = false end
    end)
end

local walkRunning = false
local walkThread = nil
local walkKeys = {}

local function releaseWalkKeys()
    for k in pairs(walkKeys) do
        pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[k], false, nil) end)
    end
    walkKeys = {}
end

local function pressWalkKey(k)
    if walkKeys[k] then return end
    walkKeys[k] = true
    pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[k], false, nil) end)
end

local function releaseWalkKey(k)
    if not walkKeys[k] then return end
    walkKeys[k] = nil
    pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[k], false, nil) end)
end

local function walkJump()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, nil)
        task.wait(0.05 + math.random() * 0.1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, nil)
    end)
end

local walkDirs = {{"W"}, {"S"}, {"A"}, {"D"}, {"W","D"}, {"W","A"}, {"S","D"}, {"S","A"}}
local function randWalkDir() return walkDirs[math.random(1, #walkDirs)] end

local function hasMacroMode(mode)
    for _, m in ipairs(Settings.MacroModes) do
        if m == mode then return true end
    end
    return false
end

local function walkLoop()
    while walkRunning do
        if not hasMacroMode("Walking") then
            task.wait(1)
            releaseWalkKeys()
            walkRunning = false
            return
        end
        local r = math.random(1, 100)
        local wc = Settings.WalkChance
        local jc = wc + Settings.JumpChance

        if r <= wc then
            local d = randWalkDir()
            for _, k in ipairs(d) do pressWalkKey(k) end
            task.wait(Settings.MoveDurationMin + math.random() * (Settings.MoveDurationMax - Settings.MoveDurationMin))
            for _, k in ipairs(d) do releaseWalkKey(k) end
        elseif r <= jc then
            local d = randWalkDir()
            for _, k in ipairs(d) do pressWalkKey(k) end
            walkJump()
            task.wait(0.3 + math.random() * 0.8)
            for _, k in ipairs(d) do releaseWalkKey(k) end        else
            task.wait(0.5 + math.random() * 1.5)
        end

        task.wait(Settings.PauseMin + math.random() * Settings.PauseMax)
        if math.random(1, 15) == 1 then releaseWalkKeys() end
    end
    releaseWalkKeys()
end

local function startWalkMacro()
    if walkRunning then return end
    walkRunning = true
    walkThread = task.spawn(walkLoop)
    notifyUser("Walking Macro", "Started (WASD + Jump)", 2)
end

local function stopWalkMacro()
    if not walkRunning then return end
    walkRunning = false
    if walkThread then task.cancel(walkThread); walkThread = nil end
    releaseWalkKeys()
    notifyUser("Walking Macro", "Stopped", 2)
end

print("[Loader] All functions ready")

-- ===========================================================
-- MACRO RECORDER MODULE (ВЗЯТО ИЗ Macro.lua)
-- ===========================================================
local Macro = {}
do
    local SaveFolder = "MacroRecorderData"
    local LastSelectedFile = SaveFolder .. "/_last_selected.txt"
    local SettingsFile = SaveFolder .. "/settings.json"
    local inputBeganConn, inputEndedConn, renderConn
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local GuiService = game:GetService("GuiService")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    -- ПЕРЕМЕННЫЕ (как в Macro.lua)
    Macro.Recording = false
    Macro.Playing = false
    Macro.Loop = false
    Macro.Data = {}
    Macro.RecordStart = 0
    Macro.HeldKeys = { W = false, A = false, S = false, D = false }
    Macro.LastEventSig = nil
    Macro.LastEventTime = -math.huge
    Macro.LastRecTogTime = -math.huge
    Macro.LastPlayStopTime = -math.huge
    Macro.SelectedName = nil
    Macro.Status = nil
    Macro.Count = nil
    Macro.Character = nil
    Macro.Humanoid = nil

    -- КЛАВИШИ (как в Macro.lua)
    local Keybinds = {
        RecordToggle = Enum.KeyCode.LeftBracket,
        PlayStop = Enum.KeyCode.RightBracket,
        Hide = Enum.KeyCode.F8
    }

    -- НАСТРОЙКИ (как в Macro.lua)
    local DuplicateEventWindow = 0.015
    local KeybindCooldown = 0.25
    local CompensateInset = false
    local DebugClicks = true
    local AutoLoadOnStart = true
    local AutoLoadDelay = 2
    local AutoStartPlayback = false
    local AutoStartDelay = 2

    -- ФУНКЦИИ СТАТУСА
    function Macro.SetStatus(text)
        if Macro.Status then
            pcall(function() Macro.Status:SetDesc(text) end)
        end
    end

    function Macro.UpdateCount()
        if Macro.Count then
            pcall(function() Macro.Count:SetDesc(tostring(#Macro.Data)) end)
        end
    end

    -- СИГНАТУРА
    local function EventSignature(data)
        return table.concat({
            tostring(data.Type),
            tostring(data.Key),
            tostring(data.State),
            tostring(data.X or ""),
            tostring(data.Y or "")
        }, "|")
    end

    -- ДОБАВЛЕНИЕ СОБЫТИЯ
    local function AddEvent(data)
        if not Macro.Recording then return end
        local now = os.clock() - Macro.RecordStart
        local sig = EventSignature(data)
        if sig == Macro.LastEventSig and (now - Macro.LastEventTime) < DuplicateEventWindow then return end
        Macro.LastEventSig = sig
        Macro.LastEventTime = now
        data.Time = now
        table.insert(Macro.Data, data)
        Macro.UpdateCount()
    end

    -- ЗАПИСЬ
    function Macro.StartRecording()
        if Macro.Playing then return end
        Macro.Data = {}
        Macro.RecordStart = os.clock()
        Macro.Recording = true
        Macro.LastEventSig = nil
        Macro.LastEventTime = -math.huge
        Macro.HeldKeys.W = false
        Macro.HeldKeys.A = false
        Macro.HeldKeys.S = false
        Macro.HeldKeys.D = false
        Macro.UpdateCount()
        Macro.SetStatus("Recording...")
        notifyUser("Macro Recorder", "Recording started — press [", 2)
    end

    function Macro.StopRecording()
        if not Macro.Recording then return end
        Macro.Recording = false
        Macro.HeldKeys.W = false
        Macro.HeldKeys.A = false
        Macro.HeldKeys.S = false
        Macro.HeldKeys.D = false
        Macro.SetStatus("Recording stopped (" .. #Macro.Data .. " events)")
        notifyUser("Macro Recorder", "Recorded events: " .. #Macro.Data, 3)
    end

    function Macro.ToggleRecording()
        if Macro.Recording then Macro.StopRecording() else Macro.StartRecording() end
    end

    -- НАПРАВЛЕНИЕ
    local function GetDirection()
        local dir = Vector3.zero
        if Macro.HeldKeys.W then dir = dir + Vector3.new(0, 0, -1) end
        if Macro.HeldKeys.S then dir = dir + Vector3.new(0, 0, 1) end
        if Macro.HeldKeys.A then dir = dir + Vector3.new(-1, 0, 0) end
        if Macro.HeldKeys.D then dir = dir + Vector3.new(1, 0, 0) end
        return dir
    end

    -- ОБРАБОТКА КЛАВИШ
    local function HandleRecordedAction(Action)
        local key = Action.Key
        local state = Action.State

        if key == Enum.KeyCode.W then
            Macro.HeldKeys.W = state == "Began"
        elseif key == Enum.KeyCode.A then
            Macro.HeldKeys.A = state == "Began"
        elseif key == Enum.KeyCode.S then
            Macro.HeldKeys.S = state == "Began"
        elseif key == Enum.KeyCode.D then
            Macro.HeldKeys.D = state == "Began"
        elseif key == Enum.KeyCode.Space and state == "Began" then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                hum.Jump = true
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        else
            pcall(function()
                VirtualInputManager:SendKeyEvent(state == "Began", key, false, game)
            end)
        end
    end

    -- ПОИСК CLICKDETECTOR
    local SearchRadius = 40
    local SearchStep = 8

    local function RaycastAt(x, y)
        local Camera = workspace.CurrentCamera
        if not Camera then return nil end
        local ok, unitRay = pcall(function() return Camera:ViewportPointToRay(x, y) end)
        if not ok or not unitRay then return nil end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local char = LocalPlayer.Character
        if char then params.FilterDescendantsInstances = { char } end
        local okRay, result = pcall(function() return workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params) end)
        if not okRay then return nil end
        return result
    end

    local function FindDetectorOnInstance(inst)
        local detector = inst:FindFirstChildOfClass("ClickDetector")
        if detector then return detector end
        local parent = inst.Parent
        while parent and parent ~= workspace do
            detector = parent:FindFirstChildOfClass("ClickDetector")
            if detector then return detector end
            parent = parent.Parent
        end
        return nil
    end

    local function GetClickDetectorAt(x, y)
        local result = RaycastAt(x, y)
        if result and result.Instance then
            if Settings.MacroDebugClicks then
                print(string.format("[MACRO][DEBUG] Raycast(%d,%d) hit: %s", x, y, result.Instance:GetFullName()))
            end
            local detector = FindDetectorOnInstance(result.Instance)
            if detector then
                if Settings.MacroDebugClicks then print("[MACRO][DEBUG] ClickDetector found with exact ray") end
                return detector
            end
        end

        if Settings.MacroDebugClicks then
            print(string.format("[MACRO][DEBUG] Exact ray missed, searching %dpx radius around (%d,%d)...", SearchRadius, x, y))
        end

        for r = SearchStep, SearchRadius, SearchStep do
            for i = 0, 7 do
                local angle = (i / 8) * math.pi * 2
                local nx = math.floor(x + r * math.cos(angle))
                local ny = math.floor(y + r * math.sin(angle))
                local ringResult = RaycastAt(nx, ny)
                if ringResult and ringResult.Instance then
                    local detector = FindDetectorOnInstance(ringResult.Instance)
                    if detector then
                        if Settings.MacroDebugClicks then
                            print(string.format("[MACRO][DEBUG] ClickDetector found within %dpx, point (%d,%d): %s", r, nx, ny, ringResult.Instance:GetFullName()))
                        end
                        return detector
                    end
                end
            end
        end

        if Settings.MacroDebugClicks then
            print("[MACRO][DEBUG] No ClickDetector found even with radius search")
        end
        return nil
    end

    local function TryFireClickDetector(detector)
        if type(fireclickdetector) ~= "function" then
            if Settings.MacroDebugClicks then warn("[MACRO][DEBUG] fireclickdetector is not available") end
            return false
        end
        local ok, err = pcall(function() fireclickdetector(detector, 0, "MouseClick") end)
        if Settings.MacroDebugClicks then
            if ok then print("[MACRO][DEBUG] fireclickdetector sent successfully")
            else warn("[MACRO][DEBUG] fireclickdetector raised an error:", err) end
        end
        return ok
    end

    -- ОТПРАВКА КЛИКА
    local function SendRecordedMouse(Action)
        local x = tonumber(Action.X) or 0
        local y = tonumber(Action.Y) or 0

        if Settings.MacroCompensateInset then
            pcall(function()
                local inset = GuiService:GetGuiInset()
                y = y - inset.Y
            end)
        end

        local detector = GetClickDetectorAt(x, y)
        if detector then
            if Action.State == "Began" then
                TryFireClickDetector(detector)
            end
            return
        end

        pcall(function()
            local button = Action.Key == Enum.UserInputType.MouseButton2 and 1 or 0
            local pressed = Action.State == "Began"
            VirtualInputManager:SendMouseMoveEvent(x - 1, y, game)
            RunService.Heartbeat:Wait()
            VirtualInputManager:SendMouseMoveEvent(x, y, game)
            RunService.Heartbeat:Wait()
            RunService.Heartbeat:Wait()
            VirtualInputManager:SendMouseButtonEvent(x, y, button, pressed, game, 0)
            if Settings.MacroDebugClicks then
                print("[MACRO] Virtual click at", x, y, pressed and "down" or "up")
            end
        end)
    end

    -- ВОСПРОИЗВЕДЕНИЕ
    function Macro.Play()
        if Macro.Recording or Macro.Playing then return end
        if #Macro.Data == 0 then
            notifyUser("Macro Recorder", "Macro is empty.", 2)
            return
        end

        Macro.Playing = true
        Macro.SetStatus("Playing...")

        task.spawn(function()
            repeat
                local _PreviousMacroTime = 0
                Macro.HeldKeys.W = false
                Macro.HeldKeys.A = false
                Macro.HeldKeys.S = false
                Macro.HeldKeys.D = false

                for _, Action in ipairs(Macro.Data) do
                    if not Macro.Playing then break end
                    local PreviousTime = _PreviousMacroTime or 0
                    local Delay = math.max(0, Action.Time - PreviousTime)
                    _PreviousMacroTime = Action.Time

                    if Delay > 0 then
                        local EndWait = os.clock() + Delay
                        while Macro.Playing and os.clock() < EndWait do
                            RunService.Heartbeat:Wait()
                        end
                    end

                    if not Macro.Playing then break end

                    if Action.Type == "Keyboard" then
                        HandleRecordedAction(Action)
                    elseif Action.Type == "Mouse" then
                        SendRecordedMouse(Action)
                    end
                end

            until not Settings.MacroLoop or not Macro.Playing

            Macro.HeldKeys.W = false
            Macro.HeldKeys.A = false
            Macro.HeldKeys.S = false
            Macro.HeldKeys.D = false

            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:Move(Vector3.zero, false) end

            Macro.Playing = false
            Macro.SetStatus("Ready.")
        end)
    end

    -- СОХРАНЕНИЕ
    local function SerializeMacro()
        local out = {}
        for _, action in ipairs(Macro.Data) do
            local entry = {
                Type = action.Type,
                State = action.State,
                Time = action.Time,
                X = action.X,
                Y = action.Y
            }
            if typeof(action.Key) == "EnumItem" then
                entry.Key = action.Key.Name
            end
            table.insert(out, entry)
        end
        return out
    end

    local function DeserializeMacro(data)
        local out = {}
        for _, entry in ipairs(data) do
            local action = {
                Type = entry.Type,
                State = entry.State,
                Time = entry.Time,
                X = entry.X,
                Y = entry.Y
            }
            if entry.Type == "Keyboard" and entry.Key then
                action.Key = Enum.KeyCode[entry.Key]
            elseif entry.Type == "Mouse" and entry.Key then
                action.Key = Enum.UserInputType[entry.Key]
            end
            table.insert(out, action)
        end
        return out
    end

    local function GetMacroPath(name)
        return SaveFolder .. "/" .. name .. ".json"
    end

    function Macro.ListSaved()
        local names = {}
        local ok, files = pcall(function() return listfiles(SaveFolder) end)
        if ok and files then
            for _, file in ipairs(files) do
                local name = tostring(file):match("([^\\/]+)%.json$")
                if name then table.insert(names, name) end
            end
        end
        table.sort(names)
        return names
    end

    function Macro.RememberLast(name)
        pcall(function()
            if not isfolder(SaveFolder) then makefolder(SaveFolder) end
            writefile(LastSelectedFile, name or "")
        end)
    end

    function Macro.GetLastSelected()
        local ok, exists = pcall(function() return isfile(LastSelectedFile) end)
        if not ok or not exists then return nil end
        local okRead, content = pcall(function() return readfile(LastSelectedFile) end)
        if okRead and content and content ~= "" then return content end
        return nil
    end

    function Macro.SaveNamed(name)
        if not name or name == "" then
            notifyUser("Macro Recorder", "Enter a name first.", 2)
            return false
        end
        if Macro.Recording or Macro.Playing then
            notifyUser("Macro Recorder", "Stop recording/playback before saving.", 2)
            return false
        end
        if #Macro.Data == 0 then
            notifyUser("Macro Recorder", "Macro is empty, nothing to save.", 2)
            return false
        end
        local ok, err = pcall(function()
            if not isfolder(SaveFolder) then makefolder(SaveFolder) end
            local json = HttpService:JSONEncode(SerializeMacro())
            writefile(GetMacroPath(name), json)
        end)
        if ok then
            Macro.SetStatus("Macro saved as \"" .. name .. "\" (" .. #Macro.Data .. " events).")
            notifyUser("Macro Recorder", "Saved as \"" .. name .. "\" (" .. #Macro.Data .. " events).", 2)
        else
            warn("[MACRO] Failed to save macro:", err)
            notifyUser("Macro Recorder", "Failed to save macro: " .. tostring(err), 4)
        end
        return ok
    end

    function Macro.LoadNamed(name, silent)
        if not name or name == "" then
            if not silent then notifyUser("Macro Recorder", "No macro selected.", 2) end
            return false
        end
        local path = GetMacroPath(name)
        local ok, exists = pcall(function() return isfile(path) end)
        if not ok or not exists then
            if not silent then notifyUser("Macro Recorder", "Saved macro \"" .. name .. "\" not found.", 2) end
            return false
        end
        local okLoad, result = pcall(function()
            local json = readfile(path)
            local data = HttpService:JSONDecode(json)
            return DeserializeMacro(data)
        end)
        if okLoad and result then
            Macro.Data = result
            Macro.UpdateCount()
            Macro.SetStatus("Loaded \"" .. name .. "\" (" .. #Macro.Data .. " events).")
            if not silent then
                notifyUser("Macro Recorder", "Loaded \"" .. name .. "\" (" .. #Macro.Data .. " events).", 2)
            end
            return true
        else
            warn("[MACRO] Failed to load macro:", result)
            if not silent then
                notifyUser("Macro Recorder", "Failed to load \"" .. name .. "\".", 3)
            end
            return false
        end
    end

    function Macro.RemoveNamed(name)
        if not name or name == "" then return false end
        local path = GetMacroPath(name)
        local ok = pcall(function() if isfile(path) then delfile(path) end end)
        if ok then
            Macro.SetStatus("Removed saved macro \"" .. name .. "\".")
            notifyUser("Macro Recorder", "Removed \"" .. name .. "\".", 2)
        else
            notifyUser("Macro Recorder", "Failed to remove \"" .. name .. "\".", 3)
        end
        return ok
    end

    -- НАСТРОЙКА ВВОДА
    function Macro.SetupInput()
        if inputBeganConn then inputBeganConn:Disconnect() end
        if inputEndedConn then inputEndedConn:Disconnect() end

        inputBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if input.KeyCode == Keybinds.RecordToggle then
                local now = os.clock()
                if now - Macro.LastRecTogTime < KeybindCooldown then return end
                Macro.LastRecTogTime = now
                Macro.ToggleRecording()
                return
            end

            if input.KeyCode == Keybinds.PlayStop then
                local now = os.clock()
                if now - Macro.LastPlayStopTime < KeybindCooldown then return end
                Macro.LastPlayStopTime = now
                if Macro.Playing then
                    Macro.Playing = false
                    Macro.SetStatus("Playback stopped.")
                elseif not Macro.Recording then
                    Macro.Play()
                end
                return
            end

            if gameProcessed or not Macro.Recording then return end

            if input.UserInputType == Enum.UserInputType.Keyboard then
                AddEvent({
                    Type = "Keyboard",
                    Key = input.KeyCode,
                    State = "Began"
                })
                if input.KeyCode == Enum.KeyCode.W then Macro.HeldKeys.W = true
                elseif input.KeyCode == Enum.KeyCode.A then Macro.HeldKeys.A = true
                elseif input.KeyCode == Enum.KeyCode.S then Macro.HeldKeys.S = true
                elseif input.KeyCode == Enum.KeyCode.D then Macro.HeldKeys.D = true end

            elseif input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.MouseButton2 then
                AddEvent({
                    Type = "Mouse",
                    Key = input.UserInputType,
                    State = "Began",
                    X = input.Position.X,
                    Y = input.Position.Y
                })
            end
        end)

        inputEndedConn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
            if gameProcessed or not Macro.Recording then return end

            if input.UserInputType == Enum.UserInputType.Keyboard then
                AddEvent({
                    Type = "Keyboard",
                    Key = input.KeyCode,
                    State = "Ended"
                })
                if input.KeyCode == Enum.KeyCode.W then Macro.HeldKeys.W = false
                elseif input.KeyCode == Enum.KeyCode.A then Macro.HeldKeys.A = false
                elseif input.KeyCode == Enum.KeyCode.S then Macro.HeldKeys.S = false
                elseif input.KeyCode == Enum.KeyCode.D then Macro.HeldKeys.D = false end

            elseif input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.MouseButton2 then
                AddEvent({
                    Type = "Mouse",
                    Key = input.UserInputType,
                    State = "Ended",
                    X = input.Position.X,
                    Y = input.Position.Y
                })
            end
        end)
    end

    -- ДВИЖЕНИЕ
    function Macro.StartMovement()
        if renderConn then return end
        renderConn = RunService.RenderStepped:Connect(function()
            if not Macro.Playing then return end
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end
            local Camera = workspace.CurrentCamera
            if not Camera then return end
            local Direction = GetDirection()
            if Direction.Magnitude == 0 then
                hum:Move(Vector3.zero, false)
                return
            end
            local Forward = Camera.CFrame.LookVector
            local Right = Camera.CFrame.RightVector
            Forward = Vector3.new(Forward.X, 0, Forward.Z)
            Right = Vector3.new(Right.X, 0, Right.Z)
            if Forward.Magnitude > 0 then Forward = Forward.Unit end
            if Right.Magnitude > 0 then Right = Right.Unit end
            local MoveDirection = Right * Direction.X + Forward * -Direction.Z
            hum:Move(MoveDirection, false)
        end)
    end

    -- ОСТАНОВКА ВСЕГО
    function Macro.StopAll()
        Macro.Recording = false
        Macro.Playing = false
        Macro.HeldKeys.W = false
        Macro.HeldKeys.A = false
        Macro.HeldKeys.S = false
        Macro.HeldKeys.D = false
        if inputBeganConn then inputBeganConn:Disconnect(); inputBeganConn = nil end
        if inputEndedConn then inputEndedConn:Disconnect(); inputEndedConn = nil end
        if renderConn then renderConn:Disconnect(); renderConn = nil end
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:Move(Vector3.zero, false) end
    end

    -- СОХРАНЕНИЕ НАСТРОЕК
    function Macro.SaveSettings()
        pcall(function()
            if not isfolder(SaveFolder) then makefolder(SaveFolder) end
            writefile(SettingsFile, HttpService:JSONEncode({
                AutoLoadOnStart = Settings.MacroAutoLoadOnStart,
                AutoLoadDelay = Settings.MacroAutoLoadDelay,
                AutoStartPlayback = Settings.MacroAutoStartPlayback,
                AutoStartDelay = Settings.MacroAutoStartDelay,
                CompensateInset = Settings.MacroCompensateInset,
                DebugClicks = Settings.MacroDebugClicks,
                Loop = Settings.MacroLoop,
            }))
        end)
    end

    function Macro.LoadSettings()
        local ok, exists = pcall(function() return isfile(SettingsFile) end)
        if not ok or not exists then return end
        local okLoad, data = pcall(function() return HttpService:JSONDecode(readfile(SettingsFile)) end)
        if not okLoad or not data then return end
        if data.AutoLoadOnStart ~= nil then Settings.MacroAutoLoadOnStart = data.AutoLoadOnStart end
        if data.AutoLoadDelay ~= nil then Settings.MacroAutoLoadDelay = tonumber(data.AutoLoadDelay) or Settings.MacroAutoLoadDelay end
        if data.AutoStartPlayback ~= nil then Settings.MacroAutoStartPlayback = data.AutoStartPlayback end
        if data.AutoStartDelay ~= nil then Settings.MacroAutoStartDelay = tonumber(data.AutoStartDelay) or Settings.MacroAutoStartDelay end
        if data.CompensateInset ~= nil then Settings.MacroCompensateInset = data.CompensateInset end
        if data.DebugClicks ~= nil then Settings.MacroDebugClicks = data.DebugClicks end
        if data.Loop ~= nil then Settings.MacroLoop = data.Loop end
    end
    Macro.LoadSettings()
end

-- ИНИЦИАЛИЗАЦИЯ
Macro.SetupInput()
Macro.StartMovement()
Macro.SetStatus("Ready.\n[ — record\n] — stop\n\\ — play / stop")
Macro.UpdateCount()

-- ===========================================================
-- VISUAL EFFECTS MODULES
-- ===========================================================

-- LIGHTING EFFECTS MODULE
local LightingEffects = {}
do
    local state = {
        originalAmbient = Lighting.Ambient,
        originalOutdoorAmbient = Lighting.OutdoorAmbient,
        atmosphere = nil,
        bloom = nil,
        colorCorrection = nil,
        sunRays = nil,
    }

    function LightingEffects.SetAmbient(enabled, color)
        if enabled then
            Lighting.Ambient = color or Color3.fromRGB(80, 60, 120)
            Lighting.OutdoorAmbient = color or Color3.fromRGB(80, 60, 120)
        else
            Lighting.Ambient = state.originalAmbient
            Lighting.OutdoorAmbient = state.originalOutdoorAmbient
        end
    end

    function LightingEffects.SetAtmosphere(enabled, color, density, haze, glare)
        if enabled then
            if not state.atmosphere then
                state.atmosphere = Instance.new("Atmosphere")
                state.atmosphere.Name = "CustomAtmosphere"
                state.atmosphere.Parent = Lighting
            end
            state.atmosphere.Color = color or Color3.fromRGB(120, 80, 200)
            state.atmosphere.Density = density or 0.3
            state.atmosphere.Haze = haze or 2
            state.atmosphere.Glare = glare or 0.5
        else
            if state.atmosphere then state.atmosphere:Destroy(); state.atmosphere = nil end
        end
    end

    function LightingEffects.SetBloom(enabled, intensity, size, threshold, decay)
        if enabled then
            if not state.bloom then
                state.bloom = Instance.new("BloomEffect")
                state.bloom.Name = "CustomBloom"
                state.bloom.Parent = Lighting
            end
            state.bloom.Intensity = intensity or 1
            state.bloom.Size = size or 24
            state.bloom.Threshold = threshold or 0.8
            state.bloom.Decay = decay or 0.5
        else
            if state.bloom then state.bloom:Destroy(); state.bloom = nil end
        end
    end

    function LightingEffects.SetColorCorrection(enabled, brightness, contrast, saturation, tintColor)
        if enabled then
            if not state.colorCorrection then
                state.colorCorrection = Instance.new("ColorCorrectionEffect")
                state.colorCorrection.Name = "CustomColorCorrection"
                state.colorCorrection.Parent = Lighting
            end
            state.colorCorrection.Brightness = brightness or 0
            state.colorCorrection.Contrast = contrast or 0
            state.colorCorrection.Saturation = saturation or 0
            state.colorCorrection.TintColor = tintColor or Color3.new(1, 1, 1)
        else
            if state.colorCorrection then state.colorCorrection:Destroy(); state.colorCorrection = nil end
        end
    end

    function LightingEffects.SetSunRays(enabled, intensity, spread)
        if enabled then
            if not state.sunRays then
                state.sunRays = Instance.new("SunRaysEffect")
                state.sunRays.Name = "CustomSunRays"
                state.sunRays.Parent = Lighting
            end
            state.sunRays.Intensity = intensity or 0.1
            state.sunRays.Spread = spread or 0.1
        else
            if state.sunRays then state.sunRays:Destroy(); state.sunRays = nil end
        end
    end

    function LightingEffects.ResetAll()
        LightingEffects.SetAmbient(false)
        LightingEffects.SetAtmosphere(false)
        LightingEffects.SetBloom(false)
        LightingEffects.SetColorCorrection(false)
        LightingEffects.SetSunRays(false)
    end

    LightingEffects.AmbientPresets = {
        Purple = Color3.fromRGB(80, 60, 120), Blue = Color3.fromRGB(40, 60, 140),
        Red = Color3.fromRGB(140, 40, 40), Green = Color3.fromRGB(40, 120, 60),
        Orange = Color3.fromRGB(160, 100, 40), Cyan = Color3.fromRGB(40, 120, 140),
        Pink = Color3.fromRGB(160, 60, 120), Gold = Color3.fromRGB(160, 140, 60),
    }
    LightingEffects.AtmospherePresets = {
        Purple = Color3.fromRGB(120, 80, 200), Blue = Color3.fromRGB(60, 100, 200),
        Red = Color3.fromRGB(200, 80, 80), Green = Color3.fromRGB(60, 180, 100),
        Orange = Color3.fromRGB(220, 140, 60), Cyan = Color3.fromRGB(60, 180, 220),
        Pink = Color3.fromRGB(220, 100, 180),
    }
    LightingEffects.TintPresets = {
        Normal = Color3.fromRGB(255, 255, 255), Warm = Color3.fromRGB(255, 200, 150),
        Cool = Color3.fromRGB(150, 200, 255), Sepia = Color3.fromRGB(255, 220, 180),
        Vintage = Color3.fromRGB(240, 220, 200), Cold = Color3.fromRGB(180, 200, 255),
        Dramatic = Color3.fromRGB(255, 180, 180),
    }
end

-- PLAYER AURA MODULE
local PlayerAura = {}
do
    local settings = {
        Enabled = false,
        Color = Color3.fromRGB(180, 120, 255),
        Count = 40,
        BaseSize = 0.6,
        Radius = 6,
        Height = 2,
        Speed = 3,
        Lifetime = 2,
        Glow = 0.8,
        RingCount = 2,
    }

    local folder, emitters, parts = nil, {}, {}
    local heartbeatConn, charAddedConn = nil, nil

    local function destroyVisuals()
        if heartbeatConn then heartbeatConn:Disconnect(); heartbeatConn = nil end
        for _, em in ipairs(emitters) do if em then pcall(function() em:Destroy() end) end end
        for _, pt in ipairs(parts) do if pt then pcall(function() pt:Destroy() end) end end
        emitters, parts = {}, {}
        if folder then pcall(function() folder:Destroy() end); folder = nil end
    end

    local function makeOrbitPart()
        local part = Instance.new("Part")
        part.Size = Vector3.new(0.5, 0.5, 0.5)
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.Transparency = 1
        part.Parent = folder

        local att = Instance.new("Attachment")
        att.Parent = part

        local em = Instance.new("ParticleEmitter")
        em.Parent = att
        em.Color = ColorSequence.new(settings.Color)
        em.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.3, settings.BaseSize),
            NumberSequenceKeypoint.new(0.7, settings.BaseSize),
            NumberSequenceKeypoint.new(1, 0),
        })
        em.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, 0.2),
            NumberSequenceKeypoint.new(0.8, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        })
        em.Rate = 12
        em.Speed = NumberRange.new(0, 0.5)
        em.Lifetime = NumberRange.new(settings.Lifetime * 0.6, settings.Lifetime)
        em.LightEmission = settings.Glow
        em.LightInfluence = 0
        em.ZOffset = -1
        em.RotSpeed = NumberRange.new(-30, 30)
        em.Rotation = NumberRange.new(0, 360)
        em.EmissionDirection = Enum.NormalId.Top

        table.insert(parts, part)
        table.insert(emitters, em)
        return part
    end

    local function getHRP()
        local char = LocalPlayer.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    local function startVisuals()
        destroyVisuals()
        if not settings.Enabled then return end

        folder = Instance.new("Folder")
        folder.Name = "PlayerAuraParticles"
        folder.Parent = workspace

        local perRing = math.max(3, math.floor(settings.Count / settings.RingCount))
        local ringParts = {}

        for ring = 1, settings.RingCount do
            ringParts[ring] = {}
            for i = 1, perRing do
                local part = makeOrbitPart()
                table.insert(ringParts[ring], { part = part, angleBase = (i / perRing) * math.pi * 2 })
            end
        end

        local t0 = tick()
        heartbeatConn = RunService.Heartbeat:Connect(function()
            if not settings.Enabled then return end
            local hrp = getHRP()
            if not hrp then return end
            local elapsed = tick() - t0
            local center = hrp.Position

            for ring = 1, settings.RingCount do
                local ringRadius = settings.Radius * (0.6 + (ring - 1) * 0.4)
                local ringHeight = settings.Height + (ring - 1) * 1.2
                local dir = (ring % 2 == 0) and -1 or 1
                local angularSpeed = settings.Speed * dir * (0.5 + ring * 0.15)

                for _, entry in ipairs(ringParts[ring]) do
                    local angle = entry.angleBase + elapsed * angularSpeed
                    local x = math.cos(angle) * ringRadius
                    local z = math.sin(angle) * ringRadius
                    local bob = math.sin(elapsed * 2 + entry.angleBase) * 0.3
                    if entry.part and entry.part.Parent then
                        entry.part.Position = center + Vector3.new(x, ringHeight + bob, z)
                    end
                end
            end
        end)
    end

    function PlayerAura.Init()
        if charAddedConn then return end
        charAddedConn = LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.5)
            if settings.Enabled then startVisuals() end
        end)
    end

    function PlayerAura.SetEnabled(enabled)
        settings.Enabled = enabled
        if enabled then startVisuals() else destroyVisuals() end
    end

    function PlayerAura.SetColor(color)
        settings.Color = color
        for _, em in ipairs(emitters) do if em and em.Parent then em.Color = ColorSequence.new(color) end end
    end

    function PlayerAura.SetCount(count)
        settings.Count = math.clamp(count, 4, 150)
        if settings.Enabled then startVisuals() end
    end

    function PlayerAura.SetRadius(radius) settings.Radius = radius end
    function PlayerAura.SetHeight(height) settings.Height = height end
    function PlayerAura.SetSpeed(speed) settings.Speed = speed end

    function PlayerAura.SetGlow(glow)
        settings.Glow = glow
        for _, em in ipairs(emitters) do if em and em.Parent then em.LightEmission = glow end end
    end

    function PlayerAura.SetRingCount(count)
        settings.RingCount = math.clamp(count, 1, 4)
        if settings.Enabled then startVisuals() end
    end

    PlayerAura.ColorPresets = {
        Purple = Color3.fromRGB(180, 120, 255), Blue = Color3.fromRGB(100, 150, 255),
        Pink = Color3.fromRGB(255, 120, 200), Green = Color3.fromRGB(100, 255, 180),
        Gold = Color3.fromRGB(255, 215, 80), Red = Color3.fromRGB(255, 80, 80),
        White = Color3.fromRGB(255, 255, 255), Cyan = Color3.fromRGB(80, 220, 255),
    }
end

-- TRAIL EFFECT MODULE
local TrailEffect = {}
do
    local settings = {
        Enabled = false,
        Color1 = Color3.fromRGB(140, 60, 255),
        Color2 = Color3.fromRGB(60, 200, 255),
        Lifetime = 0.5,
        WidthScale = 0.6,
    }

    local attachments = {}
    local trailInstance = nil
    local charAddedConn = nil

    local function destroy()
        if trailInstance then pcall(function() trailInstance:Destroy() end); trailInstance = nil end
        for _, att in ipairs(attachments) do if att then pcall(function() att:Destroy() end) end end
        attachments = {}
    end

    local function create()
        destroy()
        if not settings.Enabled then return end

        local character = LocalPlayer.Character
        if not character then return end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end

        local att0 = Instance.new("Attachment")
        att0.Position = Vector3.new(0, 1.5, 0)
        att0.Parent = rootPart
        table.insert(attachments, att0)

        local att1 = Instance.new("Attachment")
        att1.Position = Vector3.new(0, -1.5, 0)
        att1.Parent = rootPart
        table.insert(attachments, att1)

        local trail = Instance.new("Trail")
        trail.Attachment0 = att0
        trail.Attachment1 = att1
        trail.Color = ColorSequence.new(settings.Color1, settings.Color2)
        trail.Lifetime = settings.Lifetime
        trail.WidthScale = NumberSequence.new(settings.WidthScale, 0)
        trail.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1)
        })
        trail.LightEmission = 1
        trail.LightInfluence = 0
        trail.MinLength = 0.05
        trail.FaceCamera = true
        trail.Parent = rootPart

        trailInstance = trail
    end

    function TrailEffect.Init()
        if charAddedConn then return end
        charAddedConn = LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.5)
            if settings.Enabled then create() end
        end)
    end

    function TrailEffect.SetEnabled(enabled)
        settings.Enabled = enabled
        if enabled then create() else destroy() end
    end

    function TrailEffect.SetColors(c1, c2)
        settings.Color1, settings.Color2 = c1, c2
        if trailInstance then trailInstance.Color = ColorSequence.new(c1, c2) end
    end

    function TrailEffect.SetLifetime(v)
        settings.Lifetime = v
        if trailInstance then trailInstance.Lifetime = v end
    end

    function TrailEffect.SetWidth(v)
        settings.WidthScale = v
        if trailInstance then trailInstance.WidthScale = NumberSequence.new(v, 0) end
    end    TrailEffect.ColorPresets = {
        ["Purple-Blue"] = { Color3.fromRGB(140, 60, 255), Color3.fromRGB(60, 200, 255) },
        ["Red-Orange"]  = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 160, 60) },
        ["Green-Cyan"]  = { Color3.fromRGB(60, 255, 120), Color3.fromRGB(60, 220, 255) },
        ["Pink-Gold"]   = { Color3.fromRGB(255, 80, 200), Color3.fromRGB(255, 215, 80) },
        ["White-Blue"]  = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(100, 180, 255) },
    }
end

-- JUMP / LAND CIRCLE MODULE
local JumpCircle = {}
do
    local settings = {
        JumpEnabled = false,
        LandEnabled = false,
        Color = Color3.fromRGB(180, 120, 255),
        Size = 4,
        Duration = 0.5,
    }

    local humanoidConns = {}
    local charAddedConn = nil

    local function getRingTemplate(radius)
        local ring = Instance.new("Part")
        ring.Shape = Enum.PartType.Cylinder
        ring.Size = Vector3.new(0.2, radius * 2, radius * 2)
        ring.Anchored = true
        ring.CanCollide = false
        ring.CanQuery = false
        ring.Material = Enum.Material.Neon
        ring.Color = settings.Color
        ring.Transparency = 0.3
        ring.Orientation = Vector3.new(0, 0, 90)
        return ring
    end

    local function playRingAt(position)
        local ring = getRingTemplate(settings.Size)
        ring.Position = position
        ring.Parent = workspace

        local tween = TweenService:Create(
            ring,
            TweenInfo.new(settings.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                Size = Vector3.new(0.2, settings.Size * 3, settings.Size * 3),
                Transparency = 1,
            }
        )
        tween:Play()
        tween.Completed:Connect(function()
            ring:Destroy()
        end)
    end

    local function hookCharacter(character)
        for _, conn in ipairs(humanoidConns) do
            if conn then conn:Disconnect() end
        end
        humanoidConns = {}

        local humanoid = character:WaitForChild("Humanoid", 5)
        local rootPart = character:WaitForChild("HumanoidRootPart", 5)
        if not humanoid or not rootPart then return end

        local wasFalling = false

        local conn = humanoid.StateChanged:Connect(function(_, newState)
            if newState == Enum.HumanoidStateType.Jumping and settings.JumpEnabled then
                playRingAt(rootPart.Position - Vector3.new(0, 2.9, 0))
            elseif newState == Enum.HumanoidStateType.Freefall then
                wasFalling = true
            elseif newState == Enum.HumanoidStateType.Landed and settings.LandEnabled and wasFalling then
                wasFalling = false
                playRingAt(rootPart.Position - Vector3.new(0, 2.9, 0))
            end
        end)

        table.insert(humanoidConns, conn)
    end

    function JumpCircle.Init()
        if charAddedConn then return end
        if LocalPlayer.Character then hookCharacter(LocalPlayer.Character) end
        charAddedConn = LocalPlayer.CharacterAdded:Connect(function(character)
            hookCharacter(character)
        end)
    end

    function JumpCircle.SetJumpEnabled(v) settings.JumpEnabled = v end
    function JumpCircle.SetLandEnabled(v) settings.LandEnabled = v end
    function JumpCircle.SetColor(c) settings.Color = c end
    function JumpCircle.SetSize(v) settings.Size = v end
    function JumpCircle.SetDuration(v) settings.Duration = v end

    JumpCircle.ColorPresets = {
        Purple = Color3.fromRGB(180, 120, 255), Blue = Color3.fromRGB(100, 150, 255),
        Pink = Color3.fromRGB(255, 120, 200), Green = Color3.fromRGB(100, 255, 180),
        Gold = Color3.fromRGB(255, 215, 80), Red = Color3.fromRGB(255, 80, 80),
        White = Color3.fromRGB(255, 255, 255), Cyan = Color3.fromRGB(80, 220, 255),
    }
end

-- FOV CONTROL MODULE
local FOVControl = {}
do
    local camera = workspace.CurrentCamera
    local defaultFOV = camera and camera.FieldOfView or 70

    function FOVControl.Init()
        camera = workspace.CurrentCamera
        defaultFOV = camera and camera.FieldOfView or 70
    end

    function FOVControl.SetFOV(value)
        camera = workspace.CurrentCamera
        if camera then camera.FieldOfView = value end
    end

    function FOVControl.Reset()
        camera = workspace.CurrentCamera
        if camera then camera.FieldOfView = defaultFOV end
    end

    function FOVControl.GetDefault()
        return defaultFOV
    end
end

-- INITIALIZE ALL MODULES
PlayerAura.Init()
TrailEffect.Init()
JumpCircle.Init()
FOVControl.Init()

local Window = Fluent:CreateWindow({
    Title = "Skibidi Defense Script (Private)",
    SubTitle = "v2.6",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
    LoadingTitle = "Skibidi Defense Script",
    LoadingSubtitle = "Loading v2.6..."
})

if type(getgenv) == "function" then
    local env = getgenv()
    if env then env.SkibidiGUI = Window end
end
_G.SkibidiGUI = Window
print("[Loader] GUI window created")

pcall(function()
    Window.Minimized = true
    Window.Root.Visible = false
end)
print("[Loader] GUI hidden on start (press LeftControl to toggle)")

local MainTab = Window:AddTab({Title = "Main", Icon = "rbxassetid://120674109076896" })

MainTab:AddSection("Info")

local startTime = tick()
local infoParagraph = MainTab:AddParagraph({Title = "Stats", Content = "Loading..."})

local fps = 0
local frames = 0
local lastUpdate = tick()
RunService.RenderStepped:Connect(function()
    frames = frames + 1
    if tick() - lastUpdate >= 1 then fps = frames; frames = 0; lastUpdate = tick() end
end)

local function getPingNumber()
    local str = Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
    local num = tonumber(string.match(str, "%d+"))
    return math.floor(num or 0)
end

local function getPingText() return tostring(getPingNumber()) end

local cachedRegion = nil
local cachedServerInfo = nil
local cachedExecutor = nil
local cachedExecutorVersion = nil

local function getPlayerRegion()
    if cachedRegion then return cachedRegion end
    local region = "Unknown"
    pcall(function()
        local LocalizationService = game:GetService("LocalizationService")
        region = LocalizationService:GetCountryRegionForPlayerAsync(LocalPlayer) or "Unknown"
    end)
    cachedRegion = region
    return region
end

local function getExecutorInfo()
    if cachedExecutor then return cachedExecutor, cachedExecutorVersion end
    local name, version = "Unknown", ""
    pcall(function()
        if type(identifyexecutor) == "function" then
            local a, b = identifyexecutor()
            if type(a) == "string" and a ~= "" then name = a end
            if type(b) == "string" then version = b end
        elseif type(getexecutorname) == "function" then
            local a = getexecutorname()
            if type(a) == "string" and a ~= "" then name = a end
        elseif type(whatexecutor) == "function" then
            local a = whatexecutor()
            if type(a) == "string" and a ~= "" then name = a end
        end
    end)
    cachedExecutor, cachedExecutorVersion = name, version
    return name, version
end

local function getSUNCInfo()
    -- sUNC is a behavioral compatibility test, not a standard Roblox API.
    -- If the executor exposes a numeric score, use it; otherwise report N/A.
    local score = nil
    pcall(function()
        if type(getsuncscore) == "function" then score = getsuncscore() end
        if score == nil and type(suncscore) == "number" then score = suncscore end
        if score == nil and type(getgenv) == "function" then
            local env = getgenv()
            if env and type(env.sUNC) == "number" then score = env.sUNC end
            if env and type(env.SUNC) == "number" then score = env.SUNC end
        end
    end)
    if type(score) == "number" then
        return string.format("%g%%", score > 1 and score or score * 100)
    end
    return "N/A"
end

local function getServerInfo()
    if cachedServerInfo then return cachedServerInfo end
    local info = "Unknown"
    pcall(function()
        local jobId = game.JobId or ""
        local placeId = game.PlaceId or 0
        if jobId ~= "" then
            local shortJob = jobId:sub(1, 8)
            info = string.format("Place: %d | Server: %s", placeId, shortJob)
        else
            info = string.format("Place: %d", placeId)
        end
    end)
    cachedServerInfo = info
    return info
end

local function formatTime(sec)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = math.floor(sec % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

task.spawn(function()
    while true do
        local uptime = tick() - startTime
        local serverTime = os.date("%H:%M:%S")
        local pingText = getPingText()
        local playerRegion = getPlayerRegion()
        local executorName, executorVersion = getExecutorInfo()
        local suncInfo = getSUNCInfo()
        local serverInfo = getServerInfo()
        pcall(function()
            infoParagraph:SetTitle("Stats")
            infoParagraph:SetDesc(string.format("UpTime: %s\nTime: %s\nRegion: %s\nServer: %s\nPing: %sms\nFPS: %d\nExecutor: %s%s\nSUNC: %s", formatTime(uptime), serverTime, playerRegion, serverInfo, pingText, fps, executorName, executorVersion ~= "" and (" " .. executorVersion) or "", suncInfo))
        end)
        task.wait(1)
    end
end)

MainTab:AddSection("Lobby")

local Toggle_ShowAllTowers = MainTab:AddToggle("Toggle_ShowAllTowers", {Title = "Show All Towers", Default = Settings.ShowAllTowers, Callback = function(v) Settings.ShowAllTowers = v; if v then startShowAllTowers(); notifyUser("Show All Towers", "Enabled - All towers are visible", 2) else stopShowAllTowers(); notifyUser("Show All Towers", "Disabled - Towers restored", 2) end end })

MainTab:AddSection("Trading Plaza")

MainTab:AddButton({Title ="Teleport in Tower", Callback = function() pcall(function() local hrp = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if hrp then hrp.CFrame = CFrame.new(-2, 465, 433); notifyUser("Teleport", "In Tower", 2) end end) end })

MainTab:AddButton({Title ="Teleport in Yourself Quest", Callback = function() pcall(function() local hrp = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if hrp then hrp.CFrame = CFrame.new(10, 1736, -339); notifyUser("Teleport", "Yourself Quest", 2) end end) end })

local Toggle_BlackMarket = MainTab:AddToggle("BlackMarketToggle", {Title = "Open Black Market", Default = Settings.BlackMarket, Callback = function(v)
    Settings.BlackMarket = v
    if v then
        startBlackMarket()
        notifyUser("Black Market", "Enabled", 2)
    else
        stopBlackMarket()
        notifyUser("Black Market", "Disabled", 2)
    end
end })

local function getHRP()
    local c = Players.LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local camConn = nil
local lockedCF = nil
local savedCamPos = nil
local savedCamText = "(None)"
local function getShakeOffset()
    local offsets = {0.03, 0.05, 0.08, 0.1, 0.12}
    local x = offsets[math.random(1,#offsets)]
    local y = offsets[math.random(1,#offsets)]
    x = x * (math.random(0,1) == 1 and 1 or -1)
    y = y * (math.random(0,1) == 1 and 1 or -1)
    return x, y
end

local function disableAntiMacroScripts()
    local player = Players.LocalPlayer
    pcall(function()
        local char = player.Character or player.CharacterAdded:Wait()
        local anti = char:FindFirstChild("antimacro")
        if anti and anti:IsA("LocalScript") then anti.Enabled = false end
    end)
    pcall(function()
        local starter = game:GetService("StarterPlayer")
        local scs = starter:FindFirstChild("StarterCharacterScripts")
        if scs then
            local anti = scs:FindFirstChild("antimacro")
            if anti and anti:IsA("LocalScript") then anti.Enabled = false end
        end
    end)
end

local function startAntiMacro()
    if camConn then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    disableAntiMacroScripts()
    lockedCF = savedCamPos or cam.CFrame
    cam.CameraType = Enum.CameraType.Scriptable
    camConn = RunService.RenderStepped:Connect(function()
        if not Settings.AntiMacro then return end
        if not lockedCF then return end
        local cf = lockedCF
        if hasMacroMode("Shiking") then
            local x, y = getShakeOffset()
            cf = cf * CFrame.new(x, y, 0)
        end
        cam.CFrame = cf
    end)
end

local function updateLockedCF()
    if camConn and lockedCF and savedCamPos then
        lockedCF = savedCamPos
    end
end

local function applySavedCamera()
    pcall(function()
        local cam = workspace.CurrentCamera
        if not cam or not savedCamPos then return end
        cam.CFrame = savedCamPos
        if camConn and Settings.AntiMacro then lockedCF = savedCamPos end
    end)
end

local function stopAntiMacro()
    if camConn then camConn:Disconnect(); camConn = nil end
    local cam = workspace.CurrentCamera
    if cam then cam.CameraType = Enum.CameraType.Custom end
    lockedCF = nil
end

MainTab:AddSection("Macro")

MainTab:AddParagraph({Title = "Bypass Macros", Content = "Camera Lock + Shake / Walking\nВыбери режимы в списке ниже" })

local Toggle_AntiMacro = MainTab:AddToggle("Toggle_AntiMacro", {Title = "Camera Lock", Default = Settings.AntiMacro, Callback = function(v)
    Settings.AntiMacro = v
    if v then
        startAntiMacro()
        if hasMacroMode("Walking") then startWalkMacro() end
        notifyUser("Camera Lock", "ON", 2)
    else
        stopAntiMacro()
        stopWalkMacro()
        notifyUser("Camera Lock", "OFF", 2)
    end
end })

local currentMacroOption = "None"
if hasMacroMode("Shiking") and hasMacroMode("Walking") then
    currentMacroOption = "Shiking + Walking"
elseif hasMacroMode("Shiking") then
    currentMacroOption = "Shiking"
elseif hasMacroMode("Walking") then
    currentMacroOption = "Walking"
end

local macroDropdown = MainTab:AddDropdown("MacroModes", {
    Title = "Macro Modes",
    Values = {"None", "Shiking", "Walking", "Shiking + Walking"},
    Default = currentMacroOption,
    Callback = function(opt)
        Settings.MacroModes = {}
        if opt == "Shiking" then
            table.insert(Settings.MacroModes, "Shiking")
        elseif opt == "Walking" then
            table.insert(Settings.MacroModes, "Walking")
        elseif opt == "Shiking + Walking" then
            table.insert(Settings.MacroModes, "Shiking")
            table.insert(Settings.MacroModes, "Walking")
        end
        
        if not Settings.AntiMacro and opt ~= "None" then
            notifyUser("Macro Modes", "Turn on Camera Lock first!", 2)
            return
        end
        
        local parts = {}
        if hasMacroMode("Shiking") then table.insert(parts, "Shiking") end
        if hasMacroMode("Walking") then startWalkMacro(); table.insert(parts, "Walking") else stopWalkMacro() end
        
        if Settings.NotificationsEnabled and #parts > 0 then
            notifyUser("Macro Modes", table.concat(parts, " + "), 1)
        end
    end
})

MainTab:AddSection("Walk Settings")

local walkPresets = {
    None = {WalkChance = 0, JumpChance = 0, MoveDurationMin = 0.8, MoveDurationMax = 2.5, PauseMin = 0.05, PauseMax = 0.3},
    Slow = {WalkChance = 25, JumpChance = 10, MoveDurationMin = 1.5, MoveDurationMax = 3.5, PauseMin = 0.3, PauseMax = 1.0},
    Medium = {WalkChance = 40, JumpChance = 15, MoveDurationMin = 0.8, MoveDurationMax = 2.5, PauseMin = 0.05, PauseMax = 0.3},
    Fast = {WalkChance = 60, JumpChance = 25, MoveDurationMin = 0.4, MoveDurationMax = 1.5, PauseMin = 0.02, PauseMax = 0.15},
    Custom = nil
}

local walkPresetDropdown = MainTab:AddDropdown("WalkPreset", {
    Title = "Walk Preset",
    Values = {"None", "Slow", "Medium", "Fast", "Custom"},
    Default = "Medium",
    Callback = function(opt)
        local preset = walkPresets[opt]
        if preset then
            Settings.WalkChance = preset.WalkChance
            Settings.JumpChance = preset.JumpChance
            Settings.MoveDurationMin = preset.MoveDurationMin
            Settings.MoveDurationMax = preset.MoveDurationMax
            Settings.PauseMin = preset.PauseMin
            Settings.PauseMax = preset.PauseMax
            if walkChanceSlider then walkChanceSlider:SetValue(preset.WalkChance) end
            if jumpChanceSlider then jumpChanceSlider:SetValue(preset.JumpChance) end
            if moveMinSlider then moveMinSlider:SetValue(preset.MoveDurationMin) end
            if moveMaxSlider then moveMaxSlider:SetValue(preset.MoveDurationMax) end
            if pauseMinSlider then pauseMinSlider:SetValue(preset.PauseMin) end
            if pauseMaxSlider then pauseMaxSlider:SetValue(preset.PauseMax) end
            notifyUser("Walk Settings", "Preset: " .. opt, 1)
        end
    end
})

MainTab:AddParagraph({Title = "Custom Walk", Content = "Select 'Custom' preset to manually adjust sliders below"})

local walkChanceSlider = MainTab:AddSlider("WalkChance", {Title = "Walk Chance (%)", Min = 0, Max = 90, Rounding = 0, Default = Settings.WalkChance, Callback = function(v) Settings.WalkChance = v end })
local jumpChanceSlider = MainTab:AddSlider("JumpChance", {Title = "Jump Chance (%)", Min = 0, Max = 50, Rounding = 0, Default = Settings.JumpChance, Callback = function(v) Settings.JumpChance = v end })
local moveMinSlider = MainTab:AddSlider("MoveMin", {Title = "Move Min (s)", Min = 0.2, Max = 3, Rounding = 1, Default = Settings.MoveDurationMin, Callback = function(v) Settings.MoveDurationMin = v end })
local moveMaxSlider = MainTab:AddSlider("MoveMax", {Title = "Move Max (s)", Min = 0.5, Max = 5, Rounding = 1, Default = Settings.MoveDurationMax, Callback = function(v) Settings.MoveDurationMax = v end })
local pauseMinSlider = MainTab:AddSlider("PauseMin", {Title = "Pause Min (s)", Min = 0, Max = 1, Rounding = 2, Default = Settings.PauseMin, Callback = function(v) Settings.PauseMin = v end })
local pauseMaxSlider = MainTab:AddSlider("PauseMax", {Title = "Pause Max (s)", Min = 0.1, Max = 2, Rounding = 2, Default = Settings.PauseMax, Callback = function(v) Settings.PauseMax = v end })

local savedPosition = nil
local savedCoordsText = "(None)"

local teleportButton = MainTab:AddButton({Title ="Teleport to Position (None)", Callback = function() local hrp = getHRP(); if hrp and savedPosition then hrp.CFrame = savedPosition; notifyUser("Teleported", "To " .. savedCoordsText, 2) else notifyUser("Error", "No saved position", 2) end end })

MainTab:AddButton({Title ="Save Position", Callback = function() local hrp = getHRP(); if not hrp then return end; savedPosition = hrp.CFrame; local x, y, z = math.floor(hrp.Position.X), math.floor(hrp.Position.Y), math.floor(hrp.Position.Z); savedCoordsText = string.format("(%d, %d, %d)", x, y, z); teleportButton:SetTitle("Teleport to Position " .. savedCoordsText); notifyUser("Saved", "Saved at " .. savedCoordsText, 2) end })

local camTeleportButton = MainTab:AddButton({Title ="Save Camera Position (None)", Callback = function() local cam = workspace.CurrentCamera; if not cam then return end; savedCamPos = cam.CFrame; local p = cam.CFrame.Position; savedCamText = string.format("(%d, %d, %d)", math.floor(p.X), math.floor(p.Y), math.floor(p.Z)); camTeleportButton:SetTitle("Save Camera Position ("..savedCamText..")"); notifyUser("Camera", "Saved at " .. savedCamText, 2) end })

local camResetButton = MainTab:AddButton({Title ="Reset Camera Position", Callback = function() savedCamPos = nil; savedCamText = "(None)"; pcall(function() camTeleportButton:SetTitle("Save Camera Position (None)") end); notifyUser("Camera", "Saved position cleared", 2) end })

Players.LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if Settings.AutoRestoreCam and savedCamPos and workspace.CurrentCamera then
        workspace.CurrentCamera.CFrame = savedCamPos
        if camConn and Settings.AntiMacro then lockedCF = savedCamPos end
    end
end)

MainTab:AddSection("Teleports")

MainTab:AddButton({Title ="Lobby", Callback = function() pcall(function() game:GetService("TeleportService"):Teleport(14279693118, Players.LocalPlayer); notifyUser("Teleport", "To Lobby", 2) end) end })

MainTab:AddButton({Title ="Trading Plaza", Callback = function() pcall(function() game:GetService("TeleportService"):Teleport(18711550363, Players.LocalPlayer); notifyUser("Teleport", "To Trading Plaza", 2) end) end })

MainTab:AddButton({Title ="HappyBirtchDay", Callback = function() pcall(function() game:GetService("TeleportService"):Teleport(93311267472350, Players.LocalPlayer); notifyUser("Teleport", "To HappyBirtchDay", 2) end) end })

local FeaturesTab = Window:AddTab({Title = "Features", Icon = "rbxassetid://4483345998" })

FeaturesTab:AddParagraph({Title = "Coming Soon", Content = "New features are being developed and will be available in future updates.\n\nStay tuned!"})

local OtherTab = Window:AddTab({Title = "Other", Icon = "rbxassetid://102763551061763" })

OtherTab:AddSection("Utilities")

local originalHoldDurations = {}

local function saveOriginalHoldDuration(prompt) if originalHoldDurations[prompt] == nil then originalHoldDurations[prompt] = prompt.HoldDuration end end
local function setInstantProxMount(prompt) saveOriginalHoldDuration(prompt); pcall(function() prompt.HoldDuration = 0 end) end
local function restoreOriginalHoldDuration(prompt) if originalHoldDurations[prompt] ~= nil then pcall(function() prompt.HoldDuration = originalHoldDurations[prompt] end) end end
local function applyInstantProxMount(action) for _, prompt in ipairs(workspace:GetDescendants()) do if prompt:IsA("ProximityPrompt") then if action == "set" then setInstantProxMount(prompt) elseif action == "restore" then restoreOriginalHoldDuration(prompt) end end end end

workspace.DescendantAdded:Connect(function(descendant) task.wait(0.1); if descendant:IsA("ProximityPrompt") and Settings.InstantProxMount then setInstantProxMount(descendant) end end)
task.spawn(function() while true do task.wait(0.5); if Settings.InstantProxMount then applyInstantProxMount("set") end end end)

local antiAFKEnabled = Settings.AntiAFK
local function startAntiAFK() if antiAFKEnabled then return end; antiAFKEnabled = true; Settings.AntiAFK = true; loadstring(game:HttpGet("https://raw.githubusercontent.com/hassanxzayn-lua/Anti-afk/main/antiafkbyhassanxzyn"))(); notifyUser("Anti AFK", "Enabled", 2) end

OtherTab:AddButton({Title =antiAFKEnabled and "Anti AFK [ON]" or "Anti AFK", Callback = function() if not antiAFKEnabled then startAntiAFK() end end })

local Toggle_InstantProxMount = OtherTab:AddToggle("Toggle_InstantProxMount", {Title = "Instant ProxMount", Default = Settings.InstantProxMount, Callback = function(v) Settings.InstantProxMount = v; if v then applyInstantProxMount("set"); notifyUser("Instant ProxMount", "HoldDuration = 0", 2) else applyInstantProxMount("restore"); notifyUser("Instant ProxMount", "Restored", 2) end end })

local dexLoaded = false
local function loadDex() if dexLoaded then return end; dexLoaded = true; task.spawn(xpcall, assert(loadstring(game:HttpGet('https://raw.githubusercontent.com/Diffone7/r/refs/heads/main/tsb/dex')), warn)); notifyUser("Dex", "Loaded!", 2) end

OtherTab:AddButton({Title ="Dex Explorer", Callback = function() if not dexLoaded then loadDex() end end })
OtherTab:AddButton({Title ="Rejoin", Callback = function() notifyUser("Rejoin", "Rejoining server...", 2); task.wait(1); game:GetService("TeleportService"):Teleport(game.PlaceId, Players.LocalPlayer) end })
OtherTab:AddButton({Title ="Infinite Yield", Callback = function() loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))(); notifyUser("Infinite Yield", "Loaded!", 2) end })

local serverHopActive = false
local serverHopConnection = nil

local function destroyServerHopUI()
    pcall(function()
        local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            for _, gui in ipairs(playerGui:GetChildren()) do
                if gui:IsA("ScreenGui") then
                    local nameLower = string.lower(gui.Name)
                    if nameLower:find("server") or nameLower:find("hop") or nameLower:find("teleport") or nameLower:find("hub") or nameLower == "main" or gui:FindFirstChild("ServerList") or gui:FindFirstChild("ServerHop") then
                        gui:Destroy()
                    end
                end
            end
        end
        local coreGui = game:GetService("CoreGui")
        if coreGui then
            for _, gui in ipairs(coreGui:GetChildren()) do
                if gui:IsA("ScreenGui") then
                    local nameLower = string.lower(gui.Name)
                    if nameLower:find("server") or nameLower:find("hop") then gui:Destroy() end
                end
            end
        end
        if _G.ServerHop then _G.ServerHop = nil end
        if type(getgenv) == "function" then
            local env = getgenv()
            if env then env.ServerHop = nil end
        end
        if _G.ServerHopUI then _G.ServerHopUI = nil end
        if type(getgenv) == "function" then
            local env = getgenv()
            if env then env.ServerHopUI = nil end
        end
        if serverHopConnection then serverHopConnection:Disconnect(); serverHopConnection = nil end
    end)
end

local function loadServerHopUI()
    if serverHopActive then
        destroyServerHopUI()
        serverHopActive = false
        notifyUser("Server Hop UI", "Closed", 2)
        return
    end
    destroyServerHopUI()
    serverHopActive = true
    task.spawn(function()
        local success, err = pcall(function()
            local hopScript = game:HttpGet('https://raw.githubusercontent.com/MrAdivikPlayYT/sdkasjdskfjasd/refs/heads/main/Hop.lua')
            local func = loadstring(hopScript)
            if func then func() else error("Failed to loadstring") end
        end)
        if not success then
            serverHopActive = false
            notifyUser("Server Hop UI", "Failed to load: " .. tostring(err), 3)
        else
            notifyUser("Server Hop UI", "Loaded! Press again to close", 2)
        end
    end)
end

OtherTab:AddButton({Title ="Server Hop UI", Callback = function() loadServerHopUI() end })

local infCamEnabled = false
local oldMinZoom = nil
local oldMaxZoom = nil
local function toggleInfCamera(v)
    local player = Players.LocalPlayer
    if v then
        oldMinZoom = player.CameraMinZoomDistance
        oldMaxZoom = player.CameraMaxZoomDistance
        player.CameraMinZoomDistance = 0.5
        player.CameraMaxZoomDistance = 100000
    else
        if oldMinZoom and oldMaxZoom then
            player.CameraMinZoomDistance = oldMinZoom
            player.CameraMaxZoomDistance = oldMaxZoom
        end
    end
end

OtherTab:AddToggle("InfCamera", {Title = "Inf Camera Distance", Default = false, Callback = function(v) infCamEnabled = v; toggleInfCamera(v); notifyUser("Camera Distance", v and "Infinite Enabled" or "Restored", 2) end })

local Toggle_AutoRestoreCam = OtherTab:AddToggle("AutoRestoreCam", {Title = "Auto Restore Camera", Default = Settings.AutoRestoreCam, Callback = function(v) Settings.AutoRestoreCam = v; notifyUser("Camera", v and "Auto restore ON" or "Auto restore OFF", 2) end })

OtherTab:AddSection("Settings")

local Toggle_NotificationsEnabled = OtherTab:AddToggle("Toggle_NotificationsEnabled", {Title = "Show Notifications", Default = Settings.NotificationsEnabled, Callback = function(v) Settings.NotificationsEnabled = v; notifyUser("Notifications", v and "Enabled" or "Disabled", 2) end })

OtherTab:AddSection("Unload")

-- Переменная для контроля AutoSave
local autoSaveRunning = true

OtherTab:AddButton({Title = "Unload Script", Callback = function()
    autoSaveRunning = false -- Останавливаем AutoSave
    
    pcall(function() stopWalkMacro() end)
    pcall(function() stopAntiMacro() end)
    pcall(function() stopShowAllTowers() end)
    pcall(function() stopBlackMarket() end)
    pcall(function() stopMatchTracking() end)
    pcall(function() disablePotatoGraphics() end)
    pcall(function() applyInstantProxMount("restore") end)
    pcall(function() resetBoosts() end)
    pcall(function() setGameSpeed(1) end)
    pcall(function() LightingEffects.ResetAll() end)
    pcall(function() PlayerAura.SetEnabled(false) end)
    pcall(function() TrailEffect.SetEnabled(false) end)
    pcall(function() JumpCircle.SetJumpEnabled(false) end)
    pcall(function() JumpCircle.SetLandEnabled(false) end)
    pcall(function() FOVControl.Reset() end)
    pcall(function() Macro.StopAll() end)
    
    pcall(function()
        if descendantConnection then descendantConnection:Disconnect(); descendantConnection = nil end
        if showAllTowersConnection then showAllTowersConnection:Disconnect(); showAllTowersConnection = nil end
        if blackMarketConnection then blackMarketConnection:Disconnect(); blackMarketConnection = nil end
        if camConn then camConn:Disconnect(); camConn = nil end
        if endedConnection then endedConnection:Disconnect(); endedConnection = nil end
    end)
    
    pcall(function() toggleInfCamera(false) end)
    pcall(function() restoreEverything() end)
    pcall(function() restorePostEffects() end)
    
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then cam.CameraType = Enum.CameraType.Custom end
    end)
    
    pcall(function()
        if Window and Window.Destroy then Window:Destroy() end
    end)
    
    _G.SkibidiDefenseLoaded = nil
    _G.SkibidiGUI = nil
    if type(getgenv) == "function" then
        local env = getgenv()
        if env then env.SkibidiGUI = nil end
    end
    
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Skibidi Defense",
            Text = "Script unloaded!",
            Duration = 3
        })
    end)
    
    print("[Unload] Script fully unloaded")
end })

local VisualTab = Window:AddTab({Title = "Visual", Icon = "rbxassetid://10885652171" })

VisualTab:AddSection("Potato Graphics")
VisualTab:AddParagraph({Title = "Potato Graphics Mode", Content = "Maximum FPS Boost for low-end PCs\n\n• Disables shadows\n• Removes particles, trails & beams\n• Turns all materials to Plastic\n• Disables water effects\n• Disables bloom & post-processing" })
local Toggle_PotatoGraphics = VisualTab:AddToggle("Toggle_PotatoGraphics", {Title = "Potato Graphics Mode", Default = Settings.PotatoGraphics, Callback = function(v) togglePotatoGraphics(v) end })

VisualTab:AddSection("Game")
VisualTab:AddInput("GameSpeed", {Title = "Enter Speed", Placeholder = "0.1 - 10", Default = tostring(Settings.GameSpeed), Callback = function(Text) local speed = tonumber(Text); if speed then if speed < 0.1 then speed = 0.1 end; if speed > 10 then speed = 10 end; Settings.GameSpeed = speed; setGameSpeed(speed) else notifyUser("Game Speed", "Invalid! Use 0.1 - 10", 2) end end })
VisualTab:AddButton({Title ="Reset Game Speed (1x)", Callback = function() Settings.GameSpeed = 1; setGameSpeed(1) end })

VisualTab:AddSection("Tower Boosts")
VisualTab:AddDropdown("BoostType", {Title = "Boost Type", Values = {"DMG", "CASH", "COST", "HD", "RNG", "SKIP", "SPA"}, Default = Settings.SelectedBoostType, Callback = function(opt) Settings.SelectedBoostType = opt; notifyUser("Tower Boosts", "Selected: " .. opt, 1) end })
VisualTab:AddInput("BoostValue", {Title = "Boost Value", Placeholder = "Enter value (or inf)", Default = "", Callback = function(Text) local value; if string.lower(Text) == "inf" then value = math.huge else value = tonumber(Text) end; if value then applyBoostSafe(Settings.SelectedBoostType, value) else notifyUser("Tower Boosts", "Invalid number! Use 0-999 or inf", 2) end end })
VisualTab:AddButton({Title ="Reset All Tower Boosts", Callback = function() resetBoosts() end })

local VisualState = {
    Ambient = { enabled = false, color = "Purple" },
    Atmosphere = { enabled = false, color = "Purple", density = 0.3 },
    Bloom = { enabled = false, intensity = 1 },
    ColorCorrection = { enabled = false, saturation = 0, tint = "Normal" },
    SunRays = { enabled = false },
    FOV = math.floor(FOVControl.GetDefault()),
    Aura = { enabled = false, color = "Purple", count = 40, radius = 6 },
    Trail = { enabled = false, color = "Purple-Blue", lifetime = 0.5, width = 0.6 },
    JumpCircle = { enabled = false, land = false, color = "Purple" },
}
local VisualControls = {}

VisualTab:AddSection("Ambient Light")
VisualControls.AmbientToggle = VisualTab:AddToggle("AmbientToggle", {
    Title = "Custom Ambient Light", Default = false,
    Callback = function(v) VisualState.Ambient.enabled = v; LightingEffects.SetAmbient(v, LightingEffects.AmbientPresets[VisualState.Ambient.color]) end
})
VisualControls.AmbientColorDropdown = VisualTab:AddDropdown("AmbientColorDropdown", {
    Title = "Ambient Color",
    Values = { "Purple", "Blue", "Red", "Green", "Orange", "Cyan", "Pink", "Gold" },
    Default = "Purple",
    Callback = function(opt)
        VisualState.Ambient.color = opt
        if VisualState.Ambient.enabled then LightingEffects.SetAmbient(true, LightingEffects.AmbientPresets[opt]) end
    end
})

VisualTab:AddSection("Atmosphere")
VisualControls.AtmosphereToggle = VisualTab:AddToggle("AtmosphereToggle", {
    Title = "Enable Atmosphere", Default = false,
    Callback = function(v) VisualState.Atmosphere.enabled = v; LightingEffects.SetAtmosphere(v, LightingEffects.AtmospherePresets[VisualState.Atmosphere.color], VisualState.Atmosphere.density) end
})
VisualControls.AtmosphereColorDropdown = VisualTab:AddDropdown("AtmosphereColorDropdown", {
    Title = "Atmosphere Color",
    Values = { "Purple", "Blue", "Red", "Green", "Orange", "Cyan", "Pink" },
    Default = "Purple",
    Callback = function(opt)
        VisualState.Atmosphere.color = opt
        if VisualState.Atmosphere.enabled then LightingEffects.SetAtmosphere(true, LightingEffects.AtmospherePresets[opt], VisualState.Atmosphere.density) end
    end
})
VisualControls.AtmosphereDensity = VisualTab:AddSlider("AtmosphereDensity", {
    Title = "Density", Min = 0, Max = 1, Rounding = 2, Default = 0.3,
    Callback = function(v)
        VisualState.Atmosphere.density = v
        if VisualState.Atmosphere.enabled then LightingEffects.SetAtmosphere(true, LightingEffects.AtmospherePresets[VisualState.Atmosphere.color], v) end
    end
})

VisualTab:AddSection("Bloom")
VisualControls.BloomToggle = VisualTab:AddToggle("BloomToggle", {
    Title = "Enable Bloom", Default = false,
    Callback = function(v) VisualState.Bloom.enabled = v; LightingEffects.SetBloom(v, VisualState.Bloom.intensity, 24, 0.8, 0.5) end
})
VisualControls.BloomIntensity = VisualTab:AddSlider("BloomIntensity", {
    Title = "Bloom Intensity", Min = 0, Max = 5, Rounding = 1, Default = 1,
    Callback = function(v)
        VisualState.Bloom.intensity = v
        if VisualState.Bloom.enabled then LightingEffects.SetBloom(true, v, 24, 0.8, 0.5) end
    end
})

VisualTab:AddSection("Color Correction")
VisualControls.ColorCorrectionToggle = VisualTab:AddToggle("ColorCorrectionToggle", {
    Title = "Enable Color Correction", Default = false,
    Callback = function(v) VisualState.ColorCorrection.enabled = v; LightingEffects.SetColorCorrection(v, 0, 0, VisualState.ColorCorrection.saturation, LightingEffects.TintPresets[VisualState.ColorCorrection.tint]) end
})
VisualControls.TintDropdown = VisualTab:AddDropdown("TintDropdown", {
    Title = "Tint",
    Values = { "Normal", "Warm", "Cool", "Sepia", "Vintage", "Cold", "Dramatic" },
    Default = "Normal",
    Callback = function(opt)
        VisualState.ColorCorrection.tint = opt
        if VisualState.ColorCorrection.enabled then LightingEffects.SetColorCorrection(true, 0, 0, VisualState.ColorCorrection.saturation, LightingEffects.TintPresets[opt]) end
    end
})
VisualControls.Saturation = VisualTab:AddSlider("Saturation", {
    Title = "Saturation", Min = -1, Max = 1, Rounding = 1, Default = 0,
    Callback = function(v)
        VisualState.ColorCorrection.saturation = v
        if VisualState.ColorCorrection.enabled then LightingEffects.SetColorCorrection(true, 0, 0, v, LightingEffects.TintPresets[VisualState.ColorCorrection.tint]) end
    end
})

VisualTab:AddSection("Sun Rays")
VisualControls.SunRaysToggle = VisualTab:AddToggle("SunRaysToggle", {
    Title = "Enable Sun Rays", Default = false,
    Callback = function(v) VisualState.SunRays.enabled = v; LightingEffects.SetSunRays(v, 0.1, 0.1) end
})

VisualTab:AddSection("Field of View")
VisualControls.FOVSlider = VisualTab:AddSlider("FOVSlider", {
    Title = "FOV", Min = 30, Max = 120, Rounding = 0, Default = math.floor(FOVControl.GetDefault()),
    Callback = function(v) VisualState.FOV = v; FOVControl.SetFOV(v) end
})
VisualTab:AddButton({
    Title = "Reset FOV",
    Callback = function() FOVControl.Reset(); VisualState.FOV = math.floor(FOVControl.GetDefault()); if VisualControls.FOVSlider then VisualControls.FOVSlider:SetValue(VisualState.FOV) end end
})

VisualTab:AddSection("Player Aura")
VisualControls.AuraToggle = VisualTab:AddToggle("AuraToggle", {
    Title = "Enable Player Aura", Default = false,
    Callback = function(v) VisualState.Aura.enabled = v; PlayerAura.SetEnabled(v) end
})
VisualControls.AuraColorDropdown = VisualTab:AddDropdown("AuraColorDropdown", {
    Title = "Aura Color",
    Values = { "Purple", "Blue", "Pink", "Green", "Gold", "Red", "White", "Cyan" },
    Default = "Purple",
    Callback = function(opt) VisualState.Aura.color = opt; PlayerAura.SetColor(PlayerAura.ColorPresets[opt]) end
})
VisualControls.AuraCount = VisualTab:AddSlider("AuraCount", {
    Title = "Aura Particle Count", Min = 4, Max = 150, Rounding = 0, Default = 40,
    Callback = function(v) VisualState.Aura.count = v; PlayerAura.SetCount(v) end
})
VisualControls.AuraRadius = VisualTab:AddSlider("AuraRadius", {
    Title = "Aura Orbit Radius", Min = 1, Max = 20, Rounding = 1, Default = 6,
    Callback = function(v) VisualState.Aura.radius = v; PlayerAura.SetRadius(v) end
})

VisualTab:AddSection("Character Trail")
VisualControls.TrailToggle = VisualTab:AddToggle("TrailToggle", {
    Title = "Enable Trail", Default = false,
    Callback = function(v) VisualState.Trail.enabled = v; TrailEffect.SetEnabled(v) end
})
VisualControls.TrailColorDropdown = VisualTab:AddDropdown("TrailColorDropdown", {
    Title = "Trail Color",
    Values = { "Purple-Blue", "Red-Orange", "Green-Cyan", "Pink-Gold", "White-Blue" },
    Default = "Purple-Blue",
    Callback = function(opt)
        VisualState.Trail.color = opt
        local c = TrailEffect.ColorPresets[opt]
        TrailEffect.SetColors(c[1], c[2])
    end
})
VisualControls.TrailLifetime = VisualTab:AddSlider("TrailLifetime", {
    Title = "Trail Lifetime", Min = 0.1, Max = 2, Rounding = 1, Default = 0.5,
    Callback = function(v) VisualState.Trail.lifetime = v; TrailEffect.SetLifetime(v) end
})
VisualControls.TrailWidth = VisualTab:AddSlider("TrailWidth", {
    Title = "Trail Width", Min = 0.1, Max = 2, Rounding = 1, Default = 0.6,
    Callback = function(v) VisualState.Trail.width = v; TrailEffect.SetWidth(v) end
})

VisualTab:AddSection("Jump / Land Circle")
VisualControls.JumpCircleToggle = VisualTab:AddToggle("JumpCircleToggle", {
    Title = "Enable Jump Circle", Default = false,
    Callback = function(v) VisualState.JumpCircle.enabled = v; JumpCircle.SetJumpEnabled(v) end
})
VisualControls.LandCircleToggle = VisualTab:AddToggle("LandCircleToggle", {
    Title = "Enable Land Circle", Default = false,
    Callback = function(v) VisualState.JumpCircle.land = v; JumpCircle.SetLandEnabled(v) end
})
VisualControls.JumpCircleColorDropdown = VisualTab:AddDropdown("JumpCircleColorDropdown", {
    Title = "Circle Color",
    Values = { "Purple", "Blue", "Pink", "Green", "Gold", "Red", "White", "Cyan" },
    Default = "Purple",
    Callback = function(opt) VisualState.JumpCircle.color = opt; JumpCircle.SetColor(JumpCircle.ColorPresets[opt]) end
})

VisualTab:AddSection("Reset")
VisualTab:AddButton({
    Title = "Disable All Effects",
    Callback = function()
        LightingEffects.ResetAll()
        PlayerAura.SetEnabled(false)
        TrailEffect.SetEnabled(false)
        JumpCircle.SetJumpEnabled(false)
        JumpCircle.SetLandEnabled(false)
        FOVControl.Reset()
    end
})

local WebhookTab = Window:AddTab({Title = "WebHook", Icon = "rbxassetid://12465540157" })

WebhookTab:AddSection("Webhook Settings")
local Toggle_WebhookEnabled = WebhookTab:AddToggle("Toggle_WebhookEnabled", {Title = "Enable Webhook", Default = Settings.WebhookEnabled, Callback = function(v) Settings.WebhookEnabled = v; if Settings.AutoSaveEnabled and currentConfig ~= "default" then saveConfig(currentConfig) end end })
WebhookTab:AddInput("WebhookURL", {Title = "Webhook URL", Placeholder = "https://discord.com/api/webhooks/...", Default = Settings.WebhookURL, Callback = function(Text) Settings.WebhookURL = Text; if Settings.AutoSaveEnabled and currentConfig ~= "default" then saveConfig(currentConfig) end end })

WebhookTab:AddSection("Match Tracker Settings")
WebhookTab:AddToggle("WebhookMatchTracking", {Title = "Track Matches (Win/Loss)", Default = false, Callback = function(v) Settings.WebhookMatchTracking = v; if v then startMatchTracking() else stopMatchTracking() end; if Settings.AutoSaveEnabled and currentConfig ~= "default" then saveConfig(currentConfig) end end })
WebhookTab:AddToggle("ShowLogInWebhook", {Title = "Show Log in Webhook", Default = true, Callback = function(v) Settings.ShowLogInWebhook = v; if Settings.AutoSaveEnabled and currentConfig ~= "default" then saveConfig(currentConfig) end end })

WebhookTab:AddSection("Display Fields")
local matchFieldsText = WebhookTab:AddParagraph({Title = "Selected Fields", Content = table.concat(Settings.WebhookMatchFields, ", ") })
local function updateMatchFieldsText() pcall(function() matchFieldsText:SetDesc(#Settings.WebhookMatchFields > 0 and table.concat(Settings.WebhookMatchFields, ", ") or "None") end); Settings.WebhookMatchFields = Settings.WebhookMatchFields; if Settings.AutoSaveEnabled and currentConfig ~= "default" then saveConfig(currentConfig) end end

local fieldsList = {"Result", "Streak", "Kills", "Survived", "Time", "Items", "Credits", "Crystals", "Spent", "Player", "TotalCredits"}
local fieldToggles = {}
for _, field in ipairs(fieldsList) do
    local isDefaultOn = table.find(Settings.WebhookMatchFields, field) ~= nil
    fieldToggles[field] = WebhookTab:AddToggle("Show_"..field, {
        Title = "Show " .. field,
        Default = isDefaultOn,
        Callback = function(v)
            local idx = table.find(Settings.WebhookMatchFields, field)
            if v and not idx then
                table.insert(Settings.WebhookMatchFields, field)
            elseif not v and idx then
                table.remove(Settings.WebhookMatchFields, idx)
            end
            updateMatchFieldsText()
        end
    })
end

WebhookTab:AddButton({Title ="Reset Win Streak & Total Credits", Callback = function() winStreak = 0; totalCredits = 0; notifyUser("Reset", "Reset to 0", 2) end })

WebhookTab:AddButton({Title ="Test Webhook", Callback = function()
    if Settings.WebhookEnabled and Settings.WebhookURL ~= "" then
        local testFields = {}
        for _, field in ipairs(Settings.WebhookMatchFields) do
            if field == "Result" then
                table.insert(testFields, { name = "Результат", value = "ТЕСТ", inline = false })
            elseif field == "Streak" then
                table.insert(testFields, { name = "Win Streak", value = "3", inline = true })
            elseif field == "Kills" then
                table.insert(testFields, { name = "Убийств", value = "999", inline = true })
            elseif field == "Survived" then
                table.insert(testFields, { name = "Выжил", value = "25", inline = true })
            elseif field == "Time" then
                table.insert(testFields, { name = "Время", value = "12:34", inline = true })
            elseif field == "Items" then
                table.insert(testFields, { name = "Предметов", value = "99", inline = true })
            elseif field == "Credits" then
                table.insert(testFields, { name = "Кредитов", value = "20000", inline = true })
            elseif field == "Crystals" then
                table.insert(testFields, { name = "Кристаллов", value = "999", inline = true })
            elseif field == "Spent" then
                table.insert(testFields, { name = "Потрачено", value = "999", inline = false })
            elseif field == "Player" then
                table.insert(testFields, { name = "Игрок", value = Players.LocalPlayer.Name, inline = true })
            elseif field == "TotalCredits" then
                table.insert(testFields, { name = "Total Credits", value = "60000", inline = false })
            end
        end
        sendMatchWebhook(testFields)
        notifyUser("Webhook Test", "Test message sent!", 2)
    else
        notifyUser("Webhook Test", "Enable webhook and set URL first!", 3)
    end
end })

local UpdateTab = Window:AddTab({Title = "Update Log", Icon = "rbxassetid://15567843390" })
UpdateTab:AddSection("Version")
UpdateTab:AddParagraph({Title = "Version", Content = "2.6" })
UpdateTab:AddSection("Update Date")
UpdateTab:AddParagraph({Title = "Update Date", Content = "16.08.2026" })
UpdateTab:AddSection("What's New")
UpdateTab:AddParagraph({Title = "What's New v2.6", Content = "Added Visual Effects:\nAmbient Light, Atmosphere, Bloom,\nColor Correction, Sun Rays, FOV\nPlayer Aura, Character Trail,\nJump / Land Circle\nFixed Macros (Camera Lock + Walking)" })
UpdateTab:AddSection("Changelog")
UpdateTab:AddParagraph({Title = "Changelog", Content = [[
v2.6 (16.08.2026)
- Added Visual Effects: Ambient Light, Atmosphere, Bloom, Color Correction, Sun Rays, FOV
- Added Player Aura (particle rings around player)
- Added Character Trail
- Added Jump / Land Circle effects
- Fixed Macros (Camera Lock + Walking)
- Fixed Walk Preset detection on config load
- Fixed fireclickdetector compatibility
- Fixed AutoSave loop
- Added protection against duplicate execution

v2.5 (19.06.2026)
- Walk Settings presets dropdown
- Anti-duplicate GUI protection
- Server region with city name
- Safe bypassed module loading
- All functions have notifications
- Removed print statements

v2.4 (12.05.2026)
- Multi-select dropdown: Shiking + Walking
- Camera Lock separate toggle
- Walking (WASD + Jump) with settings

v2.3 (11.05.2026)
- Added Bypass Macros (Patched)
- Added Match Tracker with Win Streak
- Added Total Credits Counter
- Removed AutoRNG
- Removed Item Webhook

v2.2 (21.04.2026)

v2.1 (17.04.2026)
- Added Potato Graphics Mode
- Added Game Speed control
- Added Tower Boosts

v2.0
- Added Info section
- Added Show All Towers
]] })

local MacroRecorderTab = Window:AddTab({Title = "Macro Recorder", Icon = "rbxassetid://120674109076896"})

MacroRecorderTab:AddSection("Recording")

Macro.Count = MacroRecorderTab:AddParagraph({ Title = "Events", Content = "0" })
Macro.Status = MacroRecorderTab:AddParagraph({ Title = "Status", Content = "Ready.\n[ - record\n] - stop\n\\ - play / stop" })

MacroRecorderTab:AddButton({ Title = "Start Recording", Description = "[", Callback = function() Macro.StartRecording() end })
MacroRecorderTab:AddButton({ Title = "Stop Recording", Description = "]", Callback = function() Macro.StopRecording() end })
MacroRecorderTab:AddButton({ Title = "Play / Stop", Description = "\\", Callback = function()
    if Macro.Playing then Macro.Playing = false; Macro.SetStatus("Playback stopped.")
    else Macro.Play() end
end })

MacroRecorderTab:AddToggle("MacroLoopToggle", {
    Title = "Loop playback",
    Default = Settings.MacroLoop,
    Callback = function(v) Settings.MacroLoop = v; Macro.SaveSettings() end
})

MacroRecorderTab:AddButton({ Title = "Clear Macro", Callback = function()
    if Macro.Recording or Macro.Playing then return end
    Macro.Data = {}
    Macro.UpdateCount()
    Macro.SetStatus("Macro cleared.")
end })

MacroRecorderTab:AddSection("Save / Load")

local macroNameInput = ""
MacroRecorderTab:AddInput("MacroNameInput", {
    Title = "Macro Name",
    Placeholder = "e.g. bee swarm 1",
    Default = "",
    Callback = function(Text) macroNameInput = Text end
})

local macroSavedDropdown = MacroRecorderTab:AddDropdown("SavedMacros", {
    Title = "Saved Macros",
    Values = Macro.ListSaved(),
    Multi = false,
    Default = nil,
    Callback = function(opt) Macro.SelectedName = opt; Macro.RememberLast(opt) end
})

local function RefreshMacroDropdown()
    local list = Macro.ListSaved()
    pcall(function()
        macroSavedDropdown:SetValues(list)
        if Macro.SelectedName and table.find(list, Macro.SelectedName) then
            macroSavedDropdown:SetValue(Macro.SelectedName)
        end
    end)
end

MacroRecorderTab:AddButton({ Title = "Save", Callback = function()
    local name = macroNameInput ~= "" and macroNameInput or Macro.SelectedName
    if not name or name == "" then notifyUser("Macro Recorder", "Type a name first.", 2) return end
    if Macro.SaveNamed(name) then
        Macro.SelectedName = name
        Macro.RememberLast(name)
        RefreshMacroDropdown()
    end
end })

MacroRecorderTab:AddButton({ Title = "Load", Callback = function()
    if Macro.Recording or Macro.Playing then return end
    Macro.LoadNamed(Macro.SelectedName, false)
end })

MacroRecorderTab:AddButton({ Title = "Remove", Callback = function()
    if not Macro.SelectedName or Macro.SelectedName == "" then notifyUser("Macro Recorder", "No macro selected.", 2) return end
    Macro.RemoveNamed(Macro.SelectedName)
    Macro.SelectedName = nil
    Macro.RememberLast(nil)
    RefreshMacroDropdown()
end })

MacroRecorderTab:AddSection("Settings")

MacroRecorderTab:AddParagraph({ Title = "Keybinds", Content = "[ = toggle recording\n] = start / stop playback" })

MacroRecorderTab:AddToggle("MacroAutoLoadOnStart", {
    Title = "Auto-load macro on start",
    Description = "Loads the last saved macro automatically",
    Default = Settings.MacroAutoLoadOnStart,
    Callback = function(v) Settings.MacroAutoLoadOnStart = v; Macro.SaveSettings() end
})

MacroRecorderTab:AddSlider("MacroAutoLoadDelay", {
    Title = "Auto-load delay (s)",
    Min = 0, Max = 15, Rounding = 1,
    Default = Settings.MacroAutoLoadDelay,
    Callback = function(v) Settings.MacroAutoLoadDelay = tonumber(v) or 0; Macro.SaveSettings() end
})

MacroRecorderTab:AddToggle("MacroAutoStartPlayback", {
    Title = "Auto-start playback after load",
    Default = Settings.MacroAutoStartPlayback,
    Callback = function(v) Settings.MacroAutoStartPlayback = v; Macro.SaveSettings() end
})

MacroRecorderTab:AddSlider("MacroAutoStartDelay", {
    Title = "Auto-start delay (s)",
    Min = 0, Max = 15, Rounding = 1,
    Default = Settings.MacroAutoStartDelay,
    Callback = function(v) Settings.MacroAutoStartDelay = tonumber(v) or 0; Macro.SaveSettings() end
})

MacroRecorderTab:AddSection("Debug")

MacroRecorderTab:AddToggle("MacroDebugClicks", {
    Title = "Debug clicks in console",
    Default = Settings.MacroDebugClicks,
    Callback = function(v) Settings.MacroDebugClicks = v; Macro.SaveSettings() end
})

MacroRecorderTab:AddToggle("MacroCompensateInset", {
    Title = "Compensate top bar (GuiInset)",
    Description = "Enable if clicks are offset on Y axis",
    Default = Settings.MacroCompensateInset,
    Callback = function(v) Settings.MacroCompensateInset = v; Macro.SaveSettings() end
})

local CONFIG_FOLDER = "SkibidiConfigs"
local LAST_CONFIG_FILE = CONFIG_FOLDER.."/last.txt"
if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end

Settings.AutoSaveEnabled = false
Settings.AutoLoadEnabled = true

local function loadDefault()
    Settings.ShowAllTowers = false
    Settings.BlackMarket = false
    Settings.AntiMacro = false
    Settings.AntiAFK = false
    Settings.NotificationsEnabled = true
    Settings.InstantProxMount = false
    Settings.PotatoGraphics = false
    Settings.GameSpeed = 1
    Settings.SelectedBoostType = "DMG"
    Settings.WebhookEnabled = false
    Settings.WebhookURL = ""
    Settings.WebhookMatchTracking = false
    Settings.ShowLogInWebhook = true
    Settings.WebhookMatchFields = {"Result", "Streak", "Kills", "Survived", "Time", "Items", "Credits", "Crystals", "Spent", "Player", "TotalCredits"}
    Settings.MacroModes = {}
    Settings.WalkChance = 40
    Settings.JumpChance = 15
    Settings.MoveDurationMin = 0.8
    Settings.MoveDurationMax = 2.5
    Settings.PauseMin = 0.05
    Settings.PauseMax = 0.3
    pcall(function() Macro.LoadSettings() end)
    
    pcall(function() Toggle_InstantProxMount:SetValue(Settings.InstantProxMount) end)
    pcall(function() Toggle_AntiMacro:SetValue(Settings.AntiMacro) end)
    pcall(function() Toggle_WebhookEnabled:SetValue(Settings.WebhookEnabled) end)
    pcall(function() Toggle_ShowAllTowers:SetValue(Settings.ShowAllTowers) end)
    pcall(function() Toggle_BlackMarket:SetValue(Settings.BlackMarket) end)

    pcall(function() Toggle_NotificationsEnabled:SetValue(Settings.NotificationsEnabled) end)
    pcall(function() Toggle_PotatoGraphics:SetValue(Settings.PotatoGraphics) end)
    pcall(function() if Toggle_AutoRestoreCam then Toggle_AutoRestoreCam:SetValue(Settings.AutoRestoreCam) end end)
    pcall(function() if macroDropdown then macroDropdown:SetValue("None") end end)
    pcall(function() if walkPresetDropdown then walkPresetDropdown:SetValue("Medium") end end)
    pcall(function() if walkChanceSlider then walkChanceSlider:SetValue(Settings.WalkChance) end end)
    pcall(function() if jumpChanceSlider then jumpChanceSlider:SetValue(Settings.JumpChance) end end)
    pcall(function() if moveMinSlider then moveMinSlider:SetValue(Settings.MoveDurationMin) end end)
    pcall(function() if moveMaxSlider then moveMaxSlider:SetValue(Settings.MoveDurationMax) end end)
    pcall(function() if pauseMinSlider then pauseMinSlider:SetValue(Settings.PauseMin) end end)
    pcall(function() if pauseMaxSlider then pauseMaxSlider:SetValue(Settings.PauseMax) end end)
    pcall(function() if Toggle_AutoRestoreCam then Toggle_AutoRestoreCam:SetValue(Settings.AutoRestoreCam) end end)
    applyInstantProxMount("restore")
    savedPosition = nil
    savedCoordsText = "(None)"
    setButtonText(teleportButton, "Teleport to Position (None)")
    savedCamPos = nil
    savedCamText = "(None)"
    pcall(function() camTeleportButton:SetTitle("Save Camera Position (None)") end)
    updateMatchFieldsText()
    for _, field in ipairs(fieldsList) do
        if fieldToggles[field] then
            fieldToggles[field]:SetValue(true)
        end
    end

    pcall(function()
        LightingEffects.ResetAll()
        PlayerAura.SetEnabled(false)
        TrailEffect.SetEnabled(false)
        JumpCircle.SetJumpEnabled(false)
        JumpCircle.SetLandEnabled(false)
        FOVControl.Reset()
        VisualState = {
            Ambient = { enabled = false, color = "Purple" },
            Atmosphere = { enabled = false, color = "Purple", density = 0.3 },
            Bloom = { enabled = false, intensity = 1 },
            ColorCorrection = { enabled = false, saturation = 0, tint = "Normal" },
            SunRays = { enabled = false },
            FOV = math.floor(FOVControl.GetDefault()),
            Aura = { enabled = false, color = "Purple", count = 40, radius = 6 },
            Trail = { enabled = false, color = "Purple-Blue", lifetime = 0.5, width = 0.6 },
            JumpCircle = { enabled = false, land = false, color = "Purple" },
        }
        if VisualControls.AmbientToggle then VisualControls.AmbientToggle:SetValue(false) end
        if VisualControls.AtmosphereToggle then VisualControls.AtmosphereToggle:SetValue(false) end
        if VisualControls.BloomToggle then VisualControls.BloomToggle:SetValue(false) end
        if VisualControls.ColorCorrectionToggle then VisualControls.ColorCorrectionToggle:SetValue(false) end
        if VisualControls.SunRaysToggle then VisualControls.SunRaysToggle:SetValue(false) end
        if VisualControls.FOVSlider then VisualControls.FOVSlider:SetValue(VisualState.FOV) end
        if VisualControls.AuraToggle then VisualControls.AuraToggle:SetValue(false) end
        if VisualControls.TrailToggle then VisualControls.TrailToggle:SetValue(false) end
        if VisualControls.JumpCircleToggle then VisualControls.JumpCircleToggle:SetValue(false) end
        if VisualControls.LandCircleToggle then VisualControls.LandCircleToggle:SetValue(false) end
    end)
    pcall(function()
        Macro.Recording = false
        Macro.Playing = false
        Macro.HeldKeys.W = false
        Macro.HeldKeys.A = false
        Macro.HeldKeys.S = false
        Macro.HeldKeys.D = false
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:Move(Vector3.zero, false) end
        Macro.Data = {}
        Macro.UpdateCount()
        Macro.SetStatus("Ready.\n[ - record\n] - stop\n\\ - play / stop")
    end)
    pcall(function() Macro.SetupInput() end)
    pcall(function() Macro.StartMovement() end)
end

local function saveConfig(name)
    if not name or name == "" or name == "default" then return end
    local hrp = getHRP()
    local cam = workspace.CurrentCamera
    local data = {
        ShowAllTowers = Settings.ShowAllTowers,
        BlackMarket = Settings.BlackMarket,
        AntiMacro = Settings.AntiMacro,
        AntiAFK = Settings.AntiAFK,
        NotificationsEnabled = Settings.NotificationsEnabled,
        InstantProxMount = Settings.InstantProxMount,
        PotatoGraphics = Settings.PotatoGraphics,
        GameSpeed = Settings.GameSpeed,
        SelectedBoostType = Settings.SelectedBoostType,
        WebhookEnabled = Settings.WebhookEnabled,
        WebhookURL = Settings.WebhookURL,
        WebhookMatchTracking = Settings.WebhookMatchTracking,
        ShowLogInWebhook = Settings.ShowLogInWebhook,
        WebhookMatchFields = Settings.WebhookMatchFields,
        MacroModes = Settings.MacroModes,
        WalkChance = Settings.WalkChance,
        JumpChance = Settings.JumpChance,
        MoveDurationMin = Settings.MoveDurationMin,
        MoveDurationMax = Settings.MoveDurationMax,
        PauseMin = Settings.PauseMin,
        PauseMax = Settings.PauseMax,
        SavedPosition = hrp and { X = hrp.Position.X, Y = hrp.Position.Y, Z = hrp.Position.Z } or nil,
        SavedCamera = savedCamPos and { savedCamPos:GetComponents() } or nil,
        AutoRestoreCam = Settings.AutoRestoreCam,
        MacroLoop = Settings.MacroLoop,
        MacroCompensateInset = Settings.MacroCompensateInset,
        MacroDebugClicks = Settings.MacroDebugClicks,
        MacroAutoLoadOnStart = Settings.MacroAutoLoadOnStart,
        MacroAutoLoadDelay = Settings.MacroAutoLoadDelay,
        MacroAutoStartPlayback = Settings.MacroAutoStartPlayback,
        MacroAutoStartDelay = Settings.MacroAutoStartDelay,
        Visual = VisualState,
    }
    writefile(CONFIG_FOLDER.."/"..name..".json", HttpService:JSONEncode(data))
end

local function configExists(name)
    if isfile(CONFIG_FOLDER.."/"..name..".json") then return true end
    local ok, files = pcall(function() return listfiles(CONFIG_FOLDER) end)
    if ok and files then
        for _, file in ipairs(files) do
            if tostring(file):match("([^\\/]+)%.json$") == name then return true end
        end
    end
    return false
end

local function loadConfig(name)
    if name == "default" then loadDefault(); return true end
    local path = CONFIG_FOLDER.."/"..name..".json"
    if not configExists(name) then return false end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or not data then notifyUser("Config", "Failed to load config: " .. name, 3); return false end
    
    -- Безопасное копирование данных с проверками
    Settings.ShowAllTowers = data.ShowAllTowers or false
    Settings.BlackMarket = data.BlackMarket or false
    Settings.AntiMacro = data.AntiMacro or false
    Settings.AntiAFK = data.AntiAFK or false
    Settings.NotificationsEnabled = data.NotificationsEnabled ~= false
    Settings.InstantProxMount = data.InstantProxMount or false
    Settings.PotatoGraphics = data.PotatoGraphics or false
    Settings.GameSpeed = data.GameSpeed or 1
    Settings.SelectedBoostType = data.SelectedBoostType or "DMG"
    Settings.WebhookEnabled = data.WebhookEnabled or false
    Settings.WebhookURL = data.WebhookURL or ""
    Settings.WebhookMatchTracking = data.WebhookMatchTracking or false
    Settings.ShowLogInWebhook = data.ShowLogInWebhook ~= false
    
    -- Безопасное копирование списка
    Settings.WebhookMatchFields = {}
    if data.WebhookMatchFields and type(data.WebhookMatchFields) == "table" then
        for _, v in ipairs(data.WebhookMatchFields) do
            table.insert(Settings.WebhookMatchFields, v)
        end
    end
    if #Settings.WebhookMatchFields == 0 then
        Settings.WebhookMatchFields = {"Result", "Streak", "Kills", "Survived", "Time", "Items", "Credits", "Crystals", "Spent", "Player", "TotalCredits"}
    end
    
    Settings.MacroModes = data.MacroModes or {}
    Settings.WalkChance = data.WalkChance or 40
    Settings.JumpChance = data.JumpChance or 15
    Settings.MoveDurationMin = data.MoveDurationMin or 0.8
    Settings.MoveDurationMax = data.MoveDurationMax or 2.5
    Settings.PauseMin = data.PauseMin or 0.05
    Settings.PauseMax = data.PauseMax or 0.3
    Settings.MacroLoop = data.MacroLoop or false
    Settings.MacroCompensateInset = data.MacroCompensateInset or false
    Settings.MacroDebugClicks = data.MacroDebugClicks ~= false
    pcall(function() Macro.LoadSettings() end)

    pcall(function() Toggle_ShowAllTowers:SetValue(Settings.ShowAllTowers) end)
    pcall(function() Toggle_BlackMarket:SetValue(Settings.BlackMarket) end)
    pcall(function() Toggle_AntiMacro:SetValue(Settings.AntiMacro) end)
    pcall(function() Toggle_NotificationsEnabled:SetValue(Settings.NotificationsEnabled) end)
    pcall(function() Toggle_InstantProxMount:SetValue(Settings.InstantProxMount) end)
    pcall(function() Toggle_PotatoGraphics:SetValue(Settings.PotatoGraphics) end)
    pcall(function() Toggle_WebhookEnabled:SetValue(Settings.WebhookEnabled) end)
    
    pcall(function()
        if macroDropdown then
            local opt = "None"
            if hasMacroMode("Shiking") and hasMacroMode("Walking") then
                opt = "Shiking + Walking"
            elseif hasMacroMode("Shiking") then
                opt = "Shiking"
            elseif hasMacroMode("Walking") then
                opt = "Walking"
            end
            macroDropdown:SetValue(opt)
        end
    end)
    
    pcall(function()
        if walkPresetDropdown then
            local preset = "Custom"
            if Settings.WalkChance == 40 and Settings.JumpChance == 15 and Settings.MoveDurationMin == 0.8 and Settings.MoveDurationMax == 2.5 and Settings.PauseMin == 0.05 and Settings.PauseMax == 0.3 then preset = "Medium"
            elseif Settings.WalkChance == 25 and Settings.JumpChance == 10 then preset = "Slow"
            elseif Settings.WalkChance == 60 and Settings.JumpChance == 25 then preset = "Fast"
            end
            walkPresetDropdown:SetValue(preset)
        end
    end)
    pcall(function() if walkChanceSlider then walkChanceSlider:SetValue(Settings.WalkChance) end end)
    pcall(function() if jumpChanceSlider then jumpChanceSlider:SetValue(Settings.JumpChance) end end)
    pcall(function() if moveMinSlider then moveMinSlider:SetValue(Settings.MoveDurationMin) end end)
    pcall(function() if moveMaxSlider then moveMaxSlider:SetValue(Settings.MoveDurationMax) end end)
    pcall(function() if pauseMinSlider then pauseMinSlider:SetValue(Settings.PauseMin) end end)
    pcall(function() if pauseMaxSlider then pauseMaxSlider:SetValue(Settings.PauseMax) end end)
    
    pcall(function() if Settings.InstantProxMount then applyInstantProxMount("set") else applyInstantProxMount("restore") end end)
    pcall(function() stopShowAllTowers(); if Settings.ShowAllTowers then startShowAllTowers() end end)
    pcall(function() if Settings.BlackMarket then startBlackMarket() else stopBlackMarket() end end)

    pcall(function() if Settings.AntiAFK then startAntiAFK() end end)
    pcall(function() if Settings.PotatoGraphics then enablePotatoGraphics() else disablePotatoGraphics() end end)
    pcall(function() if Settings.WebhookMatchTracking then startMatchTracking() else stopMatchTracking() end end)
    pcall(function() if SpeedSlider then SpeedSlider:SetValue(Settings.GameSpeed) end end)
    
    pcall(function()
        updateMatchFieldsText()
        for _, field in ipairs(fieldsList) do
            if fieldToggles[field] then
                fieldToggles[field]:SetValue(table.find(Settings.WebhookMatchFields, field) ~= nil)
            end
        end
    end)
    
    if data.SavedPosition then
        savedPosition = CFrame.new(data.SavedPosition.X, data.SavedPosition.Y, data.SavedPosition.Z)
        local x,y,z = math.floor(data.SavedPosition.X), math.floor(data.SavedPosition.Y), math.floor(data.SavedPosition.Z)
        pcall(function() setButtonText(teleportButton, "Teleport to Position ("..x..","..y..","..z..")") end)
    else
        savedPosition = nil
        pcall(function() setButtonText(teleportButton, "Teleport to Position (None)") end)
    end

    if data.SavedCamera then
        savedCamPos = CFrame.new(table.unpack(data.SavedCamera))
        local x,y,z = math.floor(savedCamPos.Position.X), math.floor(savedCamPos.Position.Y), math.floor(savedCamPos.Position.Z)
        pcall(function() camTeleportButton:SetTitle("Save Camera Position ("..x..","..y..","..z..")") end)
    else
        savedCamPos = nil
        pcall(function() camTeleportButton:SetTitle("Save Camera Position (None)") end)
    end

    pcall(function()
        local cam = workspace.CurrentCamera
        if savedCamPos and cam then
            cam.CFrame = savedCamPos
            if camConn then lockedCF = savedCamPos end
        end
    end)

    if data.AutoRestoreCam ~= nil then Settings.AutoRestoreCam = data.AutoRestoreCam end

    if data.Visual then
        pcall(function()
            local v = data.Visual
            if v.Ambient then
                VisualState.Ambient.enabled = v.Ambient.enabled or false
                VisualState.Ambient.color = v.Ambient.color or "Purple"
                if VisualControls.AmbientColorDropdown then VisualControls.AmbientColorDropdown:SetValue(VisualState.Ambient.color) end
                if VisualControls.AmbientToggle then VisualControls.AmbientToggle:SetValue(VisualState.Ambient.enabled) end
            end
            if v.Atmosphere then
                VisualState.Atmosphere.enabled = v.Atmosphere.enabled or false
                VisualState.Atmosphere.color = v.Atmosphere.color or "Purple"
                VisualState.Atmosphere.density = v.Atmosphere.density or 0.3
                if VisualControls.AtmosphereColorDropdown then VisualControls.AtmosphereColorDropdown:SetValue(VisualState.Atmosphere.color) end
                if VisualControls.AtmosphereDensity then VisualControls.AtmosphereDensity:SetValue(VisualState.Atmosphere.density) end
                if VisualControls.AtmosphereToggle then VisualControls.AtmosphereToggle:SetValue(VisualState.Atmosphere.enabled) end
            end
            if v.Bloom then
                VisualState.Bloom.enabled = v.Bloom.enabled or false
                VisualState.Bloom.intensity = v.Bloom.intensity or 1
                if VisualControls.BloomIntensity then VisualControls.BloomIntensity:SetValue(VisualState.Bloom.intensity) end
                if VisualControls.BloomToggle then VisualControls.BloomToggle:SetValue(VisualState.Bloom.enabled) end
            end
            if v.ColorCorrection then
                VisualState.ColorCorrection.enabled = v.ColorCorrection.enabled or false
                VisualState.ColorCorrection.saturation = v.ColorCorrection.saturation or 0
                VisualState.ColorCorrection.tint = v.ColorCorrection.tint or "Normal"
                if VisualControls.Saturation then VisualControls.Saturation:SetValue(VisualState.ColorCorrection.saturation) end
                if VisualControls.TintDropdown then VisualControls.TintDropdown:SetValue(VisualState.ColorCorrection.tint) end
                if VisualControls.ColorCorrectionToggle then VisualControls.ColorCorrectionToggle:SetValue(VisualState.ColorCorrection.enabled) end
            end
            if v.SunRays then
                VisualState.SunRays.enabled = v.SunRays.enabled or false
                if VisualControls.SunRaysToggle then VisualControls.SunRaysToggle:SetValue(VisualState.SunRays.enabled) end
            end
            if v.FOV then
                VisualState.FOV = v.FOV
                if VisualControls.FOVSlider then VisualControls.FOVSlider:SetValue(VisualState.FOV) end
            end
            if v.Aura then
                VisualState.Aura.enabled = v.Aura.enabled or false
                VisualState.Aura.color = v.Aura.color or "Purple"
                VisualState.Aura.count = v.Aura.count or 40
                VisualState.Aura.radius = v.Aura.radius or 6
                if VisualControls.AuraColorDropdown then VisualControls.AuraColorDropdown:SetValue(VisualState.Aura.color) end
                if VisualControls.AuraCount then VisualControls.AuraCount:SetValue(VisualState.Aura.count) end
                if VisualControls.AuraRadius then VisualControls.AuraRadius:SetValue(VisualState.Aura.radius) end
                if VisualControls.AuraToggle then VisualControls.AuraToggle:SetValue(VisualState.Aura.enabled) end
            end
            if v.Trail then
                VisualState.Trail.enabled = v.Trail.enabled or false
                VisualState.Trail.color = v.Trail.color or "Purple-Blue"
                VisualState.Trail.lifetime = v.Trail.lifetime or 0.5
                VisualState.Trail.width = v.Trail.width or 0.6
                if VisualControls.TrailColorDropdown then VisualControls.TrailColorDropdown:SetValue(VisualState.Trail.color) end
                if VisualControls.TrailLifetime then VisualControls.TrailLifetime:SetValue(VisualState.Trail.lifetime) end
                if VisualControls.TrailWidth then VisualControls.TrailWidth:SetValue(VisualState.Trail.width) end
                if VisualControls.TrailToggle then VisualControls.TrailToggle:SetValue(VisualState.Trail.enabled) end
            end
            if v.JumpCircle then
                VisualState.JumpCircle.enabled = v.JumpCircle.enabled or false
                VisualState.JumpCircle.land = v.JumpCircle.land or false
                VisualState.JumpCircle.color = v.JumpCircle.color or "Purple"
                if VisualControls.JumpCircleColorDropdown then VisualControls.JumpCircleColorDropdown:SetValue(VisualState.JumpCircle.color) end
                if VisualControls.LandCircleToggle then VisualControls.LandCircleToggle:SetValue(VisualState.JumpCircle.land) end
                if VisualControls.JumpCircleToggle then VisualControls.JumpCircleToggle:SetValue(VisualState.JumpCircle.enabled) end
            end
        end)
    end
    return true
end

local function rememberLastConfig(name)
    if name and name ~= "" and name ~= "default" then
        pcall(function() writefile(LAST_CONFIG_FILE, name) end)
    end
end

local function AutoSave()
    if currentConfig ~= "default" then
        if Settings.AutoSaveEnabled then saveConfig(currentConfig) end
        rememberLastConfig(currentConfig)
    end
end

local function AutoLoad()
    if not Settings.AutoLoadEnabled then return end
    if isfile(LAST_CONFIG_FILE) then
        local last = readfile(LAST_CONFIG_FILE)
        if last and last ~= "" then
            local ok, result = pcall(function() return loadConfig(last) end)
            if ok and result then
                currentConfig = last
                return
            end
        end
    end
    currentConfig = "default"
    loadConfig("default")
end

local ConfigTab = Window:AddTab({Title = "Config", Icon = "rbxassetid://11956055886" })
local selectedLabel = ConfigTab:AddParagraph({Title = "Selected Config", Content = "default" })
local function updateSelected() pcall(function() selectedLabel:SetDesc(currentConfig) end) end

local configDropdown = ConfigTab:AddDropdown("Configs", {
    Title = "Configs",
    Values = {"default"},
    Default = "default",
    Callback = function(opt) currentConfig = opt; rememberLastConfig(opt); updateSelected(); loadConfig(currentConfig) end 
})

local function refreshDropdown()
    local map = { ["default"] = true }
    local ok, files = pcall(function() return listfiles(CONFIG_FOLDER) end)
    if ok and files then for _, file in ipairs(files) do local name = tostring(file):match("([^\\/]+)%.json$"); if name then map[name] = true end end end
    local list = {}; for name,_ in pairs(map) do table.insert(list, name) end
    table.sort(list, function(a,b) if a=="default" then return true end; if b=="default" then return false end; return a<b end)
    configDropdown:SetValues(list)
    if currentConfig then configDropdown:SetValue(currentConfig) end
end
refreshDropdown()

local inputName = ""
ConfigTab:AddInput("ConfigName", {Title = "Config Name", Placeholder = "Enter name...", Default = "", Callback = function(text) inputName = text end })
ConfigTab:AddButton({Title ="Create", Callback = function() if inputName=="" or inputName=="default" then return end; currentConfig = inputName; rememberLastConfig(inputName); if not isfile(CONFIG_FOLDER.."/"..inputName..".json") then saveConfig(inputName) end; refreshDropdown(); updateSelected() end })
ConfigTab:AddButton({Title ="Save", Callback = function() if not currentConfig then return end; saveConfig(currentConfig); AutoSave(); refreshDropdown() end })
ConfigTab:AddButton({Title ="Load", Callback = function() if not currentConfig then return end; loadConfig(currentConfig) end })
ConfigTab:AddButton({Title ="Delete", Callback = function() if currentConfig=="default" then return end; local path = CONFIG_FOLDER.."/"..currentConfig..".json"; if isfile(path) then delfile(path) end; if isfile(LAST_CONFIG_FILE) and readfile(LAST_CONFIG_FILE) == currentConfig then delfile(LAST_CONFIG_FILE) end; currentConfig="default"; loadDefault(); refreshDropdown(); updateSelected() end })
ConfigTab:AddToggle("AutoLoad", {Title = "Auto Load", Default = Settings.AutoLoadEnabled, Callback = function(v) Settings.AutoLoadEnabled=v; if Settings.AutoSaveEnabled and currentConfig ~= "default" then saveConfig(currentConfig) end end })
ConfigTab:AddToggle("AutoSave", {Title = "Auto Save", Default = Settings.AutoSaveEnabled, Callback = function(v) Settings.AutoSaveEnabled=v; if v and currentConfig ~= "default" then saveConfig(currentConfig) end end })

task.spawn(function()
    task.wait(1)
    AutoLoad()
    updateSelected()
    refreshDropdown()
    task.wait(1)
    pcall(function()
        if Settings.AutoRestoreCam and savedCamPos and workspace.CurrentCamera then
            workspace.CurrentCamera.CFrame = savedCamPos
            if camConn and Settings.AntiMacro then lockedCF = savedCamPos end
        end
    end)
end)

-- Исправленный AutoSave цикл
task.spawn(function() 
    while autoSaveRunning do 
        task.wait(20) 
        AutoSave() 
    end 
end)

notifyUser("Skibidi Defense", "v2.6 loaded! (Fluent UI)", 3)
print("[Loader] Skibidi Defense v2.6 loaded successfully!")

pcall(function() Window:SelectTab(1) end)

-- Macro Recorder: restore last selected and auto-load
task.spawn(function()
    task.wait(2)
    local rememberedName = Macro.GetLastSelected()
    if rememberedName then
        Macro.SelectedName = rememberedName
        pcall(function()
            local list = Macro.ListSaved()
            macroSavedDropdown:SetValues(list)
            if table.find(list, rememberedName) then
                macroSavedDropdown:SetValue(rememberedName)
            end
        end)
    end
    if Settings.MacroAutoLoadOnStart then
        local delay = tonumber(Settings.MacroAutoLoadDelay) or 0
        if delay > 0 then task.wait(delay) end
        Macro.LoadNamed(Macro.SelectedName, true)
    end
    if Settings.MacroAutoStartPlayback then
        local delay = tonumber(Settings.MacroAutoStartDelay) or 0
        if delay > 0 then task.wait(delay) end
        Macro.Play()
    end
end)

-- Проверка fireclickdetector
pcall(function()
    if type(fireclickdetector) ~= "function" then
        notifyUser("Macro Recorder", "fireclickdetector not available. ClickDetector clicks won't work.", 6)
    end
end)
