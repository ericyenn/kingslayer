-- AISystem.luau
-- AI system for enemy behavior
-- Handles state transitions, decision making, and coordinates chase handlers
-- Uses part-based detection instead of distance checks

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- Import ECS components
local EntityManager = require(ReplicatedStorage.Shared.EntityManager)

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
local SimpleMovementSystem = require(script.Parent.SimpleMovementSystem)

local AISystem = {}
AISystem.name = "AISystem"

-- Configuration
local CONFIG = {
	UPDATE_INTERVAL_IDLE = 1/8, -- 8 FPS for idle/patrol states
	UPDATE_INTERVAL_CHASE = 1/10, -- 10 FPS for chase states
	MAX_ENTITIES_PER_FRAME = 12,
	
	-- AI ranges
	ATTACK_RANGE = 5,
	
	-- State timeouts
	IDLE_TIME_MIN = 3, -- Minimum time to stay in idle state (seconds)
	IDLE_TIME_MAX = 10, -- Maximum time to stay in idle state (seconds)
	PATROL_TIME = 3,
	TALKING_DURATION = 6.0, -- Duration of talking state (6 seconds)
	
	-- Chat detection
	CHAT_CHECK_INTERVAL = 5.0, -- Check for chat opportunities every 5 seconds
	CHAT_DETECTION_RANGE = 5, -- Range to detect nearby enemies for chat
}

-- AI States
local AI_STATES = {
	IDLE = "idle",
	PATROL = "patrol", 
	CHASE = "chase",
	TALKING = "talking",
	ATTACK_CHASE = "attack_chase"
}

-- Track which players are touching each enemy's detection part
local enemyTouchingPlayers = {} -- {[entityId] = {player1, player2, ...}}

-- Track detection part connections for cleanup
local detectionConnections = {} -- {[entityId] = {touchedConnection, touchEndedConnection}}

-- Helper function to validate target (player or NPC)
local function isValidTarget(target)
    if not target or not target.Parent or 
       not target:FindFirstChild("HumanoidRootPart") or
       not target:FindFirstChildOfClass("Humanoid") or
       target:FindFirstChildOfClass("Humanoid").Health <= 0 then
        return false
    end
    
    -- Check if it's a player with Dead tag
    local player = Players:GetPlayerFromCharacter(target)
    if player and CollectionService:HasTag(player, "Dead") then
        return false
    end
    
    -- Check if it's an NPC that's ragdolled (dead)
    local ReviveSystem = require(script.Parent.Parent.Systems.ReviveSystem)
    if ReviveSystem:IsNPCDead(target) then
        return false
    end
    
    return true
end

-- Find best target from players touching the enemy's detection part
function AISystem._findBestTarget(entityId)
    local touchingPlayers = enemyTouchingPlayers[entityId] or {}
    local bestTarget = nil
    local bestDistance = math.huge
    
    for _, player in pairs(touchingPlayers) do
        if player and player.Character and isValidTarget(player.Character) then
            local playerPosition = player.Character.HumanoidRootPart.Position
            local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
            if enemyFolder then
                local enemyPosition = enemyFolder:GetAttribute("Position")
                if enemyPosition then
                    local distance = (playerPosition - enemyPosition).Magnitude
                    if distance < bestDistance then
                        bestDistance = distance
                        bestTarget = {
                            target = player.Character,
                            position = playerPosition,
                            type = "player",
                            entity = player.Character
                        }
                    end
                end
            end
        end
    end
    
    return bestTarget, bestDistance
end

