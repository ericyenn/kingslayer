-- BreakableDamageSystem.luau
-- Handles damage to breakable objects using existing hitbox system

local BreakableDamageSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ECS = require(ReplicatedStorage.Shared.ECS)
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local SystemManager = require(ReplicatedStorage.Shared.SystemManager)


-- Configuration
local DAMAGE_CONFIG = {
    -- Anti-cheat settings
    MAX_DAMAGE_PER_HIT = 100,
    DEFAULT_COOLDOWN = 0.5, -- Default cooldown if item doesn't specify one
    
    -- Distance validation
    MAX_ATTACK_DISTANCE = 10,
    
    -- Tool validation
    VALID_BREAKABLE_TOOLS = {"axe", "pickaxe", "crystal_tool"}
}

-- Internal state
local lastDamageTime = {}

function BreakableDamageSystem:Initialize()
    print("BreakableDamageSystem: Initializing...")
    
    -- Register with system manager
    SystemManager.RegisterSystem("BreakableDamageSystem", self)
    
    print("BreakableDamageSystem: Initialized")
end

function BreakableDamageSystem:ProcessBreakableDamageRequest(player, targetPart, damageAmount)
    -- Validate player
    if not player or not player.Character then
        warn("BreakableDamageSystem: Invalid player or no character")
        return false, "Invalid player"
    end
    
    -- Validate target
    if not targetPart or not targetPart.Parent then
        warn("BreakableDamageSystem: Invalid target part")
        return false, "Invalid target"
    end
    
    -- Check if target is a breakable object (has "Breakable" tag)
    local CollectionService = game:GetService("CollectionService")
    local isBreakable = CollectionService:HasTag(targetPart, "Breakable") or 
                       (targetPart.Parent and CollectionService:HasTag(targetPart.Parent, "Breakable"))
    
    if not isBreakable then
        return false, "Target is not breakable"
    end
    
    -- Get the breakable component
    local breakableComponent = ECS:GetComponent(targetPart, "Breakable")
    if not breakableComponent then
        return false, "Target missing breakable component"
    end
    
    -- Get the equipped tool to determine cooldown
    local character = player.Character
    local equippedTool = character and character:FindFirstChildOfClass("Tool")
    if not equippedTool then
        warn("BreakableDamageSystem: Player has no tool equipped")
        return false, "No tool equipped"
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
        warn("BreakableDamageSystem: Player", player.Name, "is attacking too fast (cooldown:", cooldown, "s)")
        return false, "Attack too fast"
    end
    
    -- Anti-cheat: Validate damage amount
    if damageAmount > DAMAGE_CONFIG.MAX_DAMAGE_PER_HIT or damageAmount <= 0 then
        warn("BreakableDamageSystem: Invalid damage amount", damageAmount, "from player", player.Name)
        return false, "Invalid damage amount"
    end
    
    -- Anti-cheat: Validate weapon and damage match
    if not self:ValidateWeaponDamage(player, damageAmount) then
        warn("BreakableDamageSystem: Weapon damage mismatch for player", player.Name)
        return false, "Weapon damage mismatch"
    end
    
    -- Anti-cheat: Check distance
    if not self:ValidateDistance(player, targetPart) then
        warn("BreakableDamageSystem: Player", player.Name, "is too far from target")
        return false, "Too far from target"
    end
    
    -- Validate tool type matches breakable requirement
    local toolType = self:GetToolType(equippedTool)
    if not toolType then
        warn("BreakableDamageSystem: Invalid tool type for weapon", equippedTool.Name)
        return false, "Invalid tool type"
    end
    
    -- Get the visual component for effects
    local visualComponent = ECS:GetComponent(targetPart, "BreakableVisual")
    print("BreakableDamageSystem: Visual component found:", visualComponent ~= nil)
    
    -- Apply damage to breakable
    local success, result = breakableComponent:TakeDamage(damageAmount, toolType)
    if not success then
        return false, result
    end
    
    -- Visual effects removed
    
    -- Update cooldown
    lastDamageTime[player] = currentTime
    
    -- Handle breaking
    if result == "broken" then
        -- Trigger break particles before destroying the object
        if visualComponent then
            print("BreakableDamageSystem: Triggering break particles for", targetPart.Name)
            visualComponent:ShowBreakEffect(targetPart)
        else
            print("BreakableDamageSystem: No visual component for break particles on", targetPart.Name)
        end
        
        self:HandleBreakableBroken(targetPart, breakableComponent)
    end
    
    print("BreakableDamageSystem: Applied", damageAmount, "damage to", targetPart.Name, "by", player.Name)
    return true, result
