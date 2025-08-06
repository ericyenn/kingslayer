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

local RangedChaseHandler = {}

-- Default configuration for ranged enemies (fallback values)
local DEFAULT_RANGED_CONFIG = {
    -- Projectile settings
    PROJECTILE_SPEED = 70,           -- studs per second
    PROJECTILE_DAMAGE = 15,          -- damage per projectile
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
    
    -- Simple ranged behavior - move to random position in zone and shoot when in range
    local attackRange = 20 -- Default attack range
    
    -- Calculate distance to target for attack range check only
    local targetPosition = bestTarget.position
    local distance = (currentPosition - targetPosition).Magnitude
    
    if distance <= attackRange then
        -- In range - stop and shoot
        SimpleMovementSystem.clearPosition(entityId)
        
        -- Play aim animation before shooting
        local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
        if enemyFolder then
            enemyFolder:SetAttribute("AimAnimation", 135648359564667)
            print("🎯 Ranged enemy", entityId, "playing aim animation before shooting")
        end
        
        RangedChaseHandler._fireProjectile(entityId, bestTarget, config, enemyAI.state)
    else
        -- Out of range - move to random position in zone
        local randomPosition = SimpleMovementSystem.getRandomPositionInZone(entityId)
        if randomPosition then
            SimpleMovementSystem.setPosition(entityId, randomPosition)
        end
    end
end

-- Fire a projectile at the target
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
    
    local targetPosition = bestTarget.position
    
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
            -- Hit a target (player or NPC)
            local humanoid = hit.Parent.Humanoid
            if humanoid and humanoid.Health > 0 then
                -- Apply damage using DamageSystem for consistency
                local DamageSystem = require(script.Parent.Parent.Systems.DamageSystem)
                DamageSystem:ApplyDamage(humanoid, config.PROJECTILE_DAMAGE, nil, "EnemyRangedAttack")
                
                local targetName = hit.Parent.Name
                print("💥 Ranged projectile hit", targetName, "for", config.PROJECTILE_DAMAGE, "damage")
            end
        end
        
        -- Clean up projectile
        projectile:Destroy()
        connection:Disconnect()
    end)
    
    -- Clean up projectile after lifetime
    Debris:AddItem(projectile, config.PROJECTILE_LIFETIME)
    
    local targetName = bestTarget.target.Name
    print("🎯 Ranged enemy", entityId, "fired projectile toward", targetName)
end

return RangedChaseHandler 