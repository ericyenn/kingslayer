-- Server-side damage system for handling weapon damage
local DamageSystem = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local Categories = require(ReplicatedStorage.Shared.ItemCategory)

-- Anti-cheat configuration
local DAMAGE_CONFIG = {
    MAX_DAMAGE_DISTANCE = 10, -- Maximum distance player can be from target
    DEFAULT_COOLDOWN = 0.1, -- Default cooldown if item doesn't specify one
    MAX_DAMAGE_PER_HIT = 50, -- Maximum damage that can be applied in one hit
}

-- Track last damage time per player for cooldown
local lastDamageTime = {}

function DamageSystem:Initialize()
    -- Handle damage requests from clients
    RemoteEvents.ApplyDamage.OnServerEvent:Connect(function(player, targetPart, weaponName, damageAmount)
        self:ProcessDamageRequest(player, targetPart, weaponName, damageAmount)
    end)
    
    -- Clean up tracking when players leave
    Players.PlayerRemoving:Connect(function(player)
        lastDamageTime[player] = nil
    end)
    
    print("DamageSystem initialized")
end

function DamageSystem:ProcessDamageRequest(player, targetPart, weaponName, damageAmount)
    -- Validate player
    if not player or not player.Character then
        warn("DamageSystem: Invalid player or no character")
        return
    end
    
    -- Validate target
    if not targetPart or not targetPart.Parent then
        warn("DamageSystem: Invalid target part")
        return
    end
    
    -- Get the equipped tool to determine cooldown
    local character = player.Character
    local equippedTool = character and character:FindFirstChildOfClass("Tool")
    if not equippedTool then
        warn("DamageSystem: Player has no tool equipped")
        return
    end
    
    -- Get item definition to determine cooldown
    local itemKey = string.lower(equippedTool.Name)
    local itemDef = ItemDefinitions:GetItem(itemKey)
    local cooldown = DAMAGE_CONFIG.DEFAULT_COOLDOWN -- Default fallback
    
    if itemDef and itemDef.actionData and itemDef.actionData.cooldown then
        cooldown = itemDef.actionData.cooldown
    end
    
    -- Anti-cheat: Check cooldown using item-specific cooldown
    local currentTime = tick()
    if lastDamageTime[player] and (currentTime - lastDamageTime[player]) < cooldown then
        warn("DamageSystem: Player", player.Name, "is attacking too fast (cooldown:", cooldown, "s)")
        return
    end
    
    -- Anti-cheat: Validate damage amount
    if damageAmount > DAMAGE_CONFIG.MAX_DAMAGE_PER_HIT or damageAmount <= 0 then
        warn("DamageSystem: Invalid damage amount", damageAmount, "from player", player.Name)
        return
    end
    
    -- Anti-cheat: Validate weapon and damage match
    if not self:ValidateWeaponDamage(player, weaponName, damageAmount) then
        warn("DamageSystem: Weapon damage mismatch for player", player.Name)
        return
    end
    
    -- Anti-cheat: Check distance
    if not self:ValidateDistance(player, targetPart) then
        warn("DamageSystem: Player", player.Name, "is too far from target")
        return
    end
    
    -- Find target with Humanoid
    local targetHumanoid = self:FindTargetHumanoid(targetPart)
    if not targetHumanoid then
        print("DamageSystem: Target has no Humanoid, cannot take damage")
        return
    end
    -- Prevent damage to dead players
    local targetPlayer = Players:GetPlayerFromCharacter(targetHumanoid.Parent)
    if targetPlayer then
        local CollectionService = game:GetService("CollectionService")
        print("[DamageSystem] Checking Dead tag for player:", targetPlayer.Name, CollectionService:HasTag(targetPlayer, "Dead"))
        if CollectionService:HasTag(targetPlayer, "Dead") then
            print("DamageSystem: Player ", targetPlayer.Name, " is dead, ignoring damage.")
            return
        end
    end
    
    -- Apply damage
    self:ApplyDamage(targetHumanoid, damageAmount, player, weaponName)
    
    -- Update cooldown
    lastDamageTime[player] = currentTime
end

