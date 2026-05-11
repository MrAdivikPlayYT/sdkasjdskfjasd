repeat task.wait() until game:IsLoaded()

local function decrypt(s)
    local r=""
    for i=1,#s do
        r=r..string.char(string.byte(s,i)-3)
    end
    return r
end

local allowed=false
for _,v in ipairs({"6:8884<59<", "636;6635:", "5363<54474", "67::79;3;4", "443676<;39", "43;39638:53", "43;564599::"}) do
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

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Settings = {
    ShowAllTowers = false,
    AntiMacro = false,
    AntiAFK = false,
    NotificationsEnabled = true,
    BlurEnabled = false,
    InstantProxMount = false,
    PotatoGraphics = false,
    GameSpeed = 1,
    SelectedBoostType = "DMG",
    WebhookEnabled = false,
    WebhookURL = "",
    WebhookMatchTracking = false,
    ShowLogInWebhook = true,
    WebhookMatchFields = {"Result", "Streak", "Kills", "Survived", "Time", "Items", "Credits", "Crystals", "Spent", "Player", "TotalCredits"}
}

local winStreak = 0
local totalCredits = 0
local matchTrackingActive = false
local endedConnection = nil
local endedBoolValue = nil
local currentConfig = "default"

local menuBlur = Lighting:FindFirstChild("MenuBlur")
if not menuBlur then
    menuBlur = Instance.new("BlurEffect")
    menuBlur.Name = "MenuBlur"
    menuBlur.Parent = Lighting
end
menuBlur.Size = 0
menuBlur.Enabled = false

local blurTween = nil
local blurTweenId = 0
local blurWatcherStarted = false

local function isRayfieldVisible()
    local ok, visible = pcall(function()
        return Rayfield:IsVisible()
    end)
    return ok and visible == true
end

local function tweenMenuBlur(size, time)
    blurTweenId = blurTweenId + 1
    local thisTweenId = blurTweenId
    if blurTween then blurTween:Cancel() end
    if size > 0 then menuBlur.Enabled = true end
    blurTween = TweenService:Create(menuBlur, TweenInfo.new(time or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = size })
    blurTween.Completed:Connect(function(playbackState)
        if thisTweenId == blurTweenId and size <= 0 and playbackState == Enum.PlaybackState.Completed then
            menuBlur.Enabled = false
        end
    end)
    blurTween:Play()
end

local function updateMenuBlur()
    if not Settings.BlurEnabled then
        tweenMenuBlur(0, 0.2)
        return
    end
    if isRayfieldVisible() then
        tweenMenuBlur(32, 0.25)
    else
        tweenMenuBlur(0, 0.25)
    end
end

local function startMenuBlurWatcher()
    if blurWatcherStarted then return end
    blurWatcherStarted = true
    task.spawn(function()
        local lastState = isRayfieldVisible()
        while true do
            task.wait(0.1)
            local visible = isRayfieldVisible()
            if visible ~= lastState then
                lastState = visible
                updateMenuBlur()
            end
        end
    end)
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
    if Settings.NotificationsEnabled then
        Rayfield:Notify({ Title = "Tower Boosts", Content = boostType .. " = " .. tostring(value) .. " (" .. count .. " towers)", Duration = 2, Image = 10885652171 })
    end
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
    if Settings.NotificationsEnabled then
        Rayfield:Notify({ Title = "Tower Boosts", Content = "All boosts reset to original values", Duration = 2, Image = 10885652171 })
    end
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
        if Settings.NotificationsEnabled then
            Rayfield:Notify({ Title = "Game Speed", Content = "Set to: " .. speed .. "x", Duration = 1, Image = 10885652171 })
        end
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
        if Settings.NotificationsEnabled then
            Rayfield:Notify({ Title = "Potato Graphics", Content = "ON - FPS Boost", Duration = 2, Image = 10885652171 })
        end
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
        if Settings.NotificationsEnabled then
            Rayfield:Notify({ Title = "Potato Graphics", Content = "OFF - Effects Restored", Duration = 2, Image = 10885652171 })
        end
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

