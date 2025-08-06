-- src/server/systems/EnemySpawnSystem.lua
--[[
	This system creates enemy folders with detection parts
	and spawns enemies based on the rules defined in the Spawner.
	Event-driven spawning - no more 3-second loops.
	Each enemy has its own movement restriction zone.
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

-- Initialize system
function EnemySpawnSystem.initialize()
	-- Create Enemies folder if it doesn't exist
	if not workspace:FindFirstChild("Enemies") then
		local enemiesFolder = Instance.new("Folder")
		enemiesFolder.Name = "Enemies"
		enemiesFolder.Parent = workspace
	end
	
	-- Initialize global movement zones table
	_G.enemyMovementZones = _G.enemyMovementZones or {}
	
	return true
end

local function getRandomPositionInRadius(center, radius)
	local angle = math.random() * 2 * math.pi
	local dist = math.random() * radius
	local basePosition = center + Vector3.new(dist * math.cos(angle), 0, dist * math.sin(angle))
	
	-- Raycast to find ground height
	local raycastResult = workspace:Raycast(
		Vector3.new(basePosition.X, 1000, basePosition.Z), -- Start high up
		Vector3.new(0, -2000, 0), -- Raycast down
		RaycastParams.new()
	)
	
	if raycastResult then
		-- Spawn 3 units above ground
		return Vector3.new(basePosition.X, raycastResult.Position.Y + 3, basePosition.Z)
	else
		-- Fallback to base position if raycast fails
		return basePosition
	end
end

-- Spawn all enemies from all spawners (call this once at game start)
function EnemySpawnSystem.spawnAllEnemies()
	print("🎯 EnemySpawnSystem: Starting one-time enemy spawn...")
	
	-- Get all entities with Spawner components
	local spawnerEntities = EntityManager.getEntitiesWith("Spawner")
	print("🎯 EnemySpawnSystem: Found", #spawnerEntities, "spawners")
	
	local totalSpawned = 0
	
	for _, entityId in ipairs(spawnerEntities) do
		local spawner = EntityManager.getComponent(entityId, "Spawner")
		
		if not spawner or not spawner.centerPosition then
			warn("Spawner", entityId, "missing centerPosition")
			continue
		end
		
		-- Clear out any dead entities from the spawner's list
		for i = #spawner.spawnedEntities, 1, -1 do
			local spawnedEntityId = spawner.spawnedEntities[i]
			local enemyAI = EntityManager.getComponent(spawnedEntityId, "EnemyAI")
			if not enemyAI then
				table.remove(spawner.spawnedEntities, i)
			end
		end

		local enemiesToSpawn = math.random(spawner.countRange.min, spawner.countRange.max)
		local spawnedCount = 0

		if #spawner.spawnedEntities >= spawner.countRange.max then
			print("🎯 Spawner", entityId, "already at max spawns")
			continue
		end

		for i = 1, enemiesToSpawn do
			if #spawner.spawnedEntities >= spawner.countRange.max then
				break
			end

			local enemyId
			if #spawner.enemies == 1 and spawner.enemies[1] == "random" then
				enemyId = EnemyDefinitions:GetRandomEnemy()
			elseif #spawner.enemies == 1 and spawner.enemies[1]:find("_type_") then
				local enemyType = spawner.enemies[1]:match("(%w+)_type_")
				if enemyType then
					enemyId = EnemyDefinitions:GetRandomEnemyOfType(enemyType)
				end
			else
				local spawnChoice = spawner.enemies[math.random(#spawner.enemies)]
				if EnemyDefinitions:GetEnemy(spawnChoice) then
					enemyId = spawnChoice
				else
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
					
					-- Set homePosition to spawner center for patrol boundaries
					if enemyComponents.EnemyAI then
						enemyComponents.EnemyAI.homePosition = spawner.centerPosition
					end
					
					-- Add EnemyChat component for enemy chat functionality
					enemyComponents.EnemyChat = Components.create("EnemyChat")
					
					-- Add all enemy components
					for componentType, componentData in pairs(enemyComponents) do
						EntityManager.addComponent(newEnemyId, componentType, componentData)
					end
					
					-- Create enemy folder in workspace
					local enemyFolder = Instance.new("Folder")
					enemyFolder.Name = tostring(newEnemyId)
					enemyFolder.Parent = workspace:FindFirstChild("Enemies")
					
					-- Create movement zone (this is also the detection zone)
					local movementZone = Instance.new("Part")
					movementZone.Name = "MovementZone"
					movementZone.Size = Vector3.new(40, 1, 40) -- 40x1x40 stud flat movement/detection area
					movementZone.Position = Vector3.new(spawnPosition.X, 0.5, spawnPosition.Z) -- Ground level
					movementZone.Anchored = true
					movementZone.CanCollide = false
					movementZone.Transparency = 0.8 -- Semi-transparent for visibility
					movementZone.Color = Color3.new(0, 1, 0) -- Green color for visibility
					movementZone.Material = Enum.Material.Neon
					movementZone.Parent = enemyFolder
					
					-- Store movement zone data in global table
					_G.enemyMovementZones[newEnemyId] = {
						cFrame = movementZone.CFrame,
						size = movementZone.Size
					}
					
					print("DEBUG: Created zone for enemy", newEnemyId)
					print("  Spawn position:", spawnPosition)
					print("  Zone center:", movementZone.CFrame.Position)
					print("  Zone size:", movementZone.Size)
					print("  Zone CFrame:", movementZone.CFrame)
					
					-- Destroy the part - we only need the data for mathematical detection
					movementZone:Destroy()
					
					-- Set position attribute
					enemyFolder:SetAttribute("Position", spawnPosition)
					enemyFolder:SetAttribute("EnemyType", enemyId)
					enemyFolder:SetAttribute("AIState", "idle")
					
					-- Set health attributes
					local enemyDef = EnemyDefinitions:GetEnemy(enemyId)
					local maxHealth = enemyDef and enemyDef.health or 100
					enemyFolder:SetAttribute("Health", maxHealth)
					enemyFolder:SetAttribute("MaxHealth", maxHealth)
					
					table.insert(spawner.spawnedEntities, newEnemyId)
					spawnedCount = spawnedCount + 1
					totalSpawned = totalSpawned + 1
					
					print(string.format("🎯 Spawned %s at %s", enemyId, tostring(spawnPosition)))
				else
					warn("Failed to create components for enemy: " .. tostring(enemyId))
				end
			end
		end

		-- Update spawner state
		if spawner.spawnType == "once" then
			spawner.hasSpawned = true
		elseif spawner.spawnType == "continuous" then
			spawner.lastSpawnTime = os.clock()
		end

		EntityManager.addComponent(entityId, "Spawner", spawner)

		if spawnedCount > 0 then
			print("🎯 EnemySpawnSystem: Spawned", spawnedCount, "enemies from spawner", entityId)
		end
	end
	
	print("🎯 EnemySpawnSystem: Total enemies spawned:", totalSpawned)
end

-- Remove the update function - no more 3-second loops
-- function EnemySpawnSystem.update(deltaTime) -- REMOVED

return EnemySpawnSystem 