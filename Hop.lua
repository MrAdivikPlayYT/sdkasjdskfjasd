repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer

local serverFrames = {}
local addQueue = {}
local isAdding = false
local currentSearch = ""

local COLORS = {
    main = Color3.fromRGB(18,18,18),
    top = Color3.fromRGB(25,25,25),
    inner = Color3.fromRGB(30,30,30),
    card = Color3.fromRGB(35,35,35),
    accent = Color3.fromRGB(70,200,120),
    button = Color3.fromRGB(45,45,45)
}

local function getServerID(jobId)
    local hash = 0
    for i = 1, #jobId do
        hash = (hash * 33 + string.byte(jobId, i)) % 100000
    end
    return hash
end

local function getBaseSeconds(jobId)
    local seed = 0
    for i = 1, #jobId do
        seed += string.byte(jobId, i)
    end
    return seed % 3600
end

local function formatTime(sec)
    local m = math.floor(sec / 60)
    local s = sec % 60
    return string.format("%d:%02d", m, s)
end

local function matchesSearch(serverId)
    if currentSearch == "" then
        return true
    end
    return tostring(getServerID(serverId)):find(currentSearch, 1, true) ~= nil
end

local function updateSearchFilter()
    for jobId, data in pairs(serverFrames) do
        local visible = matchesSearch(jobId)
        data.frame.Visible = visible
    end
end

if game.CoreGui:FindFirstChild("ServerHopUI") then
    game.CoreGui.ServerHopUI:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "ServerHopUI"
gui.ResetOnSpawn = false
gui.Parent = game.CoreGui



local main = Instance.new("Frame")
main.Parent = gui
main.Size = UDim2.new(0,520,0,700)
main.Position = UDim2.new(0.5,-260,0.5,-350)
main.BackgroundColor3 = COLORS.main
Instance.new("UICorner", main)

-- DRAG SYSTEM
local UIS = game:GetService("UserInputService")

local dragging = false
local dragInput
local dragStart
local startPos

local function update(input)
    local delta = input.Position - dragStart
    main.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

main.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

-- TOP
local topFrame = Instance.new("Frame")
topFrame.Parent = main
topFrame.Size = UDim2.new(1,-20,0,70)
topFrame.Position = UDim2.new(0,10,0,10)
topFrame.BackgroundColor3 = COLORS.top
Instance.new("UICorner", topFrame)

local title = Instance.new("TextLabel")
title.Parent = topFrame
title.Size = UDim2.new(1,0,0,30)
title.Position = UDim2.new(0,0,0,5)
title.Text = "Server Browser"
title.TextColor3 = Color3.new(1,1,1)
title.BackgroundTransparency = 1
title.TextScaled = true
title.Font = Enum.Font.GothamBold

local gameLabel = Instance.new("TextLabel")
gameLabel.Parent = topFrame
gameLabel.Size = UDim2.new(1,0,0,25)
gameLabel.Position = UDim2.new(0,0,0,35)
gameLabel.Text = "Game: " .. MarketplaceService:GetProductInfo(game.PlaceId).Name
gameLabel.TextColor3 = Color3.fromRGB(180,180,180)
gameLabel.BackgroundTransparency = 1
gameLabel.TextScaled = true
gameLabel.Font = Enum.Font.Gotham
gameLabel.TextWrapped = true

-- SEARCH
local search = Instance.new("TextBox")
search.Parent = main
search.Size = UDim2.new(1,-20,0,45)
search.Position = UDim2.new(0,10,0,90)
search.PlaceholderText = "Search ID..."
search.Text = ""
search.BackgroundColor3 = COLORS.inner
search.TextColor3 = Color3.new(1,1,1)
search.PlaceholderColor3 = Color3.fromRGB(150,150,150)
search.Font = Enum.Font.GothamBold
search.TextSize = 18
search.ClearTextOnFocus = false
Instance.new("UICorner", search)

local searchStroke = Instance.new("UIStroke")
searchStroke.Parent = search
searchStroke.Color = Color3.fromRGB(60,60,60)
searchStroke.Thickness = 1.5

search:GetPropertyChangedSignal("Text"):Connect(function()
    currentSearch = string.lower(search.Text)
    updateSearchFilter()
end)

-- SCROLL
local scroll = Instance.new("ScrollingFrame")
scroll.Parent = main
scroll.Size = UDim2.new(1,-20,1,-210)
scroll.Position = UDim2.new(0,10,0,140)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.None

local layout = Instance.new("UIListLayout")
layout.Parent = scroll
layout.Padding = UDim.new(0,10)
layout.SortOrder = Enum.SortOrder.LayoutOrder

layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scroll.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y + 10)
end)

local function removeServer(jobId)
    if serverFrames[jobId] then
        serverFrames[jobId].frame:Destroy()
        serverFrames[jobId] = nil
    end
end