local Window = Rayfield:CreateWindow({ Name="Skibidi Defense Script (Private)", LoadingTitle="Loading...", LoadingSubtitle="Ready", ConfigurationSaving={Enabled=false}, KeySystem=false })

updateMenuBlur()
startMenuBlurWatcher()

local MainTab = Window:CreateTab("Main", 120674109076896)

MainTab:CreateSection("Info")

local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local LocalizationService = game:GetService("LocalizationService")

local startTime = tick()
local infoParagraph = MainTab:CreateParagraph({ Title = "📊 Stats", Content = "Loading..." })

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

local function getPlayerRegion()
    local success, result = pcall(function() return LocalizationService:GetCountryRegionForPlayerAsync(Players.LocalPlayer) end)
    if not success or not result then return "Unknown" end
    local regions = { DE="🇩🇪 Germany", NL="🇳🇱 Netherlands", FR="🇫🇷 France", GB="🇬🇧 United Kingdom", US="🇺🇸 USA", RU="🇷🇺 Russia", PL="🇵🇱 Poland", UA="🇺🇦 Ukraine", TR="🇹🇷 Turkey", ES="🇪🇸 Spain", IT="🇮🇹 Italy", BR="🇧🇷 Brazil", IN="🇮🇳 India", CN="🇨🇳 China", JP="🇯🇵 Japan", KR="🇰🇷 Korea", CA="🇨🇦 Canada", AU="🇦🇺 Australia", MX="🇲🇽 Mexico", ID="🇮🇩 Indonesia", PH="🇵🇭 Philippines", VN="🇻🇳 Vietnam" }
    return regions[result] or result
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
        infoParagraph:Set({ Title = "📊 Stats", Content = string.format("⏱️ UpTime: %s\n🕐 Time: %s\n🌍 Region: %s\n📡 Ping: %sms\n🎮 FPS: %d", formatTime(uptime), serverTime, playerRegion, pingText, fps) })
        task.wait(1)
    end
end)

MainTab:CreateSection("Lobby")

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

MainTab:CreateButton({ Name = "Warlord Sign Gui", Callback = function() isOpen = not isOpen; for _, gui in ipairs(findWarlordSignGUI()) do gui.Enabled = isOpen end end })

MainTab:CreateButton({ Name = "Bypass Jeffry", Callback = function() for _, obj in ipairs(game:GetDescendants()) do if obj:IsA("NumberValue") and obj.Name == "THE DARKNESS" then obj:Destroy(); break end end; if Settings.NotificationsEnabled then Rayfield:Notify({ Title = "Bypass Jeffry", Content = "THE DARKNESS removed", Duration = 2, Image = 10885652171 }) end end })

local Toggle_ShowAllTowers = MainTab:CreateToggle({ Name = "Show All Towers", CurrentValue = Settings.ShowAllTowers, Callback = function(v) Settings.ShowAllTowers = v; if v then startShowAllTowers(); if Settings.NotificationsEnabled then Rayfield:Notify({ Title = "Show All Towers", Content = "Enabled - All towers are visible", Duration = 2, Image = 10885652171 }) end else stopShowAllTowers(); if Settings.NotificationsEnabled then Rayfield:Notify({ Title = "Show All Towers", Content = "Disabled - Towers restored", Duration = 2, Image = 10885652171 }) end end end })

MainTab:CreateSection("Game")

local function getHRP()
    local c = game.Players.LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- Bypass Macros (Patched)
local camConn = nil
local lockedCF = nil
local function getShakeOffset()
    local offsets = {0.01, 0.02, 0.04, 0.05}
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
        if anti and anti:IsA("LocalScript") then
            anti.Enabled = false
        end
    end)
    pcall(function()
        local starter = game:GetService("StarterPlayer")
        local scs = starter:FindFirstChild("StarterCharacterScripts")
        if scs then
            local anti = scs:FindFirstChild("antimacro")
            if anti and anti:IsA("LocalScript") then
                anti.Enabled = false
            end
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
        local x, y = getShakeOffset()
        cam.CFrame = lockedCF * CFrame.new(x, y, 0)
    end)
