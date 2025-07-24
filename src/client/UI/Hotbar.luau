-- Dynamic hotbar UI component
local Hotbar = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration (easily changeable)
local SLOT_COUNT = 10
local SLOT_SIZE = math.floor(50 * 1.3) -- 30% bigger
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

-- Add at the top of the file:
local hoveredSlotIndex = nil

-- ENHANCED: Track all connections for cleanup
local globalConnections = {}

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
    
    -- Add centered label above hotbar
    local hotbarWidth = (SLOT_SIZE * SLOT_COUNT) + (SLOT_SPACING * (SLOT_COUNT - 1)) + (HOTBAR_PADDING * 2)
    local label = Instance.new("TextLabel")
    label.Name = "HotbarHintLabel"
    label.Size = UDim2.new(0, hotbarWidth, 0, 22)
    label.Position = UDim2.new(0.5, -hotbarWidth/2, 1, -(SLOT_SIZE + HOTBAR_PADDING + 18))
    label.BackgroundTransparency = 1
    label.Text = "(G) to open the menu"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.6
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Italic)
    label.Parent = screenGui
    
    -- Calculate hotbar dimensions
    local hotbarHeight = SLOT_SIZE + (HOTBAR_PADDING * 2)
    
    -- Remove hotbarFrame and its styling
    -- All slots will be parented directly to screenGui
    
    -- Create slots
    for i = 1, SLOT_COUNT do
        self:CreateSlot(i)
    end
end

