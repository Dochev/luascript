-- ============================================================
--   ███████╗███╗   ███╗███████╗██╗    ██╗  ██╗██╗   ██╗██████╗
--   ╚════██║████╗ ████║██╔════╝██║    ██║  ██║██║   ██║██╔══██╗
--       ██╔╝██╔████╔██║█████╗  ██║    ███████║██║   ██║██████╔╝
--      ██╔╝ ██║╚██╔╝██║██╔══╝  ██║    ██╔══██║██║   ██║██╔══██╗
--      ██║  ██║ ╚═╝ ██║███████╗██║    ██║  ██║╚██████╔╝██████╔╝
--      ╚═╝  ╚═╝     ╚═╝╚══════╝╚═╝    ╚═╝  ╚═╝ ╚═════╝ ╚═════╝
--  ZmeiHub v1.0  |  Chicken Tracker  |  Educational Script
--  LocalScript → StarterPlayer > StarterPlayerScripts
-- ============================================================

-- ┌─────────────────────────────────────────────────────────┐
-- │                      SERVICES                           │
-- └─────────────────────────────────────────────────────────┘
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

-- ┌─────────────────────────────────────────────────────────┐
-- │                     REFERENCES                          │
-- └─────────────────────────────────────────────────────────┘
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Camera      = workspace.CurrentCamera

-- ============================================================
--  CONFIG
-- ============================================================
local Config = {
    ChickenFolderName = "Chickens",
    ChickenRootName   = "HumanoidRootPart",

    FOV               = 150,
    AimAssistSmooth   = 0.12,
    AutoAimEnabled    = false,
    AimAssistEnabled  = false,
    ESPEnabled        = false,

    PointsPerKill     = 10,
    BonusPointsRange  = 50,

    -- Purple palette
    BG_DARK      = Color3.fromRGB(14,  10,  22),   -- near-black purple
    BG_MID       = Color3.fromRGB(24,  16,  40),   -- panel bg
    BG_CARD      = Color3.fromRGB(32,  22,  54),   -- card bg
    BG_SECTION   = Color3.fromRGB(20,  14,  34),   -- section header bg
    ACCENT       = Color3.fromRGB(160,  80, 255),  -- vivid purple
    ACCENT_DIM   = Color3.fromRGB(100,  50, 180),  -- muted purple
    ACCENT_GLOW  = Color3.fromRGB(200, 140, 255),  -- highlight
    TEXT_BRIGHT  = Color3.fromRGB(230, 215, 255),
    TEXT_DIM     = Color3.fromRGB(140, 115, 175),
    BORDER       = Color3.fromRGB(80,   50, 130),
    GREEN_ON     = Color3.fromRGB(100, 220, 130),
    TOGGLE_OFF   = Color3.fromRGB(45,   30,  70),

    ESPColor     = Color3.fromRGB(180, 100, 255),
    FOVColor     = Color3.fromRGB(160,  80, 255),
}

-- ============================================================
--  STATE
-- ============================================================
local State = {
    Points         = 0,
    CurrentTarget  = nil,
    ESPHighlights  = {},
    TrackingActive = false,
}

-- ============================================================
--  UTILITIES
-- ============================================================
local Utils = {}

function Utils.GetChickens()
    local f = workspace:FindFirstChild(Config.ChickenFolderName)
    return f and f:GetChildren() or {}
end

function Utils.GetChickenPosition(model)
    local r = model:FindFirstChild(Config.ChickenRootName)
    return r and r.Position or nil
end

function Utils.WorldToScreen(pos)
    local sp, on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), on
end

function Utils.ScreenCenter()
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

function Utils.FindNearestChicken()
    local center = Utils.ScreenCenter()
    local best, bd = nil, math.huge
    for _, m in ipairs(Utils.GetChickens()) do
        local p = Utils.GetChickenPosition(m)
        if p then
            local sp, on = Utils.WorldToScreen(p)
            if on then
                local d = (sp - center).Magnitude
                if d < Config.FOV and d < bd then bd, best = d, m end
            end
        end
    end
    return best
