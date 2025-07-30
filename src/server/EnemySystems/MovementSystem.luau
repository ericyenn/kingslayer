-- MovementSystem.luau
-- Movement execution service for all enemy types
-- Handles movement execution only - NO decision making
--
-- ROLE: Movement execution service - does NOT make AI decisions
-- - Chase Handlers make ALL decisions (state changes, target selection, when to move)
-- - MovementSystem executes movement commands (Humanoid:MoveTo, speed adjustments)
-- - Chase Handlers call MovementSystem functions directly
--
-- COORDINATION:
-- - AISystem calls MovementSystem.moveToPatrolPosition() for patrol targets
-- - Chase Handlers call MovementSystem commands for chase movement
-- - AISystem calls MovementSystem.stopMovement() for idle/talking states
-- - MovementSystem.cleanup() called by AISystem when leaving chase state

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
    error("MovementSystem: Could not find EnemyComponents ModuleScript")
end

local MovementSystem = {}
MovementSystem.name = "MovementSystem"

-- Configuration
local CONFIG = {
    -- Movement settings
    DEFAULT_SPEED = 16,
    
    -- Patrol settings
    PATROL_SPEED_MULTIPLIER = 0.7, -- 70% speed for patrol
}

-- System state (minimal - only for tracking movement commands)
local activeMovementCommands = {} -- Track active movement commands per entity

-- Initialize system
function MovementSystem.initialize()
    activeMovementCommands = {}
    return true
end

-- ========================================
-- COMMAND FUNCTIONS (Called by Chase Handlers)
-- ========================================

-- Move to a specific position with given speed
function MovementSystem.moveToPosition(entityId, targetPosition, speed)
    local model = EntityManager.getComponent(entityId, "Model")
    if not model or not model.humanoid then
        return false
    end
    
    local humanoid = model.humanoid
    humanoid.WalkSpeed = speed or CONFIG.DEFAULT_SPEED
    humanoid:MoveTo(targetPosition)
    
    -- Track this movement command
    activeMovementCommands[entityId] = {
        type = "moveToPosition",
        targetPosition = targetPosition,
        speed = speed,
        startTime = tick()
    }
    
    print("🏃 MovementSystem: Entity", entityId, "moving to position", targetPosition, "at speed", speed)
    return true
end

-- Stop movement immediately
function MovementSystem.stopMovement(entityId)
    local model = EntityManager.getComponent(entityId, "Model")
    if not model or not model.humanoid then
        return false
    end
    
    -- Stop movement by moving to current position
    model.humanoid:MoveTo(model.part.Position)
    model.humanoid.WalkSpeed = 0
    
    -- Clear movement command
    activeMovementCommands[entityId] = nil
    
    print("🛑 MovementSystem: Stopped movement for entity", entityId)
    return true
end

-- Set speed without changing target
function MovementSystem.setSpeed(entityId, speed)
    local model = EntityManager.getComponent(entityId, "Model")
    if not model or not model.humanoid then
        return false
    end
    
    model.humanoid.WalkSpeed = speed or CONFIG.DEFAULT_SPEED
    
    -- Update active command if exists
    if activeMovementCommands[entityId] then
        activeMovementCommands[entityId].speed = speed
    end
    
    print("⚡ MovementSystem: Entity", entityId, "speed set to", speed)
    return true
end

-- Move to a random position within radius of center
function MovementSystem.moveToRandomPosition(entityId, centerPosition, radius, speed)
    local model = EntityManager.getComponent(entityId, "Model")
    if not model or not model.humanoid then
        return false
    end
    
    -- Generate random position within radius
    local angle = math.random() * 2 * math.pi
    local distance = math.random(0, radius)
    local targetPos = centerPosition + Vector3.new(
        math.cos(angle) * distance,
        0,
        math.sin(angle) * distance
    )
    
    local humanoid = model.humanoid
    humanoid.WalkSpeed = speed or CONFIG.DEFAULT_SPEED
    humanoid:MoveTo(targetPos)
    
    -- Track this movement command
    activeMovementCommands[entityId] = {
        type = "moveToRandomPosition",
        centerPosition = centerPosition,
        radius = radius,
        targetPosition = targetPos,
        speed = speed,
        startTime = tick()
    }
    
    print("🎲 MovementSystem: Entity", entityId, "moving to random position", targetPos, "at speed", speed)
    return true
end

