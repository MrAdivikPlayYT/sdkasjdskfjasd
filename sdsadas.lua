repeat task.wait() until game:IsLoaded()

local function decrypt(s)
    local r=""
    for i=1,#s do
        r=r..string.char(string.byte(s,i)-3)
    end
    return r
end

local allowed=false
for _,v in ipairs({"6:8884<59<", "636;6635:", "5363<54474"}) do
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

local Window = Rayfield:CreateWindow({
    Name="Skibidi Script",
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

Tab:CreateSection("Game")

local function getHRP()
    local c=game.Players.LocalPlayer.Character
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

Tab:CreateToggle({
    Name="Anti Macro",
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

Tab:CreateSection(" ")

Tab:CreateSection("Other")

local antiAFKEnabled = false
local antiAFKButton = nil

local function startAntiAFK()
    if antiAFKEnabled then return end
    antiAFKEnabled = true
    loadstring(game:HttpGet("https://raw.githubusercontent.com/hassanxzayn-lua/Anti-afk/main/antiafkbyhassanxzyn"))()
    antiAFKButton:Set("Name", "✅ Anti AFK")
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

Rayfield:Notify({ Title="Loaded", Content="Ready", Duration=2 })
