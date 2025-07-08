-- ItemDetailUI.luau
-- Handles item detail popup interface

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local TraderData = require(ReplicatedStorage.Shared.TraderData)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local ItemDetailUI = {}

-- Track UI state
ItemDetailUI.isDetailOpen = false
ItemDetailUI.currentDetailGui = nil
ItemDetailUI.currentItemId = nil
ItemDetailUI.modalButton = nil -- Track modal button for cursor management

-- Create the item detail popup window
function ItemDetailUI:CreateDetailWindow(itemId, itemData)
	local config = TraderData.UIConfig
	local requirements = TraderData:GetRequirements(itemId)
	
	-- Safety check: Remove any existing ItemDetailGui
	local existingGui = player.PlayerGui:FindFirstChild("ItemDetailGui")
	if existingGui then
		print("WARNING: Found existing ItemDetailGui, removing it")
		existingGui:Destroy()
	end
	
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ItemDetailGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = player.PlayerGui
	
	-- Background overlay (semi-transparent)
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui
	
	-- Main detail frame
	local detailFrame = Instance.new("Frame")
	detailFrame.Name = "DetailFrame"
	detailFrame.Size = config.detailWindowSize
	detailFrame.Position = config.detailWindowPosition
	detailFrame.BackgroundColor3 = config.backgroundColor
	detailFrame.BorderSizePixel = 0
	detailFrame.Parent = screenGui
	
	-- Corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = detailFrame
	
	-- Header section
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "HeaderFrame"
	headerFrame.Size = UDim2.new(1, 0, 0, 80)
	headerFrame.Position = UDim2.new(0, 0, 0, 0)
	headerFrame.BackgroundColor3 = config.frameColor
	headerFrame.BorderSizePixel = 0
	headerFrame.Parent = detailFrame
	
	-- Header corner
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 12)
	headerCorner.Parent = headerFrame
	
	-- Item icon (large)
	local iconFrame = Instance.new("Frame")
	iconFrame.Name = "IconFrame"
	iconFrame.Size = UDim2.new(0, 60, 0, 60)
	iconFrame.Position = UDim2.new(0, 10, 0, 10)
	iconFrame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	iconFrame.BorderSizePixel = 0
	iconFrame.Parent = headerFrame
	
	-- Icon corner
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 8)
	iconCorner.Parent = iconFrame
	
	-- Icon label (placeholder)
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "IconLabel"
	iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = "?"
	iconLabel.TextColor3 = config.textColor
	iconLabel.TextSize = 36
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.Parent = iconFrame
	
	-- Item name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -90, 0, 30)
	nameLabel.Position = UDim2.new(0, 80, 0, 10)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemData.name
	nameLabel.TextColor3 = config.textColor
	nameLabel.TextSize = 20
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = headerFrame
	
	-- Item rarity
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Size = UDim2.new(1, -90, 0, 20)
	rarityLabel.Position = UDim2.new(0, 80, 0, 40)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = itemData.rarity:upper()
	rarityLabel.TextColor3 = config.rarityColors[itemData.rarity] or config.rarityColors.common
	rarityLabel.TextSize = 14
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.Parent = headerFrame
	
	-- Description section
	local descriptionFrame = Instance.new("Frame")
	descriptionFrame.Name = "DescriptionFrame"
	descriptionFrame.Size = UDim2.new(1, -20, 0, 60)
	descriptionFrame.Position = UDim2.new(0, 10, 0, 90)
	descriptionFrame.BackgroundTransparency = 1
	descriptionFrame.Parent = detailFrame
	
	-- Description label
	local descriptionLabel = Instance.new("TextLabel")
	descriptionLabel.Name = "DescriptionLabel"
	descriptionLabel.Size = UDim2.new(1, 0, 1, 0)
	descriptionLabel.BackgroundTransparency = 1
	descriptionLabel.Text = itemData.description
	descriptionLabel.TextColor3 = config.textColor
	descriptionLabel.TextSize = 14
	descriptionLabel.TextWrapped = true
	descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
	descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
	descriptionLabel.Font = Enum.Font.Gotham
	descriptionLabel.Parent = descriptionFrame
	
	-- Requirements section
	local requirementsFrame = Instance.new("Frame")
	requirementsFrame.Name = "RequirementsFrame"
	requirementsFrame.Size = UDim2.new(1, -20, 0, 120)
	requirementsFrame.Position = UDim2.new(0, 10, 0, 160)
	requirementsFrame.BackgroundColor3 = config.frameColor
	requirementsFrame.BorderSizePixel = 0
	requirementsFrame.Parent = detailFrame
	
	-- Requirements corner
	local reqCorner = Instance.new("UICorner")
	reqCorner.CornerRadius = UDim.new(0, 8)
	reqCorner.Parent = requirementsFrame
	
	-- Requirements title
	local reqTitle = Instance.new("TextLabel")
	reqTitle.Name = "RequirementsTitle"
	reqTitle.Size = UDim2.new(1, -20, 0, 25)
	reqTitle.Position = UDim2.new(0, 10, 0, 5)
	reqTitle.BackgroundTransparency = 1
	reqTitle.Text = "Required Items:"
	reqTitle.TextColor3 = config.textColor
	reqTitle.TextSize = 16
	reqTitle.TextXAlignment = Enum.TextXAlignment.Left
	reqTitle.Font = Enum.Font.GothamBold
	reqTitle.Parent = requirementsFrame
	
	-- Requirements list
	local reqScrollFrame = Instance.new("ScrollingFrame")
	reqScrollFrame.Name = "RequirementsScrollFrame"
	reqScrollFrame.Size = UDim2.new(1, -20, 1, -35)
	reqScrollFrame.Position = UDim2.new(0, 10, 0, 30)
	reqScrollFrame.BackgroundTransparency = 1
	reqScrollFrame.BorderSizePixel = 0
	reqScrollFrame.ScrollBarThickness = 4
	reqScrollFrame.ScrollBarImageColor3 = config.accentColor
	reqScrollFrame.Parent = requirementsFrame
	
	-- Requirements layout
	local reqLayout = Instance.new("UIListLayout")
	reqLayout.FillDirection = Enum.FillDirection.Vertical
	reqLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	reqLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	reqLayout.Padding = UDim.new(0, 5)
	reqLayout.SortOrder = Enum.SortOrder.LayoutOrder
	reqLayout.Parent = reqScrollFrame
	
	-- Create requirement items
	for i, requirement in ipairs(requirements) do
		local reqItem = Instance.new("Frame")
		reqItem.Name = "RequirementItem" .. i
		reqItem.Size = UDim2.new(1, -10, 0, 25)
		reqItem.BackgroundTransparency = 1
		reqItem.LayoutOrder = i
		reqItem.Parent = reqScrollFrame
		
		-- Bullet point
		local bullet = Instance.new("TextLabel")
		bullet.Name = "Bullet"
		bullet.Size = UDim2.new(0, 20, 1, 0)
		bullet.Position = UDim2.new(0, 0, 0, 0)
		bullet.BackgroundTransparency = 1
		bullet.Text = "•"
		bullet.TextColor3 = config.accentColor
		bullet.TextSize = 16
		bullet.Font = Enum.Font.GothamBold
		bullet.Parent = reqItem
		
		-- Requirement text
		local reqText = Instance.new("TextLabel")
		reqText.Name = "RequirementText"
		reqText.Size = UDim2.new(1, -25, 1, 0)
		reqText.Position = UDim2.new(0, 25, 0, 0)
		reqText.BackgroundTransparency = 1
		reqText.Text = requirement.quantity .. "x " .. requirement.item
		reqText.TextColor3 = config.textColor
		reqText.TextSize = 14
		reqText.TextXAlignment = Enum.TextXAlignment.Left
		reqText.Font = Enum.Font.Gotham
		reqText.Parent = reqItem
	end
	
	-- Update scroll frame canvas size
	reqLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		reqScrollFrame.CanvasSize = UDim2.new(0, 0, 0, reqLayout.AbsoluteContentSize.Y + 10)
	end)
	reqScrollFrame.CanvasSize = UDim2.new(0, 0, 0, reqLayout.AbsoluteContentSize.Y + 10)
	
	-- Trade button
	local tradeButton = Instance.new("TextButton")
	tradeButton.Name = "TradeButton"
	tradeButton.Size = UDim2.new(1, -20, 0, 40)
	tradeButton.Position = UDim2.new(0, 10, 1, -50)
	tradeButton.BackgroundColor3 = config.accentColor
	tradeButton.BorderSizePixel = 0
	tradeButton.Text = "Trade"
	tradeButton.TextColor3 = Color3.new(1, 1, 1)
	tradeButton.TextSize = 18
	tradeButton.Font = Enum.Font.GothamBold
	tradeButton.Parent = detailFrame
	
	-- Trade button corner
	local tradeCorner = Instance.new("UICorner")
	tradeCorner.CornerRadius = UDim.new(0, 8)
	tradeCorner.Parent = tradeButton
	
	-- Trade button hover effects
	tradeButton.MouseEnter:Connect(function()
		tradeButton.BackgroundColor3 = Color3.new(0.3, 0.5, 0.9)
	end)
	
	tradeButton.MouseLeave:Connect(function()
		tradeButton.BackgroundColor3 = config.accentColor
	end)
	
	-- Trade button click - process the trade
	tradeButton.MouseButton1Click:Connect(function()
		print("Trade button clicked for:", itemData.name)
		self:ProcessTrade(itemId, itemData)
	end)
	
	-- Click overlay to close
	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:CloseItemDetail()
		end
	end)
	
	-- Animate in
	detailFrame.Size = UDim2.new(0, 0, 0, 0)
	detailFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	
	local tween = TweenService:Create(detailFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = config.detailWindowSize,
		Position = config.detailWindowPosition
	})
	tween:Play()
	
	return screenGui
