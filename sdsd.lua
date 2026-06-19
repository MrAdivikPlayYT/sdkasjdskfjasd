repeat task.wait() until game:IsLoaded()

local function decrypt(s)
    local r=""
    for i=1,#s do
        r=r..string.char(string.byte(s,i)-3)
    end
    return r
end

local allowed=false
for _,v in ipairs({"6:8884<59<", "636;6635:", "5363<54474", "67::79;3;4", "443676<;39", "43;39638:53", "43;564599::", "4434494<498"}) do
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

if _G.SkibidiGUI then pcall(function() _G.SkibidiGUI:Destroy() end) end
if getgenv and getgenv().SkibidiGUI then pcall(function() getgenv().SkibidiGUI:Destroy() end) end
pcall(function()
    local oldBlur = Lighting:FindFirstChild("MenuBlur")
    if oldBlur then oldBlur:Destroy() end
end)

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local Fluent = nil
local loadSuccess, loadErr = pcall(function()
    Fluent = loadstring(game:HttpGet("https://github.com/1dontgiveaf/Fluent/releases/latest/download/main.lua"))()
end)
if not loadSuccess or not Fluent then
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Skibidi Defense",
            Text = "Failed to load UI module. Retrying...",
            Duration = 5
        })
    end)
    task.wait(2)
    Fluent = loadstring(game:HttpGet("https://github.com/1dontgiveaf/Fluent/releases/latest/download/main.lua"))()
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

