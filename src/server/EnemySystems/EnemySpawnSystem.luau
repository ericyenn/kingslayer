-- src/server/systems/EnemySpawnSystem.lua
--[[
	This system queries for entities with Spawner components
	and spawns enemies based on the rules defined in the Spawner.
	Only spawns when players are within activation range.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Import custom ECS modules
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
    error("EnemySpawnSystem: Could not find EnemyComponents ModuleScript")
end

local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)

local EnemySpawnSystem = {}
EnemySpawnSystem.name = "EnemySpawnSystem"

-- Configuration
local CONFIG = {
	UPDATE_INTERVAL = 3.0, -- Check spawns every 3 seconds - much less frequent
	MAX_SPAWNS_PER_FRAME = 2 -- Reduce concurrent spawns for performance
}

-- System state
local lastUpdate = 0

-- Initialize system
function EnemySpawnSystem.initialize()
	lastUpdate = 0
	return true
end

-- Check if any player is within activation range of the spawner
local function isAnyPlayerNearSpawner(spawnerPosition, activationRange)
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local playerPosition = player.Character.HumanoidRootPart.Position
			local distance = (playerPosition - spawnerPosition).Magnitude
			if distance <= activationRange then
				return true
			end
		end
	end
	return false
end

local function getRandomPositionInRadius(center, radius)
	local angle = math.random() * 2 * math.pi
	local dist = math.random() * radius
	return center + Vector3.new(dist * math.cos(angle), 0, dist * math.sin(angle))
end

function EnemySpawnSystem.update(deltaTime)
	local currentTime = tick()
	if currentTime - lastUpdate < CONFIG.UPDATE_INTERVAL then
		return
	end
	lastUpdate = currentTime
	
	local spawnsProcessed = 0
	
	-- Get all entities with Spawner components
	local spawnerEntities = EntityManager.getEntitiesWith("Spawner")
	
	-- Debug: Print spawner count every 10 seconds
	if currentTime % 10 < 3.1 then -- Will print roughly every 10 seconds due to UPDATE_INTERVAL
		print("🎯 EnemySpawnSystem: Found", #spawnerEntities, "spawners")
	end
	
	for _, entityId in ipairs(spawnerEntities) do
		if spawnsProcessed >= CONFIG.MAX_SPAWNS_PER_FRAME then
			break
		end
		
		local spawner = EntityManager.getComponent(entityId, "Spawner")
		
		if not spawner or not spawner.centerPosition then
			-- Skip this entity - no spawner or missing center position
		else
			-- CHECK: Only proceed if a player is within activation range
			local activationRange = spawner.activationRange or 60 -- Default 60 studs
			local anyPlayerNearby = isAnyPlayerNearSpawner(spawner.centerPosition, activationRange)
			
			if not anyPlayerNearby then
				-- Skip this spawner - no players nearby
			elseif spawner.spawnType == "once" and spawner.hasSpawned then
				-- Skip this spawner - one-time spawner has already activated
			elseif spawner.spawnType == "continuous" and os.clock() - spawner.lastSpawnTime < spawner.cooldown then
				-- Skip this spawner - continuous spawner still in cooldown
			else

		-- Clear out any dead entities from the spawner's list
		for i = #spawner.spawnedEntities, 1, -1 do
			local spawnedEntityId = spawner.spawnedEntities[i]
			-- Check if entity still exists (check for Model component)
			local model = EntityManager.getComponent(spawnedEntityId, "Model")
			if not model or not model.model or not model.model.Parent then
				table.remove(spawner.spawnedEntities, i)
			end
		end

		local enemiesToSpawn = math.random(spawner.countRange.min, spawner.countRange.max)
		local spawnedCount = 0

		if #spawner.spawnedEntities >= spawner.countRange.max then
			-- Skip this entity - already at max spawns
		else

		for i = 1, enemiesToSpawn do
			if #spawner.spawnedEntities >= spawner.countRange.max then
				break
			end

			local enemyId
			if #spawner.enemies == 1 and spawner.enemies[1] == "random" then
				-- Use EnemyDefinitions to get a random enemy
				enemyId = EnemyDefinitions:GetRandomEnemy()
			elseif #spawner.enemies == 1 and spawner.enemies[1]:find("_type_") then
				-- Handle type-based spawning (e.g., "melee_type_random")
				local enemyType = spawner.enemies[1]:match("(%w+)_type_")
				if enemyType then
					enemyId = EnemyDefinitions:GetRandomEnemyOfType(enemyType)
				end
			else
				-- Use specific enemy from spawner list
				local spawnChoice = spawner.enemies[math.random(#spawner.enemies)]
				-- Validate that the enemy exists in definitions
				if EnemyDefinitions:GetEnemy(spawnChoice) then
					enemyId = spawnChoice
				else
					-- Fallback to random if enemy doesn't exist
					warn("Enemy not found in definitions: " .. tostring(spawnChoice) .. ". Using random enemy.")
					enemyId = EnemyDefinitions:GetRandomEnemy()
				end
			end

			if enemyId then
				local spawnPosition = getRandomPositionInRadius(spawner.centerPosition, spawner.radius)
				
				-- Create enemy using EnemyDefinitions
				local enemyComponents = EnemyDefinitions:CreateEnemyComponents(enemyId)
				if enemyComponents then
					-- Create new entity
					local newEnemyId = EntityManager.createEntity()
					
					-- Add temporary spawn position component (ModelCreationSystem will use and remove this)
					EntityManager.addComponent(newEnemyId, "SpawnPosition", 
						{value = spawnPosition})
					
					-- Set homePosition to spawner center for patrol boundaries
					if enemyComponents.EnemyAI then
						enemyComponents.EnemyAI.homePosition = spawner.centerPosition
					end
					
					-- Add EnemyChat component for enemy chat functionality
					enemyComponents.EnemyChat = Components.create("EnemyChat")
					
					-- Add all enemy components
					print("🔧 Adding components for entity", newEnemyId, ":")
					for componentType, componentData in pairs(enemyComponents) do
						EntityManager.addComponent(newEnemyId, componentType, componentData)
						print("   ✅ Added component:", componentType)
					end
					
					table.insert(spawner.spawnedEntities, newEnemyId)
					spawnedCount = spawnedCount + 1
					
					print(string.format("🎯 Spawned %s (%s) at %s (spawner type: %s)", 
						enemyId, 
						enemyComponents.enemyType or "unknown",
						tostring(spawnPosition),
						spawner.spawnType or "unknown"))
					
					-- Debug: Print enemy stats for verification
					local enemyDef = EnemyDefinitions:GetEnemy(enemyId)
					if enemyDef and enemyDef.customConfig then
						local cfg = enemyDef.customConfig
						print(string.format("   📊 Stats: Speed=%d, Damage=%d, AttackSpeed=%.1f, DetectRange=%d", 
							cfg.moveSpeed or 16,
							cfg.damage or 10,
							cfg.attackSpeed or 1,
							cfg.detectionRange or 30))
					end
				else
					warn("Failed to create components for enemy: " .. tostring(enemyId))
				end
			end
		end

		if spawnedCount > 0 then
			-- Update spawner state based on type
			if spawner.spawnType == "once" then
				-- Mark one-time spawner as having spawned
				spawner.hasSpawned = true
				print("🎯 One-time spawner", entityId, "has completed spawning and is now inactive")
			elseif spawner.spawnType == "continuous" then
				-- Update continuous spawner's last spawn time
				spawner.lastSpawnTime = os.clock()
			end
			
			EntityManager.addComponent(entityId, "Spawner", spawner)
			spawnsProcessed = spawnsProcessed + 1
		end
		end -- Close the else block for max spawns check
		end -- Close the else block for cooldown/proximity check
		end -- Close the else block for spawner validation
	end
end

return EnemySpawnSystem 