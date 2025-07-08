-- Advanced drag system with raycasting and constraints
local DragSystem = {}

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local Constants = require(ReplicatedStorage.Shared.Constants)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Drag state
local hoveredObject = nil
local grabbedObject = nil
local dragDistance = 5 -- Distance from camera to maintain object

-- Constraint objects
local dragTargetAttachment = nil
local dragObjectAttachment = nil
local alignPosition = nil
local alignOrientation = nil

-- Connections
local heartbeatConnection = nil

function DragSystem:Initialize()
    -- Create drag target attachment in terrain (acts as the "target" for dragging)
    dragTargetAttachment = Instance.new("Attachment")
    dragTargetAttachment.Name = "DragTarget"
    dragTargetAttachment.Parent = workspace.Terrain
    

    
    -- Handle mouse input
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:HandleMouseDown()
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:HandleMouseUp()
        end
    end)
    
    -- Start continuous update loop
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        self:Update()
    end)
    
    print("Advanced drag system initialized")
end

function DragSystem:Update()
    -- Update drag target position
    self:UpdateDragTarget()
    
    -- Update hover detection
    self:UpdateHoverDetection()
    
    -- Check if dragged object is still within range
    self:CheckDragDistance()
end

function DragSystem:UpdateDragTarget()
    if not dragTargetAttachment then return end
    
    -- Position the drag target in front of the camera
    local cameraCFrame = camera.CFrame
    local forwardVector = cameraCFrame.LookVector
    local targetPosition = cameraCFrame.Position + forwardVector * dragDistance
    
    dragTargetAttachment.WorldCFrame = CFrame.new(targetPosition)
end

function DragSystem:UpdateHoverDetection()
    if grabbedObject then return end -- Don't hover while dragging
    
    -- Don't hover draggable objects when tool is equipped
    if self:HasEquippedTool() then
        -- Clear any existing hover state
        if hoveredObject then
            self:StopHover(hoveredObject)
            hoveredObject = nil
        end
        return
    end
    
    -- OPTIMIZATION: Skip hover detection when UIs are open to avoid interference
    if self:IsUIOpen() then
        -- Clear any existing hover state when UI opens
        if hoveredObject then
            self:StopHover(hoveredObject)
            hoveredObject = nil
        end
        return
    end
    
    local hitObject = self:RaycastFromMouse()
    
    if hitObject ~= hoveredObject then
        -- Stop hovering previous object
        if hoveredObject then
            self:StopHover(hoveredObject)
        end
        
        -- Start hovering new object
        if hitObject and self:IsObjectDraggable(hitObject) then
            self:StartHover(hitObject)
            hoveredObject = hitObject
        else
            hoveredObject = nil
        end
    elseif hoveredObject then
        -- Update tooltip position if still hovering the same object
        local ItemTooltip = require(script.Parent.Parent.UI.ItemTooltip)
        local mouse = player:GetMouse()
        ItemTooltip:UpdatePosition(Vector2.new(mouse.X, mouse.Y))
    end
end

function DragSystem:RaycastFromMouse()
    local mouse = player:GetMouse()
    
    -- Create raycast params
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {player.Character}
    
    -- Cast ray from camera through mouse position
    local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * Constants.DRAG.RAYCAST_DISTANCE, raycastParams)
    
    if raycastResult then
        -- OPTIMIZATION: Only return draggable objects to avoid processing non-interactive hits
        local hitObject = raycastResult.Instance
        if self:IsObjectDraggable(hitObject) then
            return hitObject
        end
        -- Don't return non-draggable objects - this eliminates most spam
        return nil
    end
    
    return nil
end

function DragSystem:IsObjectDraggable(object)
    return CollectionService:HasTag(object, Constants.TAGS.DRAGGABLE_ITEM)
end

