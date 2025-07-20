-- EnemyDefinitions.lua
-- Enemy definitions with component configurations for different enemy types
-- Similar to ItemDefinitions but for enemies with EnemyType components

local EnemyDefinitions = {}
-- Import Components from our custom ECS (find ModuleScript specifically to avoid folder conflict)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = nil
for _, child in ipairs(ReplicatedStorage.Shared:GetChildren()) do
    if child.Name == "EnemyComponents" and child.ClassName == "ModuleScript" then
        Components = require(child)
        break
    end
end

if not Components then
    error("EnemyDefinitions: Could not find EnemyComponents ModuleScript")
end

-- Helper function for deep merging tables
local function mergeTables(t1, t2)
    local t3 = {}
    for k, v in pairs(t1) do
        t3[k] = v
    end
    for k, v in pairs(t2) do
        if type(v) == "table" and type(t3[k]) == "table" then
            t3[k] = mergeTables(t3[k], v)
        else
            t3[k] = v
        end
    end
    return t3
end

-- Enemy definitions organized by type and specific variants
EnemyDefinitions.enemies = {
    -- MELEE ENEMIES
    forest_berserker = {
        name = "Forest Berserker",
        description = "A fierce melee fighter that charges directly at enemies.",
        model = "ForestBerserkerModel",
        enemyType = "melee",
        
        -- Visual properties
        color = Color3.fromRGB(120, 80, 40), -- Brown
        size = Vector3.new(2, 4, 2),
        material = Enum.Material.Plastic,
        
        -- Custom configuration overrides
        customConfig = {
            moveSpeed = 18, -- Faster than default melee
            damage = 30,    -- Higher damage
            attackSpeed = 2.2,
            detectionRange = 35,
            -- Idle movement settings
            idleMovementEnabled = true,
            idleMovementRadius = 20,
            idleMovementInterval = 4,
            idleMovementSpeed = 10,
        },
        
        -- Loot drops
        loot = {
            { item = "sword", chance = 0.3 },
            { item = "gold_coin", chance = 0.8 },
            { item = "health_potion", chance = 0.2 }
        },
        
        -- Health and stats
        health = 80,
        experience = 15
    },
    
    desert_berserker = {
        name = "Desert Berserker",
        description = "Desert killa",
        model = "DesertBerserkerModel",
        enemyType = "melee",
        
        color = Color3.fromRGB(80, 120, 60), -- Dark green
        size = Vector3.new(3, 5, 3),
        material = Enum.Material.Concrete,
        
        customConfig = {
            moveSpeed = 14, -- Slower but tankier
            damage = 40,
            attackSpeed = 1.8,
            detectionRange = 40,
            chaseDistance = 60 -- Persistent chaser
        },
        
        loot = {
            { item = "battle_axe", chance = 0.4 },
            { item = "armor_scrap", chance = 0.6 },
            { item = "gold_coin", chance = 1.0 }
        },
        
        health = 150,
        experience = 25
    },
    
    -- RANGED ENEMIES
    forest_archer = {
        name = "Forest Archer",
        description = "Forest dude archer that keeps its distance and shoots arrows.",
        model = "ForestBerserkerModel",
        enemyType = "ranged",
        
        color = Color3.fromRGB(200, 200, 180), -- Bone white
        size = Vector3.new(2, 4, 2),
        material = Enum.Material.Marble,
        
        customConfig = {
            moveSpeed = 10, -- Slower movement
            damage = 25,
            attackSpeed = 1.2,
            attackRange = 40,
            detectionRange = 45,
            projectileSpeed = 60,
            aimAccuracy = 0.85,
            -- Idle movement settings for ranged enemies
            idleMovementEnabled = true,
            idleMovementRadius = 12,
            idleMovementInterval = 6,
            idleMovementSpeed = 6,
        },
        
        loot = {
            { item = "bow", chance = 0.5 },
            { item = "arrow", chance = 0.9 },
            { item = "bone", chance = 0.7 }
        },
        
        health = 60,
        experience = 20
    },
    
    pirate_bucaneer = {
        name = "Pirate Bucaneer",
        description = "A pirate with a powerful flintlock",
        model = "PirateBucaneerModel",
        enemyType = "ranged",
        
        color = Color3.fromRGB(100, 60, 120), -- Purple
        size = Vector3.new(1.8, 3.5, 1.8),
        material = Enum.Material.Neon,
        
        customConfig = {
            moveSpeed = 8,
            damage = 35,
            attackSpeed = 0.8, -- Slower but powerful
            attackRange = 30,
            detectionRange = 35,
            projectileSpeed = 40,
            projectileType = "magic_bolt",
            aimAccuracy = 0.9
        },
        
        loot = {
            { item = "magic_staff", chance = 0.3 },
            { item = "mana_crystal", chance = 0.6 },
            { item = "spell_scroll", chance = 0.4 }
        },
        
        health = 50,
        experience = 30
    },
    
    -- SPECIAL ENEMIES
    shadow_assassin = {
        name = "Shadow Assassin",
        description = "A mysterious enemy that can teleport and strike from shadows.",
        model = "ShadowAssassinModel",
        enemyType = "special",
        
        color = Color3.fromRGB(40, 40, 80), -- Dark blue
        size = Vector3.new(2, 4, 2),
        material = Enum.Material.ForceField,
        
        customConfig = {
            moveSpeed = 20, -- Very fast
            damage = 45,
            attackSpeed = 3.5,
            detectionRange = 50,
            specialAttacks = {"teleport", "stealth_strike"},
            manaPool = 80,
            spellCooldown = 6.0,
            teleportRange = 25,
            teleportCooldown = 10.0
        },
        
        loot = {
            { item = "shadow_blade", chance = 0.2 },
            { item = "stealth_cloak", chance = 0.1 },
            { item = "rare_gem", chance = 0.3 }
        },
        
        health = 120,
        experience = 50
    },
    
    yeti = {
        name = "Yeti",
        description = "A powerful spellcaster with area-of-effect abilities.",
        model = "YetiModel",
        enemyType = "special",
        
        color = Color3.fromRGB(255, 100, 100), -- Fiery red
        size = Vector3.new(2.5, 4.5, 2.5),
        material = Enum.Material.Neon,
        
        customConfig = {
            moveSpeed = 12,
            damage = 50,
            attackSpeed = 2.0,
            detectionRange = 45,
            specialAttacks = {"fireball", "area_damage", "magic_shield"},
            manaPool = 150,
            spellCooldown = 4.0,
            retreatThreshold = 8 -- Keeps distance
        },
        
        loot = {
            { item = "elemental_staff", chance = 0.4 },
            { item = "fire_crystal", chance = 0.7 },
            { item = "magic_tome", chance = 0.3 }
        },
        
        health = 100,
        experience = 60
    },
    
    necromancer = {
        name = "Necromancer",
        description = "A dark wizard that can summon minions and drain life.",
        model = "NecromancerModel",
        enemyType = "special",
        
        color = Color3.fromRGB(80, 40, 80), -- Dark purple
        size = Vector3.new(2.2, 4.8, 2.2),
        material = Enum.Material.Glass,
        
        customConfig = {
            moveSpeed = 10,
            damage = 35,
            attackSpeed = 1.5,
            detectionRange = 40,
            specialAttacks = {"summon_minions", "life_drain", "curse"},
            manaPool = 200,
            spellCooldown = 8.0,
            canTeleport = false -- Prefers summoning
        },
        
        loot = {
            { item = "necromancer_staff", chance = 0.3 },
            { item = "soul_gem", chance = 0.5 },
            { item = "dark_tome", chance = 0.4 }
        },
        
        health = 80,
        experience = 70
    }
}

