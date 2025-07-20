-- RangedChaseHandler.luau
-- Handles chase behavior specifically for ranged enemies
-- Ranged enemies use tactical positioning, aiming, and projectile bursts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
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
    error("RangedChaseHandler: Could not find EnemyComponents ModuleScript")
end

local EntityManager = require(ReplicatedStorage.Shared.EntityManager)

local RangedChaseHandler = {}

-- Configuration specific to ranged enemies
local RANGED_CONFIG = {
    BURST_SIZE = 3,
    SHOT_INTERVAL = 0.25,           -- 0.25 seconds between shots in burst
    AIM_TIME = 0.2,                 -- 0.2 seconds to aim and capture target
    POST_BURST_PAUSE = 0.5,         -- pause after burst before next action
    REPOSITION_THRESHOLD = 8,        -- studs player must move to trigger reposition
    OPTIMAL_DISTANCE = 25,           -- preferred shooting distance
    
    -- Projectile settings
    PROJECTILE_SPEED = 70,           -- studs per second
    PROJECTILE_DAMAGE = 15,          -- damage per projectile (45 total per burst)
    PROJECTILE_SIZE = Vector3.new(0.2, 0.2, 0.2),
    PROJECTILE_COLOR = Color3.fromRGB(255, 100, 50),  -- Orange-red
    PROJECTILE_LIFETIME = 3,         -- seconds before cleanup
}

-- Store ranged enemy state data
local rangedEnemyStates = {}  -- {[entityId] = {phase, burstCount, lastShotTime, targetedPlayerPosition, aimStartTime, activeProjectiles}}

-- Handle ranged enemy chase behavior
function RangedChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, distance, currentTime, entityLastPlayerPositions, CONFIG)
    -- Get or create ranged state for this entity
    local rangedState = rangedEnemyStates[entityId]
    if not rangedState then
        rangedState = {
            phase = "positioning",
            burstCount = 0,
            lastShotTime = 0,
            targetedPlayerPosition = nil,
            aimStartTime = 0,
            activeProjectiles = {}
        }
        rangedEnemyStates[entityId] = rangedState
    end
    
    -- Get enemy-specific ranges
    local attackRange = enemyAI.attackRange or CONFIG.ATTACK_RANGE
    local detectionRange = enemyAI.detectionRange or CONFIG.DETECTION_RANGE
    
    -- Check if we should give up chase
    if not closestPlayer then
        rangedEnemyStates[entityId] = nil  -- Clean up state
        return "idle"
    end
    
    if distance > detectionRange then
        rangedEnemyStates[entityId] = nil  -- Clean up state
        return "idle"
    end
    
    -- Check chase timeout
    local chaseTime = currentTime - (enemyAI.stateStartTime or currentTime)
    if chaseTime >= CONFIG.CHASE_TIMEOUT then
        rangedEnemyStates[entityId] = nil  -- Clean up state
        return "idle"
    end
    
    -- Handle different phases of ranged combat
    if rangedState.phase == "positioning" then
        return RangedChaseHandler._handlePositioning(entityId, enemyAI, model, closestPlayer, distance, currentTime, rangedState, entityLastPlayerPositions, CONFIG)
    elseif rangedState.phase == "aiming" then
        return RangedChaseHandler._handleAiming(entityId, enemyAI, model, closestPlayer, distance, currentTime, rangedState)
    elseif rangedState.phase == "shooting" then
        return RangedChaseHandler._handleShooting(entityId, enemyAI, model, closestPlayer, distance, currentTime, rangedState)
    elseif rangedState.phase == "repositioning" then
        return RangedChaseHandler._handleRepositioning(entityId, enemyAI, model, closestPlayer, distance, currentTime, rangedState, entityLastPlayerPositions, CONFIG)
    end
    
    return "chase"
end