function DragSystem:StartHover(object)
    -- Add highlight effect
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Constants.HOVER.HIGHLIGHT_COLOR
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Constants.HOVER.HIGHLIGHT_COLOR
    highlight.OutlineTransparency = 0
    highlight.Parent = object
    highlight.Name = "DragHoverHighlight"
    
    -- Show enhanced tooltip with name and description
    local ItemTooltip = require(script.Parent.Parent.UI.ItemTooltip)
    local mouse = player:GetMouse()
    
    -- Get item name and description from CollectionService or a way to identify the item
    local itemName = object.Name
    local itemDescription = "No description available"
    
    -- Try to find the item definition to get the description
    local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
    for itemId, definition in pairs(ItemDefinitions.items) do
        if definition.name == itemName then
            itemDescription = definition.description
            break
        end
    end
    
    ItemTooltip:ShowTooltip(itemName, itemDescription, Vector2.new(mouse.X, mouse.Y))
    
    print("Started hovering:", object.Name)
end

function DragSystem:StopHover(object)
    -- Remove highlight effect
    local highlight = object:FindFirstChild("DragHoverHighlight")
    if highlight then
        highlight:Destroy()
    end
    
    -- Hide tooltip
    local ItemTooltip = require(script.Parent.Parent.UI.ItemTooltip)
    ItemTooltip:HideTooltip()
    
    print("Stopped hovering:", object.Name)
end

function DragSystem:HandleMouseDown()
    -- Check if player has equipped tool - if so, skip all drag processing
    if self:HasEquippedTool() then
        return -- Let tool handle the click
    end
    
    -- OPTIMIZATION: Skip drag processing when UIs are open
    if self:IsUIOpen() then
        return -- Let UI handle the click
    end
    
    -- OPTIMIZATION: Only process mouse down if we're actually hovering something
    if not hoveredObject then
        return -- No point processing if nothing is hovered
    end
    
    print("Mouse down detected") -- Debug
    print("Hovered object:", hoveredObject.Name) -- Debug
    
    if not grabbedObject then
        print("Attempting to pickup:", hoveredObject.Name) -- Debug
        self:PickupObject(hoveredObject)
    else
        print("Cannot pickup - already have grabbed object:", grabbedObject.Name) -- Debug
    end
end

function DragSystem:HandleMouseUp()
    -- Check if player has equipped tool - if so, skip all drag processing
    if self:HasEquippedTool() then
        return -- Let tool handle the mouse up
    end
    
    -- OPTIMIZATION: Skip drag processing when UIs are open (but still allow dropping)
    if self:IsUIOpen() and not grabbedObject then
        return -- Let UI handle the click, but allow dropping if we have something
    end
    
    -- OPTIMIZATION: Only process mouse up if we actually have a grabbed object
    if not grabbedObject then
        return -- No point processing if nothing is grabbed
    end
    
    print("Mouse up detected") -- Debug
    print("Grabbed object:", grabbedObject.Name) -- Debug
    print("Attempting to drop:", grabbedObject.Name) -- Debug
    self:DropObject(grabbedObject)
end

