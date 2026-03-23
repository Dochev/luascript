-- ============================================================
--  CHICKEN SHOOTER GAME - Auto-Tracking System
--  Script Type : LocalScript (place in StarterPlayerScripts)
--  Author      : Educational Script for Roblox Studio
--  Description : Modular GUI with aim assist, auto-aim, ESP,
--                FOV slider, toggle, and point counter.
-- ============================================================

-- ┌─────────────────────────────────────────────────────────┐
-- │                     SERVICES                            │
-- └─────────────────────────────────────────────────────────┘
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")

-- ┌─────────────────────────────────────────────────────────┐
-- │                     REFERENCES                          │
-- └─────────────────────────────────────────────────────────┘
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")
local Camera       = workspace.CurrentCamera
local Mouse        = LocalPlayer:GetMouse()

-- ============================================================
--  MODULE: CONFIG
--  Central place to tweak all game settings.
-- ============================================================
local Config = {
    -- Chicken model settings
    ChickenFolderName  = "Chickens",   -- Folder in workspace that holds chicken models
    ChickenRootName    = "HumanoidRootPart", -- Root part name on each chicken

    -- Tracking settings
    FOV                = 150,           -- Default FOV radius (pixels) for nearest-chicken detection
    AimAssistSmooth    = 0.12,          -- Smoothing factor for aim assist (0 = instant, 1 = no movement)
    AutoAimEnabled     = false,         -- Auto-aim toggle (snaps camera)
    AimAssistEnabled   = false,         -- Aim assist toggle (smooth track)
    ESPEnabled         = false,         -- ESP highlight toggle

    -- Points
    PointsPerKill      = 10,            -- Points awarded when a chicken is eliminated
    BonusPointsRange   = 50,            -- Extra bonus points if chicken was within this stud range

    -- Colors
    ESPColor           = Color3.fromRGB(255, 80, 80),
    FOVCircleColor     = Color3.fromRGB(255, 255, 100),
    GUIAccent          = Color3.fromRGB(255, 90, 40),
}

-- ============================================================
--  MODULE: STATE
--  Tracks runtime state across modules.
-- ============================================================
local State = {
    Points          = 0,
    CurrentTarget   = nil,   -- Current locked chicken model
    ESPHighlights   = {},    -- Table[model] = Highlight instance
    TrackingActive  = false, -- Master on/off switch
}

-- ============================================================
--  MODULE: UTILITIES
--  Helper functions reused across modules.
-- ============================================================
local Utils = {}

-- Returns all chicken models inside the Chickens folder
function Utils.GetChickens()
    local folder = workspace:FindFirstChild(Config.ChickenFolderName)
    if not folder then return {} end
    return folder:GetChildren()
end

-- Returns the world position of a chicken's root part
function Utils.GetChickenPosition(model)
    local root = model:FindFirstChild(Config.ChickenRootName)
    if root then return root.Position end
    return nil
end

-- Returns the screen position of a world-space Vector3
function Utils.WorldToScreen(worldPos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen
end

-- Returns screen center as Vector2
function Utils.ScreenCenter()
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

-- Finds the chicken closest to screen center that is within FOV radius
function Utils.FindNearestChicken()
    local chickens   = Utils.GetChickens()
    local center     = Utils.ScreenCenter()
    local best       = nil
    local bestDist   = math.huge

    for _, model in ipairs(chickens) do
        local worldPos = Utils.GetChickenPosition(model)
        if worldPos then
            local screenPos, onScreen = Utils.WorldToScreen(worldPos)
            if onScreen then
                local dist = (screenPos - center).Magnitude
                if dist < Config.FOV and dist < bestDist then
                    bestDist = dist
                    best     = model
                end
            end
        end
    end

    return best
end

-- ============================================================
--  MODULE: ESP
--  Adds/removes highlight boxes on chicken models.
-- ============================================================
local ESPModule = {}

-- Adds a Highlight to a single chicken model
function ESPModule.AddHighlight(model)
    if State.ESPHighlights[model] then return end
    local hl = Instance.new("Highlight")
    hl.FillColor      = Config.ESPColor
    hl.OutlineColor   = Color3.new(1, 1, 1)
    hl.FillTransparency    = 0.55
    hl.OutlineTransparency = 0
    hl.Adornee  = model
    hl.Parent   = model
    State.ESPHighlights[model] = hl
end

-- Removes a Highlight from a single chicken model
function ESPModule.RemoveHighlight(model)
    local hl = State.ESPHighlights[model]
    if hl then
        hl:Destroy()
        State.ESPHighlights[model] = nil
    end
end

-- Refreshes all ESP highlights based on current toggle state
function ESPModule.Refresh()
    local chickens = Utils.GetChickens()
    if Config.ESPEnabled then
        for _, model in ipairs(chickens) do
            ESPModule.AddHighlight(model)
        end
    else
        for model, _ in pairs(State.ESPHighlights) do
            ESPModule.RemoveHighlight(model)
        end
    end
end

-- ============================================================
--  MODULE: TRACKING
--  Handles aim assist and auto-aim logic each frame.
-- ============================================================
local TrackingModule = {}

-- Smoothly nudges the camera toward target (aim assist)
function TrackingModule.AimAssist(target)
    local worldPos = Utils.GetChickenPosition(target)
    if not worldPos then return end

    local cf       = Camera.CFrame
    local targetCF = CFrame.lookAt(cf.Position, worldPos)
    Camera.CFrame  = cf:Lerp(targetCF, Config.AimAssistSmooth)
end

-- Snaps camera directly onto target (auto-aim)
function TrackingModule.AutoAim(target)
    local worldPos = Utils.GetChickenPosition(target)
    if not worldPos then return end
    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, worldPos)
