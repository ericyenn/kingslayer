-- MovementSystem.luau
-- Unified movement system for all enemy types
-- Handles movement for patrol and chase states only
--
-- ROLE: Movement execution only - does NOT make AI decisions
-- - AI System makes decisions (state changes, target selection)
-- - MovementSystem executes movement (Humanoid:MoveTo, speed adjustments)
-- - Chase Handlers handle enemy-type-specific behavior (attacks, abilities)
--
-- COORDINATION:
-- - AI System calls MovementSystem.moveToPatrolPosition() for patrol targets
-- - MovementSystem.update() handles all movement execution
-- - MovementSystem.cleanup() called by AI System when leaving chase state

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

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
    error("MovementSystem: Could not find EnemyComponents ModuleScript")
end

local MovementSystem = {}
MovementSystem.name = "MovementSystem"

-- Configuration
local CONFIG = {
    UPDATE_INTERVAL = 1/60, -- 60 FPS for smooth movement updates
    MAX_MOVEMENTS_PER_FRAME = 20,
    
    -- Movement settings
    DEFAULT_SPEED = 16,
    STUCK_TIMEOUT = 1, -- Force new MoveTo if no movement for 1 second (reduced from 2)
    PLAYER_MOVE_THRESHOLD = 1, -- Only call MoveTo if player moved >1 studs (reduced from 2)
    
    -- Chase movement settings
    MELEE_STOP_DISTANCE = 1.5, -- Melee enemies stop at this distance
    RANGED_RANDOM_MOVE_INTERVAL = 2, -- How often ranged enemies change random direction
}

-- System state
local lastUpdate = 0
local entityLastPlayerPositions = {} -- Track last known player position per entity
local entityLastMoveToTime = {} -- Track last MoveTo time per entity
local rangedEnemyRandomMoveTime = {} -- Track when ranged enemies last changed random direction

-- Initialize system
function MovementSystem.initialize()
    lastUpdate = 0
    entityLastPlayerPositions = {}
    entityLastMoveToTime = {}
    rangedEnemyRandomMoveTime = {}
    return true
end

-- Stop movement immediately (for idle state transitions)
function MovementSystem.stopMovement(entityId, model)
    if not model or not model.humanoid then
        return
    end
    
    -- Stop movement by moving to current position
    model.humanoid:MoveTo(model.part.Position)
    model.humanoid.WalkSpeed = 0
    
    -- Clean up any movement tracking
    entityLastPlayerPositions[entityId] = nil
    entityLastMoveToTime[entityId] = nil
    rangedEnemyRandomMoveTime[entityId] = nil
    
    print("🛑 MovementSystem: Stopped movement for entity", entityId)
end

-- Main update function
function MovementSystem.update(deltaTime)
    local currentTime = tick()
    if currentTime - lastUpdate < CONFIG.UPDATE_INTERVAL then
        return
    end
    lastUpdate = currentTime
    
    local movementsProcessed = 0
    
    -- Get all entities with EnemyAI and Model components
    local aiEntities = EntityManager.getEntitiesWithAll({"EnemyAI", "Model"})
    
    for _, entityId in ipairs(aiEntities) do
        if movementsProcessed >= CONFIG.MAX_MOVEMENTS_PER_FRAME then
            break
        end
        
        local enemyAI = EntityManager.getComponent(entityId, "EnemyAI")
        local model = EntityManager.getComponent(entityId, "Model")
        local enemyType = EntityManager.getComponent(entityId, "EnemyType")
        
        if enemyAI and model and model.part and model.humanoid then
            -- Check if enemy is in idle state - stop movement immediately
            if enemyAI.state == "idle" then
                MovementSystem.stopMovement(entityId, model)
                continue
            end
            
            -- Check if any player is within activation zone (performance optimization)
            local isPlayerInActivationZone = false
            for _, player in pairs(Players:GetPlayers()) do
                -- Validate player is still valid
                if player and player.Parent and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    -- Additional validation to ensure player hasn't disconnected
                    local humanoidRootPart = player.Character.HumanoidRootPart
                    if humanoidRootPart and humanoidRootPart.Parent then
                        if not CollectionService:HasTag(player, "Dead") then
                            local distance = (model.part.Position - humanoidRootPart.Position).Magnitude
                            if distance <= 150 then -- Use same activation zone as AI System
                                isPlayerInActivationZone = true
                                break
                            end
                        end
                    end
                end
            end
            
            -- Skip movement processing if no players in activation zone (optimization)
            if not isPlayerInActivationZone then
                -- Stop movement when outside activation zone
                model.humanoid:MoveTo(model.part.Position)
                continue
            end
            
            local currentState = enemyAI.state or "idle"
            
            -- Handle movement for all states
            if currentState == "chase" and enemyAI.target then
                MovementSystem._handleChaseMovement(entityId, enemyAI, model, enemyType, currentTime)
                movementsProcessed = movementsProcessed + 1
            elseif currentState == "patrol" then
                -- Handle patrol movement
                MovementSystem._handlePatrolMovement(entityId, enemyAI, model, currentTime)
                movementsProcessed = movementsProcessed + 1
            elseif currentState == "idle" then
                -- Stop movement when in idle state
                model.humanoid:MoveTo(model.part.Position)
            end
        end
    end
    
    -- Perform maintenance every 30 seconds
    if currentTime % 30 < CONFIG.UPDATE_INTERVAL then
        MovementSystem.performMaintenance()
    end