end

-- ============================================================
--  ESP MODULE
-- ============================================================
local ESPModule = {}

function ESPModule.Add(model)
    if State.ESPHighlights[model] then return end
    local hl = Instance.new("Highlight")
    hl.FillColor           = Config.ESPColor
    hl.OutlineColor        = Config.ACCENT_GLOW
    hl.FillTransparency    = 0.5
    hl.OutlineTransparency = 0
    hl.Adornee, hl.Parent  = model, model
    State.ESPHighlights[model] = hl
end

function ESPModule.Remove(model)
    local hl = State.ESPHighlights[model]
    if hl then hl:Destroy(); State.ESPHighlights[model] = nil end
end

function ESPModule.Refresh()
    if Config.ESPEnabled then
        for _, m in ipairs(Utils.GetChickens()) do ESPModule.Add(m) end
    else
        for m in pairs(State.ESPHighlights) do ESPModule.Remove(m) end
    end
end

-- ============================================================
--  TRACKING MODULE
-- ============================================================
local TrackingModule = {}

function TrackingModule.AimAssist(t)
    local p = Utils.GetChickenPosition(t); if not p then return end
    local cf = Camera.CFrame
    Camera.CFrame = cf:Lerp(CFrame.lookAt(cf.Position, p), Config.AimAssistSmooth)
end

function TrackingModule.AutoAim(t)
    local p = Utils.GetChickenPosition(t); if not p then return end
    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, p)
end

function TrackingModule.Update()
    if not State.TrackingActive then return end
    local t = Utils.FindNearestChicken()
    State.CurrentTarget = t
    if t then
        if Config.AutoAimEnabled then TrackingModule.AutoAim(t)
        elseif Config.AimAssistEnabled then TrackingModule.AimAssist(t) end
    end
end

-- ============================================================
--  POINTS MODULE
-- ============================================================
local PointsModule = {}

function PointsModule.AwardKill(model)
    local bonus = 0
    local r = model:FindFirstChild(Config.ChickenRootName)
    if r and (r.Position - Camera.CFrame.Position).Magnitude <= Config.BonusPointsRange then
        bonus = 5
    end
    State.Points = State.Points + Config.PointsPerKill + bonus
    local ev = game:GetService("ReplicatedStorage"):FindFirstChild("ChickenKilled")
    if ev then ev:FireServer(State.Points) end
    return State.Points
end

-- ============================================================
--  GUI MODULE  — ZmeiHub Purple Theme
-- ============================================================
local GUIModule = {}

-- ── Low-level helpers ─────────────────────────────────────────

local function Corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = p
end

local function Stroke(p, col, thick)
    local s = Instance.new("UIStroke")
    s.Color = col or Config.BORDER; s.Thickness = thick or 1; s.Parent = p
end

local function Label(p, txt, size, bold, col, xalign)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size     = UDim2.fromScale(1, 1)
    l.Text     = txt
    l.TextSize = size or 12
    l.Font     = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextColor3 = col or Config.TEXT_BRIGHT
    l.TextXAlignment = xalign or Enum.TextXAlignment.Center
    l.Parent = p; return l
end

local function Frame(p, sz, pos, bg, lo)
    local f = Instance.new("Frame")
    f.Size = sz; f.Position = pos or UDim2.new(0,0,0,0)
    f.BackgroundColor3 = bg or Config.BG_CARD
    f.BorderSizePixel  = 0
    if lo then f.LayoutOrder = lo end
    f.Parent = p; return f
end

-- Section header (matches AirHub-style labeled group boxes)
local function SectionHeader(parent, title, layoutOrder)
    local header = Frame(parent,
        UDim2.new(1, 0, 0, 18),
        nil, Config.BG_SECTION, layoutOrder)
    Corner(header, 4)
    Stroke(header, Config.BORDER, 1)

    -- left accent bar
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 1, 0)
    bar.BackgroundColor3 = Config.ACCENT
    bar.BorderSizePixel  = 0
    bar.Parent = header
    Corner(bar, 2)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = Config.ACCENT_GLOW
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = header
    return header
