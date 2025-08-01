-- BreakableDefinitions.luau
-- Breakable object definitions with component configurations

local BreakableDefinitions = {}

-- Import Components from our custom ECS
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Breakable = require(ReplicatedStorage.Shared.Components.Breakable)
local BreakableVisual = require(ReplicatedStorage.Shared.Components.BreakableVisual)

-- Helper function for deep merging tables
local function mergeTables(t1, t2)
    local t3 = {}
    for k, v in pairs(t1) do
        t3[k] = v
    end
    for k, v in pairs(t2) do
        if type(v) == "table" and type(t3[k]) == "table" then
            t3[k] = mergeTables(t3[k], v)
        else
            t3[k] = v
        end
    end
    return t3
end

-- Breakable definitions organized by type
BreakableDefinitions.breakables = {
    -- TREES
    tree = {
        name = "Tree",
        description = "A tall tree that can be chopped down.",
        model = "TreeModel",
        breakableType = "tree",
        requiredTool = "axe",
        
        -- Health and stats
        health = 100,
        maxHealth = 100,
        
        -- Drop configuration
        dropItems = {
            { item = "log", chance = 1.0, quantity = {min = 1, max = 3} }
        },
        
        -- Respawn settings
        respawnTime = 300, -- 5 minutes
        
        -- Visual/Audio
        breakAnimation = "tree_fall",
        soundEffect = "tree_break",
        
        -- Visual component settings

    },
    
    -- ROCKS
    rock = {
        name = "Rock",
        description = "A solid rock that can be mined.",
        model = "RockModel",
        breakableType = "rock",
        requiredTool = "pickaxe",
        
        -- Health and stats
        health = 150,
        maxHealth = 150,
        
        -- Drop configuration
        dropItems = {
            { item = "rock", chance = 1.0, quantity = {min = 1, max = 2} }
        },
        
        -- Respawn settings
        respawnTime = 240, -- 4 minutes
        
        -- Visual/Audio
        breakAnimation = "rock_break",
        soundEffect = "rock_break",
        

    },
    
    -- CRYSTALS
    crystal = {
        name = "Crystal",
        description = "A magical crystal that requires a special tool.",
        model = "CrystalModel",
        breakableType = "crystal",
        requiredTool = "pickaxe", -- Crystals now need pickaxe
        
        -- Health and stats
        health = 200,
        maxHealth = 200,
        
        -- Drop configuration
        dropItems = {
            { item = "crystal", chance = 1.0, quantity = {min = 1, max = 1} }
        },
        
        -- Respawn settings
        respawnTime = 600, -- 10 minutes
        
        -- Visual/Audio
        breakAnimation = "crystal_break",
        soundEffect = "crystal_break",
        

    }
}

-- Get breakable definition by ID
function BreakableDefinitions:GetBreakable(breakableId)
    return self.breakables[breakableId]
end

-- Get all breakable IDs
function BreakableDefinitions:GetAllBreakableIds()
    local ids = {}
    for id, _ in pairs(self.breakables) do
        table.insert(ids, id)
    end
    return ids
end

-- Get breakables by type
function BreakableDefinitions:GetBreakablesByType(breakableType)
    local breakables = {}
    for id, breakable in pairs(self.breakables) do
        if breakable.breakableType == breakableType then
            breakables[id] = breakable
        end
    end
    return breakables
end

-- Create components for a breakable object
function BreakableDefinitions:CreateBreakableComponents(breakableId)
    local breakableDef = self:GetBreakable(breakableId)
    if not breakableDef then
        warn("Breakable definition not found: " .. tostring(breakableId))
        return nil
    end
    
    return {
        Breakable = Breakable.new({
            health = breakableDef.health,
            maxHealth = breakableDef.maxHealth,
            breakableType = breakableDef.breakableType,
            requiredTool = breakableDef.requiredTool,
            dropItems = breakableDef.dropItems,
            respawnTime = breakableDef.respawnTime,
            breakAnimation = breakableDef.breakAnimation,
            soundEffect = breakableDef.soundEffect
        }),
        BreakableVisual = BreakableVisual.new()
    }
end

-- Get random breakable of specific type
function BreakableDefinitions:GetRandomBreakableOfType(breakableType)
    local breakablesOfType = self:GetBreakablesByType(breakableType)
    local ids = {}
    for id, _ in pairs(breakablesOfType) do
        table.insert(ids, id)
    end
    
    if #ids > 0 then
        return ids[math.random(1, #ids)]
    end
    
    return nil
end

-- Get random breakable (any type)
function BreakableDefinitions:GetRandomBreakable()
    local allIds = self:GetAllBreakableIds()
    if #allIds > 0 then
        return allIds[math.random(1, #allIds)]
    end
    return nil
end

-- Validate breakable definition
function BreakableDefinitions:ValidateBreakableDefinition(breakableId)
    local breakable = self:GetBreakable(breakableId)
    if not breakable then
        return false, "Breakable not found: " .. tostring(breakableId)
    end
    
    -- Validate breakable type
    local validTypes = {"tree", "rock", "crystal"}
    local isValid = false
    for _, validType in ipairs(validTypes) do
        if breakable.breakableType == validType then
            isValid = true
            break
        end
    end
    if not isValid then
        return false, "Invalid breakable type: " .. tostring(breakable.breakableType)
    end
    
    -- Validate required tool
    local validTools = {"axe", "pickaxe", "crystal_tool"}
    local hasValidTool = false
    for _, validTool in ipairs(validTools) do
        if breakable.requiredTool == validTool then
            hasValidTool = true
            break
        end
    end
    if not hasValidTool then
        return false, "Invalid required tool: " .. tostring(breakable.requiredTool)
    end
    
    if not breakable.health or breakable.health <= 0 then
        return false, "Breakable must have valid health"
    end
    
    return true
end

-- Debug function to print all breakables
function BreakableDefinitions:DebugPrintAllBreakables()
    print("🌳 Breakable Definitions Debug:")
    for id, breakable in pairs(self.breakables) do
        print(string.format("  %s (%s): %s", id, breakable.breakableType, breakable.name))
        print(string.format("    Health: %d, Required Tool: %s", 
            breakable.health, breakable.requiredTool))
    end
end

print("🌳 BreakableDefinitions loaded with " .. #BreakableDefinitions:GetAllBreakableIds() .. " breakable types")

return BreakableDefinitions 