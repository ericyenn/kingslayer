-- Dynamic hotbar UI component
local Hotbar = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration (easily changeable)
local SLOT_COUNT = 10
local SLOT_SIZE = 50
local SLOT_SPACING = 5
local HOTBAR_PADDING = 10

-- UI Elements
local screenGui = nil
local hotbarFrame = nil
local slots = {}

-- Drag and drop state
local dragState = {
    isDragging = false,
    draggedSlot = nil,
    dragPreview = nil,
    originalPosition = nil
}

function Hotbar:Initialize()
    self:CreateHotbarUI()
    self:SetupDragAndDrop()
    -- Note: Number key inputs now handled by InventorySystem
    print("Hotbar UI initialized with", SLOT_COUNT, "slots")
end

function Hotbar:CreateHotbarUI()
    -- Create screen GUI
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HotbarUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui
    
    -- Calculate hotbar dimensions
    local hotbarWidth = (SLOT_SIZE * SLOT_COUNT) + (SLOT_SPACING * (SLOT_COUNT - 1)) + (HOTBAR_PADDING * 2)
    local hotbarHeight = SLOT_SIZE + (HOTBAR_PADDING * 2)
    
    -- Create hotbar frame
    hotbarFrame = Instance.new("Frame")
    hotbarFrame.Name = "HotbarFrame"
    hotbarFrame.Size = UDim2.new(0, hotbarWidth, 0, hotbarHeight)
    hotbarFrame.Position = UDim2.new(0.5, -hotbarWidth/2, 1, -hotbarHeight - 20) -- Bottom center
    hotbarFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    hotbarFrame.BackgroundTransparency = 0.2
    hotbarFrame.BorderSizePixel = 0
    hotbarFrame.Parent = screenGui
    
    -- Add corner rounding
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = hotbarFrame
    
    -- Add border
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 100, 100)
    stroke.Thickness = 2
    stroke.Parent = hotbarFrame
    
    -- Create slots
    for i = 1, SLOT_COUNT do
        self:CreateSlot(i)
    end
end

function Hotbar:CreateSlot(slotNumber)
    local xOffset = HOTBAR_PADDING + ((slotNumber - 1) * (SLOT_SIZE + SLOT_SPACING))
    
    -- Slot frame
    local slotFrame = Instance.new("Frame")
    slotFrame.Name = "Slot" .. slotNumber
    slotFrame.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
    slotFrame.Position = UDim2.new(0, xOffset, 0, HOTBAR_PADDING)
    slotFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    slotFrame.BorderSizePixel = 0
    slotFrame.Parent = hotbarFrame
    
    -- Slot corner rounding
    local slotCorner = Instance.new("UICorner")
    slotCorner.CornerRadius = UDim.new(0, 4)
    slotCorner.Parent = slotFrame
    
    -- Slot border (for equipped indication)
    local slotStroke = Instance.new("UIStroke")
    slotStroke.Color = Color3.fromRGB(80, 80, 80)
    slotStroke.Thickness = 1
    slotStroke.Parent = slotFrame
    
    -- Item name display (text label showing full item name)
    local itemIcon = Instance.new("TextLabel")
    itemIcon.Name = "ItemIcon"
    itemIcon.Size = UDim2.new(1, -4, 1, -14) -- Leave space for slot number
    itemIcon.Position = UDim2.new(0, 2, 0, 12) -- Position below slot number
    itemIcon.BackgroundTransparency = 1
    itemIcon.Text = ""
    itemIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
    itemIcon.TextSize = 8
    itemIcon.Font = Enum.Font.SourceSans
    itemIcon.TextScaled = true
    itemIcon.TextWrapped = true
    itemIcon.TextXAlignment = Enum.TextXAlignment.Center
    itemIcon.TextYAlignment = Enum.TextYAlignment.Center
    itemIcon.Parent = slotFrame
    
    -- Slot number indicator
    local slotNumberLabel = Instance.new("TextLabel")
    slotNumberLabel.Name = "SlotNumber"
    slotNumberLabel.Size = UDim2.new(0, 12, 0, 12)
    slotNumberLabel.Position = UDim2.new(0, 2, 0, 2)
    slotNumberLabel.BackgroundTransparency = 1
    slotNumberLabel.Text = tostring(slotNumber == 10 and 0 or slotNumber) -- Show 0 for slot 10
    slotNumberLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    slotNumberLabel.TextSize = 10
    slotNumberLabel.Font = Enum.Font.SourceSans
    slotNumberLabel.TextStrokeTransparency = 0
    slotNumberLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    slotNumberLabel.Parent = slotFrame
    
    -- Drag detection button (invisible)
    local dragButton = Instance.new("TextButton")
    dragButton.Name = "DragButton"
    dragButton.Size = UDim2.new(1, 0, 1, 0)
    dragButton.Position = UDim2.new(0, 0, 0, 0)
    dragButton.BackgroundTransparency = 1
    dragButton.Text = ""
    dragButton.ZIndex = 2 -- Above other elements
    dragButton.Parent = slotFrame
    
    -- Store slot reference
    slots[slotNumber] = {
        frame = slotFrame,
        icon = itemIcon,
        stroke = slotStroke,
        dragButton = dragButton,
        slotNumber = slotNumber,
        isEmpty = true
    }
    
    -- Slot created successfully
