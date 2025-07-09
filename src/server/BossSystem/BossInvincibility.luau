-- Boss Invincibility System - Handles invincibility phases and effects
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BossConfig = require(ReplicatedStorage.Shared.BossConfig)
local Types = require(ReplicatedStorage.Shared.Types)

local BossInvincibility = {}

-- Private variables
local invincibilityEffects: {[Types.BossData]: {Instance}} = {}

-- Private functions
local function createInvincibilityEffects(boss: Types.BossData)
    local effects = {}
    local rootPart = boss.rootPart
    
    -- Create glowing effect
    local pointLight = Instance.new("PointLight")
    pointLight.Color = Color3.new(1, 0.8, 0)  -- Golden glow
    pointLight.Brightness = 2
    pointLight.Range = 20
    pointLight.Parent = rootPart
    table.insert(effects, pointLight)
    
    -- Create particle effect
    local attachment = Instance.new("Attachment")
    attachment.Parent = rootPart
    table.insert(effects, attachment)
    
    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(Color3.new(1, 1, 0))  -- Yellow particles
    particles.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 0)
    }
    particles.Lifetime = NumberRange.new(1, 2)
    particles.Rate = 50
    particles.SpreadAngle = Vector2.new(45, 45)
    particles.Speed = NumberRange.new(5, 10)
    particles.Parent = attachment
    table.insert(effects, particles)
    
    -- Create pulsing effect on the boss model
    local originalColor = rootPart.Color
    local originalMaterial = rootPart.Material
    local originalTransparency = rootPart.Transparency
    
    -- Change appearance during invincibility
    rootPart.Color = Color3.new(1, 1, 0)  -- Golden color
    rootPart.Material = Enum.Material.ForceField
    
    -- Create pulsing transparency tween
    local pulseInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    local pulseTween = TweenService:Create(rootPart, pulseInfo, {Transparency = 0.3})
    pulseTween:Play()
    table.insert(effects, pulseTween)
    
    -- Store original properties for restoration
    effects.originalColor = originalColor
    effects.originalMaterial = originalMaterial
    effects.originalTransparency = originalTransparency
    
    invincibilityEffects[boss] = effects
end

local function removeInvincibilityEffects(boss: Types.BossData)
    local effects = invincibilityEffects[boss]
    if not effects then return end
    
    -- Restore original appearance
    local rootPart = boss.rootPart
    if effects.originalColor then
        rootPart.Color = effects.originalColor
    end
    if effects.originalMaterial then
        rootPart.Material = effects.originalMaterial
    end
    if effects.originalTransparency then
        rootPart.Transparency = effects.originalTransparency
    end
    
    -- Clean up effects
    for _, effect in pairs(effects) do
        if typeof(effect) == "Instance" then
            effect:Destroy()
        elseif typeof(effect) == "Tween" then
            effect:Cancel()
        end
    end
    
    invincibilityEffects[boss] = nil
end

local function healBoss(boss: Types.BossData, amount: number)
    local newHealth = math.min(boss.health + amount, boss.maxHealth)
    boss.health = newHealth
    boss.humanoid.Health = newHealth
    
    print("Boss healed for", amount, "health. Current health:", newHealth)
end

-- Public functions
function BossInvincibility.startInvincibilityPhase(boss: Types.BossData)
    print("Boss entering invincibility phase")
    
    boss.isInvincible = true
    boss.invincibilityStartTime = tick()
    boss.state = "Invincible"
    boss.moveCounter = 0  -- Reset move counter
    
    -- Stop movement
    local BossMovement = require(script.Parent.BossMovement)
    BossMovement.stopMovement(boss)
    
    -- Create visual effects
    createInvincibilityEffects(boss)
    
    -- Optional healing
    if BossConfig.invincibility.healAmount > 0 then
        healBoss(boss, BossConfig.invincibility.healAmount)
    end
    
    -- TODO: Fire remote event to clients for additional effects
end

function BossInvincibility.endInvincibilityPhase(boss: Types.BossData)
    print("Boss exiting invincibility phase")
    
    boss.isInvincible = false
    boss.invincibilityStartTime = nil
    
    -- Remove visual effects
    removeInvincibilityEffects(boss)
    
    -- TODO: Fire remote event to clients to end effects
end

function BossInvincibility.updateInvincibilityEffects(boss: Types.BossData, deltaTime: number)
    if not boss.isInvincible then return end
    
    -- Update any dynamic effects here
    -- For now, the tween handles the pulsing automatically
    
    -- Could add more complex effects like:
    -- - Rotating particles
    -- - Changing light intensity
    -- - Sound effects
end

function BossInvincibility.shouldEndInvincibility(boss: Types.BossData): boolean
    if not boss.isInvincible or not boss.invincibilityStartTime then
        return false
    end
    
    local currentTime = tick()
    local elapsedTime = currentTime - boss.invincibilityStartTime
    
    return elapsedTime >= BossConfig.invincibility.duration
end

function BossInvincibility.isInvincible(boss: Types.BossData): boolean
    return boss.isInvincible
end

function BossInvincibility.blockDamage(boss: Types.BossData, damageAmount: number): number
    if not boss.isInvincible then
        return damageAmount  -- No damage reduction
    end
    
    local damageReduction = BossConfig.invincibility.damageReduction
    local actualDamage = damageAmount * (1 - damageReduction)
    
    if actualDamage < damageAmount then
        print("Boss invincibility blocked", damageAmount - actualDamage, "damage")
    end
    
    return actualDamage
end

function BossInvincibility.getRemainingInvincibilityTime(boss: Types.BossData): number?
    if not boss.isInvincible or not boss.invincibilityStartTime then
        return nil
    end
    
    local currentTime = tick()
    local elapsedTime = currentTime - boss.invincibilityStartTime
    local remainingTime = BossConfig.invincibility.duration - elapsedTime
    
    return math.max(0, remainingTime)
end

-- Cleanup function for when boss is destroyed
function BossInvincibility.cleanup(boss: Types.BossData)
    removeInvincibilityEffects(boss)
end

return BossInvincibility 