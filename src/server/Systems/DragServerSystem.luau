-- Server-side drag system for handling network ownership
local DragServerSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Track which objects are being dragged by which players
local draggedObjects = {}

function DragServerSystem:Initialize()
    -- Wait for and get remote events
    local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
    
    print("Connecting to DragRequest RemoteFunction...") -- Debug
    
    -- Handle drag requests from clients
    RemoteEvents.DragRequest.OnServerInvoke = function(player, action, object)
        print("RemoteFunction invoked by", player.Name) -- Debug
        return self:HandleDragRequest(player, action, object)
    end
    
    -- Clean up when players leave
    Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayerDrags(player)
    end)
    
    print("Drag server system initialized")
end

function DragServerSystem:HandleDragRequest(player, action, object)
    print("Server received drag request from", player.Name, "Action:", action, "Object:", object and object.Name or "nil") -- Debug
    
    if not object or not object.Parent then
        print("Server rejecting: Invalid object") -- Debug
        return false, "Invalid object"
    end
    
    if action == "pickup" then
        return self:HandlePickup(player, object)
    elseif action == "drop" then
        return self:HandleDrop(player, object)
    else
        print("Server rejecting: Invalid action:", action) -- Debug
        return false, "Invalid action"
    end
end

function DragServerSystem:HandlePickup(player, object)
    -- Check if object is already being dragged
    if draggedObjects[object] then
        return false, "Object already being dragged"
    end
    
    -- Check if object can be dragged (has the tag)
    local CollectionService = game:GetService("CollectionService")
    local Constants = require(ReplicatedStorage.Shared.Constants)
    
    if not CollectionService:HasTag(object, Constants.TAGS.DRAGGABLE_ITEM) then
        return false, "Object not draggable"
    end
    
    -- Set network ownership to the player
    local success, error = pcall(function()
        object:SetNetworkOwner(player)
    end)
    
    if not success then
        warn("Failed to set network owner:", error)
        return false, "Failed to set network ownership"
    end
    
    -- Mark as being dragged
    draggedObjects[object] = player.UserId
    object:SetAttribute("DraggedBy", player.UserId)
    
    print("Player", player.Name, "picked up", object.Name)
    return true, "Pickup successful"
end

function DragServerSystem:HandleDrop(player, object)
    -- Check if player owns this object
    if draggedObjects[object] ~= player.UserId then
        return false, "You don't own this object"
    end
    
    -- Remove from dragged objects
    draggedObjects[object] = nil
    object:SetAttribute("DraggedBy", nil)
    
    -- Reset network ownership to server
    local success, error = pcall(function()
        object:SetNetworkOwner(nil)
    end)
    
    if not success then
        warn("Failed to reset network owner:", error)
    end
    
    print("Player", player.Name, "dropped", object.Name)
    return true, "Drop successful"
end

function DragServerSystem:CleanupPlayerDrags(player)
    -- Find all objects dragged by this player and drop them
    for object, userId in pairs(draggedObjects) do
        if userId == player.UserId then
            self:HandleDrop(player, object)
        end
    end
end

return DragServerSystem 