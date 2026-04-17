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

local Settings = {
    ShowAllTowers = false,
    AntiMacro = false,
    AutoRng = false,
    AntiAFK = false,
    SelectedRngItems = {},
    NotificationsEnabled = true,
    PotatoGraphics = false,
    GameSpeed = 1,
    SelectedBoostType = "DMG"
}

local showAllTowersConnection = nil
local originalVisibility = {}
local isUpdating = false

local originalBoosts = {}
local createdSpecial = {}
local createdBoostsList = {}

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
            if not boosters then
                
            else
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
            if not boosters then
                -- skip
            else
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
        Rayfield:Notify({
            Title = "Tower Boosts",
            Content = boostType .. " = " .. tostring(value) .. " (" .. count .. " towers)",
            Duration = 2,
            Image = 10885652171
        })
    end
end

local function applyBoostSafe(boostType, value)
    if boostType == "DMG" then
        applyBoost("DMG", value)
    elseif boostType == "CASH" then
        applyBoost("CASH", math.floor(value))
    elseif boostType == "COST" then
        applyBoost("COST", math.floor(value))
    elseif boostType == "HD" then
        applyBoost("HD", math.floor(value))
    elseif boostType == "RNG" then
        applyBoost("RNG", math.floor(value))
    elseif boostType == "SKIP" then
        applyBoost("SKIP", math.floor(value))
    elseif boostType == "SPA" then
        applyBoost("SPA", math.floor(value))
    end
end

local function resetBoosts()
    local towerData = getTowerData()
    if not towerData then return end
    
    for _, tower in ipairs(towerData:GetChildren()) do
        if tower:IsA("Folder") then
            local boosters = tower:FindFirstChild("Boosters")
            if not boosters then
                -- skip
            else
                local special = boosters:FindFirstChild("Special")
                if special then
                    if originalBoosts[tower] then
                        for boostName, originalValue in pairs(originalBoosts[tower]) do
                            local boost = special:FindFirstChild(boostName)
                            if boost then
                                boost.Value = originalValue
                            end
                        end
                    end
                    
                    if createdBoostsList[tower] then
                        for boostName, _ in pairs(createdBoostsList[tower]) do
                            local boost = special:FindFirstChild(boostName)
                            if boost then
                                boost:Destroy()
                            end
                        end
                    end
                    
                    if createdSpecial[tower] then
                        special:Destroy()
                    end
                end
            end
        end
    end
    
    originalBoosts = {}
    createdSpecial = {}
    createdBoostsList = {}
    
    if Settings.NotificationsEnabled then
        Rayfield:Notify({
            Title = "Tower Boosts",
            Content = "All boosts reset to original values",
            Duration = 2,
            Image = 10885652171
        })
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
                if Settings.NotificationsEnabled then
                    Rayfield:Notify({
                        Title = "Game Speed",
                        Content = "Set to: " .. speed .. "x",
                        Duration = 1,
                        Image = 10885652171
                    })
                end
            else
                local newSpeed = Instance.new("NumberValue")
                newSpeed.Name = "Speed"
                newSpeed.Value = speed
                newSpeed.Parent = gameFolder
                if Settings.NotificationsEnabled then
                    Rayfield:Notify({
                        Title = "Game Speed",
                        Content = "Created & set to: " .. speed .. "x",
                        Duration = 1,
                        Image = 10885652171
                    })
                end
            end
        else
            local newGameFolder = Instance.new("Folder")
            newGameFolder.Name = "Game"
            newGameFolder.Parent = replicatedStorage
            
            local newSpeed = Instance.new("NumberValue")
            newSpeed.Name = "Speed"
            newSpeed.Value = speed
            newSpeed.Parent = newGameFolder
            
            if Settings.NotificationsEnabled then
                Rayfield:Notify({
                    Title = "Game Speed",
                    Content = "Created folder & set to: " .. speed .. "x",
                    Duration = 1,
                    Image = 10885652171
                })
            end
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

