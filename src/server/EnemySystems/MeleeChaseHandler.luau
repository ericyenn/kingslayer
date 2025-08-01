-- MeleeChaseHandler.luau
-- Handles chase behavior specifically for melee enemies
-- Melee enemies are aggressive and persistent, focusing on getting close to attack

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

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
local HitboxSystem = require(ReplicatedStorage.Shared.HitboxSystem)

-- Import MovementSystem for movement commands
local MovementSystem = require(script.Parent.MovementSystem)

local MeleeChaseHandler = {}

-- Attack tracking
local attackUpdateConnection = nil

-- Configuration specific to melee enemies
local ATTACK_DURATION = 0.2 -- Duration of moving shapecast attack
local MELEE_CONFIG = {
    PERSISTENCE_MULTIPLIER = 1.5,      -- Chase until 1.5x detection range
    ATTACK_WHILE_MOVING = true,        -- Can attack while moving
    STOP_DISTANCE = 1.5,               -- Stop moving when this close to player
}

-- Clean up melee chase handler for an entity
function MeleeChaseHandler.cleanup(entityId)
    -- Stop any active attacks for this entity
    local combat = EntityManager.getComponent(entityId, "Combat")
    if combat then
        combat.isAttacking = false
        combat.attackStartTime = 0
        combat.attackTargetPlayer = nil
        EntityManager.addComponent(entityId, "Combat", combat)
    end
    
    print("🧹 MeleeChaseHandler: Cleaned up entity", entityId)
end

-- Handle melee enemy chase behavior (SERVICE - no state changes)
function MeleeChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, currentTime)
    -- Validate inputs
    if not closestPlayer or not closestPlayer.player then
        return -- No valid target, but don't change state (AISystem handles that)
    end
    
    -- Check if target is dead
    local CollectionService = game:GetService("CollectionService")
    if CollectionService:HasTag(closestPlayer.player, "Dead") then
        return -- Target is dead, but don't change state (AISystem handles that)
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
    
    -- Check if we should give up chase (melee enemies are more persistent)
    local maxChaseDistance = detectionRange * MELEE_CONFIG.PERSISTENCE_MULTIPLIER
    if distance > maxChaseDistance then
        return -- Target too far, but don't change state (AISystem handles that)
    end
    
    -- Check chase timeout
    local chaseTime = currentTime - (enemyAI.stateStartTime or currentTime)
    if chaseTime >= 10 then -- 10 second timeout
        return -- Timeout, but don't change state (AISystem handles that)
    end
    
    -- === MOVEMENT LOGIC ===
    -- Melee enemies move directly toward player until close enough
    local baseSpeed = enemyAI.speed or 16
    
    -- Use MovementSystem to move toward player
    MovementSystem.moveTowardPlayer(entityId, targetPosition, baseSpeed, MELEE_CONFIG.STOP_DISTANCE)
    
    -- === ATTACK LOGIC (continuous during chase) ===
    local attackRange = 5 -- Default attack range
    local inAttackRange = distance <= attackRange
    if inAttackRange then
        -- Handle shapecast-based attacking while in range
        MeleeChaseHandler._handleContinuousAttack(entityId, closestPlayer, currentTime)
    end
end

-- Handle continuous attacking during chase with shapecast
function MeleeChaseHandler._handleContinuousAttack(entityId, closestPlayer, currentTime)
    local combat = EntityManager.getComponent(entityId, "Combat")
    if not combat then
        -- Create fallback combat component silently (no warning)
        local enemyAI = EntityManager.getComponent(entityId, "EnemyAI")
        local enemyType = EntityManager.getComponent(entityId, "EnemyType")
        local damage = (enemyType and enemyType.config and enemyType.config.damage) or 10
        local attackCooldown = (enemyType and enemyType.config and enemyType.config.attackSpeed) and (1 / enemyType.config.attackSpeed) or 1
        EntityManager.addComponent(entityId, "Combat", Components.create("Combat", {
            damage = damage,
            attackCooldown = attackCooldown
        }))
        combat = EntityManager.getComponent(entityId, "Combat")
    end
    
    -- Check attack cooldown
    local timeSinceLastAttack = currentTime - (combat.lastAttackTime or 0)
    local attackCooldown = combat.attackCooldown or 1.5
    
    if timeSinceLastAttack >= attackCooldown then
        -- Perform shapecast attack
        MeleeChaseHandler._performShapecastAttack(entityId, closestPlayer, combat, currentTime)
        
        -- Update attack time
        combat.lastAttackTime = currentTime
        EntityManager.addComponent(entityId, "Combat", combat)
    end
end

-- Start moving shapecast attack (attack animation + begin tracking)
function MeleeChaseHandler._performShapecastAttack(entityId, closestPlayer, combat, currentTime)
    local model = EntityManager.getComponent(entityId, "Model")
    if not model or not model.part then
        return
    end
    
    -- Set up attack state for moving shapecast
    combat.isAttacking = true
    combat.attackStartTime = currentTime
    combat.attackTargetPlayer = closestPlayer.player
    
    -- Start the moving shapecast update loop if not already running
    MeleeChaseHandler._ensureAttackUpdateLoop()
    
    print("⚔️ Melee enemy", entityId, "started moving shapecast attack on", closestPlayer.player.Name)
end

-- Deal damage to player from shapecast
function MeleeChaseHandler._dealShapecastDamage(entityId, player, damage)
    if not player.Character or not player.Character:FindFirstChild("Humanoid") then
        return
    end
    -- Prevent damage to dead players
    local CollectionService = game:GetService("CollectionService")
    if CollectionService:HasTag(player, "Dead") then
        print("[MeleeChaseHandler] Player is dead, not applying shapecast damage.")
        return
    end
    -- Simple damage application (you can integrate with your existing damage system)
    local humanoid = player.Character.Humanoid
    humanoid:TakeDamage(damage)
    
    print("💥 Shapecast damage:", player.Name, "took", damage, "damage from melee enemy", entityId)
