-- SpawnerSetup.luau
-- Bridge system that converts Studio-placed tagged parts into ECS spawner entities
-- Handles the migration from manual spawner creation to visual Studio-based placement

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

-- Import ECS modules
local EntityManager = require(ReplicatedStorage.Shared.EntityManager)

-- Import Components from our custom ECS (find ModuleScript specifically to avoid folder conflict)
local Components = nil
for _, child in ipairs(ReplicatedStorage.Shared:GetChildren()) do
    if child.Name == "EnemyComponents" and child.ClassName == "ModuleScript" then
        Components = require(child)
        break
    end
end

if not Components then
    error("SpawnerSetup: Could not find EnemyComponents ModuleScript")
end

local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)

local SpawnerSetup = {}

-- Configuration
local SPAWNER_TAG = "EnemySpawner"

-- Default values for missing attributes
local DEFAULT_VALUES = {
    SpawnerEnemies = "random",
    SpawnerCountMin = 1,
    SpawnerCountMax = 3,
    SpawnerRadius = 25,
    SpawnerCooldown = 15,
    SpawnerActivationRange = 60,
    SpawnerType = "once"  -- Default to one-time spawning
}

-- Parse enemy string into array format
-- Input: "goblin_warrior,skeleton_archer" or "random" or "melee_type_random"
-- Output: {"goblin_warrior", "skeleton_archer"} or {"random"} or {"melee_type_random"}
local function parseEnemyString(enemyString)
    if not enemyString or enemyString == "" then
        return {"random"}
    end
    
    -- Handle single entries (no commas)
    if not string.find(enemyString, ",") then
        return {enemyString}
    end
    
    -- Handle comma-separated list
    local enemies = {}
    for enemy in string.gmatch(enemyString, "([^,]+)") do
        -- Trim whitespace
        enemy = string.match(enemy, "^%s*(.-)%s*$")
        if enemy and enemy ~= "" then
            table.insert(enemies, enemy)
        end
    end
    
    return #enemies > 0 and enemies or {"random"}
end

-- Read and validate attributes from a part
local function readPartAttributes(part)
    local config = {}
    
    -- Read all attributes with defaults
    for attributeName, defaultValue in pairs(DEFAULT_VALUES) do
        local value = part:GetAttribute(attributeName)
        if value ~= nil then
            -- Type validation for numeric attributes
            if type(defaultValue) == "number" and type(value) ~= "number" then
                warn(string.format("⚠️ Part '%s' attribute '%s' should be number but got %s, using default: %s", 
                    part.Name, attributeName, type(value), tostring(defaultValue)))
                config[attributeName] = defaultValue
            elseif type(defaultValue) == "string" and type(value) ~= "string" then
                warn(string.format("⚠️ Part '%s' attribute '%s' should be string but got %s, using default: %s", 
                    part.Name, attributeName, type(value), tostring(defaultValue)))
                config[attributeName] = defaultValue
            else
                config[attributeName] = value
            end
        else
            config[attributeName] = defaultValue
            warn(string.format("⚠️ Part '%s' missing attribute '%s', using default: %s", 
                part.Name, attributeName, tostring(defaultValue)))
        end
    end
    
    return config
end

-- Validate enemy types against EnemyDefinitions
local function validateEnemyTypes(enemies)
    local validEnemies = {}
    
    for _, enemy in ipairs(enemies) do
        if enemy == "random" or 
           enemy:match("^%w+_type_random$") or 
           EnemyDefinitions:GetEnemy(enemy) then
            table.insert(validEnemies, enemy)
        else
            warn(string.format("⚠️ Unknown enemy type '%s', will fallback to random", enemy))
            table.insert(validEnemies, "random")
        end
    end
    
    return #validEnemies > 0 and validEnemies or {"random"}
end

-- Convert a single tagged part into a spawner entity
local function convertPartToSpawner(part)
    -- Read attributes from the part
    local config = readPartAttributes(part)
    
    -- Parse enemy string into array
    local enemies = parseEnemyString(config.SpawnerEnemies)
    enemies = validateEnemyTypes(enemies)
    
    -- Validate spawn type
    local spawnType = config.SpawnerType
    if spawnType ~= "once" and spawnType ~= "continuous" then
        warn(string.format("⚠️ Invalid SpawnerType '%s' for part '%s', using default 'once'", 
            tostring(spawnType), part.Name))
        spawnType = "once"
    end
    
    -- Create spawner entity
    local spawnerId = EntityManager.createEntity()
    
    -- Create Spawner component with part data
    local spawnerComponent = Components.create("Spawner", {
        enemies = enemies,
        countRange = {
            min = math.max(1, config.SpawnerCountMin),
            max = math.max(config.SpawnerCountMin, config.SpawnerCountMax)
        },
        radius = math.max(1, config.SpawnerRadius),
        cooldown = math.max(1, config.SpawnerCooldown),
        lastSpawnTime = 0,
        spawnedEntities = {},
        centerPosition = part.Position,
        activationRange = math.max(10, config.SpawnerActivationRange),
        spawnType = spawnType,
        hasSpawned = false
    })
    
    -- Add component to entity
    EntityManager.addComponent(spawnerId, "Spawner", spawnerComponent)
    
    -- Log successful conversion
    print(string.format("✅ Converted part '%s' to spawner entity %d", part.Name, spawnerId))
    print(string.format("   Position: %s", tostring(part.Position)))
    print(string.format("   Enemies: %s", table.concat(enemies, ", ")))
    print(string.format("   Count: %d-%d, Radius: %d, Cooldown: %ds, Type: %s", 
        spawnerComponent.countRange.min, 
        spawnerComponent.countRange.max,
        spawnerComponent.radius,
        spawnerComponent.cooldown,
        spawnerComponent.spawnType))
    
    return spawnerId
