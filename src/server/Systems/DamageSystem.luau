-- Server-side damage system for handling weapon damage
local DamageSystem = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local Categories = require(ReplicatedStorage.Shared.ItemCategory)

-- Import EntityManager for enemy entity handling
local EntityManager = require(ReplicatedStorage.Shared.EntityManager)

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
    RemoteEvents.ApplyDamage.OnServerEvent:Connect(function(player, target, weaponName, damageAmount)
        self:ProcessDamageRequest(player, target, weaponName, damageAmount)
    end)
    
    -- Clean up tracking when players leave
    Players.PlayerRemoving:Connect(function(player)
        lastDamageTime[player] = nil
    end)
    
    print("DamageSystem initialized")
end

function DamageSystem:ProcessDamageRequest(player, target, weaponName, damageAmount)
    -- Validate player
    if not player or not player.Character then
        warn("DamageSystem: Invalid player or no character")
        return
    end
    
    -- Check if target is an entity ID (enemy) or a part (player/breakable)
    local isEnemyEntity = type(target) == "number"
    
    if isEnemyEntity then
        -- Handle enemy damage
        self:ProcessEnemyDamageRequest(player, target, weaponName, damageAmount)
    else
        -- Handle player/breakable damage (existing logic)
        self:ProcessPlayerDamageRequest(player, target, weaponName, damageAmount)
    end
end

function DamageSystem:ProcessEnemyDamageRequest(player, enemyEntityId, weaponName, damageAmount)
    -- Validate player
    if not player or not player.Character then
        warn("DamageSystem: Invalid player or no character")
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
    
    -- Check if enemy entity exists
    local enemyAI = EntityManager.getComponent(enemyEntityId, "EnemyAI")
    if not enemyAI then
        warn("DamageSystem: Enemy entity", enemyEntityId, "not found")
        return
    end
    
    -- Check if enemy is dead using universal death indicator
    local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(enemyEntityId))
    if not enemyFolder then
        warn("DamageSystem: Enemy folder not found for entity", enemyEntityId)
        return
    end
    
    if enemyFolder:GetAttribute("Dead") == true then
        warn("DamageSystem: Enemy", enemyEntityId, "is already dead")
        return
    end
    
    -- Check enemy-specific attack cooldown
    local enemyType = EntityManager.getComponent(enemyEntityId, "EnemyType")
    local attackCooldown = 1.5 -- Default cooldown
    
    if enemyType and enemyType.config and enemyType.config.attackCooldown then
        attackCooldown = enemyType.config.attackCooldown
    end
    
    -- Check per-player attack cooldown for this enemy
    local cooldownKey = enemyEntityId .. "_" .. player.UserId
    if lastDamageTime[cooldownKey] and (currentTime - lastDamageTime[cooldownKey]) < attackCooldown then
        warn("DamageSystem: Attack on cooldown for enemy", enemyEntityId, "and player", player.Name)
        return
    end
    
    -- Apply damage to enemy
    self:ApplyEnemyDamage(enemyEntityId, damageAmount, player, weaponName)
    
    -- Update cooldowns
    lastDamageTime[player] = currentTime
    lastDamageTime[cooldownKey] = currentTime
end

function DamageSystem:ProcessPlayerDamageRequest(player, targetPart, weaponName, damageAmount)
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

function DamageSystem:ValidateEnemyMovementZone(player, enemyEntityId)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local playerPosition = player.Character.HumanoidRootPart.Position
    
    -- Get enemy movement zone
    local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(enemyEntityId))
    if not enemyFolder then
        return false
    end
    
    local movementZone = enemyFolder:FindFirstChild("MovementZone")
    if not movementZone then
        return false
    end
    
    -- Check if player is within the movement zone
    local zonePosition = movementZone.Position
    local zoneSize = movementZone.Size
    local zoneCFrame = movementZone.CFrame
    
    -- Convert player position to local coordinates
    local localPosition = zoneCFrame:PointToObjectSpace(playerPosition)
    
    -- Check if player is within the zone bounds
    local halfSize = zoneSize / 2
    if math.abs(localPosition.X) <= halfSize.X and 
       math.abs(localPosition.Y) <= halfSize.Y and 
       math.abs(localPosition.Z) <= halfSize.Z then
        return true
    end
    
    return false
end