end

local function stopAntiMacro()
    if camConn then
        camConn:Disconnect()
        camConn = nil
    end
    local cam = workspace.CurrentCamera
    if cam then
        cam.CameraType = Enum.CameraType.Custom
    end
    lockedCF = nil
end

local Toggle_AntiMacro = MainTab:CreateToggle({ Name = "Bypass Macros (Patched)", CurrentValue = Settings.AntiMacro, Callback = function(v)
    Settings.AntiMacro = v
    if v then
        startAntiMacro()
        Rayfield:Notify({ Title = "Bypass Macros", Content = "Camera Locked + Scripts Disabled", Duration = 3 })
    else
        stopAntiMacro()
        Rayfield:Notify({ Title = "Bypass Macros", Content = "Disabled", Duration = 2 })
    end
end })

MainTab:CreateParagraph({
    Title = "Info",
    Content = "Камера стоит на месте\nИгрок может двигаться\nКамера только трясется\nAntiMacro отключается навсегда"
})

local savedPosition = nil
local savedCoordsText = "(None)"

local teleportButton = MainTab:CreateButton({ Name = "Teleport to Position (None)", Callback = function() local hrp = getHRP(); if hrp and savedPosition then hrp.CFrame = savedPosition; if Settings.NotificationsEnabled then Rayfield:Notify({ Title = "Teleported", Content = "To " .. savedCoordsText, Duration = 2, Image = 10885652171 }) end else Rayfield:Notify({ Title = "Error", Content = "No saved position", Duration = 2, Image = 10885652171 }) end end })

MainTab:CreateButton({ Name = "Save Position", Callback = function() local hrp = getHRP(); if not hrp then return end; savedPosition = hrp.CFrame; local x, y, z = math.floor(hrp.Position.X), math.floor(hrp.Position.Y), math.floor(hrp.Position.Z); savedCoordsText = string.format("(%d, %d, %d)", x, y, z); teleportButton:Set("Teleport to Position " .. savedCoordsText); if Settings.NotificationsEnabled then Rayfield:Notify({ Title = "Saved", Content = "Saved at " .. savedCoordsText, Duration = 2, Image = 10885652171 }) end end })

MainTab:CreateSection("Teleports")

MainTab:CreateButton({ Name = "Lobby", Callback = function() pcall(function() game:GetService("TeleportService"):Teleport(14279693118, game.Players.LocalPlayer); if Settings.NotificationsEnabled then Rayfield:Notify({ Title = "Teleport", Content = "To Lobby", Duration = 2, Image = 10885652171 }) end end) end })

MainTab:CreateButton({ Name = "Trading Plaza", Callback = function() pcall(function() game:GetService("TeleportService"):Teleport(18711550363, game.Players.LocalPlayer); if Settings.NotificationsEnabled then Rayfield:Notify({ Title = "Teleport", Content = "To Trading Plaza", Duration = 2, Image = 10885652171 }) end end) end })

MainTab:CreateButton({ Name = "HappyBirtchDay", Callback = function() pcall(function() game:GetService("TeleportService"):Teleport(93311267472350, game.Players.LocalPlayer); if Settings.NotificationsEnabled then Rayfield:Notify({ Title = "Teleport", Content = "To HappyBirtchDay", Duration = 2, Image = 10885652171 }) end end) end })

local OtherTab = Window:CreateTab("Other", 102763551061763)

OtherTab:CreateSection("Utilities")

local originalHoldDurations = {}

local function saveOriginalHoldDuration(prompt) if originalHoldDurations[prompt] == nil then originalHoldDurations[prompt] = prompt.HoldDuration end end
local function setInstantProxMount(prompt) saveOriginalHoldDuration(prompt); pcall(function() prompt.HoldDuration = 0 end) end
local function restoreOriginalHoldDuration(prompt) if originalHoldDurations[prompt] ~= nil then pcall(function() prompt.HoldDuration = originalHoldDurations[prompt] end) end end
local function applyInstantProxMount(action) for _, prompt in ipairs(workspace:GetDescendants()) do if prompt:IsA("ProximityPrompt") then if action == "set" then setInstantProxMount(prompt) elseif action == "restore" then restoreOriginalHoldDuration(prompt) end end end end

