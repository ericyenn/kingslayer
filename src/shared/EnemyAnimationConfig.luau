-- EnemyAnimationConfig.luau
-- Configuration for enemy animations
-- Contains animation IDs for different enemy states

local EnemyAnimationConfig = {}

-- Animation IDs for different enemy states
EnemyAnimationConfig.ANIMATIONS = {
    idle = {
        {
            id = "rbxassetid://136904906232786", -- Original idle animation
            duration = {2.0, 4.0}, -- 2-4 seconds
            weight = 40 -- 25% chance of being selected
        },
        {
            id = "rbxassetid://94818744810007", -- Yawn animation
            duration = {3.0, 4.7}, -- 3-5 seconds
            weight = 5 -- 20% chance of being selected
        },
        {
            id = "rbxassetid://131783126711981", -- Idle scanning animation
            duration = {4.0, 6.0}, -- 4-6 seconds
            weight = 40 -- 30% chance of being selected
        },
        {
            id = "rbxassetid://105314525985893", -- Head scratch animation
            duration = {2.5, 4.2}, -- 2.5-4.5 seconds
            weight = 10 -- 25% chance of being selected
        },
        {
            id = "rbxassetid://70466819492998", -- New idle animation
            duration = {2.5, 4.0}, -- 2.5-4 seconds
            weight = 10 -- 20% chance of being selected
        }
    },
    walk = "rbxassetid://121278793466470", -- Walk animation
    talk = "rbxassetid://110570302053526" -- Talk animation
}

-- Animation settings
EnemyAnimationConfig.SETTINGS = {
    -- Minimum movement speed to trigger walk animation
    WALK_THRESHOLD = 0.5,
    
    -- Animation transition settings
    TRANSITION_TIME = 0.1,
    
    -- Attack detection settings
    ATTACK_DETECTION_RANGE = 5, -- studs
    ATTACK_COOLDOWN = 1.5, -- seconds
    
    -- Performance settings
    MAX_ANIMATED_ENEMIES = 50, -- Maximum enemies to animate at once
    CLEANUP_INTERVAL = 5 -- Seconds between cleanup checks
}

-- Idle-specific settings
EnemyAnimationConfig.IDLE_SETTINGS = {
    PREVENT_REPEAT = true, -- Prevent same animation from playing twice in a row
    MIN_TRANSITION_DELAY = 0.1 -- Minimum delay between idle animations
}

return EnemyAnimationConfig 