local function saveMaterial(obj)
    if not savedMaterials[obj] then
        savedMaterials[obj] = obj.Material
    end
end

local function saveEffect(obj)
    if obj:IsA("ParticleEmitter") and not savedParticles[obj] then
        savedParticles[obj] = obj.Enabled
    elseif (obj:IsA("Trail") or obj:IsA("Beam")) and not savedEffects[obj] then
        savedEffects[obj] = obj.Enabled
    elseif (obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles")) and not savedEffects[obj] then
        savedEffects[obj] = obj.Enabled
    elseif (obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight")) and not savedLights[obj] then
        savedLights[obj] = obj.Enabled
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
        for obj, material in pairs(savedMaterials) do
            if obj and obj.Parent then
                obj.Material = material
            end
        end
        
        for obj, enabled in pairs(savedParticles) do
            if obj and obj.Parent then
                obj.Enabled = enabled
                if enabled and obj:IsA("ParticleEmitter") then
                    obj.Rate = 10
                end
            end
        end
        
        for obj, enabled in pairs(savedEffects) do
            if obj and obj.Parent then
                obj.Enabled = enabled
            end
        end
        
        for obj, enabled in pairs(savedLights) do
            if obj and obj.Parent then
                obj.Enabled = enabled
            end
        end
        
        savedMaterials = {}
        savedParticles = {}
        savedEffects = {}
        savedLights = {}
    end)
end

local function restorePostEffects()
    local Lighting = game:GetService("Lighting")
    for v, enabled in pairs(savedPostEffects) do
        pcall(function()
            if v and v.Parent then
                v.Enabled = enabled
            end
        end)
    end
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
                if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or 
                   v:IsA("ColorCorrectionEffect") or v:IsA("DepthOfFieldEffect") or
                   v:IsA("Atmosphere") then
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
            Rayfield:Notify({
                Title = "Potato Graphics",
                Content = "ON - FPS Boost",
                Duration = 2,
                Image = 10885652171
            })
        end
    end)
end

local function disablePotatoGraphics()
    if not potatoGraphicsActive then return end
    potatoGraphicsActive = false
    
    pcall(function()
        if descendantConnection then
            descendantConnection:Disconnect()
            descendantConnection = nil
        end
        
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
            Rayfield:Notify({
                Title = "Potato Graphics",
                Content = "OFF - Effects Restored",
                Duration = 2,
                Image = 10885652171
            })
        end
    end)
end

local function togglePotatoGraphics(enabled)
    Settings.PotatoGraphics = enabled
    if enabled then
        enablePotatoGraphics()
    else
        disablePotatoGraphics()
    end
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
                        if originalVisibility[button] == nil then
                            originalVisibility[button] = button.Visible
                        end
                        if button.Visible ~= true then
                            button.Visible = true
                        end
                    end
                end
                if grid.Visible ~= true then
                    grid.Visible = true
                end
            end
        end
    end)
    isUpdating = false
end

local function restoreOriginalTowers()
    for button, visible in pairs(originalVisibility) do
        pcall(function()
            if button.Visible ~= visible then
                button.Visible = visible
            end
        end)
    end
    originalVisibility = {}
end

local function startShowAllTowers()
    if showAllTowersConnection then return end
    showAllTowers()
    showAllTowersConnection = game:GetService("RunService").Stepped:Connect(function()
        if Settings.ShowAllTowers then
            showAllTowers()
        end
    end)
end

local function stopShowAllTowers()
    if showAllTowersConnection then
        showAllTowersConnection:Disconnect()
        showAllTowersConnection = nil
    end
    restoreOriginalTowers()
end

local Window = Rayfield:CreateWindow({
    Name="Skibidi Defense Script (Private)",
    LoadingTitle="Loading...",
    LoadingSubtitle="Ready",
    ConfigurationSaving={Enabled=false},
    KeySystem=false
})

local MainTab = Window:CreateTab("Main", 120674109076896)

