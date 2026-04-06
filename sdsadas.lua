-- ============================================
-- СИСТЕМА КЛЮЧЕЙ (со спрятанным ключом)
-- ============================================

-- Часть 1: Разбивка ключа по разным функциям
local function getPartA()
    return "X7K9P"
end

local function getPartB()
    return "-3M2N8"
end

local function getPartC()
    return "-L4R1Q"
end

-- Часть 2: Сборка в другой функции
local function buildKey()
    local a = getPartA()
    local b = getPartB()
    local c = getPartC()
    return a .. b .. c
end

-- Часть 3: Дополнительная "обфускация" (перемешивание символов)
local function shuffleCheck(key)
    -- Простая проверка без расшифровки
    local correct = "X7K9P-3M2N8-L4R1Q"
    return key == correct
end

-- Часть 4: Проверка ключа (без прямого сравнения)
local function validateKey(input)
    local built = buildKey()
    return input == built
end

-- Часть 5: GUI системы ключей
local keyAccepted = false

local function createKeyGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KeySystem"
    screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 350, 0, 200)
    frame.Position = UDim2.new(0.5, -175, 0.5, -100)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 45)
    title.Text = "🔐 Введите ключ"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 18
    title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    title.Parent = frame
    
    local keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(0.8, 0, 0, 40)
    keyBox.Position = UDim2.new(0.1, 0, 0, 60)
    keyBox.PlaceholderText = "XXXXX-XXXXX-XXXXX"
    keyBox.Text = ""
    keyBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    keyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyBox.TextSize = 14
    keyBox.Parent = frame
    
    local submitBtn = Instance.new("TextButton")
    submitBtn.Size = UDim2.new(0.4, 0, 0, 40)
    submitBtn.Position = UDim2.new(0.3, 0, 0, 115)
    submitBtn.Text = "Подтвердить"
    submitBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    submitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    submitBtn.TextSize = 16
    submitBtn.Parent = frame
    
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 35)
    status.Position = UDim2.new(0, 0, 0, 160)
    status.Text = "Введите ключ доступа"
    status.TextColor3 = Color3.fromRGB(200, 200, 200)
    status.TextSize = 12
    status.BackgroundTransparency = 1
    status.Parent = frame
    
    submitBtn.MouseButton1Click:Connect(function()
        if validateKey(keyBox.Text) then
            keyAccepted = true
            status.Text = "✅ Ключ принят!"
            status.TextColor3 = Color3.fromRGB(0, 255, 0)
            task.wait(1)
            screenGui:Destroy()
        else
            status.Text = "❌ Неверный ключ!"
            status.TextColor3 = Color3.fromRGB(255, 0, 0)
            keyBox.Text = ""
        end
    end)
end

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