end

-- Handle patrol movement
function MovementSystem._handlePatrolMovement(entityId, enemyAI, model, currentTime)
    -- Check if we need to set a new patrol target
    local lastPatrolTime = enemyAI.lastPatrolTime or 0
    local patrolTarget = enemyAI.patrolTarget
    
    -- Set initial patrol target if none exists
    if not patrolTarget then
        print("🏃 MovementSystem: Setting initial patrol target for entity", entityId)
        MovementSystem._setRandomPatrolTarget(entityId, model, enemyAI)
        enemyAI.lastPatrolTime = currentTime
        EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
        return
    end
    
    -- Check if we've reached the current patrol target or need a new one
    local distanceToTarget = (model.part.Position - patrolTarget).Magnitude
    local timeSinceLastPatrol = currentTime - lastPatrolTime
    
    -- Set new patrol target if we're close to current target or too much time has passed
    if distanceToTarget < 3 or timeSinceLastPatrol > 10 then
        print("🏃 MovementSystem: Setting new patrol target for entity", entityId, "distance:", math.floor(distanceToTarget), "time:", math.floor(timeSinceLastPatrol))
        MovementSystem._setRandomPatrolTarget(entityId, model, enemyAI)
        enemyAI.lastPatrolTime = currentTime
        EntityManager.addComponent(entityId, "EnemyAI", enemyAI)
    else
        -- Ensure we're still moving to the current target
        local baseSpeed = enemyAI.speed or CONFIG.DEFAULT_SPEED
        model.humanoid.WalkSpeed = baseSpeed * 0.7
        model.humanoid:MoveTo(patrolTarget)
        
        -- Debug: Print patrol movement occasionally
        if math.random() < 0.01 then -- 1% chance to print
            print("🏃 MovementSystem: Entity", entityId, "patrolling to", patrolTarget, "distance:", math.floor(distanceToTarget), "speed:", baseSpeed * 0.7)
        end
    end
end

-- Handle chase movement
function MovementSystem._handleChaseMovement(entityId, enemyAI, model, enemyType, currentTime)
    local target = enemyAI.target
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local targetPosition = target.Character.HumanoidRootPart.Position
    local currentPosition = model.part.Position
    local distance = (currentPosition - targetPosition).Magnitude
    
    -- Check if we should update movement
    local shouldUpdateMoveTo = MovementSystem._shouldUpdateMovement(entityId, targetPosition, currentTime)
    
    if shouldUpdateMoveTo then
        -- Apply movement based on enemy type
        MovementSystem._moveToTarget(entityId, model, targetPosition, distance, enemyAI, enemyType, currentTime)
        
        -- Update tracking
        entityLastPlayerPositions[entityId] = targetPosition
        entityLastMoveToTime[entityId] = currentTime
    end
end

-- Determine if movement should be updated
function MovementSystem._shouldUpdateMovement(entityId, targetPosition, currentTime)
    -- Always update movement for smoother tracking
    -- Removed complex logic that could cause choppy movement
    return true
end