end

-- Called every frame via RunService
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
--  Awards points and fires kill events.
-- ============================================================
local PointsModule = {}

-- Call this whenever a chicken is eliminated
function PointsModule.AwardKill(chickenModel)
    local bonus   = 0
    local root    = chickenModel:FindFirstChild(Config.ChickenRootName)
    if root then
        local dist = (root.Position - Camera.CFrame.Position).Magnitude
        if dist <= Config.BonusPointsRange then
            bonus = 5   -- Bonus for close-range kill
        end
    end

    State.Points = State.Points + Config.PointsPerKill + bonus

    -- Fire to server (wire up a RemoteEvent named "ChickenKilled" in ReplicatedStorage)
    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("ChickenKilled")
    if remote then
        remote:FireServer(State.Points)
    end

    -- Return updated points so GUI can refresh
    return State.Points
end

-- ============================================================
--  MODULE: GUI
--  Builds and manages the ScreenGui.
-- ============================================================
local GUIModule = {}

-- ── Helpers ──────────────────────────────────────────────────

local function MakeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
end

local function MakeStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color     = color or Color3.fromRGB(80,80,80)
    s.Thickness = thickness or 1.5
    s.Parent    = parent
end

local function MakeLabel(parent, text, size, bold, color)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size       = UDim2.fromScale(1, 1)
    l.Text       = text
    l.TextSize   = size or 14
    l.Font       = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextColor3 = color or Color3.new(1,1,1)
    l.Parent     = parent
    return l
end

-- Animates a toggle button color
local function AnimateToggle(btn, state)
    local target = state
        and Color3.fromRGB(80, 200, 120)
        or  Color3.fromRGB(60, 60, 70)
    TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = target}):Play()
end

-- ── Build GUI ─────────────────────────────────────────────────

