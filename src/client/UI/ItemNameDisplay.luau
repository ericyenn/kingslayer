-- UI component for displaying item names on hover
local ItemNameDisplay = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create the GUI elements
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ItemNameDisplay"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local nameLabel = Instance.new("TextLabel")
nameLabel.Name = "NameLabel"
nameLabel.Size = UDim2.new(0, 200, 0, 30)
nameLabel.Position = UDim2.new(0, 0, 0, 0)
nameLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
nameLabel.BackgroundTransparency = 0.3
nameLabel.BorderSizePixel = 0
nameLabel.Text = ""
nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
nameLabel.TextSize = 18
nameLabel.TextStrokeTransparency = 0
nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
nameLabel.Font = Enum.Font.SourceSansBold
nameLabel.Visible = false
nameLabel.Parent = screenGui

-- Add corner rounding
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = nameLabel

-- Tween info for smooth animations
local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

function ItemNameDisplay:ShowName(itemName, mousePosition)
    -- Set the text
    nameLabel.Text = itemName
    
    -- Position near mouse with offset
    local offset = Vector2.new(10, -35)
    nameLabel.Position = UDim2.new(0, mousePosition.X + offset.X, 0, mousePosition.Y + offset.Y)
    
    -- Show with tween
    nameLabel.Visible = true
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextTransparency = 1
    
    local showTween = TweenService:Create(nameLabel, tweenInfo, {
        BackgroundTransparency = 0.3,
        TextTransparency = 0
    })
    showTween:Play()
end

function ItemNameDisplay:HideName()
    -- Hide with tween
    local hideTween = TweenService:Create(nameLabel, tweenInfo, {
        BackgroundTransparency = 1,
        TextTransparency = 1
    })
    
    hideTween:Play()
    hideTween.Completed:Connect(function()
        nameLabel.Visible = false
    end)
end

function ItemNameDisplay:UpdatePosition(mousePosition)
    if nameLabel.Visible then
        local offset = Vector2.new(10, -35)
        nameLabel.Position = UDim2.new(0, mousePosition.X + offset.X, 0, mousePosition.Y + offset.Y)
    end
end

function ItemNameDisplay:IsVisible()
    return nameLabel.Visible
end

return ItemNameDisplay 