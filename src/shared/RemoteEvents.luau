-- Remote events for client-server communication (merged with dialogue system)
local RemoteEvents = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Function to create RemoteEvent if it doesn't exist
local function createRemoteEvent(name)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then
		return existing
	end
	
	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = name
	remoteEvent.Parent = ReplicatedStorage
	return remoteEvent
end

-- Function to create RemoteFunction if it doesn't exist
local function createRemoteFunction(name)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then
		return existing
	end
	
	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = name
	remoteFunction.Parent = ReplicatedStorage
	return remoteFunction
end

if RunService:IsServer() then
    -- Server: Create the RemoteFunctions (existing inventory system)
    local dragRequestRemote = createRemoteFunction("DragRequest")
    local inventoryRequestRemote = createRemoteFunction("InventoryRequest")
    local armorRequestRemote = createRemoteFunction("ArmorRequest")
    
    -- Server: Create dialogue RemoteEvents
    local startDialogueRemote = createRemoteEvent("StartDialogue")
    local displayDialogueRemote = createRemoteEvent("DisplayDialogue")
    local processChoiceRemote = createRemoteEvent("ProcessChoice")
    local endDialogueRemote = createRemoteEvent("EndDialogue")
    local showOverheadTextRemote = createRemoteEvent("ShowOverheadText")
    local openTradeMenuRemote = createRemoteEvent("OpenTradeMenu")
    local openTraderShopRemote = createRemoteEvent("OpenTraderShop")
    local closeTraderShopRemote = createRemoteEvent("CloseTraderShop")
    local tradeRequestRemote = createRemoteFunction("TradeRequest")
    local updateInventoryRemote = createRemoteEvent("UpdateInventory")
    local traderLevelUpdatedRemote = createRemoteEvent("TraderLevelUpdated")
    
    -- Server: Create damage system RemoteEvents
    local applyDamageRemote = createRemoteEvent("ApplyDamage")
    local applyBreakableDamageRemote = createRemoteEvent("ApplyBreakableDamage")
    
    -- Server: Create item consumption RemoteEvents
    local consumeItemRequestRemote = createRemoteEvent("ConsumeItemRequest")
    local consumeItemResponseRemote = createRemoteEvent("ConsumeItemResponse")
    
    -- Server: Create boss spawn RemoteEvent
    local spawnBossRemote = createRemoteEvent("SpawnBoss")
    
    -- Server: Create boss landed RemoteEvent
    local bossLandedRemote = createRemoteEvent("BossLanded")
    
    -- Server: Create boss health update RemoteEvent
    local bossHealthUpdateRemote = createRemoteEvent("BossHealthUpdate")

    -- Server: Create prayer system RemoteEvent
    local _prayerRequestRemote = createRemoteEvent("PrayerRequest")

    -- Server: Create time system RemoteEvents
    local clockUpdateRemote = createRemoteEvent("ClockUpdate")
    local statsUpdateRemote = createRemoteEvent("StatsUpdate")
    
    -- Server: Create revive system RemoteEvents
    local reviveRequestRemote = createRemoteEvent("ReviveRequest")
    local reviveResponseRemote = createRemoteEvent("ReviveResponse")
    
    -- Server: Create animation system RemoteEvents
    local setupEnemyAnimationsRemote = createRemoteEvent("SetupEnemyAnimations")
    local enemyAIStateUpdateRemote = createRemoteEvent("EnemyAIStateUpdate")
    
    -- Server: Create enemy attack validation RemoteEvent
    local enemyAttackRequestRemote = createRemoteEvent("EnemyAttackRequest")
    
    -- Server: Create notification system RemoteEvent
    local showNotificationRemote = createRemoteEvent("ShowNotification")
    -- Optional: Compass unlocked event for immediate client feedback
    local compassUnlockedRemote = createRemoteEvent("CompassUnlocked")
    
    print("Server created DragRequest RemoteFunction") -- Debug
    print("Server created InventoryRequest RemoteFunction") -- Debug
    print("Server created ArmorRequest RemoteFunction") -- Debug
    print("Server created dialogue RemoteEvents") -- Debug
    
    -- Existing inventory system remotes
    RemoteEvents.DragRequest = dragRequestRemote
    RemoteEvents.InventoryRequest = inventoryRequestRemote
    RemoteEvents.ArmorRequest = armorRequestRemote
    
    -- Dialogue system remotes
    RemoteEvents.StartDialogue = startDialogueRemote
    RemoteEvents.DisplayDialogue = displayDialogueRemote
    RemoteEvents.ProcessChoice = processChoiceRemote
    RemoteEvents.EndDialogue = endDialogueRemote
    RemoteEvents.ShowOverheadText = showOverheadTextRemote
    RemoteEvents.OpenTradeMenu = openTradeMenuRemote
    RemoteEvents.OpenTraderShop = openTraderShopRemote
    RemoteEvents.CloseTraderShop = closeTraderShopRemote
    RemoteEvents.TradeRequest = tradeRequestRemote
    RemoteEvents.UpdateInventory = updateInventoryRemote
    RemoteEvents.TraderLevelUpdated = traderLevelUpdatedRemote
    
    -- Damage system remotes
    RemoteEvents.ApplyDamage = applyDamageRemote
    RemoteEvents.ApplyBreakableDamage = applyBreakableDamageRemote
    
    -- Item consumption remotes
    RemoteEvents.ConsumeItemRequest = consumeItemRequestRemote
    RemoteEvents.ConsumeItemResponse = consumeItemResponseRemote
    
    -- Boss spawn remote
    RemoteEvents.SpawnBoss = spawnBossRemote
    
    -- Boss landed remote
    RemoteEvents.BossLanded = bossLandedRemote
    
    -- Boss health update remote
    RemoteEvents.BossHealthUpdate = bossHealthUpdateRemote

    -- Time system remotes
    RemoteEvents.ClockUpdate = clockUpdateRemote
    RemoteEvents.StatsUpdate = statsUpdateRemote
    
    -- Revive system remotes
    RemoteEvents.ReviveRequest = reviveRequestRemote
    RemoteEvents.ReviveResponse = reviveResponseRemote
    
    -- Animation system remotes
    RemoteEvents.SetupEnemyAnimations = setupEnemyAnimationsRemote
    RemoteEvents.EnemyAIStateUpdate = enemyAIStateUpdateRemote
    
    -- Enemy attack validation remote
    RemoteEvents.EnemyAttackRequest = enemyAttackRequestRemote
    
    -- Notification system remote
    RemoteEvents.ShowNotification = showNotificationRemote
    RemoteEvents.CompassUnlocked = compassUnlockedRemote