-- Move to tactical position with approach style
function MovementSystem.moveToTacticalPosition(entityId, targetPosition, speed, approachStyle)
    local model = EntityManager.getComponent(entityId, "Model")
    if not model or not model.humanoid then
        return false
    end
    
    local humanoid = model.humanoid
    humanoid.WalkSpeed = speed or CONFIG.DEFAULT_SPEED
    humanoid:MoveTo(targetPosition)
    
    -- Track this movement command
    activeMovementCommands[entityId] = {
        type = "moveToTacticalPosition",
        targetPosition = targetPosition,
        speed = speed,
        approachStyle = approachStyle,
        startTime = tick()
    }
    
    print("🎯 MovementSystem: Entity", entityId, "moving to tactical position", targetPosition, "style:", approachStyle)
    return true
end

-- Move toward player with specific behavior
function MovementSystem.moveTowardPlayer(entityId, playerPosition, speed, stopDistance)
    local model = EntityManager.getComponent(entityId, "Model")
    if not model or not model.humanoid then
        return false
    end
    
    local currentPosition = model.part.Position
    local distance = (currentPosition - playerPosition).Magnitude
    
    -- Check if we should stop
    if stopDistance and distance <= stopDistance then
        MovementSystem.stopMovement(entityId)
        return true
    end
    
    local humanoid = model.humanoid
    humanoid.WalkSpeed = speed or CONFIG.DEFAULT_SPEED
    humanoid:MoveTo(playerPosition)
    
    -- Track this movement command
    activeMovementCommands[entityId] = {
        type = "moveTowardPlayer",
        targetPosition = playerPosition,
        speed = speed,
        stopDistance = stopDistance,
        startTime = tick()
    }
    
    print("👤 MovementSystem: Entity", entityId, "moving toward player at speed", speed, "distance:", math.floor(distance))
    return true
end

-- ========================================
-- AI SYSTEM FUNCTIONS (Called by AISystem)
-- ========================================

-- Move to patrol position (called by AISystem)
function MovementSystem.moveToPatrolPosition(entityId, model, enemyAI)
    if not model or not model.humanoid then
        return false
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
    local patrolSpeed = baseSpeed * CONFIG.PATROL_SPEED_MULTIPLIER
    
    -- Use the command function
    MovementSystem.moveToPosition(entityId, targetPos, patrolSpeed)
    
    -- Store the target position for tracking
    enemyAI.patrolTarget = targetPos
    
    print("🏃 MovementSystem: Set patrol target for entity", entityId, "to", targetPos, "speed:", patrolSpeed)
    return true
end

-- Stop movement immediately (called by AISystem)
function MovementSystem.stopMovement(entityId, model)
    local model = model or EntityManager.getComponent(entityId, "Model")
    if not model or not model.humanoid then
        return false
    end
    
    -- Stop the humanoid movement
    model.humanoid:MoveTo(model.part.Position)
    model.humanoid.WalkSpeed = 0
    
    -- Clear movement command tracking
    activeMovementCommands[entityId] = nil
    
    print("🛑 MovementSystem: Stopped movement for entity", entityId)
    return true
end

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

-- Get current movement command for an entity
function MovementSystem.getActiveCommand(entityId)
    return activeMovementCommands[entityId]
end

-- Check if entity is currently moving
function MovementSystem.isMoving(entityId)
    local model = EntityManager.getComponent(entityId, "Model")
    if not model or not model.humanoid then
        return false
    end
    
    return model.humanoid.WalkSpeed > 0
end

-- Clean up tracking data when entity is destroyed (called by AISystem)
function MovementSystem.cleanup(entityId)
    activeMovementCommands[entityId] = nil
    print("🧹 MovementSystem: Cleaned up movement data for entity", entityId)
end

-- Perform maintenance to prevent memory leaks (called periodically)
function MovementSystem.performMaintenance()
    local currentTime = tick()
    
    -- Clean up expired tracking data
    local cleanupCount = 0
    for entityId, command in pairs(activeMovementCommands) do
        if currentTime - command.startTime > 60 then -- Remove data older than 60 seconds
            activeMovementCommands[entityId] = nil
            cleanupCount = cleanupCount + 1
        end
    end
    
    if cleanupCount > 0 then
        print("🧹 MovementSystem: Cleaned up", cleanupCount, "expired movement commands")
    end
end

return MovementSystem 