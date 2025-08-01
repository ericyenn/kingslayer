-- TraderData.luau
-- Contains all trader configurations and item data for UI display

local TraderData = {}

-- Items available for trading (display data only)
TraderData.Items = {
	iron_sword = {
		id = "iron_sword",
		name = "Iron Sword",
		description = "A sturdy blade forged from iron ore. Perfect for adventurers seeking reliable protection.",
		icon = "rbxassetid://0", -- Placeholder - replace with actual asset ID
		rarity = "common",
		level = 1
	},
	
	steel_armor = {
		id = "steel_armor",
		name = "Steel Armor",
		description = "Heavy protective gear made from refined steel. Offers excellent defense against physical attacks.",
		icon = "rbxassetid://0", -- Placeholder
		rarity = "uncommon",
		level = 2
	},
	
	magic_potion = {
		id = "magic_potion",
		name = "Magic Potion",
		description = "A mysterious elixir that glows with arcane energy. Its effects are said to be extraordinary.",
		icon = "rbxassetid://0", -- Placeholder
		rarity = "rare",
		level = 3
	},
	
	golden_ring = {
		id = "golden_ring",
		name = "Golden Ring",
		description = "An ornate ring crafted from pure gold. Legends speak of its mystical properties.",
		icon = "rbxassetid://0", -- Placeholder
		rarity = "epic",
		level = 4
	},
	
	wooden_shield = {
		id = "wooden_shield",
		name = "Wooden Shield",
		description = "A simple shield carved from oak wood. Basic protection for novice warriors.",
		icon = "rbxassetid://0", -- Placeholder
		rarity = "common",
		level = 1
	},
	
	fire_gem = {
		id = "fire_gem",
		name = "Fire Gem",
		description = "A brilliant red gemstone that radiates warmth. Contains the essence of flame itself.",
		icon = "rbxassetid://0", -- Placeholder
		rarity = "rare",
		level = 3
	},
	
	healing_herbs = {
		id = "healing_herbs",
		name = "Healing Herbs",
		description = "Fresh medicinal plants gathered from the forest. Known for their restorative properties.",
		icon = "rbxassetid://0", -- Placeholder
		rarity = "common",
		level = 1
	},
	
	dragon_scale = {
		id = "dragon_scale",
		name = "Dragon Scale",
		description = "A magnificent scale from an ancient dragon. Incredibly rare and valuable.",
		icon = "rbxassetid://0", -- Placeholder
		rarity = "legendary",
		level = 4
	},
	
	silver_coin = {
		id = "silver_coin",
		name = "Silver Coin",
		description = "Standard currency used throughout the realm. Accepted by all merchants.",
		icon = "rbxassetid://0", -- Placeholder
		rarity = "common",
		level = 1
	},
	
	enchanted_book = {
		id = "enchanted_book",
		name = "Enchanted Book",
		description = "An ancient tome filled with magical knowledge. The pages seem to shimmer with power.",
		icon = "rbxassetid://0", -- Placeholder
		rarity = "epic",
		level = 4
	},
	
	crystal_orb = {
		id = "crystal_orb",
		name = "Crystal Orb",
		description = "A perfectly spherical crystal that seems to contain swirling mists. Purpose unknown.",
		icon = "rbxassetid://0", -- Placeholder
		rarity = "rare",
		level = 3
	},
	
	iron_ingot = {
		id = "iron_ingot",
		name = "Iron Ingot",
		description = "A refined bar of iron metal. Essential material for crafting weapons and tools.",
		icon = "rbxassetid://0", -- Placeholder
		rarity = "common",
		level = 1
	}
}

-- Trade requirements for each item (display only - no validation)
TraderData.Requirements = {
	iron_sword = {
		{item = "iron_ingot", quantity = 2},
		{item = "wood", quantity = 1}
	},
	
	steel_armor = {
		{item = "iron_ingot", quantity = 3},
		{item = "silver_coin", quantity = 5}
	},
	
	magic_potion = {
		{item = "healing_herbs", quantity = 2},
		{item = "crystal_orb", quantity = 1}
	},
	
	golden_ring = {
		{item = "golden_ring", quantity = 1},
		{item = "dragon_scale", quantity = 1}
	},
	
	wooden_shield = {
		{item = "wood", quantity = 2}
	},
	
	fire_gem = {
		{item = "fire_gem", quantity = 1},
		{item = "crystal_orb", quantity = 1}
	},
	
	healing_herbs = {
		{item = "healing_herbs", quantity = 1}
	},
	
	dragon_scale = {
		{item = "dragon_scale", quantity = 1}
	},
	
	silver_coin = {
		{item = "silver_coin", quantity = 1}
	},
	
	enchanted_book = {
		{item = "enchanted_book", quantity = 1},
		{item = "dragon_scale", quantity = 2}
	},
	
	crystal_orb = {
		{item = "crystal_orb", quantity = 1}
	},
	
	iron_ingot = {
		{item = "iron_ingot", quantity = 1}
	}
}

-- UI Configuration for trader interface
TraderData.UIConfig = {
	-- Grid layout
	itemsPerRow = 4,
	gridPadding = 10,
	itemSlotSize = UDim2.new(0, 100, 0, 100),
	
	-- Main window
	shopWindowSize = UDim2.new(0, 600, 0, 500),
	shopWindowPosition = UDim2.new(0.5, -300, 0.5, -250),
	
	-- Item detail popup
	detailWindowSize = UDim2.new(0, 400, 0, 350),
	detailWindowPosition = UDim2.new(0.5, -200, 0.5, -175),
	
	-- Colors
	backgroundColor = Color3.new(0.1, 0.1, 0.1),
	frameColor = Color3.new(0.15, 0.15, 0.15),
	accentColor = Color3.new(0.2, 0.4, 0.8),
	textColor = Color3.new(0.9, 0.9, 0.9),
	
	-- Rarity colors
	rarityColors = {
		common = Color3.new(0.6, 0.6, 0.6),
		uncommon = Color3.new(0.3, 0.8, 0.3),
		rare = Color3.new(0.3, 0.3, 0.9),
		epic = Color3.new(0.8, 0.3, 0.8),
		legendary = Color3.new(1, 0.8, 0.2)
	}
}

-- Get ordered list of items for display
function TraderData:GetItemList()
	print("TraderData: Getting item list")
	local itemList = {}
	for itemId, itemData in pairs(self.Items) do
		print("TraderData: Adding item", itemId, itemData.name)
		table.insert(itemList, {
			id = itemId,
			data = itemData
		})
	end
	
	print("TraderData: Total items before sort:", #itemList)
	
	-- Sort by rarity and name
	local rarityOrder = {common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5}
	table.sort(itemList, function(a, b)
		local rarityA = rarityOrder[a.data.rarity] or 1
		local rarityB = rarityOrder[b.data.rarity] or 1
		if rarityA == rarityB then
			return a.data.name < b.data.name
		end
		return rarityA < rarityB
	end)
	
	print("TraderData: Total items after sort:", #itemList)
	return itemList
end

-- Get item data by ID
function TraderData:GetItem(itemId)
	return self.Items[itemId]
end

-- Get requirements for an item
function TraderData:GetRequirements(itemId)
	return self.Requirements[itemId] or {}
end

return TraderData 