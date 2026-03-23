-- ============================================================
--  ZmeiHub v2.0  |  Chicken Tracker  |  Educational Script
--  LocalScript → StarterPlayer > StarterPlayerScripts
--
--  FIXES vs v1:
--   • ESP now highlights ALL players AND chickens via Highlight
--   • FOV circle drawn with pure UI frames (no broken asset ID)
--   • Aimbot sets Camera to Scriptable so it actually moves
--   • Tab bar fully functional (Aimbot / Settings / FOV / Points)
--   • No-Recoil option added (zeroes BodyVelocity recoil)
--   • Settings tab added with sensitivity + no-recoil controls
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
--  CONFIG  — all tunable values in one place
-- ============================================================
local Config = {
    -- Chicken folder
    ChickenFolderName = "Chickens",
    ChickenRootName   = "HumanoidRootPart",

    -- Tracking
    FOV              = 150,   -- screen-radius in pixels
    AimSmooth        = 0.15,  -- 0.01 = instant  /  1 = no movement
    AutoAimEnabled   = false,
    NoRecoilEnabled  = false,

    -- ESP
    ESPChickens      = false,
    ESPPlayers       = false,

    -- FOV circle
    ShowFOV          = false,

    -- Points
    PointsPerKill    = 10,
    BonusRange       = 50,

    -- ── Purple palette ───────────────────────────────────────
    BG_DARK      = Color3.fromRGB(14,  10,  22),
    BG_MID       = Color3.fromRGB(24,  16,  40),
    BG_CARD      = Color3.fromRGB(32,  22,  54),
    BG_SECTION   = Color3.fromRGB(20,  14,  34),
    ACCENT       = Color3.fromRGB(160,  80, 255),
    ACCENT_DIM   = Color3.fromRGB(100,  50, 180),
    ACCENT_GLOW  = Color3.fromRGB(200, 140, 255),
    TEXT_BRIGHT  = Color3.fromRGB(230, 215, 255),
    TEXT_DIM     = Color3.fromRGB(140, 115, 175),
    BORDER       = Color3.fromRGB(80,   50, 130),
    GREEN_ON     = Color3.fromRGB(100, 220, 130),
    TOGGLE_OFF   = Color3.fromRGB(45,   30,  70),
    ESP_CHICKEN  = Color3.fromRGB(255, 100, 80),
    ESP_PLAYER   = Color3.fromRGB(80,  200, 255),
}

-- ============================================================
--  STATE
-- ============================================================
local State = {
    Points         = 0,
    TrackingActive = false,
    ESPHighlights  = {},   -- [instance] = Highlight
}

-- ============================================================
--  UTILITIES
-- ============================================================
local Utils = {}

function Utils.GetChickens()
    local f = workspace:FindFirstChild(Config.ChickenFolderName)
    return f and f:GetChildren() or {}
end

function Utils.RootOf(model)
    return model:FindFirstChild(Config.ChickenRootName)
        or model:FindFirstChildOfClass("HumanoidRootPart")
        or model:FindFirstChild("HumanoidRootPart")
end

function Utils.PosOf(model)
    local r = Utils.RootOf(model); return r and r.Position or nil
end

function Utils.ToScreen(pos)
    local sp, on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), on
end

function Utils.Center()
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

-- Find nearest chicken within FOV circle
function Utils.NearestChicken()
    local center = Utils.Center()
    local best, bd = nil, math.huge
    for _, m in ipairs(Utils.GetChickens()) do
        local p = Utils.PosOf(m)
        if p then
            local sp, on = Utils.ToScreen(p)
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
--  Highlights chickens (orange) and other players (blue).
--  Uses Roblox Highlight instance — reliable & no asset needed.
-- ============================================================
local ESPModule = {}

-- Add a highlight to any model
local function AddHL(model, fillCol, outlineCol)
    if State.ESPHighlights[model] then return end
    local hl = Instance.new("Highlight")
    hl.FillColor           = fillCol
    hl.OutlineColor        = outlineCol
    hl.FillTransparency    = 0.45
    hl.OutlineTransparency = 0
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop  -- shows through walls
    hl.Adornee             = model
    hl.Parent              = model
    State.ESPHighlights[model] = hl
end

