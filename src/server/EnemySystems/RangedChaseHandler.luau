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

-- Import SimpleMovementSystem for movement commands
local SimpleMovementSystem = require(script.Parent.SimpleMovementSystem)

-- Import DamageSystem for applying damage
local DamageSystem = require(script.Parent.Parent.Systems.DamageSystem)

-- Import ProjectileManager for proper projectile creation
local ProjectileManager = require(script.Parent.Parent.ProjectileManager)

local RangedChaseHandler = {}

-- Per-enemy attack cooldowns: {enemyId = lastAttackTime}
local enemyAttackCooldowns = {}

-- Default configuration for ranged enemies (fallback values)
local DEFAULT_RANGED_CONFIG = {
    -- Projectile settings
    PROJECTILE_SPEED = 70,           -- studs per second
    PROJECTILE_DAMAGE = 15,          -- damage per projectile
    PROJECTILE_SIZE = Vector3.new(0.2, 0.2, 0.2),
    PROJECTILE_COLOR = Color3.fromRGB(255, 100, 50),  -- Orange-red
    PROJECTILE_LIFETIME = 3,         -- seconds before cleanup
    ATTACK_RANGE = 40,               -- Increased to 40 studs
}

-- Clean up ranged chase handler for an entity
function RangedChaseHandler.cleanup(entityId)
    -- Clean up cooldown data
    enemyAttackCooldowns[entityId] = nil
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
        -- Attack settings
        ATTACK_COOLDOWN = config.attackCooldown or 1.0, -- Default 1 second cooldown
        ATTACK_SPEED = config.attackSpeed or 1.0, -- Default 1.0 attacks per second
        
        -- Projectile settings
        PROJECTILE_SPEED = config.projectileSpeed or DEFAULT_RANGED_CONFIG.PROJECTILE_SPEED,
        PROJECTILE_DAMAGE = config.damage or DEFAULT_RANGED_CONFIG.PROJECTILE_DAMAGE,
        PROJECTILE_SIZE = config.projectileSize or DEFAULT_RANGED_CONFIG.PROJECTILE_SIZE,
        PROJECTILE_COLOR = config.projectileColor or DEFAULT_RANGED_CONFIG.PROJECTILE_COLOR,
        PROJECTILE_LIFETIME = config.projectileLifetime or DEFAULT_RANGED_CONFIG.PROJECTILE_LIFETIME,
        PROJECTILE_TYPE = config.projectileType or "default",
        ATTACK_RANGE = config.attackRange or DEFAULT_RANGED_CONFIG.ATTACK_RANGE,
    }
end

-- Handle ranged enemy chase behavior (SERVICE - no state changes)
function RangedChaseHandler.handleChase(entityId, enemyAI, currentPosition, bestTarget, currentTime)
    -- Validate inputs - trust AISystem validation
    if not bestTarget or not bestTarget.target then
        return -- No valid target, but don't change state (AISystem handles that)
    end
    
    -- Get enemy configuration
    local config = getEnemyRangedConfig(entityId)
    local baseSpeed = enemyAI.speed or 16
    
    -- Use configured attack range
    local attackRange = config.ATTACK_RANGE
    
    -- Calculate distance to target for attack range check only
    local targetPosition = bestTarget.position
    local distance = (currentPosition - targetPosition).Magnitude
    
    if distance <= attackRange then
        -- In range - stop movement but keep position for shooting
        -- Don't clear position since we need it for projectile creation
        
        -- Check attack cooldown
        local currentTime = tick()
        local lastAttackTime = enemyAttackCooldowns[entityId]
        local attackCooldown = 1.0 / config.ATTACK_SPEED -- Convert attack speed to cooldown
        
        if lastAttackTime and (currentTime - lastAttackTime) < attackCooldown then
            -- Still on cooldown, don't attack
            return
        end
        
        -- Play aim animation before shooting
        local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
        if enemyFolder then
            enemyFolder:SetAttribute("AimAnimation", 135648359564667)
            print("🎯 Ranged enemy", entityId, "playing aim animation before shooting")
        end
        
        -- Fire projectile and update cooldown
        RangedChaseHandler._fireProjectile(entityId, bestTarget, config, enemyAI.state)
        enemyAttackCooldowns[entityId] = currentTime
    else
        -- Out of range - move to random position in zone
        local randomPosition = SimpleMovementSystem.getRandomPositionInZone(entityId)
        if randomPosition then
            SimpleMovementSystem.setPosition(entityId, randomPosition)
        end
    end
end

-- Fire a projectile at the target using ProjectileManager
function RangedChaseHandler._fireProjectile(entityId, bestTarget, config, state)
    -- Get current position from folder attribute
    local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
    if not enemyFolder then
        warn("RangedChaseHandler: No enemy folder found for entity", entityId)
        return
    end
    
    local startPosition = enemyFolder:GetAttribute("Position")
    if not startPosition then
        warn("RangedChaseHandler: No position attribute for entity", entityId)
        return
    end
    
    -- Try to find gun part for better projectile origin
    local gunPosition = startPosition -- Fallback to base position
    local enemyType = enemyFolder:GetAttribute("EnemyType")
    
    -- Look for gun part in the enemy model
    local gunPart = nil
    if enemyType then
        -- Try to find the gun part by name
        local gunNames = {"Gun", "Weapon", "Bow", "Rifle", "Pistol"}
        for _, gunName in ipairs(gunNames) do
            gunPart = enemyFolder:FindFirstChild(gunName)
            if gunPart then
                break
            end
        end
        
        -- If no gun found, try to find any part that might be a weapon
        if not gunPart then
            for _, child in ipairs(enemyFolder:GetChildren()) do
                if child:IsA("BasePart") and (child.Name:find("Gun") or child.Name:find("Weapon") or child.Name:find("Bow")) then
                    gunPart = child
                    break
                end
            end
        end
    end
    
    -- Use gun position if found, otherwise use base position
    if gunPart then
        gunPosition = gunPart.Position
        print("🎯 Ranged enemy", entityId, "firing from gun part:", gunPart.Name)
    else
        print("🎯 Ranged enemy", entityId, "no gun part found, using base position")
    end
    
    local targetPosition = bestTarget.position
    
    -- Create projectile using ProjectileManager
    local projectileConfig = {
        speed = config.PROJECTILE_SPEED,
        damage = config.PROJECTILE_DAMAGE,
        size = config.PROJECTILE_SIZE,
        color = config.PROJECTILE_COLOR,
        lifetime = config.PROJECTILE_LIFETIME,
        projectileType = config.PROJECTILE_TYPE,
    }
    
    ProjectileManager.createProjectile(gunPosition, targetPosition, projectileConfig)
    
    local targetName = bestTarget.target.Name
    print("🎯 Ranged enemy", entityId, "fired projectile toward", targetName)
end

return RangedChaseHandler 