local ItemCategory = {}

ItemCategory.Tool       = "Tool"
ItemCategory.Armor      = "Armor"
ItemCategory.Functional = "Functional"
ItemCategory.Item       = "Item"

-- Define default components for each category
ItemCategory.DEFAULT_COMPONENTS = {
    [ItemCategory.Tool] = {
        Draggable = {
            force = 10000, -- Default force for tools
            maxDistance = 45,
            dampening = 0.7
        },
        Hoverable = {
            highlightColor = Color3.fromRGB(255, 255, 0) -- Default highlight for tools
        },
        Inventoryable = {
            stackable = false,
            maxStack = 1,
            canPickup = true
        }
    },
    [ItemCategory.Armor] = {
        Draggable = {
            force = 10000, -- Default force for armor
            maxDistance = 40,
            dampening = 0.7
        },
        Hoverable = {
            highlightColor = Color3.fromRGB(150, 150, 255) -- Default highlight for armor
        },
        Inventoryable = {
            stackable = false,
            maxStack = 1,
            canPickup = true
        }
    },
    [ItemCategory.Functional] = {
        -- Functional items might have varied defaults, start minimal
        Inventoryable = {
            stackable = false,
            maxStack = 1,
            canPickup = true
        }
    },
    [ItemCategory.Item] = {
        -- Generic items are inert, typically just inventoryable
        Inventoryable = {
            stackable = true, -- Common for generic items
            maxStack = 64,
            canPickup = true
        }
    }
}

-- Define a mapping of categories to their client-side "use" handler function names
-- The ToolHandler will use these names to call the correct function on the appropriate system.
ItemCategory.USE_HANDLERS = {
    [ItemCategory.Tool]       = "ToolSystem.Use",
    [ItemCategory.Armor]      = "ArmorSystem.TryEquipFromUse",
    [ItemCategory.Functional] = "FunctionalSystem.Use",
    -- No entry for Item, as it's a no-op by default
}

return ItemCategory 