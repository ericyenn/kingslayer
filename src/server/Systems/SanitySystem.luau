local SanitySystem = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

-- Configuration
local MAX_SANITY = 100
local MIN_SANITY = 0
local SANITY_DRAIN_RATE = 2 -- per second during night
local SANITY_REGEN_RATE = 1 -- per second during day

-- Player data storage
local playerSanity = {}

-- State
local isNight = false

function SanitySystem:Initialize()
    -- Initialize player data
    Players.PlayerAdded:Connect(function(player)
        playerSanity[player] = {
            current = MAX_SANITY,
            max = MAX_SANITY
        }
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        playerSanity[player] = nil
    end)
    
    -- Listen for time updates
    if RemoteEvents.ClockUpdate then
        RemoteEvents.ClockUpdate.OnServerEvent:Connect(function(clockTime)
            -- Determine if it's night (between 18:00 and 6:00)
            isNight = clockTime >= 18 or clockTime < 6
        end)
    end
    
    -- Start sanity update loop
    RunService.Heartbeat:Connect(function(deltaTime)
        self:UpdateSanity(deltaTime)
    end)
    
    print("SanitySystem initialized")
end

function SanitySystem:UpdateSanity(deltaTime)
    for player, data in pairs(playerSanity) do
        if player and player.Parent then -- Check if player still exists
            if isNight then
                -- Drain sanity during night
                data.current = math.max(MIN_SANITY, data.current - (SANITY_DRAIN_RATE * deltaTime))
            else
                -- Regenerate sanity during day
                data.current = math.min(data.max, data.current + (SANITY_REGEN_RATE * deltaTime))
            end
        end
    end
end

function SanitySystem:GetPlayerSanity(player)
    local data = playerSanity[player]
    if data then
        return data.current, data.max
    end
    return MAX_SANITY, MAX_SANITY
end

function SanitySystem:SetPlayerSanity(player, sanity)
    local data = playerSanity[player]
    if data then
        data.current = math.clamp(sanity, MIN_SANITY, data.max)
    end
end

function SanitySystem:ModifyPlayerSanity(player, amount)
    local data = playerSanity[player]
    if data then
        data.current = math.clamp(data.current + amount, MIN_SANITY, data.max)
    end
end

function SanitySystem:IsNight()
    return isNight
end

return SanitySystem 