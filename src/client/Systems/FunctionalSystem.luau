-- Functional system with shared action registry for consumables and special items
local FunctionalSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ActionRegistry = require(ReplicatedStorage.Shared.ActionRegistry)
local ActionConstants = require(ReplicatedStorage.Shared.ActionConstants)
local SystemManager = require(ReplicatedStorage.Shared.SystemManager)

-- Create functional-specific action registry
local functionalRegistry = ActionRegistry.new("FunctionalSystem")

-- Placeholder action for healing essence (to be customized later)
functionalRegistry:RegisterAction(ActionConstants.Functional.HEALING_ESSENCE, function(player, itemDef, target, actionData)
    print("🌿 Healing Essence!")
    print("  - TODO: Implement healing functionality")
    print("  - Item:", itemDef.name)
    
    if target then
        print("  - Could heal target:", target:GetFullName())
    else
        print("  - Could heal self")
    end
    
    -- Placeholder - you can customize this action later
end)

-- Summoner action - spawns boss
functionalRegistry:RegisterAction(ActionConstants.Functional.SUMMONER, function(player, itemDef, target, actionData)
    print("🔮 Summoner activated!")
    print("  - Summoning boss with item:", itemDef.name)
    
    local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
    local spawnPosition = nil
    
    if target then
        print("  - Summoning boss at target location:", target:GetFullName())
        spawnPosition = target.Position
    else
        print("  - Summoning boss at player location")
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            spawnPosition = player.Character.HumanoidRootPart.Position + Vector3.new(10, 0, 0)
        end
    end
    
    -- Fire remote event to spawn boss on server
    RemoteEvents.SpawnBoss:FireServer(spawnPosition)
    print("  - Boss spawn request sent to server")
end)

-- Revive plush action - only triggered via proximity prompt
functionalRegistry:RegisterAction(ActionConstants.Functional.REVIVE_PLUSH, function(player, itemDef, target, actionData)
    print("🧸 Revive Plush!")
    print("  - Item:", itemDef.name)
    print("  - This item can only be used via proximity prompt near dead players")
    
    -- Don't consume the item here - it will be consumed by the revive system
    -- when a successful revive is performed
end)

-- Set default action for functional items without specific actions
functionalRegistry:SetDefaultAction(function(player, itemDef, target, actionData)
    print("⚡ Functional Item Action!")
    print("  - Using", itemDef.name)
    print("  - TODO: Implement specific functionality")
    
    if target then
        print("  - Applied to target:", target:GetFullName())
    else
        print("  - Used without target")
    end
end)

function FunctionalSystem:Initialize()
    SystemManager.RegisterSystem("FunctionalSystem", self)
    print("Functional system initialized with", functionalRegistry:GetActionCount(), "functional actions")
end

function FunctionalSystem:Use(itemDef, player, target)
    print("FunctionalSystem: Use called for", itemDef.name)
    
    -- Check if item should prevent click consumption
    if itemDef.preventClickConsume then
        print("  - Item prevents click consumption:", itemDef.name)
        return
    end
    
    local actionType = itemDef.actionType or ActionConstants.Functional.DEFAULT
    local actionData = itemDef.actionData or {}
    
    print("  - Action Type:", actionType)
    print("  - Action Data:", actionData)
    
    if target then
        print("  - Target:", target:GetFullName())
    else
        print("  - No target was hit.")
    end
    
    -- Execute using shared registry
    functionalRegistry:ExecuteAction(actionType, player, itemDef, target, actionData)
    
    -- Consume the item after use (functional items are single-use)
    local InventorySystem = SystemManager.GetSystem("InventorySystem")
    if InventorySystem then
        print("FunctionalSystem: Consuming item after use")
        InventorySystem:ConsumeEquippedItem()
    else
        warn("FunctionalSystem: Could not find InventorySystem to consume item")
    end
end

-- Legacy methods for backward compatibility
function FunctionalSystem:ExecuteAction(actionName, player, itemDef, target, actionData)
    return functionalRegistry:ExecuteAction(actionName, player, itemDef, target, actionData)
end

function FunctionalSystem:RegisterAction(actionName, actionFunction)
    return functionalRegistry:RegisterAction(actionName, actionFunction)
end

function FunctionalSystem:GetRegisteredActions()
    return functionalRegistry:GetRegisteredActions()
end

return FunctionalSystem 