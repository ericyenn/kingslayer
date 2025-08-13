-- NotificationUI.luau
-- Client-side notification UI system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local NotificationUI = {}

-- Create notification GUI
function NotificationUI:CreateNotification(message, notificationType, duration)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NotificationGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player.PlayerGui
    
    -- Check if this is a quest completion notification (golden text, no background)
    local isQuestComplete = notificationType and notificationType == Color3.fromRGB(255, 255, 0) -- QUEST_COMPLETE type
    
    if isQuestComplete then
        -- Golden text notification (no background)
        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "QuestCompleteText"
        textLabel.Size = UDim2.new(0, 800, 0, 100)
        textLabel.Position = UDim2.new(0.5, -400, 0, -120) -- Start above screen
        textLabel.BackgroundTransparency = 1 -- No background
        textLabel.Text = message:upper() -- All caps
        textLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Golden color
        textLabel.TextSize = 48 -- Large text
        textLabel.Font = Enum.Font.GothamBlack -- Bold font
        textLabel.TextWrapped = true
        textLabel.Parent = screenGui
        
        -- Add stroke for golden glow effect
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 215, 0) -- Golden stroke
        stroke.Thickness = 1 -- Thin stroke to avoid making text unreadable
        stroke.Parent = textLabel
        
        -- Animate in
        local tweenIn = TweenService:Create(textLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -400, 0, 50)
        })
        tweenIn:Play()
        
        -- Wait and animate out
        task.spawn(function()
            task.wait(duration - 0.8) -- Wait before animating out
            
            local tweenOut = TweenService:Create(textLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -400, 0, -120)
            })
            tweenOut:Play()
            
            tweenOut.Completed:Connect(function()
                screenGui:Destroy()
            end)
        end)
    else
        -- Regular notification (with background)
        local notificationFrame = Instance.new("Frame")
        notificationFrame.Name = "NotificationFrame"
        notificationFrame.Size = UDim2.new(0, 400, 0, 60)
        notificationFrame.Position = UDim2.new(0.5, -200, 0, -100) -- Start above screen
        notificationFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        notificationFrame.BorderSizePixel = 0
        notificationFrame.Parent = screenGui
        
        -- Add corner radius
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = notificationFrame
        
        -- Add stroke
        local stroke = Instance.new("UIStroke")
        stroke.Color = notificationType or Color3.fromRGB(255, 255, 0)
        stroke.Thickness = 2
        stroke.Parent = notificationFrame
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "NotificationText"
        textLabel.Size = UDim2.new(1, -20, 1, -10)
        textLabel.Position = UDim2.new(0, 10, 0, 5)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = message
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.TextSize = 18
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextWrapped = true
        textLabel.Parent = notificationFrame
        
        -- Animate in
        local tweenIn = TweenService:Create(notificationFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -200, 0, 20)
        })
        tweenIn:Play()
        
        -- Wait and animate out
        task.spawn(function()
            task.wait(duration - 0.5) -- Wait before animating out
            
            local tweenOut = TweenService:Create(notificationFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -200, 0, -100)
            })
            tweenOut:Play()
            
            tweenOut.Completed:Connect(function()
                screenGui:Destroy()
            end)
        end)
    end
end

-- Initialize notification system
function NotificationUI:Initialize()
    RemoteEvents.ShowNotification.OnClientEvent:Connect(function(message, notificationType, duration)
        self:CreateNotification(message, notificationType, duration)
    end)
    
    print("NotificationUI initialized")
end

return NotificationUI
