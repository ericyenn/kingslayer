-- Components.lua
-- Component templates and default values
-- Single responsibility: Define what data each component type holds

local Components = {}

-- Health and combat
Components.Health = {
    max = 100,
    current = 100
}

Components.Combat = {
    target = nil,           -- Entity ID being attacked
    damage = 10,           -- Damage per attack
    lastAttackTime = 0,    -- When last attack occurred
    attackCooldown = 1,    -- Time between attacks
    attackRange = 5        -- Attack range in studs
}

Components.CombatStats = {
    baseAttack = 10,
    baseDefense = 0,
    critChance = 0.1,       -- 0.0 to 1.0
    critMultiplier = 1.5,
    dodgeChance = 0.05
}

-- Enemy AI and behavior
Components.EnemyType = {
    enemyType = "melee",    -- "melee", "ranged", "special"
    enemyId = "",           -- Original enemy ID from EnemyDefinitions (e.g., "goblin_warrior")
    config = {}             -- Custom configuration data
}

Components.EnemyAI = {
    state = "idle",         -- "idle", "patrol", "chase", "attack", "dead"
    stateStartTime = 0,
    detectionRange = 30,
    attackRange = 5,
    speed = 16,
    homePosition = Vector3.new(0, 0, 0),
    lastUpdateTime = 0,     -- For state-based update frequency
    lastMoveToTime = 0      -- For stuck detection
}

-- Spawning
Components.Spawner = {
    enemies = {},           -- List of enemy types to spawn
    countRange = {min = 1, max = 1},
    radius = 25,            -- Default spawn radius in studs (smaller for closer spawning)
    cooldown = 10,
    lastSpawnTime = 0,
    spawnedEntities = {},   -- Track spawned entities
    centerPosition = Vector3.new(0, 0, 0),  -- Center position for spawning
    activationRange = 60    -- Only spawn when player within this range
}

-- Visual representation (this IS needed - links entities to Roblox models)
Components.Model = {
    model = nil,            -- Roblox Model instance
    part = nil,             -- Primary part reference
    humanoid = nil          -- Humanoid reference
}

-- Animation management for entities
Components.AnimationSet = {
    idle = nil,      -- AnimationTrack for idle animation
    walk = nil,      -- AnimationTrack for walk animation  
    attack = nil,    -- AnimationTrack for attack animation
    current = nil,   -- Currently playing AnimationTrack
}

-- Helper function to create a component with custom data
function Components.create(componentType, customData)
    local template = Components[componentType]
    if not template then
        warn("❌ Unknown component type:", componentType)
        return nil
    end
    
    -- Create a copy of the template
    local component = {}
    for key, value in pairs(template) do
        component[key] = value
    end
    
    -- Override with custom data
    if customData then
        for key, value in pairs(customData) do
            component[key] = value
        end
    end
    
    return component
end

-- Debug function to list all component types
function Components.debugPrint()
    print("🔍 Available Component Types:")
    for componentType, template in pairs(Components) do
        if type(template) == "table" and componentType ~= "create" and componentType ~= "debugPrint" then
            print("  ", componentType, ":", template)
        end
    end
end

return Components 