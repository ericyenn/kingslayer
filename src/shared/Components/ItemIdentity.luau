-- ItemIdentity component for storing item identification data
local ItemIdentity = {}
ItemIdentity.__index = ItemIdentity

-- Create a new ItemIdentity component
function ItemIdentity.new(config)
    local self = setmetatable({
        -- Item identification
        itemId = config.itemId, -- The unique item ID (e.g., "iron_sword", "revive_plush")
        itemName = config.itemName, -- Display name (e.g., "Iron Sword", "Revive Plush")
        category = config.category, -- Item category (e.g., "tool", "armor", "item")
        
        -- Metadata
        rarity = config.rarity or "common",
        level = config.level or 1,
        
        -- Timestamp for tracking
        createdAt = tick()
    }, ItemIdentity)
    
    return self
end

-- Get the item ID
function ItemIdentity:GetItemId()
    return self.itemId
end

-- Get the display name
function ItemIdentity:GetItemName()
    return self.itemName
end

-- Get the category
function ItemIdentity:GetCategory()
    return self.category
end

-- Get the rarity
function ItemIdentity:GetRarity()
    return self.rarity
end

-- Get the level
function ItemIdentity:GetLevel()
    return self.level
end

-- Check if this item matches a specific item ID
function ItemIdentity:MatchesItemId(targetItemId)
    return self.itemId == targetItemId
end

-- Get all identification data
function ItemIdentity:GetIdentityData()
    return {
        itemId = self.itemId,
        itemName = self.itemName,
        category = self.category,
        rarity = self.rarity,
        level = self.level,
        createdAt = self.createdAt
    }
end

-- Clean up (called when component is removed)
function ItemIdentity:Destroy()
    -- Nothing special to clean up for now
end

return ItemIdentity 