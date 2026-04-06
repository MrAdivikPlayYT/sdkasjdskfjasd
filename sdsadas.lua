-- ============================================
-- ЗАЩИТА ОТ НЕСКОЛЬКИХ GUI (удаляет старый, загружает новый)
-- ============================================

-- Удаляем старый GUI если есть
local function unloadOldScript()
    -- Удаляем защитную метку
    local oldProtection = game:GetService("CoreGui"):FindFirstChild("SkibidiProtection")
    if oldProtection then
        oldProtection:Destroy()
    end
    
    -- Закрываем старое окно Rayfield если есть
    local rayfieldGui = game:GetService("CoreGui"):FindFirstChild("Rayfield")
    if rayfieldGui then
        rayfieldGui:Destroy()
    end
    
    -- Удаляем старую систему ключей
    local keyGui = game.Players.LocalPlayer.PlayerGui:FindFirstChild("KeySystem")
    if keyGui then
        keyGui:Destroy()
    end
    
    -- Удаляем другие возможные GUI
    for _, gui in ipairs(game.Players.LocalPlayer.PlayerGui:GetChildren()) do
        if gui.Name == "KeySystem" or gui.Name == "Auth" then
            gui:Destroy()
        end
    end
    
    print("[Система] Старый GUI удалён, загружаем новый...")
end

-- Запускаем очистку перед загрузкой
unloadOldScript()

-- Создаём новую защитную метку
local protectionGui = Instance.new("ScreenGui")
protectionGui.Name = "SkibidiProtection"
protectionGui.Parent = game:GetService("CoreGui")

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