local function RemHL(model)
    local hl = State.ESPHighlights[model]
    if hl then hl:Destroy(); State.ESPHighlights[model] = nil end
end

-- Refresh chickens ESP
function ESPModule.RefreshChickens()
    local chickens = Utils.GetChickens()
    if Config.ESPChickens then
        for _, m in ipairs(chickens) do
            AddHL(m, Config.ESP_CHICKEN, Color3.new(1,1,1))
        end
    else
        for _, m in ipairs(chickens) do RemHL(m) end
    end
end

-- Refresh players ESP (all other players, not local)
function ESPModule.RefreshPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local char = p.Character
            if char then
                if Config.ESPPlayers then
                    AddHL(char, Config.ESP_PLAYER, Color3.new(1,1,1))
                else
                    RemHL(char)
                end
            end
        end
    end
end

function ESPModule.RefreshAll()
    ESPModule.RefreshChickens()
    ESPModule.RefreshPlayers()
end

-- When a player spawns/changes character, re-apply highlight
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if Config.ESPPlayers then
            AddHL(char, Config.ESP_PLAYER, Color3.new(1,1,1))
        end
    end)
end)
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        p.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            if Config.ESPPlayers then
                AddHL(char, Config.ESP_PLAYER, Color3.new(1,1,1))
            end
        end)
    end
end

-- ============================================================
--  AIMBOT MODULE
--  Sets Camera to Scriptable only while active, restores after.
-- ============================================================
local AimbotModule = {}
local _prevCamType = Enum.CameraType.Custom

function AimbotModule.Enable()
    _prevCamType = Camera.CameraType
    Camera.CameraType = Enum.CameraType.Scriptable
end

function AimbotModule.Disable()
    Camera.CameraType = _prevCamType
    -- Reset camera subject so Roblox takes back control
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then Camera.CameraSubject = hum end
    end
    Camera.CameraType = Enum.CameraType.Custom
end

function AimbotModule.Update()
    if not State.TrackingActive or not Config.AutoAimEnabled then return end
    local target = Utils.NearestChicken()
    if not target then return end
    local pos = Utils.PosOf(target)
    if not pos then return end

    -- Smooth lerp toward target
    local cf      = Camera.CFrame
    local goalCF  = CFrame.lookAt(cf.Position, pos)
    Camera.CFrame = cf:Lerp(goalCF, Config.AimSmooth)
end

-- ============================================================
--  NO-RECOIL MODULE
--  Cancels the local character's BodyVelocity kick each frame.
--  Works for tools that apply recoil via BodyVelocity/VectorForce.
-- ============================================================
local NoRecoilModule = {}

function NoRecoilModule.Update()
    if not Config.NoRecoilEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Zero out any BodyVelocity recoil forces
    for _, v in ipairs(hrp:GetChildren()) do
        if v:IsA("BodyVelocity") and v.Name == "RecoilForce" then
            v.Velocity = Vector3.zero
        end
    end

    -- Also zero angular velocity kick (BodyAngularVelocity)
    for _, v in ipairs(hrp:GetChildren()) do
        if v:IsA("BodyAngularVelocity") and v.Name == "RecoilAngular" then
            v.AngularVelocity = Vector3.zero
        end
    end
end

-- ============================================================
--  POINTS MODULE
-- ============================================================
local PointsModule = {}

function PointsModule.AwardKill(model)
    local bonus = 0
    local r = Utils.RootOf(model)
    if r and (r.Position - Camera.CFrame.Position).Magnitude <= Config.BonusRange then
        bonus = 5
    end
    State.Points = State.Points + Config.PointsPerKill + bonus
    local ev = game:GetService("ReplicatedStorage"):FindFirstChild("ChickenKilled")
    if ev then ev:FireServer(State.Points) end
    return State.Points
end

-- ============================================================
--  GUI MODULE  — ZmeiHub Purple Theme v2
-- ============================================================
local GUIModule = {}

-- ── GUI helper functions ──────────────────────────────────────

local function Corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6); c.Parent = p
end

local function Stroke(p, col, thick)
    local s = Instance.new("UIStroke")
    s.Color = col or Config.BORDER; s.Thickness = thick or 1; s.Parent = p
end

