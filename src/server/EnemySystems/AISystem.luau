-- AISystem.luau
-- AI system for enemy behavior
-- Handles state transitions and decision making for enemies

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- Import ECS components
local EntityManager = require(ReplicatedStorage.Shared.EntityManager)

-- Import RemoteEvents for animation communication
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

-- Import Components
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

-- Import unified movement system
local MovementSystem = require(script.Parent.MovementSystem)

local AISystem = {}
AISystem.name = "AISystem"

-- Configuration
local CONFIG = {
	UPDATE_INTERVAL_IDLE = 1/8, -- 8 FPS for idle/patrol states
	UPDATE_INTERVAL_CHASE = 1/10, -- 10 FPS for chase/attack states (reduced to avoid conflicts)
	MAX_ENTITIES_PER_FRAME = 12,
	
	-- AI ranges
	DETECTION_RANGE = 30,
	ATTACK_RANGE = 5,
	CHASE_TIMEOUT = 10, -- Give up chase after this many seconds
	
	-- State timeouts
	PATROL_TIME = 3,
	
	-- Zone-based activation
	ACTIVATION_ZONE_RADIUS = 150, -- Only process AI within this distance of players
	DEACTIVATION_ZONE_RADIUS = 200 -- Disable AI when players beyond this distance
}

-- AI States
local AI_STATES = {
	IDLE = "idle",
	PATROL = "patrol", 
	CHASE = "chase",  -- Now handles both chasing and attacking
	DEAD = "dead"
}

-- Helper function to validate player
local function isValidPlayer(player)
    return player and player.Parent and player.Character and 
           player.Character:FindFirstChild("HumanoidRootPart") and
           not CollectionService:HasTag(player, "Dead")
end

-- Helper function to get player distance
local function getPlayerDistance(player, position)
    local humanoidRootPart = player.Character.HumanoidRootPart
    if humanoidRootPart and humanoidRootPart.Parent then
        return (position - humanoidRootPart.Position).Magnitude
    end
    return math.huge
end

-- Find closest player to position
function AISystem._findClosestPlayer(position)
    local closestPlayer = nil
    local closestDistance = math.huge

    for _, player in pairs(Players:GetPlayers()) do
        if isValidPlayer(player) then
            local distance = getPlayerDistance(player, position)
            if distance < closestDistance then
                closestDistance = distance
                closestPlayer = {
                    player = player,
                    position = player.Character.HumanoidRootPart.Position,
                    entity = player.Character
                }
            end
        end
    end

    return closestPlayer, closestDistance
end

-- Determine if entity should be updated based on state and timing
function AISystem._shouldUpdateEntity(entityId, enemyAI, currentTime)
	local state = enemyAI.state or AI_STATES.IDLE
	local lastUpdateTime = enemyAI.lastUpdateTime or 0
	
	-- Use different update intervals based on state
	local updateInterval
	if state == AI_STATES.CHASE then
		-- Don't throttle chase state - let MovementSystem handle movement at 60 FPS
		-- Only update AI logic (target validation, state transitions) at 10 FPS
		updateInterval = CONFIG.UPDATE_INTERVAL_CHASE
	else
		updateInterval = CONFIG.UPDATE_INTERVAL_IDLE
	end
	
	return (currentTime - lastUpdateTime) >= updateInterval
end

-- Set random patrol target (constrained to home position radius)
function AISystem._setRandomPatrolTarget(entityId, currentPos)
	local model = EntityManager.getComponent(entityId, "Model")
	local enemyAI = EntityManager.getComponent(entityId, "EnemyAI")
	if not model or not model.humanoid or not model.humanoid.Parent or not enemyAI then
		return
	end
	
	-- Use MovementSystem for patrol movement
	MovementSystem.moveToPatrolPosition(entityId, model, enemyAI)
end

-- Set AI state
function AISystem._setState(entityId, enemyAI, newState)
	if enemyAI.state ~= newState then
		local oldState = enemyAI.state
		enemyAI.state = newState
		enemyAI.stateStartTime = tick()
		
		-- Clean up tracking when leaving chase state
		if oldState == AI_STATES.CHASE and newState ~= AI_STATES.CHASE then
			MovementSystem.cleanup(entityId)
			print("[AI] Entity", entityId, "left chase state, cleaned up movement tracking")
		end
		
		-- Initialize new state
		if newState == AI_STATES.PATROL then
			-- Set initial patrol target when entering patrol state
			local model = EntityManager.getComponent(entityId, "Model")
			if model and model.part then
				MovementSystem.moveToPatrolPosition(entityId, model, enemyAI)
				print("[AI] Entity", entityId, "entered patrol state, set patrol target")
			end
		elseif newState == AI_STATES.CHASE then
			-- Initialize chase state
			print("[AI] Entity", entityId, "entered chase state")
		elseif newState == AI_STATES.IDLE then
			-- Stop movement when entering idle
			-- MovementSystem will handle stopping movement when appropriate
			print("[AI] Entity", entityId, "entered idle state, stopped movement")
		end
		
		-- Send state update to clients
		local model = EntityManager.getComponent(entityId, "Model")
		if model and model.model then
			RemoteEvents.EnemyAIStateUpdate:FireAllClients(model.model, entityId, newState)
			print("[AI] Sent state update to clients:", entityId, "->", newState)
		end
		
		EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
		print("[AI] Entity", entityId, "state changed from", oldState, "to", newState)
	end
