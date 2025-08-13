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
        id = "stick",
        name = "Cane",
        description = "Just a stick for walking. Not meant for combat, but will do.",
        model = "CaneModel",
        category = Categories.Tool,
        actionType = ActionConstants.Tool.ATTACK,
        actionData = {
            damage = 5,
            chargeMultiplier = 2.0, -- Charged attack does 2x damage (10 total)
            criticalMultiplier = 3.0, -- Critical attack does 3x damage (15 total)
            hitboxLength = 1.5 -- Short range for walking stick
        },
        components = {
            Draggable = {
                force = 8000,
                maxDistance = 35,
                dampening = 0.6
            },
            Hoverable = {
                displayName = "Walking Stick",
                description = "Just a stick for walking. Not meant for combat, but will do."
            },
            Inventoryable = {
                inventoryIcon = "🪵"
            }
        }
    },
    
    cutlass = {
        id = "cutlass",
        name = "Cutlass",
        description = "A sharp curved sword. Effective weapon for combat.",
        model = "CutlassModel",
        category = Categories.Tool,
        actionType = ActionConstants.Tool.ATTACK,
        actionData = {
            damage = 15,
            chargeMultiplier = 2.0, -- Charged attack does 2x damage (30 total)
            criticalMultiplier = 3.0, -- Critical attack does 3x damage (45 total)
            cooldown = 0.4, -- Attack cooldown in seconds
            hitboxLength = 2.5 -- Medium range for sword
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
    
    -- BREAKABLE TOOLS
    axe = {
        id = "axe",
        name = "Axe",
        description = "A tool for chopping trees and wood.",
        model = "AxeModel",
        category = Categories.Tool,
        actionType = ActionConstants.Tool.ATTACK,
        actionData = {
            damage = 20,
            chargeMultiplier = 2.0,
            criticalMultiplier = 3.0,
            breakableDamage = 25, -- Special damage for breakable objects
            cooldown = 0.8, -- Attack cooldown in seconds
            hitboxLength = 10.0 -- Long range for axe
        },
        components = {
            Draggable = {
                force = 12000,
                maxDistance = 45,
                dampening = 0.7
            },
            Hoverable = {
                displayName = "Axe",
                description = "A tool for chopping trees and wood."
            },
            Inventoryable = {
                inventoryIcon = "🪓"
            }
        },
        tags = {"Axe"} -- Tag for breakable system
    },
    
    pickaxe = {
        id = "pickaxe",
        name = "Pickaxe",
        description = "A tool for mining rocks and ore.",
        model = "PickaxeModel",
        category = Categories.Tool,
        actionType = ActionConstants.Tool.ATTACK,
        actionData = {
            damage = 15,
            chargeMultiplier = 2.0,
            criticalMultiplier = 3.0,
            breakableDamage = 30, -- Special damage for breakable objects
            cooldown = 0.6 -- Attack cooldown in seconds
        },
        components = {
            Draggable = {
                force = 12000,
                maxDistance = 45,
                dampening = 0.7
            },
            Hoverable = {
                displayName = "Pickaxe",
                description = "A tool for mining rocks and ore."
            },
            Inventoryable = {
                inventoryIcon = "⛏️"
            }
        },
        tags = {"Pickaxe"} -- Tag for breakable system
    },
    
    -- ARMOR - No click functionality, gives health when equipped
    chestplate = {
        id = "chestplate",
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
        id = "healing_essence",
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
    
    summoner = {
        id = "summoner",
        name = "Summoner",
        description = "A mysterious artifact with summoning powers. Single use item.",
        model = "SummonerModel",
        category = Categories.Functional,
        actionType = ActionConstants.Functional.SUMMONER,
        actionData = {
            -- Placeholder data - you can customize this later
        },
        components = {
            Draggable = {
                force = 7000,
                maxDistance = 35,
                dampening = 0.6
            },
            Hoverable = {
                displayName = "Summoner",
                description = "A mysterious artifact with summoning powers. Single use item.",
                highlightColor = Color3.fromRGB(128, 0, 128)
            },
            Inventoryable = {
                stackable = false,
                maxStack = 1,
                inventoryIcon = "🔮",
                canPickup = true
            }
        }
    },
    
    revive_plush = {
        id = "revive_plush",
        name = "Revive Plush",
        description = "A magical plush toy that can bring players back to life. Use near a dead player to revive them.",
        model = "RevivePlushModel",
        category = Categories.Functional,
        actionType = ActionConstants.Functional.REVIVE_PLUSH,
        preventClickConsume = true, -- Prevent normal click consumption
        actionData = {
            -- Revive action data
        },
        components = {
            Draggable = {
                force = 6000,
                maxDistance = 30,
                dampening = 0.5
            },
            Hoverable = {
                displayName = "Revive Plush",
                description = "A magical plush toy that can bring players back to life. Use near a dead player to revive them.",
                highlightColor = Color3.fromRGB(255, 182, 193) -- Light pink
            },
            Inventoryable = {
                stackable = false,
                maxStack = 1,
                inventoryIcon = "🧸",
                canPickup = true
            }
        }
    },
    
    philosophers_stone = {
        id = "philosophers_stone",
        name = "Philosopher's Stone",
        description = "A legendary artifact with the power to transmute materials and grant eternal life. The ultimate reward for the most sacred of sacrifices.",
        model = "PhilosophersStoneModel",
        category = Categories.Functional,
        actionType = ActionConstants.Functional.PHILOSOPHERS_STONE,
        actionData = {
            -- Philosopher's stone action data - placeholder for future customization
        },
        components = {
            Draggable = {
                force = 8000,
                maxDistance = 40,
                dampening = 0.7
            },
            Hoverable = {
                displayName = "Philosopher's Stone",
                description = "A legendary artifact with the power to transmute materials and grant eternal life. The ultimate reward for the most sacred of sacrifices.",
                highlightColor = Color3.fromRGB(255, 215, 0) -- Gold color
            },
            Inventoryable = {
                stackable = false,
                maxStack = 1,
                inventoryIcon = "💎",
                canPickup = true
            }
        }
    },

    -- COMPASS (consumable unlock)
    compass = {
        id = "compass",
        name = "Compass",
        description = "Consume to unlock a directional compass HUD.",
        model = "CompassModel",
        category = Categories.Functional,
        actionType = ActionConstants.Functional.UNLOCK_COMPASS,
        components = {
            Draggable = { force = 6000, maxDistance = 30, dampening = 0.5 },
            Hoverable = {
                displayName = "Compass",
                description = "Consume to unlock a directional compass HUD.",
                highlightColor = Color3.fromRGB(135, 206, 235)
            },
            Inventoryable = {
                stackable = false,
                maxStack = 1,
                inventoryIcon = "🧭",
                canPickup = true
            }
        }
    },

    -- CLOCK (consumable unlock)
    clock = {
        id = "clock",
        name = "Clock",
        description = "Consume to unlock the clock display.",
        model = "ClockModel",
        category = Categories.Functional,
        actionType = ActionConstants.Functional.UNLOCK_CLOCK,
        components = {
            Draggable = { force = 6000, maxDistance = 30, dampening = 0.5 },
            Hoverable = {
                displayName = "Clock",
                description = "Consume to unlock the clock display.",
                highlightColor = Color3.fromRGB(135, 206, 235)
            },
            Inventoryable = {
                stackable = false,
                maxStack = 1,
                inventoryIcon = "⏰",
                canPickup = true
            }
        }
    },
    
    -- ITEMS - No click actions, basic materials
    wood = {
        id = "wood",
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
        id = "stone",
        name = "Stone",
        description = "Solid rock material. Useful for construction and crafting.",
        model = "StoneModel",
        category = Categories.Item,
        -- No actionType - items have no click actions
        components = {
            Draggable = {
                force = 6000,
                maxDistance = 30,
                dampening = 0.5
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
    },
    
    -- BREAKABLE DROPS
    log = {
        id = "log",
        name = "Log",
        description = "A wooden log from a tree.",
        model = "LogModel",
        category = Categories.Item,
        components = {
            Draggable = {
                force = 8000,
                maxDistance = 35,
                dampening = 0.6
            },
            Hoverable = {
                displayName = "Log",
                description = "A wooden log from a tree.",
                highlightColor = Color3.fromRGB(139, 69, 19)
            },
            Inventoryable = {
                inventoryIcon = "🪵",
                stackable = true,
                maxStack = 10,
                canPickup = true
            }
        }
    },
    
    rock = {
        id = "rock",
        name = "Rock",
        description = "A solid rock from mining.",
        model = "RockModel",
        category = Categories.Item,
        components = {
            Draggable = {
                force = 8000,
                maxDistance = 35,
                dampening = 0.6
            },
            Hoverable = {
                displayName = "Rock",
                description = "A solid rock from mining.",
                highlightColor = Color3.fromRGB(128, 128, 128)
            },
            Inventoryable = {
                inventoryIcon = "🪨",
                stackable = true,
                maxStack = 10,
                canPickup = true
            }
        }
    },
    
    crystal = {
        id = "crystal",
        name = "Crystal",
        description = "A beautiful crystal with magical properties.",
        model = "CrystalModel",
        category = Categories.Item,
        components = {
            Draggable = {
                force = 8000,
                maxDistance = 35,
                dampening = 0.6
            },
            Hoverable = {
                displayName = "Crystal",
                description = "A beautiful crystal with magical properties.",
                highlightColor = Color3.fromRGB(138, 43, 226)
            },
            Inventoryable = {
                inventoryIcon = "💎",
                stackable = true,
                maxStack = 5,
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