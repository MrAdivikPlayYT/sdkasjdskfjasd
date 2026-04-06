-- ============================================
-- СКРИПТ СКИБИДИ ДИФЕНС + INFINITE YIELD
-- ============================================

-- Обычные переменные для отвлечения
local settings = {
    version = "1.0.0",
    author = "unknown",
    debug = false
}

local config = {
    speed = 100,
    jumpPower = 50,
    license = "X7K9P-3M2N8-L4R1Q",
    autoSave = true
}

local userData = {
    name = "",
    level = 1,
    exp = 0
}

local function validateLicense(input)
    return input == config.license
end

local keyAccepted = false

local function showKeyWindow()
    local gui = Instance.new("ScreenGui")
    gui.Name = "Auth"
    gui.Parent = game.Players.LocalPlayer.PlayerGui
    
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 300, 0, 150)
    main.Position = UDim2.new(0.5, -150, 0.5, -75)
    main.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    main.Parent = gui
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Text = "Введите ключ"
    title.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Parent = main
    
    local input = Instance.new("TextBox")
    input.Size = UDim2.new(0.8, 0, 0, 35)
    input.Position = UDim2.new(0.1, 0, 0, 50)
    input.PlaceholderText = "XXXXX-XXXXX-XXXXX"
    input.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    input.TextColor3 = Color3.fromRGB(255, 255, 255)
    input.Parent = main
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.4, 0, 0, 35)
    btn.Position = UDim2.new(0.3, 0, 0, 95)
    btn.Text = "Войти"
    btn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Parent = main
    
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 25)
    status.Position = UDim2.new(0, 0, 0, 135)
    status.Text = ""
    status.BackgroundTransparency = 1
    status.TextColor3 = Color3.fromRGB(200, 200, 200)
    status.TextSize = 12
    status.Parent = main
    
    btn.MouseButton1Click:Connect(function()
        if validateLicense(input.Text) then
            status.Text = "✅ Успешно!"
            status.TextColor3 = Color3.fromRGB(0, 255, 0)
            task.wait(0.5)
            keyAccepted = true
            gui:Destroy()
        else
            status.Text = "❌ Неверный ключ"
            status.TextColor3 = Color3.fromRGB(255, 0, 0)
            input.Text = ""
        end
    end)
end

showKeyWindow()
repeat task.wait() until keyAccepted == true

-- ============================================
-- ОСНОВНОЙ СКРИПТ (Rayfield)
-- ============================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Skibidi Defense Script",
   LoadingTitle = "Loading...",
   LoadingSubtitle = "Optimized",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false
})

local AllTab = Window:CreateTab("All", 4483362458)

-- ===== LOBBY SECTION =====
AllTab:CreateSection("Lobby")

local isOpen = false
local cachedGUI = nil

local function findWarlordSignGUI()
    if cachedGUI then return cachedGUI end
    cachedGUI = {}
    local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    for _, gui in ipairs(playerGui:GetChildren()) do
        local name = string.lower(gui.Name)
        if gui:IsA("ScreenGui") and (name:find("warlord") or name:find("warlordsign") or name:find("versus")) then
            table.insert(cachedGUI, gui)
        end
    end
    return cachedGUI
end

local function switchWarlordSignGUI()
    isOpen = not isOpen
    for _, gui in ipairs(findWarlordSignGUI()) do
        gui.Enabled = isOpen
    end
    if isOpen then
        Rayfield:Notify({ Title = "Warlord Sign Gui", Content = "GUI открыт", Duration = 2 })
    else
        Rayfield:Notify({ Title = "Warlord Sign Gui", Content = "GUI закрыт", Duration = 2 })
    end
end

AllTab:CreateButton({ Name = "Warlord Sign Gui", Callback = switchWarlordSignGUI })
AllTab:CreateSection(" ")

-- ===== GAME SECTION =====
AllTab:CreateSection("Game")

-- Anti Macro
_G.AntiMacro = false
local antiMacroConnection = nil
local originalCFrame = nil

