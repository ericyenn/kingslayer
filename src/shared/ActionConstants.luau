-- Action constants to eliminate magic strings and provide centralized action names
local ActionConstants = {}

-- Tool Actions (simplified to one generic attack)
ActionConstants.Tool = {
    ATTACK = "tool_attack",
    DEFAULT = "default_action"
}

-- Armor Actions (no click actions, only equip system)
ActionConstants.Armor = {
    DEFAULT = "default_action"
}

-- Functional Item Actions (placeholder for future customization)
ActionConstants.Functional = {
    HEALING_ESSENCE = "healing_essence_action",
    DEFAULT = "default_action"
}

-- General Actions (used across categories)
ActionConstants.General = {
    DEFAULT = "default_action"
}

-- Helper function to get all action names for a category
function ActionConstants.GetAllActions(category)
    if category == "Tool" then
        return ActionConstants.Tool
    elseif category == "Armor" then
        return ActionConstants.Armor
    elseif category == "Functional" then
        return ActionConstants.Functional
    else
        return ActionConstants.General
    end
end

-- Helper function to validate action name exists
function ActionConstants.IsValidAction(actionName, category)
    local categoryActions = ActionConstants.GetAllActions(category)
    
    for _, validAction in pairs(categoryActions) do
        if validAction == actionName then
            return true
        end
    end
    
    return false
end

-- Helper function to get default action for category
function ActionConstants.GetDefaultAction(category)
    local categoryActions = ActionConstants.GetAllActions(category)
    return categoryActions.DEFAULT or ActionConstants.General.DEFAULT
end

return ActionConstants 