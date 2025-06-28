-- Item definitions with component configurations
local ItemDefinitions = {}

ItemDefinitions.items = {
    hammer = {
        name = "Hammer",
        description = "A sturdy tool for construction and repairs. Perfect for driving nails and breaking things.",
        model = "HammerModel", -- Reference to model in ReplicatedStorage
        itemType = "tool",
        mouseDownAction = "hammer_action",
        components = {
            Draggable = {
                force = 16000,
                maxDistance = 50,
                dampening = 0.8
            },
            Hoverable = {
                displayName = "Hammer",
                description = "A sturdy tool for construction and repairs. Perfect for driving nails and breaking things.",
                highlightColor = Color3.fromRGB(255, 255, 0)
            },
            Inventoryable = {
                stackable = false,
                maxStack = 1,
                category = "Tools",
                inventoryIcon = "🔨",
                canPickup = true
            }
        }
    },
    
    wrench = {
        name = "Wrench",
        description = "An adjustable wrench for mechanical work. Essential for any toolkit.",
        model = "WrenchModel",
        itemType = "tool",
        mouseDownAction = "wrench_action",
        components = {
            Draggable = {
                force = 12000,
                maxDistance = 45,
                dampening = 0.7
            },
            Hoverable = {
                displayName = "Wrench",
                description = "An adjustable wrench for mechanical work. Essential for any toolkit.",
                highlightColor = Color3.fromRGB(0, 255, 255)
            },
            Inventoryable = {
                stackable = false,
                maxStack = 1,
                category = "Tools",
                inventoryIcon = "🔧",
                canPickup = true
            }
        }
    },
    
    screwdriver = {
        name = "Screwdriver",
        description = "A precision tool for screws and small fasteners. Handle with care.",
        model = "ScrewdriverModel",
        itemType = "tool",
        mouseDownAction = "screwdriver_action",
        components = {
            Draggable = {
                force = 8000,
                maxDistance = 40,
                dampening = 0.6
            },
            Hoverable = {
                displayName = "Screwdriver",
                description = "A precision tool for screws and small fasteners. Handle with care.",
                highlightColor = Color3.fromRGB(255, 0, 255)
            },
            Inventoryable = {
                stackable = false,
                maxStack = 1,
                category = "Tools",
                inventoryIcon = "🪛",
                canPickup = true
            }
        }
    },
    
    -- Armor Items
    helmet = {
        name = "Helmet",
        description = "Protective headgear that shields your head from damage.",
        model = "HelmetModel",
        itemType = "armor",
        armorSlot = "helmet",
        mouseDownAction = "armor_helmet_action",
        components = {
            Draggable = {
                force = 10000,
                maxDistance = 40,
                dampening = 0.7
            },
            Hoverable = {
                displayName = "Helmet",
                description = "Protective headgear that shields your head from damage.",
                highlightColor = Color3.fromRGB(150, 150, 255)
            },
            Inventoryable = {
                stackable = false,
                maxStack = 1,
                category = "Armor",
                inventoryIcon = "⛑️",
                canPickup = true
            }
        }
    },
    
    chestplate = {
        name = "Chestplate",
        description = "Heavy armor that protects your torso from attacks.",
        model = "ChestplateModel",
        itemType = "armor",
        armorSlot = "chestplate",
        mouseDownAction = "armor_chestplate_action",
        components = {
            Draggable = {
                force = 14000,
                maxDistance = 45,
                dampening = 0.8
            },
            Hoverable = {
                displayName = "Chestplate",
                description = "Heavy armor that protects your torso from attacks.",
                highlightColor = Color3.fromRGB(255, 150, 150)
            },
            Inventoryable = {
                stackable = false,
                maxStack = 1,
                category = "Armor",
                inventoryIcon = "🦺",
                canPickup = true
            }
        }
    },
    
    boots = {
        name = "Boots",
        description = "Sturdy footwear that protects your feet and improves mobility.",
        model = "BootsModel",
        itemType = "armor",
        armorSlot = "boots",
        mouseDownAction = "armor_boots_action",
        components = {
            Draggable = {
                force = 8000,
                maxDistance = 35,
                dampening = 0.6
            },
            Hoverable = {
                displayName = "Boots",
                description = "Sturdy footwear that protects your feet and improves mobility.",
                highlightColor = Color3.fromRGB(150, 255, 150)
            },
            Inventoryable = {
                stackable = false,
                maxStack = 1,
                category = "Armor",
                inventoryIcon = "🥾",
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

-- Get items by type
function ItemDefinitions:GetItemsByType(itemType)
    local items = {}
    for id, item in pairs(self.items) do
        if item.itemType == itemType then
            items[id] = item
        end
    end
    return items
end

-- Get armor items by slot
function ItemDefinitions:GetArmorBySlot(armorSlot)
    local items = {}
    for id, item in pairs(self.items) do
        if item.itemType == "armor" and item.armorSlot == armorSlot then
            items[id] = item
        end
    end
    return items
end

return ItemDefinitions 