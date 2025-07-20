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

local SpecialChaseHandler = {}

-- Configuration specific to special enemies
local SPECIAL_CONFIG = {
    PERSISTENCE_MULTIPLIER = 2.0,      -- Chase until 2x detection range (very persistent)
    MOVE_THRESHOLD_MULTIPLIER = 0.3,   -- Very responsive movement
    ABILITY_COOLDOWN = 5.0,            -- Seconds between special abilities
    TELEPORT_RANGE = 15,               -- Range for teleport abilities
}

-- Store special enemy state data for abilities
local specialEnemyStates = {}  -- {[entityId] = {lastAbilityTime, abilityPhase, ...}}

-- Handle special enemy chase behavior
function SpecialChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, distance, currentTime, entityLastPlayerPositions, CONFIG)
    -- Get or create special state for this entity
    local specialState = specialEnemyStates[entityId]
    if not specialState then
        specialState = {
            lastAbilityTime = 0,
            abilityPhase = "none"
        }
        specialEnemyStates[entityId] = specialState
    end
    
    -- Get enemy-specific ranges
    local attackRange = enemyAI.attackRange or CONFIG.ATTACK_RANGE
    local detectionRange = enemyAI.detectionRange or CONFIG.DETECTION_RANGE
    
    -- Check if we should give up chase (special enemies are very persistent)
    if not closestPlayer then
        specialEnemyStates[entityId] = nil  -- Clean up state
        return "idle"
    end
    
    local maxChaseDistance = detectionRange * SPECIAL_CONFIG.PERSISTENCE_MULTIPLIER
    if distance > maxChaseDistance then
        specialEnemyStates[entityId] = nil  -- Clean up state
        return "idle"
    end
    
    -- Check chase timeout
    local chaseTime = currentTime - (enemyAI.stateStartTime or currentTime)
    if chaseTime >= CONFIG.CHASE_TIMEOUT then
        specialEnemyStates[entityId] = nil  -- Clean up state
        return "idle"
    end
    
    -- === SPECIAL ABILITIES LOGIC ===
    SpecialChaseHandler._handleSpecialAbilities(entityId, enemyAI, model, closestPlayer, distance, currentTime, specialState)
    
    -- === ATTACK LOGIC (similar to melee but with special effects) ===
    local inAttackRange = distance <= attackRange
    if inAttackRange then
        SpecialChaseHandler._handleContinuousAttack(entityId, closestPlayer, currentTime)
        SpecialChaseHandler._playSpecialAttackAnimation(entityId, model)
    end
    
    -- === MOVEMENT LOGIC (enhanced movement) ===
    local STOPPING_ZONE = attackRange * 0.9  -- Get close for special attacks
    local SLOW_ZONE = attackRange * 2.5      -- Larger slow zone
    
    -- Very responsive player tracking
    local lastKnownPlayerPos = entityLastPlayerPositions[entityId]
    local currentPlayerPos = closestPlayer.position
    local shouldUpdateMoveTo = false

    if not lastKnownPlayerPos then
        shouldUpdateMoveTo = true
    else
        local playerMovedDistance = (currentPlayerPos - lastKnownPlayerPos).Magnitude
        local moveThreshold = CONFIG.PLAYER_MOVE_THRESHOLD * SPECIAL_CONFIG.MOVE_THRESHOLD_MULTIPLIER
        if playerMovedDistance > moveThreshold then
            shouldUpdateMoveTo = true
        end
    end

    -- Basic stuck detection
    local lastMoveToTime = enemyAI.lastMoveToTime or 0
    if not shouldUpdateMoveTo and (currentTime - lastMoveToTime) > CONFIG.STUCK_TIMEOUT then
        shouldUpdateMoveTo = true
    end

    -- Movement behavior
    if distance <= STOPPING_ZONE then
        -- Close enough for special attacks
        if inAttackRange then
            print("✨ Special enemy", entityId, "in optimal special attack position")
        end
    elseif shouldUpdateMoveTo then
        -- Enhanced movement for special enemies
        SpecialChaseHandler._moveToPlayerEnhanced(entityId, closestPlayer, distance, SLOW_ZONE, enemyAI, CONFIG)
        entityLastPlayerPositions[entityId] = currentPlayerPos
        enemyAI.lastMoveToTime = currentTime
        
        if inAttackRange then
            print("🏃‍♂️✨ Special enemy", entityId, "using special attacks while moving")
        end
    end
    
    return "chase"
end

-- Handle special abilities (placeholder for future expansion)
function SpecialChaseHandler._handleSpecialAbilities(entityId, enemyAI, model, closestPlayer, distance, currentTime, specialState)
    local timeSinceLastAbility = currentTime - specialState.lastAbilityTime
    
    if timeSinceLastAbility >= SPECIAL_CONFIG.ABILITY_COOLDOWN then
        -- Example special ability: teleport closer if far away
        if distance > 20 and distance < SPECIAL_CONFIG.TELEPORT_RANGE * 2 then
            SpecialChaseHandler._attemptTeleport(entityId, model, closestPlayer, specialState, currentTime)
        end
        
        -- Add more special abilities here in the future:
        -- - Shadow clone
        -- - Area damage
        -- - Temporary invincibility
        -- - Life drain
        -- - Summon minions
    end
