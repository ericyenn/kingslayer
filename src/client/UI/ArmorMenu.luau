-- Armor menu UI component
local ArmorMenu = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local StatsPanel = require(script.Parent.StatsPanel)

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
local titleLabel = nil
local modalButton = nil -- For freeing cursor in first person
local slots = {}
local isVisible = false

local statsPanel = nil

local daysSurvived = 1
local playtime = 0

local statsUpdateLoopActive = false

local ARMOR_SLOT_ANIM_TIME = 0.35
local ARMOR_SLOT_ANIM_TIME_OUT = 0.18
local ARMOR_SLOT_Y_HIDDEN = -200
local ARMOR_SLOT_Y_VISIBLE = 0
local DECAL_Y_HIDDEN = -300
local DECAL_Y_VISIBLE = 0
local armorSlotTweens = {}
local decalTween = nil

-- Add a container for slots and decal
local slotsContainer = nil
local SLOTS_CONTAINER_ANIM_TIME = 0.35
local SLOTS_CONTAINER_ANIM_TIME_OUT = 0.12 -- Faster hide
local SLOTS_CONTAINER_Y_HIDDEN = -300
local SLOTS_CONTAINER_Y_VISIBLE = 0
local SLOTS_CONTAINER_Y_SCALE = 0.3
local SLOTS_CONTAINER_Y_OFFSET_VISIBLE = nil -- set in CreateArmorMenuUI
local SLOTS_CONTAINER_Y_OFFSET_HIDDEN = nil -- set in CreateArmorMenuUI
local slotsContainerTween = nil

-- Store original Y offsets for slots and decal
local slotOriginalYs = {}
local decalOriginalY = nil

local function startStatsUpdateLoop()
	if statsUpdateLoopActive then return end
	statsUpdateLoopActive = true
	task.spawn(function()
		while statsUpdateLoopActive do
			RemoteEvents.StatsUpdate:FireServer()
			task.wait(1)
		end
	end)
end

local function stopStatsUpdateLoop()
	statsUpdateLoopActive = false
end

local function formatPlaytime(seconds)
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", mins, secs)
end

RemoteEvents.StatsUpdate.OnClientEvent:Connect(function(serverDaysSurvived, serverPlaytime)
	if statsPanel then
		statsPanel:SetStats(serverDaysSurvived, serverPlaytime)
	end
end)

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
    self.menuHeight = menuHeight
    SLOTS_CONTAINER_Y_OFFSET_VISIBLE = -menuHeight * 1.5 + 40
    SLOTS_CONTAINER_Y_OFFSET_HIDDEN = SLOTS_CONTAINER_Y_OFFSET_VISIBLE - 300

    -- Remove armorFrame entirely
    -- Title label parented to screenGui
    -- Remove the title label creation
    -- (do not create titleLabel)
    
    -- Create container for slots and decal
    slotsContainer = Instance.new("Frame")
    slotsContainer.Name = "SlotsContainer"
    slotsContainer.Size = UDim2.new(1, 0, 1, 0)
    slotsContainer.Position = UDim2.new(0, 0, SLOTS_CONTAINER_Y_SCALE, SLOTS_CONTAINER_Y_OFFSET_VISIBLE)
    slotsContainer.BackgroundTransparency = 1
    slotsContainer.Parent = screenGui
    self.slotsContainer = slotsContainer

    -- Create armor slots parented to slotsContainer
    for i, armorSlot in ipairs(ARMOR_SLOTS) do
        self:CreateArmorSlot(i, armorSlot, menuWidth, menuHeight, slotsContainer)
    end
    
    -- Modal button for cursor management remains parented to screenGui
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

    -- Add centered background decal behind slots, parented to slotsContainer
    local decalImage = Instance.new("ImageLabel")
    decalImage.Name = "ArmorMenuDecal"
    decalImage.Image = "rbxassetid://99343688701653"
    decalImage.BackgroundTransparency = 1
    decalImage.SizeConstraint = Enum.SizeConstraint.RelativeYY
    decalImage.Size = UDim2.new(0, menuHeight * 3, 0, menuHeight * 3)
    decalImage.Position = UDim2.new(0.5, -menuHeight * 1.5, 0.3, -menuHeight * 1.5 + 40)
    decalImage.Visible = false
    decalImage.ZIndex = 0
    decalImage.Parent = slotsContainer
    self.decalImage = decalImage
    decalOriginalY = -menuHeight * 1.5 + 40

    -- Add stats panel (modular)
    statsPanel = StatsPanel.new(screenGui)
    self.statsPanel = statsPanel

    -- Create darken overlay (behind blur, ZIndex 1)
    -- darkenOverlay = Instance.new("Frame")
    -- darkenOverlay.Name = "DarkenOverlay"
    -- darkenOverlay.Size = UDim2.new(1, 0, 1, 0)
    -- darkenOverlay.Position = UDim2.new(0, 0, 0, 0)
    -- darkenOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
    -- darkenOverlay.BackgroundTransparency = 1
    -- darkenOverlay.ZIndex = 1
    -- darkenOverlay.Visible = false
    -- darkenOverlay.Parent = screenGui
    -- self.darkenOverlay = darkenOverlay
