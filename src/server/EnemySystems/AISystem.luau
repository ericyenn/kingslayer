-- AISystem.luau
-- AI system for enemy behavior
-- Handles state transitions, decision making, and coordinates chase handlers

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

-- Import chase handlers as services
local MeleeChaseHandler = require(script.Parent.MeleeChaseHandler)
local RangedChaseHandler = require(script.Parent.RangedChaseHandler)
local SpecialChaseHandler = require(script.Parent.SpecialChaseHandler)

-- Import movement system
local MovementSystem = require(script.Parent.MovementSystem)

-- Import enemy chat system
local EnemyChatSystem = require(script.Parent.EnemyChatSystem)

local AISystem = {}
AISystem.name = "AISystem"

-- Configuration
local CONFIG = {
	UPDATE_INTERVAL_IDLE = 1/8, -- 8 FPS for idle/patrol states
	UPDATE_INTERVAL_CHASE = 1/10, -- 10 FPS for chase states
	MAX_ENTITIES_PER_FRAME = 12,
	
	-- AI ranges
	ATTACK_RANGE = 5,
	CHASE_TIMEOUT = 10, -- Give up chase after this many seconds
	
	-- State timeouts
	IDLE_TIME_MIN = 3, -- Minimum time to stay in idle state (seconds)
	IDLE_TIME_MAX = 10, -- Maximum time to stay in idle state (seconds)
	PATROL_TIME = 3,
	TALKING_DURATION = 6.0, -- Duration of talking state (6 seconds)
	
	-- Zone-based activation (PERFORMANCE OPTIMIZATION)
	ACTIVATION_ZONE_RADIUS = 150, -- Only process AI within this distance of players
	
	-- Chat detection
	CHAT_CHECK_INTERVAL = 2.0, -- Check for chat opportunities every 2 seconds
	CHAT_DETECTION_RANGE = 8, -- Range to detect nearby enemies for chat
}

