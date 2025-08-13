local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local Healthbar = {}

local screenGui = nil
local healthBarFrame = nil
local sanityBarFrame = nil
local healthFill = nil
local sanityFill = nil
local healthLabel = nil
local sanityLabel = nil
local clockTitleLabel = nil
local clockValueLabel = nil
local clockTitleFrame = nil

local BAR_WIDTH = 240
local BAR_HEIGHT = 28
local BAR_MARGIN = 24
local BAR_SPACING = 8

-- Sanity configuration
local MAX_SANITY = 100
local SANITY_DRAIN_RATE = 2 -- per second during night
local SANITY_REGEN_RATE = 1 -- per second during day
local currentSanity = MAX_SANITY
local isNight = false

function Healthbar:Initialize()
    -- Hide the default Roblox health bar
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
    
    -- Create ScreenGui
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HealthbarUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui
    -- Add clock title with gradient background (similar to compass UI)
    clockTitleFrame = Instance.new("Frame")
    clockTitleFrame.Name = "ClockTitleBackground"
    clockTitleFrame.Size = UDim2.new(0, BAR_WIDTH, 0, 22)
    clockTitleFrame.Position = UDim2.new(0, BAR_MARGIN, 1, -(BAR_HEIGHT * 2 + BAR_SPACING + BAR_MARGIN + 24))
    clockTitleFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    clockTitleFrame.BackgroundTransparency = 0
    clockTitleFrame.BorderSizePixel = 0
    clockTitleFrame.Parent = screenGui

    do
        local grad = Instance.new("UIGradient")
        grad.Rotation = 0
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
            ColorSequenceKeypoint.new(1, Color3.new(1,1,1)),
        })
        grad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.0, 1.0),
            NumberSequenceKeypoint.new(0.15, 0.6),
            NumberSequenceKeypoint.new(0.5, 0.2),
            NumberSequenceKeypoint.new(0.85, 0.6),
            NumberSequenceKeypoint.new(1.0, 1.0),
        })
        grad.Parent = clockTitleFrame
    end

    clockTitleLabel = Instance.new("TextLabel")
    clockTitleLabel.Name = "ClockTitle"
    clockTitleLabel.Size = UDim2.new(0, 80, 1, 0)
    clockTitleLabel.Position = UDim2.new(0, 10, 0, 0)
    clockTitleLabel.BackgroundTransparency = 1
    clockTitleLabel.Text = "Clock:"
    clockTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    clockTitleLabel.TextStrokeTransparency = 0.5
    clockTitleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    clockTitleLabel.TextSize = 25
    -- Use Patrick Hand font
    clockTitleLabel.Font = Enum.Font.PatrickHand
    clockTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    clockTitleLabel.TextYAlignment = Enum.TextYAlignment.Center
    clockTitleLabel.Parent = clockTitleFrame

    -- Clock time value shown next to the title
    clockValueLabel = Instance.new("TextLabel")
    clockValueLabel.Name = "ClockValue"
    clockValueLabel.Size = UDim2.new(1, 0, 1, 0)
    clockValueLabel.Position = UDim2.new(0, 0, 0, 0)
    clockValueLabel.BackgroundTransparency = 1
    clockValueLabel.Text = "00:00"
    clockValueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    clockValueLabel.TextStrokeTransparency = 0.35
    clockValueLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    clockValueLabel.TextSize = 25
    -- Use Patrick Hand font
    clockValueLabel.Font = Enum.Font.PatrickHand
    clockValueLabel.TextXAlignment = Enum.TextXAlignment.Center
    clockValueLabel.TextYAlignment = Enum.TextYAlignment.Center
    clockValueLabel.Parent = clockTitleFrame

    -- Create health bar background
    healthBarFrame = Instance.new("Frame")
    healthBarFrame.Name = "HealthBarFrame"
    healthBarFrame.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
    healthBarFrame.Position = UDim2.new(0, BAR_MARGIN, 1, -(BAR_HEIGHT * 2 + BAR_SPACING + BAR_MARGIN))
    healthBarFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    healthBarFrame.BorderSizePixel = 0
    healthBarFrame.BackgroundTransparency = 0.15
    healthBarFrame.Parent = screenGui

    -- Create health fill
    healthFill = Instance.new("Frame")
    healthFill.Name = "HealthFill"
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.Position = UDim2.new(0, 0, 0, 0)
    healthFill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    healthFill.BorderSizePixel = 0
    healthFill.BackgroundTransparency = 0.05
    healthFill.Parent = healthBarFrame
    -- Subtle vertical gradient for 3D effect
    do
        local g = Instance.new("UIGradient")
        g.Rotation = 90
        g.Color = ColorSequence.new(Color3.new(1,1,1), Color3.new(1,1,1))
        g.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.0, 0.12),
            NumberSequenceKeypoint.new(0.5, 0.0),
            NumberSequenceKeypoint.new(1.0, 0.18),
        })
        g.Parent = healthFill
    end

    -- Create sanity bar background
    sanityBarFrame = Instance.new("Frame")
    sanityBarFrame.Name = "SanityBarFrame"
    sanityBarFrame.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
    sanityBarFrame.Position = UDim2.new(0, BAR_MARGIN, 1, -(BAR_HEIGHT + BAR_MARGIN))
    sanityBarFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    sanityBarFrame.BorderSizePixel = 0
    sanityBarFrame.BackgroundTransparency = 0.15
    sanityBarFrame.Parent = screenGui

    -- Create sanity fill
    sanityFill = Instance.new("Frame")
    sanityFill.Name = "SanityFill"
    sanityFill.Size = UDim2.new(1, 0, 1, 0)
    sanityFill.Position = UDim2.new(0, 0, 0, 0)
    sanityFill.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
    sanityFill.BorderSizePixel = 0
    sanityFill.BackgroundTransparency = 0.05
    sanityFill.Parent = sanityBarFrame
    -- Subtle vertical gradient for 3D effect
    do
        local g = Instance.new("UIGradient")
        g.Rotation = 90
        g.Color = ColorSequence.new(Color3.new(1,1,1), Color3.new(1,1,1))
        g.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.0, 0.12),
            NumberSequenceKeypoint.new(0.5, 0.0),
            NumberSequenceKeypoint.new(1.0, 0.18),
        })
        g.Parent = sanityFill
    end

    -- Add rounded corners to all bars
    local function addCorner(parent)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = parent
    end
    
    addCorner(healthBarFrame)
    addCorner(sanityBarFrame)
    addCorner(healthFill)
    addCorner(sanityFill)

    -- Health label
    healthLabel = Instance.new("TextLabel")
    healthLabel.Name = "HealthLabel"
    healthLabel.Size = UDim2.new(1, 0, 1, 0)
    healthLabel.Position = UDim2.new(0, 0, 0, 0)
    healthLabel.BackgroundTransparency = 1
    healthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    healthLabel.TextStrokeTransparency = 0.5
    healthLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    healthLabel.TextSize = 23
    healthLabel.Font = Enum.Font.PatrickHand
    healthLabel.TextXAlignment = Enum.TextXAlignment.Left
    healthLabel.Position = UDim2.new(0, 8, 0, 0)
    healthLabel.Size = UDim2.new(1, -8, 1, 0)
    healthLabel.TextYAlignment = Enum.TextYAlignment.Center
    healthLabel.Parent = healthBarFrame

    -- Sanity label
    sanityLabel = Instance.new("TextLabel")
    sanityLabel.Name = "SanityLabel"
    sanityLabel.Size = UDim2.new(1, 0, 1, 0)
    sanityLabel.Position = UDim2.new(0, 0, 0, 0)
    sanityLabel.BackgroundTransparency = 1
    sanityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    sanityLabel.TextStrokeTransparency = 0.5
    sanityLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    sanityLabel.TextSize = 23
    sanityLabel.Font = Enum.Font.PatrickHand
    sanityLabel.TextXAlignment = Enum.TextXAlignment.Left
    sanityLabel.Position = UDim2.new(0, 8, 0, 0)
    sanityLabel.Size = UDim2.new(1, -8, 1, 0)
    sanityLabel.TextYAlignment = Enum.TextYAlignment.Center
    sanityLabel.Parent = sanityBarFrame

    self:ConnectHealth()
    self:ConnectSanity()
    self:ConnectTimeSystem()
