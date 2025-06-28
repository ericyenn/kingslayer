-- Simple ECS component manager
local ECS = {}

-- Store components for each item
local itemComponents = {}

-- Add a component to an item
function ECS:AddComponent(item, componentName, componentData)
    if not itemComponents[item] then
        itemComponents[item] = {}
    end
    itemComponents[item][componentName] = componentData
end

-- Get a specific component from an item
function ECS:GetComponent(item, componentName)
    return itemComponents[item] and itemComponents[item][componentName]
end

-- Check if an item has a specific component
function ECS:HasComponent(item, componentName)
    return itemComponents[item] and itemComponents[item][componentName] ~= nil
end

-- Query all items that have the specified components
function ECS:QueryComponents(...)
    local requiredComponents = {...}
    local results = {}
    
    for item, components in pairs(itemComponents) do
        local hasAll = true
        for _, componentName in ipairs(requiredComponents) do
            if not components[componentName] then
                hasAll = false
                break
            end
        end
        if hasAll then
            table.insert(results, item)
        end
    end
    
    return results
end

-- Remove a component from an item
function ECS:RemoveComponent(item, componentName)
    if itemComponents[item] then
        itemComponents[item][componentName] = nil
        
        -- Clean up if no components left
        if next(itemComponents[item]) == nil then
            itemComponents[item] = nil
        end
    end
end

-- Remove all components from an item (cleanup)
function ECS:RemoveAllComponents(item)
    itemComponents[item] = nil
end

return ECS 