local function MkFrame(parent, size, pos, bg, lo)
    local f = Instance.new("Frame")
    f.Size = size; f.Position = pos or UDim2.new(0,0,0,0)
    f.BackgroundColor3 = bg or Config.BG_CARD
    f.BorderSizePixel  = 0
    if lo then f.LayoutOrder = lo end
    f.Parent = parent; return f
end

local function MkScroll(parent, size, pos)
    local s = Instance.new("ScrollingFrame")
    s.Size = size; s.Position = pos or UDim2.new(0,0,0,0)
    s.BackgroundTransparency = 1; s.BorderSizePixel = 0
    s.ScrollBarThickness = 0
    s.CanvasSize = UDim2.new(0,0,0,0)
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.Parent = parent; return s
end

local function ListLayout(parent, gap)
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, gap or 4)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.FillDirection = Enum.FillDirection.Vertical
    l.Parent = parent; return l
end

local function Padding(parent, t,b,l,r)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.PaddingLeft   = UDim.new(0, l or 0)
    p.PaddingRight  = UDim.new(0, r or 0)
    p.Parent = parent
end

-- Section header with left accent bar
local function SecHeader(parent, title, lo)
    local h = MkFrame(parent, UDim2.new(1,0,0,18), nil, Config.BG_SECTION, lo)
    Corner(h, 4); Stroke(h, Config.BORDER, 1)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0,3,1,0); bar.BackgroundColor3 = Config.ACCENT
    bar.BorderSizePixel = 0; bar.Parent = h; Corner(bar,2)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-12,1,0); lbl.Position = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = title
    lbl.TextSize = 11; lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = Config.ACCENT_GLOW
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = h; return h
end

-- Checkbox row — returns row and a setter function
local function CheckRow(parent, txt, lo, callback)
    local row = MkFrame(parent, UDim2.new(1,0,0,18), nil, Color3.new(0,0,0), lo)
    row.BackgroundTransparency = 1

    local box = Instance.new("TextButton")
    box.Size = UDim2.new(0,12,0,12); box.Position = UDim2.new(0,2,0.5,-6)
    box.BackgroundColor3 = Config.TOGGLE_OFF; box.Text = ""
    box.AutoButtonColor = false; box.Parent = row
    Corner(box,2); Stroke(box, Config.BORDER,1)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-20,1,0); lbl.Position = UDim2.new(0,18,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = txt
    lbl.TextSize = 11; lbl.Font = Enum.Font.Gotham
    lbl.TextColor3 = Config.TEXT_BRIGHT
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local on = false
    local function SetState(v)
        on = v
        TweenService:Create(box, TweenInfo.new(0.15), {
            BackgroundColor3 = on and Config.ACCENT or Config.TOGGLE_OFF
        }):Play()
    end
    box.MouseButton1Click:Connect(function()
        SetState(not on)
        if callback then callback(on) end
    end)
    return row, SetState
end

-- Slider row — returns wrap frame and label
local function SliderRow(parent, labelTxt, minV, maxV, defV, lo, cb)
    local wrap = MkFrame(parent, UDim2.new(1,0,0,34), nil, Color3.new(0,0,0), lo)
    wrap.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,0,15); lbl.BackgroundTransparency = 1
    lbl.Text = labelTxt .. ": " .. tostring(defV)
    lbl.TextSize = 11; lbl.Font = Enum.Font.Gotham
    lbl.TextColor3 = Config.TEXT_DIM
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = wrap

    local track = MkFrame(wrap, UDim2.new(1,0,0,5), UDim2.new(0,0,0,19),
        Color3.fromRGB(38,25,60))
    Corner(track,3); Stroke(track, Config.BORDER,1)

    local pct = (defV - minV) / math.max(maxV - minV, 1)
    local fill = MkFrame(track, UDim2.new(pct,0,1,0), nil, Config.ACCENT_DIM)
    Corner(fill,3)

    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0,9,0,9); knob.Position = UDim2.new(pct,-5,0.5,-5)
    knob.BackgroundColor3 = Config.ACCENT_GLOW; knob.Text = ""
    knob.AutoButtonColor = false; knob.Parent = track; Corner(knob,5)

    local sliding = false
    knob.MouseButton1Down:Connect(function() sliding = true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not sliding or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local abs = track.AbsolutePosition; local sz = track.AbsoluteSize
        local rel = math.clamp((i.Position.X - abs.X) / sz.X, 0, 1)
        local val = math.floor(minV + rel*(maxV-minV))
        lbl.Text = labelTxt .. ": " .. tostring(val)
        fill.Size = UDim2.new(rel,0,1,0); knob.Position = UDim2.new(rel,-5,0.5,-5)
        if cb then cb(val) end
    end)
    return wrap, lbl
