-- NotificationSystem.luau
-- Simple modular notification system for displaying messages to players

local NotificationSystem = {}

-- Notification types and their colors
NotificationSystem.TYPES = {
    QUEST_COMPLETE = Color3.fromRGB(255, 255, 0), -- Yellow
    SUCCESS = Color3.fromRGB(0, 255, 0), -- Green
    ERROR = Color3.fromRGB(255, 0, 0), -- Red
    INFO = Color3.fromRGB(0, 150, 255), -- Blue
}

-- Show notification to all players
function NotificationSystem:ShowToAll(message, notificationType, duration)
    duration = duration or 5 -- Default 5 seconds
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
    
    -- Send to all clients
    RemoteEvents.ShowNotification:FireAllClients(message, notificationType, duration)
end

-- Show notification to specific player
function NotificationSystem:ShowToPlayer(player, message, notificationType, duration)
    duration = duration or 5 -- Default 5 seconds
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
    
    -- Send to specific client
    RemoteEvents.ShowNotification:FireClient(player, message, notificationType, duration)
end

return NotificationSystem

