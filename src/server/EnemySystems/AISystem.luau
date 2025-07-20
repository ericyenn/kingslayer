--[[
AISystem.lua

Core AI State Machine System for processing entities with EnemyAI components.
Manages state transitions between idle, patrol, chase, attack, and dead states.
Pure ECS with no external system dependencies.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
    error("AISystem: Could not find EnemyComponents ModuleScript")
end

-- Import modular chase handlers
local MeleeChaseHandler = require(script.Parent.MeleeChaseHandler)
local RangedChaseHandler = require(script.Parent.RangedChaseHandler)
local SpecialChaseHandler = require(script.Parent.SpecialChaseHandler)

local AISystem = {}
AISystem.name = "AISystem"

-- Configuration
local CONFIG = {
	UPDATE_INTERVAL_IDLE = 1/8, -- 8 FPS for idle/patrol states (increased from 6 FPS)
	UPDATE_INTERVAL_CHASE = 1/20, -- 20 FPS for chase/attack states (increased from 15 FPS for smoother movement)
	PLAYER_UPDATE_INTERVAL = 0.05, -- Update player positions every 0.05 seconds (increased from 0.1)
	MAX_ENTITIES_PER_FRAME = 12,
	MAX_AI_DISTANCE = 150, -- Only process AI within this distance of players
	
	-- AI ranges
	DETECTION_RANGE = 30,
	ATTACK_RANGE = 5,
	CHASE_TIMEOUT = 10, -- Give up chase after this many seconds
	PLAYER_MOVE_THRESHOLD = 2, -- Only call MoveTo if player moved >2 studs (reduced from 5 for smoother following)
	STUCK_TIMEOUT = 2, -- Force new MoveTo if no movement for 2 seconds (reduced from 3 for more responsive unstuck)
	
	-- State timeouts
	IDLE_MIN_TIME = 2,
	IDLE_MAX_TIME = 6,
	PATROL_TIME = 3
}

-- System state
local lastUpdate = 0
local playerPositions = {}
local lastPlayerScan = 0
local entityLastPlayerPositions = {} -- Track last known player position per entity

-- AI States
local AI_STATES = {
	IDLE = "idle",
	PATROL = "patrol", 
	CHASE = "chase",  -- Now handles both chasing and attacking
	DEAD = "dead"
}

-- Initialize system
function AISystem.initialize()
	lastUpdate = 0
	playerPositions = {}
	lastPlayerScan = 0
	return true
end

-- Main update function
function AISystem.update(deltaTime)
	local currentTime = tick()
	
	-- Update player positions periodically
	if currentTime - lastPlayerScan > CONFIG.PLAYER_UPDATE_INTERVAL then
		AISystem._updatePlayerPositions()
		lastPlayerScan = currentTime
	end
	
	local entitiesProcessed = 0
	
	-- Get all entities with EnemyAI, Model, and Health components (removed Position dependency)
	local aiEntities = EntityManager.getEntitiesWithAll({"EnemyAI", "Model", "Health"})

	for _, entityId in ipairs(aiEntities) do
		if entitiesProcessed >= CONFIG.MAX_ENTITIES_PER_FRAME then
			break
		end
		
		local enemyAI = EntityManager.getComponent(entityId, "EnemyAI")
		local model = EntityManager.getComponent(entityId, "Model")
		local health = EntityManager.getComponent(entityId, "Health")
		
		if not enemyAI or not model or not health or not model.part then
			-- Skip this entity
		else
			-- Get position directly from the model
			local currentPosition = model.part.Position
			
			-- Skip if too far from players
			if not AISystem._isNearPlayer(currentPosition) then
				-- Skip this entity
			elseif health.current <= 0 then
				-- Skip if dead
				AISystem._setState(entityId, enemyAI, AI_STATES.DEAD)
			else
				-- Check if we should update this entity based on its state
				local shouldUpdate = AISystem._shouldUpdateEntity(entityId, enemyAI, currentTime)
				if shouldUpdate then
					AISystem._updateEntityAI(entityId, enemyAI, model, currentTime)
					entitiesProcessed = entitiesProcessed + 1
				end
			end
		end
	end
end

-- Update AI for a single entity
function AISystem._updateEntityAI(entityId, enemyAI, model, currentTime)
	-- Update the last update time
	enemyAI.lastUpdateTime = currentTime
	
	local currentState = enemyAI.state or AI_STATES.IDLE
	local currentPosition = model.part.Position
	local closestPlayer, distance = AISystem._findClosestPlayer(currentPosition)
	
	-- State machine
	if currentState == AI_STATES.IDLE then
		AISystem._handleIdleState(entityId, enemyAI, model, closestPlayer, distance, currentTime)
		
	elseif currentState == AI_STATES.PATROL then
		AISystem._handlePatrolState(entityId, enemyAI, model, closestPlayer, distance, currentTime)
		
	elseif currentState == AI_STATES.CHASE then
		-- Use appropriate chase handler based on enemy type
		local result = AISystem._handleChaseWithModularHandlers(entityId, enemyAI, model, closestPlayer, distance, currentTime)
		
	elseif currentState == AI_STATES.DEAD then
		-- Dead entities don't do anything
		return
	end
	
	-- Save the updated AI component
	EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
end

-- Handle idle state
function AISystem._handleIdleState(entityId, enemyAI, model, closestPlayer, distance, currentTime)
	-- Use per-enemy detection range, fallback to config
	local detectionRange = enemyAI.detectionRange or CONFIG.DETECTION_RANGE
	
	-- Check for player
	if closestPlayer and distance <= detectionRange then
		AISystem._setState(entityId, enemyAI, AI_STATES.CHASE)
		return
	end
	
	-- Transition to patrol after random time
	local stateTime = currentTime - (enemyAI.stateStartTime or currentTime)
	local idleTime = math.random(CONFIG.IDLE_MIN_TIME, CONFIG.IDLE_MAX_TIME)
	
	if stateTime >= idleTime then
		AISystem._setState(entityId, enemyAI, AI_STATES.PATROL)
		AISystem._setRandomPatrolTarget(entityId, model.part.Position)
	end
end

-- Handle patrol state
function AISystem._handlePatrolState(entityId, enemyAI, model, closestPlayer, distance, currentTime)
	-- Use per-enemy detection range, fallback to config
	local detectionRange = enemyAI.detectionRange or CONFIG.DETECTION_RANGE
	
	-- Check for player
	if closestPlayer and distance <= detectionRange then
		AISystem._setState(entityId, enemyAI, AI_STATES.CHASE)
		return
	end
	
	-- Return to idle after patrol time
	local stateTime = currentTime - (enemyAI.stateStartTime or currentTime)
	if stateTime >= CONFIG.PATROL_TIME then
		AISystem._setState(entityId, enemyAI, AI_STATES.IDLE)
	end
end

-- Handle chase state using modular chase handlers
function AISystem._handleChaseWithModularHandlers(entityId, enemyAI, model, closestPlayer, distance, currentTime)
	-- Get enemy type to determine which handler to use
	local enemyType = EntityManager.getComponent(entityId, "EnemyType")
	if not enemyType then
		warn("No EnemyType component found for entity", entityId, "- defaulting to melee behavior")
		enemyType = {enemyType = "melee"}
	end
	
	local result = "chase"  -- Default to continue chasing
	
	-- Route to appropriate chase handler based on enemy type
	if enemyType.enemyType == "melee" then
		result = MeleeChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, distance, currentTime, entityLastPlayerPositions, CONFIG)
	elseif enemyType.enemyType == "ranged" then
		result = RangedChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, distance, currentTime, entityLastPlayerPositions, CONFIG)
	elseif enemyType.enemyType == "special" then
		result = SpecialChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, distance, currentTime, entityLastPlayerPositions, CONFIG)
	else
		warn("Unknown enemy type:", enemyType.enemyType, "for entity", entityId, "- using melee handler")
		result = MeleeChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, distance, currentTime, entityLastPlayerPositions, CONFIG)
	end
	
	-- Handle state transitions returned by chase handlers
	if result == "idle" then
		AISystem._setState(entityId, enemyAI, AI_STATES.IDLE)
	elseif result == "patrol" then
		AISystem._setState(entityId, enemyAI, AI_STATES.PATROL)
	-- If result is "chase", stay in chase state
	end