function GUIModule.Build()
    -- Root ScreenGui
    local sg = Instance.new("ScreenGui")
    sg.Name            = "ChickenTrackerGUI"
    sg.ResetOnSpawn    = false
    sg.IgnoreGuiInset  = true
    sg.Parent          = PlayerGui

    -- ── Main Window ──────────────────────────────────────────
    local window = Instance.new("Frame")
    window.Name              = "Window"
    window.Size              = UDim2.new(0, 280, 0, 370)
    window.Position          = UDim2.new(0, 24, 0.5, -185)
    window.BackgroundColor3  = Color3.fromRGB(18, 18, 22)
    window.BorderSizePixel   = 0
    window.Parent            = sg
    MakeCorner(window, 12)
    MakeStroke(window, Color3.fromRGB(60, 60, 75), 1.5)

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size             = UDim2.new(1, 0, 0, 44)
    titleBar.BackgroundColor3 = Color3.fromRGB(255, 90, 40)
    titleBar.BorderSizePixel  = 0
    titleBar.Parent           = window
    MakeCorner(titleBar, 12)

    -- Patch bottom corners of title bar
    local patch = Instance.new("Frame")
    patch.Size              = UDim2.new(1, 0, 0, 12)
    patch.Position          = UDim2.new(0, 0, 1, -12)
    patch.BackgroundColor3  = Color3.fromRGB(255, 90, 40)
    patch.BorderSizePixel   = 0
    patch.Parent            = titleBar

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size                 = UDim2.new(1, -44, 1, 0)
    titleLbl.Position             = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text                 = "🐔  Chicken Tracker"
    titleLbl.TextSize             = 16
    titleLbl.Font                 = Enum.Font.GothamBold
    titleLbl.TextColor3           = Color3.new(1, 1, 1)
    titleLbl.TextXAlignment       = Enum.TextXAlignment.Left
    titleLbl.Parent               = titleBar

    -- Drag functionality
    local dragging, dragInput, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = input.Position
            startPos  = window.Position
        end
    end)
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            window.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- ── Content Frame ─────────────────────────────────────────
    local content = Instance.new("Frame")
    content.Size             = UDim2.new(1, 0, 1, -44)
    content.Position         = UDim2.new(0, 0, 0, 44)
    content.BackgroundTransparency = 1
    content.Parent           = window

    local layout = Instance.new("UIListLayout")
    layout.Padding           = UDim.new(0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent            = content

    local padding = Instance.new("UIPadding")
    padding.PaddingTop    = UDim.new(0, 12)
    padding.PaddingLeft   = UDim.new(0, 14)
    padding.PaddingRight  = UDim.new(0, 14)
    padding.Parent        = content

    -- ── Points Display ────────────────────────────────────────
    local pointsFrame = Instance.new("Frame")
    pointsFrame.Size             = UDim2.new(1, 0, 0, 54)
    pointsFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    pointsFrame.Parent           = content
    MakeCorner(pointsFrame, 8)

    local pointsTitle = Instance.new("TextLabel")
    pointsTitle.Size                  = UDim2.new(1, 0, 0, 20)
    pointsTitle.Position              = UDim2.new(0, 0, 0, 6)
    pointsTitle.BackgroundTransparency = 1
    pointsTitle.Text                  = "POINTS"
    pointsTitle.TextSize              = 10
    pointsTitle.Font                  = Enum.Font.GothamBold
    pointsTitle.TextColor3            = Color3.fromRGB(180, 180, 200)
    pointsTitle.LetterSpacing         = 3
    pointsTitle.Parent                = pointsFrame

    local pointsValue = Instance.new("TextLabel")
    pointsValue.Name                  = "PointsValue"
    pointsValue.Size                  = UDim2.new(1, 0, 0, 28)
    pointsValue.Position              = UDim2.new(0, 0, 0, 22)
    pointsValue.BackgroundTransparency = 1
    pointsValue.Text                  = "0"
    pointsValue.TextSize              = 26
    pointsValue.Font                  = Enum.Font.GothamBold
    pointsValue.TextColor3            = Config.GUIAccent
    pointsValue.Parent                = pointsFrame

    -- ── Section: Master Toggle ────────────────────────────────
    local function MakeToggleRow(labelText, defaultState, callback)
        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1, 0, 0, 40)
        row.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
        row.Parent           = content
        MakeCorner(row, 8)

        local lbl = Instance.new("TextLabel")
        lbl.Size                  = UDim2.new(1, -60, 1, 0)
        lbl.Position              = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text                  = labelText
        lbl.TextSize              = 13
        lbl.Font                  = Enum.Font.Gotham
        lbl.TextColor3            = Color3.new(1, 1, 1)
        lbl.TextXAlignment        = Enum.TextXAlignment.Left
        lbl.Parent                = row

        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0, 44, 0, 24)
        btn.Position         = UDim2.new(1, -54, 0.5, -12)
        btn.BackgroundColor3 = defaultState and Color3.fromRGB(80,200,120) or Color3.fromRGB(60,60,70)
        btn.Text             = ""
        btn.Parent           = row
        MakeCorner(btn, 12)

        -- Knob
        local knob = Instance.new("Frame")
        knob.Size             = UDim2.new(0, 18, 0, 18)
        knob.Position         = defaultState and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        knob.BackgroundColor3 = Color3.new(1, 1, 1)
        knob.Parent           = btn
        MakeCorner(knob, 9)

        local isOn = defaultState
        btn.MouseButton1Click:Connect(function()
            isOn = not isOn
            AnimateToggle(btn, isOn)
            TweenService:Create(knob, TweenInfo.new(0.2), {
                Position = isOn
                    and UDim2.new(1, -21, 0.5, -9)
                    or  UDim2.new(0, 3,   0.5, -9)
            }):Play()
            callback(isOn)
        end)

        return row
    end

    -- Master tracking toggle
    MakeToggleRow("🔴  Tracking Active", false, function(val)
        State.TrackingActive = val
        if not val then
            -- Clear all ESP when master is off
            for model, _ in pairs(State.ESPHighlights) do
                ESPModule.RemoveHighlight(model)
            end
        end
    end)

    MakeToggleRow("🎯  Auto-Aim (Snap)", false, function(val)
        Config.AutoAimEnabled = val
    end)

    MakeToggleRow("🧲  Aim Assist (Smooth)", false, function(val)
        Config.AimAssistEnabled = val
    end)

    MakeToggleRow("👁️  ESP Highlights", false, function(val)
        Config.ESPEnabled = val
        ESPModule.Refresh()
    end)

    -- ── FOV Slider ────────────────────────────────────────────
    local fovFrame = Instance.new("Frame")
    fovFrame.Size             = UDim2.new(1, 0, 0, 60)
    fovFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    fovFrame.Parent           = content
    MakeCorner(fovFrame, 8)

    local fovLabel = Instance.new("TextLabel")
    fovLabel.Size                  = UDim2.new(0.6, 0, 0, 20)
    fovLabel.Position              = UDim2.new(0, 12, 0, 8)
    fovLabel.BackgroundTransparency = 1
    fovLabel.Text                  = "FOV Radius"
    fovLabel.TextSize              = 13
    fovLabel.Font                  = Enum.Font.Gotham
    fovLabel.TextColor3            = Color3.new(1, 1, 1)
    fovLabel.TextXAlignment        = Enum.TextXAlignment.Left
    fovLabel.Parent                = fovFrame

    local fovValue = Instance.new("TextLabel")
    fovValue.Size                  = UDim2.new(0.35, 0, 0, 20)
    fovValue.Position              = UDim2.new(0.65, -12, 0, 8)
    fovValue.BackgroundTransparency = 1
    fovValue.Text                  = tostring(Config.FOV) .. " px"
    fovValue.TextSize              = 13
    fovValue.Font                  = Enum.Font.GothamBold
    fovValue.TextColor3            = Config.GUIAccent
    fovValue.TextXAlignment        = Enum.TextXAlignment.Right
    fovValue.Parent                = fovFrame

    -- Slider track
    local sliderTrack = Instance.new("Frame")
    sliderTrack.Size             = UDim2.new(1, -24, 0, 6)
    sliderTrack.Position         = UDim2.new(0, 12, 0, 38)
    sliderTrack.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    sliderTrack.Parent           = fovFrame
    MakeCorner(sliderTrack, 3)

    local sliderFill = Instance.new("Frame")
    sliderFill.Size             = UDim2.new(Config.FOV / 400, 0, 1, 0)
    sliderFill.BackgroundColor3 = Config.GUIAccent
    sliderFill.Parent           = sliderTrack
    MakeCorner(sliderFill, 3)

    local sliderKnob = Instance.new("TextButton")
    sliderKnob.Size             = UDim2.new(0, 16, 0, 16)
    sliderKnob.Position         = UDim2.new(Config.FOV / 400, -8, 0.5, -8)
    sliderKnob.BackgroundColor3 = Color3.new(1, 1, 1)
    sliderKnob.Text             = ""
    sliderKnob.Parent           = sliderTrack
    MakeCorner(sliderKnob, 8)

    -- Slider logic (drag)
    local sliding = false
    sliderKnob.MouseButton1Down:Connect(function() sliding = true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if sliding and i.UserInputType == Enum.UserInputType.MouseMovement then
            local trackAbs  = sliderTrack.AbsolutePosition
            local trackSize = sliderTrack.AbsoluteSize
            local relX = math.clamp((i.Position.X - trackAbs.X) / trackSize.X, 0, 1)
            Config.FOV = math.floor(relX * 400)
            fovValue.Text       = tostring(Config.FOV) .. " px"
            sliderFill.Size     = UDim2.new(relX, 0, 1, 0)
            sliderKnob.Position = UDim2.new(relX, -8, 0.5, -8)
        end
    end)

    -- ── FOV Circle (drawn on screen) ──────────────────────────
    local fovCircle = Instance.new("ImageLabel")
    fovCircle.Name                   = "FOVCircle"
    fovCircle.BackgroundTransparency = 1
    fovCircle.Image                  = "rbxassetid://3570695787"  -- circle outline asset
    fovCircle.ImageColor3            = Config.FOVCircleColor
    fovCircle.ImageTransparency      = 0.4
    fovCircle.AnchorPoint            = Vector2.new(0.5, 0.5)
    fovCircle.ZIndex                 = 10
    fovCircle.Parent                 = sg

    -- Update circle size/position every frame
    RunService.RenderStepped:Connect(function()
        local center = Utils.ScreenCenter()
        fovCircle.Position = UDim2.new(0, center.X, 0, center.Y)
        local d = Config.FOV * 2
        fovCircle.Size     = UDim2.new(0, d, 0, d)
        fovCircle.Visible  = State.TrackingActive
    end)

    -- ── Expose points label so PointsModule can update it ─────
    GUIModule.PointsLabel = pointsValue