end

-- Checkbox row  (small colored square + label)
local function CheckRow(parent, txt, layoutOrder, callback)
    local row = Frame(parent, UDim2.new(1, 0, 0, 18), nil, Color3.new(0,0,0), layoutOrder)
    row.BackgroundTransparency = 1

    local box = Instance.new("TextButton")
    box.Size             = UDim2.new(0, 12, 0, 12)
    box.Position         = UDim2.new(0, 2, 0.5, -6)
    box.BackgroundColor3 = Config.TOGGLE_OFF
    box.Text             = ""; box.AutoButtonColor = false
    box.Parent           = row
    Corner(box, 2)
    Stroke(box, Config.BORDER, 1)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 1, 0)
    lbl.Position = UDim2.new(0, 18, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = txt; lbl.TextSize = 11
    lbl.Font = Enum.Font.Gotham
    lbl.TextColor3 = Config.TEXT_BRIGHT
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local checked = false
    box.MouseButton1Click:Connect(function()
        checked = not checked
        TweenService:Create(box, TweenInfo.new(0.15), {
            BackgroundColor3 = checked and Config.ACCENT or Config.TOGGLE_OFF
        }):Play()
        if callback then callback(checked) end
    end)
    return row
end

-- Compact slider row
local function SliderRow(parent, labelTxt, minV, maxV, defaultV, layoutOrder, callback)
    local wrap = Frame(parent, UDim2.new(1, 0, 0, 36), nil, Color3.new(0,0,0), layoutOrder)
    wrap.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelTxt .. ": " .. tostring(defaultV)
    lbl.TextSize = 11; lbl.Font = Enum.Font.Gotham
    lbl.TextColor3 = Config.TEXT_DIM
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = wrap

    local track = Frame(wrap, UDim2.new(1, 0, 0, 5), UDim2.new(0, 0, 0, 18), Color3.fromRGB(38, 25, 60), layoutOrder)
    Corner(track, 3)
    Stroke(track, Config.BORDER, 1)

    local pct = (defaultV - minV) / (maxV - minV)

    local fill = Frame(track, UDim2.new(pct, 0, 1, 0), nil, Config.ACCENT_DIM)
    Corner(fill, 3)

    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 9, 0, 9)
    knob.Position = UDim2.new(pct, -5, 0.5, -5)
    knob.BackgroundColor3 = Config.ACCENT_GLOW
    knob.Text = ""; knob.AutoButtonColor = false
    knob.Parent = track
    Corner(knob, 5)

    local sliding = false
    knob.MouseButton1Down:Connect(function() sliding = true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not sliding or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local abs  = track.AbsolutePosition
        local sz   = track.AbsoluteSize
        local rel  = math.clamp((i.Position.X - abs.X) / sz.X, 0, 1)
        local val  = math.floor(minV + rel * (maxV - minV))
        lbl.Text         = labelTxt .. ": " .. tostring(val)
        fill.Size        = UDim2.new(rel, 0, 1, 0)
        knob.Position    = UDim2.new(rel, -5, 0.5, -5)
        if callback then callback(val) end
    end)
    return wrap, lbl
end

-- ── Main Build ────────────────────────────────────────────────

