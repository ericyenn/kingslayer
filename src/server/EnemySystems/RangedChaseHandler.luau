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

-- Import MovementSystem for movement commands
local MovementSystem = require(script.Parent.MovementSystem)

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

-- Clean up ranged chase handler for an entity
function RangedChaseHandler.cleanup(entityId)
    -- No state to clean up - handlers are stateless
    print("🧹 RangedChaseHandler: Cleaned up entity", entityId)
end

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

-- Handle ranged enemy chase behavior (SERVICE - no state changes)
function RangedChaseHandler.handleChase(entityId, enemyAI, model, closestPlayer, currentTime)
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
    
    -- Check if we should give up chase
    if distance > detectionRange then
        return -- Target too far, but don't change state (AISystem handles that)
    end
    
    -- Check chase timeout
    local chaseTime = currentTime - (enemyAI.stateStartTime or currentTime)
    if chaseTime >= 10 then -- 10 second timeout
        return -- Timeout, but don't change state (AISystem handles that)
    end
    
    -- Simple ranged behavior - just move toward player and shoot when in range
    local attackRange = 5 -- Default attack range
    local config = getEnemyRangedConfig(entityId)
    local baseSpeed = enemyAI.speed or 16
    
    if distance <= attackRange then
        -- In range - stop and shoot
        MovementSystem.stopMovement(entityId)
        RangedChaseHandler._fireProjectile(entityId, closestPlayer, config)
    else
        -- Out of range - move toward player
        local playerPosition = closestPlayer.position
        local currentPosition = model.part.Position
        
        -- Calculate optimal tactical position
        local directionToPlayer = (playerPosition - currentPosition).Unit
        local optimalDistance = config.OPTIMAL_DISTANCE
        local tacticalPosition = playerPosition - (directionToPlayer * optimalDistance)
        
        MovementSystem.moveToTacticalPosition(entityId, tacticalPosition, baseSpeed * 0.9, "tactical")
    end
end

-- Phase-based functions removed - handlers are now stateless

-- Fire a projectile at the target
function RangedChaseHandler._fireProjectile(entityId, closestPlayer, config)
    local model = EntityManager.getComponent(entityId, "Model")
    if not model or not model.part then
        return
    end
    
    local startPosition = model.part.Position
    local targetPosition = closestPlayer.position
    
    -- Calculate direction to target
    local direction = (targetPosition - startPosition).Unit
    
    -- Create projectile
    local projectile = Instance.new("Part")
    projectile.Name = "RangedProjectile"
    projectile.Size = config.PROJECTILE_SIZE
    projectile.Position = startPosition
    projectile.Anchored = false
    projectile.CanCollide = false
    projectile.Color = config.PROJECTILE_COLOR
    projectile.Material = Enum.Material.Neon
    projectile.Parent = workspace
    
    -- Create body velocity for movement
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = direction * config.PROJECTILE_SPEED
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Parent = projectile
    
    -- Set up collision detection
    local connection
    connection = projectile.Touched:Connect(function(hit)
        if hit.Parent and hit.Parent:FindFirstChild("Humanoid") then
            -- Hit a player
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            if player then
                -- Apply damage
                local humanoid = hit.Parent.Humanoid
                humanoid:TakeDamage(config.PROJECTILE_DAMAGE)
                print("💥 Ranged projectile hit", player.Name, "for", config.PROJECTILE_DAMAGE, "damage")
            end
        end
        
        -- Clean up projectile
        projectile:Destroy()
        connection:Disconnect()
    end)
    
    -- Clean up projectile after lifetime
    Debris:AddItem(projectile, config.PROJECTILE_LIFETIME)
    
    print("🎯 Ranged enemy", entityId, "fired projectile toward", closestPlayer.player.Name)
end

return RangedChaseHandler 