local Settings = {
    ShowAllTowers = false,
    BlackMarket = false,
    RNG = false,
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
    local player = game.Players.LocalPlayer
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
    
    local player = game.Players.LocalPlayer
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
            name = "📡 Log",
            value = darkCode(timeNow),
            inline = false
        })
    end
    
    local data = {
        username = "Skibidi Defense Match Tracker",
        avatar_url = "https://cdn.discordapp.com/embed/avatars/0.png",
        embeds = {{
            author = { name = "Skibidi Defense Script", icon_url = "https://cdn.discordapp.com/embed/avatars/0.png" },
            title = "🚀 Skibidi Defense (Private)",
            color = 65280,
            fields = fields,
            footer = { text = "Нажми на значение чтобы скопировать" }
        }}
    }
    
    local json = game:GetService("HttpService"):JSONEncode(data)
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
            fields[#fields+1] = { name = "🎯 Результат", value = result, inline = false }
        elseif field == "Streak" then
            fields[#fields+1] = { name = "📊 Win Streak", value = tostring(winStreak), inline = true }
        elseif field == "Kills" then
            fields[#fields+1] = { name = "⚔️ Убийств", value = stats.kills, inline = true }
        elseif field == "Survived" then
            fields[#fields+1] = { name = "🛡️ Выжил", value = stats.survived, inline = true }
        elseif field == "Time" then
            fields[#fields+1] = { name = "⏱️ Время", value = stats.timeelapsed, inline = true }
        elseif field == "Items" then
            fields[#fields+1] = { name = "🎁 Предметов", value = stats.items, inline = true }
        elseif field == "Credits" then
            fields[#fields+1] = { name = "💰 Кредитов", value = stats.credits, inline = true }
        elseif field == "Crystals" then
            fields[#fields+1] = { name = "💎 Кристаллов", value = stats.crystals, inline = true }
        elseif field == "Spent" then
            fields[#fields+1] = { name = "💸 Потрачено", value = stats.spent, inline = false }
        elseif field == "Player" then
            fields[#fields+1] = { name = "👤 Игрок", value = game.Players.LocalPlayer.Name, inline = true }
        elseif field == "TotalCredits" then
            fields[#fields+1] = { name = "💰 Total Credits", value = formatNumber(totalCredits), inline = false }
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
        local player = game.Players.LocalPlayer
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
        local player = game.Players.LocalPlayer
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
        local player = game.Players.LocalPlayer
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return end
        local sg = pg:FindFirstChild("BLACKMARKET")
        if not sg then return end
        sg.Enabled = false
        local main = sg:FindFirstChild("Main")
        if main then main.Visible = false end
    end)
end

local rngConnection = nil
local function showRNG()
    pcall(function()
        local player = game.Players.LocalPlayer
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return end
        local rng = pg:FindFirstChild("RNG")
        if not rng then return end
        rng.Enabled = true
        local roll = rng:FindFirstChild("Roll")
        if roll then roll.Position = UDim2.new(roll.Position.X.Scale, roll.Position.X.Offset, 0, 820) end
        local rollSpeed = rng:FindFirstChild("RollSpeed")
        if rollSpeed then rollSpeed.Position = UDim2.new(rollSpeed.Position.X.Scale, rollSpeed.Position.X.Offset, 0, 820) end
        local auto = rng:FindFirstChild("Auto")
        if auto then auto.Position = UDim2.new(auto.Position.X.Scale, auto.Position.X.Offset, 0, 820) end
        local swap = rng:FindFirstChild("Swap")
        if swap then swap.Visible = false end
        local warning = rng:FindFirstChild("Warning")
        if warning then warning.Visible = false end
    end)
end

local function startRNG()
    if rngConnection then return end
    showRNG()
    rngConnection = RunService.Stepped:Connect(function()
        if Settings.RNG then showRNG() end
    end)
end

local function stopRNG()
    if rngConnection then rngConnection:Disconnect(); rngConnection = nil end
    pcall(function()
        local player = game.Players.LocalPlayer
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return end
        local rng = pg:FindFirstChild("RNG")
        if not rng then return end
        rng.Enabled = false
        local roll = rng:FindFirstChild("Roll")
        if roll then roll.Position = UDim2.new(roll.Position.X.Scale, roll.Position.X.Offset, 0, 923) end
        local rollSpeed = rng:FindFirstChild("RollSpeed")
        if rollSpeed then rollSpeed.Position = UDim2.new(rollSpeed.Position.X.Scale, rollSpeed.Position.X.Offset, 0, 923) end
        local auto = rng:FindFirstChild("Auto")
        if auto then auto.Position = UDim2.new(auto.Position.X.Scale, auto.Position.X.Offset, 0, 923) end
        local swap = rng:FindFirstChild("Swap")
        if swap then swap.Visible = true end
        local warning = rng:FindFirstChild("Warning")
        if warning then warning.Visible = true end
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

local function walkLoop()
    while walkRunning do
        if not table.find(Settings.MacroModes, "Walking") then
            task.wait(1)
            releaseWalkKeys()
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
            for _, k in ipairs(d) do releaseWalkKey(k) end
        else
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

local Window = Fluent:CreateWindow({
    Title = "Skibidi Defense Script (Private)",
    SubTitle = "v2.5",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
    LoadingTitle = "Skibidi Defense Script",
    LoadingSubtitle = "Loading v2.5..."
})

if getgenv then getgenv().SkibidiGUI = Window end
_G.SkibidiGUI = Window

local MainTab = Window:AddTab({Title = "Main", Icon = "rbxassetid://120674109076896" })

MainTab:AddSection("Info")

local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

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

local function getServerRegion()
    if cachedRegion then return cachedRegion end
    local region = "Unknown"
    local apis = {
        "https://ipapi.co/json/",
        "https://ipinfo.io/json",
        "https://api.ipify.org?format=json"
    }
    for _, url in ipairs(apis) do
        pcall(function()
            local resp = game:HttpGet(url)
            if resp and resp ~= "" then
                local data = HttpService:JSONDecode(resp)
                if data then
                    local city = data.city or data.locality or ""
                    local country = data.country_name or data.country or ""
                    local ip = data.ip or ""
                    if city ~= "" and country ~= "" then
                        region = country .. ", " .. city
                    elseif country ~= "" then
                        region = country
                    elseif ip ~= "" then
                        region = "IP: " .. ip
                    end
                end
            end
        end)
        if region ~= "Unknown" then break end
    end
    cachedRegion = region
    return region
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
        local serverRegion = getServerRegion()
        local serverInfo = getServerInfo()
        pcall(function()
            infoParagraph:SetTitle("📊 Stats")
            infoParagraph:SetDesc(string.format("⏱️ UpTime: %s\n🕐 Time: %s\n🌍 Region: %s\n🖥️ Server: %s\n📡 Ping: %sms\n🎮 FPS: %d", formatTime(uptime), serverTime, serverRegion, serverInfo, pingText, fps))
        end)
        task.wait(1)
    end
end)

MainTab:AddSection("Lobby")

local isOpen = false
local cachedGUI = nil

local function findWarlordSignGUI()
    if cachedGUI then return cachedGUI end
    cachedGUI = {}
    local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    for _, gui in ipairs(playerGui:GetChildren()) do
        local name = string.lower(gui.Name)
        if gui:IsA("ScreenGui") and (name:find("warlord") or name:find("versus")) then
            table.insert(cachedGUI, gui)
        end
    end
    return cachedGUI
end

local WarlordButton = MainTab:AddButton({Title = "Warlord Sign Gui", Callback = function() isOpen = not isOpen; for _, gui in ipairs(findWarlordSignGUI()) do gui.Enabled = isOpen end; notifyUser("Warlord Sign", isOpen and "Enabled" or "Disabled", 2) end })

MainTab:AddButton({Title ="Bypass Jeffry", Callback = function() for _, obj in ipairs(game:GetDescendants()) do if obj:IsA("NumberValue") and obj.Name == "THE DARKNESS" then obj:Destroy(); break end end; notifyUser("Bypass Jeffry", "THE DARKNESS removed", 2) end })

local Toggle_ShowAllTowers = MainTab:AddToggle("Toggle_ShowAllTowers", {Title = "Show All Towers", Default = Settings.ShowAllTowers, Callback = function(v) Settings.ShowAllTowers = v; if v then startShowAllTowers(); notifyUser("Show All Towers", "Enabled - All towers are visible", 2) else stopShowAllTowers(); notifyUser("Show All Towers", "Disabled - Towers restored", 2) end end })

MainTab:AddSection("Trading Plaza")

MainTab:AddButton({Title ="Teleport in Tower", Callback = function() pcall(function() local hrp = game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if hrp then hrp.CFrame = CFrame.new(-2, 465, 433); notifyUser("Teleport", "In Tower", 2) end end) end })

MainTab:AddButton({Title ="Teleport in Yourself Quest", Callback = function() pcall(function() local hrp = game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if hrp then hrp.CFrame = CFrame.new(10, 1736, -339); notifyUser("Teleport", "Yourself Quest", 2) end end) end })

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

local Toggle_RNG = MainTab:AddToggle("RNGToggle", {Title = "Show RNG in Plaza", Default = Settings.RNG, Callback = function(v)
    Settings.RNG = v
    if v then
        startRNG()
        notifyUser("RNG", "Enabled", 2)
    else
        stopRNG()
        notifyUser("RNG", "Disabled", 2)
    end
end })

local function getHRP()
    local c = game.Players.LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local camConn = nil
local lockedCF = nil
local function getShakeOffset()
    local offsets = {0.03, 0.05, 0.08, 0.1, 0.12}
    local x = offsets[math.random(1,#offsets)]
    local y = offsets[math.random(1,#offsets)]
    x = x * (math.random(0,1) == 1 and 1 or -1)
    y = y * (math.random(0,1) == 1 and 1 or -1)
    return x, y
end

local function disableAntiMacroScripts()
    local player = game.Players.LocalPlayer
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
    lockedCF = cam.CFrame
    cam.CameraType = Enum.CameraType.Scriptable
    camConn = RunService.RenderStepped:Connect(function()
        if not Settings.AntiMacro then return end
        if not lockedCF then return end
        local cf = lockedCF
        if table.find(Settings.MacroModes, "Shiking") then
            local x, y = getShakeOffset()
            cf = cf * CFrame.new(x, y, 0)
        end
        cam.CFrame = cf
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
        if table.find(Settings.MacroModes, "Walking") then startWalkMacro() end
        notifyUser("Camera Lock", "ON", 2)
    else
        stopAntiMacro()
        stopWalkMacro()
        notifyUser("Camera Lock", "OFF", 2)
    end
end })

local currentMacroOption = "None"
if table.find(Settings.MacroModes, "Shiking") and table.find(Settings.MacroModes, "Walking") then
    currentMacroOption = "Shiking + Walking"
elseif table.find(Settings.MacroModes, "Shiking") then
    currentMacroOption = "Shiking"
elseif table.find(Settings.MacroModes, "Walking") then
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
        
        local hasWalking = table.find(Settings.MacroModes, "Walking")
        local parts = {}
        if table.find(Settings.MacroModes, "Shiking") then table.insert(parts, "Shiking") end
        if hasWalking then startWalkMacro(); table.insert(parts, "Walking") else stopWalkMacro() end
        
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

MainTab:AddSection("Teleports")

MainTab:AddButton({Title ="Lobby", Callback = function() pcall(function() game:GetService("TeleportService"):Teleport(14279693118, game.Players.LocalPlayer); notifyUser("Teleport", "To Lobby", 2) end) end })

MainTab:AddButton({Title ="Trading Plaza", Callback = function() pcall(function() game:GetService("TeleportService"):Teleport(18711550363, game.Players.LocalPlayer); notifyUser("Teleport", "To Trading Plaza", 2) end) end })

MainTab:AddButton({Title ="HappyBirtchDay", Callback = function() pcall(function() game:GetService("TeleportService"):Teleport(93311267472350, game.Players.LocalPlayer); notifyUser("Teleport", "To HappyBirtchDay", 2) end) end })

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
OtherTab:AddButton({Title ="Rejoin", Callback = function() notifyUser("Rejoin", "Rejoining server...", 2); task.wait(1); game:GetService("TeleportService"):Teleport(game.PlaceId, game.Players.LocalPlayer) end })
OtherTab:AddButton({Title ="Infinite Yield", Callback = function() loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))(); notifyUser("Infinite Yield", "Loaded!", 2) end })

local serverHopActive = false
local serverHopConnection = nil

local function destroyServerHopUI()
    pcall(function()
        local playerGui = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
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
        if getgenv().ServerHop then getgenv().ServerHop = nil end
        if _G.ServerHopUI then _G.ServerHopUI = nil end
        if getgenv().ServerHopUI then getgenv().ServerHopUI = nil end
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
    local player = game.Players.LocalPlayer
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

OtherTab:AddSection("Settings")

local Toggle_NotificationsEnabled = OtherTab:AddToggle("Toggle_NotificationsEnabled", {Title = "Show Notifications", Default = Settings.NotificationsEnabled, Callback = function(v) Settings.NotificationsEnabled = v; notifyUser("Notifications", v and "Enabled" or "Disabled", 2) end })



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
                table.insert(testFields, { name = "🎯 Результат", value = "ТЕСТ", inline = false })
            elseif field == "Streak" then
                table.insert(testFields, { name = "📊 Win Streak", value = "3", inline = true })
            elseif field == "Kills" then
                table.insert(testFields, { name = "⚔️ Убийств", value = "999", inline = true })
            elseif field == "Survived" then
                table.insert(testFields, { name = "🛡️ Выжил", value = "25", inline = true })
            elseif field == "Time" then
                table.insert(testFields, { name = "⏱️ Время", value = "12:34", inline = true })
            elseif field == "Items" then
                table.insert(testFields, { name = "🎁 Предметов", value = "99", inline = true })
            elseif field == "Credits" then
                table.insert(testFields, { name = "💰 Кредитов", value = "20000", inline = true })
            elseif field == "Crystals" then
                table.insert(testFields, { name = "💎 Кристаллов", value = "999", inline = true })
            elseif field == "Spent" then
                table.insert(testFields, { name = "💸 Потрачено", value = "999", inline = false })
            elseif field == "Player" then
                table.insert(testFields, { name = "👤 Игрок", value = game.Players.LocalPlayer.Name, inline = true })
            elseif field == "TotalCredits" then
                table.insert(testFields, { name = "💰 Total Credits", value = "60000", inline = false })
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
UpdateTab:AddParagraph({Title = "Version", Content = "2.5" })
UpdateTab:AddSection("Update Date")
UpdateTab:AddParagraph({Title = "Update Date", Content = "19.06.2026" })
UpdateTab:AddSection("What's New")
UpdateTab:AddParagraph({Title = "What's New v2.5", Content = "Walk Settings presets (None/Slow/Medium/Fast/Custom)\nAnti-duplicate GUI protection\nServer region with city\nSafe module loading\nAll functions have notifications" })
UpdateTab:AddSection("Changelog")
UpdateTab:AddParagraph({Title = "Changelog", Content = [[
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
- Added Show RNG In Plaza

v2.1 (17.04.2026)
- Added Potato Graphics Mode
- Added Game Speed control
- Added Tower Boosts

v2.0
- Added Info section
- Added Show All Towers
]] })

local CONFIG_FOLDER = "SkibidiConfigs"
local LAST_CONFIG_FILE = CONFIG_FOLDER.."/last.txt"
if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end

Settings.AutoSaveEnabled = false
Settings.AutoLoadEnabled = true

local function loadDefault()
    Settings.ShowAllTowers = false
    Settings.BlackMarket = false
    Settings.RNG = false
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
    
    pcall(function() Toggle_InstantProxMount:SetValue(Settings.InstantProxMount) end)
    pcall(function() Toggle_AntiMacro:SetValue(Settings.AntiMacro) end)
    pcall(function() Toggle_WebhookEnabled:SetValue(Settings.WebhookEnabled) end)
    pcall(function() Toggle_ShowAllTowers:SetValue(Settings.ShowAllTowers) end)
    pcall(function() Toggle_BlackMarket:SetValue(Settings.BlackMarket) end)
    pcall(function() Toggle_RNG:SetValue(Settings.RNG) end)
    pcall(function() Toggle_NotificationsEnabled:SetValue(Settings.NotificationsEnabled) end)
    pcall(function() Toggle_PotatoGraphics:SetValue(Settings.PotatoGraphics) end)
    pcall(function() if macroDropdown then macroDropdown:SetValue("None") end end)
    pcall(function() if walkPresetDropdown then walkPresetDropdown:SetValue("Medium") end end)
    pcall(function() if walkChanceSlider then walkChanceSlider:SetValue(Settings.WalkChance) end end)
    pcall(function() if jumpChanceSlider then jumpChanceSlider:SetValue(Settings.JumpChance) end end)
    pcall(function() if moveMinSlider then moveMinSlider:SetValue(Settings.MoveDurationMin) end end)
    pcall(function() if moveMaxSlider then moveMaxSlider:SetValue(Settings.MoveDurationMax) end end)
    pcall(function() if pauseMinSlider then pauseMinSlider:SetValue(Settings.PauseMin) end end)
    pcall(function() if pauseMaxSlider then pauseMaxSlider:SetValue(Settings.PauseMax) end end)
    applyInstantProxMount("restore")
    savedPosition = nil
    savedCoordsText = "(None)"
    setButtonText(teleportButton, "Teleport to Position (None)")
    updateMatchFieldsText()
    for _, field in ipairs(fieldsList) do
        if fieldToggles[field] then
            fieldToggles[field]:SetValue(true)
        end
    end
end

local function saveConfig(name)
    if not name or name == "" or name == "default" then return end
    local hrp = getHRP()
    local data = {
        ShowAllTowers = Settings.ShowAllTowers,
        BlackMarket = Settings.BlackMarket,
        RNG = Settings.RNG,
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
        SavedPosition = hrp and { X = hrp.Position.X, Y = hrp.Position.Y, Z = hrp.Position.Z } or nil
    }
    writefile(CONFIG_FOLDER.."/"..name..".json", HttpService:JSONEncode(data))
end

local function loadConfig(name)
    if name == "default" then loadDefault(); return end
    local path = CONFIG_FOLDER.."/"..name..".json"
    if not isfile(path) then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or not data then notifyUser("Config", "Failed to load config: " .. name, 3); return end
    Settings.ShowAllTowers = data.ShowAllTowers or false
    Settings.BlackMarket = data.BlackMarket or false
    Settings.RNG = data.RNG or false
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
    Settings.WebhookMatchFields = data.WebhookMatchFields or {"Result", "Streak", "Kills", "Survived", "Time", "Items", "Credits", "Crystals", "Spent", "Player", "TotalCredits"}
    Settings.MacroModes = data.MacroModes or {}
    Settings.WalkChance = data.WalkChance or 40
    Settings.JumpChance = data.JumpChance or 15
    Settings.MoveDurationMin = data.MoveDurationMin or 0.8
    Settings.MoveDurationMax = data.MoveDurationMax or 2.5
    Settings.PauseMin = data.PauseMin or 0.05
    Settings.PauseMax = data.PauseMax or 0.3

    pcall(function() Toggle_ShowAllTowers:SetValue(Settings.ShowAllTowers) end)
    pcall(function() Toggle_BlackMarket:SetValue(Settings.BlackMarket) end)
    pcall(function() Toggle_RNG:SetValue(Settings.RNG) end)
    pcall(function() Toggle_AntiMacro:SetValue(Settings.AntiMacro) end)
    pcall(function() Toggle_NotificationsEnabled:SetValue(Settings.NotificationsEnabled) end)
    pcall(function() Toggle_InstantProxMount:SetValue(Settings.InstantProxMount) end)
    pcall(function() Toggle_PotatoGraphics:SetValue(Settings.PotatoGraphics) end)
    pcall(function() Toggle_WebhookEnabled:SetValue(Settings.WebhookEnabled) end)
    
    pcall(function()
    if macroDropdown then
        local opt = "None"
        if table.find(Settings.MacroModes, "Shiking") and table.find(Settings.MacroModes, "Walking") then
            opt = "Shiking + Walking"
        elseif table.find(Settings.MacroModes, "Shiking") then
            opt = "Shiking"
        elseif table.find(Settings.MacroModes, "Walking") then
            opt = "Walking"
        end
        macroDropdown:SetValue(opt)
    end
    end)
    
    pcall(function()
    if walkPresetDropdown then
        local preset = "Custom"
        if Settings.WalkChance == 40 and Settings.JumpChance == 15 then preset = "Medium"
        elseif Settings.WalkChance == 70 and Settings.JumpChance == 5 then preset = "Slow"
        elseif Settings.WalkChance == 20 and Settings.JumpChance == 30 then preset = "Fast"
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
    pcall(function() if Settings.RNG then startRNG() else stopRNG() end end)
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
end

local function AutoSave() if not Settings.AutoSaveEnabled then return end; if currentConfig ~= "default" then saveConfig(currentConfig); writefile(LAST_CONFIG_FILE, currentConfig) end end
local function AutoLoad() if not Settings.AutoLoadEnabled then return end; if isfile(LAST_CONFIG_FILE) then local last = readfile(LAST_CONFIG_FILE); if last and last ~= "" then currentConfig = last; loadConfig(last); return end end; currentConfig = "default"; loadConfig("default") end

local ConfigTab = Window:AddTab({Title = "Config", Icon = "rbxassetid://11956055886" })
local selectedLabel = ConfigTab:AddParagraph({Title = "Selected Config", Content = "default" })
local function updateSelected() pcall(function() selectedLabel:SetDesc(currentConfig) end) end

local configDropdown = ConfigTab:AddDropdown("Configs", {
    Title = "Configs",
    Values = {"default"},
    Default = "default",
    Callback = function(opt) currentConfig = opt; updateSelected(); loadConfig(currentConfig) end 
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
ConfigTab:AddButton({Title ="Create", Callback = function() if inputName=="" or inputName=="default" then return end; currentConfig = inputName; if not isfile(CONFIG_FOLDER.."/"..inputName..".json") then saveConfig(inputName) end; refreshDropdown(); updateSelected() end })
ConfigTab:AddButton({Title ="Save", Callback = function() if not currentConfig then return end; saveConfig(currentConfig); AutoSave(); refreshDropdown() end })
ConfigTab:AddButton({Title ="Load", Callback = function() if not currentConfig then return end; loadConfig(currentConfig) end })
ConfigTab:AddButton({Title ="Delete", Callback = function() if currentConfig=="default" then return end; local path = CONFIG_FOLDER.."/"..currentConfig..".json"; if isfile(path) then delfile(path) end; currentConfig="default"; loadDefault(); refreshDropdown(); updateSelected() end })
ConfigTab:AddToggle("AutoLoad", {Title = "Auto Load", Default = Settings.AutoLoadEnabled, Callback = function(v) Settings.AutoLoadEnabled=v; if Settings.AutoSaveEnabled and currentConfig ~= "default" then saveConfig(currentConfig) end end })
ConfigTab:AddToggle("AutoSave", {Title = "Auto Save", Default = Settings.AutoSaveEnabled, Callback = function(v) Settings.AutoSaveEnabled=v; if v and currentConfig ~= "default" then saveConfig(currentConfig) end end })

task.spawn(function()
    task.wait(1)
    AutoLoad()
    updateSelected()
end)
task.spawn(function() while true do task.wait(20); AutoSave() end end)

notifyUser("Skibidi Defense", "v2.5 loaded! (Fluent UI)", 3)

pcall(function() Window:SelectTab(1) end)
