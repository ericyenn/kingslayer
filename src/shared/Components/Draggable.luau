-- Draggable component for items
local Draggable = {}
Draggable.__index = Draggable

-- Create a new Draggable component
function Draggable.new(config)
    local self = setmetatable({
        -- Configuration
        force = config.force or 16000,
        maxDistance = config.maxDistance or 50,
        dampening = config.dampening or 0.8,
        
        -- State
        isDragging = false,
        alignPosition = nil,
        attachment = nil,
        dragConnection = nil,
        
        -- Internal
        camera = workspace.CurrentCamera
    }, Draggable)
    
    return self
end

-- Start dragging this item
function Draggable:StartDrag(item, mouse)
    if self.isDragging then return end
    
    self.isDragging = true
    
    -- Create attachment for AlignPosition
    self.attachment = Instance.new("Attachment")
    self.attachment.Parent = item
    
    -- Create AlignPosition for smooth physics-based dragging
    self.alignPosition = Instance.new("AlignPosition")
    self.alignPosition.MaxForce = self.force
    self.alignPosition.MaxVelocity = math.huge
    self.alignPosition.Responsiveness = 200
    self.alignPosition.Attachment0 = self.attachment
    self.alignPosition.Parent = item
    
    -- Connect to mouse movement
    self.dragConnection = mouse.Move:Connect(function()
        self:UpdateDrag(item, mouse)
    end)
    
    -- Initial position update
    self:UpdateDrag(item, mouse)
    
    print("Started dragging with AlignPosition:", item.Name)
end

-- Update drag position based on mouse
function Draggable:UpdateDrag(item, mouse)
    if not self.isDragging or not self.alignPosition then return end
    
    -- Cast ray from camera through mouse position
    local ray = self.camera:ScreenPointToRay(mouse.X, mouse.Y)
    
    -- Calculate target position at max distance
    local targetPosition = ray.Origin + ray.Direction * self.maxDistance
    
    -- Set the align position target
    self.alignPosition.Position = targetPosition
    
    -- Debug: Print position updates (only occasionally to avoid spam)
    if math.random() < 0.1 then -- 10% chance to print
        print("Dragging", item.Name, "to position:", targetPosition)
    end
end

-- Stop dragging this item
function Draggable:StopDrag(item)
    if not self.isDragging then return end
    
    self.isDragging = false
    
    -- Clean up drag connection
    if self.dragConnection then
        self.dragConnection:Disconnect()
        self.dragConnection = nil
    end
    
    -- Clean up align position
    if self.alignPosition then
        self.alignPosition:Destroy()
        self.alignPosition = nil
    end
    
    -- Clean up attachment
    if self.attachment then
        self.attachment:Destroy()
        self.attachment = nil
    end
    
    print("Stopped dragging:", item and item.Name or "unknown")
end

-- Check if currently being dragged
function Draggable:IsDragging()
    return self.isDragging
end

-- Clean up (called when component is removed)
function Draggable:Destroy()
    if self.isDragging then
        self.isDragging = false
        
        -- Clean up connections
        if self.dragConnection then
            self.dragConnection:Disconnect()
        end
        
        -- Clean up constraints
        if self.alignPosition then
            self.alignPosition:Destroy()
        end
        
        if self.attachment then
            self.attachment:Destroy()
        end
    end
    
    -- Clear all references
    self.dragConnection = nil
    self.alignPosition = nil
    self.attachment = nil
    self.isDragging = false
end

return Draggable 