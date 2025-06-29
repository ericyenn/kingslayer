-- Item definitions with component configurations
local ItemDefinitions = {}
local Categories = require(script.Parent.ItemCategory)
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
    hammer = {
        name = "Hammer",
        description = "A sturdy tool for construction and repairs. Perfect for driving nails and breaking things.",
        model = "HammerModel", -- Reference to model in ReplicatedStorage
        category = Categories.Tool,
        mouseDownAction = "hammer_action",
        components = {
            -- Draggable, Hoverable, Inventoryable components will be merged from defaults
            -- Only specify unique overrides here
            Draggable = {
                force = 16000, -- Override default force
                maxDistance = 50, -- Override default maxDistance
                dampening = 0.8 -- Override default dampening
            },
            Hoverable = {
                displayName = "Hammer",
                description = "A sturdy tool for construction and repairs. Perfect for driving nails and breaking things."
                -- highlightColor will come from default
            },
            Inventoryable = {
                -- category field is now at top-level, not in Inventoryable component
                inventoryIcon = "🔨"
            }
        }
    },
    
    wrench = {
        name = "Wrench",
        description = "An adjustable wrench for mechanical work. Essential for any toolkit.",
        model = "WrenchModel",
        category = Categories.Tool,
        mouseDownAction = "wrench_action",
        components = {
            Draggable = {
                force = 12000,
                maxDistance = 45,
                dampening = 0.7
            },
            Hoverable = {
                displayName = "Wrench",
                description = "An adjustable wrench for mechanical work. Essential for any toolkit."
            },
            Inventoryable = {
                inventoryIcon = "🔧"
            }
        }
    },
    
    screwdriver = {
        name = "Screwdriver",
        description = "A precision tool for screws and small fasteners. Handle with care.",
        model = "ScrewdriverModel",
        category = Categories.Tool,
        mouseDownAction = "screwdriver_action",
        components = {
            Draggable = {
                force = 8000,
                maxDistance = 40,
                dampening = 0.6
            },
            Hoverable = {
                displayName = "Screwdriver",
                description = "A precision tool for screws and small fasteners. Handle with care."
            },
            Inventoryable = {
                inventoryIcon = "🪛"
            }
        }
    },
    
    -- Armor Items
    helmet = {
        name = "Helmet",
        description = "Protective headgear that shields your head from damage.",
        model = "HelmetModel",
        category = Categories.Armor,
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
                description = "Protective headgear that shields your head from damage."
                -- highlightColor will come from default
            },
            Inventoryable = {
                inventoryIcon = "⛑️"
            }
        }
    },
    
    chestplate = {
        name = "Chestplate",
        description = "Heavy armor that protects your torso from attacks.",
        model = "ChestplateModel",
        category = Categories.Armor,
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
                category = Categories.Armor,
                inventoryIcon = "🦺",
                canPickup = true
            }
        }
    },
    
    boots = {
        name = "Boots",
        description = "Sturdy footwear that protects your feet and improves mobility.",
        model = "BootsModel",
        category = Categories.Armor,
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
                category = Categories.Armor,
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