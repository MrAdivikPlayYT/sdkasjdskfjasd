local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Skibidi Defense Script",
   LoadingTitle = "Loading...",
   LoadingSubtitle = "Optimized",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false
})

-- =========================
-- ОДИН ТАБ - ALL
-- =========================
local AllTab = Window:CreateTab("All", 4483362458)

-- =========================
-- GUI (Warlord Sign Gui)
-- =========================

local isOpen = false
local cachedGUI = nil

local function findWarlordSignGUI()
    if cachedGUI then return cachedGUI end

    cachedGUI = {}
    local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")

    for _, gui in ipairs(playerGui:GetChildren()) do
        local name = string.lower(gui.Name)

        if gui:IsA("ScreenGui") and (
            name:find("warlord") or
            name:find("warlordsign") or
            name:find("versus")
        ) then
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
        print("[Warlord Sign Gui] Открыт")
        Rayfield:Notify({
            Title = "Warlord Sign Gui",
            Content = "GUI открыт",
            Duration = 2
        })
    else
        print("[Warlord Sign Gui] Закрыт")
        Rayfield:Notify({
            Title = "Warlord Sign Gui",
            Content = "GUI закрыт",
            Duration = 2
        })
    end
end

AllTab:CreateSection("Lobby")

AllTab:CreateButton({
   Name = "Warlord Sign Gui",
   Callback = function()
       switchWarlordSignGUI()
   end,
})

AllTab:CreateSection(" ")

-- =========================
-- Protection (Anti Macro + Anti AFK)
-- =========================

-- Anti Macro
_G.AntiMacro = false
local antiMacroConnection = nil
local originalCFrame = nil

local function startAntiMacro()
    if antiMacroConnection then return end
    
    local player = game.Players.LocalPlayer
    local camera = workspace.CurrentCamera
    
    originalCFrame = camera.CFrame
    
    print("[Anti-Macro] Активирован - камера заморожена")
    Rayfield:Notify({
        Title = "Anti Macro",
        Content = "Камера заморожена",
        Duration = 2
    })
    
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
    
    print("[Anti-Macro] Деактивирован - камера разморожена")
    Rayfield:Notify({
        Title = "Anti Macro",
        Content = "Камера разморожена",
        Duration = 2
    })
end

-- Anti AFK (Только 1 раз)
local antiAfkLoaded = false
local antiAfkButtonPressed = false

local function loadAntiAfk()
    if antiAfkLoaded then
        print("[Anti AFK] Уже загружен!")
        Rayfield:Notify({
            Title = "Anti AFK",
            Content = "Уже загружен!",
            Duration = 2
        })
        return
    end
    
    if antiAfkButtonPressed then
        print("[Anti AFK] Кнопка уже была нажата!")
        Rayfield:Notify({
            Title = "Anti AFK",
            Content = "Можно нажать только 1 раз!",
            Duration = 2
        })
        return
    end
    
    antiAfkButtonPressed = true
    
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/hassanxzayn-lua/Anti-afk/main/antiafkbyhassanxzyn"))()
        antiAfkLoaded = true
        print("[Anti AFK] Успешно загружен!")
        Rayfield:Notify({
            Title = "Anti AFK",
            Content = "Успешно загружен!",
            Duration = 3
        })
    end)
    
    if not success then
        antiAfkButtonPressed = false
        print("[Anti AFK] Ошибка загрузки: " .. tostring(err))
        Rayfield:Notify({
            Title = "Anti AFK",
            Content = "Ошибка загрузки!",
            Duration = 3
        })
    end
end

AllTab:CreateSection("Game")

AllTab:CreateToggle({
    Name = "Anti Macro",
    CurrentValue = false,
    Callback = function(value)
        _G.AntiMacro = value
        
        if value then
            startAntiMacro()
        else
            stopAntiMacro()
        end
    end,
})

AllTab:CreateButton({
    Name = "Anti AFK",
    Callback = function()
        loadAntiAfk()
    end,
})

AllTab:CreateSection(" ")

-- =========================
-- Automation (Auto Rng Items)
-- =========================

_G.AutoRng = false
local autoRngThread = nil

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local targetObjects = {"JackpotPotion", "Luck2", "Time2", "Luck3", "Time3", "Remover"}

local function getHumanoidRootPart()
    local char = localPlayer.Character
    if char then
        return char:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local function autoRngLoop()
    while _G.AutoRng do
        local hrp = getHumanoidRootPart()
        
        if hrp then
            local foundTarget = nil
            
            for _, targetName in ipairs(targetObjects) do
                local obj = workspace:FindFirstChild(targetName)
                if obj and obj:IsA("BasePart") and obj.Parent ~= localPlayer.Character then
                    foundTarget = obj
                    break
                end
            end
            
            if foundTarget then
                local targetPos = foundTarget.CFrame + Vector3.new(0, 3, 0)
                hrp.CFrame = targetPos
                print("[Auto Rng Items] Телепорт к: " .. foundTarget.Name)
                Rayfield:Notify({
                    Title = "Auto Rng Items",
                    Content = "Телепорт к: " .. foundTarget.Name,
                    Duration = 1
                })
                task.wait(0.5)
            end
        end
        
        task.wait(0.3)
    end
end

local function startAutoRng()
    if _G.AutoRng then
        if autoRngThread then return end
        print("[Auto Rng Items] Активирован")
        Rayfield:Notify({
            Title = "Auto Rng Items",
            Content = "Авто RNG включен",
            Duration = 2
        })
        autoRngThread = coroutine.wrap(autoRngLoop)
        autoRngThread()
    end
end

local function stopAutoRng()
    _G.AutoRng = false
    autoRngThread = nil
    print("[Auto Rng Items] Деактивирован")
    Rayfield:Notify({
        Title = "Auto Rng Items",
        Content = "Авто RNG выключен",
        Duration = 2
    })
end

AllTab:CreateSection("RNG")

AllTab:CreateToggle({
    Name = "Auto Rng Items",
    CurrentValue = false,
    Callback = function(value)
        _G.AutoRng = value
        
        if value then
            startAutoRng()
        else
            stopAutoRng()
        end
    end,
})

AllTab:CreateSection(" ")

-- Обновление персонажа при респе
localPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if _G.AutoRng then
        print("[Auto Rng Items] Персонаж обновлен")
    end
end)

-- Защита от внешнего отключения Anti-Macro
spawn(function()
    while task.wait(1) do
        if _G.AntiMacro and not antiMacroConnection then
            print("[Anti-Macro] Обнаружена попытка отключения! Перезапуск...")
            Rayfield:Notify({
                Title = "Anti Macro",
                Content = "Обнаружена атака! Защита перезапущена",
                Duration = 3
            })
            startAntiMacro()
        end
    end
end)

print("[Скрипт] Загружен успешно!")
Rayfield:Notify({
    Title = "Скрипт",
    Content = "Загружен успешно!",
    Duration = 3
})