MainTab:CreateSection("Info")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local LocalizationService = game:GetService("LocalizationService")

local startTime = tick()
local infoParagraph = MainTab:CreateParagraph({Title = "📊 Stats", Content = "Loading..."})

local fps = 0
local frames = 0
local lastUpdate = tick()

RunService.RenderStepped:Connect(function()
    frames = frames + 1
    if tick() - lastUpdate >= 1 then
        fps = frames
        frames = 0
        lastUpdate = tick()
    end
end)

local function getPingNumber()
    local str = Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
    local num = tonumber(string.match(str, "%d+"))
    return math.floor(num or 0)
end

local function getPingText()
    local ping = getPingNumber()
    return tostring(ping)
end

local function getPlayerRegion()
    local success, result = pcall(function()
        return LocalizationService:GetCountryRegionForPlayerAsync(Players.LocalPlayer)
    end)
    if not success or not result then return "Unknown" end
    
    local regions = {
        DE="🇩🇪 Germany", NL="🇳🇱 Netherlands", FR="🇫🇷 France", GB="🇬🇧 United Kingdom", 
        US="🇺🇸 USA", RU="🇷🇺 Russia", PL="🇵🇱 Poland", UA="🇺🇦 Ukraine", TR="🇹🇷 Turkey", 
        ES="🇪🇸 Spain", IT="🇮🇹 Italy", BR="🇧🇷 Brazil", IN="🇮🇳 India", CN="🇨🇳 China", 
        JP="🇯🇵 Japan", KR="🇰🇷 Korea", CA="🇨🇦 Canada", AU="🇦🇺 Australia", 
        MX="🇲🇽 Mexico", ID="🇮🇩 Indonesia", PH="🇵🇭 Philippines", VN="🇻🇳 Vietnam"
    }
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
        local pingNum = getPingNumber()
        local pingText = getPingText()
        local playerRegion = getPlayerRegion()
        
        infoParagraph:Set({
            Title = "📊 Stats",
            Content = string.format("⏱️ UpTime: %s\n🕐 Time: %s\n🌍 Region: %s\n📡 Ping: %sms\n🎮 FPS: %d",
                formatTime(uptime), serverTime, playerRegion, pingText, fps)
        })
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

MainTab:CreateButton({
    Name = "Warlord Sign Gui",
    Callback = function()
        isOpen = not isOpen
        for _, gui in ipairs(findWarlordSignGUI()) do
            gui.Enabled = isOpen
        end
    end
})

MainTab:CreateButton({
    Name = "Bypass Jeffry",
    Callback = function()
        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("NumberValue") and obj.Name == "THE DARKNESS" then
                obj:Destroy()
                break
            end
        end
        if Settings.NotificationsEnabled then
            Rayfield:Notify({
                Title = "Bypass Jeffry", 
                Content = "THE DARKNESS removed", 
                Duration = 2,
                Image = 10885652171
            })
        end
    end
})

MainTab:CreateToggle({
    Name = "Show All Towers",
    CurrentValue = Settings.ShowAllTowers,
    Callback = function(v)
        Settings.ShowAllTowers = v
        if v then
            startShowAllTowers()
            if Settings.NotificationsEnabled then
                Rayfield:Notify({
                    Title = "Show All Towers", 
                    Content = "Enabled - All towers are visible", 
                    Duration = 2,
                    Image = 10885652171
                })
            end
        else
            stopShowAllTowers()
            if Settings.NotificationsEnabled then
                Rayfield:Notify({
                    Title = "Show All Towers", 
                    Content = "Disabled - Towers restored", 
                    Duration = 2,
                    Image = 10885652171
                })
            end
        end
    end
})

MainTab:CreateSection("Trading Plaza")

local showImageButtons = false