else
    -- Client: Wait for the RemoteFunctions to be created by server (existing)
    local dragRequestRemote = ReplicatedStorage:WaitForChild("DragRequest")
    local inventoryRequestRemote = ReplicatedStorage:WaitForChild("InventoryRequest")
    local armorRequestRemote = ReplicatedStorage:WaitForChild("ArmorRequest")
    
    -- Client: Wait for dialogue RemoteEvents
    local startDialogueRemote = ReplicatedStorage:WaitForChild("StartDialogue")
    local displayDialogueRemote = ReplicatedStorage:WaitForChild("DisplayDialogue")
    local processChoiceRemote = ReplicatedStorage:WaitForChild("ProcessChoice")
    local endDialogueRemote = ReplicatedStorage:WaitForChild("EndDialogue")
    local showOverheadTextRemote = ReplicatedStorage:WaitForChild("ShowOverheadText")
    local openTradeMenuRemote = ReplicatedStorage:WaitForChild("OpenTradeMenu")
    local openTraderShopRemote = ReplicatedStorage:WaitForChild("OpenTraderShop")
    local closeTraderShopRemote = ReplicatedStorage:WaitForChild("CloseTraderShop")
    local tradeRequestRemote = ReplicatedStorage:WaitForChild("TradeRequest")
    local updateInventoryRemote = ReplicatedStorage:WaitForChild("UpdateInventory")
    local traderLevelUpdatedRemote = ReplicatedStorage:WaitForChild("TraderLevelUpdated")
    
    -- Client: Wait for damage system RemoteEvents
    local applyDamageRemote = ReplicatedStorage:WaitForChild("ApplyDamage")
    local applyBreakableDamageRemote = ReplicatedStorage:WaitForChild("ApplyBreakableDamage")
    
    -- Client: Wait for item consumption RemoteEvents
    local consumeItemRequestRemote = ReplicatedStorage:WaitForChild("ConsumeItemRequest")
    local consumeItemResponseRemote = ReplicatedStorage:WaitForChild("ConsumeItemResponse")
    
    -- Client: Wait for boss spawn RemoteEvent
    local spawnBossRemote = ReplicatedStorage:WaitForChild("SpawnBoss")
    
    -- Client: Wait for boss landed RemoteEvent
    local bossLandedRemote = ReplicatedStorage:WaitForChild("BossLanded")
    
    -- Client: Wait for boss health update RemoteEvent
    local bossHealthUpdateRemote = ReplicatedStorage:WaitForChild("BossHealthUpdate")
    
    -- Client: Wait for prayer system RemoteEvent
    local prayerRequestRemote = ReplicatedStorage:WaitForChild("PrayerRequest")

    -- Client: Wait for time system RemoteEvents
    local clockUpdateRemote = ReplicatedStorage:WaitForChild("ClockUpdate")
    local statsUpdateRemote = ReplicatedStorage:WaitForChild("StatsUpdate")
    
    -- Client: Wait for revive system RemoteEvents
    local reviveRequestRemote = ReplicatedStorage:WaitForChild("ReviveRequest")
    local reviveResponseRemote = ReplicatedStorage:WaitForChild("ReviveResponse")
    
    -- Client: Wait for animation system RemoteEvents
    local setupEnemyAnimationsRemote = ReplicatedStorage:WaitForChild("SetupEnemyAnimations")
    local enemyAIStateUpdateRemote = ReplicatedStorage:WaitForChild("EnemyAIStateUpdate")
    
    -- Client: Wait for enemy attack validation RemoteEvent
    local enemyAttackRequestRemote = ReplicatedStorage:WaitForChild("EnemyAttackRequest")
    
    -- Client: Wait for notification system RemoteEvent
    local showNotificationRemote = ReplicatedStorage:WaitForChild("ShowNotification")
    -- Optional: Compass unlocked event
    local compassUnlockedRemote = ReplicatedStorage:WaitForChild("CompassUnlocked")
    
    print("Client found DragRequest RemoteFunction") -- Debug
    print("Client found InventoryRequest RemoteFunction") -- Debug
    print("Client found ArmorRequest RemoteFunction") -- Debug
    print("Client found dialogue RemoteEvents") -- Debug
    
    -- Existing inventory system remotes
    RemoteEvents.DragRequest = dragRequestRemote
    RemoteEvents.InventoryRequest = inventoryRequestRemote
    RemoteEvents.ArmorRequest = armorRequestRemote
    
    -- Dialogue system remotes
    RemoteEvents.StartDialogue = startDialogueRemote
    RemoteEvents.DisplayDialogue = displayDialogueRemote
    RemoteEvents.ProcessChoice = processChoiceRemote
    RemoteEvents.EndDialogue = endDialogueRemote
    RemoteEvents.ShowOverheadText = showOverheadTextRemote
    RemoteEvents.OpenTradeMenu = openTradeMenuRemote
    RemoteEvents.OpenTraderShop = openTraderShopRemote
    RemoteEvents.CloseTraderShop = closeTraderShopRemote
    RemoteEvents.TradeRequest = tradeRequestRemote
    RemoteEvents.UpdateInventory = updateInventoryRemote
    RemoteEvents.TraderLevelUpdated = traderLevelUpdatedRemote
    
    -- Damage system remotes
    RemoteEvents.ApplyDamage = applyDamageRemote
    RemoteEvents.ApplyBreakableDamage = applyBreakableDamageRemote
    
    -- Item consumption remotes
    RemoteEvents.ConsumeItemRequest = consumeItemRequestRemote
    RemoteEvents.ConsumeItemResponse = consumeItemResponseRemote
    
    -- Boss spawn remote
    RemoteEvents.SpawnBoss = spawnBossRemote
    
    -- Boss landed remote
    RemoteEvents.BossLanded = bossLandedRemote
    
    -- Boss health update remote
    RemoteEvents.BossHealthUpdate = bossHealthUpdateRemote
    
    -- Prayer system remote
    RemoteEvents.PrayerRequest = prayerRequestRemote

    -- Time system remotes
    RemoteEvents.ClockUpdate = clockUpdateRemote
    RemoteEvents.StatsUpdate = statsUpdateRemote
    
    -- Revive system remotes
    RemoteEvents.ReviveRequest = reviveRequestRemote
    RemoteEvents.ReviveResponse = reviveResponseRemote
    
    -- Animation system remotes
    RemoteEvents.SetupEnemyAnimations = setupEnemyAnimationsRemote
    RemoteEvents.EnemyAIStateUpdate = enemyAIStateUpdateRemote
    
    -- Enemy attack validation remote
    RemoteEvents.EnemyAttackRequest = enemyAttackRequestRemote
    
    -- Notification system remote
    RemoteEvents.ShowNotification = showNotificationRemote
    RemoteEvents.CompassUnlocked = compassUnlockedRemote
end

return RemoteEvents 