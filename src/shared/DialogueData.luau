-- DialogueData.luau
-- Contains all NPC dialogue configurations

local DialogueData = {}

-- Dialogue states for each NPC
DialogueData.NPCDialogues = {
	-- Wise Man NPC - Changes based on quest state
	wise_man_default = {
		text = "Welcome, I am Gary. What wisdom do you seek?\n\n• [Request Quest] - Why are we here?\n• [Learn Ancient Lore] - What is this land?\n• [Depart] - Thank you for your time, wise one",
		actions = {"start_quest", "show_lore", "goodbye"}
	},
	
	wise_man_quest_active = {
		text = "The princess awaits rescue in the tower!\n\n• [Quest Info] - Tell me about the princess\n• [Learn Ancient Lore] - Tell me of the old days\n• [Depart] - I must go help her",
		actions = {"quest_info", "show_lore", "goodbye"}
	},
	
	-- Princess NPC - Only appears after quest is taken
	princess = {
		text = "Oh brave hero! You've found me! Please help break this terrible curse!\n\n• [Break Curse - Become Companion] - I'll escort you to safety\n• [Break Curse - Test Your Strength] - Prove you're worthy first\n• [Leave Cursed] - I cannot help you right now",
		actions = {"become_companion", "enable_combat", "goodbye"}
	},
	
	-- Trader NPC
	trader = {
		text = "Ah, a customer! I have rare goods to trade.\n\n• [Open Trading Post] - Let's make a deal\n• [Leave] - Perhaps another time",
		actions = {"open_trade", "goodbye"}
	},
	
	-- Regular NPC
	regular_npc = {
		text = "Hello there, traveler! Care to hear a tale?\n\n• [Hear Story] - I'd love to listen\n• [Move Along] - Maybe another time",
		actions = {"tell_story", "goodbye"}
	}
}

-- Response dialogues that replace the old overhead text system
DialogueData.ResponseDialogues = {
	start_quest = {
		text = "My daughter, Ella, was kidnapped by an evil god. They call him the uncrowned king. Bring her back and I shall teach you how to return to your world.",
		actions = {}
	},
	show_lore = {
		text = "Ella, known for her vibrant spirit and her unusual affinity for the high mountain meadows, was not a typical royal. She often ventured far beyond the castle walls, seeking out rare herbs and sketching the intricate patterns of alpine flowers. It was said she had a connection to the 'Aether Weave,' the invisible currents of magic and life that flowed through the peaks. This made her, unbeknownst to her, a beacon.",
		actions = {}
	},
	quest_info = {
		text = "She's trapped in the eastern tower, cursed by an ancient spell. Only a true hero can free her!",
		actions = {}
	},
	become_companion = {
		text = "Thank you! I am free! I shall accompany you on your adventures!",
		actions = {}
	},
	enable_combat = {
		text = "The curse compels me to fight! Defeat me to break the curse forever!",
		actions = {}
	},
	open_trade = {
		text = "Choose your trades wisely! I have the finest goods in the realm!",
		actions = {}
	},
	tell_story = {
		text = "Once upon a time, in a village much like this one, a great dragon threatened all who lived here. But a brave hero rose to challenge the beast, and that's how our town was saved!",
		actions = {}
	}
}

-- Trade configurations for the trader
DialogueData.TradeOptions = {
	{give = "Wood", giveAmount = 5, receive = "Stone", receiveAmount = 1},
	{give = "Stone", giveAmount = 3, receive = "Iron", receiveAmount = 1},
	{give = "Iron", giveAmount = 2, receive = "Gold", receiveAmount = 1},
}

return DialogueData 