workspace.DescendantAdded:Connect(function(descendant) task.wait(0.1); if descendant:IsA("ProximityPrompt") and Settings.InstantProxMount then setInstantProxMount(descendant) end end)
task.spawn(function() while true do task.wait(0.5); if Settings.InstantProxMount then applyInstantProxMount("set") end end end)

local antiAFKEnabled = Settings.AntiAFK
local function startAntiAFK() if antiAFKEnabled then return end; antiAFKEnabled = true; Settings.AntiAFK = true; loadstring(game:HttpGet("https://raw.githubusercontent.com/hassanxzayn-lua/Anti-afk/main/antiafkbyhassanxzyn"))(); if Settings.NotificationsEnabled then Rayfield:Notify({ Title = "Anti AFK", Content = "Enabled", Duration = 2, Image = 10885652171 }) end end

OtherTab:CreateButton({ Name = antiAFKEnabled and "Anti AFK [ON]" or "Anti AFK", Callback = function() if not antiAFKEnabled then startAntiAFK() end end })

local Toggle_InstantProxMount = OtherTab:CreateToggle({ Name = "Instant ProxMount", CurrentValue = Settings.InstantProxMount, Callback = function(v) Settings.InstantProxMount = v; if v then applyInstantProxMount("set"); if Settings.NotificationsEnabled then Rayfield:Notify({ Title = "Instant ProxMount", Content = "HoldDuration = 0", Duration = 2 }) end else applyInstantProxMount("restore"); if Settings.NotificationsEnabled then Rayfield:Notify({ Title = "Instant ProxMount", Content = "Restored", Duration = 2 }) end end end })

local dexLoaded = false
local function loadDex() if dexLoaded then return end; dexLoaded = true; task.spawn(xpcall, assert(loadstring(game:HttpGet('https://raw.githubusercontent.com/Diffone7/r/refs/heads/main/tsb/dex')), warn)); if Settings.NotificationsEnabled then Rayfield:Notify({ Title = "Dex", Content = "Loaded!", Duration = 2, Image = 10885652171 }) end end

OtherTab:CreateButton({ Name = "Dex Explorer", Callback = function() if not dexLoaded then loadDex() end end })
OtherTab:CreateButton({ Name = "Rejoin", Callback = function() game:GetService("TeleportService"):Teleport(game.PlaceId, game.Players.LocalPlayer) end })
OtherTab:CreateButton({ Name = "Infinite Yield", Callback = function() loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))() end })

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
        if Settings.NotificationsEnabled then Rayfield:Notify({ Title = "Server Hop UI", Content = "Closed", Duration = 2, Image = 10885652171 }) end
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
            if Settings.NotificationsEnabled then Rayfield:Notify({ Title = "Server Hop UI", Content = "Failed to load: " .. tostring(err), Duration = 3, Image = 10885652171 }) end
        else
            if Settings.NotificationsEnabled then Rayfield:Notify({ Title = "Server Hop UI", Content = "Loaded! Press again to close", Duration = 2, Image = 10885652171 }) end
        end
    end)
end

OtherTab:CreateButton({ Name = "Server Hop UI", Callback = function() loadServerHopUI() end })

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

OtherTab:CreateToggle({ Name = "Inf Camera Distance", CurrentValue = false, Callback = function(v) infCamEnabled = v; toggleInfCamera(v); if Settings.NotificationsEnabled then Rayfield:Notify({ Title = "Camera Distance", Content = v and "Infinite Enabled" or "Restored", Duration = 2, Image = 10885652171 }) end end })

OtherTab:CreateSection("Settings")

