-- SpecialChaseHandler.luau
-- Handles chase behavior specifically for special enemies
-- Special enemies have unique abilities like teleporting, stealth, etc.

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
    error("SpecialChaseHandler: Could not find EnemyComponents ModuleScript")
end

local EntityManager = require(ReplicatedStorage.Shared.EntityManager)

-- Import SimpleMovementSystem for movement commands
local SimpleMovementSystem = require(script.Parent.SimpleMovementSystem)

local SpecialChaseHandler = {}

-- Default configuration for special enemies
local DEFAULT_SPECIAL_CONFIG = {
    TELEPORT_RANGE = 25,
    TELEPORT_COOLDOWN = 10.0,
    STEALTH_DURATION = 3.0,
    STEALTH_COOLDOWN = 15.0,
    MANA_POOL = 100,
    MANA_REGEN_RATE = 5, -- per second
}

-- Clean up special chase handler for an entity
function SpecialChaseHandler.cleanup(entityId)
    -- No state to clean up - handlers are stateless
    print("🧹 SpecialChaseHandler: Cleaned up entity", entityId)
end

-- Helper function to get enemy-specific special configuration
local function getEnemySpecialConfig(entityId)
    local enemyType = EntityManager.getComponent(entityId, "EnemyType")
    if not enemyType or not enemyType.config then
        return DEFAULT_SPECIAL_CONFIG
    end
    
    local config = enemyType.config
    return {
        TELEPORT_RANGE = config.teleportRange or DEFAULT_SPECIAL_CONFIG.TELEPORT_RANGE,
        TELEPORT_COOLDOWN = config.teleportCooldown or DEFAULT_SPECIAL_CONFIG.TELEPORT_COOLDOWN,
        STEALTH_DURATION = config.stealthDuration or DEFAULT_SPECIAL_CONFIG.STEALTH_DURATION,
        STEALTH_COOLDOWN = config.stealthCooldown or DEFAULT_SPECIAL_CONFIG.STEALTH_COOLDOWN,
        MANA_POOL = config.manaPool or DEFAULT_SPECIAL_CONFIG.MANA_POOL,
        MANA_REGEN_RATE = config.manaRegenRate or DEFAULT_SPECIAL_CONFIG.MANA_REGEN_RATE,
        SPECIAL_ATTACKS = config.specialAttacks or {},
    }
end

-- Handle special enemy chase behavior (SERVICE - no state changes)
function SpecialChaseHandler.handleChase(entityId, enemyAI, currentPosition, bestTarget, currentTime)
    -- Validate inputs - trust AISystem validation
    if not bestTarget or not bestTarget.target then
        return -- No valid target, but don't change state (AISystem handles that)
    end
    
    -- Get enemy configuration
    local config = getEnemySpecialConfig(entityId)
    local baseSpeed = enemyAI.speed or 16
    
    -- Simple special behavior - move toward player and use abilities when in range
    local attackRange = 8 -- Default attack range for special enemies
    
    -- Calculate distance to target for attack range check only
    local targetPosition = bestTarget.position
    local distance = (currentPosition - targetPosition).Magnitude
    
    if distance <= attackRange then
        -- In range - stop and use special abilities
        SimpleMovementSystem.clearPosition(entityId)
        SpecialChaseHandler._useSpecialAbilities(entityId, bestTarget, config, currentTime)
    else
        -- Out of range - move toward target
        local targetPosition = bestTarget.position
        
        -- Set position to target position (client handles movement)
        SimpleMovementSystem.setPosition(entityId, targetPosition)
    end
end

-- Use special abilities based on enemy type
function SpecialChaseHandler._useSpecialAbilities(entityId, bestTarget, config, currentTime)
    local enemyType = EntityManager.getComponent(entityId, "EnemyType")
    if not enemyType then
        return
    end
    
    -- Get current position from folder attribute
    local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
    if not enemyFolder then
        return
    end
    
    local currentPosition = enemyFolder:GetAttribute("Position")
    if not currentPosition then
        return
    end
    
    -- Check for special attacks
    if config.SPECIAL_ATTACKS then
        for _, ability in ipairs(config.SPECIAL_ATTACKS) do
            if ability == "teleport" then
                SpecialChaseHandler._teleportAbility(entityId, bestTarget, config, currentTime)
            elseif ability == "stealth_strike" then
                SpecialChaseHandler._stealthStrikeAbility(entityId, bestTarget, config, currentTime)
            elseif ability == "fireball" then
                SpecialChaseHandler._fireballAbility(entityId, bestTarget, config, currentTime)
            end
        end
    end