local function startAntiMacro()
    if antiMacroConnection then return end
    local player = game.Players.LocalPlayer
    local camera = workspace.CurrentCamera
    originalCFrame = camera.CFrame
    antiMacroConnection = game:GetService("RunService").RenderStepped:Connect(function()
        if _G.AntiMacro then
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                camera.CameraSubject = player.Character.Humanoid
            end
            camera.CFrame = originalCFrame
        end
    end)
end

local function stopAntiMacro()
    if antiMacroConnection then
        antiMacroConnection:Disconnect()
        antiMacroConnection = nil
    end
end

AllTab:CreateToggle({ Name = "Anti Macro", CurrentValue = false, Callback = function(value) _G.AntiMacro = value; if value then startAntiMacro() else stopAntiMacro() end end })

-- Anti AFK
local antiAfkLoaded = false
local antiAfkButtonPressed = false

local function loadAntiAfk()
    if antiAfkLoaded then
        Rayfield:Notify({ Title = "Anti AFK", Content = "Уже загружен!", Duration = 2 })
        return
    end
    if antiAfkButtonPressed then
        Rayfield:Notify({ Title = "Anti AFK", Content = "Можно нажать только 1 раз!", Duration = 2 })
        return
    end
    antiAfkButtonPressed = true
    local success = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/hassanxzayn-lua/Anti-afk/main/antiafkbyhassanxzyn"))()
        antiAfkLoaded = true
        Rayfield:Notify({ Title = "Anti AFK", Content = "Успешно загружен!", Duration = 3 })
    end)
    if not success then
        antiAfkButtonPressed = false
        Rayfield:Notify({ Title = "Anti AFK", Content = "Ошибка загрузки!", Duration = 3 })
    end
end

AllTab:CreateButton({ Name = "Anti AFK", Callback = loadAntiAfk })
AllTab:CreateSection(" ")

-- ===== RNG SECTION =====
AllTab:CreateSection("RNG")

_G.AutoRng = false
local autoRngThread = nil
local localPlayer = game.Players.LocalPlayer
local targetObjects = {"JackpotPotion", "Luck2", "Time2", "Luck3", "Time3", "Remover"}

local function getHumanoidRootPart()
    local char = localPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function autoRngLoop()
    while _G.AutoRng do
        local hrp = getHumanoidRootPart()
        if hrp then
            for _, targetName in ipairs(targetObjects) do
                local obj = workspace:FindFirstChild(targetName)
                if obj and obj:IsA("BasePart") and obj.Parent ~= localPlayer.Character then
                    hrp.CFrame = obj.CFrame + Vector3.new(0, 3, 0)
                    task.wait(0.5)
                    break
                end
            end
        end
        task.wait(0.3)
    end
end

AllTab:CreateToggle({ Name = "Auto Rng Items", CurrentValue = false, Callback = function(value) _G.AutoRng = value; if value then autoRngThread = coroutine.wrap(autoRngLoop); autoRngThread() end end })
AllTab:CreateSection(" ")

-- ===== OTHER SECTION (Infinite Yield) =====
AllTab:CreateSection("Other")

-- Infinite Yield кнопка (рабочая)
AllTab:CreateButton({
    Name = "Infinite Yield",
    Callback = function()
        local success, err = pcall(function()
            local iy = loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source.lua'))
            if iy then
                iy()
                Rayfield:Notify({
                    Title = "Infinite Yield",
                    Content = "Загружен!",
                    Duration = 2
                })
            else
                Rayfield:Notify({
                    Title = "Ошибка",
                    Content = "Не удалось загрузить!",
                    Duration = 2
                })
            end
        end)
        if not success then
            Rayfield:Notify({
                Title = "Ошибка",
                Content = "Не удалось загрузить!",
                Duration = 2
            })
        end
    end
})

print("[СКРИПТ] Загружен!")
Rayfield:Notify({ Title = "Скрипт", Content = "Загружен!", Duration = 3 })
