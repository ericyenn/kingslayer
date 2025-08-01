-- TraderUI.luau
-- Handles client-side trader shop interface

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local TraderData = require(ReplicatedStorage.Shared.TraderData)

local TraderUI = {}

-- Track UI state
TraderUI.isShopOpen = false
TraderUI.currentShopGui = nil
TraderUI.currentConfig = nil
TraderUI.ItemDetailUI = nil -- Will be set from init.client.luau
TraderUI.modalButton = nil -- Track modal button for cursor management

-- Create the main trader shop window
function TraderUI:CreateShopWindow(traderData)
	local config = traderData.config
	
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TraderShopGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = player.PlayerGui
	
	-- Main shop frame
	local shopFrame = Instance.new("Frame")
	shopFrame.Name = "ShopFrame"
	shopFrame.Size = config.shopWindowSize
	shopFrame.Position = config.shopWindowPosition
	shopFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45) -- Muted grey like DialogueUI
	shopFrame.BackgroundTransparency = 0.1 -- Semi-transparent
	shopFrame.BorderSizePixel = 0
	shopFrame.Parent = screenGui
	
	-- Corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12) -- Gentle rounding like DialogueUI
	corner.Parent = shopFrame
	
	-- Header frame
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "HeaderFrame"
	headerFrame.Size = UDim2.new(1, 0, 0, 50)
	headerFrame.Position = UDim2.new(0, 0, 0, 0)
	headerFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50) -- Muted grey like choice boxes
	headerFrame.BackgroundTransparency = 0.2 -- Semi-transparent
	headerFrame.BorderSizePixel = 0
	headerFrame.Parent = shopFrame
	
	-- Header corner
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 12)
	headerCorner.Parent = headerFrame
	
	-- Title label
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -60, 1, 0)
	titleLabel.Position = UDim2.new(0, 10, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Trader's Wares"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White text like DialogueUI
	titleLabel.TextSize = 24
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = headerFrame
	
	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 40, 0, 40)
	closeButton.Position = UDim2.new(1, -45, 0, 5)
	closeButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40) -- Darker red
	closeButton.BackgroundTransparency = 0.3 -- Semi-transparent
	closeButton.BorderSizePixel = 0
	closeButton.Text = "×"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextSize = 24
	closeButton.Font = Enum.Font.GothamBold
	closeButton.ZIndex = 10  -- Ensure button is on top
	closeButton.Parent = headerFrame
	
	-- Close button corner
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton
	
	-- Close button hover effects (BOTW-style)
	closeButton.MouseEnter:Connect(function()
		closeButton.BackgroundColor3 = Color3.fromRGB(120, 60, 60) -- Lighter red on hover
		closeButton.BackgroundTransparency = 0.1
	end)
	
	closeButton.MouseLeave:Connect(function()
		closeButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
		closeButton.BackgroundTransparency = 0.3
	end)
	
	-- Close button click
	closeButton.MouseButton1Click:Connect(function()
		print("Close button clicked!")
		self:CloseShop()
	end)
	
	-- Content frame (holds all the level sections)
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, -20, 1, -70)
	contentFrame.Position = UDim2.new(0, 10, 0, 60)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = shopFrame
	
	-- Scrolling frame for content
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ContentScrollFrame"
	scrollFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollFrame.Position = UDim2.new(0, 0, 0, 0)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 8
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 200) -- Blue accent like DialogueUI hover
	scrollFrame.Parent = contentFrame
	
	-- List layout to stack level containers vertically
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 20) -- 20px spacing between levels
	listLayout.Parent = scrollFrame
	
	-- Padding for scroll frame
	local scrollPadding = Instance.new("UIPadding")
	scrollPadding.PaddingTop = UDim.new(0, 10)
	scrollPadding.PaddingBottom = UDim.new(0, 10)
	scrollPadding.PaddingLeft = UDim.new(0, 10)
	scrollPadding.PaddingRight = UDim.new(0, 10)
	scrollPadding.Parent = scrollFrame
	
	return screenGui, scrollFrame
end

