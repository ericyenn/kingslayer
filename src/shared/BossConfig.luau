local BossConfig = {
    -- ATTACK SEQUENCES 
    sequences = {
        default = {"orbitalStrike", "trackingShot", "rippleSquares"},
        -- Add new attack sequences here as you create new abilities
        -- Example: mixed = {"trackingShot", "newAttack", "trackingShot"}
    },
    
    -- MOVEMENT & MELEE SETTINGS
    movement = {
        speed = 16,                      -- Base movement speed (same as default player speed)
        stoppingDistance = 35,           -- How close to get to player before attacking
        selectNewPlayerAfterAttack = true,
        
        -- Melee damage settings
        meleeRange = 8,                  -- Distance for melee damage
        meleeDamage = 20,                -- Damage per melee hit
        meleeKnockback = 10,             -- Knockback force
        meleeCooldown = 1.5,             -- Seconds between melee hits on same player
    },
    
    -- INVINCIBILITY SETTINGS
    invincibility = {
        triggerAfterMoves = 3,           -- Become invincible every 3 moves
        triggerVariation = 1,            -- Random +/- 1 (so 3-4 moves)
        duration = 8,                    -- Seconds of invincibility
        visualEffect = "glow",           -- Visual indicator type
        healAmount = 100,                -- Optional: heal during invincibility
        damageReduction = 1,             -- 1 = completely invincible, 0.5 = 50% damage reduction
    },
    
    -- INDIVIDUAL ATTACK SETTINGS
    abilities = {
        trackingShot = {
            trackingDuration = 2,        -- How long to track player
            blinkCount = 3,              -- Number of beam blinks before lock-on
            blinkSpeed = 0.2,            -- Seconds between blinks
            lockOnDuration = 0.45,       -- Time needed visible during blinks to achieve lock (reduced for floating point safety)
            requiresLineOfSight = false, -- Must see target during blinks to lock on (TEMP: disabled for testing)
            cooldownAfter = 2,           -- Seconds before next action
            
            -- Missile physics settings
            missileSpeed = 12,           -- Slightly slower than player (16)
            missileTurnRate = 3,         -- Radians per second turning speed (more realistic)
            missileLifetime = 10,        -- Max flight time before self-destruct
            missileSize = Vector3.new(1, 1, 3), -- Missile dimensions
            
            -- Damage settings
            damage = 50,                 -- Explosion damage
            explosionRadius = 8,         -- Explosion damage radius
            explosionVisualSize = 12,    -- Visual explosion size
            explosionDuration = 2,       -- How long explosion lasts
            
            -- Network settings
            updateRate = 30,             -- Server updates per second (increased for smoother movement)
            predictionTime = 0.1,        -- Client prediction window (reduced)
            
            -- Laser visual settings (lock-on phase)
            laserColor = Color3.new(1, 0, 0),  -- Red laser (tracking)
            lockOnColor = Color3.new(1, 0.5, 0), -- Orange laser (locked on)
            laserWidth = 0.5,            -- Beam width
            laserTransparency = 0.2,     -- Normal transparency
            blinkTransparency = {0.05, 0.8}, -- Blink on/off transparency
            particleRate = 50,           -- Particle emission rate
            
            -- Missile visual settings
            missileColor = Color3.new(0.8, 0.2, 0), -- Dark red missile
            trailColor = Color3.new(1, 0.4, 0),     -- Orange trail
            trailLength = 20,            -- Trail particle count
        },
        
        orbitalStrike = {
            circleCount = 15,            -- Number of strike circles (increased to 15)
            circleInterval = 0.75,       -- Time between each circle appearing (faster for overlapping strikes)
            strikeDelay = 0.5,           -- Time from circle appearance to strike (NEW: replaces finalWarningDuration)
            damage = 75,                 -- Strike damage
            damageRadius = 10,           -- Damage radius for each circle (increased from 6)
            visualRadius = 12,           -- Visual circle/beam radius (increased from 8)
            beamDuration = 0.5,          -- How long beams last (reduced from 1.0 to 0.5 seconds)
            cooldownAfter = 2,           -- Seconds before next action
            
            -- Strike area settings (expanded radius)
            minDistance = 15,            -- Minimum distance from boss (increased)
            maxDistance = 60,            -- Maximum distance from boss (doubled)
            
            -- Visual settings
            circleColor = Color3.new(1, 0, 0),  -- Red warning circles
            beamColor = Color3.new(1, 0.2, 0),  -- Orange-red beams
        },
        
        rippleSquares = {
            -- Square outline expansion settings
            initialSize = Vector3.new(6, 0.5, 6),      -- Starting size at boss position
            maxSize = Vector3.new(80, 0.5, 80),        -- Maximum expansion size
            expansionDuration = 6,                      -- Time to expand from min to max (slower)
            outlineThickness = 2,                       -- How thick the square outline parts are
            
            -- Ripple timing (more spacing between squares)
            rippleInterval = 3.0,                       -- New square every 3 seconds (increased spacing)
            maxActiveSquares = 4,                       -- Max squares expanding at once
            
            -- Visual settings (client-side styling)
            visualColor = Color3.new(1, 0, 0),         -- Red outline
            visualMaterial = Enum.Material.Neon,       -- Glowing effect
            visualTransparency = 0.2,                  -- Slightly transparent
            
            -- Gameplay settings
            damage = 30,                                -- Damage when touched
            cooldownAfter = 2,                          -- Cooldown after ability
        },
        
        -- Add new abilities here as you create them
        -- Example:
        -- newAttack = {
        --     damage = 30,
        --     cooldownAfter = 1.5,
        --     -- ... other settings
        -- }
    },
    
    -- BOSS STATS
    boss = {
        health = 1000,                   -- Total boss health
        maxHealth = 1000,                -- For health bar calculations
        walkSpeed = 16,                  -- Movement speed (matches player)
        size = Vector3.new(4, 8, 4),     -- Boss size
        spawnPosition = Vector3.new(0, 5, 0), -- Where boss spawns
        model = "rbxasset://models/BossModel", -- Boss model asset (placeholder)
    },
    
    -- TIMING SETTINGS
    timing = {
        globalCooldown = 8,              -- Base cooldown between any actions (further increased for more spacing)
        attackStartDelay = 1,            -- Delay before starting attacks
        sequenceRestartDelay = 3,        -- Delay before restarting sequence
        vulnerabilityDuration = 5,       -- Seconds boss is vulnerable after each attack
        gracePeriod = 10,                -- Seconds after landing where boss can't attack or be damaged
    },
    
    -- TEMPLATE SETTINGS
    templates = {
        bossName = "BossTemplate",       -- Name of boss template in ServerStorage
        enemyName = "EnemyTemplate",     -- Name of enemy template in ServerStorage
        validateOnStart = true,          -- Check templates exist on server start
    }
}

return BossConfig 