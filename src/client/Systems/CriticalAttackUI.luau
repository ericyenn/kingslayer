-- Critical Attack UI system for managing the critical timing bar
local CriticalAttackUI = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local BAR_CONFIG = {
    width = 18,  -- Scaled up from 12 to 18 (1.5x larger)
    height = 150, -- Scaled up from 100 to 150 (1.5x larger)
    offsetX = -60, -- Adjusted offset for bigger bar (1.5x larger)
    backgroundColor = Color3.fromRGB(0, 0, 0), -- Changed to black
    borderColor = Color3.fromRGB(120, 120, 120),
    transparency = 0.3 -- Increased opacity (more transparent) for better visibility
}

local CRITICAL_CONFIG = {
    minPosition = 0.1, -- 10% from top
    maxPosition = 0.7, -- 70% from top (leaves room for zone height)
    minSize = 0.15,    -- 15% of bar height
    maxSize = 0.25,    -- 25% of bar height
    color = Color3.fromRGB(255, 255, 255), -- White highlight
    transparency = 0.0 -- Make it fully opaque white
}

local INDICATOR_CONFIG = {
    height = 4,        -- Scaled up from 3 to 4 (proportional to larger bar)
    color = Color3.fromRGB(255, 200, 0), -- Gold/yellow
    speed = 2.0        -- Seconds for full up/down cycle
}

-- UI Elements
local criticalBarGui = nil
local criticalBarFrame = nil
local criticalZoneFrame = nil
local indicatorFrame = nil

-- State tracking
local isBarVisible = false
local indicatorAnimation = nil
local currentCriticalZone = nil

function CriticalAttackUI:Initialize()
    -- Set up global reference for other systems
    _G.CriticalAttackUI = self
    
    self:CreateCriticalBarUI()
    
    print("CriticalAttackUI initialized")
end

function CriticalAttackUI:CreateCriticalBarUI()
    -- Create critical bar GUI (initially hidden)
    criticalBarGui = Instance.new("ScreenGui")
    criticalBarGui.Name = "CriticalBarGui"
    criticalBarGui.ResetOnSpawn = false
    criticalBarGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    criticalBarGui.Enabled = false -- Start hidden
    criticalBarGui.Parent = playerGui
    
    -- Main bar frame (positioned relative to crosshair center)
    criticalBarFrame = Instance.new("Frame")
    criticalBarFrame.Name = "CriticalBar"
    criticalBarFrame.Size = UDim2.new(0, BAR_CONFIG.width, 0, BAR_CONFIG.height)
    criticalBarFrame.Position = UDim2.new(0.5, BAR_CONFIG.offsetX, 0.5, -BAR_CONFIG.height/2) -- Center vertically with crosshair
    criticalBarFrame.BackgroundColor3 = BAR_CONFIG.backgroundColor
    criticalBarFrame.BackgroundTransparency = BAR_CONFIG.transparency
    criticalBarFrame.BorderSizePixel = 0
    criticalBarFrame.Parent = criticalBarGui
    
    -- Add rounded corners to main bar
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 9) -- Scaled up from 6 to 9 (1.5x larger)
    barCorner.Parent = criticalBarFrame
    
    -- Add border stroke
    local borderStroke = Instance.new("UIStroke")
    borderStroke.Color = BAR_CONFIG.borderColor
    borderStroke.Thickness = 1
    borderStroke.Parent = criticalBarFrame
    
    -- Critical zone frame (will be positioned dynamically)
    criticalZoneFrame = Instance.new("Frame")
    criticalZoneFrame.Name = "CriticalZone"
    criticalZoneFrame.BackgroundColor3 = CRITICAL_CONFIG.color
    criticalZoneFrame.BackgroundTransparency = CRITICAL_CONFIG.transparency -- Use config transparency (0.0 for opaque white)
    criticalZoneFrame.BorderSizePixel = 0
    criticalZoneFrame.Parent = criticalBarFrame
    
    -- Add rounded corners to critical zone
    local zoneCorner = Instance.new("UICorner")
    zoneCorner.CornerRadius = UDim.new(0, 6) -- Scaled up from 4 to 6 (1.5x larger)
    zoneCorner.Parent = criticalZoneFrame
    
    -- Moving indicator frame
    indicatorFrame = Instance.new("Frame")
    indicatorFrame.Name = "Indicator"
    indicatorFrame.Size = UDim2.new(1, 0, 0, INDICATOR_CONFIG.height)
    indicatorFrame.Position = UDim2.new(0, 0, 0, 0) -- Start at top
    indicatorFrame.BackgroundColor3 = INDICATOR_CONFIG.color
    indicatorFrame.BackgroundTransparency = 0
    indicatorFrame.BorderSizePixel = 0
    indicatorFrame.Parent = criticalBarFrame
    
    -- Add rounded corners to indicator
    local indicatorCorner = Instance.new("UICorner")
    indicatorCorner.CornerRadius = UDim.new(0, 3) -- Scaled up from 2 to 3 (1.5x larger)
    indicatorCorner.Parent = indicatorFrame
    
    print("Critical bar UI created")
