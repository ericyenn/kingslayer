-- Enhanced tooltip UI component for displaying item information on hover
local ItemTooltip = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create the GUI elements
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ItemTooltip"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local tooltipFrame = Instance.new("Frame")
tooltipFrame.Name = "TooltipFrame"
tooltipFrame.Size = UDim2.new(0, 250, 0, 80)
tooltipFrame.Position = UDim2.new(0, 0, 0, 0)
tooltipFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
tooltipFrame.BackgroundTransparency = 0.1
tooltipFrame.BorderSizePixel = 0
tooltipFrame.Visible = false
tooltipFrame.ZIndex = 1000
tooltipFrame.Parent = screenGui

-- Add corner rounding
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = tooltipFrame

-- Add border
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(100, 100, 100)
stroke.Thickness = 1
stroke.Parent = tooltipFrame

-- Title label (item name)
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, -16, 0, 24)
titleLabel.Position = UDim2.new(0, 8, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = ""
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 16
titleLabel.TextStrokeTransparency = 0
titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextYAlignment = Enum.TextYAlignment.Top
titleLabel.Parent = tooltipFrame

-- Description label
local descriptionLabel = Instance.new("TextLabel")
descriptionLabel.Name = "DescriptionLabel"
descriptionLabel.Size = UDim2.new(1, -16, 1, -40)
descriptionLabel.Position = UDim2.new(0, 8, 0, 32)
descriptionLabel.BackgroundTransparency = 1
descriptionLabel.Text = ""
descriptionLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
descriptionLabel.TextSize = 12
descriptionLabel.TextStrokeTransparency = 0
descriptionLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
descriptionLabel.Font = Enum.Font.SourceSans
descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
descriptionLabel.TextWrapped = true
descriptionLabel.Parent = tooltipFrame

-- Tween info for smooth animations
local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

function ItemTooltip:ShowTooltip(itemName, itemDescription, mousePosition)
    -- Set the text
    titleLabel.Text = itemName or "Unknown Item"
    descriptionLabel.Text = itemDescription or "No description available."
    
    -- Calculate text size and adjust frame size
    local titleSize = TextService:GetTextSize(titleLabel.Text, titleLabel.TextSize, titleLabel.Font, Vector2.new(234, math.huge))
    local descSize = TextService:GetTextSize(descriptionLabel.Text, descriptionLabel.TextSize, descriptionLabel.Font, Vector2.new(234, math.huge))
    
    local totalHeight = math.max(80, titleSize.Y + descSize.Y + 24)
    tooltipFrame.Size = UDim2.new(0, 250, 0, totalHeight)
    
    -- Position near mouse with offset and screen boundary checking
    local offset = Vector2.new(15, -totalHeight - 10)
    local screenSize = workspace.CurrentCamera.ViewportSize
    
    local posX = math.clamp(mousePosition.X + offset.X, 0, screenSize.X - 250)
    local posY = math.clamp(mousePosition.Y + offset.Y, 0, screenSize.Y - totalHeight)
    
    tooltipFrame.Position = UDim2.new(0, posX, 0, posY)
    
    -- Show with tween
    tooltipFrame.Visible = true
    tooltipFrame.BackgroundTransparency = 1
    titleLabel.TextTransparency = 1
    descriptionLabel.TextTransparency = 1
    stroke.Transparency = 1
    
    local showTween = TweenService:Create(tooltipFrame, tweenInfo, {
        BackgroundTransparency = 0.1
    })
    local titleTween = TweenService:Create(titleLabel, tweenInfo, {
        TextTransparency = 0
    })
    local descTween = TweenService:Create(descriptionLabel, tweenInfo, {
        TextTransparency = 0
    })
    local strokeTween = TweenService:Create(stroke, tweenInfo, {
        Transparency = 0
    })
    
    showTween:Play()
    titleTween:Play()
    descTween:Play()
    strokeTween:Play()
end

function ItemTooltip:HideTooltip()
    -- Hide with tween
    local hideTween = TweenService:Create(tooltipFrame, tweenInfo, {
        BackgroundTransparency = 1
    })
    local titleTween = TweenService:Create(titleLabel, tweenInfo, {
        TextTransparency = 1
    })
    local descTween = TweenService:Create(descriptionLabel, tweenInfo, {
        TextTransparency = 1
    })
    local strokeTween = TweenService:Create(stroke, tweenInfo, {
        Transparency = 1
    })
    
    hideTween:Play()
    titleTween:Play()
    descTween:Play()
    strokeTween:Play()
    
    hideTween.Completed:Connect(function()
        tooltipFrame.Visible = false
    end)
end

function ItemTooltip:UpdatePosition(mousePosition)
    if tooltipFrame.Visible then
        local offset = Vector2.new(15, -tooltipFrame.AbsoluteSize.Y - 10)
        local screenSize = workspace.CurrentCamera.ViewportSize
        
        local posX = math.clamp(mousePosition.X + offset.X, 0, screenSize.X - tooltipFrame.AbsoluteSize.X)
        local posY = math.clamp(mousePosition.Y + offset.Y, 0, screenSize.Y - tooltipFrame.AbsoluteSize.Y)
        
        tooltipFrame.Position = UDim2.new(0, posX, 0, posY)
    end
end

function ItemTooltip:IsVisible()
    return tooltipFrame.Visible
end

return ItemTooltip 