end

-- Handle idle state (now waits for animation completion)
function AISystem._handleIdleState(entityId, enemyAI, model, closestPlayer, closestDistance, currentTime)
	-- Idle state now waits for animation completion signal from client
	-- No random timer logic - animation system will notify when idle animation completes
	-- This function is called periodically but doesn't transition to patrol automatically
end

-- Handle patrol state
function AISystem._handlePatrolState(entityId, enemyAI, model, closestPlayer, closestDistance, currentTime)
	-- Return to idle after patrol time
	local stateTime = currentTime - (enemyAI.stateStartTime or currentTime)
	if stateTime >= CONFIG.PATROL_TIME then
		AISystem._setState(entityId, enemyAI, AI_STATES.IDLE)
		enemyAI.target = nil
		print("[AI] Entity", entityId, "cleared target (patrol->idle)")
		EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
	end
end

-- Handle idle animation completion (using entity ID directly)
function AISystem._handleIdleAnimationComplete(enemyModel, entityId)
	-- Use the entity ID directly - no searching needed!
	if not entityId then
		print("[AI] No entity ID provided for enemy model:", enemyModel.Name)
		return
	end
	
	local enemyAI = EntityManager.getComponent(entityId, "EnemyAI")
	local model = EntityManager.getComponent(entityId, "Model")
	
	if not enemyAI or not model then
		print("[AI] Missing AI or Model component for entity:", entityId)
		return
	end
	
	-- Check if entity is still in idle state
	if enemyAI.state == AI_STATES.IDLE then
		print("[AI] Entity", entityId, "idle animation completed, transitioning to patrol")
		AISystem._setState(entityId, enemyAI, AI_STATES.PATROL)
		AISystem._setRandomPatrolTarget(entityId, model.part.Position)
		enemyAI.target = nil
		EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
	else
		print("[AI] Entity", entityId, "not in idle state, ignoring animation completion")
	end
end

-- Handle chase state using modular chase handlers
function AISystem._handleChaseWithModularHandlers(entityId, enemyAI, model, closestPlayer, closestDistance, currentTime)
	-- Get enemy type to determine which handler to use
	local enemyType = EntityManager.getComponent(entityId, "EnemyType")
	if not enemyType then
		warn("No EnemyType component found for entity", entityId, "- defaulting to melee behavior")
		enemyType = {enemyType = "melee"}
	end
	
	local result = "chase"  -- Default to continue chasing
	
	-- Route to appropriate chase handler based on enemy type
	-- Note: Movement is handled by MovementSystem at 60 FPS, not by chase handlers
	if enemyType.enemyType == "melee" then
		result = MeleeChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, closestDistance, currentTime, nil, CONFIG)
	elseif enemyType.enemyType == "ranged" then
		result = RangedChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, closestDistance, currentTime, nil, CONFIG)
	elseif enemyType.enemyType == "special" then
		result = SpecialChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, closestDistance, currentTime, nil, CONFIG)
	else
		warn("Unknown enemy type:", enemyType.enemyType, "for entity", entityId, "- using melee handler")
		result = MeleeChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, closestDistance, currentTime, nil, CONFIG)
	end
	
	-- Handle state transitions returned by chase handlers
	if result == "idle" then
		AISystem._setState(entityId, enemyAI, AI_STATES.IDLE)
	elseif result == "patrol" then
		AISystem._setState(entityId, enemyAI, AI_STATES.PATROL)
	-- If result is "chase", stay in chase state
	end
end

-- Update AI for a single entity
function AISystem._updateEntityAI(entityId, enemyAI, model, currentTime, closestPlayer, closestDistance)
	-- Update the last update time
	enemyAI.lastUpdateTime = currentTime
	
	local currentState = enemyAI.state or AI_STATES.IDLE
	local currentPosition = model.part.Position
	
	-- Early exit if closestPlayer is dead or invalid
	if closestPlayer and CollectionService:HasTag(closestPlayer.player, "Dead") then
		enemyAI.target = nil
		AISystem._setState(entityId, enemyAI, AI_STATES.IDLE)
		EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
		return
	end
	
	-- State machine
	if currentState == AI_STATES.IDLE then
		AISystem._handleIdleState(entityId, enemyAI, model, closestPlayer, closestDistance, currentTime)
		
	elseif currentState == AI_STATES.PATROL then
		AISystem._handlePatrolState(entityId, enemyAI, model, closestPlayer, closestDistance, currentTime)
		
	elseif currentState == AI_STATES.CHASE then
		-- For chase state, only handle AI logic (target validation, state transitions)
		-- Movement is handled by MovementSystem at 60 FPS
		local result = AISystem._handleChaseWithModularHandlers(entityId, enemyAI, model, closestPlayer, closestDistance, currentTime)
		
	elseif currentState == AI_STATES.DEAD then
		-- Dead entities don't do anything
		return
	end
	
	-- Save the updated AI component
	EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