-- Check for nearby enemies that could start a conversation (client-side chat will handle the actual conversation)
function AISystem._checkForChatOpportunity(entityId, enemyAI, currentTime)
    -- Check if enough time has passed since last chat check
    local lastChatCheck = enemyAI.lastChatCheck or 0
    if currentTime - lastChatCheck < CONFIG.CHAT_CHECK_INTERVAL then
        return
    end
    
    -- Find nearby enemies that could chat
    local allChatEntities = EntityManager.getEntitiesWithAll({"EnemyAI", "EnemyChat"})
    local nearbyEntities = {}
    
    local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
    if not enemyFolder then return end
    
    local currentPosition = enemyFolder:GetAttribute("Position")
    if not currentPosition then return end
    
    for _, otherEntityId in ipairs(allChatEntities) do
        if otherEntityId ~= entityId then
            local otherFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(otherEntityId))
            if otherFolder then
                local otherPosition = otherFolder:GetAttribute("Position")
                if otherPosition then
                    local distance = (currentPosition - otherPosition).Magnitude
                    if distance <= CONFIG.CHAT_DETECTION_RANGE then
                        table.insert(nearbyEntities, otherEntityId)
                    end
                end
            end
        end
    end
    
    -- If we found nearby enemies, set both to talking state (client will handle the conversation)
    if #nearbyEntities > 0 and math.random() <= 0.3 then
		local otherEntityId = nearbyEntities[1] -- Pick first nearby enemy
		local otherEnemyAI = EntityManager.getComponent(otherEntityId, "EnemyAI")
		if otherEnemyAI then
			AISystem._setState(otherEntityId, otherEnemyAI, AI_STATES.TALKING)
			-- Make enemies face each other
			AISystem._makeEnemiesFaceEachOther(entityId, otherEntityId)
		end
		AISystem._setState(entityId, enemyAI, AI_STATES.TALKING)
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
		
		-- Update folder attribute
		local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
		if enemyFolder then
			enemyFolder:SetAttribute("AIState", newState)
		end
		
		-- Clean up tracking when leaving chase state
		if oldState == AI_STATES.CHASE and newState ~= AI_STATES.CHASE then
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
			local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
			if enemyFolder then
				local currentPosition = enemyFolder:GetAttribute("Position")
				if currentPosition then
					AISystem._setPatrolPosition(entityId, currentPosition, enemyAI)
					print("[AI] Entity", entityId, "entered patrol state, set patrol target")
				end
			end
		elseif newState == AI_STATES.CHASE then
			-- Initialize chase state
			print("[AI] Entity", entityId, "entered chase state")
		elseif newState == AI_STATES.IDLE then
			-- Stop movement immediately when entering idle state
			print("[AI] Entity", entityId, "entered idle state, stopped movement")
		elseif newState == AI_STATES.TALKING then
			-- Stop movement and other actions when entering talking state
			print("[AI] Entity", entityId, "entered talking state, stopped movement")
		elseif newState == AI_STATES.ATTACK_CHASE then
			-- Initialize attack chase state
			print("[AI] Entity", entityId, "entered attack_chase state")
		end
		
		EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
		print("[AI] Entity", entityId, "state changed from", oldState, "to", newState)
	end
end

-- Set patrol position
function AISystem._setPatrolPosition(entityId, currentPosition, enemyAI)
	local homePosition = enemyAI.homePosition or currentPosition
	local patrolRadius = enemyAI.patrolRadius or 30
	
	-- Move to random position in zone (combines getRandomPositionInZone + setPosition)
	local SimpleMovementSystem = require(script.Parent.SimpleMovementSystem)
	if SimpleMovementSystem.moveToRandomPosition(entityId) then
		print("[AI] Entity", entityId, "moved to random patrol position")
	else
		print("[AI] Entity", entityId, "no movement zone defined")
	end
end

-- Handle idle state
function AISystem._handleIdleState(entityId, enemyAI, currentTime)
	-- Check for chat opportunities during idle state
	AISystem._checkForChatOpportunity(entityId, enemyAI, currentTime)
	
	-- Get the idle duration for this entity (random between min and max)
	local idleDuration = enemyAI.idleDuration
	if not idleDuration then
		-- Set random idle duration when entering idle state
		idleDuration = math.random(CONFIG.IDLE_TIME_MIN, CONFIG.IDLE_TIME_MAX)
		enemyAI.idleDuration = idleDuration
		print("[AI] Entity", entityId, "set idle duration to", idleDuration, "seconds")
	end
	
	-- Transition to patrol after idle time
	local stateTime = currentTime - (enemyAI.stateStartTime or currentTime)
	if stateTime >= idleDuration then
		AISystem._setState(entityId, enemyAI, AI_STATES.PATROL)
		enemyAI.idleDuration = nil -- Clear the duration for next idle cycle
		print("[AI] Entity", entityId, "idle time complete (", idleDuration, "s), transitioning to patrol")
		EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
	end
end