end

-- Create modal button for cursor management (exactly like DialogueUI)
function ItemDetailUI:CreateModalButton()
	if self.modalButton then
		return -- Already exists
	end
	
	if not self.currentDetailGui then
		return -- No detail UI active
	end
	
	-- Create invisible modal button to keep cursor unlocked
	local modalButton = Instance.new("TextButton")
	modalButton.Name = "ItemDetailModalButton"
	modalButton.Size = UDim2.new(1, 0, 1, 0)
	modalButton.Position = UDim2.new(0, 0, 0, 0)
	modalButton.BackgroundTransparency = 1
	modalButton.Text = ""
	modalButton.Modal = true -- This keeps the cursor unlocked
	modalButton.ZIndex = -1 -- Behind other UI elements
	modalButton.Parent = self.currentDetailGui
	
	self.modalButton = modalButton
end

-- Remove modal button
function ItemDetailUI:RemoveModalButton()
	if self.modalButton then
		self.modalButton:Destroy()
		self.modalButton = nil
	end
end

-- Show item detail popup
function ItemDetailUI:ShowItemDetail(itemId, itemData)
	print("ShowItemDetail called for:", itemData.name, "Current detail open:", self.isDetailOpen)
	
	-- Force cleanup any existing detail windows first
	self:ForceCleanup()
	
	-- Now create the new detail window
	self.isDetailOpen = true
	self.currentItemId = itemId

	-- Create detail window
	local detailGui = self:CreateDetailWindow(itemId, itemData)
	self.currentDetailGui = detailGui
	
	-- Create modal button to keep cursor unlocked (BEFORE setting cursor properties)
	self:CreateModalButton()
	
	-- Unlock cursor and hide crosshair when detail opens (AFTER modal button is created)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	
	-- Hide crosshair when detail is open
	if _G.CameraSystem then
		_G.CameraSystem:HideCrosshair()
	end

	print("Showing item detail for:", itemData.name)