MainTab:CreateToggle({
    Name = "Show RNG In Plaza",
    CurrentValue = false,
    Callback = function(v)
        showImageButtons = v
        local rng = game.Players.LocalPlayer.PlayerGui:FindFirstChild("RNG")
        if rng then
            for _, child in ipairs(rng:GetDescendants()) do
                if child:IsA("ImageButton") and child.Name ~= "PotionTracker" then
                    child.Visible = showImageButtons
                end
            end
        end
    end
})

MainTab:CreateSection("Game")

local function getHRP()
    local c = game.Players.LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local camConn = nil
local oldCF = nil

function startAntiMacro()
    if camConn then return end
    local cam = workspace.CurrentCamera
    oldCF = cam.CFrame
    camConn = game:GetService("RunService").RenderStepped:Connect(function()
        if Settings.AntiMacro then
            cam.CFrame = oldCF
        end
    end)
end

function stopAntiMacro()
    if camConn then
        camConn:Disconnect()
        camConn = nil
    end
end

MainTab:CreateToggle({
    Name = "Anti Macro (Bypass)",
    CurrentValue = Settings.AntiMacro,
    Callback = function(v)
        Settings.AntiMacro = v
        if v then startAntiMacro() else stopAntiMacro() end
        if Settings.NotificationsEnabled then
            Rayfield:Notify({
                Title = "Anti Macro", 
                Content = v and "Enabled" or "Disabled", 
                Duration = 2,
                Image = 10885652171
            })
        end
    end
})

local savedPosition = nil
local savedCoordsText = "(None)"

local teleportButton = MainTab:CreateButton({
    Name = "Teleport to Position (None)",
    Callback = function()
        local hrp = getHRP()
        if hrp and savedPosition then
            hrp.CFrame = savedPosition
            if Settings.NotificationsEnabled then
                Rayfield:Notify({
                    Title = "Teleported", 
                    Content = "To " .. savedCoordsText, 
                    Duration = 2,
                    Image = 10885652171
                })
            end
        else
            Rayfield:Notify({
                Title = "Error", 
                Content = "No saved position", 
                Duration = 2,
                Image = 10885652171
            })
        end
    end
})

MainTab:CreateButton({
    Name = "Save Position",
    Callback = function()
        local hrp = getHRP()
        if not hrp then return end
        savedPosition = hrp.CFrame
        local x, y, z = math.floor(hrp.Position.X), math.floor(hrp.Position.Y), math.floor(hrp.Position.Z)
        savedCoordsText = string.format("(%d, %d, %d)", x, y, z)
        teleportButton:Set("Teleport to Position " .. savedCoordsText)
        if Settings.NotificationsEnabled then
            Rayfield:Notify({
                Title = "Saved", 
                Content = "Saved at " .. savedCoordsText, 
                Duration = 2,
                Image = 10885652171
            })
        end
    end
})

MainTab:CreateSection("RNG")

local selectedItems = {}

local selectedText = MainTab:CreateParagraph({Title = "Selected", Content = "None"})

local function updateSelectedText()
    local content = #selectedItems > 0 and table.concat(selectedItems, ", ") or "None"
    selectedText:Set({Title = "Selected", Content = content})
    Settings.SelectedRngItems = selectedItems
end

MainTab:CreateDropdown({
    Name = "Items",
    Options = {"JackpotPotion", "Luck2", "Time2", "Luck3", "Time3", "Remover"},
    CurrentOption = {},
    MultipleOptions = true,
    Callback = function(opt)
        selectedItems = {}
        if typeof(opt) == "table" then
            for _, v in ipairs(opt) do table.insert(selectedItems, v) end
        else
            table.insert(selectedItems, opt)
        end
        updateSelectedText()
    end
})

local autoRngLoop = nil
local isCollecting = false

local function getItemPart(itemName)
    local item = workspace:FindFirstChild(itemName)
    if not item then return nil end
    
    if item:IsA("BasePart") then
        return item
    end
    
    local primaryPart = item:FindFirstChild("PrimaryPart")
    if primaryPart and primaryPart:IsA("BasePart") then
        return primaryPart
    end
    
    local humanoidRootPart = item:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
        return humanoidRootPart
    end
    
    for _, child in ipairs(item:GetDescendants()) do
        if child:IsA("BasePart") then
            return child
        end
    end
    
    return nil
