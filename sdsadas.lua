-- Система ключей через GitHub
local keysURL = "https://raw.githubusercontent.com/MrAdivikPlayYT/sdkasjdskfjasd/refs/heads/main/keys.txt?token=GHSAT0AAAAAADZQGTOBHSEPSWV36ACZKVEE2OTZYWA"

local keyAccepted = false

local function loadKeysFromGitHub()
    local success, data = pcall(function()
        return game:HttpGet(keysURL)
    end)
    
    if success then
        local validKeys = {}
        for line in string.gmatch(data, "[^\r\n]+") do
            validKeys[line] = true
        end
        print("[Система] Ключи загружены, найдено: " .. #validKeys)
        return validKeys
    else
        print("[Ошибка] Не удалось загрузить ключи: " .. tostring(data))
        return {}
    end
end

local function createKeyGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KeySystem"
    screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 350, 0, 220)
    frame.Position = UDim2.new(0.5, -175, 0.5, -110)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    -- Заголовок
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 45)
    title.Text = "🔐 Введите ключ доступа"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 18
    title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    title.Parent = frame
    
    -- Поле ввода ключа
    local keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(0.8, 0, 0, 40)
    keyBox.Position = UDim2.new(0.1, 0, 0, 60)
    keyBox.PlaceholderText = "XXXXX-XXXXX-XXXXX"
    keyBox.Text = ""
    keyBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    keyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyBox.TextSize = 14
    keyBox.Parent = frame
    
    -- Кнопка подтверждения
    local submitBtn = Instance.new("TextButton")
    submitBtn.Size = UDim2.new(0.4, 0, 0, 40)
    submitBtn.Position = UDim2.new(0.3, 0, 0, 115)
    submitBtn.Text = "Подтвердить"
    submitBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    submitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    submitBtn.TextSize = 16
    submitBtn.Parent = frame
    
    -- Статус
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 35)
    status.Position = UDim2.new(0, 0, 0, 170)
    status.Text = "📡 Загрузка ключей..."
    status.TextColor3 = Color3.fromRGB(200, 200, 200)
    status.TextSize = 12
    status.BackgroundTransparency = 1
    status.Parent = frame
    
    -- Загружаем ключи
    local validKeys = loadKeysFromGitHub()
    
    if next(validKeys) == nil then
        status.Text = "❌ Ошибка загрузки ключей! Перезапустите скрипт"
        status.TextColor3 = Color3.fromRGB(255, 0, 0)
        return
    end
    
    status.Text = "✅ Введите ключ из 15 символов"
    status.TextColor3 = Color3.fromRGB(0, 255, 0)
    
    submitBtn.MouseButton1Click:Connect(function()
        local inputKey = keyBox.Text
        if validKeys[inputKey] then
            keyAccepted = true
            status.Text = "✅ Ключ принят! Загрузка..."
            status.TextColor3 = Color3.fromRGB(0, 255, 0)
            submitBtn.Visible = false
            keyBox.Visible = false
            task.wait(1)
            screenGui:Destroy()
        else
            status.Text = "❌ Неверный ключ! Попробуйте снова"
            status.TextColor3 = Color3.fromRGB(255, 0, 0)
            keyBox.Text = ""
        end
    end)
end

-- Запуск системы ключей
createKeyGUI()
repeat task.wait() until keyAccepted == true

print("[Система] Доступ разрешен!")

-- ============================================
-- ДАЛЕЕ ВАШ ОСНОВНОЙ СКРИПТ
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

-- Warlord Sign Gui
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

AllTab:CreateSection("Lobby")
AllTab:CreateButton({ Name = "Warlord Sign Gui", Callback = switchWarlordSignGUI })
AllTab:CreateSection(" ")

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

-- Anti AFK (только 1 раз)
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

AllTab:CreateSection("Game")
AllTab:CreateToggle({ Name = "Anti Macro", CurrentValue = false, Callback = function(value) _G.AntiMacro = value; if value then startAntiMacro() else stopAntiMacro() end end })
AllTab:CreateButton({ Name = "Anti AFK", Callback = loadAntiAfk })
AllTab:CreateSection(" ")

-- Auto Rng Items
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

AllTab:CreateSection("RNG")
AllTab:CreateToggle({ Name = "Auto Rng Items", CurrentValue = false, Callback = function(value) _G.AutoRng = value; if value then autoRngThread = coroutine.wrap(autoRngLoop); autoRngThread() end end })

print("[Скрипт] Загружен успешно!")
Rayfield:Notify({ Title = "Скрипт", Content = "Загружен успешно!", Duration = 3 })