end

-- ── FOV Circle (pure UI — NO asset ID needed) ────────────────
--  Built from 64 thin Frame segments arranged in a circle.
local function BuildFOVCircle(parent)
    local container = Instance.new("Frame")
    container.Name = "FOVCircle"
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.ZIndex = 20
    container.Visible = false
    container.Parent = parent

    local SEGS = 64
    local segments = {}
    for i = 1, SEGS do
        local seg = Instance.new("Frame")
        seg.BackgroundColor3 = Config.ACCENT
        seg.BackgroundTransparency = 0.1
        seg.BorderSizePixel = 0
        seg.AnchorPoint = Vector2.new(0.5, 1)   -- pivot at bottom center
        seg.ZIndex = 20
        seg.Parent = container
        segments[i] = seg
    end

    -- Update every frame
    RunService.RenderStepped:Connect(function()
        local show = State.TrackingActive and Config.ShowFOV
        container.Visible = show
        if not show then return end

        local r   = Config.FOV
        local cx  = Camera.ViewportSize.X / 2
        local cy  = Camera.ViewportSize.Y / 2
        local dia = r * 2
        container.Size     = UDim2.new(0, dia, 0, dia)
        container.Position = UDim2.new(0, cx, 0, cy)

        local segLen = (2 * math.pi * r) / SEGS + 1  -- arc length per segment
        local thick  = 1.5

        for i, seg in ipairs(segments) do
            local angle = (2 * math.pi * (i - 1)) / SEGS
            local px = r + math.sin(angle) * r
            local py = r - math.cos(angle) * r
            seg.Size     = UDim2.new(0, thick, 0, segLen)
            seg.Position = UDim2.new(0, px, 0, py)
            seg.Rotation = math.deg(angle)
        end
    end)

    return container
end

-- ── Main GUI Build ────────────────────────────────────────────

