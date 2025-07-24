local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Healthbar = {}

local screenGui = nil
local barFrame = nil
local healthFill = nil
local healthLabel = nil

local BAR_WIDTH = 240
local BAR_HEIGHT = 28
local BAR_MARGIN = 24

function Healthbar:Initialize()
    -- Create ScreenGui
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HealthbarUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    -- Create bar background
    barFrame = Instance.new("Frame")
    barFrame.Name = "HealthBarFrame"
    barFrame.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
    barFrame.Position = UDim2.new(0, BAR_MARGIN, 1, -(BAR_HEIGHT + BAR_MARGIN))
    barFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    barFrame.BorderSizePixel = 0
    barFrame.BackgroundTransparency = 0.15
    barFrame.Parent = screenGui

    -- Create health fill
    healthFill = Instance.new("Frame")
    healthFill.Name = "HealthFill"
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.Position = UDim2.new(0, 0, 0, 0)
    healthFill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    healthFill.BorderSizePixel = 0
    healthFill.BackgroundTransparency = 0.05
    healthFill.Parent = barFrame

    -- Mask fill with UI corner
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = barFrame
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 8)
    fillCorner.Parent = healthFill

    -- Health label
    healthLabel = Instance.new("TextLabel")
    healthLabel.Name = "HealthLabel"
    healthLabel.Size = UDim2.new(1, 0, 1, 0)
    healthLabel.Position = UDim2.new(0, 0, 0, 0)
    healthLabel.BackgroundTransparency = 1
    healthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    healthLabel.TextStrokeTransparency = 0.5
    healthLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    healthLabel.TextSize = 18
    healthLabel.Font = Enum.Font.GothamBold
    healthLabel.TextXAlignment = Enum.TextXAlignment.Center
    healthLabel.TextYAlignment = Enum.TextYAlignment.Center
    healthLabel.Parent = barFrame

    self:ConnectHealth()
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
        healthLabel.Text = string.format("%d / %d", math.floor(health), math.floor(maxHealth))
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

return Healthbar 