-- AI States
local AI_STATES = {
	IDLE = "idle",
	PATROL = "patrol", 
	CHASE = "chase",
	TALKING = "talking",
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

-- Check for nearby enemies that could start a conversation
function AISystem._checkForChatOpportunity(entityId, enemyAI, model, currentTime)
    -- Check if enough time has passed since last chat check
    local lastChatCheck = enemyAI.lastChatCheck or 0
    if currentTime - lastChatCheck < CONFIG.CHAT_CHECK_INTERVAL then
        return
    end
    
    -- Find nearby enemies that could chat
    local allChatEntities = EntityManager.getEntitiesWithAll({"EnemyAI", "Model", "EnemyChat"})
    local nearbyEntities = {}
    
    for _, otherEntityId in ipairs(allChatEntities) do
        if otherEntityId ~= entityId then
            local otherModel = EntityManager.getComponent(otherEntityId, "Model")
            if otherModel and otherModel.part then
                local distance = (model.part.Position - otherModel.part.Position).Magnitude
                if distance <= CONFIG.CHAT_DETECTION_RANGE then
                    table.insert(nearbyEntities, otherEntityId)
                end
            end
        end
    end
    
    -- Check each nearby enemy for chat opportunity
    for _, otherEntityId in ipairs(nearbyEntities) do
        -- Check if these enemies can chat
        if EnemyChatSystem.canEnemiesChat(entityId, otherEntityId, currentTime) then
            -- Start conversation and set both enemies to talking state
            if EnemyChatSystem.startConversation(entityId, otherEntityId, currentTime) then
                -- Set both enemies to talking state
                local otherEnemyAI = EntityManager.getComponent(otherEntityId, "EnemyAI")
                if otherEnemyAI then
                    AISystem._setState(otherEntityId, otherEnemyAI, AI_STATES.TALKING)
                end
                AISystem._setState(entityId, enemyAI, AI_STATES.TALKING)
                break
            end
        end
    end
    
    -- Update last chat check time
    enemyAI.lastChatCheck = currentTime
    EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
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
			
			-- Clean up chase handlers
			local enemyType = EntityManager.getComponent(entityId, "EnemyType")
			if enemyType then
				if enemyType.enemyType == "melee" then
					MeleeChaseHandler.cleanup(entityId)
				elseif enemyType.enemyType == "ranged" then
					RangedChaseHandler.cleanup(entityId)
				elseif enemyType.enemyType == "special" then
					SpecialChaseHandler.cleanup(entityId)
				end
			end
			
			print("[AI] Entity", entityId, "left chase state, cleaned up all handlers")
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
			-- Stop movement immediately when entering idle state
			local model = EntityManager.getComponent(entityId, "Model")
			if model and model.part then
				MovementSystem.stopMovement(entityId, model)
				print("[AI] Entity", entityId, "entered idle state, stopped movement immediately")
			end
		elseif newState == AI_STATES.TALKING then
			-- Stop movement and other actions when entering talking state
			local model = EntityManager.getComponent(entityId, "Model")
			if model and model.part then
				MovementSystem.stopMovement(entityId, model)
				print("[AI] Entity", entityId, "entered talking state, stopped movement")
			end
		end
		
		-- Simple RemoteEvent call to update animations
		local model = EntityManager.getComponent(entityId, "Model")
		if model and model.model then
			RemoteEvents.EnemyAIStateUpdate:FireAllClients(model.model, entityId, newState)
			print("[AI] Sent state update to clients:", entityId, "->", newState)
		end
		
		EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
		print("[AI] Entity", entityId, "state changed from", oldState, "to", newState)
	end
end

-- Handle idle state
function AISystem._handleIdleState(entityId, enemyAI, model, currentTime)
	-- Check for chat opportunities during idle state
	AISystem._checkForChatOpportunity(entityId, enemyAI, model, currentTime)
	
	-- Get the idle duration for this entity (random between min and max)
	local idleDuration = enemyAI.idleDuration
	if not idleDuration then
		-- Set random idle duration when entering idle state
		idleDuration = math.random(CONFIG.IDLE_TIME_MIN, CONFIG.IDLE_TIME_MAX)
		enemyAI.idleDuration = idleDuration
		print("[AI] Entity", entityId, "set idle duration to", idleDuration, "seconds")
	end
	
	-- Transition to patrol after idle time (since animation system is now purely reactive)
	local stateTime = currentTime - (enemyAI.stateStartTime or currentTime)
	if stateTime >= idleDuration then
		AISystem._setState(entityId, enemyAI, AI_STATES.PATROL)
		enemyAI.idleDuration = nil -- Clear the duration for next idle cycle
		print("[AI] Entity", entityId, "idle time complete (", idleDuration, "s), transitioning to patrol")
		EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
	end
end

-- Handle patrol state
function AISystem._handlePatrolState(entityId, enemyAI, model, currentTime)
	-- Check for chat opportunities during patrol state
	AISystem._checkForChatOpportunity(entityId, enemyAI, model, currentTime)
	
	-- Handle patrol movement
	local stateTime = currentTime - (enemyAI.stateStartTime or currentTime)
	
	-- Move to patrol position if not already moving
	if not MovementSystem.isMoving(entityId) then
		local patrolTarget = AISystem._getPatrolTarget(entityId, model)
		if patrolTarget then
			local baseSpeed = enemyAI.speed or 16
			MovementSystem.moveToPosition(entityId, patrolTarget, baseSpeed * 0.7) -- Slower patrol speed
			print("[AI] Entity", entityId, "moving to patrol position")
		end
	end
	
	-- Return to idle after patrol time
	if stateTime >= CONFIG.PATROL_TIME then
		MovementSystem.stopMovement(entityId) -- Stop movement when leaving patrol
		AISystem._setState(entityId, enemyAI, AI_STATES.IDLE)
		enemyAI.target = nil
		print("[AI] Entity", entityId, "patrol time complete, returning to idle")
		EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
	end
end

-- Get patrol target position for an entity
function AISystem._getPatrolTarget(entityId, model)
	if not model or not model.part then
		return nil
	end
	
	-- Simple patrol: move to a random position within 20 studs of current position
	local currentPosition = model.part.Position
	local randomOffset = Vector3.new(
		math.random(-20, 20),
		0,
		math.random(-20, 20)
	)
	
	return currentPosition + randomOffset
end

-- Handle talking state
function AISystem._handleTalkingState(entityId, enemyAI, model, currentTime)
	-- Talking state lasts for a configured duration
	local timeInTalking = currentTime - enemyAI.stateStartTime
	local timeRemaining = CONFIG.TALKING_DURATION - timeInTalking
	
	if timeInTalking >= CONFIG.TALKING_DURATION then
		-- Conversation ended, transition to patrol state
		print("[AI] Entity", entityId, "talking ended, transitioning to patrol")
		AISystem._setState(entityId, enemyAI, AI_STATES.PATROL)
	else
		-- Debug: Log remaining time occasionally
		if math.floor(timeRemaining) % 2 == 0 and timeRemaining > 0 then
			print("[AI] Entity", entityId, "still talking,", math.floor(timeRemaining), "seconds remaining")
		end
	end
end

-- Call appropriate chase handler service
function AISystem._callChaseHandler(entityId, enemyAI, model, closestPlayer, currentTime)
	local enemyType = EntityManager.getComponent(entityId, "EnemyType")
	if not enemyType then
		warn("No EnemyType component found for entity", entityId, "- defaulting to melee behavior")
		enemyType = {enemyType = "melee"}
	end
	
	-- Validate inputs before calling chase handler
	if not closestPlayer or not closestPlayer.player then
		warn("Invalid closestPlayer for entity", entityId, "- skipping chase handler")
		return
	end
	
	if not model or not model.part then
		warn("Invalid model for entity", entityId, "- skipping chase handler")
		return
	end
	
	if not enemyAI.detectionRange then
		warn("No detectionRange defined for entity", entityId, "- skipping chase handler")
		return
	end
	
	-- Call appropriate chase handler service
	local success, error = pcall(function()
		if enemyType.enemyType == "melee" then
			MeleeChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, currentTime)
		elseif enemyType.enemyType == "ranged" then
			RangedChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, currentTime)
		elseif enemyType.enemyType == "special" then
			SpecialChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, currentTime)
		else
			warn("Unknown enemy type:", enemyType.enemyType, "for entity", entityId, "- using melee handler")
			MeleeChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, currentTime)
		end
	end)
	
	if not success then
		warn("Error in chase handler for entity", entityId, ":", error)
	end
