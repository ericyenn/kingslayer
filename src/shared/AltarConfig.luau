-- AltarConfig.luau
-- Configuration for healing altar system

local AltarConfig = {}

-- Main altar configuration
AltarConfig.SETTINGS = {
    requiredSacrifices = 5, -- Changed from 3 to 5 enemy ragdolls
    requiredPlayerSacrifices = 1, -- Only need 1 player sacrifice
    cooldownTime = 30, -- seconds
    rewardItem = "revive_plush", -- Changed from summoner to revive_plush
    requirePrayer = true, -- Must pray to figure before reward triggers
    successChance = 0.75 -- 75% chance of getting reward
}

-- Sacrifice requirements (simplified - any enemy with "Sacrifice" tag is valid)
AltarConfig.SACRIFICE_REQUIREMENTS = {
    -- No specific enemy type requirements
    -- Any ragdoll with "Sacrifice" tag counts
    -- Player ragdolls with "PlayerSacrifice" tag also count (1 player = philosopher's stone)
}

-- Reward configuration
AltarConfig.REWARD_CONFIG = {
    itemId = "revive_plush", -- Changed from summoner to revive_plush
    spawnPosition = "altar_center" -- or "random_near_altar"
}

-- Prayer configuration
AltarConfig.PRAYER_CONFIG = {
    interactionDistance = 10, -- Distance to interact with prayer figure
    prayerDuration = 2, -- Seconds to hold E to complete prayer
    prayerKey = "E" -- Key to press for prayer
}

return AltarConfig 