end

-- Initialize system
function AISystem.initialize()
	-- Set up idle animation completion listener
	if RemoteEvents.IdleAnimationComplete then
		RemoteEvents.IdleAnimationComplete.OnServerEvent:Connect(function(player, enemyModel, entityId)
			print("[AI] Received idle animation completion for enemy:", enemyModel.Name, "entity ID:", entityId, "from player:", player.Name)
			AISystem._handleIdleAnimationComplete(enemyModel, entityId)
		end)
		print("[AI] Set up idle animation completion listener")
	else
		print("[AI] Warning: IdleAnimationComplete RemoteEvent not found")
	end
	
	return true
end

-- Main update function
function AISystem.update(deltaTime)
	local currentTime = tick()
	local entitiesProcessed = 0
	
	-- Get all entities with EnemyAI and Model components
	local aiEntities = EntityManager.getEntitiesWithAll({"EnemyAI", "Model"})

	for _, entityId in ipairs(aiEntities) do
		if entitiesProcessed >= CONFIG.MAX_ENTITIES_PER_FRAME then
			break
		end
		
		local enemyAI = EntityManager.getComponent(entityId, "EnemyAI")
		local model = EntityManager.getComponent(entityId, "Model")
		
		if not enemyAI or not model or not model.part then
			continue
		end
		
		local currentPosition = model.part.Position
		local currentState = enemyAI.state or AI_STATES.IDLE
		
		-- Check if any player is within activation zone
		local isPlayerInActivationZone = false
		for _, player in pairs(Players:GetPlayers()) do
			if isValidPlayer(player) then
				local distance = getPlayerDistance(player, currentPosition)
				if distance <= CONFIG.ACTIVATION_ZONE_RADIUS then
					isPlayerInActivationZone = true
					break
				end
			end
		end
		
		-- Disable AI when players are too far
		if not isPlayerInActivationZone then
			if currentState ~= AI_STATES.IDLE then
				enemyAI.target = nil
				AISystem._setState(entityId, enemyAI, AI_STATES.IDLE)
				-- MovementSystem will handle stopping movement when appropriate
				print("[AI] Entity", entityId, "disabled - no players in activation zone")
			end
			continue
		end
		
		-- Process based on current state
		if currentState == AI_STATES.CHASE then
			-- Chase state processing
			local shouldUpdate = AISystem._shouldUpdateEntity(entityId, enemyAI, currentTime)
			if shouldUpdate then
				local closestPlayer, closestDistance = AISystem._findClosestPlayer(currentPosition)
				
				-- Check if target is still valid
				if enemyAI.target and not isValidPlayer(enemyAI.target) then
					enemyAI.target = nil
					print("[AI] Entity", entityId, "target became invalid, clearing")
				end
				
				-- Update chase logic
				AISystem._updateEntityAI(entityId, enemyAI, model, currentTime, closestPlayer, closestDistance)
				entitiesProcessed = entitiesProcessed + 1
				
				-- MovementSystem.update() handles movement independently at 60 FPS
			end
		else
			-- In idle/patrol state - check for zone transitions
			local isPlayerInZone = false
			
			for _, player in pairs(Players:GetPlayers()) do
				if isValidPlayer(player) then
					local distance = getPlayerDistance(player, currentPosition)
					if distance <= CONFIG.DETECTION_RANGE then
						isPlayerInZone = true
						AISystem._setState(entityId, enemyAI, AI_STATES.CHASE)
						enemyAI.target = player
						print("[AI] Entity", entityId, "triggered chase - player entered zone")
						break
					end
				end
			end
			
			-- Handle idle/patrol logic if no players in zone
			if not isPlayerInZone then
				if currentState == AI_STATES.IDLE then
					local shouldUpdate = AISystem._shouldUpdateEntity(entityId, enemyAI, currentTime)
					if shouldUpdate then
						-- Idle state now waits for animation completion signal
						-- No automatic transition to patrol
						AISystem._updateEntityAI(entityId, enemyAI, model, currentTime, nil, math.huge)
						entitiesProcessed = entitiesProcessed + 1
					end
				elseif currentState == AI_STATES.PATROL then
					local shouldUpdate = AISystem._shouldUpdateEntity(entityId, enemyAI, currentTime)
					if shouldUpdate then
						local stateTime = currentTime - (enemyAI.stateStartTime or currentTime)
						if stateTime >= CONFIG.PATROL_TIME then
							AISystem._setState(entityId, enemyAI, AI_STATES.IDLE)
							enemyAI.target = nil
							print("[AI] Entity", entityId, "cleared target (patrol->idle)")
							EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
						end
						entitiesProcessed = entitiesProcessed + 1
					end
				end
			end
		end
	end
end

return AISystem
