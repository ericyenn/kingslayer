local CompassUI = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI refs
local screenGui = nil
local container = nil
local content = nil
local centerMarker = nil
local degreeLabel = nil

-- Render loop connection
local renderConn = nil
local isActive = false
local lastYawDeg = nil

-- Layout config
local BAR_HEIGHT = 22
local BAR_WIDTH_PX = 320 -- shortened bar width
local TOP_OFFSET = 2 -- move even closer to top
local SCROLL_REPEAT_DEG = 720 -- scrolling repeats every 2 full rotations
local PIXELS_PER_DEG = 2 -- gentler scroll scale

local function getYawDegrees(): number
    -- Prefer HRP facing (character yaw), fallback to camera yaw
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local look = hrp.CFrame.LookVector
        local yaw = math.deg(math.atan2(look.X, look.Z))
        if yaw < 0 then yaw += 360 end
        return yaw
    end
    local cam = workspace.CurrentCamera
    if cam then
        local look = cam.CFrame.LookVector
        local yaw = math.deg(math.atan2(look.X, look.Z))
        if yaw < 0 then yaw += 360 end
        return yaw
    end
    return 0
end

local function headingToText(deg: number): string
    local dirs = {
        {name = "N", ang = 0}, {name = "NE", ang = 45}, {name = "E", ang = 90}, {name = "SE", ang = 135},
        {name = "S", ang = 180}, {name = "SW", ang = 225}, {name = "W", ang = 270}, {name = "NW", ang = 315}
    }
    local best, diff = "N", 360
    for _, d in ipairs(dirs) do
        local delta = math.abs(((deg - d.ang + 180) % 360) - 180)
        if delta < diff then best, diff = d.name, delta end
    end
    return string.format("%d° %s", math.floor(deg + 0.5) % 360, best)
end

local function buildUI()
screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CompassUI"
    screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

    container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.fromOffset(BAR_WIDTH_PX, BAR_HEIGHT)
    container.Position = UDim2.new(0.5, -BAR_WIDTH_PX/2, 0, TOP_OFFSET)
    container.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    container.BackgroundTransparency = 0
    container.BorderSizePixel = 0
    container.ClipsDescendants = true
    container.Parent = screenGui

    -- Whole-bar gradient: center least transparent, edges more transparent
    local bgGrad = Instance.new("UIGradient")
    bgGrad.Rotation = 0
    bgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(1, Color3.new(1,1,1)),
    })
    bgGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 1.0),
        NumberSequenceKeypoint.new(0.15, 0.6),
        NumberSequenceKeypoint.new(0.5, 0.2),
        NumberSequenceKeypoint.new(0.85, 0.6),
        NumberSequenceKeypoint.new(1.0, 1.0),
    })
    bgGrad.Parent = container

    content = Instance.new("Frame")
    content.Name = "Content"
    local drawDeg = SCROLL_REPEAT_DEG + math.ceil(BAR_WIDTH_PX / PIXELS_PER_DEG)
    content.Size = UDim2.fromOffset(drawDeg * PIXELS_PER_DEG, BAR_HEIGHT)
    content.Position = UDim2.fromOffset(0, 0)
    content.BackgroundTransparency = 1
    content.ZIndex = 1
    content.Parent = container

    -- Add labels at 45° (N, NE, E, SE, S, SW, W, NW) and subtle ticks at 15°
    for deg = 0, drawDeg do
        if deg % 15 == 0 then
            local tick = Instance.new("Frame")
            tick.Size = UDim2.fromOffset(1, 8)
            tick.Position = UDim2.fromOffset(math.floor(deg * PIXELS_PER_DEG), BAR_HEIGHT - 9)
            tick.BackgroundColor3 = Color3.fromRGB(190, 190, 190)
            tick.BorderSizePixel = 0
            tick.ZIndex = 2
            tick.Parent = content
        end
        if deg % 45 == 0 then
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.fromOffset(24, BAR_HEIGHT)
            lbl.Position = UDim2.fromOffset(math.floor(deg * PIXELS_PER_DEG) - 12, 0)
            lbl.BackgroundTransparency = 1
            local name
            local d = (deg % 360)
            if d == 0 then name = "N" elseif d == 45 then name = "NE" elseif d == 90 then name = "E" elseif d == 135 then name = "SE"
            elseif d == 180 then name = "S" elseif d == 225 then name = "SW" elseif d == 270 then name = "W" else name = "NW" end
            lbl.Text = name
            lbl.TextColor3 = Color3.fromRGB(255,255,255)
            lbl.TextStrokeTransparency = 0.6
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 12
            lbl.ZIndex = 2
            lbl.Parent = content
        end
    end

    centerMarker = Instance.new("Frame")
    centerMarker.Name = "CenterMarker"
    centerMarker.Size = UDim2.fromOffset(2, BAR_HEIGHT)
    centerMarker.Position = UDim2.fromOffset(BAR_WIDTH_PX/2 - 1, 0)
    centerMarker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    centerMarker.BorderSizePixel = 0
    centerMarker.ZIndex = 3
    centerMarker.Parent = container

    -- Bottom etch at the center (small notch)
    local bottomEtch = Instance.new("Frame")
    bottomEtch.Name = "BottomEtch"
    bottomEtch.Size = UDim2.fromOffset(8, 3)
    bottomEtch.Position = UDim2.fromOffset(BAR_WIDTH_PX/2 - 4, BAR_HEIGHT - 3)
    bottomEtch.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    bottomEtch.BorderSizePixel = 0
    bottomEtch.ZIndex = 3
    bottomEtch.Parent = container

    degreeLabel = Instance.new("TextLabel")
    degreeLabel.Name = "DegreeLabel"
    degreeLabel.Size = UDim2.fromOffset(120, 14)
    degreeLabel.Position = UDim2.new(0.5, -60, 0, TOP_OFFSET + BAR_HEIGHT + 2)
    degreeLabel.BackgroundTransparency = 1
    degreeLabel.Font = Enum.Font.Gotham
    degreeLabel.TextSize = 12
    degreeLabel.TextColor3 = Color3.fromRGB(255,255,255)
    degreeLabel.TextXAlignment = Enum.TextXAlignment.Center
    degreeLabel.Text = ""
    degreeLabel.ZIndex = 3
    degreeLabel.Parent = screenGui

    screenGui.Enabled = false
end

local function update()
    if not isActive or not content then return end
    local yaw = getYawDegrees()
    if lastYawDeg and math.abs(yaw - lastYawDeg) < 0.1 then return end
    lastYawDeg = yaw

    -- Content offset so that current yaw appears at center marker
    local totalWidth = SCROLL_REPEAT_DEG * PIXELS_PER_DEG
    local centerX = BAR_WIDTH_PX/2
    local desiredX = (yaw * PIXELS_PER_DEG) - centerX
    desiredX = desiredX % totalWidth
    content.Position = UDim2.fromOffset(-desiredX, 0)
    if degreeLabel then
        degreeLabel.Text = headingToText(yaw)
    end
end

function CompassUI:Initialize()
    if screenGui then return end
    buildUI()
end

function CompassUI:Show()
    self:Initialize()
    isActive = true
    if screenGui then screenGui.Enabled = true end
    if not renderConn then
        renderConn = RunService.RenderStepped:Connect(update)
    end
end

function CompassUI:Hide()
    isActive = false
    if screenGui then screenGui.Enabled = false end
    if renderConn then renderConn:Disconnect(); renderConn = nil end
end

return CompassUI