local function createServer(server)
    if server.playing == 0 then
        removeServer(server.id)
        return
    end

    if serverFrames[server.id] then
        serverFrames[server.id].server = server
        return
    end

    local id = getServerID(server.id)
    local baseTime = getBaseSeconds(server.id)

    local row = Instance.new("Frame")
    row.Parent = scroll
    row.Size = UDim2.new(1,-5,0,85)
    row.BackgroundColor3 = COLORS.card
    row.Visible = matchesSearch(server.id)
    Instance.new("UICorner", row)

    local bar = Instance.new("Frame")
    bar.Parent = row
    bar.Size = UDim2.new(0,4,1,-20)
    bar.Position = UDim2.new(0,8,0,10)
    bar.BackgroundColor3 = COLORS.accent
    Instance.new("UICorner", bar)

    local name = Instance.new("TextLabel")
    name.Parent = row
    name.Size = UDim2.new(1,-120,0,30)
    name.Position = UDim2.new(0,18,0,5)
    name.Text = "Server " .. id
    name.TextColor3 = Color3.new(1,1,1)
    name.BackgroundTransparency = 1
    name.TextScaled = true
    name.Font = Enum.Font.GothamBold
    name.TextXAlignment = Enum.TextXAlignment.Left

    local info = Instance.new("TextLabel")
    info.Parent = row
    info.Size = UDim2.new(1,-120,0,25)
    info.Position = UDim2.new(0,18,0,40)
    info.Text = server.playing .. " Online  ID: " .. id .. "  " .. formatTime(baseTime)
    info.TextColor3 = Color3.fromRGB(200,200,200)
    info.BackgroundTransparency = 1
    info.TextScaled = true
    info.Font = Enum.Font.Gotham
    info.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton")
    btn.Parent = row
    btn.Size = UDim2.new(0,85,0,35)
    btn.Position = UDim2.new(1,-95,0.5,-17)
    btn.Text = "JOIN"
    btn.BackgroundColor3 = COLORS.accent
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    Instance.new("UICorner", btn)

    btn.MouseButton1Click:Connect(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, player)
    end)

    serverFrames[server.id] = {
        frame = row,
        info = info,
        time = baseTime,
        server = server
    }
end

local function processQueue()
    if isAdding then
        return
    end

    isAdding = true

    task.spawn(function()
        while #addQueue > 0 do
            createServer(table.remove(addQueue, 1))
            task.wait(0.1)
        end
        isAdding = false
    end)
end

local function fetchServers()
    local cursor

    for _ = 1, 3 do
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=100"
        if cursor then
            url = url .. "&cursor=" .. cursor
        end

        local data = HttpService:JSONDecode(game:HttpGet(url))

        for _, s in ipairs(data.data or {}) do
            table.insert(addQueue, s)
        end

        processQueue()

        cursor = data.nextPageCursor
        if not cursor then
            break
        end
    end
end

task.spawn(function()
    while true do
        for _, data in pairs(serverFrames) do
            data.time += 0.5
            data.info.Text = data.server.playing .. " Online  ID: " .. getServerID(data.server.id) .. "  " .. formatTime(math.floor(data.time))
        end
        task.wait(0.5)
    end
end)

-- BUTTONS BACKGROUND
local buttonHolder = Instance.new("Frame")
buttonHolder.Parent = main
buttonHolder.Size = UDim2.new(1,-20,0,70)
buttonHolder.Position = UDim2.new(0,10,1,-80)
buttonHolder.BackgroundColor3 = COLORS.top
Instance.new("UICorner", buttonHolder)

local btnLayout = Instance.new("UIListLayout")
btnLayout.Parent = buttonHolder
btnLayout.FillDirection = Enum.FillDirection.Horizontal
btnLayout.Padding = UDim.new(0,12)
btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local padding = Instance.new("UIPadding")
padding.Parent = buttonHolder
padding.PaddingLeft = UDim.new(0,10)
padding.PaddingRight = UDim.new(0,10)

local quick = Instance.new("TextButton")
quick.Parent = buttonHolder
quick.Size = UDim2.new(0.5,-6,0,40)
quick.Text = "Quick Join"
quick.BackgroundColor3 = COLORS.inner
quick.TextColor3 = Color3.new(1,1,1)
quick.Font = Enum.Font.GothamBold
quick.TextSize = 20
Instance.new("UICorner", quick)

local stroke1 = Instance.new("UIStroke")
stroke1.Parent = quick
stroke1.Color = Color3.fromRGB(60,60,60)
stroke1.Thickness = 1.5

local small = Instance.new("TextButton")
small.Parent = buttonHolder
small.Size = UDim2.new(0.5,-6,0,40)
small.Text = "Small Join"
small.BackgroundColor3 = COLORS.inner
small.TextColor3 = Color3.new(1,1,1)
small.Font = Enum.Font.GothamBold
small.TextSize = 20
Instance.new("UICorner", small)

local stroke2 = Instance.new("UIStroke")
stroke2.Parent = small
stroke2.Color = Color3.fromRGB(60,60,60)
stroke2.Thickness = 1.5

fetchServers()