end

function ArmorMenu:CreateArmorSlot(slotIndex, armorSlotData, menuWidth, menuHeight, parent)
    -- Stack slots vertically, centered horizontally
    local totalSlots = #ARMOR_SLOTS
    local totalHeight = (SLOT_SIZE * totalSlots) + (SLOT_SPACING * (totalSlots - 1))
    local yOffset = ((slotIndex - 1) * (SLOT_SIZE + SLOT_SPACING)) - (totalHeight // 2)
    -- Move headgear up and boots down
    if armorSlotData.slot == "helmet" then
        yOffset = yOffset - 40
    elseif armorSlotData.slot == "boots" then
        yOffset = yOffset + 110
    end
    local xOffset = 0 -- Centered
    -- Slot frame parented to slotsContainer
    local slotFrame = Instance.new("Frame")
    slotFrame.Name = "ArmorSlot" .. armorSlotData.slot
    slotFrame:SetAttribute("ArmorSlotType", armorSlotData.slot)
    slotFrame.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
    slotFrame.Position = UDim2.new(0.5, -SLOT_SIZE/2, 0.3, yOffset)
    slotFrame.BackgroundTransparency = 1
    slotFrame.BorderSizePixel = 0
    slotFrame.Visible = false
    slotFrame.Parent = parent or screenGui
    -- Add hotbar slot image as background
    local slotImage = Instance.new("ImageLabel")
    slotImage.Name = "SlotImage"
    slotImage.Size = UDim2.new(1, 0, 1, 0)
    slotImage.Position = UDim2.new(0, 0, 0, 0)
    slotImage.BackgroundTransparency = 1
    slotImage.Image = "rbxassetid://71503412974519"
    slotImage.Parent = slotFrame
    -- Remove slot outline (no UIStroke)
    
    -- Remove slot corner rounding (no UICorner)
    
    -- Default slot icon (when empty) - remove emoji
    local defaultIcon = Instance.new("TextLabel")
    defaultIcon.Name = "DefaultIcon"
    defaultIcon.Size = UDim2.new(1, 0, 0.6, 0)
    defaultIcon.Position = UDim2.new(0, 0, 0, 0)
    defaultIcon.BackgroundTransparency = 1
    defaultIcon.Text = ""
    defaultIcon.TextColor3 = Color3.fromRGB(120, 120, 120)
    defaultIcon.TextSize = 20 -- Bigger font for icon
    defaultIcon.Font = Enum.Font.Gotham
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
    itemDisplay.TextSize = 18 -- Bigger font for item name
    itemDisplay.Font = Enum.Font.Gotham
    itemDisplay.TextScaled = true
    itemDisplay.TextWrapped = true
    itemDisplay.TextXAlignment = Enum.TextXAlignment.Center
    itemDisplay.TextYAlignment = Enum.TextYAlignment.Center
    itemDisplay.Visible = false
    itemDisplay.Parent = slotFrame
    
    -- Slot label - change helmet to 'Headgear', chestplate to 'Body Armor'
    local slotLabel = Instance.new("TextLabel")
    slotLabel.Name = "SlotLabel"
    slotLabel.Size = UDim2.new(1, 0, 0.4, 0)
    slotLabel.Position = UDim2.new(0, 0, 0.6, 0)
    slotLabel.BackgroundTransparency = 1
    slotLabel.Text = armorSlotData.name
    slotLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    slotLabel.TextSize = 16 -- Bigger font for slot label
    slotLabel.Font = Enum.Font.Gotham
    slotLabel.TextXAlignment = Enum.TextXAlignment.Center
    slotLabel.TextYAlignment = Enum.TextYAlignment.Center
    slotLabel.TextWrapped = true
    -- Put long words on a new line if needed
    if armorSlotData.slot == "chestplate" then
        slotLabel.Text = "Body\nArmor"
    elseif armorSlotData.slot == "helmet" then
        slotLabel.Text = "Head\nGear"
    else
        slotLabel.Text = armorSlotData.name
    end
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
    
    -- Add UIStroke for outline/highlight (hidden by default)
    local slotStroke = Instance.new("UIStroke")
    slotStroke.Color = Color3.fromRGB(220, 220, 220)
    slotStroke.Thickness = 0 -- Hidden by default
    slotStroke.Parent = slotFrame

    -- Add overlay for hover effect (default hidden)
    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundColor3 = Color3.new(1, 1, 1)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 3
    overlay.Parent = slotFrame
    
    -- Store slot reference
    slots[armorSlotData.slot] = {
        frame = slotFrame,
        defaultIcon = defaultIcon,
        itemDisplay = itemDisplay,
        stroke = slotStroke, -- Store the stroke
        overlay = overlay,   -- Store the overlay
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
    -- Hover highlight logic (match hotbar)
    clickDetector.MouseEnter:Connect(function()
        slotStroke.Color = Color3.fromRGB(220, 220, 220)
        slotStroke.Thickness = 2
        overlay.BackgroundTransparency = 0.93
    end)
    clickDetector.MouseLeave:Connect(function()
        slotStroke.Thickness = 0
        overlay.BackgroundTransparency = 1
    end)
    -- Store original Y offset for animation
    slotOriginalYs[slotFrame] = yOffset
end

function ArmorMenu:Show()
    print("[ARMOR MENU DEBUG] --- Show START ---")
    print("[ARMOR MENU DEBUG] Current visibility state:", isVisible)
    
    if not isVisible then
        print("[ARMOR MENU DEBUG] Showing armor menu")
        -- Animate slotsContainer (decal and slots move together)
        if self.slotsContainer then
            self.slotsContainer.Visible = true
            self.slotsContainer.Position = UDim2.new(0, 0, SLOTS_CONTAINER_Y_SCALE, SLOTS_CONTAINER_Y_OFFSET_HIDDEN)
            if slotsContainerTween then slotsContainerTween:Cancel() end
            slotsContainerTween = TweenService:Create(self.slotsContainer, TweenInfo.new(SLOTS_CONTAINER_ANIM_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, SLOTS_CONTAINER_Y_SCALE, SLOTS_CONTAINER_Y_OFFSET_VISIBLE)})
            slotsContainerTween:Play()
        end
        -- Show all slot frames and decal
        for _, slot in pairs(slots) do
            if slot.frame then slot.frame.Visible = true end
        end
        if self.decalImage then self.decalImage.Visible = true end
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
        
        -- Camera zoom in
        if _G.CameraSystem and _G.CameraSystem.ZoomIn then
            _G.CameraSystem:ZoomIn()
        end
        
        print("[ARMOR MENU DEBUG] SUCCESS: Armor menu shown")
        if self.statsPanel then
            self.statsPanel:Show()
        end
        -- Request stats from server and start update loop
        RemoteEvents.StatsUpdate:FireServer()
        startStatsUpdateLoop()

        -- Show and tween in darken overlay
        -- if self.darkenOverlay then
        --     self.darkenOverlay.Visible = true
        --     if darkenTween then darkenTween:Cancel() end
        --     darkenTween = TweenService:Create(self.darkenOverlay, TweenInfo.new(DARKEN_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = DARKEN_TARGET_TRANSPARENCY})
        --     darkenTween:Play()
        -- end
    else
        print("[ARMOR MENU DEBUG] Menu already visible, no action needed")
    end
    
    print("[ARMOR MENU DEBUG] --- Show END ---")
end

function ArmorMenu:Hide()
    if isVisible then
        if self.slotsContainer then
            if slotsContainerTween then slotsContainerTween:Cancel() end
            slotsContainerTween = TweenService:Create(self.slotsContainer, TweenInfo.new(SLOTS_CONTAINER_ANIM_TIME_OUT, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(0, 0, SLOTS_CONTAINER_Y_SCALE, SLOTS_CONTAINER_Y_OFFSET_HIDDEN)})
            slotsContainerTween:Play()
            task.delay(SLOTS_CONTAINER_ANIM_TIME_OUT, function()
                self.slotsContainer.Visible = false
            end)
        end
        -- Hide all slot frames and decal after animation
        task.delay(SLOTS_CONTAINER_ANIM_TIME_OUT, function()
            for _, slot in pairs(slots) do
                if slot.frame then slot.frame.Visible = false end
            end
            if self.decalImage then self.decalImage.Visible = false end
        end)
        modalButton.Visible = false -- Hide modal button to restore cursor lock
        isVisible = false
        -- Restore mouse behavior (let other systems handle it)
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        UserInputService.MouseIconEnabled = false
        -- Show crosshair when armor menu is closed
        if _G.CameraSystem then
            _G.CameraSystem:ShowCrosshair()
        end
        -- Camera zoom out
        if _G.CameraSystem and _G.CameraSystem.ZoomOut then
            _G.CameraSystem:ZoomOut()
        end
        print("Armor menu hidden")
        if self.statsPanel then
            self.statsPanel:Hide()
        end
        stopStatsUpdateLoop()

        -- Tween out and hide darken overlay
        -- if self.darkenOverlay then
        --     if darkenTween then darkenTween:Cancel() end
        --     darkenTween = TweenService:Create(self.darkenOverlay, TweenInfo.new(DARKEN_TWEEN_TIME_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1})
        --     darkenTween:Play()
        --     task.delay(DARKEN_TWEEN_TIME_OUT, function()
        --         self.darkenOverlay.Visible = false
        --     end)
        -- end
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