end

-- Close item detail popup
function ItemDetailUI:CloseItemDetail()
	print("CloseItemDetail called, isDetailOpen:", self.isDetailOpen)
	
	if not self.isDetailOpen then
		print("Detail not open, ignoring close request")
		return
	end
	
	self.isDetailOpen = false
	self.currentItemId = nil
	
	-- Remove modal button
	self:RemoveModalButton()

	-- Remove detail GUI immediately without animation to prevent glitches
	if self.currentDetailGui then
		print("Destroying detail GUI immediately")
		self.currentDetailGui:Destroy()
		self.currentDetailGui = nil
	else
		print("No detail GUI to destroy")
	end
	

	
	-- Only restore cursor lock if TraderUI is not open
	if not (_G.TraderUI and _G.TraderUI.isShopOpen) then
		-- Restore cursor lock and show crosshair when detail closes
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		
		-- Show crosshair when detail is closed
		if _G.CameraSystem then
			_G.CameraSystem:ShowCrosshair()
		end
		
		print("[ITEM DETAIL DEBUG] Restored cursor lock (TraderUI not open)")
	else
		print("[ITEM DETAIL DEBUG] TraderUI is open, not locking cursor")
	end

	print("Closed item detail")
end

-- Force cleanup of all detail windows (for emergency cleanup)
function ItemDetailUI:ForceCleanup()
	print("ItemDetailUI: Force cleanup called")
	
	-- Reset state
	self.isDetailOpen = false
	self.currentItemId = nil
	self.currentDetailGui = nil
	
	-- Remove modal button
	self:RemoveModalButton()

	-- Remove any ItemDetailGui from PlayerGui
	local allDetailGuis = player.PlayerGui:GetChildren()
	for _, gui in pairs(allDetailGuis) do
		if gui.Name == "ItemDetailGui" then
			print("Force removing ItemDetailGui:", gui)
			gui:Destroy()
		end
	end
	

	
	-- Only restore cursor lock if TraderUI is not open
	if not (_G.TraderUI and _G.TraderUI.isShopOpen) then
		-- Restore cursor lock and show crosshair when cleanup happens
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		
		-- Show crosshair when cleanup happens
		if _G.CameraSystem then
			_G.CameraSystem:ShowCrosshair()
		end
		
		print("[ITEM DETAIL DEBUG] ForceCleanup: Restored cursor lock (TraderUI not open)")
	else
		print("[ITEM DETAIL DEBUG] ForceCleanup: TraderUI is open, not locking cursor")
	end

	print("ItemDetailUI: Force cleanup completed")