end

function Healthbar:ConnectHealth()
    local function updateHealth()
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local health = math.max(0, humanoid.Health)
        local maxHealth = math.max(1, humanoid.MaxHealth)
        local percent = health / maxHealth
        healthFill.Size = UDim2.new(percent, 0, 1, 0)
        healthLabel.Text = string.format("Health %d", math.floor(health))
    end

    local function onCharacterAdded(char)
        local humanoid = char:WaitForChild("Humanoid")
        humanoid.HealthChanged:Connect(updateHealth)
        humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealth)
        updateHealth()
    end

    if player.Character then
        onCharacterAdded(player.Character)
    end
    player.CharacterAdded:Connect(onCharacterAdded)
end

function Healthbar:ConnectSanity()
    -- Update sanity display
    local function updateSanityDisplay()
        local percent = currentSanity / MAX_SANITY
        sanityFill.Size = UDim2.new(percent, 0, 1, 0)
        sanityLabel.Text = string.format("Sanity %d", math.floor(currentSanity))
        
        -- Change color based on sanity level
        if currentSanity > 70 then
            sanityFill.BackgroundColor3 = Color3.fromRGB(100, 150, 255) -- Blue
        elseif currentSanity > 30 then
            sanityFill.BackgroundColor3 = Color3.fromRGB(255, 200, 100) -- Yellow
        else
            sanityFill.BackgroundColor3 = Color3.fromRGB(255, 100, 100) -- Red
        end
    end
    
    -- Initialize sanity display
    updateSanityDisplay()
    
    -- Sanity update loop
    local lastUpdate = tick()
    game:GetService("RunService").Heartbeat:Connect(function()
        local currentTime = tick()
        local deltaTime = currentTime - lastUpdate
        lastUpdate = currentTime
        
        if isNight then
            -- Drain sanity during night
            currentSanity = math.max(0, currentSanity - (SANITY_DRAIN_RATE * deltaTime))
        else
            -- Regenerate sanity during day
            currentSanity = math.min(MAX_SANITY, currentSanity + (SANITY_REGEN_RATE * deltaTime))
        end
        
        updateSanityDisplay()
    end)
end

function Healthbar:ConnectTimeSystem()
    -- Listen for clock updates to determine day/night
    if RemoteEvents.ClockUpdate then
        RemoteEvents.ClockUpdate.OnClientEvent:Connect(function(clockTime)
            -- Determine if it's night (between 18:00 and 6:00)
            isNight = clockTime >= 18 or clockTime < 6
        end)
    end
end

return Healthbar 