end

function CriticalAttackUI:GenerateCriticalZone()
    -- Generate random critical zone position and size
    local position = math.random(CRITICAL_CONFIG.minPosition * 100, CRITICAL_CONFIG.maxPosition * 100) / 100
    local size = math.random(CRITICAL_CONFIG.minSize * 100, CRITICAL_CONFIG.maxSize * 100) / 100
    
    -- Ensure zone doesn't exceed bar bounds
    local endPosition = math.min(position + size, 0.9)
    size = endPosition - position
    
    currentCriticalZone = {
        startPercent = position,
        endPercent = endPosition,
        size = size
    }
    
    -- Update critical zone visual
    criticalZoneFrame.Size = UDim2.new(1, 0, size, 0)
    criticalZoneFrame.Position = UDim2.new(0, 0, position, 0)
    
    print("Generated critical zone:", position, "to", endPosition, "(size:", size .. ")")
    
    return currentCriticalZone
end

function CriticalAttackUI:ShowCriticalBar()
    if isBarVisible then return end
    
    -- Generate new random critical zone
    self:GenerateCriticalZone()
    
    -- Show the bar
    criticalBarGui.Enabled = true
    isBarVisible = true
    
    -- Start indicator animation
    self:StartIndicatorAnimation()
    
    print("Critical bar shown with new zone")
end

function CriticalAttackUI:HideCriticalBar()
    if not isBarVisible then return end
    
    -- Hide the bar
    criticalBarGui.Enabled = false
    isBarVisible = false
    
    -- Stop indicator animation
    self:StopIndicatorAnimation()
    
    print("Critical bar hidden")
end

