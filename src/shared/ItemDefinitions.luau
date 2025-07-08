-- Item definitions with component configurations
local ItemDefinitions = {}
local Categories = require(script.Parent.ItemCategory)
local ActionConstants = require(script.Parent.ActionConstants)
local Color3 = Color3 -- Assume Color3 is globally available or imported if necessary

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

ItemDefinitions.items = {
    -- TOOLS - All use generic attack action with different damage
    stick = {
        name = "Stick",
        description = "A simple wooden stick. Basic weapon for combat.",
        model = "StickModel",
        category = Categories.Tool,
        actionType = ActionConstants.Tool.ATTACK,
        actionData = {
            damage = 5,
            chargeMultiplier = 2.0, -- Charged attack does 2x damage (10 total)
            criticalMultiplier = 3.0 -- Critical attack does 3x damage (15 total)
        },
        components = {
            Draggable = {
                force = 8000,
                maxDistance = 35,
                dampening = 0.6
            },
            Hoverable = {
                displayName = "Stick",
                description = "A simple wooden stick. Basic weapon for combat."
            },
            Inventoryable = {
                inventoryIcon = "🪵"
            }
        }
    },
    
    cutlass = {
        name = "Cutlass",
        description = "A sharp curved sword. Effective weapon for combat.",
        model = "CutlassModel",
        category = Categories.Tool,
        actionType = ActionConstants.Tool.ATTACK,
        actionData = {
            damage = 15,
            chargeMultiplier = 2.0, -- Charged attack does 2x damage (30 total)
            criticalMultiplier = 3.0 -- Critical attack does 3x damage (45 total)
        },
        components = {
            Draggable = {
                force = 12000,
                maxDistance = 45,
                dampening = 0.7
            },
            Hoverable = {
                displayName = "Cutlass",
                description = "A sharp curved sword. Effective weapon for combat."
            },
            Inventoryable = {
                inventoryIcon = "⚔️"
            }
        }
    },
    
    -- ARMOR - No click functionality, gives health when equipped
    chestplate = {
        name = "Chestplate",
        description = "Heavy armor that protects your torso and provides health.",
        model = "ChestplateModel",
        category = Categories.Armor,
        armorSlot = "chestplate",
        -- No actionType - armor has no click functionality
        components = {
            Draggable = {
                force = 14000,
                maxDistance = 45,
                dampening = 0.8
            },
            Hoverable = {
                displayName = "Chestplate",
                description = "Heavy armor that protects your torso and provides health.",
                highlightColor = Color3.fromRGB(255, 150, 150)
            },
            Inventoryable = {
                stackable = false,
                maxStack = 1,
                category = Categories.Armor,
                inventoryIcon = "🦺",
                canPickup = true
            }
        }
    },
    
    -- FUNCTIONAL ITEMS - Placeholder for future customization
    healing_essence = {
        name = "Healing Essence",
        description = "A magical essence with healing properties. Use to restore health.",
        model = "HealingEssenceModel",
        category = Categories.Functional,
        actionType = ActionConstants.Functional.HEALING_ESSENCE,
        actionData = {
            -- Placeholder data - you can customize this later
        },
        components = {
            Draggable = {
                force = 6000,
                maxDistance = 30,
                dampening = 0.5
            },
            Hoverable = {
                displayName = "Healing Essence",
                description = "A magical essence with healing properties. Use to restore health.",
                highlightColor = Color3.fromRGB(34, 139, 34)
            },
            Inventoryable = {
                stackable = true,
                maxStack = 10,
                inventoryIcon = "🌿",
                canPickup = true
            }
        }
    },
    
    -- ITEMS - No click actions, basic materials
    wood = {
        name = "Wood",
        description = "Basic crafting material from trees. Essential for many recipes.",
        model = "WoodModel",
        category = Categories.Item,
        -- No actionType - items have no click actions
        components = {
            Draggable = {
                force = 6000,
                maxDistance = 30,
                dampening = 0.5
            },
            Hoverable = {
                displayName = "Wood",
                description = "Basic crafting material from trees. Essential for many recipes.",
                highlightColor = Color3.fromRGB(139, 69, 19)
            },
            Inventoryable = {
                stackable = false,
                maxStack = 1,
                canPickup = true
            }
        }
    },
    
    stone = {
        name = "Stone",
        description = "Solid rock material. Useful for construction and crafting.",
        model = "StoneModel",
        category = Categories.Item,
        -- No actionType - items have no click actions
        components = {
            Draggable = {
                force = 8000,
                maxDistance = 35,
                dampening = 0.6
            },
            Hoverable = {
                displayName = "Stone",
                description = "Solid rock material. Useful for construction and crafting.",
                highlightColor = Color3.fromRGB(128, 128, 128)
            },
            Inventoryable = {
                stackable = false,
                maxStack = 1,
                canPickup = true
            }
        }
    }
}

-- Get item definition by ID
function ItemDefinitions:GetItem(itemId)
    return self.items[itemId]
end

-- Get all item IDs
function ItemDefinitions:GetAllItemIds()
    local ids = {}
    for id, _ in pairs(self.items) do
        table.insert(ids, id)
    end
    return ids
end

-- Get items by category
function ItemDefinitions:GetItemsByCategory(category)
    local items = {}
    for id, item in pairs(self.items) do
        if item.category == category then
            items[id] = item
        end
    end
    return items
end

-- Get armor items by slot
function ItemDefinitions:GetArmorBySlot(armorSlot)
    local items = {}
    for id, item in pairs(self.items) do
        if item.category == Categories.Armor and item.armorSlot == armorSlot then
            items[id] = item
        end
    end
    return items
end

return ItemDefinitions 