end

-- ============================================================
--  MODULE: KILL DETECTION
--  Watches for chickens being removed and awards points.
-- ============================================================
local KillDetection = {}

function KillDetection.WatchFolder()
    local folder = workspace:WaitForChild(Config.ChickenFolderName, 10)
    if not folder then
        warn("[ChickenTracker] Could not find Chickens folder in workspace!")
        return
    end

    -- When a child (chicken) is removed from the folder → award points
    folder.ChildRemoved:Connect(function(model)
        if State.TrackingActive then
            local pts = PointsModule.AwardKill(model)
            if GUIModule.PointsLabel then
                GUIModule.PointsLabel.Text = tostring(pts)
                -- Pop animation
                TweenService:Create(GUIModule.PointsLabel, TweenInfo.new(0.1), {TextSize = 32}):Play()
                task.delay(0.15, function()
                    TweenService:Create(GUIModule.PointsLabel, TweenInfo.new(0.1), {TextSize = 26}):Play()
                end)
            end
        end
        -- Clean up ESP for removed chicken
        ESPModule.RemoveHighlight(model)
    end)

    -- When a new chicken spawns, add ESP if enabled
    folder.ChildAdded:Connect(function(model)
        if Config.ESPEnabled then
            task.wait(0.1)  -- small wait for model to fully load
            ESPModule.AddHighlight(model)
        end
    end)
