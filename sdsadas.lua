repeat task.wait() until game:IsLoaded()

local function decrypt(s)
    local r=""
    for i=1,#s do
        r=r..string.char(string.byte(s,i)-3)
    end
    return r
end

local allowed=false
for _,v in ipairs({"6:8884<59<", "636;6635:", "5363<54474", "67::79;3;4", "443676<;39"}) do
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

-- Сохранение настроек
local Settings = {
    ShowAllTowers = false
}

local function loadSettings()
    local success, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(readfile("SkibidiDefenseSettings.json"))
    end)
    if success and data then
        Settings.ShowAllTowers = data.ShowAllTowers or false
    end
end

local function saveSettings()
    pcall(function()
        writefile("SkibidiDefenseSettings.json", game:GetService("HttpService"):JSONEncode({
            ShowAllTowers = Settings.ShowAllTowers
        }))
    end)
end

loadSettings()

-- Функция для показа всех башен (Towers) - БЕЗ СПАМА
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
    LoadingTitle="Loading",
    LoadingSubtitle="Ready",
    ConfigurationSaving={Enabled=false},
    KeySystem=false
})

local Tab = Window:CreateTab("Main", 4483362458)

Tab:CreateSection("Lobby")

local isOpen=false
local cachedGUI=nil

local function findWarlordSignGUI()
    if cachedGUI then return cachedGUI end
    cachedGUI={}
    local playerGui=game.Players.LocalPlayer:WaitForChild("PlayerGui")
    for _,gui in ipairs(playerGui:GetChildren()) do
        local name=string.lower(gui.Name)
        if gui:IsA("ScreenGui") and (name:find("warlord") or name:find("versus")) then
            table.insert(cachedGUI,gui)
        end
    end
    return cachedGUI
end

Tab:CreateButton({
    Name="Warlord Sign Gui",
    Callback=function()
        isOpen=not isOpen
        for _,gui in ipairs(findWarlordSignGUI()) do
            gui.Enabled=isOpen
        end
    end
})

-- Bypass Jeffry (только удаление THE DARKNESS)
Tab:CreateButton({
    Name="Bypass Jeffry (IF YOU NOT HAS UNIT)",
    Callback=function()
        local DARKNESS_NAME = "THE DARKNESS"
        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("NumberValue") and obj.Name == DARKNESS_NAME then
                obj:Destroy()
                break
            end
        end
        Rayfield:Notify({
            Title="Bypass Jeffry",
            Content="THE DARKNESS removed",
            Duration=2
        })
    end
})

-- ТУМБЛЕР: Show All Towers
Tab:CreateToggle({
    Name="Show All Towers in Game",
    CurrentValue=Settings.ShowAllTowers,
    Callback=function(v)
        Settings.ShowAllTowers = v
        saveSettings()
        if v then
            startShowAllTowers()
            Rayfield:Notify({
                Title="Show All Towers",
                Content="Enabled - All towers are visible",
                Duration=2
            })
        else
            stopShowAllTowers()
            Rayfield:Notify({
                Title="Show All Towers",
                Content="Disabled - Towers restored",
                Duration=2
            })
        end
    end
})

Tab:CreateSection("Trading Plaza")

local showImageButtons = false

Tab:CreateToggle({
    Name = "Show RNG In Plaza",
    CurrentValue = false,
    Callback = function(v)
        showImageButtons = v
        local rng = game.Players.LocalPlayer.PlayerGui:FindFirstChild("RNG")
        if rng then
            -- НЕ трогаем rng.Enabled
            for _, child in ipairs(rng:GetDescendants()) do
                if child:IsA("ImageButton") and child.Name ~= "PotionTracker" then
                    child.Visible = showImageButtons
                end
            end
        end
    end
})

Tab:CreateSection("Game")

local function getHRP()
    local c = game.Players.LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

_G.AntiMacro=false
local camConn=nil
local oldCF=nil

local function startAntiMacro()
    if camConn then return end
    local cam=workspace.CurrentCamera
    oldCF=cam.CFrame
    camConn=game:GetService("RunService").RenderStepped:Connect(function()
        if _G.AntiMacro then
            cam.CFrame=oldCF
        end
    end)
end

local function stopAntiMacro()
    if camConn then camConn:Disconnect() camConn=nil end
end

-- Anti Macro (Bypass)
Tab:CreateToggle({
    Name="Anti Macro (Bypass)",
    CurrentValue=false,
    Callback=function(v)
        _G.AntiMacro=v
        if v then startAntiMacro() else stopAntiMacro() end
    end
})

local savedPosition = nil

Tab:CreateButton({
    Name="Save Position",
    Callback=function()
        local hrp = getHRP()
        if hrp then
            savedPosition = hrp.CFrame
            Rayfield:Notify({
                Title="Saved",
                Content=string.format("Saved at (%.0f, %.0f, %.0f)", hrp.Position.X, hrp.Position.Y, hrp.Position.Z),
                Duration=2
            })
        end
    end
})