-- Handle patrol state
function AISystem._handlePatrolState(entityId, enemyAI, currentTime)
	-- Check for chat opportunities during patrol state
	AISystem._checkForChatOpportunity(entityId, enemyAI, currentTime)
	
	-- Handle patrol movement
	local stateTime = currentTime - (enemyAI.stateStartTime or currentTime)
	
	-- Set patrol position only once when entering patrol state
	if not enemyAI.patrolPositionSet then
		local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
		if enemyFolder then
			local currentPosition = enemyFolder:GetAttribute("Position")
			if currentPosition then
				AISystem._setPatrolPosition(entityId, currentPosition, enemyAI)
				enemyAI.patrolPositionSet = true
				print("[AI] Entity", entityId, "set patrol position")
			end
		end
	end
	
	-- Return to idle after patrol time
	if stateTime >= CONFIG.PATROL_TIME then
		AISystem._setState(entityId, enemyAI, AI_STATES.IDLE)
		enemyAI.target = nil
		enemyAI.patrolPositionSet = nil -- Reset for next patrol cycle
		print("[AI] Entity", entityId, "patrol time complete, returning to idle")
		EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
	end
end

-- Handle talking state
function AISystem._handleTalkingState(entityId, enemyAI, currentTime)
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

-- Handle attack chase state (identical to chase but no zone restrictions)
function AISystem._handleAttackChaseState(entityId, enemyAI, currentTime)
	-- Check if attack chase time has expired (15 seconds)
	local timeInAttackChase = currentTime - enemyAI.stateStartTime
	if timeInAttackChase >= 15.0 then
		-- Attack chase expired - return to idle
		AISystem._setState(entityId, enemyAI, AI_STATES.IDLE)
		enemyAI.target = nil
		print("[AI] Entity", entityId, "attack chase expired, returning to idle")
		return
	end
	
	-- Same logic as normal chase but no zone restrictions
	local bestTarget, bestDistance = AISystem._findBestTarget(entityId)
	if bestTarget then
		AISystem._callChaseHandler(entityId, enemyAI, bestTarget, currentTime)
	else
		-- No valid target - return to idle
		AISystem._setState(entityId, enemyAI, AI_STATES.IDLE)
		enemyAI.target = nil
		print("[AI] Entity", entityId, "no valid target in attack chase, returning to idle")
	end
end

-- Call appropriate chase handler service
function AISystem._callChaseHandler(entityId, enemyAI, bestTarget, currentTime)
	local enemyType = EntityManager.getComponent(entityId, "EnemyType")
	if not enemyType then
		warn("No EnemyType component found for entity", entityId, "- defaulting to melee behavior")
		enemyType = {enemyType = "melee"}
	end
	
	print("[AI] DEBUG: Entity", entityId, "enemyType:", enemyType.enemyType, "bestTarget valid:", bestTarget ~= nil)
	
	-- Validate inputs before calling chase handler
	if not bestTarget or not bestTarget.target then
		warn("Invalid bestTarget for entity", entityId, "- skipping chase handler")
		return
	end
	
	local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
	if not enemyFolder then
		warn("No enemy folder found for entity", entityId, "- skipping chase handler")
		return
	end
	
	local currentPosition = enemyFolder:GetAttribute("Position")
	if not currentPosition then
		warn("No position found for entity", entityId, "- skipping chase handler")
		return
	end
	
	-- Call appropriate chase handler service
	local success, error = pcall(function()
		if enemyType.enemyType == "melee" then
			MeleeChaseHandler.handleChase(entityId, enemyAI, currentPosition, bestTarget, currentTime)
		elseif enemyType.enemyType == "ranged" then
			RangedChaseHandler.handleChase(entityId, enemyAI, currentPosition, bestTarget, currentTime)
		elseif enemyType.enemyType == "special" then
			SpecialChaseHandler.handleChase(entityId, enemyAI, currentPosition, bestTarget, currentTime)
		else
			warn("Unknown enemy type:", enemyType.enemyType, "for entity", entityId, "- using melee handler")
			MeleeChaseHandler.handleChase(entityId, enemyAI, currentPosition, bestTarget, currentTime)
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
	print("[AI] Initialized - using part-based detection")
	
	-- Make system globally accessible for cleanup
	_G.AISystem = AISystem
	
	return true
end

-- Set up detection part collision handling
function AISystem.setupDetectionPart(entityId, detectionPart)
	-- Track touching players for this enemy
	enemyTouchingPlayers[entityId] = {}
	
	-- Store connections for cleanup
	detectionConnections[entityId] = {}
	
	-- Handle player touching detection part
	local touchedConnection = detectionPart.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		
		if player and isValidTarget(player.Character) then
			-- Add player to touching list
			if not enemyTouchingPlayers[entityId] then
				enemyTouchingPlayers[entityId] = {}
			end
			
			-- Check if player is already in the list
			local alreadyTouching = false
			for _, touchingPlayer in pairs(enemyTouchingPlayers[entityId]) do
				if touchingPlayer == player then
					alreadyTouching = true
					break
				end
			end
			
			if not alreadyTouching then
				table.insert(enemyTouchingPlayers[entityId], player)
				print("[AI] Player", player.Name, "started touching enemy", entityId)
			end
		end
	end)
	
	-- Handle player leaving detection part
	local touchEndedConnection = detectionPart.TouchEnded:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		
		if player and enemyTouchingPlayers[entityId] then
			-- Remove player from touching list
			for i, touchingPlayer in pairs(enemyTouchingPlayers[entityId]) do
				if touchingPlayer == player then
					table.remove(enemyTouchingPlayers[entityId], i)
					print("[AI] Player", player.Name, "stopped touching enemy", entityId)
					break
				end
			end
		end
	end)
	
	-- Store connections for cleanup
	detectionConnections[entityId] = {
		touched = touchedConnection,
		touchEnded = touchEndedConnection
	}
