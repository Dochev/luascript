-- ============================================================
--  CHICKEN SHOOTER GAME - Auto-Tracking System  (FIXED v2)
--  Script Type : LocalScript → StarterPlayer > StarterPlayerScripts
--  Fix Notes   : Content frame changed to ScrollingFrame with
--                AutomaticCanvasSize so toggles/slider never clip.
--                Window height increased. UIPadding scope fixed.
-- ============================================================

-- ┌─────────────────────────────────────────────────────────┐
-- │                     SERVICES                            │
-- └─────────────────────────────────────────────────────────┘
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

-- ┌─────────────────────────────────────────────────────────┐
-- │                     REFERENCES                          │
-- └─────────────────────────────────────────────────────────┘
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Camera      = workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

-- ============================================================
--  MODULE: CONFIG
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

    ESPColor          = Color3.fromRGB(255, 80,  80),
    FOVCircleColor    = Color3.fromRGB(255, 255, 100),
    GUIAccent         = Color3.fromRGB(255, 90,  40),
}

-- ============================================================
--  MODULE: STATE
-- ============================================================
local State = {
    Points         = 0,
    CurrentTarget  = nil,
    ESPHighlights  = {},
    TrackingActive = false,
}

-- ============================================================
--  MODULE: UTILITIES
-- ============================================================
local Utils = {}

function Utils.GetChickens()
    local folder = workspace:FindFirstChild(Config.ChickenFolderName)
    if not folder then return {} end
    return folder:GetChildren()
end

function Utils.GetChickenPosition(model)
    local root = model:FindFirstChild(Config.ChickenRootName)
    if root then return root.Position end
    return nil
end

function Utils.WorldToScreen(worldPos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen
end

function Utils.ScreenCenter()
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

function Utils.FindNearestChicken()
    local chickens = Utils.GetChickens()
    local center   = Utils.ScreenCenter()
    local best, bestDist = nil, math.huge

    for _, model in ipairs(chickens) do
        local worldPos = Utils.GetChickenPosition(model)
        if worldPos then
            local screenPos, onScreen = Utils.WorldToScreen(worldPos)
            if onScreen then
                local dist = (screenPos - center).Magnitude
                if dist < Config.FOV and dist < bestDist then
                    bestDist, best = dist, model
                end
            end
        end
    end
    return best
end

-- ============================================================
--  MODULE: ESP
-- ============================================================
local ESPModule = {}

function ESPModule.AddHighlight(model)
    if State.ESPHighlights[model] then return end
    local hl = Instance.new("Highlight")
    hl.FillColor           = Config.ESPColor
    hl.OutlineColor        = Color3.new(1, 1, 1)
    hl.FillTransparency    = 0.55
    hl.OutlineTransparency = 0
    hl.Adornee             = model
    hl.Parent              = model
    State.ESPHighlights[model] = hl
end

function ESPModule.RemoveHighlight(model)
    local hl = State.ESPHighlights[model]
    if hl then
        hl:Destroy()
        State.ESPHighlights[model] = nil
    end
end

function ESPModule.Refresh()
    local chickens = Utils.GetChickens()
    if Config.ESPEnabled then
        for _, model in ipairs(chickens) do ESPModule.AddHighlight(model) end
    else
        for model in pairs(State.ESPHighlights) do ESPModule.RemoveHighlight(model) end
    end
end

-- ============================================================
--  MODULE: TRACKING
-- ============================================================
local TrackingModule = {}

function TrackingModule.AimAssist(target)
    local worldPos = Utils.GetChickenPosition(target)
    if not worldPos then return end
    local cf = Camera.CFrame
    Camera.CFrame = cf:Lerp(CFrame.lookAt(cf.Position, worldPos), Config.AimAssistSmooth)
end

function TrackingModule.AutoAim(target)
    local worldPos = Utils.GetChickenPosition(target)
    if not worldPos then return end
    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, worldPos)
end