end

-- NOTE: Attack handling functions moved to individual chase handlers for modularity

-- Set AI state
function AISystem._setState(entityId, enemyAI, newState)
	if enemyAI.state ~= newState then
		enemyAI.state = newState
		enemyAI.stateStartTime = tick()
		
		-- Clean up tracking when leaving chase state
		if enemyAI.state ~= AI_STATES.CHASE and entityLastPlayerPositions[entityId] then
			entityLastPlayerPositions[entityId] = nil
		end
		
		-- Play appropriate animation for the new state
		AISystem._playAnimationForState(entityId, newState)
		
		EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
	end
end

-- Play appropriate animation for AI state (respects movement detection priority)
function AISystem._playAnimationForState(entityId, state)
	local animationSet = EntityManager.getComponent(entityId, "AnimationSet")
	if not animationSet then
		return -- No animations loaded for this entity
	end
	
	-- Priority system: Attack > Movement Detection > State-based
	-- Movement detection only controls walk animations, AI controls everything else
	
	-- Note: Attack animations are now handled as overlays in the new system
	-- This section is no longer needed since attacks happen during chase state
		
	if state == AI_STATES.DEAD then
		-- Dead state: stop all animations
		if animationSet.current then
			animationSet.current:Stop()
			animationSet.current = nil
		end
		animationSet.animationSource = "state"
		print("🎭 Entity", entityId, "stopped all animations (dead)")
		
	else
		-- For IDLE, PATROL, CHASE states: play appropriate animations
		-- Don't override movement-driven walk animations, but do play idle/other states
		
		if animationSet.animationSource == "movement" then
			-- Movement detection is controlling - don't override walk animations
			return
		end
		
		-- Play state-based animations
		if animationSet.current then
			animationSet.current:Stop()
			animationSet.current = nil
		end
		
		local newAnimation = nil
		if state == AI_STATES.IDLE and animationSet.idle then
			newAnimation = animationSet.idle
		elseif (state == AI_STATES.PATROL or state == AI_STATES.CHASE) and animationSet.walk then
			newAnimation = animationSet.walk
		end
		
		if newAnimation then
			newAnimation:Play()
			animationSet.current = newAnimation
			animationSet.animationSource = "state"
			print("🎭 Entity", entityId, "playing", state, "animation (state-driven)")
		end
	end
	
	-- Save updated animation state
	EntityManager.addComponent(entityId, "AnimationSet", animationSet)