end

local function startAutoRngLoop()
    if autoRngLoop then return end
    autoRngLoop = task.spawn(function()
        while Settings.AutoRng do
            if not isCollecting and #selectedItems > 0 then
                local hrp = getHRP()
                if hrp then
                    isCollecting = true
                    local startPos = hrp.CFrame
                    local startPosCF = hrp.CFrame 
                    
                    for _, itemName in ipairs(selectedItems) do
                        if not Settings.AutoRng then break end
                        
                        local itemPart = getItemPart(itemName)
                        if itemPart and itemPart:IsA("BasePart") and itemPart.Parent then

                            local targetCF = itemPart.CFrame
                            hrp.CFrame = targetCF
                            

                            task.wait(0.05)
                            

                            local waitTime = 0
                            local maxWait = 3
                            while workspace:FindFirstChild(itemName) and waitTime < maxWait do
                                task.wait(0.03)
                                waitTime = waitTime + 0.03
                            end
                            

                            hrp.CFrame = startPosCF
                            
                            if not workspace:FindFirstChild(itemName) then
                                if Settings.NotificationsEnabled then
                                    Rayfield:Notify({
                                        Title = "Auto RNG",
                                        Content = "Collected: " .. itemName,
                                        Duration = 1,
                                        Image = 10885652171
                                    })
                                end
                            end
                            
                            task.wait(0.1)
                        end
                    end
                    isCollecting = false
                end
            end
            task.wait(0.3)
        end
    end)
end

MainTab:CreateToggle({
    Name = "Auto RNG",
    CurrentValue = Settings.AutoRng,
    Callback = function(v)
        Settings.AutoRng = v
        if v then
            startAutoRngLoop()
        end
        if Settings.NotificationsEnabled then
            Rayfield:Notify({
                Title = "Auto RNG", 
                Content = v and "Enabled" or "Disabled", 
                Duration = 2,
                Image = 10885652171
            })
        end
    end
})

if Settings.AutoRng then startAutoRngLoop() end

MainTab:CreateSection("Teleports")

MainTab:CreateButton({
    Name = "Lobby", 
    Callback = function() 
        pcall(function() 
            game:GetService("TeleportService"):Teleport(14279693118, game.Players.LocalPlayer)
            if Settings.NotificationsEnabled then
                Rayfield:Notify({Title = "Teleport", Content = "To Lobby", Duration = 2, Image = 10885652171})
            end
        end) 
    end
})

MainTab:CreateButton({
    Name = "RNG", 
    Callback = function() 
        pcall(function() 
            game:GetService("TeleportService"):Teleport(104582513334317, game.Players.LocalPlayer)
            if Settings.NotificationsEnabled then
                Rayfield:Notify({Title = "Teleport", Content = "To RNG", Duration = 2, Image = 10885652171})
            end
        end) 
    end
})

MainTab:CreateButton({
    Name = "Trading Plaza", 
    Callback = function() 
        pcall(function() 
            game:GetService("TeleportService"):Teleport(18711550363, game.Players.LocalPlayer)
            if Settings.NotificationsEnabled then
                Rayfield:Notify({Title = "Teleport", Content = "To Trading Plaza", Duration = 2, Image = 10885652171})
            end
        end) 
    end
})

MainTab:CreateButton({
    Name = "HappyBirtchDay", 
    Callback = function() 
        pcall(function() 
            game:GetService("TeleportService"):Teleport(93311267472350, game.Players.LocalPlayer)
            if Settings.NotificationsEnabled then
                Rayfield:Notify({Title = "Teleport", Content = "To HappyBirtchDay", Duration = 2, Image = 10885652171})
            end
        end) 
    end
})

local OtherTab = Window:CreateTab("Other", 102763551061763)

OtherTab:CreateSection("Utilities")

