-- SacrificeData.luau
-- Data structures for sacrifice tracking

local SacrificeData = {}

-- Sacrifice tracking structure
SacrificeData.SacrificeTracker = {}
SacrificeData.SacrificeTracker.__index = SacrificeData.SacrificeTracker

function SacrificeData.SacrificeTracker.new()
    local self = setmetatable({
        sacrifices = {}, -- [ragdoll] = true
        playerSacrifices = {}, -- [ragdoll] = true (player sacrifices)
        count = 0,
        playerCount = 0, -- Count of player sacrifices
        altar = nil,
        lastTriggerTime = 0,
        hasPrayed = false, -- Track if player has prayed to the figure
        prayerFigure = nil -- Reference to the prayer figure
    }, SacrificeData.SacrificeTracker)
    
    return self
end

-- Add a sacrifice to the tracker
function SacrificeData.SacrificeTracker:addSacrifice(ragdoll)
    if not self.sacrifices[ragdoll] then
        self.sacrifices[ragdoll] = true
        self.count = self.count + 1
        print("Added sacrifice to altar. Count:", self.count)
        return true
    end
    return false
end

-- Remove a sacrifice from the tracker
function SacrificeData.SacrificeTracker:removeSacrifice(ragdoll)
    if self.sacrifices[ragdoll] then
        self.sacrifices[ragdoll] = nil
        self.count = self.count - 1
        print("Removed sacrifice from altar. Count:", self.count)
        return true
    end
    return false
end

-- Add a player sacrifice to the tracker
function SacrificeData.SacrificeTracker:addPlayerSacrifice(ragdoll)
    if not self.playerSacrifices[ragdoll] then
        self.playerSacrifices[ragdoll] = true
        self.playerCount = self.playerCount + 1
        print("Added player sacrifice to altar. Player count:", self.playerCount)
        return true
    end
    return false
end

-- Remove a player sacrifice from the tracker
function SacrificeData.SacrificeTracker:removePlayerSacrifice(ragdoll)
    if self.playerSacrifices[ragdoll] then
        self.playerSacrifices[ragdoll] = nil
        self.playerCount = self.playerCount - 1
        print("Removed player sacrifice from altar. Player count:", self.playerCount)
        return true
    end
    return false
end

-- Check if altar has enough sacrifices
function SacrificeData.SacrificeTracker:hasEnoughSacrifices()
    -- If there are any player sacrifices, only need 1
    if self.playerCount > 0 then
        return true
    end
    -- Otherwise need 3 enemy sacrifices
    return self.count >= 3
end

-- Get all current sacrifices
function SacrificeData.SacrificeTracker:getSacrifices()
    local sacrifices = {}
    for ragdoll, _ in pairs(self.sacrifices) do
        table.insert(sacrifices, ragdoll)
    end
    return sacrifices
end

-- Get all current player sacrifices
function SacrificeData.SacrificeTracker:getPlayerSacrifices()
    local playerSacrifices = {}
    for ragdoll, _ in pairs(self.playerSacrifices) do
        table.insert(playerSacrifices, ragdoll)
    end
    return playerSacrifices
end

-- Check if altar has any player sacrifices
function SacrificeData.SacrificeTracker:hasPlayerSacrifices()
    return self.playerCount > 0
end

-- Clear all sacrifices
function SacrificeData.SacrificeTracker:clearSacrifices()
    self.sacrifices = {}
    self.playerSacrifices = {}
    self.count = 0
    self.playerCount = 0
    self.hasPrayed = false -- Reset prayer state when sacrifices are cleared
end

-- Check if altar is on cooldown
function SacrificeData.SacrificeTracker:isOnCooldown()
    return (tick() - self.lastTriggerTime) < 30 -- 30 second cooldown
end

-- Set trigger time (when reward was spawned)
function SacrificeData.SacrificeTracker:setTriggerTime()
    self.lastTriggerTime = tick()
end

-- Set prayer state
function SacrificeData.SacrificeTracker:setPrayed(hasPrayed)
    self.hasPrayed = hasPrayed
    print("Prayer state updated:", hasPrayed)
end

-- Check if player has prayed
function SacrificeData.SacrificeTracker:hasPrayed()
    return self.hasPrayed
end

-- Set prayer figure reference
function SacrificeData.SacrificeTracker:setPrayerFigure(figure)
    self.prayerFigure = figure
end

-- Get prayer figure reference
function SacrificeData.SacrificeTracker:getPrayerFigure()
    return self.prayerFigure
end

return SacrificeData 