function DamageSystem:ValidateWeaponDamage(player, weaponName, damageAmount)
    -- Check if player has the weapon equipped
    local character = player.Character
    if not character then return false end
    
    local equippedTool = character:FindFirstChildOfClass("Tool")
    if not equippedTool then
        warn("DamageSystem: Player has no tool equipped")
        return false
    end
    
    -- Check if tool name matches
    if equippedTool.Name ~= weaponName then
        warn("DamageSystem: Tool name mismatch -", equippedTool.Name, "vs", weaponName)
        return false
    end
    
    -- Get item definition and validate damage
    local itemKey = string.lower(weaponName)
    local itemDef = ItemDefinitions:GetItem(itemKey)
    
    if not itemDef then
        warn("DamageSystem: No item definition for weapon", weaponName)
        return false
    end
    
    if itemDef.category ~= Categories.Tool then
        warn("DamageSystem: Item is not a tool category")
        return false
    end
    
    local baseDamage = itemDef.actionData and itemDef.actionData.damage or 10
    local chargeMultiplier = itemDef.actionData and itemDef.actionData.chargeMultiplier or 1.0
    local criticalMultiplier = itemDef.actionData and itemDef.actionData.criticalMultiplier or 3.0
    
    -- Calculate expected damage ranges
    local expectedNormalDamage = baseDamage
    local expectedChargedDamage = math.floor(baseDamage * chargeMultiplier)
    local expectedCriticalDamage = math.floor(baseDamage * criticalMultiplier)
    
    -- Check if damage matches normal, charged, or critical attack
    local isNormalAttack = math.abs(damageAmount - expectedNormalDamage) <= 0.1
    local isChargedAttack = math.abs(damageAmount - expectedChargedDamage) <= 0.1
    local isCriticalAttack = math.abs(damageAmount - expectedCriticalDamage) <= 0.1
    
    if not isNormalAttack and not isChargedAttack and not isCriticalAttack then
        warn("DamageSystem: Damage mismatch -", damageAmount, "vs expected normal", expectedNormalDamage, "charged", expectedChargedDamage, "or critical", expectedCriticalDamage)
        return false
    end
    
    -- Log the attack type for debugging
    if isCriticalAttack then
        print("DamageSystem: Validated CRITICAL attack -", damageAmount, "damage")
    elseif isChargedAttack then
        print("DamageSystem: Validated CHARGED attack -", damageAmount, "damage")
    else
        print("DamageSystem: Validated normal attack -", damageAmount, "damage")
    end
    
    return true
end

function DamageSystem:ValidateDistance(player, targetPart)
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local playerPosition = character.HumanoidRootPart.Position
    local targetPosition = targetPart.Position
    
    local distance = (playerPosition - targetPosition).Magnitude
    
    return distance <= DAMAGE_CONFIG.MAX_DAMAGE_DISTANCE
end

function DamageSystem:FindTargetHumanoid(targetPart)
    -- First check if the part itself is a Humanoid
    if targetPart:IsA("Humanoid") then
        return targetPart
    end
    
    -- Check if the part's parent has a Humanoid
    local parent = targetPart.Parent
    if parent then
        local humanoid = parent:FindFirstChild("Humanoid")
        if humanoid then
            return humanoid
        end
    end
    
    -- Check if the part is part of a character model
    -- Look for Humanoid in the model hierarchy
    local model = targetPart.Parent
    while model and model ~= workspace do
        local humanoid = model:FindFirstChild("Humanoid")
        if humanoid then
            return humanoid
        end
        model = model.Parent
    end
    
    return nil
end

function DamageSystem:ApplyDamage(humanoid, damageAmount, attacker, weaponName)
    -- Check if target is already dead
    if humanoid.Health <= 0 then
        return
    end
    
    -- Apply damage
    local newHealth = math.max(0, humanoid.Health - damageAmount)
    humanoid.Health = newHealth
    
    -- Get target name for logging
    local targetName = "Unknown"
    if humanoid.Parent then
        targetName = humanoid.Parent.Name
    end
    
    print("DamageSystem: Applied", damageAmount, "damage to", targetName, "with", weaponName)
    print("  - Health:", humanoid.Health .. "/" .. humanoid.MaxHealth)
    
    -- Audio is now handled client-side in ToolSystem
    
    if newHealth <= 0 then
        print("DamageSystem:", targetName, "has been defeated by", attacker.Name)
        -- The Humanoid.Died event will be handled by the target's own systems
    end
end



-- Public methods for other systems
function DamageSystem:GetDamageConfig()
    return DAMAGE_CONFIG
end

function DamageSystem:IsPlayerOnCooldown(player)
    if not lastDamageTime[player] then return false end
    
    -- Get the equipped tool to determine cooldown
    local character = player.Character
    local equippedTool = character and character:FindFirstChildOfClass("Tool")
    if not equippedTool then
        return false -- No tool equipped, not on cooldown
    end
    
    -- Get item definition to determine cooldown
    local itemKey = string.lower(equippedTool.Name)
    local itemDef = ItemDefinitions:GetItem(itemKey)
    local cooldown = DAMAGE_CONFIG.DEFAULT_COOLDOWN -- Default fallback
    
    if itemDef and itemDef.actionData and itemDef.actionData.cooldown then
        cooldown = itemDef.actionData.cooldown
    end
    
    return (tick() - lastDamageTime[player]) < cooldown
end

return DamageSystem 