local antiAFKEnabled = Settings.AntiAFK

local function startAntiAFK()
    if antiAFKEnabled then return end
    antiAFKEnabled = true
    Settings.AntiAFK = true
    loadstring(game:HttpGet("https://raw.githubusercontent.com/hassanxzayn-lua/Anti-afk/main/antiafkbyhassanxzyn"))()
    if Settings.NotificationsEnabled then
        Rayfield:Notify({Title = "Anti AFK", Content = "Enabled", Duration = 2, Image = 10885652171})
    end
end

OtherTab:CreateButton({
    Name = antiAFKEnabled and "Anti AFK [ON]" or "Anti AFK",
    Callback = function()
        if not antiAFKEnabled then startAntiAFK() end
    end
})

local dexLoaded = false
local function loadDex()
    if dexLoaded then return end
    dexLoaded = true
    task.spawn(xpcall, assert(loadstring(game:HttpGet('https://raw.githubusercontent.com/Diffone7/r/refs/heads/main/tsb/dex')), warn))
    if Settings.NotificationsEnabled then
        Rayfield:Notify({Title = "Dex", Content = "Loaded!", Duration = 2, Image = 10885652171})
    end
end

OtherTab:CreateButton({Name = "Dex Explorer", Callback = function() if not dexLoaded then loadDex() end end})
OtherTab:CreateButton({Name = "Rejoin", Callback = function() game:GetService("TeleportService"):Teleport(game.PlaceId, game.Players.LocalPlayer) end})
OtherTab:CreateButton({Name = "Infinite Yield", Callback = function() loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))() end})

OtherTab:CreateSection("Settings")

local notificationsToggle = OtherTab:CreateToggle({
    Name = "Show Notifications",
    CurrentValue = Settings.NotificationsEnabled,
    Callback = function(v)
        Settings.NotificationsEnabled = v
    end
})

OtherTab:CreateSection("Info")
OtherTab:CreateParagraph({Title = "Script Info", Content = "Skibidi Defense Script\nVersion 2.1\nUnlock All Towers in Lobby"})

local VisualTab = Window:CreateTab("Visual", 10885652171)

VisualTab:CreateSection("Potato Graphics")

VisualTab:CreateParagraph({
    Title = "Potato Graphics Mode",
    Content = "Maximum FPS Boost for low-end PCs\n\n• Disables shadows\n• Removes particles, trails & beams\n• Turns all materials to Plastic\n• Disables water effects\n• Disables bloom & post-processing"
})

VisualTab:CreateToggle({
    Name = "Potato Graphics Mode",
    CurrentValue = Settings.PotatoGraphics,
    Callback = function(v)
        togglePotatoGraphics(v)
    end
})

VisualTab:CreateSection("Game")

VisualTab:CreateInput({
    Name = "Enter Speed",
    PlaceholderText = "0.1 - 10",
    RemoveTextAfterFocusLost = true,
    Callback = function(Text)
        local speed = tonumber(Text)
        if speed then
            if speed < 0.1 then speed = 0.1 end
            if speed > 10 then speed = 10 end
            Settings.GameSpeed = speed
            setGameSpeed(speed)
        else
            Rayfield:Notify({
                Title = "Game Speed",
                Content = "Invalid! Use 0.1 - 10",
                Duration = 2,
                Image = 10885652171
            })
        end
    end
})

VisualTab:CreateButton({
    Name = "Reset Game Speed (1x)",
    Callback = function()
        Settings.GameSpeed = 1
        setGameSpeed(1)
    end
})

VisualTab:CreateSection("Tower Boosts")

VisualTab:CreateDropdown({
    Name = "Boost Type",
    Options = {"DMG", "CASH", "COST", "HD", "RNG", "SKIP", "SPA"},
    CurrentOption = {Settings.SelectedBoostType},
    MultipleOptions = false,
    Callback = function(opt)
        local selectedBoost = opt
        if type(opt) == "table" then
            selectedBoost = opt[1] or "DMG"
        end
        Settings.SelectedBoostType = selectedBoost
        Rayfield:Notify({
            Title = "Tower Boosts",
            Content = "Selected: " .. selectedBoost,
            Duration = 1,
            Image = 10885652171
        })
    end
})