function DragSystem:PickupObject(object)
    print("Attempting server pickup request for:", object.Name) -- Debug
    
    -- Check if object is within pickup range
    local distanceToObject = (camera.CFrame.Position - object.Position).Magnitude
    if distanceToObject > Constants.DRAG.RAYCAST_DISTANCE then
        warn("Object too far to pickup:", object.Name, "Distance:", distanceToObject)
        return
    end
    
    -- Request pickup from server with error handling
    local success, result, message = pcall(function()
        return RemoteEvents.DragRequest:InvokeServer("pickup", object)
    end)
    
    if not success then
        warn("RemoteFunction call failed:", result)
        return
    end
    
    local serverSuccess, serverMessage = result, message
    print("Server response - Success:", serverSuccess, "Message:", serverMessage) -- Debug
    
    if not serverSuccess then
        warn("Failed to pickup object:", serverMessage)
        return
    end
    
    -- Store the drag distance (clamped to reasonable limits)
    dragDistance = math.clamp(distanceToObject, Constants.DRAG.MIN_DRAG_DISTANCE, Constants.DRAG.MAX_DRAG_DISTANCE)
    
    -- Create attachment on the object
    dragObjectAttachment = Instance.new("Attachment")
    dragObjectAttachment.Name = "DragAttachment"
    dragObjectAttachment.Parent = object
    
    -- Create constraints with anti-exploit settings
    alignPosition = Instance.new("AlignPosition")
    alignPosition.MaxForce = 25000 -- Reduced force to prevent violent movements
    alignPosition.MaxVelocity = 50 -- Limited velocity to prevent flick exploits
    alignPosition.Responsiveness = 100 -- Reduced responsiveness for smoother movement
    alignPosition.Attachment0 = dragObjectAttachment
    alignPosition.Attachment1 = dragTargetAttachment
    alignPosition.Parent = object
    
    alignOrientation = Instance.new("AlignOrientation")
    alignOrientation.MaxTorque = 25000 -- Reduced torque
    alignOrientation.MaxAngularVelocity = 20 -- Limited angular velocity
    alignOrientation.Responsiveness = 50 -- Smoother rotation
    alignOrientation.Attachment0 = dragObjectAttachment
    alignOrientation.Attachment1 = dragTargetAttachment
    alignOrientation.Parent = object
    
    -- Add a BodyVelocity for additional dampening
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(5000, 5000, 5000)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = object
    bodyVelocity.Name = "DragDampening"
    
    grabbedObject = object
    
    -- Stop hovering since we're now dragging
    if hoveredObject == object then
        self:StopHover(object)
        hoveredObject = nil
    end
    
    print("Successfully picked up object:", object.Name, "at distance:", dragDistance)
end

function DragSystem:DropObject(object)
    -- Request drop from server with error handling
    local success, result, message = pcall(function()
        return RemoteEvents.DragRequest:InvokeServer("drop", object)
    end)
    
    if not success then
        warn("RemoteFunction call failed:", result)
    else
        local serverSuccess, serverMessage = result, message
        
        if not serverSuccess then
            warn("Failed to drop object:", serverMessage)
        end
    end
    
    -- Clean up constraints
    if alignPosition then
        alignPosition:Destroy()
        alignPosition = nil
    end
    
    if alignOrientation then
        alignOrientation:Destroy()
        alignOrientation = nil
    end
    
    if dragObjectAttachment then
        dragObjectAttachment:Destroy()
        dragObjectAttachment = nil
    end
    
    -- Clean up dampening BodyVelocity
    local bodyVelocity = object:FindFirstChild("DragDampening")
    if bodyVelocity then
        bodyVelocity:Destroy()
    end
    
    grabbedObject = nil
end

function DragSystem:CheckDragDistance()
    if not grabbedObject then return end
    
    -- Check if the object is still within drag range
    local distanceToObject = (camera.CFrame.Position - grabbedObject.Position).Magnitude
    if distanceToObject > Constants.DRAG.RAYCAST_DISTANCE * 1.5 then -- Give some buffer before auto-dropping
        warn("Object too far away, auto-dropping:", grabbedObject.Name)
        self:DropObject(grabbedObject)
    end
end

function DragSystem:Cleanup()
    -- Disconnect heartbeat connection
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end
    
    -- Drop any grabbed object
    if grabbedObject then
        self:DropObject(grabbedObject)
    end
    
    -- Clean up drag target attachment
    if dragTargetAttachment then
        dragTargetAttachment:Destroy()
        dragTargetAttachment = nil
    end
    
    -- Clear all state
    grabbedObject = nil
    hoveredObject = nil
    dragDistance = 5
end

function DragSystem:GetHoveredObject()
    return hoveredObject
end

function DragSystem:HasEquippedTool()
    -- Access the global inventory state to avoid circular dependency
    -- This will be set by the InventorySystem when tools are equipped/unequipped
    return _G.PlayerHasEquippedTool == true
end

function DragSystem:IsUIOpen()
    -- Check if any UI that should block drag interactions is open
    local isTraderOpen = _G.TraderUI and _G.TraderUI.isShopOpen
    local isDialogueOpen = _G.DialogueUI and _G.DialogueUI.isDialogueOpen
    local isItemDetailOpen = _G.ItemDetailUI and _G.ItemDetailUI.isDetailOpen
    
    return isTraderOpen or isDialogueOpen or isItemDetailOpen
end

return DragSystem 