function GUIModule.Build()
    local sg = Instance.new("ScreenGui")
    sg.Name = "ZmeiHubGUI"; sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true; sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = PlayerGui

    -- FOV circle lives on the ScreenGui directly
    BuildFOVCircle(sg)

    -- ── Window ───────────────────────────────────────────────
    local win = MkFrame(sg, UDim2.new(0,490,0,340), UDim2.new(0.5,-245,0.5,-170),
        Config.BG_DARK)
    win.Name = "ZmeiWin"; win.ClipsDescendants = true
    Corner(win,8); Stroke(win, Config.ACCENT_DIM, 1.5)

    -- ── Title bar ────────────────────────────────────────────
    local titleBar = MkFrame(win, UDim2.new(1,0,0,30), nil, Config.BG_MID)
    titleBar.ZIndex = 3
    -- bottom accent line
    local tline = MkFrame(titleBar, UDim2.new(1,0,0,1), UDim2.new(0,0,1,-1), Config.ACCENT_DIM)
    tline.ZIndex = 3

    local hubLbl = Instance.new("TextLabel")
    hubLbl.Size = UDim2.new(0,95,1,0); hubLbl.Position = UDim2.new(0,8,0,0)
    hubLbl.BackgroundTransparency = 1; hubLbl.Text = "ZmeiHub v2.0"
    hubLbl.TextSize = 11; hubLbl.Font = Enum.Font.GothamBold
    hubLbl.TextColor3 = Config.ACCENT_GLOW
    hubLbl.TextXAlignment = Enum.TextXAlignment.Left
    hubLbl.ZIndex = 4; hubLbl.Parent = titleBar

    local sepLbl = Instance.new("TextLabel")
    sepLbl.Size = UDim2.new(0,8,1,0); sepLbl.Position = UDim2.new(0,98,0,0)
    sepLbl.BackgroundTransparency = 1; sepLbl.Text = "│"; sepLbl.TextSize = 11
    sepLbl.Font = Enum.Font.Gotham; sepLbl.TextColor3 = Config.TEXT_DIM
    sepLbl.ZIndex = 4; sepLbl.Parent = titleBar

    -- ── TAB SYSTEM ───────────────────────────────────────────
    -- Each tab has a button in the title bar + a page frame in the body
    local tabNames   = {"Aimbot", "Settings", "FOV", "Points"}
    local tabButtons = {}
    local tabPages   = {}
    local activeTab  = "Aimbot"

    local function SwitchTab(name)
        activeTab = name
        for _, n in ipairs(tabNames) do
            tabButtons[n].TextColor3 = (n == name) and Config.ACCENT_GLOW or Config.TEXT_DIM
            -- underline for active tab
            tabButtons[n].FontFace = (n == name)
                and Font.fromEnum(Enum.Font.GothamBold)
                or  Font.fromEnum(Enum.Font.Gotham)
            if tabPages[n] then
                tabPages[n].Visible = (n == name)
            end
        end
    end

    local tabX = 108
    for _, name in ipairs(tabNames) do
        local tb = Instance.new("TextButton")
        tb.Size = UDim2.new(0,60,1,-4); tb.Position = UDim2.new(0,tabX,0,2)
        tb.BackgroundTransparency = 1; tb.Text = name; tb.TextSize = 10
        tb.Font = Enum.Font.Gotham
        tb.TextColor3 = Config.TEXT_DIM; tb.AutoButtonColor = false
        tb.ZIndex = 4; tb.Parent = titleBar
        tabButtons[name] = tb
        tabX = tabX + 62
        tb.MouseButton1Click:Connect(function() SwitchTab(name) end)
    end

    -- Gear icon (visual only — same as Settings tab shortcut)
    local gearBtn = Instance.new("TextButton")
    gearBtn.Size = UDim2.new(0,22,1,0); gearBtn.Position = UDim2.new(1,-26,0,0)
    gearBtn.BackgroundTransparency = 1; gearBtn.Text = "⚙"; gearBtn.TextSize = 13
    gearBtn.TextColor3 = Config.TEXT_DIM; gearBtn.AutoButtonColor = false
    gearBtn.ZIndex = 4; gearBtn.Parent = titleBar
    gearBtn.MouseButton1Click:Connect(function() SwitchTab("Settings") end)

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
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                     startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    -- ── Body container ───────────────────────────────────────
    local body = MkFrame(win, UDim2.new(1,0,1,-30), UDim2.new(0,0,0,30), Config.BG_DARK)

    -- Helper: build a two-column page
    local function TwoColPage(name)
        local page = MkFrame(body, UDim2.new(1,0,1,0), nil, Color3.new(0,0,0))
        page.BackgroundTransparency = 1; page.Visible = false
        tabPages[name] = page

        local left = MkScroll(page, UDim2.new(0.5,-1,1,0), UDim2.new(0,0,0,0))
        ListLayout(left, 4); Padding(left,8,8,8,6)

        local div = MkFrame(page, UDim2.new(0,1,1,0), UDim2.new(0.5,-1,0,0), Config.BORDER)

        local right = MkScroll(page, UDim2.new(0.5,-1,1,0), UDim2.new(0.5,1,0,0))
        ListLayout(right, 4); Padding(right,8,8,6,8)

        return page, left, right
    end

    -- Helper: single-column page
    local function OneColPage(name)
        local page = MkFrame(body, UDim2.new(1,0,1,0), nil, Color3.new(0,0,0))
        page.BackgroundTransparency = 1; page.Visible = false
        tabPages[name] = page
        local col = MkScroll(page, UDim2.new(1,0,1,0))
        ListLayout(col, 4); Padding(col,8,8,12,12)
        return page, col
    end

    -- =========================================================
    --  TAB: AIMBOT
    -- =========================================================
    local _, aLeft, aRight = TwoColPage("Aimbot")

    -- LEFT — targeting controls
    SecHeader(aLeft, "Targeting", 1)

    CheckRow(aLeft, "Master Enable", 2, function(v)
        State.TrackingActive = v
        if v then
            AimbotModule.Enable()
        else
            AimbotModule.Disable()
            -- clear all ESP when master off
            if not Config.ESPChickens and not Config.ESPPlayers then
                for m in pairs(State.ESPHighlights) do
                    local hl = State.ESPHighlights[m]
                    if hl then hl:Destroy(); State.ESPHighlights[m] = nil end
                end
            end
        end
    end)

    CheckRow(aLeft, "Auto-Aim (Snap to Chicken)", 3, function(v)
        Config.AutoAimEnabled = v
        if v then AimbotModule.Enable() else AimbotModule.Disable() end
    end)

    CheckRow(aLeft, "No Recoil", 4, function(v)
        Config.NoRecoilEnabled = v
    end)

    SecHeader(aLeft, "Aim Settings", 5)
    SliderRow(aLeft, "Smoothness", 1, 100,
        math.floor(Config.AimSmooth * 100), 6,
        function(v) Config.AimSmooth = v / 100 end)

    SliderRow(aLeft, "FOV Amount", 10, 500, Config.FOV, 7,
        function(v) Config.FOV = v end)

    -- RIGHT — ESP controls
    SecHeader(aRight, "ESP - Chickens", 1)

    CheckRow(aRight, "Highlight Chickens", 2, function(v)
        Config.ESPChickens = v
        ESPModule.RefreshChickens()
    end)

    SecHeader(aRight, "ESP - Players", 3)

    CheckRow(aRight, "Highlight Other Players", 4, function(v)
        Config.ESPPlayers = v
        ESPModule.RefreshPlayers()
    end)

    SecHeader(aRight, "FOV Circle", 5)

    CheckRow(aRight, "Show FOV Circle", 6, function(v)
        Config.ShowFOV = v
    end)

    -- Chicken ESP colour info
    local espInfo = MkFrame(aRight, UDim2.new(1,0,0,38), nil, Config.BG_CARD, 7)
    Corner(espInfo,5); Stroke(espInfo, Config.BORDER,1)
    Padding(espInfo,4,4,8,8)

    local function SwatchInfo(parent, col, label, yOff)
        local sw = Instance.new("Frame")
        sw.Size = UDim2.new(0,10,0,10); sw.Position = UDim2.new(0,0,0,yOff)
        sw.BackgroundColor3 = col; sw.BorderSizePixel = 0; sw.Parent = parent; Corner(sw,2)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,-16,0,12); lbl.Position = UDim2.new(0,14,0,yOff-1)
        lbl.BackgroundTransparency = 1; lbl.Text = label; lbl.TextSize = 10
        lbl.Font = Enum.Font.Gotham; lbl.TextColor3 = Config.TEXT_DIM
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = parent
    end
    SwatchInfo(espInfo, Config.ESP_CHICKEN, "Chickens", 4)
    SwatchInfo(espInfo, Config.ESP_PLAYER,  "Players",  18)

    -- =========================================================
    --  TAB: SETTINGS
    -- =========================================================
    local _, sCol = OneColPage("Settings")

    SecHeader(sCol, "Aim Behaviour", 1)
    SliderRow(sCol, "Aim Smooth (lower=faster)", 1, 100,
        math.floor(Config.AimSmooth * 100), 2,
        function(v) Config.AimSmooth = v / 100 end)

    SecHeader(sCol, "No Recoil", 3)
    CheckRow(sCol, "Enable No Recoil", 4, function(v)
        Config.NoRecoilEnabled = v
    end)

    local noRecoilNote = MkFrame(sCol, UDim2.new(1,0,0,30), nil, Config.BG_CARD, 5)
    Corner(noRecoilNote,5); Stroke(noRecoilNote, Config.BORDER,1)
    local noteLbl = Instance.new("TextLabel")
    noteLbl.Size = UDim2.new(1,-10,1,0); noteLbl.Position = UDim2.new(0,6,0,0)
    noteLbl.BackgroundTransparency = 1
    noteLbl.Text = "Cancels BodyVelocity recoil forces each frame."
    noteLbl.TextSize = 10; noteLbl.Font = Enum.Font.Gotham
    noteLbl.TextWrapped = true; noteLbl.TextColor3 = Config.TEXT_DIM
    noteLbl.TextXAlignment = Enum.TextXAlignment.Left; noteLbl.Parent = noRecoilNote

    SecHeader(sCol, "Manual Training Mode", 6)
    CheckRow(sCol, "Disable Auto-Aim (manual practice)", 7, function(v)
        Config.AutoAimEnabled = not v
        if v then AimbotModule.Disable() end
    end)

    local trainNote = MkFrame(sCol, UDim2.new(1,0,0,30), nil, Config.BG_CARD, 8)
    Corner(trainNote,5); Stroke(trainNote, Config.BORDER,1)
    local trainLbl = Instance.new("TextLabel")
    trainLbl.Size = UDim2.new(1,-10,1,0); trainLbl.Position = UDim2.new(0,6,0,0)
    trainLbl.BackgroundTransparency = 1
    trainLbl.Text = "Train manually with no recoil but no aimbot."
    trainLbl.TextSize = 10; trainLbl.Font = Enum.Font.Gotham
    trainLbl.TextWrapped = true; trainLbl.TextColor3 = Config.TEXT_DIM
    trainLbl.TextXAlignment = Enum.TextXAlignment.Left; trainLbl.Parent = trainNote

    -- =========================================================
    --  TAB: FOV
    -- =========================================================
    local _, fLeft, fRight = TwoColPage("FOV")

    SecHeader(fLeft, "Field of View", 1)
    CheckRow(fLeft, "Show FOV Circle", 2, function(v) Config.ShowFOV = v end)

    SliderRow(fLeft, "FOV Radius (px)", 10, 500, Config.FOV, 3,
        function(v) Config.FOV = v end)

    SecHeader(fLeft, "Appearance", 4)
    SliderRow(fLeft, "Circle Opacity", 0, 10, 9, 5, function(v)
        -- 0=transparent, 10=opaque  →  maps to ImageTransparency
        -- handled via segment color alpha in future version
    end)

    SecHeader(fRight, "Info", 1)
    local fovNote = MkFrame(fRight, UDim2.new(1,0,0,60), nil, Config.BG_CARD, 2)
    Corner(fovNote,5); Stroke(fovNote, Config.BORDER,1)
    Padding(fovNote,6,6,8,8)
    local fn = Instance.new("TextLabel")
    fn.Size = UDim2.new(1,0,1,0); fn.BackgroundTransparency = 1
    fn.Text = "The FOV circle shows the screen radius used to detect chickens. Only chickens inside the circle are targeted by the aimbot."
    fn.TextSize = 10; fn.Font = Enum.Font.Gotham
    fn.TextWrapped = true; fn.TextColor3 = Config.TEXT_DIM
    fn.TextXAlignment = Enum.TextXAlignment.Left
    fn.TextYAlignment = Enum.TextYAlignment.Top
    fn.Parent = fovNote

    -- =========================================================
    --  TAB: POINTS
    -- =========================================================
    local _, pCol = OneColPage("Points")

    SecHeader(pCol, "Score", 1)

    local scorCard = MkFrame(pCol, UDim2.new(1,0,0,50), nil, Config.BG_CARD, 2)
    Corner(scorCard,6); Stroke(scorCard, Config.BORDER,1)

    local scorTitle = Instance.new("TextLabel")
    scorTitle.Size = UDim2.new(1,0,0,18); scorTitle.Position = UDim2.new(0,0,0,6)
    scorTitle.BackgroundTransparency = 1; scorTitle.Text = "CURRENT SCORE"
    scorTitle.TextSize = 9; scorTitle.Font = Enum.Font.GothamBold
    scorTitle.TextColor3 = Config.TEXT_DIM; scorTitle.Parent = scorCard

    local scorVal = Instance.new("TextLabel")
    scorVal.Name = "PointsValue"
    scorVal.Size = UDim2.new(1,0,0,28); scorVal.Position = UDim2.new(0,0,0,20)
    scorVal.BackgroundTransparency = 1; scorVal.Text = "0"
    scorVal.TextSize = 26; scorVal.Font = Enum.Font.GothamBold
    scorVal.TextColor3 = Config.ACCENT_GLOW; scorVal.Parent = scorCard
    GUIModule.PointsLabel = scorVal

    SecHeader(pCol, "Per Kill", 3)
    SliderRow(pCol, "Points Per Kill", 1, 50, Config.PointsPerKill, 4,
        function(v) Config.PointsPerKill = v end)
    SliderRow(pCol, "Bonus Range (studs)", 10, 200, Config.BonusRange, 5,
        function(v) Config.BonusRange = v end)

    -- ── Status bar ───────────────────────────────────────────
    local statusBar = MkFrame(win, UDim2.new(1,0,0,18), UDim2.new(0,0,1,-18), Config.BG_MID)
    statusBar.ZIndex = 5
    MkFrame(statusBar, UDim2.new(1,0,0,1), nil, Config.ACCENT_DIM).ZIndex = 5
    local stLbl = Instance.new("TextLabel")
    stLbl.Size = UDim2.new(1,0,1,0); stLbl.BackgroundTransparency = 1
    stLbl.Text = "ZmeiHub v2.0  ·  Chicken Tracker  ·  Educational Script"
    stLbl.TextSize = 9; stLbl.Font = Enum.Font.Gotham
    stLbl.TextColor3 = Config.TEXT_DIM; stLbl.ZIndex = 6; stLbl.Parent = statusBar

    -- Activate the default tab
    SwitchTab("Aimbot")
