-- TraderHandler.luau
-- Handles server-side trader UI coordination

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TraderData = require(ReplicatedStorage.Shared.TraderData)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ItemMapping = require(ReplicatedStorage.Shared.ItemMapping)
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)

local TraderHandler = {}

-- Track active trader sessions {[player] = {npcId, startTime}}
TraderHandler.activeTradeSessions = {}

-- Open trader shop for a player
function TraderHandler:OpenShop(player, npcId)
	-- Check if player already has a trade session
	if self.activeTradeSessions[player] then
		print("Player", player.Name, "already has an active trade session")
		return
	end
	
	-- Create trade session
	self.activeTradeSessions[player] = {
		npcId = npcId or "trader",
		startTime = tick()
	}
	
	-- Get trader data for client
	local itemList = TraderData:GetItemList()
	local uiConfig = TraderData.UIConfig
	
	print("Server: Sending trader data to", player.Name)
	print("Server: Item list count:", #itemList)
	print("Server: First item:", itemList[1] and itemList[1].id or "none")
	
	-- Send trader data to client
	RemoteEvents.OpenTraderShop:FireClient(player, {
		items = itemList,
		config = uiConfig,
		npcId = npcId or "trader"
	})
	
	print("Opened trader shop for", player.Name)
end

-- Close trader shop for a player
function TraderHandler:CloseShop(player)
	if self.activeTradeSessions[player] then
		self.activeTradeSessions[player] = nil
		RemoteEvents.CloseTraderShop:FireClient(player)
		print("Closed trader shop for", player.Name)
	end
end

-- Handle player disconnect cleanup
function TraderHandler:HandlePlayerDisconnect(player)
	if self.activeTradeSessions[player] then
		self.activeTradeSessions[player] = nil
		print("Cleaned up trade session for disconnected player", player.Name)
	end
end

-- Process a trade request from a player
function TraderHandler:ProcessTrade(player, itemId)
	print("Processing trade request for player:", player.Name, "item:", itemId)
	
	-- Check if player has an active trade session
	if not self.activeTradeSessions[player] then
		return false, "No active trade session"
	end
	
	-- Get trade requirements
	local requirements = TraderData:GetRequirements(itemId)
	if not requirements or #requirements == 0 then
		return false, "No trade requirements found for item: " .. itemId
	end
	
	-- Get player's inventory from InventoryServerSystem
	local InventoryServerSystem = _G.InventoryServerSystem
	if not InventoryServerSystem then
		return false, "Inventory system not available"
	end
	
	local playerInventory = InventoryServerSystem:GetPlayerInventory(player)
	if not playerInventory then
		return false, "Player inventory not found"
	end
	
	-- Validate trade requirements
	local isValid, validationResults, missingItems = ItemMapping:ValidateTradeRequirements(playerInventory, requirements)
	
	if not isValid then
		local missingItemsText = {}
		for _, missing in ipairs(missingItems) do
			table.insert(missingItemsText, missing.missing .. "x " .. missing.item)
		end
		return false, "Missing items: " .. table.concat(missingItemsText, ", ")
	end
	
	-- Execute the trade
	local success, errorMessage = self:ExecuteTrade(player, itemId, validationResults, playerInventory)
	
	if success then
		print("Trade successful for player:", player.Name, "item:", itemId)
		return true, "Trade completed successfully"
	else
		print("Trade failed for player:", player.Name, "error:", errorMessage)
		return false, errorMessage or "Trade execution failed"
	end
end

-- Execute the actual trade (remove items and spawn new item)
function TraderHandler:ExecuteTrade(player, itemId, validationResults, playerInventory)
	print("Executing trade for player:", player.Name, "item:", itemId)
	
	-- Get required systems
	local InventoryServerSystem = _G.InventoryServerSystem
	local ItemSpawnSystem = _G.ItemSpawnSystem
	
	if not InventoryServerSystem or not ItemSpawnSystem then
		return false, "Required systems not available"
	end
	
	-- Remove required items from inventory
	for requiredItem, validation in pairs(validationResults) do
		if validation.satisfied then
			local itemsToRemove = validation.required
			local slotsToRemove = validation.slots
			
			-- Remove items from the first slots that contain them
			for i = 1, math.min(itemsToRemove, #slotsToRemove) do
				local slot = slotsToRemove[i]
				local inventoryItem = playerInventory[slot]
				
				if inventoryItem and inventoryItem.object then
					-- Destroy the physical object
					inventoryItem.object:Destroy()
					
					-- Remove from inventory
					InventoryServerSystem:RemoveItemBySlot(player, slot)
					
					print("Removed item from slot", slot, ":", inventoryItem.itemName)
				end
			end
		end
	end
	
	-- Get the game item ID for the traded item
	local gameItemId = ItemMapping:GetGameItemId(itemId)
	if not gameItemId then
		-- If no mapping exists, try to use the itemId directly
		gameItemId = itemId
	end
	
	-- Check if the item exists in ItemDefinitions
	local itemDefinition = ItemDefinitions:GetItem(gameItemId)
	if not itemDefinition then
		return false, "Item definition not found: " .. gameItemId
	end
	
	-- Calculate spawn position (near the player)
	local character = player.Character
	local spawnPosition = Vector3.new(0, 10, 0) -- Default position
	
	if character and character:FindFirstChild("HumanoidRootPart") then
		local rootPart = character.HumanoidRootPart
		-- Spawn 5 studs in front of the player
		spawnPosition = rootPart.Position + rootPart.CFrame.LookVector * 5 + Vector3.new(0, 2, 0)
	end
	
	-- Spawn the new item
	local spawnedItem = ItemSpawnSystem:SpawnItem(gameItemId, spawnPosition)
	
	if spawnedItem then
		print("Spawned traded item:", itemDefinition.name, "at position:", spawnPosition)
		
		-- Update client inventory UI
		RemoteEvents.UpdateInventory:FireClient(player, InventoryServerSystem:GetPlayerInventory(player))
		
		return true, "Trade completed successfully"
	else
		return false, "Failed to spawn traded item"
	end
end

-- Initialize the trader handler
function TraderHandler:Initialize()
	-- Set up RemoteEvent connections
	RemoteEvents.CloseTraderShop.OnServerEvent:Connect(function(player)
		self:CloseShop(player)
	end)
	
	-- Set up trade request handling
	RemoteEvents.TradeRequest.OnServerInvoke = function(player, itemId)
		return self:ProcessTrade(player, itemId)
	end
	
	-- Handle player disconnect
	Players.PlayerRemoving:Connect(function(player)
		self:HandlePlayerDisconnect(player)
	end)
	
	print("TraderHandler initialized")
end

return TraderHandler 