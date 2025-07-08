-- ItemMapping.luau
-- Maps TraderData item names to ItemDefinitions IDs and provides trade utilities

local ItemMapping = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)

-- Mapping from TraderData item names to ItemDefinitions IDs
-- This allows the trader system to reference actual game items
ItemMapping.TraderToGameItems = {
    -- Trader items that correspond to actual game items
    ["Iron Sword"] = "iron_sword", -- Would need to be added to ItemDefinitions
    ["Steel Armor"] = "steel_armor", -- Would need to be added to ItemDefinitions
    ["Helmet"] = "helmet", -- Already exists in ItemDefinitions
    ["Chestplate"] = "chestplate", -- Already exists in ItemDefinitions
    ["Boots"] = "boots", -- Already exists in ItemDefinitions
    
    -- Basic materials and currency (these would be simple stackable items)
    ["Wood"] = "wood", -- Would need to be added to ItemDefinitions
    ["Iron Ingot"] = "iron_ingot", -- Would need to be added to ItemDefinitions
    ["Silver Coin"] = "silver_coin", -- Would need to be added to ItemDefinitions
    ["Healing Herbs"] = "healing_herbs", -- Would need to be added to ItemDefinitions
    ["Crystal Orb"] = "crystal_orb", -- Would need to be added to ItemDefinitions
    ["Fire Gem"] = "fire_gem", -- Would need to be added to ItemDefinitions
    ["Dragon Scale"] = "dragon_scale", -- Would need to be added to ItemDefinitions
    ["Enchanted Book"] = "enchanted_book", -- Would need to be added to ItemDefinitions
}

-- Reverse mapping for quick lookups
ItemMapping.GameToTraderItems = {}
for traderName, gameId in pairs(ItemMapping.TraderToGameItems) do
    ItemMapping.GameToTraderItems[gameId] = traderName
end

-- Check if a trader item name maps to a valid game item
function ItemMapping:IsValidTraderItem(traderItemName)
    local gameItemId = self.TraderToGameItems[traderItemName]
    if not gameItemId then
        return false, "No mapping found for trader item: " .. traderItemName
    end
    
    local itemDefinition = ItemDefinitions:GetItem(gameItemId)
    if not itemDefinition then
        return false, "Game item definition not found: " .. gameItemId
    end
    
    return true, gameItemId
end

-- Get the game item ID for a trader item name
function ItemMapping:GetGameItemId(traderItemName)
    return self.TraderToGameItems[traderItemName]
end

-- Get the trader item name for a game item ID
function ItemMapping:GetTraderItemName(gameItemId)
    return self.GameToTraderItems[gameItemId]
end

-- Check if an inventory item matches a trader requirement
function ItemMapping:DoesInventoryItemMatch(inventoryItemName, requiredTraderItemName)
    -- Direct name match
    if inventoryItemName == requiredTraderItemName then
        return true
    end
    
    -- Check if the inventory item's name matches the trader item
    local gameItemId = self.TraderToGameItems[requiredTraderItemName]
    if gameItemId then
        local itemDefinition = ItemDefinitions:GetItem(gameItemId)
        if itemDefinition and itemDefinition.name == inventoryItemName then
            return true
        end
    end
    
    return false
end

-- Validate if a player's inventory contains the required items for a trade
function ItemMapping:ValidateTradeRequirements(playerInventory, requirements)
    local missingItems = {}
    local validationResults = {}
    
    for _, requirement in ipairs(requirements) do
        local requiredItem = requirement.item
        local requiredQuantity = requirement.quantity
        local foundQuantity = 0
        local foundSlots = {}
        
        -- Search through player's inventory
        for slot, inventoryItem in pairs(playerInventory) do
            if inventoryItem and self:DoesInventoryItemMatch(inventoryItem.itemName, requiredItem) then
                -- For now, assume all items have quantity 1 (non-stackable)
                -- TODO: Add proper stackable item support
                foundQuantity = foundQuantity + 1
                table.insert(foundSlots, slot)
                
                if foundQuantity >= requiredQuantity then
                    break
                end
            end
        end
        
        validationResults[requiredItem] = {
            required = requiredQuantity,
            found = foundQuantity,
            slots = foundSlots,
            satisfied = foundQuantity >= requiredQuantity
        }
        
        if foundQuantity < requiredQuantity then
            table.insert(missingItems, {
                item = requiredItem,
                required = requiredQuantity,
                found = foundQuantity,
                missing = requiredQuantity - foundQuantity
            })
        end
    end
    
    local isValid = #missingItems == 0
    return isValid, validationResults, missingItems
end

return ItemMapping 