-- EntityManager.lua
-- Simple entity and component management system
-- Single responsibility: Create entities and store their components

local EntityManager = {}

-- Core storage
EntityManager.nextEntityId = 1
EntityManager.components = {} -- [componentType][entityId] = componentData

-- Create a new entity (just assigns a unique ID)
function EntityManager.createEntity()
    local entityId = EntityManager.nextEntityId
    EntityManager.nextEntityId = EntityManager.nextEntityId + 1
    return entityId
end

-- Add a component to an entity
function EntityManager.addComponent(entityId, componentType, componentData)
    if not EntityManager.components[componentType] then
        EntityManager.components[componentType] = {}
    end
    EntityManager.components[componentType][entityId] = componentData
end

-- Get a component from an entity
function EntityManager.getComponent(entityId, componentType)
    if EntityManager.components[componentType] then
        return EntityManager.components[componentType][entityId]
    end
    return nil
end

-- Check if entity has a component
function EntityManager.hasComponent(entityId, componentType)
    return EntityManager.getComponent(entityId, componentType) ~= nil
end

-- Remove a component from an entity
function EntityManager.removeComponent(entityId, componentType)
    if EntityManager.components[componentType] then
        EntityManager.components[componentType][entityId] = nil
    end
end

-- Remove an entity and all its components
function EntityManager.removeEntity(entityId)
    for componentType, _ in pairs(EntityManager.components) do
        EntityManager.components[componentType][entityId] = nil
    end
end

-- Get all entities that have a specific component
function EntityManager.getEntitiesWith(componentType)
    local entities = {}
    if EntityManager.components[componentType] then
        for entityId, _ in pairs(EntityManager.components[componentType]) do
            table.insert(entities, entityId)
        end
    end
    return entities
end

-- Get all entities that have ALL specified components
function EntityManager.getEntitiesWithAll(componentTypes)
    local entities = {}
    local firstComponentType = componentTypes[1]
    
    if EntityManager.components[firstComponentType] then
        for entityId, _ in pairs(EntityManager.components[firstComponentType]) do
            local hasAll = true
            for i = 2, #componentTypes do
                if not EntityManager.hasComponent(entityId, componentTypes[i]) then
                    hasAll = false
                    break
                end
            end
            if hasAll then
                table.insert(entities, entityId)
            end
        end
    end
    
    return entities
end

-- Debug: Print all entities and their components
function EntityManager.debugPrint()
    print("🔍 EntityManager Debug:")
    print("  Next Entity ID:", EntityManager.nextEntityId)
    for componentType, componentStorage in pairs(EntityManager.components) do
        print("  Component:", componentType)
        for entityId, componentData in pairs(componentStorage) do
            print("    Entity", entityId, ":", componentData)
        end
    end
end

return EntityManager 