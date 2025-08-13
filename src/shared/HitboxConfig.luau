-- HitboxConfig.luau
-- Configuration for the hitbox system

local HitboxConfig = {
    -- Detection method
    method = "GetPartBoundsInBox", -- Using GetPartBoundsInBox for detection
    
    -- Default settings
    default = {
        size = Vector3.new(4, 6, 1), -- Width: 4 studs (player width), Height: 6 studs (player height), Depth: 1 stud (will be replaced by hitboxLength)
        distance = 2,
        swingDuration = 0.3,
        cooldown = 0.5,
        debugVisible = false,
        ignoreFloor = true
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