function TrackingModule.Update()
    if not State.TrackingActive then return end
    local target = Utils.FindNearestChicken()
    State.CurrentTarget = target
    if target then
        if Config.AutoAimEnabled then
            TrackingModule.AutoAim(target)
        elseif Config.AimAssistEnabled then
            TrackingModule.AimAssist(target)
        end
    end
end

-- ============================================================
--  MODULE: POINTS
-- ============================================================
local PointsModule = {}

function PointsModule.AwardKill(chickenModel)
    local bonus = 0
    local root  = chickenModel:FindFirstChild(Config.ChickenRootName)
    if root then
        local dist = (root.Position - Camera.CFrame.Position).Magnitude
        if dist <= Config.BonusPointsRange then bonus = 5 end
    end
    State.Points = State.Points + Config.PointsPerKill + bonus

    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("ChickenKilled")
    if remote then remote:FireServer(State.Points) end

    return State.Points
end

-- ============================================================
--  MODULE: GUI  (v2 - FIXED)
-- ============================================================
local GUIModule = {}

-- ── Shared helpers ────────────────────────────────────────────

local function Corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
end

local function Stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color     = color     or Color3.fromRGB(80, 80, 80)
    s.Thickness = thickness or 1.5
    s.Parent    = parent
end

local function AnimateToggle(btn, on)
    TweenService:Create(btn, TweenInfo.new(0.18), {
        BackgroundColor3 = on
            and Color3.fromRGB(80, 200, 120)
            or  Color3.fromRGB(55, 55, 68)
    }):Play()
end

-- ── Main build ────────────────────────────────────────────────