end

-- Clean up detection part events for dead enemies
function AISystem.cleanupDeadEnemy(entityId)
	-- Disconnect detection part events
	if detectionConnections[entityId] then
		if detectionConnections[entityId].touched then
			detectionConnections[entityId].touched:Disconnect()
		end
		if detectionConnections[entityId].touchEnded then
			detectionConnections[entityId].touchEnded:Disconnect()
		end
		detectionConnections[entityId] = nil
		print("[AI] Cleaned up detection events for dead enemy", entityId)
	end
	
	-- Clear touching players
	enemyTouchingPlayers[entityId] = nil
end

-- Check if player is in enemy's movement zone
function AISystem.isPlayerInZone(entityId, player)
	local zoneData = _G.enemyMovementZones and _G.enemyMovementZones[entityId]
	if not zoneData then 
		print("DEBUG: No zone data for entity", entityId)
		return false 
	end
	
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then 
		print("DEBUG: No character or HumanoidRootPart for player", player.Name)
		return false 
	end
	
	local playerPosition = character.HumanoidRootPart.Position
	local zoneCenter = zoneData.cFrame.Position
	local distance = (playerPosition - zoneCenter).Magnitude
	local threshold = zoneData.size.X / 2
	
	print("DEBUG Zone Check - Entity:", entityId, "Player:", player.Name)
	print("  Zone center:", zoneCenter)
	print("  Zone size:", zoneData.size)
	print("  Player position:", playerPosition)
	print("  Distance:", distance)
	print("  Threshold:", threshold)
	print("  In zone:", distance <= threshold)
	
	return distance <= threshold -- 20 studs radius
end

-- Make two enemies face each other
function AISystem._makeEnemiesFaceEachOther(entityId1, entityId2)
	local enemy1Folder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId1))
	local enemy2Folder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId2))
	
	if enemy1Folder and enemy2Folder then
		local pos1 = enemy1Folder:GetAttribute("Position")
		local pos2 = enemy2Folder:GetAttribute("Position")
		
		if pos1 and pos2 then
			-- Calculate directions for rotation
			local direction1 = (pos2 - pos1).Unit
			local direction2 = (pos1 - pos2).Unit
			
			-- Set rotation attributes for client-side rotation
			enemy1Folder:SetAttribute("FacingDirection", direction1)
			enemy2Folder:SetAttribute("FacingDirection", direction2)
			
			print("[AI] Enemies", entityId1, "and", entityId2, "facing each other for conversation")
		end
	end
end

