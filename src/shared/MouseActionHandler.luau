-- Mouse action handler for different item types
local MouseActionHandler = {}

-- Registry of mouse down actions
local actions = {}

-- Register action functions
actions["hammer_action"] = function(player, tool)
    print("🔨 Advanced Hammering! Building structures...")
    -- Custom hammer functionality here
end

actions["wrench_action"] = function(player, tool)
    print("🔧 Mechanical Work! Fixing machinery...")
    -- Custom wrench functionality here
end

actions["screwdriver_action"] = function(player, tool)
    print("🪛 Precision Work! Adjusting components...")
    -- Custom screwdriver functionality here
end

-- Armor-specific actions
actions["armor_helmet_action"] = function(player, tool)
    print("⛑️ Protective Helmet! Press G to open armor menu and equip to helmet slot.")
    -- Helmet-specific functionality here
end

actions["armor_chestplate_action"] = function(player, tool)
    print("🦺 Heavy Chestplate! Press G to open armor menu and equip to chestplate slot.")
    -- Chestplate-specific functionality here
end

actions["armor_boots_action"] = function(player, tool)
    print("🥾 Sturdy Boots! Press G to open armor menu and equip to boots slot.")
    -- Boots-specific functionality here
end

actions["armor_action"] = function(player, tool)
    print("🛡️ Defensive Action! Shield bash...")
    -- Custom armor functionality here
end

actions["potion_action"] = function(player, tool)
    print("🧪 Using Potion! Healing effects...")
    -- Custom potion functionality here
end

actions["default_action"] = function(player, tool)
    print("⚡ Item Action! Generic use...")
    -- Default action for items without specific actions
end

-- Execute an action by name
function MouseActionHandler:ExecuteAction(actionName, player, tool)
    local actionFunction = actions[actionName]
    
    if actionFunction then
        actionFunction(player, tool)
    else
        -- Fallback to default action
        actions["default_action"](player, tool)
    end
end

-- Register a new action (for future extensibility)
function MouseActionHandler:RegisterAction(actionName, actionFunction)
    actions[actionName] = actionFunction
end

-- Get all registered actions
function MouseActionHandler:GetRegisteredActions()
    local actionNames = {}
    for name, _ in pairs(actions) do
        table.insert(actionNames, name)
    end
    return actionNames
end

return MouseActionHandler 