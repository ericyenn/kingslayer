-- RewardProcessor.luau
-- Handles summoner spawning and cleanup for altar system

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RewardConfig = require(ReplicatedStorage.Shared.RewardConfig)

local RewardProcessor = {}

-- Spawn reward for an altar
function RewardProcessor:SpawnReward(altar, sacrifices, hasPlayerSacrifices)
    print("Spawning reward for altar:", altar:GetFullName())
    print("Sacrifices count:", #sacrifices)
    print("Has player sacrifices:", hasPlayerSacrifices)
    
    -- Calculate spawn position
    local spawnPosition = self:CalculateSpawnPosition(altar)
    
    -- Determine which reward to spawn
    local success
    if hasPlayerSacrifices then
        -- Spawn philosopher's stone if there are player sacrifices
        success = self:SpawnPhilosophersStone(spawnPosition)
    else
        -- Spawn summoner item for enemy sacrifices
        success = self:SpawnSummoner(spawnPosition)
    end
    
    if success then
        -- Clean up sacrifices
        self:CleanupSacrifices(sacrifices)
        print("Reward spawned successfully")
        return true
    else
        print("Failed to spawn reward")
        return false
    end
end

-- Calculate spawn position for reward
function RewardProcessor:CalculateSpawnPosition(altar)
    local spawnType = RewardConfig.SUMMONER_REWARD.spawnPosition
    local spawnFunction = RewardConfig.SPAWN_POSITIONS[spawnType]
    
    if spawnFunction then
        return spawnFunction(altar)
    else
        -- Default to altar center
        return altar.Position + Vector3.new(0, 2, 0)
    end
end

-- Spawn the summoner item
function RewardProcessor:SpawnSummoner(position)
    -- Get the ItemSpawnSystem from global
    local ItemSpawnSystem = _G.ItemSpawnSystem
    
    if not ItemSpawnSystem then
        warn("ItemSpawnSystem not available")
        return false
    end
    
    -- Spawn the summoner item
    local itemId = RewardConfig.SUMMONER_REWARD.itemId
    local spawnedItem = ItemSpawnSystem.SpawnItem(itemId, position)
    
    if spawnedItem then
        print("Spawned summoner item at:", position)
        return true
    else
        warn("Failed to spawn summoner item")
        return false
    end
end

-- Spawn the philosopher's stone
function RewardProcessor:SpawnPhilosophersStone(position)
    -- Get the ItemSpawnSystem from global
    local ItemSpawnSystem = _G.ItemSpawnSystem
    
    if not ItemSpawnSystem then
        warn("ItemSpawnSystem not available")
        return false
    end
    
    -- Spawn the philosopher's stone
    local itemId = RewardConfig.PHILOSOPHERS_STONE_REWARD.itemId
    local spawnedItem = ItemSpawnSystem.SpawnItem(itemId, position)
    
    if spawnedItem then
        print("Spawned philosopher's stone at:", position)
        return true
    else
        warn("Failed to spawn philosopher's stone")
        return false
    end
end

-- Clean up sacrificed ragdolls
function RewardProcessor:CleanupSacrifices(sacrifices)
    print("Cleaning up", #sacrifices, "sacrifices")
    
    -- Get the drag server system to clean up drag references
    local DragServerSystem = require(script.Parent.DragServerSystem)
    
    for _, sacrifice in ipairs(sacrifices) do
        if sacrifice and sacrifice.Parent then
            print("Destroying sacrifice:", sacrifice.Name)
            
            -- Clean up any drag references before destroying
            if DragServerSystem and DragServerSystem.CleanupObjectDrags then
                DragServerSystem:CleanupObjectDrags(sacrifice)
            end
            
            sacrifice:Destroy()
        end
    end
end

return RewardProcessor 