-- SpawnRules.lua
-- Simple generic spawn configuration system for StayAlive survival game
-- Defines basic enemy spawning rules without biome dependencies

local SpawnRules = {}

-- ================================
-- SPAWN RULE TYPES AND CONSTANTS
-- ================================

-- Entity types that can spawn
local ENTITY_TYPES = {
	ENEMY = "enemy",
	STRUCTURE = "structure"
}

-- Spawn condition types
local SPAWN_CONDITIONS = {
	ALWAYS = "always",
	TIMED = "timed",
	PROXIMITY = "proximity"
}

-- ================================
-- BASIC SPAWN CONFIGURATIONS
-- ================================

-- Simple spawn rules for generic areas
local BASIC_SPAWN_DATA = {
	enemies = {
		{
			entityId = "Wolf",
			countRange = {min = 2, max = 4},
			minDistance = 25,
			spawnCondition = SPAWN_CONDITIONS.ALWAYS,
			difficulty = 3,
			hostile = true,
			spawnWeight = 1.0
		},
		{
			entityId = "Bear",
			countRange = {min = 1, max = 2},
			minDistance = 50,
			spawnCondition = SPAWN_CONDITIONS.ALWAYS,
			difficulty = 5,
			hostile = true,
			spawnWeight = 0.5
		},
		{
			entityId = "Scorpion",
			countRange = {min = 3, max = 6},
			minDistance = 20,
			spawnCondition = SPAWN_CONDITIONS.ALWAYS,
			difficulty = 2,
			hostile = true,
			spawnWeight = 0.8
		}
	},
	structures = {
		{
			entityId = "GenericSpawner",
			countRange = {min = 1, max = 3},
			minDistance = 100,
			spawnCondition = SPAWN_CONDITIONS.ALWAYS,
			structureType = "spawner"
		}
	}
}

-- ================================
-- PUBLIC API FUNCTIONS
-- ================================

-- Get all available entity types
function SpawnRules.getEntityTypes()
	return ENTITY_TYPES
end

-- Get spawn conditions
function SpawnRules.getSpawnConditions()
	return SPAWN_CONDITIONS
end

-- Get basic spawn rules for enemies
function SpawnRules.getEnemySpawnRules()
	return BASIC_SPAWN_DATA.enemies
end

-- Get basic spawn rules for structures
function SpawnRules.getStructureSpawnRules()
	return BASIC_SPAWN_DATA.structures
end

-- Get all spawn rules
function SpawnRules.getAllSpawnRules()
	return BASIC_SPAWN_DATA
end

-- Get a random enemy type based on spawn weights
function SpawnRules.getRandomEnemyType()
	local enemies = BASIC_SPAWN_DATA.enemies
	local totalWeight = 0
	
	-- Calculate total weight
	for _, enemy in ipairs(enemies) do
		totalWeight = totalWeight + (enemy.spawnWeight or 1.0)
	end
	
	-- Pick random enemy based on weight
	local randomValue = math.random() * totalWeight
	local currentWeight = 0
	
	for _, enemy in ipairs(enemies) do
		currentWeight = currentWeight + (enemy.spawnWeight or 1.0)
		if randomValue <= currentWeight then
			return enemy.entityId
		end
	end
	
	-- Fallback to first enemy
	return enemies[1] and enemies[1].entityId or "Wolf"
end

-- Validate spawn rule configuration
function SpawnRules.validateSpawnRule(rule)
	if not rule then
		return false, "Rule is nil"
	end
	
	if not rule.entityId then
		return false, "Missing entityId"
	end
	
	if not rule.countRange or not rule.countRange.min or not rule.countRange.max then
		return false, "Missing or invalid countRange"
	end
	
	if rule.countRange.min > rule.countRange.max then
		return false, "countRange.min cannot be greater than countRange.max"
	end
	
	return true, "Valid"
end

-- Get spawn count for a rule
function SpawnRules.getSpawnCount(rule)
	if not rule or not rule.countRange then
		return 1
	end
	
	return math.random(rule.countRange.min, rule.countRange.max)
end

-- Check if an entity should spawn based on conditions
function SpawnRules.shouldSpawn(rule, context)
	if not rule then
		return false
	end
	
	local condition = rule.spawnCondition or SPAWN_CONDITIONS.ALWAYS
	
	if condition == SPAWN_CONDITIONS.ALWAYS then
		return true
	elseif condition == SPAWN_CONDITIONS.TIMED then
		-- Basic timed spawning logic
		local currentTime = tick()
		local lastSpawn = context.lastSpawnTime or 0
		local spawnInterval = rule.spawnInterval or 30 -- 30 seconds default
		return (currentTime - lastSpawn) >= spawnInterval
	elseif condition == SPAWN_CONDITIONS.PROXIMITY then
		-- Basic proximity spawning logic
		return context.playersNearby or false
	end
	
	return false
end

-- ================================
-- HELPER FUNCTIONS
-- ================================

-- Get minimum distance for entity placement
function SpawnRules.getMinDistance(entityId)
	-- Check enemies first
	for _, enemy in ipairs(BASIC_SPAWN_DATA.enemies) do
		if enemy.entityId == entityId then
			return enemy.minDistance or 20
		end
	end
	
	-- Check structures
	for _, structure in ipairs(BASIC_SPAWN_DATA.structures) do
		if structure.entityId == entityId then
			return structure.minDistance or 50
		end
	end
	
	return 20 -- Default minimum distance
end

-- Get difficulty for entity
function SpawnRules.getDifficulty(entityId)
	for _, enemy in ipairs(BASIC_SPAWN_DATA.enemies) do
		if enemy.entityId == entityId then
			return enemy.difficulty or 1
		end
	end
	return 1
end

-- Check if entity is hostile
function SpawnRules.isHostile(entityId)
	for _, enemy in ipairs(BASIC_SPAWN_DATA.enemies) do
		if enemy.entityId == entityId then
			return enemy.hostile or false
		end
	end
	return false
end

return SpawnRules 