end

function BreakableDamageSystem:ValidateWeaponDamage(player, damageAmount)
    -- Check if player has the weapon equipped
    local character = player.Character
    if not character then return false end
    
    local equippedTool = character:FindFirstChildOfClass("Tool")
    if not equippedTool then
        warn("BreakableDamageSystem: Player has no tool equipped")
        return false
    end
    
    -- Get item definition and validate damage
    local itemKey = string.lower(equippedTool.Name)
    local itemDef = ItemDefinitions:GetItem(itemKey)
    
    if not itemDef then
        warn("BreakableDamageSystem: No item definition for weapon", equippedTool.Name)
        return false
    end
    
    if itemDef.category ~= "tool" then
        warn("BreakableDamageSystem: Item is not a tool category")
        return false
    end
    
    -- Check if it's a breakable tool (has breakable damage)
    local breakableDamage = itemDef.actionData and itemDef.actionData.breakableDamage
    if not breakableDamage then
        warn("BreakableDamageSystem: Tool has no breakable damage")
        return false
    end
    
    -- Validate damage is within expected range
    local expectedDamage = breakableDamage
    local tolerance = 5 -- Allow some variance
    
    if math.abs(damageAmount - expectedDamage) > tolerance then
        warn("BreakableDamageSystem: Damage mismatch - expected", expectedDamage, "got", damageAmount)
        return false
    end
    
    return true
end

function BreakableDamageSystem:ValidateDistance(player, targetPart)
    local character = player.Character
    if not character then return false end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return false end
    
    local distance = (humanoidRootPart.Position - targetPart.Position).Magnitude
    return distance <= DAMAGE_CONFIG.MAX_ATTACK_DISTANCE
end

function BreakableDamageSystem:GetToolType(equippedTool)
    if not equippedTool then
        return nil
    end
    
    -- Check for tags to determine tool type
    local CollectionService = game:GetService("CollectionService")
    
    -- Debug: Print all tags on the tool
    local tags = CollectionService:GetTags(equippedTool)
    print("BreakableDamageSystem: Tool", equippedTool.Name, "has tags:", table.concat(tags, ", "))
    
    if CollectionService:HasTag(equippedTool, "Axe") then
        return "axe"
    elseif CollectionService:HasTag(equippedTool, "Pickaxe") then
        return "pickaxe"
    end
    
    return nil
end

function BreakableDamageSystem:HandleBreakableBroken(breakableObject, breakableComponent)
    -- Store position for respawning
    local originalPosition = breakableObject.Position
    local originalSize = breakableObject.Size
    local originalCFrame = breakableObject.CFrame
    
    -- Remove Breakable tag while broken
    local CollectionService = game:GetService("CollectionService")
    CollectionService:RemoveTag(breakableObject, "Breakable")
    
    -- Start respawn timer
    breakableComponent:StartRespawn()
    
    -- Drop items
    self:DropBreakableItems(breakableObject, breakableComponent)
    
    -- Notify client systems
    self:NotifyBreakableBroken(breakableObject, breakableComponent)
    
    -- Destroy the object completely
    breakableObject:Destroy()
    
    print("BreakableDamageSystem: Breakable broken:", breakableObject.Name)
end

function BreakableDamageSystem:DropBreakableItems(breakableObject, breakableComponent)
    local dropItems = breakableComponent:GetDropItems()
    local dropPosition = breakableObject.Position + Vector3.new(0, 2, 0)
    
    for _, dropConfig in ipairs(dropItems) do
        if math.random() <= dropConfig.chance then
            local quantity = math.random(dropConfig.quantity.min, dropConfig.quantity.max)
            
            -- Spawn the item using existing ItemSpawnSystem
            local itemSpawnSystem = SystemManager.GetSystem("ItemSpawnSystem")
            if itemSpawnSystem then
                for i = 1, quantity do
                    local offset = Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
                    itemSpawnSystem:SpawnItem(dropConfig.item, dropPosition + offset)
                end
            else
                warn("BreakableDamageSystem: ItemSpawnSystem not found")
            end
        end
    end
end

function BreakableDamageSystem:NotifyBreakableBroken(breakableObject, breakableComponent)
    -- This would typically send a remote event to clients
    -- For now, we'll just print a message
    print("BreakableDamageSystem: Notifying clients of broken breakable:", breakableObject.Name)
end

function BreakableDamageSystem:GetBreakableComponent(part)
    return ECS:GetComponent(part, "Breakable")
end

function BreakableDamageSystem:IsBreakable(part)
    return ECS:HasComponent(part, "Breakable")
end

return BreakableDamageSystem 