function Hotbar:CreateSlot(slotNumber)
    local hotbarWidth = (SLOT_SIZE * SLOT_COUNT) + (SLOT_SPACING * (SLOT_COUNT - 1))
    local slotX = -hotbarWidth/2 + ((slotNumber - 1) * (SLOT_SIZE + SLOT_SPACING))
    
    -- Slot image background (replace Frame with ImageLabel)
    local slotImage = Instance.new("ImageLabel")
    slotImage.Name = "Slot" .. slotNumber
    slotImage.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
    slotImage.Position = UDim2.new(0.5, slotX, 1, -(SLOT_SIZE // 4 + 52)) -- Keep same vertical offset logic
    slotImage.BackgroundTransparency = 1
    slotImage.Image = "rbxassetid://71503412974519"
    slotImage.Parent = screenGui
    
    -- Slot border (for equipped/hovered indication)
    local slotStroke = Instance.new("UIStroke")
    slotStroke.Color = Color3.fromRGB(80, 80, 80)
    slotStroke.Thickness = 1
    slotStroke.Parent = slotImage
    
    -- Light overlay (for equipped/hovered effect)
    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundColor3 = Color3.new(1, 1, 1)
    overlay.BackgroundTransparency = 1 -- Default hidden
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 3
    overlay.Parent = slotImage
    
    -- Item name display (text label showing full item name)
    local itemIcon = Instance.new("TextLabel")
    itemIcon.Name = "ItemIcon"
    itemIcon.Size = UDim2.new(1, -4, 1, -14) -- Leave space for slot number
    itemIcon.Position = UDim2.new(0, 2, 0, 12) -- Position below slot number
    itemIcon.BackgroundTransparency = 1
    itemIcon.Text = ""
    itemIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
    itemIcon.TextSize = 12 -- Smaller font for item name
    itemIcon.Font = Enum.Font.Gotham
    itemIcon.TextScaled = true
    itemIcon.TextWrapped = true
    itemIcon.TextXAlignment = Enum.TextXAlignment.Center
    itemIcon.TextYAlignment = Enum.TextYAlignment.Center
    itemIcon.Parent = slotImage
    
    -- Slot number indicator
    local slotNumberLabel = Instance.new("TextLabel")
    slotNumberLabel.Name = "SlotNumber"
    slotNumberLabel.Size = UDim2.new(0, 12, 0, 12)
    slotNumberLabel.Position = UDim2.new(0, 2, 0, 2)
    slotNumberLabel.BackgroundTransparency = 1
    slotNumberLabel.Text = tostring(slotNumber == 10 and 0 or slotNumber) -- Show 0 for slot 10
    slotNumberLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    slotNumberLabel.TextSize = 14 -- Smaller font for slot number
    slotNumberLabel.Font = Enum.Font.Gotham
    slotNumberLabel.TextStrokeTransparency = 0
    slotNumberLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    slotNumberLabel.Parent = slotImage
    
    -- Drag detection button (invisible)
    local dragButton = Instance.new("TextButton")
    dragButton.Name = "DragButton"
    dragButton.Size = UDim2.new(1, 0, 1, 0)
    dragButton.Position = UDim2.new(0, 0, 0, 0)
    dragButton.BackgroundTransparency = 1
    dragButton.Text = ""
    dragButton.ZIndex = 4 -- Above overlay
    dragButton.Parent = slotImage
    
    -- Store slot reference
    slots[slotNumber] = {
        frame = slotImage,
        icon = itemIcon,
        stroke = slotStroke,
        dragButton = dragButton,
        overlay = overlay,
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
        local canDrag = self:CanDragSlots()
        
        if canDrag and not slot.isEmpty then
            self:StartDrag(slot)
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
    return _G.ArmorSystem and _G.ArmorSystem:IsArmorMenuVisible()
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
    
    -- Get GuiService for window offset calculation
    local GuiService = game:GetService("GuiService")
    
    -- Update preview position with mouse movement
    local connection
    connection = UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragState.isDragging then
            -- Get screen coordinates and convert to game window coordinates
            local mousePos = UserInputService:GetMouseLocation()
            local guiInset = GuiService:GetGuiInset()
            
            -- Adjust for window offset (title bar, etc.)
            local gameWindowX = mousePos.X - guiInset.X
            local gameWindowY = mousePos.Y - guiInset.Y
            
            -- Position drag preview centered on cursor
            dragState.dragPreview.Position = UDim2.new(0, gameWindowX - SLOT_SIZE/2, 0, gameWindowY - SLOT_SIZE/2)
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

function Hotbar:DetectSlotAtMousePosition()
    -- Helper method to detect which hotbar slot the mouse is over
    local GuiService = game:GetService("GuiService")
    local mousePos = UserInputService:GetMouseLocation()
    local guiInset = GuiService:GetGuiInset()
    
    -- Convert to game window coordinates
    local gameWindowX = mousePos.X - guiInset.X
    local gameWindowY = mousePos.Y - guiInset.Y
    
    local guiObjects = playerGui:GetGuiObjectsAtPosition(gameWindowX, gameWindowY)
    
    -- Look for hotbar slot elements
    for _, gui in ipairs(guiObjects) do
        -- Skip the drag preview frame
        if gui.Name ~= "DragPreview" then
            local current = gui
            while current do
                -- Check if this is a hotbar slot frame
                if current.Name and string.match(current.Name, "^Slot%d+$") then
                    -- Extract slot number from name (e.g., "Slot2" -> 2)
                    local slotNumber = tonumber(string.match(current.Name, "%d+"))
                    if slotNumber and slots[slotNumber] then
                        print("[HOTBAR DEBUG] Detected hotbar slot at mouse position:", slotNumber)
                        return slots[slotNumber]
                    end
                end
                
                -- Check if this is a drag button inside a slot
                if current.Name == "DragButton" and current.Parent then
                    local slotFrame = current.Parent
                    if slotFrame.Name and string.match(slotFrame.Name, "^Slot%d+$") then
                        local slotNumber = tonumber(string.match(slotFrame.Name, "%d+"))
                        if slotNumber and slots[slotNumber] then
                            print("[HOTBAR DEBUG] Detected hotbar slot via drag button at mouse position:", slotNumber)
                            return slots[slotNumber]
                        end
                    end
                end
                
                current = current.Parent
            end
        end
    end
    
    return nil
end

function Hotbar:CompleteDrag(targetSlot)
    if not dragState.isDragging or not dragState.draggedSlot then
        return
    end
    
    local sourceSlot = dragState.draggedSlot
    
    -- If no target slot provided, try to detect one at mouse position
    if not targetSlot then
        targetSlot = self:DetectSlotAtMousePosition()
    end
    
    -- Swap only if a valid target slot was found and it's different from source
    if targetSlot and sourceSlot ~= targetSlot then
        self:SwapSlots(sourceSlot.slotNumber, targetSlot.slotNumber)
    end
    
    -- First clean up drag visuals so the preview frame no longer blocks hit-testing
    self:CleanupDrag()

    -- Now detect if the mouse is over an armour slot
    local GuiService = game:GetService("GuiService")
    local mousePos = UserInputService:GetMouseLocation()
    local guiInset = GuiService:GetGuiInset()
    
    -- Convert to game window coordinates
    local gameWindowX = mousePos.X - guiInset.X
    local gameWindowY = mousePos.Y - guiInset.Y
    
    local guiObjects = playerGui:GetGuiObjectsAtPosition(gameWindowX, gameWindowY)
    local detectedArmorSlot
    for _, gui in ipairs(guiObjects) do
        -- Skip the hotbar preview frame if it somehow survived
        if gui.Name ~= "DragPreview" then
            local current = gui
            while current do
                local slotType = current:GetAttribute("ArmorSlotType")
                if slotType then
                    detectedArmorSlot = slotType
                    break
                end
                current = current.Parent
            end
            if detectedArmorSlot then break end
        end
    end

    if detectedArmorSlot and _G.ArmorSystem then
        _G.ArmorSystem:EquipFromInventorySlot(sourceSlot.slotNumber, detectedArmorSlot)
    end
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
end

-- ENHANCED: Handle global mouse up to complete drag even if mouse leaves slot (with connection tracking)
globalConnections.globalMouseUp = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and dragState.isDragging then
        -- Complete drag without a specific hotbar target; will still attempt armor detection
        Hotbar:CompleteDrag(nil)
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
        
        -- Update equipped/hovered indicator
        if equippedSlot == i or hoveredSlotIndex == i then
            slot.stroke.Color = Color3.fromRGB(220, 220, 220) -- Slightly gray outline
            slot.stroke.Thickness = 2 -- Slightly thicker outline
            slot.overlay.BackgroundTransparency = 0.93 -- Even less bright overlay
        else
            slot.stroke.Color = Color3.fromRGB(80, 80, 80)
            slot.stroke.Thickness = 1
            slot.overlay.BackgroundTransparency = 1 -- Hide overlay
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

-- ENHANCED: Add cleanup method for connection management
function Hotbar:Cleanup()
    -- Clean up global connections
    for connectionName, connection in pairs(globalConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    globalConnections = {}
    
    -- Clean up drag state
    if dragState.previewConnection then
        dragState.previewConnection:Disconnect()
        dragState.previewConnection = nil
    end
    
    if dragState.dragPreview then
        dragState.dragPreview:Destroy()
        dragState.dragPreview = nil
    end
    
    -- Clear drag state
    dragState.isDragging = false
    dragState.draggedSlot = nil
    dragState.originalPosition = nil
    
    -- Clear hoveredSlotIndex
    hoveredSlotIndex = nil

    -- Clean up UI
    if screenGui then
        screenGui:Destroy()
        screenGui = nil
    end
    
    -- Clear slots
    slots = {}
end

-- Add this after Hotbar:Initialize()
local ArmorMenu = require(script.Parent.ArmorMenu)
local originalShow = ArmorMenu.Show
function ArmorMenu:Show(...)
    -- Add blur effect
    if not Lighting:FindFirstChild("MenuBlur") then
        local blur = Instance.new("BlurEffect")
        blur.Name = "MenuBlur"
        blur.Size = 18
        blur.Parent = Lighting
    end
    return originalShow(self, ...)
end

local originalHide = ArmorMenu.Hide
function ArmorMenu:Hide(...)
    -- Remove blur effect
    local blur = Lighting:FindFirstChild("MenuBlur")
    if blur then
        blur:Destroy()
    end
    return originalHide(self, ...)
end

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        if ArmorMenu:IsVisible() then
            local mousePos = input.Position
            local found = nil
            for i, slot in pairs(slots) do
                if slot.frame.AbsolutePosition and slot.frame.AbsoluteSize then
                    local pos = slot.frame.AbsolutePosition
                    local size = slot.frame.AbsoluteSize
                    if mousePos.X >= pos.X and mousePos.X <= pos.X + size.X and
                       mousePos.Y >= pos.Y and mousePos.Y <= pos.Y + size.Y then
                        found = i
                        break
                    end
                end
            end
            if hoveredSlotIndex ~= found then
                hoveredSlotIndex = found
                Hotbar:UpdateDisplay(_G.InventorySystem and _G.InventorySystem:GetInventory() or {}, _G.InventorySystem and _G.InventorySystem:GetEquippedSlot() or nil)
            end
        else
            if hoveredSlotIndex ~= nil then
                hoveredSlotIndex = nil
                Hotbar:UpdateDisplay(_G.InventorySystem and _G.InventorySystem:GetInventory() or {}, _G.InventorySystem and _G.InventorySystem:GetEquippedSlot() or nil)
            end
        end
    end
end)

return Hotbar 