end

-- Process a trade request
function ItemDetailUI:ProcessTrade(itemId, itemData)
	print("Processing trade for item:", itemId, itemData.name)
	
	-- Disable the trade button temporarily to prevent double-clicking
	if self.currentDetailGui then
		local detailFrame = self.currentDetailGui:FindFirstChild("ItemDetailFrame")
		if detailFrame then
			local tradeButton = detailFrame:FindFirstChild("TradeButton")
			if tradeButton then
				tradeButton.Enabled = false
				tradeButton.Text = "Trading..."
			end
		end
	end
	
	-- Send trade request to server
	local success, message = RemoteEvents.TradeRequest:InvokeServer(itemId)
	
	-- Handle the response
	if success then
		print("Trade successful:", message)
		
		-- Close the item detail UI immediately
		self:CloseItemDetail()
		
		-- Close the trader UI as well
		if _G.TraderUI then
			_G.TraderUI:CloseShop()
		end
	else
		print("Trade failed:", message)
		
		-- Show error message
		self:ShowTradeMessage("Trade Failed", message or "Unknown error occurred", Color3.fromRGB(255, 0, 0))
		
		-- Re-enable the trade button
		if self.currentDetailGui then
			local detailFrame = self.currentDetailGui:FindFirstChild("ItemDetailFrame")
			if detailFrame then
				local tradeButton = detailFrame:FindFirstChild("TradeButton")
				if tradeButton then
					tradeButton.Enabled = true
					tradeButton.Text = "Trade"
				end
			end
		end
	end
end

-- Show a trade message (success or error)
function ItemDetailUI:ShowTradeMessage(title, message, color)
	if not self.currentDetailGui then return end
	
	local detailFrame = self.currentDetailGui:FindFirstChild("ItemDetailFrame")
	if not detailFrame then return end
	
	-- Create message frame
	local messageFrame = Instance.new("Frame")
	messageFrame.Name = "TradeMessageFrame"
	messageFrame.Size = UDim2.new(1, -20, 0, 80)
	messageFrame.Position = UDim2.new(0, 10, 0, 10)
	messageFrame.BackgroundColor3 = color
	messageFrame.BorderSizePixel = 0
	messageFrame.ZIndex = 10
	messageFrame.Parent = detailFrame
	
	-- Message frame corner
	local messageCorner = Instance.new("UICorner")
	messageCorner.CornerRadius = UDim.new(0, 8)
	messageCorner.Parent = messageFrame
	
	-- Title label
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -10, 0, 25)
	titleLabel.Position = UDim2.new(0, 5, 0, 5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextSize = 18
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = messageFrame
	
	-- Message label
	local messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "MessageLabel"
	messageLabel.Size = UDim2.new(1, -10, 0, 45)
	messageLabel.Position = UDim2.new(0, 5, 0, 30)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Text = message
	messageLabel.TextColor3 = Color3.new(1, 1, 1)
	messageLabel.TextSize = 14
	messageLabel.Font = Enum.Font.Gotham
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextYAlignment = Enum.TextYAlignment.Top
	messageLabel.TextWrapped = true
	messageLabel.Parent = messageFrame
	
	-- Auto-remove message after 3 seconds
	game:GetService("Debris"):AddItem(messageFrame, 3)
end

-- Initialize the item detail UI
function ItemDetailUI:Initialize()
	print("ItemDetailUI initialized")
end

return ItemDetailUI 