function GUIModule.Build()

    -- Root ScreenGui
    local sg = Instance.new("ScreenGui")
    sg.Name           = "ChickenTrackerGUI"
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = PlayerGui

    -- ── Window ───────────────────────────────────────────────
    local window = Instance.new("Frame")
    window.Name             = "Window"
    window.Size             = UDim2.new(0, 280, 0, 440)
    window.Position         = UDim2.new(0, 24, 0.5, -220)
    window.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    window.BorderSizePixel  = 0
    window.ClipsDescendants = true
    window.Parent           = sg
    Corner(window, 12)
    Stroke(window, Color3.fromRGB(55, 55, 72), 1.5)

    -- ── Title bar ────────────────────────────────────────────
    local titleBar = Instance.new("Frame")
    titleBar.Name             = "TitleBar"
    titleBar.Size             = UDim2.new(1, 0, 0, 46)
    titleBar.BackgroundColor3 = Color3.fromRGB(255, 90, 40)
    titleBar.BorderSizePixel  = 0
    titleBar.ZIndex           = 2
    titleBar.Parent           = window
    Corner(titleBar, 12)

    -- Square off bottom corners of title bar
    local tbPatch = Instance.new("Frame")
    tbPatch.Size             = UDim2.new(1, 0, 0, 14)
    tbPatch.Position         = UDim2.new(0, 0, 1, -14)
    tbPatch.BackgroundColor3 = Color3.fromRGB(255, 90, 40)
    tbPatch.BorderSizePixel  = 0
    tbPatch.ZIndex           = 2
    tbPatch.Parent           = titleBar

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size                   = UDim2.new(1, -16, 1, 0)
    titleLbl.Position               = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text                   = "🐔  Chicken Tracker"
    titleLbl.TextSize               = 16
    titleLbl.Font                   = Enum.Font.GothamBold
    titleLbl.TextColor3             = Color3.new(1, 1, 1)
    titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
    titleLbl.ZIndex                 = 3
    titleLbl.Parent                 = titleBar

    -- Drag logic
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = i.Position
            startPos  = window.Position
        end
    end)
    titleBar.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            window.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)

    -- ── CONTENT (ScrollingFrame — FIX for blank settings panel)
    --  AutomaticCanvasSize = Y  →  canvas grows with children,
    --  so nothing is ever clipped regardless of child count.
    local content = Instance.new("ScrollingFrame")
    content.Name                 = "Content"
    content.Size                 = UDim2.new(1, 0, 1, -46)
    content.Position             = UDim2.new(0, 0, 0, 46)
    content.BackgroundTransparency = 1
    content.BorderSizePixel      = 0
    content.ScrollBarThickness   = 0          -- invisible scrollbar
    content.CanvasSize           = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize  = Enum.AutomaticSize.Y
    content.Parent               = window

    local layout = Instance.new("UIListLayout")
    layout.Padding             = UDim.new(0, 8)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder           = Enum.SortOrder.LayoutOrder
    layout.FillDirection       = Enum.FillDirection.Vertical
    layout.Parent              = content

    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0, 12)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.PaddingLeft   = UDim.new(0, 12)
    pad.PaddingRight  = UDim.new(0, 12)
    pad.Parent        = content

    -- ── Points display ───────────────────────────────────────
    local pFrame = Instance.new("Frame")
    pFrame.Name             = "PointsFrame"
    pFrame.Size             = UDim2.new(1, 0, 0, 58)
    pFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
    pFrame.LayoutOrder      = 1
    pFrame.Parent           = content
    Corner(pFrame, 8)
    Stroke(pFrame, Color3.fromRGB(45, 45, 58))

    local pTitle = Instance.new("TextLabel")
    pTitle.Size                   = UDim2.new(1, 0, 0, 20)
    pTitle.Position               = UDim2.new(0, 0, 0, 8)
    pTitle.BackgroundTransparency = 1
    pTitle.Text                   = "POINTS"
    pTitle.TextSize               = 10
    pTitle.Font                   = Enum.Font.GothamBold
    pTitle.TextColor3             = Color3.fromRGB(170, 170, 195)
    pTitle.Parent                 = pFrame

    local pValue = Instance.new("TextLabel")
    pValue.Name                   = "PointsValue"
    pValue.Size                   = UDim2.new(1, 0, 0, 30)
    pValue.Position               = UDim2.new(0, 0, 0, 24)
    pValue.BackgroundTransparency = 1
    pValue.Text                   = "0"
    pValue.TextSize               = 28
    pValue.Font                   = Enum.Font.GothamBold
    pValue.TextColor3             = Config.GUIAccent
    pValue.Parent                 = pFrame

    -- ── Toggle factory ───────────────────────────────────────
    local toggleOrder = 2

    local function MakeToggle(label, default, callback)
        local row = Instance.new("Frame")
        row.Name             = "Row"
        row.Size             = UDim2.new(1, 0, 0, 42)
        row.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
        row.LayoutOrder      = toggleOrder
        row.Parent           = content
        Corner(row, 8)
        Stroke(row, Color3.fromRGB(45, 45, 58))
        toggleOrder += 1

        local lbl = Instance.new("TextLabel")
        lbl.Size                   = UDim2.new(1, -62, 1, 0)
        lbl.Position               = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text                   = label
        lbl.TextSize               = 13
        lbl.Font                   = Enum.Font.Gotham
        lbl.TextColor3             = Color3.fromRGB(225, 225, 235)
        lbl.TextXAlignment         = Enum.TextXAlignment.Left
        lbl.Parent                 = row

        local track = Instance.new("TextButton")
        track.Size             = UDim2.new(0, 46, 0, 26)
        track.Position         = UDim2.new(1, -56, 0.5, -13)
        track.BackgroundColor3 = default
            and Color3.fromRGB(80, 200, 120)
            or  Color3.fromRGB(55, 55, 68)
        track.Text             = ""
        track.AutoButtonColor  = false
        track.Parent           = row
        Corner(track, 13)

        local knob = Instance.new("Frame")
        knob.Size             = UDim2.new(0, 20, 0, 20)
        knob.Position         = default
            and UDim2.new(1, -23, 0.5, -10)
            or  UDim2.new(0,   3, 0.5, -10)
        knob.BackgroundColor3 = Color3.new(1, 1, 1)
        knob.Parent           = track
        Corner(knob, 10)

        local isOn = default
        track.MouseButton1Click:Connect(function()
            isOn = not isOn
            AnimateToggle(track, isOn)
            TweenService:Create(knob, TweenInfo.new(0.18), {
                Position = isOn
                    and UDim2.new(1, -23, 0.5, -10)
                    or  UDim2.new(0,   3, 0.5, -10)
            }):Play()
            callback(isOn)
        end)
    end

    -- ── 4 Toggle rows ────────────────────────────────────────
    MakeToggle("🔴  Tracking Active", false, function(v)
        State.TrackingActive = v
        if not v then
            for model in pairs(State.ESPHighlights) do
                ESPModule.RemoveHighlight(model)
            end
        end
    end)

    MakeToggle("🎯  Auto-Aim (Snap)", false, function(v)
        Config.AutoAimEnabled = v
    end)

    MakeToggle("🧲  Aim Assist (Smooth)", false, function(v)
        Config.AimAssistEnabled = v
    end)

    MakeToggle("👁️  ESP Highlights", false, function(v)
        Config.ESPEnabled = v
        ESPModule.Refresh()
    end)

    -- ── FOV Slider ───────────────────────────────────────────
    local fovFrame = Instance.new("Frame")
    fovFrame.Name             = "FOVSlider"
    fovFrame.Size             = UDim2.new(1, 0, 0, 66)
    fovFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
    fovFrame.LayoutOrder      = toggleOrder
    fovFrame.Parent           = content
    Corner(fovFrame, 8)
    Stroke(fovFrame, Color3.fromRGB(45, 45, 58))

    local fovLbl = Instance.new("TextLabel")
    fovLbl.Size                   = UDim2.new(0.55, 0, 0, 22)
    fovLbl.Position               = UDim2.new(0, 12, 0, 10)
    fovLbl.BackgroundTransparency = 1
    fovLbl.Text                   = "FOV Radius"
    fovLbl.TextSize               = 13
    fovLbl.Font                   = Enum.Font.Gotham
    fovLbl.TextColor3             = Color3.fromRGB(225, 225, 235)
    fovLbl.TextXAlignment         = Enum.TextXAlignment.Left
    fovLbl.Parent                 = fovFrame

    local fovVal = Instance.new("TextLabel")
    fovVal.Size                   = UDim2.new(0.4, 0, 0, 22)
    fovVal.Position               = UDim2.new(0.6, -12, 0, 10)
    fovVal.BackgroundTransparency = 1
    fovVal.Text                   = tostring(Config.FOV) .. " px"
    fovVal.TextSize               = 13
    fovVal.Font                   = Enum.Font.GothamBold
    fovVal.TextColor3             = Config.GUIAccent
    fovVal.TextXAlignment         = Enum.TextXAlignment.Right
    fovVal.Parent                 = fovFrame

    local sliderTrack = Instance.new("Frame")
    sliderTrack.Size             = UDim2.new(1, -24, 0, 6)
    sliderTrack.Position         = UDim2.new(0, 12, 0, 42)
    sliderTrack.BackgroundColor3 = Color3.fromRGB(48, 48, 62)
    sliderTrack.Parent           = fovFrame
    Corner(sliderTrack, 3)

    local sliderFill = Instance.new("Frame")
    sliderFill.Size             = UDim2.new(Config.FOV / 400, 0, 1, 0)
    sliderFill.BackgroundColor3 = Config.GUIAccent
    sliderFill.Parent           = sliderTrack
    Corner(sliderFill, 3)

    local sliderKnob = Instance.new("TextButton")
    sliderKnob.Size             = UDim2.new(0, 16, 0, 16)
    sliderKnob.Position         = UDim2.new(Config.FOV / 400, -8, 0.5, -8)
    sliderKnob.BackgroundColor3 = Color3.new(1, 1, 1)
    sliderKnob.Text             = ""
    sliderKnob.AutoButtonColor  = false
    sliderKnob.Parent           = sliderTrack
    Corner(sliderKnob, 8)

    local sliding = false
    sliderKnob.MouseButton1Down:Connect(function() sliding = true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not sliding then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local abs  = sliderTrack.AbsolutePosition
        local size = sliderTrack.AbsoluteSize
        local rel  = math.clamp((i.Position.X - abs.X) / size.X, 0, 1)
        Config.FOV          = math.floor(rel * 400)
        fovVal.Text         = tostring(Config.FOV) .. " px"
        sliderFill.Size     = UDim2.new(rel, 0, 1, 0)
        sliderKnob.Position = UDim2.new(rel, -8, 0.5, -8)
    end)

    -- ── FOV circle overlay ───────────────────────────────────
    local circle = Instance.new("ImageLabel")
    circle.Name                   = "FOVCircle"
    circle.BackgroundTransparency = 1
    circle.Image                  = "rbxassetid://3570695787"
    circle.ImageColor3            = Config.FOVCircleColor
    circle.ImageTransparency      = 0.35
    circle.AnchorPoint            = Vector2.new(0.5, 0.5)
    circle.ZIndex                 = 10
    circle.Parent                 = sg

    RunService.RenderStepped:Connect(function()
        local c = Utils.ScreenCenter()
        circle.Position = UDim2.new(0, c.X, 0, c.Y)
        circle.Size     = UDim2.new(0, Config.FOV * 2, 0, Config.FOV * 2)
        circle.Visible  = State.TrackingActive
    end)

    -- Expose for kill detection
    GUIModule.PointsLabel = pValue