function GUIModule.Build()
    -- Root ScreenGui
    local sg = Instance.new("ScreenGui")
    sg.Name = "ZmeiHubGUI"; sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true; sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = PlayerGui

    -- ── Outer window ─────────────────────────────────────────
    local win = Instance.new("Frame")
    win.Name = "ZmeiWin"
    win.Size = UDim2.new(0, 480, 0, 340)
    win.Position = UDim2.new(0.5, -240, 0.5, -170)
    win.BackgroundColor3 = Config.BG_DARK
    win.BorderSizePixel  = 0
    win.ClipsDescendants = true
    win.Parent = sg
    Corner(win, 8)
    Stroke(win, Config.ACCENT_DIM, 1.5)

    -- Subtle inner glow border
    local glow = Instance.new("UIStroke")
    glow.Color = Config.ACCENT; glow.Thickness = 1
    glow.Transparency = 0.6; glow.Parent = win

    -- ── Title bar ────────────────────────────────────────────
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Config.BG_MID
    titleBar.BorderSizePixel  = 0
    titleBar.ZIndex = 3
    titleBar.Parent = win

    -- bottom border on title bar
    local titleLine = Instance.new("Frame")
    titleLine.Size = UDim2.new(1, 0, 0, 1)
    titleLine.Position = UDim2.new(0, 0, 1, -1)
    titleLine.BackgroundColor3 = Config.ACCENT_DIM
    titleLine.BorderSizePixel = 0; titleLine.Parent = titleBar

    -- Hub name
    local hubName = Instance.new("TextLabel")
    hubName.Size = UDim2.new(0, 90, 1, 0)
    hubName.Position = UDim2.new(0, 8, 0, 0)
    hubName.BackgroundTransparency = 1
    hubName.Text = "ZmeiHub v1.0"
    hubName.TextSize = 11; hubName.Font = Enum.Font.GothamBold
    hubName.TextColor3 = Config.ACCENT_GLOW
    hubName.TextXAlignment = Enum.TextXAlignment.Left
    hubName.ZIndex = 4; hubName.Parent = titleBar

    -- Separator
    local sep = Instance.new("TextLabel")
    sep.Size = UDim2.new(0, 8, 1, 0); sep.Position = UDim2.new(0, 96, 0, 0)
    sep.BackgroundTransparency = 1; sep.Text = "│"; sep.TextSize = 11
    sep.Font = Enum.Font.Gotham; sep.TextColor3 = Config.TEXT_DIM
    sep.ZIndex = 4; sep.Parent = titleBar

    -- Tab buttons
    local tabs = {"Aimbot", "Settings", "FOV", "Points"}
    local tabX = 108
    for _, t in ipairs(tabs) do
        local tb = Instance.new("TextButton")
        tb.Size = UDim2.new(0, 56, 1, -4)
        tb.Position = UDim2.new(0, tabX, 0, 2)
        tb.BackgroundColor3 = Color3.fromRGB(0,0,0)
        tb.BackgroundTransparency = 1
        tb.Text = t; tb.TextSize = 10
        tb.Font = Enum.Font.GothamBold
        tb.TextColor3 = Config.TEXT_DIM
        tb.AutoButtonColor = false
        tb.ZIndex = 4; tb.Parent = titleBar
        tabX = tabX + 58
        -- first tab is "active"
        if t == "Aimbot" then tb.TextColor3 = Config.ACCENT_GLOW end
    end

    -- Gear icon
    local gear = Instance.new("TextLabel")
    gear.Size = UDim2.new(0, 20, 1, 0); gear.Position = UDim2.new(1, -24, 0, 0)
    gear.BackgroundTransparency = 1; gear.Text = "⚙"; gear.TextSize = 13
    gear.TextColor3 = Config.TEXT_DIM; gear.ZIndex = 4; gear.Parent = titleBar

    -- Drag
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = i.Position; startPos = win.Position
        end
    end)
    titleBar.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            win.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    -- ── Body: two-column layout ───────────────────────────────
    local body = Instance.new("Frame")
    body.Name = "Body"
    body.Size = UDim2.new(1, 0, 1, -30)
    body.Position = UDim2.new(0, 0, 0, 30)
    body.BackgroundColor3 = Config.BG_DARK
    body.BorderSizePixel  = 0
    body.Parent = win

    -- Left column
    local leftCol = Instance.new("ScrollingFrame")
    leftCol.Name = "Left"
    leftCol.Size = UDim2.new(0.5, -1, 1, 0)
    leftCol.Position = UDim2.new(0, 0, 0, 0)
    leftCol.BackgroundTransparency = 1
    leftCol.BorderSizePixel = 0
    leftCol.ScrollBarThickness = 0
    leftCol.CanvasSize = UDim2.new(0, 0, 0, 0)
    leftCol.AutomaticCanvasSize = Enum.AutomaticSize.Y
    leftCol.Parent = body

    local leftLayout = Instance.new("UIListLayout")
    leftLayout.Padding = UDim.new(0, 4)
    leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
    leftLayout.Parent = leftCol

    local leftPad = Instance.new("UIPadding")
    leftPad.PaddingTop = UDim.new(0, 8); leftPad.PaddingLeft = UDim.new(0, 8)
    leftPad.PaddingRight = UDim.new(0, 6); leftPad.PaddingBottom = UDim.new(0, 8)
    leftPad.Parent = leftCol

    -- Column divider
    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(0, 1, 1, 0)
    divider.Position = UDim2.new(0.5, -1, 0, 0)
    divider.BackgroundColor3 = Config.BORDER
    divider.BorderSizePixel  = 0
    divider.Parent = body

    -- Right column
    local rightCol = Instance.new("ScrollingFrame")
    rightCol.Name = "Right"
    rightCol.Size = UDim2.new(0.5, -1, 1, 0)
    rightCol.Position = UDim2.new(0.5, 1, 0, 0)
    rightCol.BackgroundTransparency = 1
    rightCol.BorderSizePixel = 0
    rightCol.ScrollBarThickness = 0
    rightCol.CanvasSize = UDim2.new(0, 0, 0, 0)
    rightCol.AutomaticCanvasSize = Enum.AutomaticSize.Y
    rightCol.Parent = body

    local rightLayout = Instance.new("UIListLayout")
    rightLayout.Padding = UDim.new(0, 4)
    rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rightLayout.Parent = rightCol

    local rightPad = Instance.new("UIPadding")
    rightPad.PaddingTop = UDim.new(0, 8); rightPad.PaddingLeft = UDim.new(0, 6)
    rightPad.PaddingRight = UDim.new(0, 8); rightPad.PaddingBottom = UDim.new(0, 8)
    rightPad.Parent = rightCol

    -- =========================================================
    --  LEFT COLUMN CONTENTS
    -- =========================================================

    -- ── Section: Values ──────────────────────────────────────
    SectionHeader(leftCol, "Values", 1)

    CheckRow(leftCol, "Enabled (Master)", 2, function(v)
        State.TrackingActive = v
        if not v then
            for m in pairs(State.ESPHighlights) do ESPModule.Remove(m) end
        end
    end)

    CheckRow(leftCol, "Auto-Aim (Snap)", 3, function(v)
        Config.AutoAimEnabled = v
    end)

    -- ── Section: Aim Assist ───────────────────────────────────
    SectionHeader(leftCol, "Aim Assist", 4)

    CheckRow(leftCol, "Enable Smooth Track", 5, function(v)
        Config.AimAssistEnabled = v
    end)

    SliderRow(leftCol, "Sensitivity", 1, 100,
        math.floor(Config.AimAssistSmooth * 100), 6,
        function(v) Config.AimAssistSmooth = v / 100 end)

    -- ── Section: Checks ───────────────────────────────────────
    SectionHeader(leftCol, "Checks", 7)

    CheckRow(leftCol, "ESP Highlights", 8, function(v)
        Config.ESPEnabled = v; ESPModule.Refresh()
    end)

    CheckRow(leftCol, "Show FOV Circle", 9, function(v)
        -- stored for FOV circle visibility logic below
        _G.ZmeiShowFOV = v
    end)

    CheckRow(leftCol, "Alive Check Only", 10, function(_) end)

    -- ── Section: Points ───────────────────────────────────────
    SectionHeader(leftCol, "Points", 11)

    -- Points value display
    local pointsWrap = Frame(leftCol, UDim2.new(1, 0, 0, 28), nil, Config.BG_CARD, 12)
    Corner(pointsWrap, 5)
    Stroke(pointsWrap, Config.BORDER, 1)

    local pointsLbl = Instance.new("TextLabel")
    pointsLbl.Name = "PointsLabel"
    pointsLbl.Size = UDim2.new(0.45, 0, 1, 0)
    pointsLbl.BackgroundTransparency = 1
    pointsLbl.Text = "Score:"
    pointsLbl.TextSize = 11; pointsLbl.Font = Enum.Font.Gotham
    pointsLbl.TextColor3 = Config.TEXT_DIM
    pointsLbl.TextXAlignment = Enum.TextXAlignment.Left
    pointsLbl.Position = UDim2.new(0, 8, 0, 0)
    pointsLbl.Parent = pointsWrap

    local pointsVal = Instance.new("TextLabel")
    pointsVal.Name = "PointsValue"
    pointsVal.Size = UDim2.new(0.5, 0, 1, 0)
    pointsVal.Position = UDim2.new(0.5, 0, 0, 0)
    pointsVal.BackgroundTransparency = 1
    pointsVal.Text = "0"
    pointsVal.TextSize = 14; pointsVal.Font = Enum.Font.GothamBold
    pointsVal.TextColor3 = Config.ACCENT_GLOW
    pointsVal.TextXAlignment = Enum.TextXAlignment.Right
    pointsVal.Position = UDim2.new(0, 0, 0, 0)
    pointsVal.Size = UDim2.new(1, -10, 1, 0)
    pointsVal.Parent = pointsWrap

    GUIModule.PointsLabel = pointsVal

    -- =========================================================
    --  RIGHT COLUMN CONTENTS
    -- =========================================================

    -- ── Section: Field Of View ────────────────────────────────
    SectionHeader(rightCol, "Field Of View", 1)

    CheckRow(rightCol, "Enabled", 2, function(v)
        _G.ZmeiShowFOV = v
    end)

    CheckRow(rightCol, "Visible on Screen", 3, function(_) end)

    local _, fovAmtLbl = SliderRow(rightCol, "Amount", 10, 400, Config.FOV, 4,
        function(v) Config.FOV = v end)

    -- ── Section: FOV Circle Appearance ───────────────────────
    SectionHeader(rightCol, "FOV Circle Appearance", 5)

    CheckRow(rightCol, "Filled", 6, function(_) end)

    local _, tranLbl = SliderRow(rightCol, "Transparency", 0, 10, 4, 7, function(_) end)

    local _, sidesLbl = SliderRow(rightCol, "Sides (smoothness)", 4, 100, 60, 8, function(_) end)

    local _, thickLbl = SliderRow(rightCol, "Thickness", 1, 10, 1, 9, function(_) end)

    -- Color swatches (decorative)
    SectionHeader(rightCol, "Colors", 10)

    local colorRow = Frame(rightCol, UDim2.new(1, 0, 0, 22), nil, Color3.new(0,0,0), 11)
    colorRow.BackgroundTransparency = 1

    local function Swatch(parent, col, xpos, labelTxt)
        local sw = Instance.new("Frame")
        sw.Size = UDim2.new(0, 14, 0, 14)
        sw.Position = UDim2.new(0, xpos, 0.5, -7)
        sw.BackgroundColor3 = col
        sw.Parent = parent
        Corner(sw, 3); Stroke(sw, Config.BORDER, 1)
        local lbl2 = Instance.new("TextLabel")
        lbl2.Size = UDim2.new(0, 80, 1, 0)
        lbl2.Position = UDim2.new(0, xpos + 18, 0, 0)
        lbl2.BackgroundTransparency = 1
        lbl2.Text = labelTxt; lbl2.TextSize = 10
        lbl2.Font = Enum.Font.Gotham
        lbl2.TextColor3 = Config.TEXT_DIM
        lbl2.TextXAlignment = Enum.TextXAlignment.Left
        lbl2.Parent = parent
    end
    Swatch(colorRow, Config.ACCENT,       2,  "FOV Color")
    Swatch(colorRow, Config.ACCENT_GLOW,  90, "Lock Color")

    -- ── Status bar at bottom of window ───────────────────────
    local statusBar = Instance.new("Frame")
    statusBar.Name = "StatusBar"
    statusBar.Size = UDim2.new(1, 0, 0, 18)
    statusBar.Position = UDim2.new(0, 0, 1, -18)
    statusBar.BackgroundColor3 = Config.BG_MID
    statusBar.BorderSizePixel  = 0
    statusBar.ZIndex = 5
    statusBar.Parent = win

    local topLine2 = Instance.new("Frame")
    topLine2.Size = UDim2.new(1, 0, 0, 1)
    topLine2.BackgroundColor3 = Config.ACCENT_DIM
    topLine2.BorderSizePixel  = 0; topLine2.Parent = statusBar

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, 0, 1, 0)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "ZmeiHub v1.0  ·  Chicken Tracker  ·  Educational Script"
    statusLbl.TextSize = 9; statusLbl.Font = Enum.Font.Gotham
    statusLbl.TextColor3 = Config.TEXT_DIM
    statusLbl.ZIndex = 6; statusLbl.Parent = statusBar

    -- ── FOV circle overlay on screen ─────────────────────────
    local circle = Instance.new("ImageLabel")
    circle.Name = "FOVCircle"
    circle.BackgroundTransparency = 1
    circle.Image = "rbxassetid://3570695787"
    circle.ImageColor3 = Config.FOVColor
    circle.ImageTransparency = 0.35
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.ZIndex = 10
    circle.Parent = sg

    RunService.RenderStepped:Connect(function()
        local c = Utils.ScreenCenter()
        circle.Position = UDim2.new(0, c.X, 0, c.Y)
        circle.Size = UDim2.new(0, Config.FOV * 2, 0, Config.FOV * 2)
        circle.Visible = State.TrackingActive and (_G.ZmeiShowFOV == true)
    end)
