-- Inventoryable component for items that can be stored in inventory
local Inventoryable = {}
Inventoryable.__index = Inventoryable

-- Create a new Inventoryable component
function Inventoryable.new(config)
    local self = setmetatable({
        -- Configuration
        canPickup = config.canPickup ~= false, -- Default true
        stackable = config.stackable or false,
        maxStack = config.maxStack or 1,
        category = config.category or "Items",
        inventoryIcon = config.inventoryIcon or "",
        
        -- State
        isInInventory = false,
        hotbarSlot = nil, -- Which slot (1-10) or nil if not equipped
        stackCount = 1,
        originalCFrame = nil, -- Where it was in world before pickup
        originalParent = nil -- Original parent before pickup
    }, Inventoryable)
    
    return self
end

-- Move item to inventory
function Inventoryable:MoveToInventory(slot)
    if self.isInInventory then return false end
    
    self.isInInventory = true
    self.hotbarSlot = slot
    
    return true
end

-- Move item back to world
function Inventoryable:MoveToWorld(newCFrame, newParent)
    if not self.isInInventory then return false end
    
    self.isInInventory = false
    self.hotbarSlot = nil
    self.originalCFrame = newCFrame
    self.originalParent = newParent
    
    return true
end

-- Check if item can be picked up
function Inventoryable:CanPickup()
    return self.canPickup and not self.isInInventory
end

-- Get display information
function Inventoryable:GetDisplayInfo()
    return {
        stackable = self.stackable,
        stackCount = self.stackCount,
        maxStack = self.maxStack,
        category = self.category,
        icon = self.inventoryIcon
    }
end

-- Clean up (called when component is removed)
function Inventoryable:Destroy()
    -- Nothing special to clean up for now
end

return Inventoryable 