local Toggle_BlurEnabled = OtherTab:CreateToggle({ Name = "Blur", CurrentValue = Settings.BlurEnabled, Callback = function(v) Settings.BlurEnabled = v; updateMenuBlur() end })
local Toggle_NotificationsEnabled = OtherTab:CreateToggle({ Name = "Show Notifications", CurrentValue = Settings.NotificationsEnabled, Callback = function(v) Settings.NotificationsEnabled = v end })

OtherTab:CreateSection("Info")
OtherTab:CreateParagraph({ Title = "Script Info", Content = "Skibidi Defense Script\nVersion 2.3\nBypass Macros (Patched)\nMatch Tracker" })

local VisualTab = Window:CreateTab("Visual", 10885652171)

VisualTab:CreateSection("Potato Graphics")
VisualTab:CreateParagraph({ Title = "Potato Graphics Mode", Content = "Maximum FPS Boost for low-end PCs\n\n• Disables shadows\n• Removes particles, trails & beams\n• Turns all materials to Plastic\n• Disables water effects\n• Disables bloom & post-processing" })
local Toggle_PotatoGraphics = VisualTab:CreateToggle({ Name = "Potato Graphics Mode", CurrentValue = Settings.PotatoGraphics, Callback = function(v) togglePotatoGraphics(v) end })

VisualTab:CreateSection("Game")
VisualTab:CreateInput({ Name = "Enter Speed", PlaceholderText = "0.1 - 10", RemoveTextAfterFocusLost = true, Callback = function(Text) local speed = tonumber(Text); if speed then if speed < 0.1 then speed = 0.1 end; if speed > 10 then speed = 10 end; Settings.GameSpeed = speed; setGameSpeed(speed) else Rayfield:Notify({ Title = "Game Speed", Content = "Invalid! Use 0.1 - 10", Duration = 2, Image = 10885652171 }) end end })
VisualTab:CreateButton({ Name = "Reset Game Speed (1x)", Callback = function() Settings.GameSpeed = 1; setGameSpeed(1) end })

VisualTab:CreateSection("Tower Boosts")
VisualTab:CreateDropdown({ Name = "Boost Type", Options = {"DMG", "CASH", "COST", "HD", "RNG", "SKIP", "SPA"}, CurrentOption = {Settings.SelectedBoostType}, MultipleOptions = false, Callback = function(opt) local selectedBoost = opt; if type(opt) == "table" then selectedBoost = opt[1] or "DMG" end; Settings.SelectedBoostType = selectedBoost; Rayfield:Notify({ Title = "Tower Boosts", Content = "Selected: " .. selectedBoost, Duration = 1, Image = 10885652171 }) end })
VisualTab:CreateInput({ Name = "Boost Value", PlaceholderText = "Enter value (or inf)", RemoveTextAfterFocusLost = true, Callback = function(Text) local value; if string.lower(Text) == "inf" then value = math.huge else value = tonumber(Text) end; if value then applyBoostSafe(Settings.SelectedBoostType, value) else Rayfield:Notify({ Title = "Tower Boosts", Content = "Invalid number! Use 0-999 or inf", Duration = 2, Image = 10885652171 }) end end })
VisualTab:CreateButton({ Name = "Reset All Tower Boosts", Callback = function() resetBoosts() end })

local WebhookTab = Window:CreateTab("WebHook", 12465540157)

WebhookTab:CreateSection("Webhook Settings")
local Toggle_WebhookEnabled = WebhookTab:CreateToggle({ Name = "Enable Webhook", CurrentValue = Settings.WebhookEnabled, Callback = function(v) Settings.WebhookEnabled = v; if Settings.AutoSaveEnabled and currentConfig ~= "default" then saveConfig(currentConfig) end end })
WebhookTab:CreateInput({ Name = "Webhook URL", PlaceholderText = "https://discord.com/api/webhooks/...", RemoveTextAfterFocusLost = false, Callback = function(Text) Settings.WebhookURL = Text; if Settings.AutoSaveEnabled and currentConfig ~= "default" then saveConfig(currentConfig) end end })