function DamageSystem:ApplyEnemyDamage(enemyEntityId, damageAmount, attacker, weaponName)
    -- Get enemy folder and model
    local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(enemyEntityId))
    if not enemyFolder then
        warn("DamageSystem: Enemy folder not found for entity", enemyEntityId)
        return
    end
    
    -- Get enemy type for logging
    local enemyType = EntityManager.getComponent(enemyEntityId, "EnemyType")
    local enemyName = enemyType and enemyType.enemyId or "Unknown"
    
    -- Get current health from attribute (default to 100 if not set)
    local currentHealth = enemyFolder:GetAttribute("Health") or 100
    local maxHealth = enemyFolder:GetAttribute("MaxHealth") or 100
    
    -- Check if enemy is already dead
    if currentHealth <= 0 then
        return
    end
    
    -- Apply damage
    local newHealth = math.max(0, currentHealth - damageAmount)
    
    -- Update health attribute
    enemyFolder:SetAttribute("Health", newHealth)
    
    -- Trigger attack chase state when enemy takes damage
    if newHealth > 0 then -- Only if enemy is still alive
        if _G.AISystem then
            local enemyAI = EntityManager.getComponent(enemyEntityId, "EnemyAI")
            if enemyAI then
                _G.AISystem._setState(enemyEntityId, enemyAI, "attack_chase")
                enemyAI.target = attacker
                print("DamageSystem: Enemy", enemyEntityId, "entered attack_chase state from damage")
            end
        end
    end
    
    if newHealth <= 0 then
        local attackerName = attacker and attacker.Name or "Unknown"
        print("DamageSystem: Enemy", enemyEntityId, "(", enemyName, ") has been defeated by", attackerName)
        
        -- Set universal death indicator (triggers client destruction)
        enemyFolder:SetAttribute("Dead", true)
        
        -- Clean up AI detection events
        if _G.AISystem then
            _G.AISystem.cleanupDeadEnemy(enemyEntityId)
        end
        
        -- Wait for client to destroy original enemy
        task.wait()
        
        -- Create ragdoll for dragging
        local ragdollModel = self:CreateEnemyRagdoll(enemyEntityId)
        if ragdollModel then
            ragdollModel.Parent = workspace
            local CollectionService = game:GetService("CollectionService")
            CollectionService:AddTag(ragdollModel, "Draggable")
            print("DamageSystem: Created draggable ragdoll for enemy", enemyEntityId)
        end
    end
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

-- Create ragdoll from enemy model
function DamageSystem:CreateEnemyRagdoll(enemyEntityId)
    -- Find the enemy model on the client that created it
    local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(enemyEntityId))
    if not enemyFolder then
        return nil
    end
    
    -- Get enemy type for model name
    local enemyType = enemyFolder:GetAttribute("EnemyType")
    if not enemyType then
        return nil
    end
    
    -- Create ragdoll model from ReplicatedStorage
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local enemyModels = ReplicatedStorage:FindFirstChild("EnemyModels")
    if not enemyModels then
        return nil
    end
    
    local modelName = self:GetModelNameForEnemy(enemyType)
    local model = enemyModels:FindFirstChild(modelName)
    if not model then
        return nil
    end
    
    -- Clone the model
    local ragdollModel = model:Clone()
    
    -- Position at enemy death location
    local enemyPosition = enemyFolder:GetAttribute("Position")
    if enemyPosition and ragdollModel.PrimaryPart then
        ragdollModel:SetPrimaryPartCFrame(CFrame.new(enemyPosition))
    end
    
    -- Convert to ragdoll (convert Motor6D to BallSocketConstraints)
    local humanoid = ragdollModel:FindFirstChildOfClass("Humanoid")
    if humanoid then
        -- Keep humanoid but disable all functionality
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.AutoRotate = false
        humanoid.AutoJumpEnabled = false
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.RequiresNeck = false
        humanoid.BreakJointsOnDeath = false
        -- CRITICAL: Prevent standing up
        humanoid.PlatformStand = true
        -- Disable AI state machine
        humanoid.EvaluateStateMachine = false
    end
    
    -- Set collision groups for ragdoll parts
    for _, part in pairs(ragdollModel:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CollisionGroup = "Ragdolls"
            part.CanCollide = true
        end
    end
    
    -- Remove any AI or combat components
    for _, child in pairs(ragdollModel:GetChildren()) do
        if child:IsA("Script") or child:IsA("LocalScript") then
            child:Destroy() -- Remove scripts
        end
    end
    
    -- Convert joints to ragdoll
    for _, part in pairs(ragdollModel:GetDescendants()) do
        if part:IsA("Motor6D") then
            local Socket = Instance.new("BallSocketConstraint")
            local a1 = Instance.new("Attachment")
            local a2 = Instance.new("Attachment")
            a1.Parent = part.Part0
            a2.Parent = part.Part1
            Socket.Parent = part.Parent
            Socket.Attachment0 = a1
            Socket.Attachment1 = a2
            a1.CFrame = part.C0
            a2.CFrame = part.C1
            Socket.LimitsEnabled = true
            Socket.TwistLimitsEnabled = true
            part:Destroy()
        end
    end
    
    -- Unanchor for ragdoll physics
    if ragdollModel.PrimaryPart then
        ragdollModel.PrimaryPart.Anchored = false
    end
    
    return ragdollModel
end

-- Get model name for enemy type
function DamageSystem:GetModelNameForEnemy(enemyType)
    local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
    local enemyDef = EnemyDefinitions:GetEnemy(enemyType)
    return enemyDef and enemyDef.model or "Jason"
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
        local attackerName = attacker and attacker.Name or "Unknown"
        print("DamageSystem:", targetName, "has been defeated by", attackerName)
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