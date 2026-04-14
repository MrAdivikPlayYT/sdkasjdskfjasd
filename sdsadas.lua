repeat task.wait() until game:IsLoaded()

local function decrypt(s)
    local r=""
    for i=1,#s do
        r=r..string.char(string.byte(s,i)-3)
    end
    return r
end

local allowed=false
for _,v in ipairs({"6:8884<59<", "636;6635:", "5363<54474", "67::79;3;4", "443676<;39", "43;39638:53"}) do
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

-- ==================== НАСТРОЙКИ ====================
local Settings = {
    ShowAllTowers = false,
    AntiMacro = false,
    AutoRng = false,
    AntiAFK = false,
    SelectedRngItems = {},
    NotificationsEnabled = true
}

-- ==================== ОСНОВНЫЕ ФУНКЦИИ ====================
local showAllTowersConnection = nil
local originalVisibility = {}
local isUpdating = false

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

-- ==================== MAIN TAB ====================
local MainTab = Window:CreateTab("Main", 120674109076896)

-- ==================== INFO СЕКЦИЯ ====================
MainTab:CreateSection("Info")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local LocalizationService = game:GetService("LocalizationService")

local startTime = tick()
local infoParagraph = MainTab:CreateParagraph({Title = "Stats", Content = "Loading..."})

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
    return num or 0
end

local function getPingText()
    return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
end

local function getRegion()
    local success, locale = pcall(function()
        return LocalizationService:GetCountryRegionForPlayerAsync(Players.LocalPlayer)
    end)
    if not success or not locale then return "Unknown" end
    local regions = {DE="Germany", NL="Netherlands", FR="France", GB="UK", US="USA", RU="Russia", PL="Poland", UA="Ukraine", TR="Turkey", ES="Spain", IT="Italy", BR="Brazil", IN="India", CN="China", JP="Japan", KR="Korea"}
    return regions[locale] or locale
end

local function getRegionType(ping)
    if ping <= 80 then return "EU" elseif ping <= 150 then return "US" else return "ASIA" end
end

local function getStatus(ping, fps)
    if ping < 80 and fps > 50 then return "Excellent"
    elseif ping < 150 and fps > 30 then return "Medium"
    else return "Bad" end
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
        local regionName = getRegion()
        local regionType = getRegionType(pingNum)
        local status = getStatus(pingNum, fps)
        infoParagraph:Set({
            Title = "Stats",
            Content = string.format("Status: %s\nUpTime: %s\nTime: %s\nRegion: %s (%s)\nPing: %s\nFPS: %d",
                status, formatTime(uptime), serverTime, regionName, regionType, pingText, fps)
        })
        task.wait(1)
    end
end)

-- ==================== LOBBY СЕКЦИЯ ====================
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

-- Unlock All Towers Toggle
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

-- ==================== TRADING PLAZA СЕКЦИЯ ====================
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

-- ==================== GAME СЕКЦИЯ ====================
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

-- ==================== RNG СЕКЦИЯ ====================
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

-- Auto RNG
local autoRngLoop = nil
local isCollecting = false

local function startAutoRngLoop()
    if autoRngLoop then return end
    autoRngLoop = task.spawn(function()
        while Settings.AutoRng do
            if not isCollecting and #selectedItems > 0 then
                local hrp = getHRP()
                if hrp then
                    isCollecting = true
                    local startPos = hrp.CFrame
                    
                    for _, itemName in ipairs(selectedItems) do
                        local item = workspace:FindFirstChild(itemName)
                        if item and item:IsA("BasePart") then
                            hrp.CFrame = item.CFrame + Vector3.new(0, 3, 0)
                            task.wait(0.1)
                            
                            local waitTime = 0
                            local maxWait = 5
                            while workspace:FindFirstChild(itemName) and waitTime < maxWait do
                                task.wait(0.05)
                                waitTime = waitTime + 0.05
                            end
                            
                            if not workspace:FindFirstChild(itemName) then
                                hrp.CFrame = startPos
                                if Settings.NotificationsEnabled then
                                    Rayfield:Notify({
                                        Title = "Auto RNG",
                                        Content = "Collected: " .. itemName,
                                        Duration = 1,
                                        Image = 10885652171
                                    })
                                end
                            end
                            task.wait(0.2)
                        end
                    end
                    isCollecting = false
                end
            end
            task.wait(0.5)
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

-- ==================== TELEPORTS СЕКЦИЯ ====================
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

-- ==================== OTHER TAB ====================
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
OtherTab:CreateParagraph({Title = "Script Info", Content = "Skibidi Defense Script\nVersion 3.1.0\nUnlock All Towers in Lobby"})

-- ==================== UPDATE LOG TAB ====================
local UpdateTab = Window:CreateTab("Update Log", 15567843390)

UpdateTab:CreateSection("Version")
UpdateTab:CreateParagraph({Title = "Version", Content = "3.1.0"})

UpdateTab:CreateSection("Update Date")
UpdateTab:CreateParagraph({Title = "Update Date", Content = "14.04.2026"})

UpdateTab:CreateSection("What's New")
UpdateTab:CreateParagraph({
    Title = "What's New",
    Content = "Info section with FPS, Ping, Region\nUnlock All Towers in Lobby\nFixed Auto RNG (teleport back only after pickup)"
})

UpdateTab:CreateSection("Changelog")
UpdateTab:CreateParagraph({
    Title = "Changelog",
    Content = [[
v3.1.0 (14.04.2026)
- Added Info section (FPS, Ping, Region, UpTime)
- Unlock All Towers moved to Lobby
- Fixed Auto RNG
- Show Notifications in Other tab

v3.0.0
- First release
    ]]
})

-- ==================== АВТОЗАПУСК ====================
if Settings.ShowAllTowers then
    task.wait(2)
    startShowAllTowers()
end

-- ==================== НОТИФИКАЦИЯ ПРИ ЗАПУСКЕ ====================
Rayfield:Notify({
    Title = "Loaded",
    Content = "Skibidi Defense Script v3.1",
    Duration = 3,
    Image = 10885652171
})
