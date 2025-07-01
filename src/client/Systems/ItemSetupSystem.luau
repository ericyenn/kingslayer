 -- Client-side item setup system - adds components to spawned items
local ItemSetupSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ECS = require(ReplicatedStorage.Shared.ECS)
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local Constants = require(ReplicatedStorage.Shared.Constants)

-- Component classes
local Draggable = require(ReplicatedStorage.Shared.components.Draggable)
local Hoverable = require(ReplicatedStorage.Shared.components.Hoverable)
local Inventoryable = require(ReplicatedStorage.Shared.components.Inventoryable)

local processedItems = {}

function ItemSetupSystem:Initialize()
    -- Process existing tagged items
    local existingItems = CollectionService:GetTagged(Constants.TAGS.DRAGGABLE_ITEM)
    for _, item in ipairs(existingItems) do
        self:SetupItem(item)
    end
    
    -- Listen for new tagged items
    CollectionService:GetInstanceAddedSignal(Constants.TAGS.DRAGGABLE_ITEM):Connect(function(item)
        self:SetupItem(item)
    end)
    
    -- Listen for removed tagged items (cleanup)
    CollectionService:GetInstanceRemovedSignal(Constants.TAGS.DRAGGABLE_ITEM):Connect(function(item)
        self:CleanupItem(item)
    end)
    
    print("Item setup system initialized")
end

function ItemSetupSystem:SetupItem(item)
    -- Avoid processing the same item twice
    if processedItems[item] then return end
    processedItems[item] = true
    
    -- Skip Handle objects (they are part of tools, not world items)
    if item.Name == "Handle" then
        return
    end
    
    -- Find the item definition by name
    local itemDefinition = self:FindItemDefinitionByName(item.Name)
    if not itemDefinition then
        warn("No item definition found for:", item.Name)
        return
    end
    
    -- Add components to the item on the client
    self:AddComponentsToItem(item, itemDefinition.components)
    
    print("Setup item on client:", item.Name)
end

function ItemSetupSystem:FindItemDefinitionByName(itemName)
    for itemId, definition in pairs(ItemDefinitions.items) do
        if definition.name == itemName then
            return definition
        end
    end
    return nil
end

function ItemSetupSystem:AddComponentsToItem(item, componentConfigs)
    for componentName, config in pairs(componentConfigs) do
        local component = self:CreateComponent(componentName, config)
        if component then
            ECS:AddComponent(item, componentName, component)
        else
            warn("Failed to create component:", componentName)
        end
    end
end

function ItemSetupSystem:CreateComponent(componentName, config)
    if componentName == "Draggable" then
        return Draggable.new(config)
    elseif componentName == "Hoverable" then
        return Hoverable.new(config)
    elseif componentName == "Inventoryable" then
        return Inventoryable.new(config)
    else
        warn("Unknown component type:", componentName)
        return nil
    end
end

function ItemSetupSystem:CleanupItem(item)
    -- Remove from processed items
    processedItems[item] = nil
    
    -- Clean up ECS components
    ECS:RemoveAllComponents(item)
    
    print("Cleaned up item:", item.Name)
end

return ItemSetupSystem 