end

-- Example special ability: teleport
function SpecialChaseHandler._attemptTeleport(entityId, model, closestPlayer, specialState, currentTime)
    if not model.part or not closestPlayer.player.Character then
        return
    end
    
    local playerPosition = closestPlayer.player.Character.HumanoidRootPart.Position
    local currentPosition = model.part.Position
    
    -- Calculate teleport position (closer to player but not too close)
    local direction = (playerPosition - currentPosition).Unit
    local teleportPosition = playerPosition - (direction * SPECIAL_CONFIG.TELEPORT_RANGE)
    
    -- Teleport with visual effect
    model.part.CFrame = CFrame.new(teleportPosition)
    
    -- Visual effect (simple for now)
    local effect = Instance.new("Explosion")
    effect.Position = currentPosition
    effect.BlastRadius = 5
    effect.BlastPressure = 0  -- No damage
    effect.Parent = workspace
    
    local effect2 = Instance.new("Explosion")
    effect2.Position = teleportPosition
    effect2.BlastRadius = 5
    effect2.BlastPressure = 0  -- No damage
    effect2.Parent = workspace
    
    specialState.lastAbilityTime = currentTime
    print("⚡ Special enemy", entityId, "teleported closer to player!")
end

-- Handle continuous attacking with special effects
function SpecialChaseHandler._handleContinuousAttack(entityId, closestPlayer, currentTime)
    local combat = EntityManager.getComponent(entityId, "Combat")
    if not combat then
        -- Create special combat component
        local enemyAI = EntityManager.getComponent(entityId, "EnemyAI")
        local attackRange = enemyAI and enemyAI.attackRange or 5
        
        warn("⚠️ No Combat component found for special entity", entityId, "- creating enhanced one")
        EntityManager.addComponent(entityId, "Combat", Components.create("Combat", {
            target = closestPlayer.entity,
            damage = 15,  -- Higher damage for special enemies
            lastAttackTime = currentTime,
            attackRange = attackRange
        }))
        print("✨ Created enhanced Combat component for special entity", entityId)
    else
        -- Update combat target if it changed
        if combat.target ~= closestPlayer.entity then
            combat.target = closestPlayer.entity
            EntityManager.addComponent(entityId, "Combat", combat)
            print("🎯 Updated Combat target for special entity", entityId, "to new target")
        end
    end
end

-- Play special attack animation
function SpecialChaseHandler._playSpecialAttackAnimation(entityId, model)
    local animationSet = EntityManager.getComponent(entityId, "AnimationSet")
    if not animationSet or not model.humanoid then
        return
    end
    
    -- Play attack animation with special effects
    if animationSet.attack and not animationSet.attack.IsPlaying then
        animationSet.attack.Priority = Enum.AnimationPriority.Action
        animationSet.attack:Play()
        print("✨ Playing special attack animation for entity", entityId)
    end
end

-- Enhanced movement for special enemies
function SpecialChaseHandler._moveToPlayerEnhanced(entityId, playerData, currentDistance, slowZoneDistance, enemyAI, CONFIG)
    local model = EntityManager.getComponent(entityId, "Model")
    if not model or not model.humanoid or not model.humanoid.Parent then
        return
    end
    
    if playerData.player.Character and playerData.player.Character:FindFirstChild("HumanoidRootPart") then
        local humanoid = model.humanoid
        local targetPosition = playerData.player.Character.HumanoidRootPart.Position
        
        -- Enhanced speed for special enemies
        local baseSpeed = enemyAI.speed or humanoid.WalkSpeed or 16
        local newSpeed = baseSpeed * 1.2  -- 20% faster than normal
        
        if currentDistance <= slowZoneDistance then
            -- Smooth approach but maintain higher speed
            local slowFactor = math.max(0.6, currentDistance / slowZoneDistance)  -- Don't slow down as much
            newSpeed = newSpeed * slowFactor
            print("✨ Special entity", entityId, "in enhanced approach - speed:", math.floor(newSpeed))
        end
        
        -- Apply enhanced speed
        humanoid.WalkSpeed = newSpeed
        
        -- Move to target
        humanoid:MoveTo(targetPosition)
        
        print("🎯 Special entity", entityId, "moving with enhanced speed", newSpeed, "distance:", math.floor(currentDistance))
    end
end

-- Clean up special enemy state when entity is destroyed
function SpecialChaseHandler.cleanupEntity(entityId)
    specialEnemyStates[entityId] = nil
end

return SpecialChaseHandler 