end

-- Determine if entity should be updated based on state and timing
function AISystem._shouldUpdateEntity(entityId, enemyAI, currentTime)
	local state = enemyAI.state or AI_STATES.IDLE
	local lastUpdateTime = enemyAI.lastUpdateTime or 0
	
	-- Use different update intervals based on state
	local updateInterval
	if state == AI_STATES.CHASE then
		updateInterval = CONFIG.UPDATE_INTERVAL_CHASE
	else
		updateInterval = CONFIG.UPDATE_INTERVAL_IDLE
	end
	
	return (currentTime - lastUpdateTime) >= updateInterval
end

-- Initialize system
function AISystem.initialize()
	-- Animation system is now purely reactive - no listeners needed
	print("[AI] Initialized - animation system is purely reactive")
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
		
		-- STEP 1: PERFORMANCE CHECK - Skip if no players in activation zone
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
		
		-- Skip processing entirely if no players in activation zone
		if not isPlayerInActivationZone then
			if currentState ~= AI_STATES.IDLE then
				enemyAI.target = nil
				AISystem._setState(entityId, enemyAI, AI_STATES.IDLE)
				print("[AI] Entity", entityId, "disabled - no players in activation zone")
			end
			continue
		end
		
		-- STEP 2: STATE PROCESSING
		if currentState == AI_STATES.CHASE then
			-- CHASE STATE: Check if target is still in detection range
			local shouldUpdate = AISystem._shouldUpdateEntity(entityId, enemyAI, currentTime)
			if shouldUpdate then
				local closestPlayer, closestDistance = AISystem._findClosestPlayer(currentPosition)
				
				-- Check if target is still valid and in detection range
				if not closestPlayer or closestDistance > enemyAI.detectionRange then
					-- Target out of range - go back to idle
					AISystem._setState(entityId, enemyAI, AI_STATES.IDLE)
					enemyAI.target = nil
					print("[AI] Entity", entityId, "target out of range, returning to idle")
				else
					-- Target in range - call chase handler service
					AISystem._callChaseHandler(entityId, enemyAI, model, closestPlayer, currentTime)
				end
				
				enemyAI.lastUpdateTime = currentTime
				EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
				entitiesProcessed = entitiesProcessed + 1
			end
		else
			-- IDLE/PATROL STATE: Check for players entering detection range
			local shouldUpdate = AISystem._shouldUpdateEntity(entityId, enemyAI, currentTime)
			if shouldUpdate then
				local closestPlayer, closestDistance = AISystem._findClosestPlayer(currentPosition)
				
				-- Check if any player is in detection range
				if closestPlayer and closestDistance <= enemyAI.detectionRange then
					-- Player in range - start chase
					AISystem._setState(entityId, enemyAI, AI_STATES.CHASE)
					enemyAI.target = closestPlayer.player
					print("[AI] Entity", entityId, "triggered chase - player entered detection range (range:", enemyAI.detectionRange, "distance:", math.floor(closestDistance), ")")
					
					-- Immediately call chase handler
					AISystem._callChaseHandler(entityId, enemyAI, model, closestPlayer, currentTime)
				else
					-- No players in range - handle idle/patrol logic
					local success, error = pcall(function()
						if currentState == AI_STATES.IDLE then
							AISystem._handleIdleState(entityId, enemyAI, model, currentTime)
						elseif currentState == AI_STATES.PATROL then
							AISystem._handlePatrolState(entityId, enemyAI, model, currentTime)
						elseif currentState == AI_STATES.TALKING then
							AISystem._handleTalkingState(entityId, enemyAI, model, currentTime)
						end
					end)
					
					if not success then
						warn("Error in state handling for entity", entityId, ":", error)
					end
				end
				
				enemyAI.lastUpdateTime = currentTime
				EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
				entitiesProcessed = entitiesProcessed + 1
			end
		end
	end
	
	-- Perform maintenance every 30 seconds
	if currentTime % 30 < CONFIG.UPDATE_INTERVAL_IDLE then
		MovementSystem.performMaintenance()
	end
end

return AISystem
