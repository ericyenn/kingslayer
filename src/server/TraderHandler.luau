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

-- Server trader state (shared across all players)
TraderHandler.serverState = {
	currentLevel = 1,
	unlockRequests = {
		level2 = {
			requirements = {{item = "revive_plush", quantity = 1}},
			description = "Bring me 1 Revive Plush"
		},
		level3 = {
			requirements = {{item = "fire_gem", quantity = 2}, {item = "silver_coin", quantity = 5}},
			description = "I need 2 Fire Gems and 5 Silver Coins"
		},
		level4 = {
			requirements = {{item = "dragon_scale", quantity = 1}, {item = "golden_ring", quantity = 3}},
			description = "Find me 1 Dragon Scale and 3 Golden Rings"
		}
	}
}

-- Zone tracking system
TraderHandler.zoneItems = {} -- Track items currently in the zone

-- Add item to zone
function TraderHandler:AddItemToZone(itemName)
	self.zoneItems[itemName] = (self.zoneItems[itemName] or 0) + 1
	print("Added item to zone:", itemName, "Total:", self.zoneItems[itemName])
	-- Removed automatic zone completion check - only check when player clicks "Check Tradezone"
end

-- Remove item from zone
function TraderHandler:RemoveItemFromZone(itemName)
	if self.zoneItems[itemName] then
		self.zoneItems[itemName] = self.zoneItems[itemName] - 1
		if self.zoneItems[itemName] <= 0 then
			self.zoneItems[itemName] = nil
		end
		print("Removed item from zone:", itemName, "Remaining:", self.zoneItems[itemName] or 0)
		-- Removed automatic zone completion check - only check when player clicks "Check Tradezone"
	end
end

-- Check if zone requirements are met
function TraderHandler:CheckZoneCompletion()
	local currentRequest = self:GetCurrentUnlockRequest()
	if not currentRequest then
		print("DEBUG: No current unlock request found")
		return false -- No more levels to unlock
	end
	
	print("DEBUG: Checking zone completion for level", self.serverState.currentLevel + 1)
	print("DEBUG: Current request:", currentRequest.description)
	print("DEBUG: Zone items:", self.zoneItems)
	
	-- Check if all requirements are met
	for _, requirement in ipairs(currentRequest.requirements) do
		local currentQuantity = self.zoneItems[requirement.item] or 0
		print("DEBUG: Requirement:", requirement.item, "needed:", requirement.quantity, "have:", currentQuantity)
		if currentQuantity < requirement.quantity then
			print("DEBUG: Not enough", requirement.item, "- need", requirement.quantity, "but have", currentQuantity)
			return false -- Not enough of this item
		end
	end
	
	-- All requirements met!
	print("Zone requirements met! Unlocking next level...")
	self:CompleteZoneRequest()
	return true
end

-- Complete the zone request (called when all requirements met)
function TraderHandler:CompleteZoneRequest()
	-- Find and destroy only the required items in the tradezone
	local CollectionService = game:GetService("CollectionService")
	local tradezones = CollectionService:GetTagged("Tradezone")
	
	if #tradezones > 0 then
		local tradezone = tradezones[1]
		print("Destroying required items in tradezone:", tradezone.Name)
		
		-- Get the current unlock request to know what items to destroy
		local currentRequest = self:GetCurrentUnlockRequest()
		if not currentRequest then
			print("No current unlock request found")
			return
		end
		
		-- Find and destroy only the required items
		local itemsDestroyed = 0
		for _, item in ipairs(workspace:GetChildren()) do
			-- Check if this item is in the tradezone
			if item:IsA("BasePart") or item:IsA("Model") then
				-- Check if item has the DraggableItem tag (actual game items)
				if CollectionService:HasTag(item, "DraggableItem") then
					-- Check if this item is touching the tradezone
					local itemInZone = false
					for _, part in ipairs(tradezone:GetTouchingParts()) do
						if part == item or (item:IsA("Model") and part:IsDescendantOf(item)) then
							itemInZone = true
							break
						end
					end
					
					if itemInZone then
						-- Check if this item is one of the required items for the upgrade
						local ECS = require(game:GetService("ReplicatedStorage").Shared.ECS)
						local identityComponent = ECS:GetComponent(item, "ItemIdentity")
						
						if identityComponent then
							local itemId = identityComponent:GetItemId()
							
							-- Check if this item is required for the upgrade
							for _, requirement in ipairs(currentRequest.requirements) do
								if requirement.item == itemId then
									print("Destroying required item in tradezone:", item.Name, "(", itemId, ")")
									item:Destroy()
									itemsDestroyed = itemsDestroyed + 1
									break -- Only destroy one instance of each required item
								end
							end
						end
					end
				end
			end
		end
		
		print("Destroyed", itemsDestroyed, "required items from tradezone")
	end
	
	-- Clear all items from zone tracking
	self.zoneItems = {}
	
	-- Unlock next level
	self:UnlockNextLevel()
	
	print("Zone request completed and level unlocked!")
