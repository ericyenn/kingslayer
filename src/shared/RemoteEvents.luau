-- Remote events for client-server communication
local RemoteEvents = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if RunService:IsServer() then
    -- Server: Create the RemoteFunctions
    local dragRequestRemote = Instance.new("RemoteFunction")
    dragRequestRemote.Name = "DragRequest"
    dragRequestRemote.Parent = ReplicatedStorage
    
    local inventoryRequestRemote = Instance.new("RemoteFunction")
    inventoryRequestRemote.Name = "InventoryRequest"
    inventoryRequestRemote.Parent = ReplicatedStorage
    
    local armorRequestRemote = Instance.new("RemoteFunction")
    armorRequestRemote.Name = "ArmorRequest"
    armorRequestRemote.Parent = ReplicatedStorage
    
    print("Server created DragRequest RemoteFunction") -- Debug
    print("Server created InventoryRequest RemoteFunction") -- Debug
    print("Server created ArmorRequest RemoteFunction") -- Debug
    
    RemoteEvents.DragRequest = dragRequestRemote
    RemoteEvents.InventoryRequest = inventoryRequestRemote
    RemoteEvents.ArmorRequest = armorRequestRemote
else
    -- Client: Wait for the RemoteFunctions to be created by server
    local dragRequestRemote = ReplicatedStorage:WaitForChild("DragRequest")
    local inventoryRequestRemote = ReplicatedStorage:WaitForChild("InventoryRequest")
    local armorRequestRemote = ReplicatedStorage:WaitForChild("ArmorRequest")
    
    print("Client found DragRequest RemoteFunction") -- Debug
    print("Client found InventoryRequest RemoteFunction") -- Debug
    print("Client found ArmorRequest RemoteFunction") -- Debug
    
    RemoteEvents.DragRequest = dragRequestRemote
    RemoteEvents.InventoryRequest = inventoryRequestRemote
    RemoteEvents.ArmorRequest = armorRequestRemote
end

return RemoteEvents 