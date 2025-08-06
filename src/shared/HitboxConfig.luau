-- HitboxConfig.luau
-- Configuration for the hitbox system

local HitboxConfig = {
    -- Detection method
    method = "GetPartsInPart", -- Using GetPartsInPart for detection
    
    -- Default settings
    default = {
        size = Vector3.new(3, 2, 1),
        distance = 2,
        swingDuration = 0.3,
        cooldown = 0.5,
        debugVisible = false,
        ignoreFloor = true
    },
    
    -- Per-item settings
    itemSettings = {
        sword = {
            size = Vector3.new(4, 2, 1),
            distance = 2.5,
            swingDuration = 0.4
        },
        axe = {
            size = Vector3.new(5, 3, 2),
            distance = 3,
            swingDuration = 0.5
        },
        dagger = {
            size = Vector3.new(2, 1.5, 0.5),
            distance = 1.5,
            swingDuration = 0.2
        }
    },
    
    -- Enemy settings (melee enemies now use raycasts instead of hitboxes)
    enemySettings = {
        boss = {
            size = Vector3.new(3, 3, 3),
            distance = 2.0,
            swingDuration = 0.5
        }
    }
}

return HitboxConfig 