-- ▼ put this near the top of EnemyDefinitions.lua
local DEFAULT_MODEL_BY_TYPE = {
    melee   = "Jason",
    ranged  = "R6",
    special = "Dog",
}

local DEFAULT_IDLE_ANIM = "Idle"
local DEFAULT_RUN_ANIM  = "Run"

-- Set default models and animations for all enemies
for _, enemy in pairs(EnemyDefinitions.enemies) do
    -- only fill in if you didn’t already specify one
    enemy.model = enemy.model or DEFAULT_MODEL_BY_TYPE[enemy.enemyType]

    enemy.customConfig = enemy.customConfig or {}
    enemy.customConfig.idleAnim = enemy.customConfig.idleAnim or DEFAULT_IDLE_ANIM
    enemy.customConfig.runAnim  = enemy.customConfig.runAnim  or DEFAULT_RUN_ANIM
end

-- Get enemy definition by ID
function EnemyDefinitions:GetEnemy(enemyId)
    return self.enemies[enemyId]
end

-- Get all enemy IDs
function EnemyDefinitions:GetAllEnemyIds()
    local ids = {}
    for id, _ in pairs(self.enemies) do
        table.insert(ids, id)
    end
    return ids
end

-- Get enemies by type
function EnemyDefinitions:GetEnemiesByType(enemyType)
    local enemies = {}
    for id, enemy in pairs(self.enemies) do
        if enemy.enemyType == enemyType then
            enemies[id] = enemy
        end
    end
    return enemies