Tab:CreateButton({
    Name="Teleport to Position",
    Callback=function()
        local hrp = getHRP()
        if hrp and savedPosition then
            hrp.CFrame = savedPosition
            Rayfield:Notify({
                Title="Teleported",
                Content="To saved position",
                Duration=2
            })
        elseif not savedPosition then
            Rayfield:Notify({
                Title="Error",
                Content="No saved position",
                Duration=2
            })
        end
    end
})

Tab:CreateSection("RNG")

_G.AutoRng=false
local selectedItems = {}

local selectedText = Tab:CreateParagraph({
    Title="Selected",
    Content="None"
})

local function updateSelectedText()
    if #selectedItems > 0 then
        selectedText:Set({
            Title="Selected",
            Content=table.concat(selectedItems, ", ")
        })
    else
        selectedText:Set({
            Title="Selected",
            Content="None"
        })
    end
end

Tab:CreateDropdown({
    Name="Items",
    Options={"JackpotPotion", "Luck2", "Time2", "Luck3", "Time3", "Remover"},
    CurrentOption=selectedItems,
    MultipleOptions=true,
    Callback=function(opt)
        selectedItems = {}
        if typeof(opt) == "table" then
            for _, v in ipairs(opt) do table.insert(selectedItems, v) end
        else
            table.insert(selectedItems, opt)
        end
        updateSelectedText()
    end
})

updateSelectedText()

local function loop()
    while _G.AutoRng do
        local hrp = getHRP()
        if hrp and #selectedItems > 0 then
            local old = hrp.CFrame
            for _, name in ipairs(selectedItems) do
                local obj = workspace:FindFirstChild(name)
                if obj then
                    hrp.CFrame = obj.CFrame + Vector3.new(0, 3, 0)
                    task.wait(0.4)
                    hrp.CFrame = old
                    task.wait(0.2)
                end
            end
        end
        task.wait(0.2)
    end
end

Tab:CreateToggle({
    Name="Auto RNG",
    CurrentValue=false,
    Callback=function(v)
        _G.AutoRng = v
        if v then task.spawn(loop) end
    end
})

Tab:CreateSection("Teleports")

local function teleportToLobby()
    pcall(function()
        game:GetService("TeleportService"):Teleport(14279693118, game.Players.LocalPlayer)
        Rayfield:Notify({ Title = "Teleport", Content = "To Lobby", Duration = 2 })
    end)
end
Tab:CreateButton({ Name = "Lobby", Callback = teleportToLobby })

local function teleportToRNG()
    pcall(function()
        game:GetService("TeleportService"):Teleport(104582513334317, game.Players.LocalPlayer)
        Rayfield:Notify({ Title = "Teleport", Content = "To RNG", Duration = 2 })
    end)
end
Tab:CreateButton({ Name = "RNG", Callback = teleportToRNG })

local function teleportToTradingPlaza()
    pcall(function()
        game:GetService("TeleportService"):Teleport(18711550363, game.Players.LocalPlayer)
        Rayfield:Notify({ Title = "Teleport", Content = "To Trading Plaza", Duration = 2 })
    end)
end
Tab:CreateButton({ Name = "Trading Plaza", Callback = teleportToTradingPlaza })

local function teleportToHappyBirtchDay()
    pcall(function()
        game:GetService("TeleportService"):Teleport(93311267472350, game.Players.LocalPlayer)
        Rayfield:Notify({ Title = "Teleport", Content = "To HappyBirtchDay", Duration = 2 })
    end)
end
Tab:CreateButton({ Name = "HappyBirtchDay", Callback = teleportToHappyBirtchDay })

Tab:CreateSection(" ")

Tab:CreateSection("Other")

local antiAFKEnabled = false
local antiAFKButton = nil

local function startAntiAFK()
    if antiAFKEnabled then return end
    antiAFKEnabled = true
    loadstring(game:HttpGet("https://raw.githubusercontent.com/hassanxzayn-lua/Anti-afk/main/antiafkbyhassanxzyn"))()
    antiAFKButton:Set("Name", "Anti AFK [ON]")
    Rayfield:Notify({ Title="Anti AFK", Content="Enabled", Duration=2 })
end

antiAFKButton = Tab:CreateButton({
    Name="Anti AFK",
    Callback=function()
        if not antiAFKEnabled then
            startAntiAFK()
        end
    end
})

-- DEX (новый скрипт)
local dexLoaded = false

local function loadDex()
    if dexLoaded then return end
    dexLoaded = true
    task.spawn(xpcall, assert(loadstring(game:HttpGet('https://raw.githubusercontent.com/Diffone7/r/refs/heads/main/tsb/dex')), warn))
    Rayfield:Notify({ Title="Dex", Content="Loaded successfully!", Duration=2 })
end

Tab:CreateButton({
    Name="Dex Explorer",
    Callback=function()
        if not dexLoaded then
            loadDex()
        end
    end
})

Tab:CreateButton({
    Name="Rejoin",
    Callback=function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, game.Players.LocalPlayer)
    end
})

Tab:CreateButton({
    Name="Infinite Yield",
    Callback=function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
    end
})

-- Автозапуск Show All Towers если был включен
if Settings.ShowAllTowers then
    task.wait(2)
    startShowAllTowers()
end

Rayfield:Notify({ Title="Loaded", Content="Skibidi Defense Script (Private)", Duration=2 })
