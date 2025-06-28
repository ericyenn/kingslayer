-- Hoverable component for items
local Hoverable = {}
Hoverable.__index = Hoverable

-- Create a new Hoverable component
function Hoverable.new(config)
    local self = setmetatable({
        -- Configuration
        displayName = config.displayName or "Item",
        highlightColor = config.highlightColor or Color3.fromRGB(255, 255, 0),
        showHighlight = config.showHighlight ~= false, -- Default true
        
        -- State
        isHovered = false,
        selectionBox = nil
    }, Hoverable)
    
    return self
end

-- Start hovering (no visual highlight, just prepare for name display)
function Hoverable:StartHover(item)
    if self.isHovered then return end
    
    self.isHovered = true
    
    -- No visual highlighting - removed selection box creation
end

-- Stop hovering (no cleanup needed since no visual highlight)
function Hoverable:StopHover(item)
    if not self.isHovered then return end
    
    self.isHovered = false
    
    -- No selection box to clean up
end

-- Get the display name
function Hoverable:GetDisplayName()
    return self.displayName
end

-- Check if currently being hovered
function Hoverable:IsHovered()
    return self.isHovered
end

-- Clean up (called when component is removed)
function Hoverable:Destroy()
    if self.isHovered then
        self:StopHover()
    end
end

return Hoverable 