end

-- Move enemy to player using Roblox's built-in movement
function AISystem._moveToPlayer(entityId, playerData)
	local model = EntityManager.getComponent(entityId, "Model")
	if not model or not model.humanoid or not model.humanoid.Parent then
		return
	end
	
	-- Use Roblox's MoveTo with the actual player part for real-time following
	if playerData.player.Character and playerData.player.Character:FindFirstChild("HumanoidRootPart") then
		model.humanoid:MoveTo(playerData.player.Character.HumanoidRootPart.Position)
		-- REMOVED: Position component sync - we get position directly from model now
	end
end

-- Move enemy to player with zone-based speed adjustment (princess-like movement)
function AISystem._moveToPlayerWithZones(entityId, playerData, currentDistance, slowZoneDistance)
	local model = EntityManager.getComponent(entityId, "Model")
	if not model or not model.humanoid or not model.humanoid.Parent then
		return
	end
	
	-- Use Roblox's MoveTo with the actual player part for real-time following
	if playerData.player.Character and playerData.player.Character:FindFirstChild("HumanoidRootPart") then
		local humanoid = model.humanoid
		local targetPosition = playerData.player.Character.HumanoidRootPart.Position
		
		-- Zone-based speed adjustment for smoother movement
		-- Get base speed from EnemyAI component, fallback to current humanoid speed
		local enemyAI = EntityManager.getComponent(entityId, "EnemyAI")
		local baseSpeed = (enemyAI and enemyAI.speed) or humanoid.WalkSpeed or 16
		local newSpeed = baseSpeed
		
		if currentDistance <= slowZoneDistance then
			-- In slow zone: reduce speed for smoother approach
			local slowFactor = math.max(0.4, currentDistance / slowZoneDistance) -- 40% to 100% speed
			newSpeed = baseSpeed * slowFactor
			print("🐌 Entity", entityId, "in slow zone - speed:", math.floor(newSpeed))
		end
		
		-- Apply speed adjustment
		humanoid.WalkSpeed = newSpeed
		
		-- Move to target
		humanoid:MoveTo(targetPosition)
		
		print("🎯 Entity", entityId, "moving to player at speed", newSpeed, "distance:", math.floor(currentDistance))
	end
end

-- Set random patrol target (simplified for testing)
function AISystem._setRandomPatrolTarget(entityId, currentPos)
	local model = EntityManager.getComponent(entityId, "Model")
	if not model or not model.humanoid or not model.humanoid.Parent then
		return
	end
	
	-- Simple random patrol movement
	local angle = math.random() * 2 * math.pi
	local distance = math.random(10, 20)
	local targetPos = currentPos + Vector3.new(
		math.cos(angle) * distance,
		0,
		math.sin(angle) * distance
	)
	
	model.humanoid:MoveTo(targetPos)
end

-- Update player positions
function AISystem._updatePlayerPositions()
	playerPositions = {}
	
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			table.insert(playerPositions, {
				player = player,
				position = player.Character.HumanoidRootPart.Position,
				entity = player.Character
			})
		end
	end
end

-- Find closest player to position
function AISystem._findClosestPlayer(position)
	local closestPlayer = nil
	local closestDistance = math.huge
	
	for _, playerData in ipairs(playerPositions) do
		local distance = (position - playerData.position).Magnitude
		if distance < closestDistance then
			closestDistance = distance
			closestPlayer = playerData
		end
	end
	
	return closestPlayer, closestDistance
end

-- Check if position is near any player
function AISystem._isNearPlayer(position)
	for _, playerData in ipairs(playerPositions) do
		if (position - playerData.position).Magnitude <= CONFIG.MAX_AI_DISTANCE then
			return true
		end
	end
	return false
end

-- Clean up tracking data when entity is destroyed
function AISystem.cleanup(entityId)
	entityLastPlayerPositions[entityId] = nil
end

-- Determine if entity should be updated based on state and timing
function AISystem._shouldUpdateEntity(entityId, enemyAI, currentTime)
	local state = enemyAI.state or AI_STATES.IDLE
	local lastUpdateTime = enemyAI.lastUpdateTime or 0
	
	-- Use different update intervals based on state
	local updateInterval
	if state == AI_STATES.CHASE then
		updateInterval = CONFIG.UPDATE_INTERVAL_CHASE -- 20 FPS for active states (chase now includes attacking)
	else
		updateInterval = CONFIG.UPDATE_INTERVAL_IDLE -- 8 FPS for passive states
	end
	
	return (currentTime - lastUpdateTime) >= updateInterval
end

return AISystem