end

-- ============================================================
--  KILL DETECTION
-- ============================================================
local KillDetection = {}

function KillDetection.Watch()
    local folder = workspace:WaitForChild(Config.ChickenFolderName, 10)
    if not folder then
        warn("[ZmeiHub] Folder '" .. Config.ChickenFolderName .. "' not found!")
        return
    end

    folder.ChildRemoved:Connect(function(model)
        if State.TrackingActive then
            local pts = PointsModule.AwardKill(model)
            if GUIModule.PointsLabel then
                GUIModule.PointsLabel.Text = tostring(pts)
                TweenService:Create(GUIModule.PointsLabel, TweenInfo.new(0.1),{TextSize=32}):Play()
                task.delay(0.15, function()
                    TweenService:Create(GUIModule.PointsLabel, TweenInfo.new(0.1),{TextSize=26}):Play()
                end)
            end
        end
        -- Remove ESP from dead chicken
        local hl = State.ESPHighlights[model]
        if hl then hl:Destroy(); State.ESPHighlights[model] = nil end
    end)

    folder.ChildAdded:Connect(function(model)
        task.wait(0.1)
        if Config.ESPChickens then
            AddHL(model, Config.ESP_CHICKEN, Color3.new(1,1,1))
        end
    end)
end

-- ============================================================
--  MAIN LOOP
-- ============================================================
RunService.RenderStepped:Connect(function()
    -- Aimbot
    AimbotModule.Update()
    -- No recoil
    NoRecoilModule.Update()
    -- ESP refresh (throttled — every 10 frames)
    if (tick() * 10) % 1 < 0.1 then
        ESPModule.RefreshAll()
    end
end)

