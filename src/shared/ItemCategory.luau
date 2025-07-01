--[[
ItemCategory
============
Central table enumerating item categories and shared configs.
Returns a single table with:
  • Tool, Armor, Functional, Item category constants.
  • DEFAULT_COMPONENTS : per-category default component property overrides.
  • USE_HANDLERS      : category→handler module name (client side).
--]]

local ItemCategory = {}

-- Simple enum-like identifiers
ItemCategory.Tool       = "tool"
ItemCategory.Armor      = "armor"
ItemCategory.Functional = "functional"
ItemCategory.Item       = "item"

-- Component defaults that get merged into each item definition
ItemCategory.DEFAULT_COMPONENTS = {
    [ItemCategory.Tool] = {
        Draggable = { force = 12000, maxDistance = 45, dampening = 0.75 },
        Hoverable = { highlightColor = Color3.fromRGB(255, 255, 0) }, -- yellow
        Inventoryable = { stackable = false, maxStack = 1, inventoryIcon = "❔", canPickup = true },
    },
    [ItemCategory.Armor] = {
        Draggable = { force = 10000, maxDistance = 40, dampening = 0.7 },
        Hoverable = { highlightColor = Color3.fromRGB(150, 150, 255) }, -- light blue
        Inventoryable = { stackable = false, maxStack = 1, inventoryIcon = "🗡️", canPickup = true },
    },
    [ItemCategory.Functional] = {
        Draggable = { force = 9000, maxDistance = 40, dampening = 0.7 },
        Hoverable = { highlightColor = Color3.fromRGB(255, 200, 150) },
        Inventoryable = { stackable = false, maxStack = 1, inventoryIcon = "⚙️", canPickup = true },
    },
    [ItemCategory.Item] = {
        Draggable = { force = 8000, maxDistance = 35, dampening = 0.6 },
        Hoverable = { highlightColor = Color3.fromRGB(200, 200, 200) },
        Inventoryable = { stackable = true, maxStack = 20, inventoryIcon = "📦", canPickup = true },
    },
}

-- (Client-side) table that maps category to handler global names used by ToolHandler
ItemCategory.USE_HANDLERS = {
    [ItemCategory.Tool]       = "ToolSystem",
    [ItemCategory.Armor]      = "ArmorSystem",
    [ItemCategory.Functional] = "FunctionalSystem",
}

return ItemCategory 