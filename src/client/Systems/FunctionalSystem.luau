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