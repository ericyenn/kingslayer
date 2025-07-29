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

-- Import rotation utility
local EnemyRotationUtility = require(script.Parent.EnemyRotationUtility)

-- Import DamageSystem for applying damage
local DamageSystem = require(script.Parent.Parent.Systems.DamageSystem)

local RangedChaseHandler = {}

-- Default configuration for ranged enemies (fallback values)
local DEFAULT_RANGED_CONFIG = {
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
local rangedEnemyStates = {}  -- {[entityId] = {phase, burstCount, lastShotTime, targetedPlayerPosition, aimStartTime, activeProjectiles, firingAnimationTrack}}

-- Helper function to get enemy-specific ranged configuration
local function getEnemyRangedConfig(entityId)
    local enemyType = EntityManager.getComponent(entityId, "EnemyType")
    if not enemyType or not enemyType.config then
        return DEFAULT_RANGED_CONFIG
    end
    
    local config = enemyType.config
    return {
        BURST_SIZE = config.burstSize or DEFAULT_RANGED_CONFIG.BURST_SIZE,
        SHOT_INTERVAL = config.shotInterval or DEFAULT_RANGED_CONFIG.SHOT_INTERVAL,
        AIM_TIME = config.aimTime or DEFAULT_RANGED_CONFIG.AIM_TIME,
        POST_BURST_PAUSE = config.postBurstPause or DEFAULT_RANGED_CONFIG.POST_BURST_PAUSE,
        REPOSITION_THRESHOLD = config.repositionThreshold or DEFAULT_RANGED_CONFIG.REPOSITION_THRESHOLD,
        OPTIMAL_DISTANCE = config.optimalDistance or DEFAULT_RANGED_CONFIG.OPTIMAL_DISTANCE,
        
        -- Projectile settings
        PROJECTILE_SPEED = config.projectileSpeed or DEFAULT_RANGED_CONFIG.PROJECTILE_SPEED,
        PROJECTILE_DAMAGE = config.damage or DEFAULT_RANGED_CONFIG.PROJECTILE_DAMAGE,
        PROJECTILE_SIZE = config.projectileSize or DEFAULT_RANGED_CONFIG.PROJECTILE_SIZE,
        PROJECTILE_COLOR = config.projectileColor or DEFAULT_RANGED_CONFIG.PROJECTILE_COLOR,
        PROJECTILE_LIFETIME = config.projectileLifetime or DEFAULT_RANGED_CONFIG.PROJECTILE_LIFETIME,
        PROJECTILE_TYPE = config.projectileType or "default",
    }
end

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
        local enemyConfig = getEnemyRangedConfig(entityId)
        if playerMovedDistance > enemyConfig.REPOSITION_THRESHOLD then
            shouldUpdateMoveTo = true
        end
    end
    
    -- Move toward player (but only when they're out of range)
    if shouldUpdateMoveTo then
        -- Rotate to face player while moving
        EnemyRotationUtility.rotateForChase(entityId, closestPlayer)
        
        RangedChaseHandler._moveToPlayer(entityId, closestPlayer, enemyAI)
        entityLastPlayerPositions[entityId] = currentPlayerPos
        enemyAI.lastMoveToTime = currentTime
        print("📍 Ranged enemy", entityId, "moving closer - player out of range")
    end
    
    return "chase"
end

-- Phase 2: Aiming - Capture target position and prepare to shoot
function RangedChaseHandler._handleAiming(entityId, enemyAI, model, closestPlayer, distance, currentTime, rangedState)
    local enemyConfig = getEnemyRangedConfig(entityId)
    local aimDuration = currentTime - rangedState.aimStartTime
    
    -- Play aiming animation when starting to aim (only once)
    -- This triggers when ranged enemies transition from positioning to aiming phase
    if aimDuration < 0.1 then  -- Just started aiming
        local ModelCreationSystem = require(script.Parent.ModelCreationSystem)
        ModelCreationSystem.playAnimationForEntity(entityId, "aim")
        print("🎯 Ranged enemy", entityId, "started aiming animation")
    end
    
    if aimDuration >= enemyConfig.AIM_TIME then
        -- Aiming complete - transition to shooting
        rangedState.phase = "shooting"
        rangedState.burstCount = 0
        rangedState.lastShotTime = currentTime - enemyConfig.SHOT_INTERVAL  -- Allow immediate first shot
        print("🔫 Ranged enemy", entityId, "aiming complete - starting burst")
        return "chase"
    end
    
    -- Stop movement during aiming - just face the target
    if model.humanoid then
        -- Stop any current movement
        model.humanoid:MoveTo(model.part.Position)
    end
    
    -- Rotate to face player during aiming
    EnemyRotationUtility.rotateForAttackInstant(entityId, closestPlayer)
    
    print("🎯 Ranged enemy", entityId, "aiming... (" .. math.floor((enemyConfig.AIM_TIME - aimDuration) * 10) / 10 .. "s remaining)")
    return "chase"
end

-- Phase 3: Shooting - Fire projectile burst at captured position
function RangedChaseHandler._handleShooting(entityId, enemyAI, model, closestPlayer, distance, currentTime, rangedState)
    local enemyConfig = getEnemyRangedConfig(entityId)
    
    -- Stop movement during shooting
    if model.humanoid then
        model.humanoid:MoveTo(model.part.Position)
    end
    
    -- Rotate to face player during shooting
    EnemyRotationUtility.rotateForAttackInstant(entityId, closestPlayer)
    
    -- Get the animation track from the aiming phase and pause it at the last frame
    if rangedState.burstCount == 0 and not rangedState.firingAnimationTrack then
        local animationSet = EntityManager.getComponent(entityId, "AnimationSet")
        if animationSet and animationSet.aim then
            rangedState.firingAnimationTrack = animationSet.aim
            
            -- Pause the animation at the last frame immediately when shooting starts
            rangedState.firingAnimationTrack:AdjustSpeed(0)
            print("🎭 Ranged enemy", entityId, "paused aiming animation at last frame for firing")
        end
    end
    
    -- Check if we should fire next shot
    local timeSinceLastShot = currentTime - rangedState.lastShotTime
    
    if timeSinceLastShot >= enemyConfig.SHOT_INTERVAL and rangedState.burstCount < enemyConfig.BURST_SIZE then
        -- Fire projectile
        RangedChaseHandler._fireProjectile(entityId, model, rangedState.targetedPlayerPosition)
        rangedState.burstCount = rangedState.burstCount + 1
        rangedState.lastShotTime = currentTime
        print("💥 Ranged enemy", entityId, "fired shot", rangedState.burstCount, "of", enemyConfig.BURST_SIZE)
    end
    
    -- Check if burst is complete
    if rangedState.burstCount >= enemyConfig.BURST_SIZE then
        -- Resume the animation after burst is complete
        if rangedState.firingAnimationTrack then
            -- Resume normal speed immediately
            rangedState.firingAnimationTrack:AdjustSpeed(1)
            print("🎭 Ranged enemy", entityId, "resumed animation after burst")
        end
        
        -- Burst complete - transition to repositioning
        rangedState.phase = "repositioning"
        rangedState.repositionStartTime = currentTime
        rangedState.firingAnimationTrack = nil  -- Clear the track reference
        print("✅ Ranged enemy", entityId, "burst complete - repositioning")
    end
    
    return "chase"
end

-- Phase 4: Repositioning - Brief pause then decide next action
function RangedChaseHandler._handleRepositioning(entityId, enemyAI, model, closestPlayer, distance, currentTime, rangedState, entityLastPlayerPositions, CONFIG)
    local enemyConfig = getEnemyRangedConfig(entityId)
    local pauseDuration = currentTime - (rangedState.repositionStartTime or currentTime)
    local attackRange = enemyAI.attackRange or CONFIG.ATTACK_RANGE
    
    -- Stop movement during repositioning pause
    if model.humanoid then
        model.humanoid:MoveTo(model.part.Position)
    end
    
    if pauseDuration >= enemyConfig.POST_BURST_PAUSE then
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
    
    local enemyConfig = getEnemyRangedConfig(entityId)
    
    -- Find the weapon in the enemy's right hand
    local startPosition = model.part.Position + Vector3.new(0, 2, 0)  -- Default fallback
    
    if model.model then
        -- First, try to find the Gun model directly in the enemy model
        local gun = model.model:FindFirstChild("Gun")
        if gun then
            -- Gun is a Model, so we need to find the "Tip" part first, then fallback to other parts
            local tip = gun:FindFirstChild("Tip")
            if tip then
                startPosition = tip.Position
                print("🎯 Found Gun Tip at position:", tip.Position)
            else
                -- Look for other specific parts in the Gun model (like "Barrel" or "Muzzle")
                local barrel = gun:FindFirstChild("Barrel") or gun:FindFirstChild("Muzzle")
                if barrel then
                    startPosition = barrel.Position
                    print("🎯 Found Gun barrel at position:", barrel.Position)
                else
                    -- Fallback: use the PrimaryPart or first part in the Gun model
                    if gun.PrimaryPart then
                        startPosition = gun.PrimaryPart.Position
                        print("🎯 Found Gun model PrimaryPart at position:", gun.PrimaryPart.Position)
                    else
                        local firstPart = gun:FindFirstChildWhichIsA("BasePart")
                        if firstPart then
                            startPosition = firstPart.Position
                            print("🎯 Found Gun part at position:", firstPart.Position)
                        else
                            print("⚠️ Gun model found but no parts inside it")
                        end
                    end
                end
            end
        else
            -- Try to find the weapon in the right hand/arm
            local rightArm = model.model:FindFirstChild("Right Arm") or model.model:FindFirstChild("RightHand")
            if rightArm then
                -- Look for a weapon in the right arm
                local weapon = rightArm:FindFirstChild("Bow") or rightArm:FindFirstChild("Gun") or rightArm:FindFirstChild("Weapon")
                if weapon then
                    -- Use the weapon's position
                    startPosition = weapon.Position
                    print("🎯 Found weapon in right arm at position:", weapon.Position)
                else
                    -- Use the right arm's position
                    startPosition = rightArm.Position
                    print("🎯 Using right arm position:", rightArm.Position)
                end
            else
                -- Fallback: try to find any weapon in the model
                local weapon = model.model:FindFirstChild("Bow") or model.model:FindFirstChild("Gun") or model.model:FindFirstChild("Weapon")
                if weapon then
                    startPosition = weapon.Position
                    print("🎯 Found weapon in model at position:", weapon.Position)
                else
                    print("⚠️ No weapon found, using default position:", startPosition)
                end
            end
        end
    end
    
    -- Create projectile using ProjectileManager (server logic only)
    local ProjectileManager = require(script.Parent.Parent.ProjectileManager)
    local projectileConfig = {
        size = enemyConfig.PROJECTILE_SIZE,
        color = enemyConfig.PROJECTILE_COLOR,
        speed = enemyConfig.PROJECTILE_SPEED,
        damage = enemyConfig.PROJECTILE_DAMAGE,
        lifetime = enemyConfig.PROJECTILE_LIFETIME,
        projectileType = enemyConfig.PROJECTILE_TYPE
    }
    
    print("🎯 DEBUG: Creating projectile with config:", projectileConfig)
    print("🎯 DEBUG: ProjectileType:", enemyConfig.PROJECTILE_TYPE)
    
    ProjectileManager.createProjectile(startPosition, targetPosition, projectileConfig)
    
    print("🚀 Server fired projectile from", startPosition, "to", targetPosition)
end

-- Clean up ranged enemy state when entity is destroyed
function RangedChaseHandler.cleanupEntity(entityId)
    local rangedState = rangedEnemyStates[entityId]
    if rangedState and rangedState.firingAnimationTrack then
        -- Resume normal speed before cleanup
        rangedState.firingAnimationTrack:AdjustSpeed(1)
    end
    rangedEnemyStates[entityId] = nil
end

return RangedChaseHandler 