-- SacrificeValidator.luau
-- Simplified sacrifice validation system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local AltarConfig = require(ReplicatedStorage.Shared.AltarConfig)

local SacrificeValidator = {}

-- Check if a part is a valid sacrifice
function SacrificeValidator:IsValidSacrifice(part)
    -- Check if the part or its parent has the "Sacrifice" tag
    if CollectionService:HasTag(part, "Sacrifice") then
        return true
    end
    
    -- Check if parent is a sacrifice (for model parts)
    if part.Parent and CollectionService:HasTag(part.Parent, "Sacrifice") then
        return true
    end
    
    -- Check if the part or its parent has the "PlayerSacrifice" tag
    if CollectionService:HasTag(part, "PlayerSacrifice") then
        return true
    end
    
    -- Check if parent is a player sacrifice (for model parts)
    if part.Parent and CollectionService:HasTag(part.Parent, "PlayerSacrifice") then
        return true
    end
    
    return false
end

-- Get the actual sacrifice object (handles model parts)
function SacrificeValidator:GetSacrificeObject(part)
    -- If the part itself is tagged, return it
    if CollectionService:HasTag(part, "Sacrifice") then
        return part
    end
    
    -- If the parent is tagged, return the parent
    if part.Parent and CollectionService:HasTag(part.Parent, "Sacrifice") then
        return part.Parent
    end
    
    -- If the part itself is player sacrifice tagged, return it
    if CollectionService:HasTag(part, "PlayerSacrifice") then
        return part
    end
    
    -- If the parent is player sacrifice tagged, return the parent
    if part.Parent and CollectionService:HasTag(part.Parent, "PlayerSacrifice") then
        return part.Parent
    end
    
    return nil
end

-- Validate sacrifice count
function SacrificeValidator:ValidateSacrificeCount(count)
    return count >= AltarConfig.SETTINGS.requiredSacrifices
end

-- Check if sacrifices are unique (not the same ragdoll counted multiple times)
function SacrificeValidator:AreSacrificesUnique(sacrifices)
    local seen = {}
    for _, sacrifice in ipairs(sacrifices) do
        if seen[sacrifice] then
            return false -- Duplicate found
        end
        seen[sacrifice] = true
    end
    return true
end

return SacrificeValidator 