end

-- Create components for an enemy
function EnemyDefinitions:CreateEnemyComponents(enemyId)
    local enemyDef = self:GetEnemy(enemyId)
    if not enemyDef then
        warn("Enemy definition not found: " .. tostring(enemyId))
        return nil
    end
    
    local cfg = enemyDef.customConfig or {}
    return {
        EnemyType = Components.create("EnemyType", {
            enemyType = enemyDef.enemyType,
            enemyId = enemyId,  -- Store the original enemy ID for model lookup
            config = cfg
        }),
        EnemyAI = Components.create("EnemyAI", {
            state = "idle",
            detectionRange = cfg.detectionRange or 30,
            attackRange = cfg.attackRange or 5,
            speed = cfg.moveSpeed or 16,
            homePosition = Vector3.new(0, 0, 0)
        }),
        Combat = Components.create("Combat", {
            damage = cfg.damage or 10,
            attackCooldown = cfg.attackSpeed and (1 / cfg.attackSpeed) or 1,
            attackRange = cfg.attackRange or 5
        }),
        CombatStats = Components.create("CombatStats", {
            baseAttack = cfg.damage or 10,
            baseDefense = 5,
            critChance = 0.1,
            critMultiplier = 1.5,
            dodgeChance = 0.05
        }),
        Health = Components.create("Health", {
            max = enemyDef.health or 100,
            current = enemyDef.health or 100
        })
        -- Note: enemyType is stored in the EnemyType component, not as a separate field
    }
end

-- Get random enemy of specific type
function EnemyDefinitions:GetRandomEnemyOfType(enemyType)
    local enemiesOfType = self:GetEnemiesByType(enemyType)
    local ids = {}
    for id, _ in pairs(enemiesOfType) do
        table.insert(ids, id)
    end
    
    if #ids > 0 then
        return ids[math.random(1, #ids)]
    end
    
    return nil
end

-- Get random enemy (any type)
function EnemyDefinitions:GetRandomEnemy()
    local allIds = self:GetAllEnemyIds()
    if #allIds > 0 then
        return allIds[math.random(1, #allIds)]
    end
    return nil
end

-- Validate enemy definition
function EnemyDefinitions:ValidateEnemyDefinition(enemyId)
    local enemy = self:GetEnemy(enemyId)
    if not enemy then
        return false, "Enemy not found: " .. tostring(enemyId)
    end
    
    -- Simple enemy type validation (no longer using Components.isValidType)
    local validTypes = {"melee", "ranged", "special"}
    local isValid = false
    for _, validType in ipairs(validTypes) do
        if enemy.enemyType == validType then
            isValid = true
            break
        end
    end
    if not isValid then
        return false, "Invalid enemy type: " .. tostring(enemy.enemyType)
    end
    
    if not enemy.health or enemy.health <= 0 then
        return false, "Enemy must have valid health"
    end
    
    return true
end

-- Debug function to print all enemies
function EnemyDefinitions:DebugPrintAllEnemies()
    print("🎭 Enemy Definitions Debug:")
    for id, enemy in pairs(self.enemies) do
        print(string.format("  %s (%s): %s", id, enemy.enemyType, enemy.name))
        print(string.format("    Health: %d, Damage: %d", 
            enemy.health, 
            enemy.customConfig and enemy.customConfig.damage or "default"))
    end
end

print("👾 EnemyDefinitions loaded with " .. #EnemyDefinitions:GetAllEnemyIds() .. " enemy types")

return EnemyDefinitions 