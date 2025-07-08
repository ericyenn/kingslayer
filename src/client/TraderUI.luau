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
	shopFrame.BackgroundColor3 = config.backgroundColor
	shopFrame.BorderSizePixel = 0
	shopFrame.Parent = screenGui
	
	-- Corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = shopFrame
	
	-- Header frame
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "HeaderFrame"
	headerFrame.Size = UDim2.new(1, 0, 0, 50)
	headerFrame.Position = UDim2.new(0, 0, 0, 0)
	headerFrame.BackgroundColor3 = config.frameColor
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
	titleLabel.TextColor3 = config.textColor
	titleLabel.TextSize = 24
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = headerFrame
	
	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 40, 0, 40)
	closeButton.Position = UDim2.new(1, -45, 0, 5)
	closeButton.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "×"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextSize = 24
	closeButton.Font = Enum.Font.GothamBold
	closeButton.ZIndex = 10  -- Ensure button is on top
	closeButton.Parent = headerFrame
	
	-- Close button corner
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton
	
	-- Close button hover effects
	closeButton.MouseEnter:Connect(function()
		closeButton.BackgroundColor3 = Color3.new(1, 0.3, 0.3)
	end)
	
	closeButton.MouseLeave:Connect(function()
		closeButton.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
	end)
	
	-- Close button click
	closeButton.MouseButton1Click:Connect(function()
		print("Close button clicked!")
		self:CloseShop()
	end)
	
	-- Scrolling frame for items
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ItemScrollFrame"
	scrollFrame.Size = UDim2.new(1, -20, 1, -70)
	scrollFrame.Position = UDim2.new(0, 10, 0, 60)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 8
	scrollFrame.ScrollBarImageColor3 = config.accentColor
	scrollFrame.Parent = shopFrame
	
	-- Grid layout for items
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = config.itemSlotSize
	gridLayout.CellPadding = UDim2.new(0, config.gridPadding, 0, config.gridPadding)
	gridLayout.FillDirectionMaxCells = config.itemsPerRow
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = scrollFrame
	
	-- Padding for scroll frame
	local scrollPadding = Instance.new("UIPadding")
	scrollPadding.PaddingTop = UDim.new(0, 10)
	scrollPadding.PaddingBottom = UDim.new(0, 10)
	scrollPadding.PaddingLeft = UDim.new(0, 10)
	scrollPadding.PaddingRight = UDim.new(0, 10)
	scrollPadding.Parent = scrollFrame
	
	return screenGui, scrollFrame
end

-- Create an item slot
function TraderUI:CreateItemSlot(itemData, config, parent, layoutOrder)
	local itemFrame = Instance.new("Frame")
	itemFrame.Name = "ItemSlot_" .. itemData.id
	itemFrame.Size = config.itemSlotSize
	itemFrame.BackgroundColor3 = config.frameColor
	itemFrame.BorderSizePixel = 0
	itemFrame.LayoutOrder = layoutOrder
	itemFrame.Parent = parent
	
	-- Corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
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
	iconFrame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
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
	iconLabel.TextColor3 = config.textColor
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
	nameLabel.TextColor3 = config.textColor
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
	
	-- Hover effects
	clickButton.MouseEnter:Connect(function()
		itemFrame.BackgroundColor3 = Color3.new(0.25, 0.25, 0.25)
		-- Tween scale up slightly
		local tween = TweenService:Create(itemFrame, TweenInfo.new(0.2), {Size = UDim2.new(1.05, 0, 1.05, 0)})
		tween:Play()
	end)
	
	clickButton.MouseLeave:Connect(function()
		itemFrame.BackgroundColor3 = config.frameColor
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
	
	self.isShopOpen = true
	self.currentConfig = traderData.config
	
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

	-- Create item slots
	if traderData.items then
		for i, itemData in ipairs(traderData.items) do
			print("Creating item slot for:", itemData.id, itemData.data.name)
			self:CreateItemSlot(itemData, traderData.config, scrollFrame, i)
		end
	else
		print("ERROR: No items data received!")
	end
	
	-- Update scroll frame canvas size
	local gridLayout = scrollFrame:FindFirstChild("UIGridLayout")
	if gridLayout then
		gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			scrollFrame.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 20)
		end)
		-- Initial canvas size update
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 20)
	end
	
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