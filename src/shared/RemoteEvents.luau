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
    
    -- Server: Create damage system RemoteEvents
    local applyDamageRemote = createRemoteEvent("ApplyDamage")
    
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
    
    -- Damage system remotes
    RemoteEvents.ApplyDamage = applyDamageRemote
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
    
    -- Client: Wait for damage system RemoteEvents
    local applyDamageRemote = ReplicatedStorage:WaitForChild("ApplyDamage")
    
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
    
    -- Damage system remotes
    RemoteEvents.ApplyDamage = applyDamageRemote
end

return RemoteEvents 