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

-- Rotation utility removed for melee enemies (only ranged enemies rotate)

local MeleeChaseHandler = {}

-- Attack tracking
local attackUpdateConnection = nil

-- Configuration specific to melee enemies
local ATTACK_DURATION = 0.2 -- Duration of moving shapecast attack
local MELEE_CONFIG = {
    STOPPING_ZONE_MULTIPLIER = 0.8,    -- Stop at 80% of attack range
    SLOW_ZONE_MULTIPLIER = 2.0,        -- Slow down at 2x attack range
    PERSISTENCE_MULTIPLIER = 1.5,      -- Chase until 1.5x detection range
    MOVE_THRESHOLD_MULTIPLIER = 0.5,   -- More responsive movement (50% of normal threshold)
    ATTACK_WHILE_MOVING = true,        -- Can attack while moving
}

-- Handle melee enemy chase behavior
function MeleeChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, distance, currentTime, entityLastPlayerPositions, CONFIG)
    -- Check if closestPlayer is dead, if so, stop targeting
    if closestPlayer and closestPlayer.player then
        local CollectionService = game:GetService("CollectionService")
        print("[MeleeChaseHandler] (handleChase) Checking Dead tag for player:", closestPlayer.player.Name, CollectionService:HasTag(closestPlayer.player, "Dead"))
        if CollectionService:HasTag(closestPlayer.player, "Dead") then
            return "idle" -- Stop targeting dead players
        end
    end
    -- Get enemy-specific ranges
    local attackRange = enemyAI.attackRange or CONFIG.ATTACK_RANGE
    local detectionRange = enemyAI.detectionRange or CONFIG.DETECTION_RANGE
    
    -- Ensure Combat component exists when chasing
    local combat = EntityManager.getComponent(entityId, "Combat")
    if not combat then
        -- Try to get config from EnemyType or EnemyAI
        local enemyType = EntityManager.getComponent(entityId, "EnemyType")
        local damage = (enemyType and enemyType.config and enemyType.config.damage) or 10
        local attackCooldown = (enemyType and enemyType.config and enemyType.config.attackSpeed) and (1 / enemyType.config.attackSpeed) or 1
        local attackRangeVal = (enemyType and enemyType.config and enemyType.config.attackRange) or attackRange or 5
        EntityManager.addComponent(entityId, "Combat", Components.create("Combat", {
            damage = damage,
            attackCooldown = attackCooldown,
            attackRange = attackRangeVal
        }))
        -- Optionally, debug print
        -- print("[Debug] Created Combat component for entity", entityId, "on chase start")
    end
    
    -- Check if we should give up chase (melee enemies are more persistent)
    if not closestPlayer then
        return "idle"  -- Lost target
    end
    
    local maxChaseDistance = detectionRange * MELEE_CONFIG.PERSISTENCE_MULTIPLIER
    if distance > maxChaseDistance then
        return "idle"  -- Target too far, give up
    end
    
    -- Check chase timeout
    local chaseTime = currentTime - (enemyAI.stateStartTime or currentTime)
    if chaseTime >= CONFIG.CHASE_TIMEOUT then
        return "idle"  -- Timeout
    end
    
    -- === ATTACK LOGIC (continuous during chase) ===
    local inAttackRange = distance <= attackRange
    if inAttackRange then
        -- Handle shapecast-based attacking while in range
        MeleeChaseHandler._handleContinuousAttack(entityId, closestPlayer, currentTime)
    end
    
    -- === MOVEMENT LOGIC (independent of attacking) ===
    -- Zone-based movement logic for smooth approach
    local STOPPING_ZONE = attackRange * MELEE_CONFIG.STOPPING_ZONE_MULTIPLIER
    local SLOW_ZONE = attackRange * MELEE_CONFIG.SLOW_ZONE_MULTIPLIER
    
    -- Continuous player tracking (melee enemies are more responsive)
    local lastKnownPlayerPos = entityLastPlayerPositions[entityId]
    local currentPlayerPos = closestPlayer.position
    local shouldUpdateMoveTo = false

    if not lastKnownPlayerPos then
        shouldUpdateMoveTo = true
    else
        local playerMovedDistance = (currentPlayerPos - lastKnownPlayerPos).Magnitude
        local moveThreshold = CONFIG.PLAYER_MOVE_THRESHOLD * MELEE_CONFIG.MOVE_THRESHOLD_MULTIPLIER
        if playerMovedDistance > moveThreshold then
            shouldUpdateMoveTo = true
        end
    end

    -- Basic stuck detection
    local lastMoveToTime = enemyAI.lastMoveToTime or 0
    if not shouldUpdateMoveTo and (currentTime - lastMoveToTime) > CONFIG.STUCK_TIMEOUT then
        shouldUpdateMoveTo = true
    end

    -- Movement behavior (happens regardless of attack state)
    if distance <= STOPPING_ZONE then
        -- Close enough - don't move closer, just attack if in range
        if inAttackRange then
            print("⚔️ Melee enemy", entityId, "in optimal attack position")
        end
    elseif shouldUpdateMoveTo then
        -- Move toward player with zone-based speed adjustment
        MeleeChaseHandler._moveToPlayerWithZones(entityId, closestPlayer, distance, SLOW_ZONE, enemyAI, CONFIG)
        entityLastPlayerPositions[entityId] = currentPlayerPos
        enemyAI.lastMoveToTime = currentTime
        
        if inAttackRange then
            print("🏃‍♂️⚔️ Melee enemy", entityId, "attacking while moving toward player")
        end
    end
    
    return "chase"  -- Continue chasing