end

-- ============================================================
--  MODULE: KILL DETECTION
-- ============================================================
local KillDetection = {}

function KillDetection.WatchFolder()
    local folder = workspace:WaitForChild(Config.ChickenFolderName, 10)
    if not folder then
        warn("[ChickenTracker] Folder '" .. Config.ChickenFolderName .. "' not found!")
        return
    end

    folder.ChildRemoved:Connect(function(model)
        if State.TrackingActive then
            local pts = PointsModule.AwardKill(model)
            if GUIModule.PointsLabel then
                GUIModule.PointsLabel.Text = tostring(pts)
                TweenService:Create(GUIModule.PointsLabel, TweenInfo.new(0.1), {TextSize = 34}):Play()
                task.delay(0.15, function()
                    TweenService:Create(GUIModule.PointsLabel, TweenInfo.new(0.1), {TextSize = 28}):Play()
                end)
            end
        end
        ESPModule.RemoveHighlight(model)
    end)

    folder.ChildAdded:Connect(function(model)
        if Config.ESPEnabled then
            task.wait(0.1)
            ESPModule.AddHighlight(model)
        end
    end)
end

-- ============================================================
--  INIT
-- ============================================================
local function Init()
    GUIModule.Build()
    task.spawn(KillDetection.WatchFolder)

    RunService.RenderStepped:Connect(function()
        TrackingModule.Update()
        if Config.ESPEnabled then ESPModule.Refresh() end
    end)

    print("[ChickenTracker] Loaded — v2 GUI fix applied.")
end

Init()

--[[
  SETUP CHECKLIST:
  1. Script: StarterPlayer > StarterPlayerScripts
  2. Workspace > Folder named "Chickens"
     - Each chicken Model must have a part: "HumanoidRootPart"
  3. ReplicatedStorage > RemoteEvent named "ChickenKilled"

  v2 BUG FIXES:
  - Content area is now a ScrollingFrame with AutomaticCanvasSize = Y
    so children are NEVER clipped regardless of window height
  - Window height bumped to 440px
  - UIPadding correctly scoped inside the scroll frame
  - ClipsDescendants = true on the outer window for clean corners
]]