-- Move to target with enemy-type-specific behavior
function MovementSystem._moveToTarget(entityId, model, targetPosition, distance, enemyAI, enemyType, currentTime)
    local humanoid = model.humanoid
    local baseSpeed = enemyAI.speed or CONFIG.DEFAULT_SPEED
    local attackRange = enemyAI.attackRange or 5
    
    if not enemyType then
        -- Default movement
        humanoid.WalkSpeed = baseSpeed
        humanoid:MoveTo(targetPosition)
        return
    end
    
    if enemyType.enemyType == "melee" then
        -- Melee: Move directly toward player until 1.5 studs away
        if distance <= CONFIG.MELEE_STOP_DISTANCE then
            -- Close enough - stop moving
            humanoid:MoveTo(model.part.Position)
            return
        end
        
        -- Move directly toward player with full speed
        humanoid.WalkSpeed = baseSpeed
        humanoid:MoveTo(targetPosition)
        
        -- Debug: Print movement info occasionally
        if math.random() < 0.01 then -- 1% chance to print
            print("🏃 Melee enemy", entityId, "moving to player at speed", baseSpeed, "distance:", math.floor(distance))
        end
        
    elseif enemyType.enemyType == "ranged" then
        -- Ranged: Move randomly if too far to shoot
        if distance <= attackRange then
            -- In shooting range - stop moving
            humanoid:MoveTo(model.part.Position)
            return
        end
        
        -- Too far to shoot - move in random direction toward player
        local lastRandomMove = rangedEnemyRandomMoveTime[entityId] or 0
        if currentTime - lastRandomMove > CONFIG.RANGED_RANDOM_MOVE_INTERVAL then
            -- Change random direction
            MovementSystem._setRandomRangedMoveTarget(entityId, model, targetPosition, distance)
            rangedEnemyRandomMoveTime[entityId] = currentTime
        end
        
        -- Use moderate speed for ranged positioning
        humanoid.WalkSpeed = baseSpeed * 0.9
        
    elseif enemyType.enemyType == "special" then
        -- Special: Enhanced movement with 20% speed boost
        local SLOW_ZONE = attackRange * 2.5
        local STOPPING_ZONE = attackRange * 0.9
        
        local newSpeed = baseSpeed * 1.2 -- 20% faster
        
        if distance <= STOPPING_ZONE then
            -- Close enough for special attacks
            humanoid:MoveTo(model.part.Position)
            return
        elseif distance <= SLOW_ZONE then
            -- Smooth approach but maintain higher speed
            local slowFactor = math.max(0.6, distance / SLOW_ZONE)
            newSpeed = newSpeed * slowFactor
        end
        
        humanoid.WalkSpeed = newSpeed
        humanoid:MoveTo(targetPosition)
        
    else
        -- Default movement for unknown types
        humanoid.WalkSpeed = baseSpeed
        humanoid:MoveTo(targetPosition)
    end
end

-- Set random movement target for ranged enemies
function MovementSystem._setRandomRangedMoveTarget(entityId, model, playerPosition, distance)
    if not model or not model.humanoid then
        return
    end
    
    local currentPosition = model.part.Position
    
    -- Calculate direction toward player
    local directionToPlayer = (playerPosition - currentPosition).Unit
    
    -- Add random offset (perpendicular to direction to player)
    local randomAngle = math.random() * 2 * math.pi
    local perpendicular = Vector3.new(-directionToPlayer.Z, 0, directionToPlayer.X)
    local randomOffset = perpendicular * math.random(-2, 2) -- Random offset of -2 to 2 studs
    
    -- Create target position that's closer to player but with random offset
    local moveDistance = math.min(distance - 5, 10) -- Move closer but not too far
    local targetPosition = currentPosition + (directionToPlayer * moveDistance) + randomOffset
    
    model.humanoid:MoveTo(targetPosition)
end

-- Set random patrol target
function MovementSystem._setRandomPatrolTarget(entityId, model, enemyAI)
    if not model or not model.humanoid then
        return
    end
    
    local homePosition = enemyAI.homePosition or model.part.Position
    local patrolRadius = enemyAI.patrolRadius or 30
    
    -- Generate random patrol target within patrol radius
    local angle = math.random() * 2 * math.pi
    local distance = math.random(5, patrolRadius)
    local targetPos = homePosition + Vector3.new(
        math.cos(angle) * distance,
        0,
        math.sin(angle) * distance
    )
    
    -- Set proper walk speed for patrol movement
    local baseSpeed = enemyAI.speed or CONFIG.DEFAULT_SPEED
    model.humanoid.WalkSpeed = baseSpeed * 0.7 -- Slightly slower for patrol
    
    -- Move to the patrol target
    model.humanoid:MoveTo(targetPos)
    
    -- Store the target position for tracking
    enemyAI.patrolTarget = targetPos
    
    print("🏃 MovementSystem: Set patrol target for entity", entityId, "to", targetPos, "speed:", baseSpeed * 0.7)
end

-- Move to random patrol position (for external calls)
function MovementSystem.moveToPatrolPosition(entityId, model, enemyAI)
    MovementSystem._setRandomPatrolTarget(entityId, model, enemyAI)
end

-- Clean up tracking data when entity is destroyed
function MovementSystem.cleanup(entityId)
    entityLastPlayerPositions[entityId] = nil
    entityLastMoveToTime[entityId] = nil
    rangedEnemyRandomMoveTime[entityId] = nil
end

-- Perform maintenance to prevent memory leaks
function MovementSystem.performMaintenance()
    local currentTime = tick()
    
    -- Clean up expired tracking data
    local cleanupCount = 0
    for entityId, lastMoveTime in pairs(entityLastMoveToTime) do
        if currentTime - lastMoveTime > 60 then -- Remove data older than 60 seconds
            entityLastPlayerPositions[entityId] = nil
            entityLastMoveToTime[entityId] = nil
            rangedEnemyRandomMoveTime[entityId] = nil
            cleanupCount = cleanupCount + 1
        end
    end
    
    if cleanupCount > 0 then
        print("🧹 MovementSystem: Cleaned up", cleanupCount, "expired tracking entries")
    end
end

return MovementSystem 