end

-- Handle continuous attacking during chase with shapecast
function MeleeChaseHandler._handleContinuousAttack(entityId, closestPlayer, currentTime)
    local combat = EntityManager.getComponent(entityId, "Combat")
    if not combat then
        -- Create fallback combat component silently (no warning)
        local enemyAI = EntityManager.getComponent(entityId, "EnemyAI")
        local enemyType = EntityManager.getComponent(entityId, "EnemyType")
        local attackRange = (enemyType and enemyType.config and enemyType.config.attackRange) or (enemyAI and enemyAI.attackRange) or 5
        local damage = (enemyType and enemyType.config and enemyType.config.damage) or 10
        local attackCooldown = (enemyType and enemyType.config and enemyType.config.attackSpeed) and (1 / enemyType.config.attackSpeed) or 1
        EntityManager.addComponent(entityId, "Combat", Components.create("Combat", {
            target = closestPlayer.entity,
            damage = damage,
            lastAttackTime = currentTime,
            attackRange = attackRange,
            attackCooldown = attackCooldown
        }))
        -- Optionally, debug print
        -- print("[Debug] Silently created fallback Combat component for entity", entityId)
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
    
    -- Play attack animation
    MeleeChaseHandler._playAttackAnimationOverlay(entityId, model)
    
    -- Set up attack state for moving shapecast
    combat.isAttacking = true
    combat.attackStartTime = currentTime
    combat.attackTargetPlayer = closestPlayer.player
    
    -- Start the moving shapecast update loop if not already running
    MeleeChaseHandler._ensureAttackUpdateLoop()
    
    print("⚔️ Melee enemy", entityId, "started moving shapecast attack on", closestPlayer.player.Name)
end

-- Play attack animation overlay for melee attacks
function MeleeChaseHandler._playAttackAnimationOverlay(entityId, model)
    local animationSet = EntityManager.getComponent(entityId, "AnimationSet")
    if not animationSet or not model.humanoid then
        return
    end
    
    -- Play attack animation as overlay (higher priority than movement)
    if animationSet.attack and not animationSet.attack.IsPlaying then
        animationSet.attack.Priority = Enum.AnimationPriority.Action
        animationSet.attack:Play()
        print("⚔️ Playing melee attack animation overlay for entity", entityId)
    end