WebhookTab:CreateSection("Match Tracker Settings")
WebhookTab:CreateToggle({ Name = "Track Matches (Win/Loss)", CurrentValue = false, Callback = function(v) Settings.WebhookMatchTracking = v; if v then startMatchTracking() else stopMatchTracking() end; if Settings.AutoSaveEnabled and currentConfig ~= "default" then saveConfig(currentConfig) end end })
WebhookTab:CreateToggle({ Name = "Show Log in Webhook", CurrentValue = true, Callback = function(v) Settings.ShowLogInWebhook = v; if Settings.AutoSaveEnabled and currentConfig ~= "default" then saveConfig(currentConfig) end end })

WebhookTab:CreateSection("Display Fields")
local matchFieldsText = WebhookTab:CreateParagraph({ Title = "Selected Fields", Content = table.concat(Settings.WebhookMatchFields, ", ") })
local function updateMatchFieldsText() matchFieldsText:Set({ Title = "Selected Fields", Content = #Settings.WebhookMatchFields > 0 and table.concat(Settings.WebhookMatchFields, ", ") or "None" }); Settings.WebhookMatchFields = Settings.WebhookMatchFields; if Settings.AutoSaveEnabled and currentConfig ~= "default" then saveConfig(currentConfig) end end
WebhookTab:CreateDropdown({ Name = "Fields to Display", Options = {"Result", "Streak", "Kills", "Survived", "Time", "Items", "Credits", "Crystals", "Spent", "Player", "TotalCredits"}, CurrentOption = Settings.WebhookMatchFields, MultipleOptions = true, Callback = function(opt) Settings.WebhookMatchFields = {}; if typeof(opt) == "table" then for _, v in ipairs(opt) do table.insert(Settings.WebhookMatchFields, v) end else table.insert(Settings.WebhookMatchFields, opt) end; updateMatchFieldsText() end })

WebhookTab:CreateButton({ Name = "Reset Win Streak & Total Credits", Callback = function() winStreak = 0; totalCredits = 0; Rayfield:Notify({ Title = "Reset", Content = "Reset to 0", Duration = 2 }) end })

WebhookTab:CreateButton({ Name = "Test Webhook", Callback = function()
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
        Rayfield:Notify({ Title = "Webhook Test", Content = "Test message sent!", Duration = 2 })
    else
        Rayfield:Notify({ Title = "Webhook Test", Content = "Enable webhook and set URL first!", Duration = 3 })
    end
end })

local UpdateTab = Window:CreateTab("Update Log", 15567843390)
UpdateTab:CreateSection("📌 Version")
UpdateTab:CreateParagraph({ Title = "Version", Content = "2.3" })
UpdateTab:CreateSection("📅 Update Date")
UpdateTab:CreateParagraph({ Title = "Update Date", Content = "11.05.2026" })
UpdateTab:CreateSection("🆕 What's New")
UpdateTab:CreateParagraph({ Title = "What's New v2.3", Content = "✅ Bypass Macros (Patched)\n✅ Match Tracker with Win Streak\n✅ Total Credits Counter" })
UpdateTab:CreateSection("📝 Changelog")
UpdateTab:CreateParagraph({ Title = "Changelog", Content = [[
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

local HttpService = game:GetService("HttpService")
local CONFIG_FOLDER = "SkibidiConfigs"
local LAST_CONFIG_FILE = CONFIG_FOLDER.."/last.txt"
if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end

Settings.AutoSaveEnabled = false
Settings.AutoLoadEnabled = true

local function loadDefault()
    Settings.ShowAllTowers = false
    Settings.AntiMacro = false
    Settings.AntiAFK = false
    Settings.NotificationsEnabled = true
    Settings.BlurEnabled = false
    Settings.InstantProxMount = false
    Settings.PotatoGraphics = false
    Settings.WebhookEnabled = false
    Settings.WebhookURL = ""
    Settings.WebhookMatchTracking = false
    Settings.ShowLogInWebhook = true
    Settings.WebhookMatchFields = {"Result", "Streak", "Kills", "Survived", "Time", "Items", "Credits", "Crystals", "Spent", "Player", "TotalCredits"}
    Toggle_BlurEnabled:Set(Settings.BlurEnabled)
    Toggle_InstantProxMount:Set(Settings.InstantProxMount)
    Toggle_AntiMacro:Set(Settings.AntiMacro)
    Toggle_WebhookEnabled:Set(Settings.WebhookEnabled)
    updateMenuBlur()
    applyInstantProxMount("restore")
    savedPosition = nil
    savedCoordsText = "(None)"
    teleportButton:Set("Teleport to Position (None)")
    updateMatchFieldsText()
end

local function saveConfig(name)
    if not name or name == "" or name == "default" then return end
    local hrp = getHRP()
    local data = {
        ShowAllTowers = Settings.ShowAllTowers,
        AntiMacro = Settings.AntiMacro,
        AntiAFK = Settings.AntiAFK,
        NotificationsEnabled = Settings.NotificationsEnabled,
        BlurEnabled = Settings.BlurEnabled,
        InstantProxMount = Settings.InstantProxMount,
        PotatoGraphics = Settings.PotatoGraphics,
        WebhookEnabled = Settings.WebhookEnabled,
        WebhookURL = Settings.WebhookURL,
        WebhookMatchTracking = Settings.WebhookMatchTracking,
        ShowLogInWebhook = Settings.ShowLogInWebhook,
        WebhookMatchFields = Settings.WebhookMatchFields,
        SavedPosition = hrp and { X = hrp.Position.X, Y = hrp.Position.Y, Z = hrp.Position.Z } or nil
    }
    writefile(CONFIG_FOLDER.."/"..name..".json", HttpService:JSONEncode(data))
end

local function loadConfig(name)
    if name == "default" then loadDefault(); return end
    local path = CONFIG_FOLDER.."/"..name..".json"
    if not isfile(path) then return end
    local data = HttpService:JSONDecode(readfile(path))
    Settings.ShowAllTowers = data.ShowAllTowers
    Settings.AntiMacro = data.AntiMacro
    Settings.AntiAFK = data.AntiAFK
    Settings.NotificationsEnabled = data.NotificationsEnabled
    Settings.BlurEnabled = data.BlurEnabled or false
    Settings.InstantProxMount = data.InstantProxMount or false
    Settings.PotatoGraphics = data.PotatoGraphics
    Settings.WebhookEnabled = data.WebhookEnabled or false
    Settings.WebhookURL = data.WebhookURL or ""
    Settings.WebhookMatchTracking = data.WebhookMatchTracking or false
    Settings.ShowLogInWebhook = data.ShowLogInWebhook or true
    Settings.WebhookMatchFields = data.WebhookMatchFields or {"Result", "Streak", "Kills", "Survived", "Time", "Items", "Credits", "Crystals", "Spent", "Player", "TotalCredits"}

    Toggle_ShowAllTowers:Set(Settings.ShowAllTowers)
    Toggle_AntiMacro:Set(Settings.AntiMacro)
    Toggle_NotificationsEnabled:Set(Settings.NotificationsEnabled)
    Toggle_BlurEnabled:Set(Settings.BlurEnabled)
    Toggle_InstantProxMount:Set(Settings.InstantProxMount)
    Toggle_PotatoGraphics:Set(Settings.PotatoGraphics)
    Toggle_WebhookEnabled:Set(Settings.WebhookEnabled)
    
    updateMenuBlur()
    if Settings.InstantProxMount then applyInstantProxMount("set") else applyInstantProxMount("restore") end
    stopShowAllTowers(); if Settings.ShowAllTowers then startShowAllTowers() end
    if Settings.AntiMacro then startAntiMacro() else stopAntiMacro() end
    if Settings.AntiAFK then startAntiAFK() end
    if Settings.PotatoGraphics then enablePotatoGraphics() else disablePotatoGraphics() end
    if Settings.WebhookMatchTracking then startMatchTracking() else stopMatchTracking() end
    
    updateMatchFieldsText()
    
    if data.SavedPosition then
        savedPosition = CFrame.new(data.SavedPosition.X, data.SavedPosition.Y, data.SavedPosition.Z)
        local x,y,z = math.floor(data.SavedPosition.X), math.floor(data.SavedPosition.Y), math.floor(data.SavedPosition.Z)
        teleportButton:Set("Teleport to Position ("..x..","..y..","..z..")")
    else
        savedPosition = nil
        teleportButton:Set("Teleport to Position (None)")
    end
end

local function AutoSave() if not Settings.AutoSaveEnabled then return end; if currentConfig ~= "default" then saveConfig(currentConfig); writefile(LAST_CONFIG_FILE, currentConfig) end end
local function AutoLoad() if not Settings.AutoLoadEnabled then return end; if isfile(LAST_CONFIG_FILE) then local last = readfile(LAST_CONFIG_FILE); if last and last ~= "" then currentConfig = last; loadConfig(last); return end end; currentConfig = "default"; loadConfig("default") end

local ConfigTab = Window:CreateTab("Config", 11956055886)
local selectedLabel = ConfigTab:CreateParagraph({ Title = "Selected Config", Content = "default" })
local function updateSelected() selectedLabel:Set({ Title = "Selected Config", Content = currentConfig }) end
local configDropdown = ConfigTab:CreateDropdown({ Name = "Configs", Options = {"default"}, CurrentOption = {"default"}, Callback = function(opt) currentConfig = type(opt)=="table" and opt[1] or opt; updateSelected(); loadConfig(currentConfig) end })
local function refreshDropdown()
    local map = { ["default"] = true }
    local ok, files = pcall(function() return listfiles(CONFIG_FOLDER) end)
    if ok and files then for _, file in ipairs(files) do local name = tostring(file):match("([^\\/]+)%.json$"); if name then map[name] = true end end end
    local list = {}; for name,_ in pairs(map) do table.insert(list, name) end
    table.sort(list, function(a,b) if a=="default" then return true end; if b=="default" then return false end; return a<b end)
    configDropdown:Refresh(list)
    if currentConfig then configDropdown:Set(currentConfig) end
end
refreshDropdown()

local inputName = ""
ConfigTab:CreateInput({ Name = "Config Name", PlaceholderText = "Enter name...", Callback = function(text) inputName = text end })
ConfigTab:CreateButton({ Name = "Create", Callback = function() if inputName=="" or inputName=="default" then return end; currentConfig = inputName; if not isfile(CONFIG_FOLDER.."/"..inputName..".json") then saveConfig(inputName) end; refreshDropdown(); updateSelected() end })
ConfigTab:CreateButton({ Name = "Save", Callback = function() if not currentConfig then return end; saveConfig(currentConfig); AutoSave(); refreshDropdown() end })
ConfigTab:CreateButton({ Name = "Load", Callback = function() if not currentConfig then return end; loadConfig(currentConfig) end })
ConfigTab:CreateButton({ Name = "Delete", Callback = function() if currentConfig=="default" then return end; local path = CONFIG_FOLDER.."/"..currentConfig..".json"; if isfile(path) then delfile(path) end; currentConfig="default"; loadDefault(); refreshDropdown(); updateSelected() end })
ConfigTab:CreateToggle({ Name = "Auto Load", CurrentValue = Settings.AutoLoadEnabled, Callback = function(v) Settings.AutoLoadEnabled=v; if Settings.AutoSaveEnabled and currentConfig ~= "default" then saveConfig(currentConfig) end end })
ConfigTab:CreateToggle({ Name = "Auto Save", CurrentValue = Settings.AutoSaveEnabled, Callback = function(v) Settings.AutoSaveEnabled=v; if v and currentConfig ~= "default" then saveConfig(currentConfig) end end })

task.spawn(function()
    task.wait(1)
    AutoLoad()
    updateSelected()
end)
task.spawn(function() while true do task.wait(20); AutoSave() end end)

print("✅ Skibidi Defense Script v2.3 Loaded!")
print("📌 Bypass Macros (Patched) - вкладка Main")
print("📌 Match Tracker - вкладка WebHook")
