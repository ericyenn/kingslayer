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
    healthLabel.TextSize = 16
    healthLabel.Font = Enum.Font.GothamBold
    healthLabel.TextXAlignment = Enum.TextXAlignment.Center
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
    sanityLabel.TextSize = 16
    sanityLabel.Font = Enum.Font.GothamBold
    sanityLabel.TextXAlignment = Enum.TextXAlignment.Center
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
        healthLabel.Text = string.format("Health: %d / %d", math.floor(health), math.floor(maxHealth))
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
        sanityLabel.Text = string.format("Sanity: %d / %d", math.floor(currentSanity), MAX_SANITY)
        
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