-- Create a level section (header + items)
function TraderUI:CreateLevelSection(level, items, config, parent)
	-- Create level container
	local levelContainer = Instance.new("Frame")
	levelContainer.Name = "LevelContainer_" .. level
	levelContainer.Size = UDim2.new(1, 0, 0, 0) -- Auto-size height
	levelContainer.BackgroundTransparency = 1
	levelContainer.LayoutOrder = level -- Use level number for ordering
	levelContainer.Parent = parent
	
	-- Level header banner
	local headerBanner = Instance.new("Frame")
	headerBanner.Name = "LevelHeader"
	headerBanner.Size = UDim2.new(1, 0, 0, 60) -- Bigger height for banner
	headerBanner.Position = UDim2.new(0, 0, 0, 0)
	headerBanner.BackgroundColor3 = Color3.fromRGB(50, 50, 50) -- Muted grey like choice boxes
	headerBanner.BackgroundTransparency = 0.3 -- Semi-transparent
	headerBanner.BorderSizePixel = 0
	headerBanner.Parent = levelContainer
	
	-- Header banner corner rounding
	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, 8) -- Gentle rounding like DialogueUI
	bannerCorner.Parent = headerBanner
	
	-- Level header text
	local headerLabel = Instance.new("TextLabel")
	headerLabel.Name = "HeaderText"
	headerLabel.Size = UDim2.new(1, -20, 1, 0)
	headerLabel.Position = UDim2.new(0, 10, 0, 0)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = "LEVEL " .. level
	headerLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White text like DialogueUI
	headerLabel.TextSize = 28 -- Bigger text
	headerLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerLabel.Font = Enum.Font.GothamBold
	headerLabel.Parent = headerBanner
	
	-- Add accent line to the banner
	local accentLine = Instance.new("Frame")
	accentLine.Name = "AccentLine"
	accentLine.Size = UDim2.new(0, 6, 0, 30)
	accentLine.Position = UDim2.new(0, 5, 0.5, -15)
	accentLine.BackgroundColor3 = Color3.fromRGB(80, 120, 200) -- Blue accent like DialogueUI hover
	accentLine.BorderSizePixel = 0
	accentLine.Parent = headerBanner
	
	-- Accent line corner
	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0, 3)
	accentCorner.Parent = accentLine
	
	-- Items grid container
	local itemsGrid = Instance.new("Frame")
	itemsGrid.Name = "ItemsGrid"
	itemsGrid.Size = UDim2.new(1, 0, 0, 0) -- Auto-size height
	itemsGrid.Position = UDim2.new(0, 0, 0, 80) -- Below banner with spacing
	itemsGrid.BackgroundTransparency = 1
	itemsGrid.Parent = levelContainer
	
	-- Grid layout for items
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 120, 0, 120) -- Slightly larger items
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gridLayout.FillDirectionMaxCells = 4 -- 4 items per row
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = itemsGrid
	
	-- Create items for this level
	for i, itemData in ipairs(items) do
		self:CreateItemSlot(itemData, config, itemsGrid, i)
	end
	
	-- Update container height based on grid content
	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		itemsGrid.Size = UDim2.new(1, 0, 0, gridLayout.AbsoluteContentSize.Y)
		levelContainer.Size = UDim2.new(1, 0, 0, 80 + gridLayout.AbsoluteContentSize.Y + 20) -- Banner + items + spacing
	end)
	
	return levelContainer
end

-- Create a locked level section (shows a message)
function TraderUI:CreateLockedLevelSection(level, config, parent)
	local lockedContainer = Instance.new("Frame")
	lockedContainer.Name = "LockedLevelContainer_" .. level
	lockedContainer.Size = UDim2.new(1, 0, 0, 60) -- Fixed height for the locked message
	lockedContainer.BackgroundTransparency = 1
	lockedContainer.LayoutOrder = level -- Use level number for ordering
	lockedContainer.Parent = parent
	
	local lockedBanner = Instance.new("Frame")
	lockedBanner.Name = "LockedLevelHeader"
	lockedBanner.Size = UDim2.new(1, 0, 0, 60) -- Bigger height for banner
	lockedBanner.Position = UDim2.new(0, 0, 0, 0)
	lockedBanner.BackgroundColor3 = Color3.fromRGB(50, 50, 50) -- Muted grey like choice boxes
	lockedBanner.BackgroundTransparency = 0.3 -- Semi-transparent
	lockedBanner.BorderSizePixel = 0
	lockedBanner.Parent = lockedContainer
	
	local lockedCorner = Instance.new("UICorner")
	lockedCorner.CornerRadius = UDim.new(0, 8)
	lockedCorner.Parent = lockedBanner
	
	local lockedLabel = Instance.new("TextLabel")
	lockedLabel.Name = "LockedLevelText"
	lockedLabel.Size = UDim2.new(1, -20, 1, 0)
	lockedLabel.Position = UDim2.new(0, 10, 0, 0)
	lockedLabel.BackgroundTransparency = 1
	lockedLabel.Text = "LEVEL " .. level .. " - Locked"
	lockedLabel.TextColor3 = Color3.fromRGB(150, 150, 150) -- Muted grey text
	lockedLabel.TextSize = 28 -- Bigger text
	lockedLabel.TextXAlignment = Enum.TextXAlignment.Left
	lockedLabel.Font = Enum.Font.GothamBold
	lockedLabel.Parent = lockedBanner
	
	local accentLine = Instance.new("Frame")
	accentLine.Name = "LockedAccentLine"
	accentLine.Size = UDim2.new(0, 6, 0, 30)
	accentLine.Position = UDim2.new(0, 5, 0.5, -15)
	accentLine.BackgroundColor3 = Color3.fromRGB(150, 150, 150) -- Muted grey accent
	accentLine.BorderSizePixel = 0
	accentLine.Parent = lockedBanner
	
	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0, 3)
	accentCorner.Parent = accentLine
	
	return lockedContainer