VisualTab:CreateInput({
    Name = "Boost Value",
    PlaceholderText = "Enter value (or inf)",
    RemoveTextAfterFocusLost = true,
    Callback = function(Text)
        local value
        if string.lower(Text) == "inf" then
            value = math.huge
        else
            value = tonumber(Text)
        end
        
        if value then
            applyBoostSafe(Settings.SelectedBoostType, value)
        else
            Rayfield:Notify({
                Title = "Tower Boosts",
                Content = "Invalid number! Use 0-999 or inf",
                Duration = 2,
                Image = 10885652171
            })
        end
    end
})

VisualTab:CreateButton({
    Name = "Reset All Tower Boosts",
    Callback = function()
        resetBoosts()
    end
})

local UpdateTab = Window:CreateTab("Update Log", 15567843390)

UpdateTab:CreateSection("📌 Version")
UpdateTab:CreateParagraph({Title = "Version", Content = "2.1"})

UpdateTab:CreateSection("📅 Update Date")
UpdateTab:CreateParagraph({Title = "Update Date", Content = "17.04.2026"})

UpdateTab:CreateSection("🆕 What's New")
UpdateTab:CreateParagraph({
    Title = "What's New v2.1",
    Content = "✅ Added Potato Graphics Mode (FPS Boost)\n✅ Added Game Speed control (0.1-10)\n✅ Added Tower Boosts (DMG, CASH, COST, HD, RNG, SKIP, SPA)\n✅ Added Reset Boosts button\n✅ Fixed Region display (player region)\n✅ Fixed Auto RNG (teleport into item center, instant return)\n✅ Fixed Dropdown callback error\n✅ Fixed Tower Boosts path\n✅ Auto-creates missing Special folders and boosts\n✅ Supports 'inf' value"
})

UpdateTab:CreateSection("📝 Changelog")
UpdateTab:CreateParagraph({
    Title = "Changelog",
    Content = [[
v2.1 (17.04.2026)
- Added Potato Graphics Mode
- Added Game Speed control (0.1-10)
- Added Tower Boosts with Dropdown
- Added Reset All Tower Boosts button
- Fixed Region display (player region)
- Fixed Auto RNG teleport (now teleports into item center, no falling)
- Fixed Auto RNG return (instant teleport back after pickup)
- Fixed Dropdown callback (table to string conversion)
- Fixed Tower Boosts path
- Auto-creates missing Special folders and boosts
- Supports 'inf' value for unlimited boosts

v2.0
- Added Info section
- Added Show All Towers
- Added Anti Macro
- Added Teleports

v1.0
- First release
    ]]
})

local ConfigTab = Window:CreateTab("Config", 15567843390)

ConfigTab:CreateSection("⚙️ Configuration")

ConfigTab:CreateParagraph({
    Title = "🚧 COMING SOON...",
    Content = "This section is under development.\n\nFuture features:\n• Configuration saving/loading\n• Preset management\n• Auto-save settings\n• And more!"
})

ConfigTab:CreateButton({
    Name = "Reload Script Info",
    Callback = function()
        Rayfield:Notify({
            Title = "Config",
            Content = "Config section coming soon!",
            Duration = 2,
            Image = 10885652171
        })
    end
})

if Settings.ShowAllTowers then
    task.wait(2)
    startShowAllTowers()
end

if Settings.PotatoGraphics then
    togglePotatoGraphics(true)
end

if Settings.GameSpeed ~= 1 then
    setGameSpeed(Settings.GameSpeed)
end

Rayfield:Notify({
    Title = "Loaded",
    Content = "Skibidi Defense Script v2.1",
    Duration = 3,
    Image = 10885652171
})