-- Main update function
function AISystem.update(deltaTime)
    local currentTime = tick()
    local entitiesProcessed = 0
    
    -- Get all entities with EnemyAI components
    local aiEntities = EntityManager.getEntitiesWith("EnemyAI")

    for _, entityId in ipairs(aiEntities) do
        if entitiesProcessed >= CONFIG.MAX_ENTITIES_PER_FRAME then
            break
        end
        
        local enemyAI = EntityManager.getComponent(entityId, "EnemyAI")
        
        if not enemyAI then
            continue
        end
        
        -- Skip dead enemies
        local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
        if enemyFolder and enemyFolder:GetAttribute("Dead") == true then
            continue
        end
        
        local currentState = enemyAI.state or AI_STATES.IDLE
		
		-- Debug: Log detection info occasionally
		if currentTime % 5 < 0.1 then -- Log every 5 seconds
			local playersInZone = 0
			for _, player in pairs(Players:GetPlayers()) do
				if AISystem.isPlayerInZone(entityId, player) then
					playersInZone = playersInZone + 1
				end
			end
			print("[AI] Entity", entityId, "State:", currentState, "Players in zone:", playersInZone)
		end
		
		-- STEP 2: STATE PROCESSING
		if currentState == AI_STATES.CHASE then
			-- CHASE STATE: Check if any players are still in zone
			local shouldUpdate = AISystem._shouldUpdateEntity(entityId, enemyAI, currentTime)
			if shouldUpdate then
				local bestTarget, bestDistance = AISystem._findBestTarget(entityId)
				
				-- Update enemyTouchingPlayers with zone detection results
				enemyTouchingPlayers[entityId] = {}
				for _, player in pairs(Players:GetPlayers()) do
					if AISystem.isPlayerInZone(entityId, player) then
						table.insert(enemyTouchingPlayers[entityId], player)
					end
				end
				
				-- Check if any players are still in the movement zone
				local touchingPlayers = enemyTouchingPlayers[entityId] or {}
				
				if #touchingPlayers == 0 then
					-- No players in zone - go back to idle
					AISystem._setState(entityId, enemyAI, AI_STATES.IDLE)
					enemyAI.target = nil
					print("[AI] Entity", entityId, "no players in zone, returning to idle")
				else
					-- Players still in zone - continue chase
					AISystem._callChaseHandler(entityId, enemyAI, bestTarget, currentTime)
				end
				
				enemyAI.lastUpdateTime = currentTime
				EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
				entitiesProcessed = entitiesProcessed + 1
			end
		elseif currentState == AI_STATES.ATTACK_CHASE then
			-- ATTACK_CHASE STATE: Handle attack chase logic
			local shouldUpdate = AISystem._shouldUpdateEntity(entityId, enemyAI, currentTime)
			if shouldUpdate then
				AISystem._handleAttackChaseState(entityId, enemyAI, currentTime)
				enemyAI.lastUpdateTime = currentTime
				EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
				entitiesProcessed = entitiesProcessed + 1
			end
		else
			-- IDLE/PATROL STATE: Check for players in movement zone
			local shouldUpdate = AISystem._shouldUpdateEntity(entityId, enemyAI, currentTime)
			if shouldUpdate then
				-- Update enemyTouchingPlayers with zone detection results
				enemyTouchingPlayers[entityId] = {}
				for _, player in pairs(Players:GetPlayers()) do
					if AISystem.isPlayerInZone(entityId, player) then
						table.insert(enemyTouchingPlayers[entityId], player)
					end
				end
				
				local touchingPlayers = enemyTouchingPlayers[entityId] or {}
				
				-- Check if any players are in the movement zone
				if #touchingPlayers > 0 then
					-- Players in zone - start chase
					local bestTarget, bestDistance = AISystem._findBestTarget(entityId)
					if bestTarget then
						AISystem._setState(entityId, enemyAI, AI_STATES.CHASE)
						enemyAI.target = bestTarget.target
						print("[AI] Entity", entityId, "triggered chase - player in movement zone")
					end
				else
					-- No players in zone - handle idle/patrol logic
					local success, error = pcall(function()
						if currentState == AI_STATES.IDLE then
							AISystem._handleIdleState(entityId, enemyAI, currentTime)
						elseif currentState == AI_STATES.PATROL then
							AISystem._handlePatrolState(entityId, enemyAI, currentTime)
						elseif currentState == AI_STATES.TALKING then
							AISystem._handleTalkingState(entityId, enemyAI, currentTime)
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
end

return AISystem