end

-- Move enemy toward player with zone-based speed adjustment
function MeleeChaseHandler._moveToPlayerWithZones(entityId, playerData, currentDistance, slowZoneDistance, enemyAI, CONFIG)
    local model = EntityManager.getComponent(entityId, "Model")
    if not model or not model.humanoid or not model.humanoid.Parent then
        return
    end
    
    if playerData.player.Character and playerData.player.Character:FindFirstChild("HumanoidRootPart") then
        local humanoid = model.humanoid
        local targetPosition = playerData.player.Character.HumanoidRootPart.Position
        
        -- Zone-based speed adjustment for smoother movement
        local baseSpeed = enemyAI.speed or humanoid.WalkSpeed or 16
        local newSpeed = baseSpeed
        
        if currentDistance <= slowZoneDistance then
            -- In slow zone: reduce speed for smoother approach
            local slowFactor = math.max(0.4, currentDistance / slowZoneDistance)
            newSpeed = baseSpeed * slowFactor
            print("🐌 Melee entity", entityId, "in slow zone - speed:", math.floor(newSpeed))
        end
        
        -- Apply speed adjustment
        humanoid.WalkSpeed = newSpeed
        
        -- Move to target
        humanoid:MoveTo(targetPosition)
        
        print("🎯 Melee entity", entityId, "moving to player at speed", newSpeed, "distance:", math.floor(currentDistance))
    end
end

-- Deal damage to player from shapecast
function MeleeChaseHandler._dealShapecastDamage(entityId, player, damage)
    if not player.Character or not player.Character:FindFirstChild("Humanoid") then
        return
    end
    -- Prevent damage to dead players
    local CollectionService = game:GetService("CollectionService")
    print("[MeleeChaseHandler] Checking Dead tag for player:", player.Name, CollectionService:HasTag(player, "Dead"))
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
    
    attackUpdateConnection = RunService.Heartbeat:Connect(function()
        MeleeChaseHandler._updateActiveAttacks()
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
    
    -- Perform moving shapecast at current enemy position
    local enemyPosition = model.part.Position
    local enemyLookVector = model.part.CFrame.LookVector
    
    -- Shapecast configuration
    local shapecastDistance = 1.0  -- 1 stud in front (closer for more precise combat)
    local shapecastSize = Vector3.new(1.5, 1.5, 1.5)  -- 1.5x1.5x1.5 detection box
    
    -- Calculate current shapecast center position (moves with enemy)
    local shapecastCenter = enemyPosition + enemyLookVector * shapecastDistance
    
    -- Perform the shapecast using GetPartBoundsInBox
    -- Create CFrame oriented to face the same direction as the enemy
    local enemyCFrame = model.part.CFrame
    local orientedCFrame = CFrame.new(shapecastCenter, shapecastCenter + enemyCFrame.LookVector)
    local detectedParts = workspace:GetPartBoundsInBox(orientedCFrame, shapecastSize)
    
    -- Check if we hit the target player
    local targetPlayer = combat.attackTargetPlayer
    if targetPlayer and targetPlayer.Character then
        for _, part in ipairs(detectedParts) do
            -- Check if this part belongs to the target player
            if part:IsDescendantOf(targetPlayer.Character) then
                -- Hit! Deal damage and end attack
                MeleeChaseHandler._dealShapecastDamage(entityId, targetPlayer, combat.damage or 10)
                MeleeChaseHandler._endAttack(entityId, combat, true, shapecastCenter, shapecastSize)
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
            local missCenter = enemyPosition + enemyLookVector * 1.0  -- Match the shapecast distance
            MeleeChaseHandler._createAttackVisual(missCenter, Vector3.new(1.5, 1.5, 1.5), false)
        end
        print("⚔️ Melee enemy", entityId, "MISSED with moving shapecast")
    end
    
    -- Update the combat component
    EntityManager.addComponent(entityId, "Combat", combat)
end

return MeleeChaseHandler 