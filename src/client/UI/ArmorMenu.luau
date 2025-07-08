-- Armor menu UI component
local ArmorMenu = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local SLOT_SIZE = 80  -- Larger than hotbar slots
local SLOT_SPACING = 10
local MENU_PADDING = 20

-- Armor slot configuration
local ARMOR_SLOTS = {
    {name = "Helmet", slot = "helmet", icon = "⛑️"},
    {name = "Chestplate", slot = "chestplate", icon = "🦺"},
    {name = "Boots", slot = "boots", icon = "🥾"}
}

-- UI Elements
local screenGui = nil
local armorFrame = nil
local titleLabel = nil
local modalButton = nil -- For freeing cursor in first person
local slots = {}
local isVisible = false

function ArmorMenu:Initialize()
    self:CreateArmorMenuUI()
    print("Armor menu UI initialized with", #ARMOR_SLOTS, "slots")
end

function ArmorMenu:CreateArmorMenuUI()
    -- Create screen GUI
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ArmorMenuUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui
    
    -- Calculate menu dimensions
    local menuWidth = (SLOT_SIZE * #ARMOR_SLOTS) + (SLOT_SPACING * (#ARMOR_SLOTS - 1)) + (MENU_PADDING * 2)
    local menuHeight = SLOT_SIZE + 40 + (MENU_PADDING * 2) -- Extra height for title
    
    -- Create armor menu frame
    armorFrame = Instance.new("Frame")
    armorFrame.Name = "ArmorFrame"
    armorFrame.Size = UDim2.new(0, menuWidth, 0, menuHeight)
    armorFrame.Position = UDim2.new(0.5, -menuWidth/2, 0.3, -menuHeight/2) -- Center-left of screen
    armorFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    armorFrame.BackgroundTransparency = 0.1
    armorFrame.BorderSizePixel = 0
    armorFrame.Visible = false -- Initially hidden
    armorFrame.Parent = screenGui
    
    -- Add corner rounding
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = armorFrame
    
    -- Add border
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(120, 120, 120)
    stroke.Thickness = 3
    stroke.Parent = armorFrame
    
    -- Create invisible modal button to free cursor in first person
    modalButton = Instance.new("TextButton")
    modalButton.Name = "ModalButton"
    modalButton.Size = UDim2.new(1, 0, 1, 0) -- Full screen
    modalButton.Position = UDim2.new(0, 0, 0, 0)
    modalButton.BackgroundTransparency = 1 -- Invisible
    modalButton.Text = "" -- No text
    modalButton.Modal = true -- This is the key property that frees the cursor
    modalButton.Active = false -- Don't interfere with camera controls
    modalButton.Selectable = false -- Don't interfere with console
    modalButton.ZIndex = -1 -- Behind everything else
    modalButton.Visible = false -- Initially hidden
    modalButton.Parent = screenGui
    
    -- Title label
    titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, 0, 0, 30)
    titleLabel.Position = UDim2.new(0, 0, 0, MENU_PADDING)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "ARMOR EQUIPMENT"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 18
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.Parent = armorFrame
    
    -- Create armor slots
    for i, armorSlot in ipairs(ARMOR_SLOTS) do
        self:CreateArmorSlot(i, armorSlot)
    end
end

function ArmorMenu:CreateArmorSlot(slotIndex, armorSlotData)
    local xOffset = MENU_PADDING + ((slotIndex - 1) * (SLOT_SIZE + SLOT_SPACING))
    local yOffset = 40 + MENU_PADDING -- Below title
    
    -- Slot frame
    local slotFrame = Instance.new("Frame")
    slotFrame.Name = "ArmorSlot" .. armorSlotData.slot
    slotFrame:SetAttribute("ArmorSlotType", armorSlotData.slot)
    slotFrame.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
    slotFrame.Position = UDim2.new(0, xOffset, 0, yOffset)
    slotFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    slotFrame.BorderSizePixel = 0
    slotFrame.Parent = armorFrame
    
    -- Slot corner rounding
    local slotCorner = Instance.new("UICorner")
    slotCorner.CornerRadius = UDim.new(0, 6)
    slotCorner.Parent = slotFrame
    
    -- Slot border
    local slotStroke = Instance.new("UIStroke")
    slotStroke.Color = Color3.fromRGB(80, 80, 80)
    slotStroke.Thickness = 2
    slotStroke.Parent = slotFrame
    
    -- Default slot icon (when empty)
    local defaultIcon = Instance.new("TextLabel")
    defaultIcon.Name = "DefaultIcon"
    defaultIcon.Size = UDim2.new(1, 0, 0.6, 0)
    defaultIcon.Position = UDim2.new(0, 0, 0, 0)
    defaultIcon.BackgroundTransparency = 1
    defaultIcon.Text = armorSlotData.icon
    defaultIcon.TextColor3 = Color3.fromRGB(120, 120, 120)
    defaultIcon.TextSize = 32
    defaultIcon.Font = Enum.Font.SourceSans
    defaultIcon.TextXAlignment = Enum.TextXAlignment.Center
    defaultIcon.TextYAlignment = Enum.TextYAlignment.Center
    defaultIcon.Parent = slotFrame
    
    -- Item display (when equipped)
    local itemDisplay = Instance.new("TextLabel")
    itemDisplay.Name = "ItemDisplay"
    itemDisplay.Size = UDim2.new(1, -4, 0.6, 0)
    itemDisplay.Position = UDim2.new(0, 2, 0, 0)
    itemDisplay.BackgroundTransparency = 1
    itemDisplay.Text = ""
    itemDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
    itemDisplay.TextSize = 10
    itemDisplay.Font = Enum.Font.SourceSans
    itemDisplay.TextScaled = true
    itemDisplay.TextWrapped = true
    itemDisplay.TextXAlignment = Enum.TextXAlignment.Center
    itemDisplay.TextYAlignment = Enum.TextYAlignment.Center
    itemDisplay.Visible = false
    itemDisplay.Parent = slotFrame
    
    -- Slot label
    local slotLabel = Instance.new("TextLabel")
    slotLabel.Name = "SlotLabel"
    slotLabel.Size = UDim2.new(1, 0, 0.4, 0)
    slotLabel.Position = UDim2.new(0, 0, 0.6, 0)
    slotLabel.BackgroundTransparency = 1
    slotLabel.Text = armorSlotData.name
    slotLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    slotLabel.TextSize = 12
    slotLabel.Font = Enum.Font.SourceSans
    slotLabel.TextXAlignment = Enum.TextXAlignment.Center
    slotLabel.TextYAlignment = Enum.TextYAlignment.Center
    slotLabel.Parent = slotFrame
    
    -- Make slot clickable
    local clickDetector = Instance.new("TextButton")
    clickDetector.Name = "ClickDetector"
    clickDetector.Size = UDim2.new(1, 0, 1, 0)
    clickDetector.Position = UDim2.new(0, 0, 0, 0)
    clickDetector.BackgroundTransparency = 1
    clickDetector.Text = ""
    clickDetector:SetAttribute("ArmorSlotType", armorSlotData.slot)
    clickDetector.Parent = slotFrame
    
    -- Store slot reference
    slots[armorSlotData.slot] = {
        frame = slotFrame,
        defaultIcon = defaultIcon,
        itemDisplay = itemDisplay,
        stroke = slotStroke,
        clickDetector = clickDetector,
        isEmpty = true,
        slotType = armorSlotData.slot
    }
    
    -- Connect click event (will be handled by ArmorSystem)
    clickDetector.MouseButton1Click:Connect(function()
        -- Signal to ArmorSystem that this slot was clicked
        if _G.ArmorSystem then
            _G.ArmorSystem:HandleSlotClick(armorSlotData.slot)
        end
    end)
end

function ArmorMenu:Show()
    print("[ARMOR MENU DEBUG] --- Show START ---")
    print("[ARMOR MENU DEBUG] Current visibility state:", isVisible)
    
    if not isVisible then
        print("[ARMOR MENU DEBUG] Showing armor menu")
        armorFrame.Visible = true
        modalButton.Visible = true -- Show modal button to free cursor
        isVisible = true
        
        print("[ARMOR MENU DEBUG] Frame and modal button made visible")
        
        -- Enable mouse cursor (this works with the modal button)
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
        
        print("[ARMOR MENU DEBUG] Mouse behavior set to Default, cursor enabled")
        
        -- Hide crosshair when armor menu is open
        if _G.CameraSystem then
            print("[ARMOR MENU DEBUG] Hiding crosshair via CameraSystem")
            _G.CameraSystem:HideCrosshair()
        else
            print("[ARMOR MENU DEBUG] WARNING: CameraSystem not found")
        end
        
        -- Smooth fade in animation
        armorFrame.BackgroundTransparency = 1
        local tween = TweenService:Create(armorFrame, TweenInfo.new(0.2), {BackgroundTransparency = 0.1})
        tween:Play()
        
        print("[ARMOR MENU DEBUG] SUCCESS: Armor menu shown with fade-in animation")
    else
        print("[ARMOR MENU DEBUG] Menu already visible, no action needed")
    end
    
    print("[ARMOR MENU DEBUG] --- Show END ---")
end

function ArmorMenu:Hide()
    if isVisible then
        -- Smooth fade out animation
        local tween = TweenService:Create(armorFrame, TweenInfo.new(0.2), {BackgroundTransparency = 1})
        tween:Play()
        
        tween.Completed:Connect(function()
            armorFrame.Visible = false
            modalButton.Visible = false -- Hide modal button to restore cursor lock
            isVisible = false
            
            -- Restore mouse behavior (let other systems handle it)
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
            UserInputService.MouseIconEnabled = false
            
            -- Show crosshair when armor menu is closed
            if _G.CameraSystem then
                _G.CameraSystem:ShowCrosshair()
            end
            
            print("Armor menu hidden")
        end)
    end
end

function ArmorMenu:Toggle()
    print("[ARMOR MENU DEBUG] --- Toggle START ---")
    print("[ARMOR MENU DEBUG] Current visibility state:", isVisible)
    
    if isVisible then
        print("[ARMOR MENU DEBUG] Menu is visible - hiding")
        self:Hide()
    else
        print("[ARMOR MENU DEBUG] Menu is hidden - showing")
        self:Show()
    end
    
    print("[ARMOR MENU DEBUG] --- Toggle END ---")
end

function ArmorMenu:UpdateDisplay(armorInventory)
    -- Update all armor slots
    for slotType, slot in pairs(slots) do
        local armorItem = armorInventory[slotType]
        
        if armorItem then
            -- Slot has armor equipped
            slot.defaultIcon.Visible = false
            slot.itemDisplay.Visible = true
            slot.itemDisplay.Text = armorItem.itemName or "Unknown"
            slot.stroke.Color = Color3.fromRGB(100, 255, 100) -- Green for equipped
            slot.isEmpty = false
        else
            -- Slot is empty
            slot.defaultIcon.Visible = true
            slot.itemDisplay.Visible = false
            slot.stroke.Color = Color3.fromRGB(80, 80, 80) -- Default gray
            slot.isEmpty = true
        end
    end
end

function ArmorMenu:IsVisible()
    return isVisible
end

return ArmorMenu 