end

-- ============================================================
--  KILL DETECTION
-- ============================================================
local KillDetection = {}

function KillDetection.Watch()
    local folder = workspace:WaitForChild(Config.ChickenFolderName, 10)
    if not folder then
        warn("[ZmeiHub] Folder '" .. Config.ChickenFolderName .. "' not found in Workspace!")
        return
    end

    folder.ChildRemoved:Connect(function(model)
        if State.TrackingActive then
            local pts = PointsModule.AwardKill(model)
            if GUIModule.PointsLabel then
                GUIModule.PointsLabel.Text = tostring(pts)
                TweenService:Create(GUIModule.PointsLabel, TweenInfo.new(0.1),
                    {TextSize = 18}):Play()
                task.delay(0.15, function()
                    TweenService:Create(GUIModule.PointsLabel, TweenInfo.new(0.1),
                        {TextSize = 14}):Play()
                end)
            end
        end
        ESPModule.Remove(model)
    end)

    folder.ChildAdded:Connect(function(model)
        if Config.ESPEnabled then task.wait(0.1); ESPModule.Add(model) end
    end)
end

-- ============================================================
--  INIT
-- ============================================================
_G.ZmeiShowFOV = false

local function Init()
    GUIModule.Build()
    task.spawn(KillDetection.Watch)
    RunService.RenderStepped:Connect(function()
        TrackingModule.Update()
        if Config.ESPEnabled then ESPModule.Refresh() end
    end)
    print("[ZmeiHub] Loaded successfully.")
end

Init()

--[[
  ╔══════════════════════════════════════════════════════════╗
  ║                   ZMEI HUB SETUP                        ║
  ╠══════════════════════════════════════════════════════════╣
  ║  1. Place in: StarterPlayer > StarterPlayerScripts       ║
  ║  2. Workspace > Folder = "Chickens"                      ║
  ║     Each chicken Model needs "HumanoidRootPart"          ║
  ║  3. ReplicatedStorage > RemoteEvent = "ChickenKilled"    ║
  ╠══════════════════════════════════════════════════════════╣
  ║  GUI LAYOUT  (mirrors AirHub two-column style)           ║
  ║  LEFT  │ Values · Aim Assist · Checks · Points           ║
  ║  RIGHT │ Field Of View · FOV Appearance · Colors         ║
  ╚══════════════════════════════════════════════════════════╝
]]