end

-- Teleport ability
function SpecialChaseHandler._teleportAbility(entityId, bestTarget, config, currentTime)
    local targetPosition = bestTarget.position
    
    -- Get current position from folder attribute
    local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
    if not enemyFolder then
        return
    end
    
    local currentPosition = enemyFolder:GetAttribute("Position")
    if not currentPosition then
        return
    end
    
    -- Calculate teleport position (behind target)
    local directionToTarget = (targetPosition - currentPosition).Unit
    local teleportPosition = targetPosition - (directionToTarget * 5) -- 5 studs behind target
    
    -- Update position via SimpleMovementSystem (which updates folder attribute)
    SimpleMovementSystem.setPosition(entityId, teleportPosition)
    
    -- Broadcast teleport effect to clients
    local RemoteEvents = require(game:GetService("ReplicatedStorage").Shared.RemoteEvents)
    if RemoteEvents.EnemyAIStateUpdate then
        RemoteEvents.EnemyAIStateUpdate:FireAllClients(nil, entityId, "teleport")
    end
    
    print("✨ Special enemy", entityId, "teleported to", teleportPosition)
end

-- Stealth strike ability
function SpecialChaseHandler._stealthStrikeAbility(entityId, bestTarget, config, currentTime)
    -- Apply stealth damage
    local target = bestTarget.target
    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then
        local damage = 25 -- Stealth strike damage
        local DamageSystem = require(script.Parent.Parent.Systems.DamageSystem)
        DamageSystem:ApplyDamage(humanoid, damage, nil, "EnemyStealthStrike")
        
        print("🗡️ Special enemy", entityId, "performed stealth strike for", damage, "damage")
    end
    
    -- Broadcast stealth effect to clients
    local RemoteEvents = require(game:GetService("ReplicatedStorage").Shared.RemoteEvents)
    if RemoteEvents.EnemyAIStateUpdate then
        RemoteEvents.EnemyAIStateUpdate:FireAllClients(nil, entityId, "stealth_strike")
    end
end

-- Fireball ability
function SpecialChaseHandler._fireballAbility(entityId, bestTarget, config, currentTime)
    local targetPosition = bestTarget.position
    
    -- Get current position from folder attribute
    local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
    if not enemyFolder then
        return
    end
    
    local currentPosition = enemyFolder:GetAttribute("Position")
    if not currentPosition then
        return
    end
    
    -- Create fireball projectile
    local fireball = Instance.new("Part")
    fireball.Name = "FireballProjectile"
    fireball.Size = Vector3.new(0.5, 0.5, 0.5)
    fireball.Position = currentPosition
    fireball.Anchored = false
    fireball.CanCollide = false
    fireball.Color = Color3.fromRGB(255, 100, 0)
    fireball.Material = Enum.Material.Neon
    fireball.Parent = workspace
    
    -- Create body velocity for movement
    local direction = (targetPosition - currentPosition).Unit
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = direction * 50 -- Fireball speed
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Parent = fireball
    
    -- Set up collision detection
    local connection
    connection = fireball.Touched:Connect(function(hit)
        if hit.Parent and hit.Parent:FindFirstChild("Humanoid") then
            local humanoid = hit.Parent.Humanoid
            if humanoid and humanoid.Health > 0 then
                local damage = 30 -- Fireball damage
                local DamageSystem = require(script.Parent.Parent.Systems.DamageSystem)
                DamageSystem:ApplyDamage(humanoid, damage, nil, "EnemyFireball")
                
                local targetName = hit.Parent.Name
                print("🔥 Fireball hit", targetName, "for", damage, "damage")
            end
        end
        
        -- Clean up fireball
        fireball:Destroy()
        connection:Disconnect()
    end)
    
    -- Clean up fireball after lifetime
    Debris:AddItem(fireball, 5)
    
    print("🔥 Special enemy", entityId, "fired fireball toward", bestTarget.target.Name)
end

return SpecialChaseHandler 