end

-- Scan workspace for all tagged spawner parts
function SpawnerSetup.scanForSpawnerParts()
    local taggedParts = CollectionService:GetTagged(SPAWNER_TAG)
    
    print(string.format("🔍 SpawnerSetup: Found %d parts with tag '%s'", #taggedParts, SPAWNER_TAG))
    
    for i, part in ipairs(taggedParts) do
        print(string.format("   %d. %s at %s", i, part.Name, tostring(part.Position)))
    end
    
    return taggedParts
end

-- Convert all tagged parts to spawner entities
function SpawnerSetup.convertAllTaggedParts()
    local taggedParts = SpawnerSetup.scanForSpawnerParts()
    local spawnerEntities = {}
    
    for _, part in ipairs(taggedParts) do
        local success, result = pcall(function()
            return convertPartToSpawner(part)
        end)
        
        if success then
            table.insert(spawnerEntities, result)
        else
            warn(string.format("❌ Failed to convert part '%s': %s", part.Name, tostring(result)))
        end
    end
    
    print(string.format("✅ Successfully converted %d/%d tagged parts to spawner entities", 
        #spawnerEntities, #taggedParts))
    
    return spawnerEntities
end

-- Create fallback spawners if no tagged parts found (backwards compatibility)
function SpawnerSetup.createFallbackSpawners()
    print("🔄 No tagged parts found, creating fallback spawners...")
    
    local fallbackConfigs = {
        {pos = Vector3.new(0, 0, 100), enemies = {"random"}, radius = 25},
        {pos = Vector3.new(100, 0, 0), enemies = {"random"}, radius = 25},
        {pos = Vector3.new(-100, 0, 0), enemies = {"random"}, radius = 25},
        {pos = Vector3.new(0, 0, -100), enemies = {"random"}, radius = 25}
    }
    
    local spawnerEntities = {}
    
    for i, config in ipairs(fallbackConfigs) do
        local spawnerId = EntityManager.createEntity()
        
        EntityManager.addComponent(spawnerId, "Spawner", Components.create("Spawner", {
            enemies = config.enemies,
            countRange = {min = 2, max = 4},
            radius = config.radius,
            cooldown = 10,
            lastSpawnTime = 0,
            spawnedEntities = {},
            centerPosition = config.pos,
            activationRange = 60,
            spawnType = "continuous",  -- Fallback spawners use continuous for backwards compatibility
            hasSpawned = false
        }))
        
        table.insert(spawnerEntities, spawnerId)
        print(string.format("✅ Created fallback spawner %d at %s", i, tostring(config.pos)))
    end
    
    return spawnerEntities
end

-- Main initialization function
function SpawnerSetup.initializeAllSpawners()
    print("🎯 SpawnerSetup: Initializing spawner system...")
    
    -- Wait a moment for workspace to be fully loaded
    if RunService:IsStudio() then
        wait(0.1) -- Small delay in Studio for parts to load
    end
    
    -- Try to convert tagged parts first
    local spawnerEntities = SpawnerSetup.convertAllTaggedParts()
    
    -- If no tagged parts found, create fallback spawners
    if #spawnerEntities == 0 then
        spawnerEntities = SpawnerSetup.createFallbackSpawners()
    end
    
    print(string.format("🎯 SpawnerSetup: Initialization complete with %d spawners", #spawnerEntities))
    
    return spawnerEntities
end

-- Debug function to list all current spawner entities
function SpawnerSetup.debugListSpawners()
    local spawnerEntities = EntityManager.getEntitiesWith("Spawner")
    
    print(string.format("🔍 Debug: Found %d spawner entities:", #spawnerEntities))
    
    for i, entityId in ipairs(spawnerEntities) do
        local spawner = EntityManager.getComponent(entityId, "Spawner")
        if spawner then
            print(string.format("   %d. Entity %d at %s", 
                i, entityId, tostring(spawner.centerPosition)))
            print(string.format("      Enemies: %s", table.concat(spawner.enemies, ", ")))
        end
    end
end

return SpawnerSetup 