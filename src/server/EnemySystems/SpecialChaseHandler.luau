-- SpecialChaseHandler.luau
-- Handles chase behavior specifically for special enemies
-- Special enemies have unique abilities and behaviors

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Import Components (find ModuleScript specifically)
local Components = nil
for _, child in ipairs(ReplicatedStorage.Shared:GetChildren()) do
    if child.Name == "EnemyComponents" and child.ClassName == "ModuleScript" then
        Components = require(child)
        break
    end
end

if not Components then
    error("SpecialChaseHandler: Could not find EnemyComponents ModuleScript")
end

local EntityManager = require(ReplicatedStorage.Shared.EntityManager)

-- Import MovementSystem for movement commands
local MovementSystem = require(script.Parent.MovementSystem)

local SpecialChaseHandler = {}

-- Configuration specific to special enemies
local SPECIAL_CONFIG = {
    PERSISTENCE_MULTIPLIER = 2.0,      -- Chase until 2x detection range (very persistent)
    MOVE_THRESHOLD_MULTIPLIER = 0.3,   -- Very responsive movement
    ABILITY_COOLDOWN = 5.0,            -- Seconds between special abilities
    TELEPORT_RANGE = 15,               -- Range for teleport abilities
    STOP_DISTANCE = 1.5,               -- Stop moving when this close to player
    SPEED_BOOST = 1.2,                 -- 20% speed boost for special enemies
}

-- Clean up special chase handler for an entity
function SpecialChaseHandler.cleanup(entityId)
    -- No state to clean up - handlers are stateless
    print("🧹 SpecialChaseHandler: Cleaned up entity", entityId)
end

-- Handle special enemy chase behavior (SERVICE - no state changes)
function SpecialChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, currentTime)
    -- Validate inputs
    if not closestPlayer or not closestPlayer.player then
        return -- No valid target, but don't change state (AISystem handles that)
    end
    
    -- Get enemy-specific ranges
    local detectionRange = enemyAI.detectionRange
    if not detectionRange then
        warn("⚠️ No detectionRange defined for entity", entityId, "- cannot chase")
        return
    end
    
    -- Calculate distance to target
    local currentPosition = model.part.Position
    local targetPosition = closestPlayer.position
    local distance = (currentPosition - targetPosition).Magnitude
    
    -- Check if we should give up chase (special enemies are very persistent)
    local maxChaseDistance = detectionRange * SPECIAL_CONFIG.PERSISTENCE_MULTIPLIER
    if distance > maxChaseDistance then
        return -- Target too far, but don't change state (AISystem handles that)
    end
    
    -- Check chase timeout
    local chaseTime = currentTime - (enemyAI.stateStartTime or currentTime)
    if chaseTime >= 10 then -- 10 second timeout
        return -- Timeout, but don't change state (AISystem handles that)
    end
    
    -- === MOVEMENT LOGIC (enhanced movement with speed boost) ===
    local baseSpeed = enemyAI.speed or 16
    local enhancedSpeed = baseSpeed * SPECIAL_CONFIG.SPEED_BOOST
    
    -- Use MovementSystem for enhanced movement toward player
    MovementSystem.moveTowardPlayer(entityId, targetPosition, enhancedSpeed, SPECIAL_CONFIG.STOP_DISTANCE)
    
    -- === SPECIAL ABILITIES LOGIC ===
    SpecialChaseHandler._handleSpecialAbilities(entityId, enemyAI, model, closestPlayer, distance, currentTime)
    
    -- === ATTACK LOGIC (similar to melee but with special effects) ===
    local attackRange = 5 -- Default attack range
    local inAttackRange = distance <= attackRange
    if inAttackRange then
        SpecialChaseHandler._handleContinuousAttack(entityId, closestPlayer, currentTime)
    end
end

-- Handle special abilities (placeholder for future implementation)
function SpecialChaseHandler._handleSpecialAbilities(entityId, enemyAI, model, closestPlayer, distance, currentTime)
    -- Could implement special abilities here (teleport, area attacks, etc.)
    -- For now, just a placeholder
    print("✨ Special enemy", entityId, "ready for special ability")
end

-- Handle continuous attacking during chase (similar to melee but with special effects)
function SpecialChaseHandler._handleContinuousAttack(entityId, closestPlayer, currentTime)
    local combat = EntityManager.getComponent(entityId, "Combat")
    if not combat then
        -- Create fallback combat component
        local enemyAI = EntityManager.getComponent(entityId, "EnemyAI")
        local enemyType = EntityManager.getComponent(entityId, "EnemyType")
        local damage = (enemyType and enemyType.config and enemyType.config.damage) or 15 -- Higher damage for special enemies
        local attackCooldown = (enemyType and enemyType.config and enemyType.config.attackSpeed) and (1 / enemyType.config.attackSpeed) or 1.2
        EntityManager.addComponent(entityId, "Combat", Components.create("Combat", {
            damage = damage,
            attackCooldown = attackCooldown
        }))
        combat = EntityManager.getComponent(entityId, "Combat")
    end
    
    -- Check attack cooldown
    local timeSinceLastAttack = currentTime - (combat.lastAttackTime or 0)
    local attackCooldown = combat.attackCooldown or 1.2
    
    if timeSinceLastAttack >= attackCooldown then
        -- Perform special attack (could be enhanced version of melee attack)
        SpecialChaseHandler._performSpecialAttack(entityId, closestPlayer, combat, currentTime)
        
        -- Update attack time
        combat.lastAttackTime = currentTime
        EntityManager.addComponent(entityId, "Combat", combat)
    end
end

-- Perform special attack (placeholder for enhanced attack logic)
function SpecialChaseHandler._performSpecialAttack(entityId, closestPlayer, combat, currentTime)
    local model = EntityManager.getComponent(entityId, "Model")
    if not model or not model.part then
        return
    end
    
    -- Set up attack state for special attack
    combat.isAttacking = true
    combat.attackStartTime = currentTime
    combat.attackTargetPlayer = closestPlayer.player
    
    print("✨ Special enemy", entityId, "performing special attack on", closestPlayer.player.Name)
    
    -- Could implement special attack effects here
    -- For now, just apply damage like a melee enemy but with special effects
    if closestPlayer.player.Character and closestPlayer.player.Character:FindFirstChild("Humanoid") then
        local humanoid = closestPlayer.player.Character.Humanoid
        humanoid:TakeDamage(combat.damage or 15)
        print("💥 Special attack hit", closestPlayer.player.Name, "for", combat.damage or 15, "damage")
    end
    
    -- Reset attack state
    combat.isAttacking = false
    combat.attackStartTime = 0
    combat.attackTargetPlayer = nil
end

return SpecialChaseHandler 