end

-- Create an item slot
function TraderUI:CreateItemSlot(itemData, config, parent, layoutOrder)
	local itemFrame = Instance.new("Frame")
	itemFrame.Name = "ItemSlot_" .. itemData.id
	itemFrame.Size = config.itemSlotSize
	itemFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50) -- Muted grey like choice boxes
	itemFrame.BackgroundTransparency = 0.3 -- Semi-transparent
	itemFrame.BorderSizePixel = 0
	itemFrame.LayoutOrder = layoutOrder
	itemFrame.Parent = parent
	
	-- Corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8) -- Gentle rounding like DialogueUI
	corner.Parent = itemFrame
	
	-- Rarity border
	local rarityBorder = Instance.new("Frame")
	rarityBorder.Name = "RarityBorder"
	rarityBorder.Size = UDim2.new(1, 4, 1, 4)
	rarityBorder.Position = UDim2.new(0, -2, 0, -2)
	rarityBorder.BackgroundColor3 = config.rarityColors[itemData.data.rarity] or config.rarityColors.common
	rarityBorder.BorderSizePixel = 0
	rarityBorder.ZIndex = itemFrame.ZIndex - 1
	rarityBorder.Parent = itemFrame
	
	-- Rarity border corner
	local rarityCorner = Instance.new("UICorner")
	rarityCorner.CornerRadius = UDim.new(0, 10)
	rarityCorner.Parent = rarityBorder
	
	-- Item icon (placeholder)
	local iconFrame = Instance.new("Frame")
	iconFrame.Name = "IconFrame"
	iconFrame.Size = UDim2.new(1, -20, 1, -40)
	iconFrame.Position = UDim2.new(0, 10, 0, 10)
	iconFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30) -- Darker grey for icon background
	iconFrame.BorderSizePixel = 0
	iconFrame.Parent = itemFrame
	
	-- Icon corner
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 6)
	iconCorner.Parent = iconFrame
	
	-- Icon label (placeholder for actual icon)
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "IconLabel"
	iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = "?"
	iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White text like DialogueUI
	iconLabel.TextSize = 32
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.Parent = iconFrame
	
	-- Item name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -10, 0, 25)
	nameLabel.Position = UDim2.new(0, 5, 1, -30)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemData.data.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White text like DialogueUI
	nameLabel.TextSize = 12
	nameLabel.TextScaled = true
	nameLabel.TextWrapped = true
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.Parent = itemFrame
	
	-- Click detection
	local clickButton = Instance.new("TextButton")
	clickButton.Name = "ClickButton"
	clickButton.Size = UDim2.new(1, 0, 1, 0)
	clickButton.BackgroundTransparency = 1
	clickButton.Text = ""
	clickButton.Parent = itemFrame
	
	-- Hover effects (BOTW-style)
	clickButton.MouseEnter:Connect(function()
		itemFrame.BackgroundColor3 = Color3.fromRGB(80, 120, 200) -- Blue highlight like DialogueUI
		itemFrame.BackgroundTransparency = 0.1 -- More opaque when highlighted
		-- Tween scale up slightly
		local tween = TweenService:Create(itemFrame, TweenInfo.new(0.2), {Size = UDim2.new(1.05, 0, 1.05, 0)})
		tween:Play()
	end)
	
	clickButton.MouseLeave:Connect(function()
		itemFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		itemFrame.BackgroundTransparency = 0.3
		-- Tween scale back to normal
		local tween = TweenService:Create(itemFrame, TweenInfo.new(0.2), {Size = config.itemSlotSize})
		tween:Play()
	end)
	
	-- Click handling
	clickButton.MouseButton1Click:Connect(function()
		if self.ItemDetailUI then
			self.ItemDetailUI:ShowItemDetail(itemData.id, itemData.data)
		end
	end)
	
	return itemFrame
end

-- Create modal button for cursor management (exactly like DialogueUI)
function TraderUI:CreateModalButton()
	if self.modalButton then
		return -- Already exists
	end
	
	if not self.currentShopGui then
		return -- No shop UI active
	end
	
	-- Create invisible modal button to keep cursor unlocked
	local modalButton = Instance.new("TextButton")
	modalButton.Name = "TraderModalButton"
	modalButton.Size = UDim2.new(1, 0, 1, 0)
	modalButton.Position = UDim2.new(0, 0, 0, 0)
	modalButton.BackgroundTransparency = 1
	modalButton.Text = ""
	modalButton.Modal = true -- This keeps the cursor unlocked
	modalButton.ZIndex = -1 -- Behind other UI elements
	modalButton.Parent = self.currentShopGui
	
	self.modalButton = modalButton
