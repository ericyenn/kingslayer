-- RewardConfig.luau
-- Configuration for altar reward system

local RewardConfig = {}

-- Reward configuration for summoner item
RewardConfig.SUMMONER_REWARD = {
    itemId = "summoner",
    spawnPosition = "altar_center", -- or "random_near_altar"
    spawnOffset = Vector3.new(0, 2, 0) -- Offset above altar
}

-- Reward configuration for philosopher's stone
RewardConfig.PHILOSOPHERS_STONE_REWARD = {
    itemId = "philosophers_stone",
    spawnPosition = "altar_center", -- or "random_near_altar"
    spawnOffset = Vector3.new(0, 2, 0) -- Offset above altar
}

-- Spawn position types
RewardConfig.SPAWN_POSITIONS = {
    altar_center = function(altar)
        return altar.Position + Vector3.new(0, 2, 0)
    end,
    random_near_altar = function(altar)
        local radius = 5
        local angle = math.random() * 2 * math.pi
        local distance = math.random() * radius
        return altar.Position + Vector3.new(
            math.cos(angle) * distance,
            2,
            math.sin(angle) * distance
        )
    end
}

return RewardConfig 