-- MeleeChaseHandler.luau
-- Handles chase behavior specifically for melee enemies
-- Melee enemies are aggressive and persistent, focusing on getting close to attack

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

-- Import Components (find ModuleScript specifically)
local Components = nil
for _, child in ipairs(ReplicatedStorage.Shared:GetChildren()) do
    if child.Name == "EnemyComponents" and child.ClassName == "ModuleScript" then
        Components = require(child)
        break
    end
end

if not Components then
    error("MeleeChaseHandler: Could not find EnemyComponents ModuleScript")
end

local EntityManager = require(ReplicatedStorage.Shared.EntityManager)

-- Import SimpleMovementSystem for movement commands
local SimpleMovementSystem = require(script.Parent.SimpleMovementSystem)

local MeleeChaseHandler = {}

-- Configuration specific to melee enemies
local MELEE_CONFIG = {
    ATTACK_RANGE = 3.0,    -- Default fallback range (enemy definitions override this)
    ATTACK_COOLDOWN = 1.5, -- Time between attacks per player
}

-- Per-player attack cooldowns: {enemyId = {playerId = lastAttackTime}}
local enemyAttackCooldowns = {}

-- Clean up melee chase handler for an entity
function MeleeChaseHandler.cleanup(entityId)
    -- Clean up cooldown data
    enemyAttackCooldowns[entityId] = nil
    print("🧹 MeleeChaseHandler: Cleaned up entity", entityId)
end

-- Handle melee enemy chase behavior (SERVICE - no state changes)
function MeleeChaseHandler.handleChase(entityId, enemyAI, currentPosition, bestTarget, currentTime)
    -- Validate inputs - trust AISystem validation
    if not bestTarget or not bestTarget.target then
        return -- No valid target, but don't change state (AISystem handles that)
    end
    
    -- Get enemy-specific attack range for movement (should match client raycastDistance)
    local enemyType = EntityManager.getComponent(entityId, "EnemyType")
    local attackRange = MELEE_CONFIG.ATTACK_RANGE -- Default fallback
    
    -- Check if enemy has custom raycast distance in config (should match client)
    if enemyType and enemyType.config and enemyType.config.raycastDistance then
        attackRange = enemyType.config.raycastDistance
    end
    
    -- Calculate distance to target for movement only
    local targetPosition = bestTarget.position
    local distance = (currentPosition - targetPosition).Magnitude
    
    if distance <= attackRange then
        -- In attack range - stop moving, let client handle attack
        -- Client will perform raycast and send attack request
        print("🎯 Melee enemy", entityId, "in attack range, waiting for client attack")
    else
        -- Out of range - move toward target
        local baseSpeed = enemyAI.speed or 16
        
        -- Set position to target position (client handles movement)
        SimpleMovementSystem.setPosition(entityId, targetPosition)
    end
end

-- Validate and process client attack request
function MeleeChaseHandler.validateAttackRequest(entityId, targetPlayer, raycastDistance, timestamp)
    -- Basic validation
    if not entityId or not targetPlayer then
        return false, "Invalid parameters"
    end
    
    -- Check if enemy exists and is in chase state
    local enemyAI = EntityManager.getComponent(entityId, "EnemyAI")
    if not enemyAI or (enemyAI.state ~= "chase" and enemyAI.state ~= "attack_chase") then
        return false, "Enemy not in chase state"
    end
    
    -- Check if target player is valid and alive
    if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("Humanoid") then
        return false, "Target player invalid"
    end
    
    local targetHumanoid = targetPlayer.Character.Humanoid
    if targetHumanoid.Health <= 0 then
        return false, "Target player is dead"
    end
    
    -- Get enemy definition for attack cooldown
    local enemyType = EntityManager.getComponent(entityId, "EnemyType")
    local attackCooldown = MELEE_CONFIG.ATTACK_COOLDOWN -- Default cooldown
    
    if enemyType and enemyType.config and enemyType.config.attackCooldown then
        attackCooldown = enemyType.config.attackCooldown
    end
    
    -- Check per-player attack cooldown
    local cooldownData = enemyAttackCooldowns[entityId]
    if cooldownData and cooldownData[targetPlayer.UserId] then
        local lastAttackTime = cooldownData[targetPlayer.UserId]
        local currentTime = tick()
        
        if currentTime - lastAttackTime < attackCooldown then
            return false, "Attack on cooldown for this player"
        end
    end
    
    -- Validate distance (with 20% buffer for lag compensation)
    local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
    if not enemyFolder then
        return false, "Enemy folder not found"
    end
    
    local enemyPosition = enemyFolder:GetAttribute("Position")
    if not enemyPosition then
        return false, "Enemy position not found"
    end
    
    local targetPosition = targetPlayer.Character.HumanoidRootPart.Position
    local actualDistance = (enemyPosition - targetPosition).Magnitude
    local maxAllowedDistance = raycastDistance * 1.2 -- 20% buffer
    
    if actualDistance > maxAllowedDistance then
        return false, "Distance too far"
    end
    
    -- Check if enemy is dead using universal death indicator
    local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
    if not enemyFolder then
        return false, "Enemy folder not found"
    end
    
    if enemyFolder:GetAttribute("Dead") == true then
        return false, "Enemy is dead"
    end
    
    -- All validation passed - apply damage
    local damage = 10 -- Default damage
    if enemyType and enemyType.config and enemyType.config.damage then
        damage = enemyType.config.damage
    end
    
    -- Apply damage
    local DamageSystem = require(script.Parent.Parent.Systems.DamageSystem)
    DamageSystem:ApplyDamage(targetHumanoid, damage, nil, "EnemyMeleeAttack")
    
    -- Update per-player cooldown
    if not enemyAttackCooldowns[entityId] then
        enemyAttackCooldowns[entityId] = {}
    end
    enemyAttackCooldowns[entityId][targetPlayer.UserId] = tick()
    
    print("💥 Melee enemy", entityId, "attacked", targetPlayer.Name, "for", damage, "damage")
    return true, "Attack successful"
end

return MeleeChaseHandler 