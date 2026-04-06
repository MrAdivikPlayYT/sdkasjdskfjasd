-- ============================================
-- ОБФУСЦИРОВАННАЯ СИСТЕМА КЛЮЧЕЙ
-- ============================================

-- Часть ключа 1 (X7K9P) - разбита на символы
local _a = "X"
local _b = "7"
local _c = "K"
local _d = "9"
local _e = "P"

-- Где-то в середине скрипта (переменные для других целей)
local someValue = 100
local anotherValue = 500
local tempData = {}

-- Часть ключа 2 (-3M2N8) - спрятана в таблице
local hiddenParts = {
    ["sep1"] = "-",
    ["num1"] = "3",
    ["letter1"] = "M",
    ["num2"] = "2",
    ["letter2"] = "N",
    ["num3"] = "8"
}

-- Функция для сбора первой части
local function getFirstPart()
    return _a .. _b .. _c .. _d .. _e
end

-- Функция для сбора второй части
local function getSecondPart()
    return hiddenParts["sep1"] .. hiddenParts["num1"] .. hiddenParts["letter1"] .. 
           hiddenParts["num2"] .. hiddenParts["letter2"] .. hiddenParts["num3"]
end

-- Часть ключа 3 (-L4R1Q) - спрятана в другой таблице
local keySuffix = {
    [1] = "-",
    [2] = "L",
    [3] = "4",
    [4] = "R",
    [5] = "1",
    [6] = "Q"
}

-- Функция для сбора третьей части
local function getThirdPart()
    local result = ""
    for i = 1, 6 do
        result = result .. keySuffix[i]
    end
    return result
end

-- Рандомная функция для отвлечения
local function calculateSomething(a, b)
    return a + b
end

-- Еще одна рандомная переменная
local randomString = "nothing"

-- Функция сборки полного ключа (вызвана глубоко)
local function buildFullKey()
    local first = getFirstPart()
    local second = getSecondPart()
    local third = getThirdPart()
    return first .. second .. third
end

-- Проверка ключа
local function checkKey(input)
    local correct = buildFullKey()
    return input == correct
end

-- ============================================
-- GUI СИСТЕМЫ КЛЮЧЕЙ
-- ============================================
local keyAccepted = false

local function createKeyGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AuthSystem"
    screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 350, 0, 200)
    frame.Position = UDim2.new(0.5, -175, 0.5, -100)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 45)
    title.Text = "🔐 АВТОРИЗАЦИЯ"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 20
    title.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    title.Parent = frame
    
    local keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(0.8, 0, 0, 40)
    keyBox.Position = UDim2.new(0.1, 0, 0, 60)
    keyBox.PlaceholderText = "XXXXX-XXXXX-XXXXX"
    keyBox.Text = ""
    keyBox.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    keyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyBox.TextSize = 14
    keyBox.Parent = frame
    
    local submitBtn = Instance.new("TextButton")
    submitBtn.Size = UDim2.new(0.4, 0, 0, 40)
    submitBtn.Position = UDim2.new(0.3, 0, 0, 115)
    submitBtn.Text = "ВОЙТИ"
    submitBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
    submitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    submitBtn.TextSize = 16
    submitBtn.Parent = frame
    
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 35)
    status.Position = UDim2.new(0, 0, 0, 160)
    status.Text = "Введите лицензионный ключ"
    status.TextColor3 = Color3.fromRGB(180, 180, 180)
    status.TextSize = 12
    status.BackgroundTransparency = 1
    status.Parent = frame
    
    submitBtn.MouseButton1Click:Connect(function()
        if checkKey(keyBox.Text) then
            keyAccepted = true
            status.Text = "✅ ДОСТУП РАЗРЕШЕН!"
            status.TextColor3 = Color3.fromRGB(0, 255, 0)
            submitBtn.Visible = false
            keyBox.Visible = false
            task.wait(1.5)
            screenGui:Destroy()
        else
            status.Text = "❌ НЕВЕРНЫЙ КЛЮЧ!"
            status.TextColor3 = Color3.fromRGB(255, 0, 0)
            keyBox.Text = ""
        end
    end)
end

-- Запуск проверки ключа
createKeyGUI()
repeat task.wait() until keyAccepted == true

print("[AUTH] Доступ разрешен!")

-- ============================================
-- ОСНОВНОЙ СКРИПТ (Rayfield UI)
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

print("[SCRIPT] Загружен успешно!")
Rayfield:Notify({ Title = "Скрипт", Content = "Загружен успешно!", Duration = 3 })
