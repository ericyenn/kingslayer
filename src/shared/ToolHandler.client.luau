-- Tool interaction handler for inventory system tools
-- This script will be copied to each tool when created

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MouseActionHandler = require(ReplicatedStorage.Shared.MouseActionHandler)
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)

local player = Players.LocalPlayer

-- Wait for tool to be available
local tool = script.Parent
if not tool:IsA("Tool") then
    warn("ToolHandler script not parented to a Tool")
    return
end

print("Tool handler initialized for:", tool.Name)

-- Handle tool activation (left click)
tool.Activated:Connect(function()
    print("Used tool:", tool.Name)
    
    -- Find the item definition for this tool
    local itemDefinition = nil
    for itemId, definition in pairs(ItemDefinitions.items) do
        if definition.name == tool.Name then
            itemDefinition = definition
            break
        end
    end
    
    -- Execute the mouse down action if defined
    if itemDefinition and itemDefinition.mouseDownAction then
        MouseActionHandler:ExecuteAction(itemDefinition.mouseDownAction, player, tool)
    else
        -- Fallback to default behavior for items without defined actions
        MouseActionHandler:ExecuteAction("default_action", player, tool)
    end
end)

-- Handle tool equipped
tool.Equipped:Connect(function()
    print("Equipped tool:", tool.Name)
end)

-- Handle tool unequipped
tool.Unequipped:Connect(function()
    print("Unequipped tool:", tool.Name)
end) 