end

function Hotbar:SetupDragAndDrop()
    -- Connect drag events for all slots
    for slotNumber, slot in pairs(slots) do
        self:ConnectSlotDragEvents(slot)
    end
end

function Hotbar:ConnectSlotDragEvents(slot)
    local dragButton = slot.dragButton
    
    -- Mouse button down - start potential drag
    dragButton.MouseButton1Down:Connect(function()
        print("[HOTBAR DEBUG] Mouse button down on slot", slot.slotNumber)
        print("[HOTBAR DEBUG] Slot is empty:", slot.isEmpty)
        
        local canDrag = self:CanDragSlots()
        print("[HOTBAR DEBUG] Can drag slots:", canDrag)
        
        if canDrag and not slot.isEmpty then
            print("[HOTBAR DEBUG] Starting drag for slot", slot.slotNumber)
            self:StartDrag(slot)
        else
            print("[HOTBAR DEBUG] Cannot start drag - canDrag:", canDrag, "isEmpty:", slot.isEmpty)
        end
    end)
    
    -- Mouse enter - highlight as drop target
    dragButton.MouseEnter:Connect(function()
        if dragState.isDragging and dragState.draggedSlot ~= slot then
            self:HighlightDropTarget(slot, true)
        end
    end)
    
    -- Mouse leave - remove drop target highlight
    dragButton.MouseLeave:Connect(function()
        if dragState.isDragging and dragState.draggedSlot ~= slot then
            self:HighlightDropTarget(slot, false)
        end
    end)
    
    -- Mouse button up - complete drag
    dragButton.MouseButton1Up:Connect(function()
        if dragState.isDragging then
            self:CompleteDrag(slot)
        end
    end)
end

function Hotbar:CanDragSlots()
    -- Only allow dragging when armor menu is visible
    local canDrag = _G.ArmorSystem and _G.ArmorSystem:IsArmorMenuVisible()
    print("[HOTBAR DEBUG] CanDragSlots check - ArmorSystem exists:", _G.ArmorSystem ~= nil)
    print("[HOTBAR DEBUG] CanDragSlots check - Armor menu visible:", _G.ArmorSystem and _G.ArmorSystem:IsArmorMenuVisible())
    print("[HOTBAR DEBUG] CanDragSlots result:", canDrag)
    return canDrag
end

function Hotbar:StartDrag(slot)
    print("[HOTBAR DEBUG] --- StartDrag START ---")
    print("[HOTBAR DEBUG] Starting drag for slot:", slot.slotNumber)
    
    dragState.isDragging = true
    dragState.draggedSlot = slot
    dragState.originalPosition = slot.frame.Position
    
    print("[HOTBAR DEBUG] Drag state updated - isDragging:", dragState.isDragging)
    
    -- Create drag preview
    self:CreateDragPreview(slot)
    print("[HOTBAR DEBUG] Drag preview created")
    
    -- Highlight the dragged slot
    slot.stroke.Color = Color3.fromRGB(100, 150, 255) -- Blue for dragging
    slot.stroke.Thickness = 2
    print("[HOTBAR DEBUG] Slot highlighted for dragging")
    
    print("[HOTBAR DEBUG] SUCCESS: Started dragging slot", slot.slotNumber)
    print("[HOTBAR DEBUG] --- StartDrag END ---")
end

function Hotbar:CreateDragPreview(slot)
    -- Create a preview frame that follows the mouse
    dragState.dragPreview = slot.frame:Clone()
    dragState.dragPreview.Name = "DragPreview"
    dragState.dragPreview.ZIndex = 10 -- Above everything
    dragState.dragPreview.BackgroundTransparency = 0.5 -- Semi-transparent
    dragState.dragPreview.Parent = screenGui
    
    -- Update preview position with mouse movement
    local connection
    connection = UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragState.isDragging then
            local mousePos = UserInputService:GetMouseLocation()
            dragState.dragPreview.Position = UDim2.new(0, mousePos.X - SLOT_SIZE/2, 0, mousePos.Y - SLOT_SIZE/2)
        end
    end)
    
    -- Store connection for cleanup
    dragState.previewConnection = connection
end