function CriticalAttackUI:StartIndicatorAnimation()
    -- Stop any existing animation
    self:StopIndicatorAnimation()
    
    -- Create continuous up/down animation
    local startPosition = UDim2.new(0, 0, 0, 0) -- Top
    local endPosition = UDim2.new(0, 0, 1, -INDICATOR_CONFIG.height) -- Bottom
    
    -- Forward declare functions
    local animateDown, animateUp
    
    animateDown = function()
        local tween = TweenService:Create(
            indicatorFrame,
            TweenInfo.new(INDICATOR_CONFIG.speed / 2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
            {Position = endPosition}
        )
        tween:Play()
        
        tween.Completed:Connect(function()
            if isBarVisible then
                animateUp()
            end
        end)
    end
    
    animateUp = function()
        local tween = TweenService:Create(
            indicatorFrame,
            TweenInfo.new(INDICATOR_CONFIG.speed / 2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
            {Position = startPosition}
        )
        tween:Play()
        
        tween.Completed:Connect(function()
            if isBarVisible then
                animateDown()
            end
        end)
    end
    
    -- Start with downward animation
    indicatorFrame.Position = startPosition
    animateDown()
    
    print("Indicator animation started")
end

function CriticalAttackUI:StopIndicatorAnimation()
    -- Note: TweenService automatically handles cleanup when objects are destroyed
    -- We just need to ensure isBarVisible is false to stop the animation loop
    print("Indicator animation stopped")
end

function CriticalAttackUI:IsIndicatorInCriticalZone()
    if not isBarVisible or not currentCriticalZone then
        return false
    end
    
    -- Get current indicator position as percentage of bar height
    local indicatorY = indicatorFrame.Position.Y.Scale
    
    -- Check if indicator is within critical zone
    local inZone = indicatorY >= currentCriticalZone.startPercent and 
                   indicatorY <= currentCriticalZone.endPercent
    
    return inZone
end

function CriticalAttackUI:ShowCriticalSuccessEffect()
    -- Flash the critical zone green briefly to indicate success
    if not criticalZoneFrame then return end
    
    local originalColor = criticalZoneFrame.BackgroundColor3
    local originalTransparency = criticalZoneFrame.BackgroundTransparency
    
    -- Flash bright green
    criticalZoneFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    criticalZoneFrame.BackgroundTransparency = 0
    
    -- Play critical timing success sound
    if _G.AudioSystem then
        _G.AudioSystem:PlayCriticalTimingSuccess()
    end
    
    -- Screen flash effect removed per user request
    
    -- Restore original color after brief flash
    local tween = TweenService:Create(
        criticalZoneFrame,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            BackgroundColor3 = originalColor,
            BackgroundTransparency = originalTransparency
        }
    )
    tween:Play()
    
    print("Critical success effect displayed")
end

function CriticalAttackUI:CreateScreenFlash()
    -- Create a brief white border flash effect for critical hits
    local flashGui = Instance.new("ScreenGui")
    flashGui.Name = "CriticalFlash"
    flashGui.ResetOnSpawn = false
    flashGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    flashGui.IgnoreGuiInset = true -- Ensure full screen coverage
    flashGui.Parent = playerGui
    
    local borderThickness = 20 -- Thickness of the border flash
    
    -- Top border
    local topBorder = Instance.new("Frame")
    topBorder.Name = "TopBorder"
    topBorder.Size = UDim2.new(1, 0, 0, borderThickness)
    topBorder.Position = UDim2.new(0, 0, 0, 0)
    topBorder.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- White flash
    topBorder.BackgroundTransparency = 0
    topBorder.BorderSizePixel = 0
    topBorder.Parent = flashGui
    
    -- Bottom border
    local bottomBorder = Instance.new("Frame")
    bottomBorder.Name = "BottomBorder"
    bottomBorder.Size = UDim2.new(1, 0, 0, borderThickness)
    bottomBorder.Position = UDim2.new(0, 0, 1, -borderThickness)
    bottomBorder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    bottomBorder.BackgroundTransparency = 0
    bottomBorder.BorderSizePixel = 0
    bottomBorder.Parent = flashGui
    
    -- Left border
    local leftBorder = Instance.new("Frame")
    leftBorder.Name = "LeftBorder"
    leftBorder.Size = UDim2.new(0, borderThickness, 1, 0)
    leftBorder.Position = UDim2.new(0, 0, 0, 0)
    leftBorder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    leftBorder.BackgroundTransparency = 0
    leftBorder.BorderSizePixel = 0
    leftBorder.Parent = flashGui
    
    -- Right border
    local rightBorder = Instance.new("Frame")
    rightBorder.Name = "RightBorder"
    rightBorder.Size = UDim2.new(0, borderThickness, 1, 0)
    rightBorder.Position = UDim2.new(1, -borderThickness, 0, 0)
    rightBorder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    rightBorder.BackgroundTransparency = 0
    rightBorder.BorderSizePixel = 0
    rightBorder.Parent = flashGui
    
    -- Create a table of all border frames for easy tweening
    local borderFrames = {topBorder, bottomBorder, leftBorder, rightBorder}
    
    -- Quick fade out and destroy
    for _, border in ipairs(borderFrames) do
        local tween = TweenService:Create(
            border,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 1}
        )
        tween:Play()
    end
    
    -- Destroy the GUI after animation completes
    task.wait(0.2)
    flashGui:Destroy()
end

function CriticalAttackUI:GetCriticalZoneInfo()
    return currentCriticalZone
end

function CriticalAttackUI:IsBarVisible()
    return isBarVisible
end

-- Cleanup function
function CriticalAttackUI:Cleanup()
    self:HideCriticalBar()
    
    if criticalBarGui then
        criticalBarGui:Destroy()
        criticalBarGui = nil
    end
    
    print("CriticalAttackUI cleanup completed")
end

return CriticalAttackUI 