end

-- ============================================================
--  INIT — Wire everything together
-- ============================================================
local function Init()
    -- Build the GUI
    GUIModule.Build()

    -- Start watching the chickens folder for kills
    task.spawn(KillDetection.WatchFolder)

    -- Main update loop
    RunService.RenderStepped:Connect(function()
        TrackingModule.Update()

        -- Keep ESP synced every few frames
        if Config.ESPEnabled then
            ESPModule.Refresh()
        end
    end)

    print("[ChickenTracker] ✅ System loaded successfully!")
end

Init()

-- ============================================================
--  USAGE NOTES FOR ROBLOX STUDIO
-- ============================================================
--[[
  SETUP STEPS:
  1. Place this script inside StarterPlayer > StarterPlayerScripts
  2. In workspace, create a Folder named "Chickens"
     - All chicken Models should be parented inside this folder
     - Each chicken Model must contain a part named "HumanoidRootPart"
  3. In ReplicatedStorage, create a RemoteEvent named "ChickenKilled"
     - Wire the server-side script to this event to sync points

  MODULES SUMMARY:
  ┌──────────────────┬──────────────────────────────────────────┐
  │ Config           │ All tunable settings in one place        │
  │ State            │ Runtime state (points, target, etc.)     │
  │ Utils            │ Shared helpers (find chickens, etc.)     │
  │ ESPModule        │ Highlight boxes on chickens              │
  │ TrackingModule   │ Aim assist & auto-aim logic              │
  │ PointsModule     │ Kill detection & point awarding          │
  │ GUIModule        │ Builds the ScreenGui                     │
  │ KillDetection    │ Watches folder for removed chickens      │
  └──────────────────┴──────────────────────────────────────────┘

  CUSTOMIZATION TIPS:
  - Change Config.PointsPerKill to adjust scoring
  - Change Config.AimAssistSmooth (0.05 = very smooth, 0.3 = snappy)
  - Change Config.ChickenFolderName to match your folder name
  - The FOV slider goes from 0 to 400 pixels radius
]]