function Hotbar:HighlightDropTarget(slot, highlight)
    if highlight then
        slot.stroke.Color = Color3.fromRGB(100, 255, 100) -- Green for valid drop target
        slot.stroke.Thickness = 2
    else
        -- Restore normal appearance (will be updated by UpdateDisplay)
        slot.stroke.Color = Color3.fromRGB(80, 80, 80)
        slot.stroke.Thickness = 1
    end
end

function Hotbar:CompleteDrag(targetSlot)
    print("[HOTBAR DEBUG] --- CompleteDrag START ---")
    print("[HOTBAR DEBUG] Target slot:", targetSlot and targetSlot.slotNumber or "NIL")
    print("[HOTBAR DEBUG] Drag state - isDragging:", dragState.isDragging)
    print("[HOTBAR DEBUG] Drag state - draggedSlot:", dragState.draggedSlot and dragState.draggedSlot.slotNumber or "NIL")
    
    if not dragState.isDragging or not dragState.draggedSlot then
        print("[HOTBAR DEBUG] ERROR: Invalid drag state, aborting")
        return
    end
    
    local sourceSlot = dragState.draggedSlot
    print("[HOTBAR DEBUG] Source slot:", sourceSlot.slotNumber)
    
    -- Only proceed if we're dropping on a different slot
    if sourceSlot ~= targetSlot then
        print("[HOTBAR DEBUG] Different slots - proceeding with swap")
        print("[HOTBAR DEBUG] Swapping slot", sourceSlot.slotNumber, "with slot", targetSlot.slotNumber)
        self:SwapSlots(sourceSlot.slotNumber, targetSlot.slotNumber)
        print("[HOTBAR DEBUG] Swap completed")
    else
        print("[HOTBAR DEBUG] Same slot - no swap needed")
    end
    
    -- Clean up drag state
    print("[HOTBAR DEBUG] Cleaning up drag state")
    self:CleanupDrag()
    
    print("[HOTBAR DEBUG] --- CompleteDrag END ---")
end

function Hotbar:SwapSlots(slot1, slot2)
    -- Request slot swap from inventory system (preserves equipped item)
    if _G.InventorySystem then
        _G.InventorySystem:SwapSlots(slot1, slot2)
    end
end

function Hotbar:CleanupDrag()
    -- Remove drag preview
    if dragState.dragPreview then
        dragState.dragPreview:Destroy()
        dragState.dragPreview = nil
    end
    
    -- Disconnect mouse movement connection
    if dragState.previewConnection then
        dragState.previewConnection:Disconnect()
        dragState.previewConnection = nil
    end
    
    -- Reset drag state
    dragState.isDragging = false
    dragState.draggedSlot = nil
    dragState.originalPosition = nil
    
    -- Force UI update to restore normal appearance
    if _G.InventorySystem then
        local inventory = _G.InventorySystem:GetInventory()
        local equippedSlot = _G.InventorySystem:GetEquippedSlot()
        self:UpdateDisplay(inventory, equippedSlot)
    end
    
    print("Drag operation completed")
end

-- Handle global mouse up to complete drag even if mouse leaves slot
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and dragState.isDragging then
        -- Complete drag without a specific target (cancel drag)
        Hotbar:CleanupDrag()
    end
end)

function Hotbar:UpdateDisplay(inventory, equippedSlot)
    -- Update all slots
    for i = 1, SLOT_COUNT do
        local slot = slots[i]
        local inventoryItem = inventory[i]
        
        if not slot then
            warn("Slot", i, "is nil in slots array!")
            continue
        end
        
        if inventoryItem then
            -- Slot has item - show full item name
            slot.icon.Text = inventoryItem.itemName or "Unknown"
            slot.isEmpty = false
        else
            -- Slot is empty
            slot.icon.Text = ""
            slot.isEmpty = true
        end
        
        -- Update equipped indicator
        if equippedSlot == i then
            slot.stroke.Color = Color3.fromRGB(255, 255, 0) -- Yellow for equipped
            slot.stroke.Thickness = 3
        else
            slot.stroke.Color = Color3.fromRGB(80, 80, 80) -- Default gray
            slot.stroke.Thickness = 1
        end
    end
end

function Hotbar:SetSlotCount(newCount)
    SLOT_COUNT = newCount
    -- Recreate UI with new slot count
    if screenGui then
        screenGui:Destroy()
    end
    slots = {}
    self:CreateHotbarUI()
end

function Hotbar:SetSlotSize(newSize)
    SLOT_SIZE = newSize
    -- Recreate UI with new slot size
    if screenGui then
        screenGui:Destroy()
    end
    slots = {}
    self:CreateHotbarUI()
end

function Hotbar:GetSlotCount()
    return SLOT_COUNT
end

return Hotbar 