-- ============================================================
--  INIT
-- ============================================================
local function Init()
    GUIModule.Build()
    task.spawn(KillDetection.Watch)
    print("[ZmeiHub] v2.0 loaded successfully.")
end

Init()

--[[
  ╔══════════════════════════════════════════════════════════════╗
  ║                     ZMEI HUB v2 SETUP                       ║
  ╠══════════════════════════════════════════════════════════════╣
  ║  1. Script location:                                         ║
  ║     StarterPlayer > StarterPlayerScripts                     ║
  ║                                                              ║
  ║  2. Workspace > Folder named "Chickens"                      ║
  ║     Each chicken Model needs "HumanoidRootPart"              ║
  ║                                                              ║
  ║  3. ReplicatedStorage > RemoteEvent "ChickenKilled"          ║
  ║     (for server-side leaderboard syncing)                    ║
  ╠══════════════════════════════════════════════════════════════╣
  ║  FEATURES:                                                   ║
  ║  • Auto-Aim    — locks camera onto nearest chicken in FOV    ║
  ║  • No Recoil   — cancels BodyVelocity recoil each frame      ║
  ║  • ESP Chickens — orange Highlight, shows through walls      ║
  ║  • ESP Players  — blue Highlight on all other players        ║
  ║  • FOV Circle   — pure UI circle (no broken asset ID)        ║
  ║  • Tab system   — Aimbot / Settings / FOV / Points           ║
  ║  • Settings tab — gear icon clickable, manual training mode  ║
  ╚══════════════════════════════════════════════════════════════╝
]]