end

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
	
	-- Get trader data for client, filtered by current level
	local allItems = TraderData:GetItemList()
	local filteredItems = {}
	
	-- Filter items based on server's current trader level
	for _, itemData in ipairs(allItems) do
		if itemData.data.level <= self.serverState.currentLevel then
			table.insert(filteredItems, itemData)
		end
	end
	
	local uiConfig = TraderData.UIConfig
	
	print("Server: Sending trader data to", player.Name)
	print("Server: Current level:", self.serverState.currentLevel)
	print("Server: Filtered items count:", #filteredItems)
	
	-- Send trader data to client
	RemoteEvents.OpenTraderShop:FireClient(player, {
		items = filteredItems,
		config = uiConfig,
		npcId = npcId or "trader",
		currentLevel = self.serverState.currentLevel
	})
	
	print("Opened trader shop for", player.Name)
end

-- Unlock the next trader level
function TraderHandler:UnlockNextLevel()
	if self.serverState.currentLevel < 4 then
		self.serverState.currentLevel = self.serverState.currentLevel + 1
		print("Trader level unlocked! New level:", self.serverState.currentLevel)
		
		-- Notify all clients of the level change
		RemoteEvents.TraderLevelUpdated:FireAllClients(self.serverState.currentLevel)
		
		return true
	else
		print("Trader is already at maximum level")
		return false
	end
end

-- Get current unlock request
function TraderHandler:GetCurrentUnlockRequest()
	local nextLevel = self.serverState.currentLevel + 1
	if nextLevel <= 4 then
		return self.serverState.unlockRequests["level" .. nextLevel]
	else
		return nil
	end
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
	
	-- Set up zone detection
	self:SetupZoneDetection()
	
	-- Handle player disconnect
	Players.PlayerRemoving:Connect(function(player)
		self:HandlePlayerDisconnect(player)
	end)
	
	print("TraderHandler initialized")
end

-- Setup zone detection for tradezone
function TraderHandler:SetupZoneDetection()
	-- Find the tradezone object by tag
	local CollectionService = game:GetService("CollectionService")
	local tradezones = CollectionService:GetTagged("Tradezone")
	
	if #tradezones == 0 then
		print("WARNING: No objects with 'Tradezone' tag found!")
		return
	end
	
	-- Use the first tradezone found (or you could support multiple)
	local tradezone = tradezones[1]
	print("Found tradezone:", tradezone.Name)
	
	-- Set up touch detection
	tradezone.Touched:Connect(function(hit)
		print("DEBUG: Touch detected:", hit.Name, "Tags:", CollectionService:GetTags(hit))
		print("DEBUG: Part type:", hit.ClassName, "Parent:", hit.Parent and hit.Parent.Name or "None")
		
		-- Check if it's a valid item (not a ragdoll) - check both part and parent
		if self:IsValidItem(hit) then
			print("DEBUG: Item has valid tags")
			
			-- Get the actual item object (handles model parts)
			local itemObject = self:GetItemObject(hit)
			if itemObject then
				print("DEBUG: Got item object:", itemObject.Name)
				-- Get the ItemIdentity component to verify this is a valid game item
				local ECS = require(game:GetService("ReplicatedStorage").Shared.ECS)
				local identityComponent = ECS:GetComponent(itemObject, "ItemIdentity")
				
				if identityComponent then
					local itemId = identityComponent:GetItemId()
					print("Valid item detected in zone:", itemId, "(", identityComponent:GetItemName(), ")")
					self:AddItemToZone(itemId)
				else
					print("Item in zone has no ItemIdentity component:", itemObject.Name)
					print("DEBUG: Available components:", ECS:QueryComponents())
				end
			else
				print("DEBUG: Could not get item object for:", hit.Name)
			end
		else
			print("DEBUG: Item does not have valid tags:", hit.Name)
		end
	end)
	
	tradezone.TouchEnded:Connect(function(hit)
		-- Check if it's a valid item (not a ragdoll) - check both part and parent
		if self:IsValidItem(hit) then
			-- Get the actual item object (handles model parts)
			local itemObject = self:GetItemObject(hit)
			if itemObject then
				-- Get the ItemIdentity component to verify this is a valid game item
				local ECS = require(game:GetService("ReplicatedStorage").Shared.ECS)
				local identityComponent = ECS:GetComponent(itemObject, "ItemIdentity")
				
				if identityComponent then
					local itemId = identityComponent:GetItemId()
					print("Valid item removed from zone:", itemId, "(", identityComponent:GetItemName(), ")")
					self:RemoveItemFromZone(itemId)
				end
			end
		end
	end)
	
	print("Zone detection setup complete for:", tradezone.Name)
end

-- Check if a part is a valid item (similar to altar's IsValidSacrifice)
function TraderHandler:IsValidItem(part)
	local CollectionService = game:GetService("CollectionService")
	local Players = game:GetService("Players")
	
	-- Ignore player character parts
	if part.Name == "Head" or part.Name == "Torso" or part.Name == "HumanoidRootPart" or
	   part.Name:find("Arm") or part.Name:find("Leg") or part.Name == "Handle" then
		-- Check if this part belongs to a player character
		local current = part
		while current.Parent do
			if current:IsA("Model") then
				-- Check if this model is a player character
				for _, player in ipairs(Players:GetPlayers()) do
					if player.Character and (current == player.Character or current:IsDescendantOf(player.Character)) then
						return false -- This is a player character part
					end
				end
			end
			current = current.Parent
		end
	end
	
	-- Check if the part or its parent has the "DraggableItem" tag
	if CollectionService:HasTag(part, "DraggableItem") then
		return true
	end
	
	-- Check if parent is draggable (for model parts)
	if part.Parent and CollectionService:HasTag(part.Parent, "DraggableItem") then
		return true
	end
	
	-- Check if the part or its parent has the "Inventoryable" tag
	if CollectionService:HasTag(part, "Inventoryable") then
		return true
	end
	
	-- Check if parent is inventoryable (for model parts)
	if part.Parent and CollectionService:HasTag(part.Parent, "Inventoryable") then
		return true
	end
	
	return false
end

-- Get the actual item object (handles model parts) - similar to altar's GetSacrificeObject
function TraderHandler:GetItemObject(part)
	local CollectionService = game:GetService("CollectionService")
	
	-- If the part itself is tagged, return it
	if CollectionService:HasTag(part, "DraggableItem") or CollectionService:HasTag(part, "Inventoryable") then
		return part
	end
	
	-- If the parent is tagged, return the parent
	if part.Parent and (CollectionService:HasTag(part.Parent, "DraggableItem") or CollectionService:HasTag(part.Parent, "Inventoryable")) then
		return part.Parent
	end
	
	return nil
end

return TraderHandler 