-- ============================================
-- НОВЫЙ ДИЗАЙН ОКНА ВВОДА КЛЮЧА (тёмный, закруглённый)
-- ============================================
local function showKeyWindow()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KeySystem"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Главное окно (закруглённое)
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 380, 0, 220)
    mainFrame.Position = UDim2.new(0.5, -190, 0.5, -110)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    mainFrame.BackgroundTransparency = 0
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui
    
    -- Скругление углов
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    -- Обводка
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 70)
    stroke.Thickness = 1
    stroke.Parent = mainFrame
    
    -- Верхняя панель
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 50)
    topBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    topBar.BorderSizePixel = 0
    topBar.Parent = mainFrame
    
    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = UDim.new(0, 12)
    topCorner.Parent = topBar
    
    -- Заголовок "KEY"
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "KEY"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.Parent = topBar
    
    -- Иконка замка
    local lockIcon = Instance.new("TextLabel")
    lockIcon.Size = UDim2.new(0, 40, 1, 0)
    lockIcon.Position = UDim2.new(0, 10, 0, 0)
    lockIcon.BackgroundTransparency = 1
    lockIcon.Text = "🔐"
    lockIcon.TextSize = 22
    lockIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
    lockIcon.Parent = topBar
    
    -- Поле ввода ключа
    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(0.8, 0, 0, 45)
    inputBox.Position = UDim2.new(0.1, 0, 0, 75)
    inputBox.PlaceholderText = "XXXX-XXXX-XXXX-XXXX"
    inputBox.Text = ""
    inputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    inputBox.TextSize = 16
    inputBox.Font = Enum.Font.Gotham
    inputBox.ClearTextOnFocus = false
    inputBox.Parent = mainFrame
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = inputBox
    
    -- Кнопка подтверждения
    local submitBtn = Instance.new("TextButton")
    submitBtn.Size = UDim2.new(0.4, 0, 0, 45)
    submitBtn.Position = UDim2.new(0.3, 0, 0, 140)
    submitBtn.Text = "ВОЙТИ"
    submitBtn.BackgroundColor3 = Color3.fromRGB(0, 130, 0)
    submitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    submitBtn.TextSize = 16
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.Parent = mainFrame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = submitBtn
    
    -- Статус
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 30)
    statusLabel.Position = UDim2.new(0, 0, 0, 190)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.TextSize = 12
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = mainFrame
    
    -- Анимация кнопки
    submitBtn.MouseEnter:Connect(function()
        submitBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    end)
    
    submitBtn.MouseLeave:Connect(function()
        submitBtn.BackgroundColor3 = Color3.fromRGB(0, 130, 0)
    end)
    
    -- Обработка ввода ключа
    submitBtn.MouseButton1Click:Connect(function()
        local enteredKey = inputBox.Text
        if validateLicense(enteredKey) then
            statusLabel.Text = "✅ ДОСТУП РАЗРЕШЁН"
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            submitBtn.Visible = false
            inputBox.Visible = false
            task.wait(1)
            keyAccepted = true
            screenGui:Destroy()
        else
            statusLabel.Text = "❌ НЕВЕРНЫЙ КЛЮЧ"
            statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            inputBox.Text = ""
            -- Эффект встряски
            local originalPos = mainFrame.Position
            for i = 1, 4 do
                mainFrame.Position = UDim2.new(0.5, -190 + (i % 2 == 0 and 5 or -5), 0.5, -110)
                task.wait(0.02)
            end
            mainFrame.Position = originalPos
            task.wait(0.5)
            statusLabel.Text = ""
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

-- ===== TELEPORTS SECTION =====
AllTab:CreateSection("Teleports")

-- Teleport Lobby
local function teleportToLobby()
    pcall(function()
        game:GetService("TeleportService"):Teleport(14279693118, game.Players.LocalPlayer)
        Rayfield:Notify({ Title = "Teleport", Content = "Телепорт в лобби...", Duration = 2 })
    end)
end
AllTab:CreateButton({ Name = "Teleport Lobby", Callback = teleportToLobby })

-- Teleport RNG
local function teleportToRNG()
    pcall(function()
        game:GetService("TeleportService"):Teleport(104582513334317, game.Players.LocalPlayer)
        Rayfield:Notify({ Title = "Teleport", Content = "Телепорт в RNG...", Duration = 2 })
    end)
end
AllTab:CreateButton({ Name = "Teleport RNG", Callback = teleportToRNG })

-- Teleport Trading Plaza
local function teleportToTradingPlaza()
    pcall(function()
        game:GetService("TeleportService"):Teleport(18711550363, game.Players.LocalPlayer)
        Rayfield:Notify({ Title = "Teleport", Content = "Телепорт в Trading Plaza...", Duration = 2 })
    end)
end
AllTab:CreateButton({ Name = "Teleport Trading Plaza", Callback = teleportToTradingPlaza })

AllTab:CreateSection(" ")

-- ===== OTHER SECTION (Infinite Yield) =====
AllTab:CreateSection("Other")

-- Infinite Yield
local iyLoaded = false
local iyButtonPressed = false

local function loadInfiniteYield()
    if iyLoaded then
        Rayfield:Notify({ Title = "Infinite Yield", Content = "Уже загружен!", Duration = 2 })
        return
    end
    if iyButtonPressed then
        Rayfield:Notify({ Title = "Infinite Yield", Content = "Можно нажать только 1 раз!", Duration = 2 })
        return
    end
    iyButtonPressed = true
    
    Rayfield:Notify({ Title = "Infinite Yield", Content = "Загрузка...", Duration = 2 })
    
    local success = pcall(function()
        local scriptContent = game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source')
        loadstring(scriptContent)()
        iyLoaded = true
        Rayfield:Notify({ Title = "Infinite Yield", Content = "Успешно загружен!", Duration = 3 })
    end)
    
    if not success then
        iyButtonPressed = false
        Rayfield:Notify({ Title = "Infinite Yield", Content = "Ошибка загрузки!", Duration = 3 })
    end
end

AllTab:CreateButton({ Name = "Infinite Yield", Callback = loadInfiniteYield })

print("[СКРИПТ] Загружен!")
Rayfield:Notify({ Title = "Скрипт", Content = "Загружен!", Duration = 3 })