end

-- Create visual feedback for attack (for debugging)
function MeleeChaseHandler._createAttackVisual(centerPosition, size, hit)
    local visual = Instance.new("Part")
    visual.Name = "MeleeAttackVisual"
    visual.Size = size
    visual.Position = centerPosition
    visual.Anchored = true
    visual.CanCollide = false
    visual.Transparency = 0.7
    visual.Color = hit and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)  -- Green for hit, red for miss
    visual.Material = Enum.Material.Neon
    visual.Parent = workspace
    
    -- Remove after short duration
    Debris:AddItem(visual, 0.2)
end

-- Ensure the attack update loop is running
function MeleeChaseHandler._ensureAttackUpdateLoop()
    if attackUpdateConnection then
        return -- Already running
    end
    
    -- Use throttled update instead of every frame to prevent choppy movement
    local lastUpdate = 0
    local UPDATE_INTERVAL = 1/10 -- 10 FPS for attack updates
    
    attackUpdateConnection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        if currentTime - lastUpdate >= UPDATE_INTERVAL then
            MeleeChaseHandler._updateActiveAttacks()
            lastUpdate = currentTime
        end
    end)
    
    print("🔄 Started melee attack update loop")
end

-- Update all active moving shapecasts
function MeleeChaseHandler._updateActiveAttacks()
    local currentTime = tick()
    local activeAttacks = 0
    
    -- Iterate through all entities with Combat components to find active attacks
    local entitiesWithCombat = EntityManager.getEntitiesWith("Combat")
    for _, entityId in ipairs(entitiesWithCombat) do
        local combat = EntityManager.getComponent(entityId, "Combat")
        
        if combat and combat.isAttacking then
            activeAttacks = activeAttacks + 1
            MeleeChaseHandler._updateSingleAttack(entityId, combat, currentTime)
        end
    end
    
    -- Stop the update loop if no active attacks
    if activeAttacks == 0 and attackUpdateConnection then
        attackUpdateConnection:Disconnect()
        attackUpdateConnection = nil
        print("🛑 Stopped melee attack update loop - no active attacks")
    end
end

-- Update a single entity's moving shapecast attack
function MeleeChaseHandler._updateSingleAttack(entityId, combat, currentTime)
    local model = EntityManager.getComponent(entityId, "Model")
    if not model or not model.part then
        -- Entity no longer exists, end attack
        combat.isAttacking = false
        return
    end
    
    -- Check if attack duration has expired
    local attackElapsed = currentTime - combat.attackStartTime
    if attackElapsed >= ATTACK_DURATION then
        -- Attack duration ended - create miss visual and end attack
        MeleeChaseHandler._endAttack(entityId, combat, false)
        return
    end
    
    -- Perform moving hitbox detection at current enemy position
    local enemyPosition = model.part.Position
    local enemyLookVector = model.part.CFrame.LookVector
    
    -- Get enemy-specific hitbox settings
    local HitboxSystem = require(game:GetService("ReplicatedStorage").Shared.HitboxSystem)
    local enemySettings = HitboxSystem.getEnemySettings("melee") -- Default to melee settings
    
    -- Calculate current hitbox center position (moves with enemy)
    local hitboxCenter = enemyPosition + enemyLookVector * enemySettings.distance
    
    -- Get target player
    local targetPlayer = combat.attackTargetPlayer
    
    -- Perform the hitbox detection using HitboxSystem with proper orientation
    local enemyOrientation = CFrame.Angles(0, math.atan2(enemyLookVector.X, enemyLookVector.Z), 0)
    local detectedParts = HitboxSystem.performDetection(nil, hitboxCenter, enemySettings.size, {
        ignoreFloor = true,
        targetPlayer = targetPlayer
    }, enemyOrientation)
    
    -- Check if we hit the target player
    if targetPlayer and targetPlayer.Character then
        for _, part in ipairs(detectedParts) do
            -- Check if this part belongs to the target player
            if part:IsDescendantOf(targetPlayer.Character) then
                -- Hit! Deal damage and end attack
                MeleeChaseHandler._dealShapecastDamage(entityId, targetPlayer, combat.damage or 10)
                MeleeChaseHandler._endAttack(entityId, combat, true, hitboxCenter, enemySettings.size)
                return
            end
        end
    end
end

-- End an attack with visual feedback
function MeleeChaseHandler._endAttack(entityId, combat, hit, centerPosition, size)
    -- Reset attack state
    combat.isAttacking = false
    combat.attackStartTime = 0
    combat.attackTargetPlayer = nil
    
    -- Create visual feedback
    if hit and centerPosition and size then
        MeleeChaseHandler._createAttackVisual(centerPosition, size, true)
        print("⚔️ Melee enemy", entityId, "HIT with moving shapecast!")
    else
        -- Miss - create visual at current position for feedback
        local model = EntityManager.getComponent(entityId, "Model")
        if model and model.part then
            local enemyPosition = model.part.Position
            local enemyLookVector = model.part.CFrame.LookVector
            local enemySettings = HitboxSystem.getEnemySettings("melee")
            local missCenter = enemyPosition + enemyLookVector * enemySettings.distance
            MeleeChaseHandler._createAttackVisual(missCenter, enemySettings.size, false)
        end
        print("⚔️ Melee enemy", entityId, "MISSED with moving hitbox")
    end
    
    -- Update the combat component
    EntityManager.addComponent(entityId, "Combat", combat)
end

return MeleeChaseHandler 