end

-- Remove modal button
function TraderUI:RemoveModalButton()
	if self.modalButton then
		self.modalButton:Destroy()
		self.modalButton = nil
	end
end

-- Open the trader shop
function TraderUI:OpenShop(traderData)
	if self.isShopOpen then
		print("Shop already open, ignoring request")
		return
	end
	
	print("Opening trader shop with data:", traderData)
	print("Items count:", traderData.items and #traderData.items or "nil")
	print("Current server level:", traderData.currentLevel)
	
	self.isShopOpen = true
	self.currentConfig = traderData.config
	self.currentServerLevel = traderData.currentLevel
	
	-- Create shop window
	local shopGui, scrollFrame = self:CreateShopWindow(traderData)
	self.currentShopGui = shopGui
	
	-- Create modal button to keep cursor unlocked
	self:CreateModalButton()
	
	-- Use small delay to ensure dialogue cleanup is processed first, then set cursor
	task.spawn(function()
		task.wait(0.1) -- Small delay to ensure dialogue EndDialogue has processed
		
		-- Unlock cursor and hide crosshair when shop opens
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		
		print("[TRADER DEBUG] Set MouseBehavior to Default and MouseIconEnabled to true")
	end)
	
	-- Hide crosshair when shop is open
	if _G.CameraSystem then
		_G.CameraSystem:HideCrosshair()
	end

	-- Create level sections for all 4 levels
	for level = 1, 4 do
		if level <= self.currentServerLevel then
			-- Level is unlocked - show items
			local levelItems = {}
			for _, itemData in ipairs(traderData.items) do
				if itemData.data.level == level then
					table.insert(levelItems, itemData)
				end
			end
			
			if #levelItems > 0 then
				print("Creating unlocked level section for level:", level, "with", #levelItems, "items")
				self:CreateLevelSection(level, levelItems, traderData.config, scrollFrame)
			end
		else
			-- Level is locked - show locked message
			print("Creating locked level section for level:", level)
			self:CreateLockedLevelSection(level, traderData.config, scrollFrame)
		end
	end
	
	-- Update scroll frame canvas size
	local function updateCanvasSize()
		local totalHeight = 0
		for _, child in pairs(scrollFrame:GetChildren()) do
			if child:IsA("Frame") then
				totalHeight = totalHeight + child.AbsoluteSize.Y + 10 -- Add spacing between sections
			end
		end
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20) -- Extra padding
	end
	
	-- Update canvas size after a short delay to ensure all elements are sized
	task.spawn(function()
		task.wait(0.2) -- Slightly longer delay for auto-sizing
		updateCanvasSize()
	end)
	
	print("Trader shop opened with", traderData.items and #traderData.items or 0, "items")
end

-- Close the trader shop
function TraderUI:CloseShop()
	print("CloseShop called, isShopOpen:", self.isShopOpen)
	
	if not self.isShopOpen then
		print("Shop not open, ignoring close request")
		return
	end
	
	self.isShopOpen = false
	
	-- Remove modal button
	self:RemoveModalButton()

	-- Close item detail if open (force cleanup to prevent glitches)
	if self.ItemDetailUI then
		print("Force cleaning up item detail UI")
		self.ItemDetailUI:ForceCleanup()
	end
	
	-- Remove shop GUI
	if self.currentShopGui then
		print("Destroying shop GUI")
		self.currentShopGui:Destroy()
		self.currentShopGui = nil
	else
		print("No shop GUI to destroy")
	end
	

	
	-- Restore cursor lock and show crosshair when shop closes
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	
	-- Show crosshair when shop is closed
	if _G.CameraSystem then
		_G.CameraSystem:ShowCrosshair()
	end
	
	-- Notify server
	print("Notifying server of shop close")
	RemoteEvents.CloseTraderShop:FireServer()
	
	print("Trader shop closed")
end

-- Initialize the trader UI
function TraderUI:Initialize(itemDetailUI)
	-- Set up global reference for other systems
	_G.TraderUI = self
	
	self.ItemDetailUI = itemDetailUI
	
	-- Set up RemoteEvent connections
	RemoteEvents.OpenTraderShop.OnClientEvent:Connect(function(traderData)
		self:OpenShop(traderData)
	end)
	
	RemoteEvents.CloseTraderShop.OnClientEvent:Connect(function()
		self:CloseShop()
	end)
	
	print("TraderUI initialized")
end

return TraderUI 