-- Phase 1: Positioning - Move closer if player is out of range
function RangedChaseHandler._handlePositioning(entityId, enemyAI, model, closestPlayer, distance, currentTime, rangedState, entityLastPlayerPositions, CONFIG)
    local attackRange = enemyAI.attackRange or CONFIG.ATTACK_RANGE
    
    -- Simple logic: if player is within attack range, start shooting
    if distance <= attackRange then
        -- Player is in range - transition to aiming
        rangedState.phase = "aiming"
        rangedState.aimStartTime = currentTime
        rangedState.targetedPlayerPosition = closestPlayer.position  -- Capture target position
        print("🎯 Ranged enemy", entityId, "player in range - transitioning to aiming phase")
        return "chase"
    end
    
    -- Player is out of range - move closer
    local shouldUpdateMoveTo = false
    
    -- Calculate if we need to move
    local lastKnownPlayerPos = entityLastPlayerPositions[entityId]
    local currentPlayerPos = closestPlayer.position
    
    if not lastKnownPlayerPos then
        shouldUpdateMoveTo = true
    else
        local playerMovedDistance = (currentPlayerPos - lastKnownPlayerPos).Magnitude
        if playerMovedDistance > RANGED_CONFIG.REPOSITION_THRESHOLD then
            shouldUpdateMoveTo = true
        end
    end
    
    -- Move toward player (but only when they're out of range)
    if shouldUpdateMoveTo then
        RangedChaseHandler._moveToPlayer(entityId, closestPlayer, enemyAI)
        entityLastPlayerPositions[entityId] = currentPlayerPos
        enemyAI.lastMoveToTime = currentTime
        print("📍 Ranged enemy", entityId, "moving closer - player out of range")
    end
    
    return "chase"
end

-- Phase 2: Aiming - Capture target position and prepare to shoot
function RangedChaseHandler._handleAiming(entityId, enemyAI, model, closestPlayer, distance, currentTime, rangedState)
    local aimDuration = currentTime - rangedState.aimStartTime
    
    if aimDuration >= RANGED_CONFIG.AIM_TIME then
        -- Aiming complete - transition to shooting
        rangedState.phase = "shooting"
        rangedState.burstCount = 0
        rangedState.lastShotTime = currentTime - RANGED_CONFIG.SHOT_INTERVAL  -- Allow immediate first shot
        print("🔫 Ranged enemy", entityId, "aiming complete - starting burst")
        return "chase"
    end
    
    -- Continue aiming - face the target position
    if model.humanoid and rangedState.targetedPlayerPosition then
        local currentPos = model.part.Position
        local targetPos = rangedState.targetedPlayerPosition
        local direction = (targetPos - currentPos).Unit
        model.humanoid:MoveTo(currentPos + direction * 0.1)  -- Face target without moving
    end
    
    print("🎯 Ranged enemy", entityId, "aiming... (" .. math.floor((RANGED_CONFIG.AIM_TIME - aimDuration) * 10) / 10 .. "s remaining)")
    return "chase"
end

-- Phase 3: Shooting - Fire projectile burst at captured position
function RangedChaseHandler._handleShooting(entityId, enemyAI, model, closestPlayer, distance, currentTime, rangedState)
    -- Check if we should fire next shot
    local timeSinceLastShot = currentTime - rangedState.lastShotTime
    
    if timeSinceLastShot >= RANGED_CONFIG.SHOT_INTERVAL and rangedState.burstCount < RANGED_CONFIG.BURST_SIZE then
        -- Fire projectile
        RangedChaseHandler._fireProjectile(entityId, model, rangedState.targetedPlayerPosition)
        rangedState.burstCount = rangedState.burstCount + 1
        rangedState.lastShotTime = currentTime
        print("💥 Ranged enemy", entityId, "fired shot", rangedState.burstCount, "of", RANGED_CONFIG.BURST_SIZE)
    end
    
    -- Check if burst is complete
    if rangedState.burstCount >= RANGED_CONFIG.BURST_SIZE then
        -- Burst complete - transition to repositioning
        rangedState.phase = "repositioning"
        rangedState.repositionStartTime = currentTime
        print("✅ Ranged enemy", entityId, "burst complete - repositioning")
    end
    
    return "chase"
end

-- Phase 4: Repositioning - Brief pause then decide next action
function RangedChaseHandler._handleRepositioning(entityId, enemyAI, model, closestPlayer, distance, currentTime, rangedState, entityLastPlayerPositions, CONFIG)
    local pauseDuration = currentTime - (rangedState.repositionStartTime or currentTime)
    local attackRange = enemyAI.attackRange or CONFIG.ATTACK_RANGE
    
    if pauseDuration >= RANGED_CONFIG.POST_BURST_PAUSE then
        -- Simple logic: if player is in range, shoot again; if not, move closer
        if distance <= attackRange then
            -- Player still in range - start another burst cycle
            rangedState.phase = "aiming"
            rangedState.aimStartTime = currentTime
            rangedState.targetedPlayerPosition = closestPlayer.position
            print("🔄 Ranged enemy", entityId, "player still in range - starting new burst cycle")
        else
            -- Player out of range - go back to positioning to move closer
            rangedState.phase = "positioning"
            print("🔄 Ranged enemy", entityId, "player out of range - repositioning to get closer")
        end
    end
    
    return "chase"
end

-- Move directly toward player (only when out of range)
function RangedChaseHandler._moveToPlayer(entityId, playerData, enemyAI)
    local model = EntityManager.getComponent(entityId, "Model")
    if not model or not model.humanoid or not model.humanoid.Parent then
        return
    end
    
    if playerData.player.Character and playerData.player.Character:FindFirstChild("HumanoidRootPart") then
        local humanoid = model.humanoid
        local playerPosition = playerData.player.Character.HumanoidRootPart.Position
        
        -- Move directly toward player
        local baseSpeed = enemyAI.speed or 16
        humanoid.WalkSpeed = baseSpeed * 0.8  -- Slightly slower for positioning
        
        humanoid:MoveTo(playerPosition)
    end
end

-- Fire a projectile at the target position
function RangedChaseHandler._fireProjectile(entityId, model, targetPosition)
    if not model.part or not targetPosition then
        return
    end
    
    local startPosition = model.part.Position + Vector3.new(0, 2, 0)  -- Shoot from slightly above
    
    -- Create projectile
    local projectile = Instance.new("Part")
    projectile.Name = "RangedProjectile"
    projectile.Size = RANGED_CONFIG.PROJECTILE_SIZE
    projectile.Color = RANGED_CONFIG.PROJECTILE_COLOR
    projectile.Material = Enum.Material.Neon
    projectile.Shape = Enum.PartType.Ball
    projectile.CanCollide = false
    projectile.Anchored = false
    projectile.Position = startPosition
    
    -- Add trail effect
    local trail = Instance.new("Trail")
    trail.Attachment0 = Instance.new("Attachment")
    trail.Attachment1 = Instance.new("Attachment")
    trail.Attachment0.Parent = projectile
    trail.Attachment1.Parent = projectile
    trail.Attachment1.Position = Vector3.new(0, 0, -0.5)  -- Behind the projectile
    trail.Color = ColorSequence.new(RANGED_CONFIG.PROJECTILE_COLOR)
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1)
    })
    trail.Lifetime = 0.5
    trail.MinLength = 0
    trail.Parent = projectile
    
    projectile.Parent = workspace
    
    -- Calculate movement
    local direction = (targetPosition - startPosition).Unit
    local distance = (targetPosition - startPosition).Magnitude
    local travelTime = distance / RANGED_CONFIG.PROJECTILE_SPEED
    
    -- Add BodyVelocity for movement
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
    bodyVelocity.Velocity = direction * RANGED_CONFIG.PROJECTILE_SPEED
    bodyVelocity.Parent = projectile
    
    -- Handle collision detection
    local connection
    connection = projectile.Touched:Connect(function(hit)
        local character = hit.Parent
        local humanoid = character:FindFirstChild("Humanoid")
        
        if humanoid and Players:GetPlayerFromCharacter(character) then
            -- Hit a player
            print("💥 Projectile hit player:", character.Name)
            
            -- Deal damage through combat system (create temporary combat event)
            -- This could be enhanced to integrate with your damage system
            
            -- Clean up
            connection:Disconnect()
            projectile:Destroy()
        end
    end)
    
    -- Auto cleanup after lifetime
    Debris:AddItem(projectile, RANGED_CONFIG.PROJECTILE_LIFETIME)
    
    print("🚀 Fired projectile from", startPosition, "to", targetPosition, "travel time:", math.floor(travelTime * 100) / 100, "s")
end

-- Clean up ranged enemy state when entity is destroyed
function RangedChaseHandler.cleanupEntity(entityId)
    rangedEnemyStates[entityId] = nil
end

return RangedChaseHandler 