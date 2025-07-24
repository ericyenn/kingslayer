-- Server-side drag system for handling network ownership
local DragServerSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Track which objects are being dragged by which players
local draggedObjects = {}

function DragServerSystem:Initialize()
    -- Wait for and get remote events
    local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
    
    -- Handle drag requests from clients
    RemoteEvents.DragRequest.OnServerInvoke = function(player, action, object)
        return self:HandleDragRequest(player, action, object)
    end
    
    -- Clean up when players leave
    Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayerDrags(player)
    end)
    
    print("Drag server system initialized")
end

function DragServerSystem:HandleDragRequest(player, action, object)
    if not object or not object.Parent then
        return false, "Invalid object"
    end
    
    if action == "pickup" then
        return self:HandlePickup(player, object)
    elseif action == "drop" then
        return self:HandleDrop(player, object)
    else
        return false, "Invalid action"
    end
end

function DragServerSystem:HandlePickup(player, object)
    -- Check if object is already being dragged
    if draggedObjects[object] then
        return false, "Object already being dragged"
    end
    -- Check if object can be dragged (has the tag or parent is Draggable model)
    local CollectionService = game:GetService("CollectionService")
    local Constants = require(ReplicatedStorage.Shared.Constants)
    local isModel = object.Parent and CollectionService:HasTag(object.Parent, "Draggable")
    if not (CollectionService:HasTag(object, Constants.TAGS.DRAGGABLE_ITEM) or isModel) then
        return false, "Object not draggable"
    end
    -- If it's a model, always drag the model itself
    if isModel then
        object = object.Parent
        -- Find the part to set network ownership on
        local mainPart = object.PrimaryPart or object:FindFirstChild("Torso") or object:FindFirstChild("HumanoidRootPart")
        if not mainPart then
            return false, "No suitable part to set network ownership"
        end
        -- Set network ownership to the player
        local success, error = pcall(function()
            mainPart:SetNetworkOwner(player)
        end)
        if not success then
            warn("Failed to set network owner:", error)
            return false, "Failed to set network ownership"
        end
    else
        -- Set network ownership to the player for regular parts
        local success, error = pcall(function()
            object:SetNetworkOwner(player)
        end)
        if not success then
            warn("Failed to set network owner:", error)
            return false, "Failed to set network ownership"
        end
    end
    -- Mark as being dragged
    draggedObjects[object] = player.UserId
    object:SetAttribute("DraggedBy", player.UserId)
    print("Player", player.Name, "picked up", object.Name)
    return true, "Pickup successful"
end

function DragServerSystem:HandleDrop(player, object)
    -- Find the actual dragged object (could be the object itself or its parent model)
    local actualObject = object
    for draggedObj, userId in pairs(draggedObjects) do
        if userId == player.UserId then
            -- Check if this is the object or if object is a child of the dragged model
            if draggedObj == object or (draggedObj:IsA("Model") and object.Parent == draggedObj) then
                actualObject = draggedObj
                break
            end
        end
    end
    
    -- Check if player owns this object
    if draggedObjects[actualObject] ~= player.UserId then
        return false, "You don't own this object"
    end
    
    -- Remove from dragged objects
    draggedObjects[actualObject] = nil
    actualObject:SetAttribute("DraggedBy", nil)
    
    -- Reset network ownership to server
    local success, error = pcall(function()
        actualObject:SetNetworkOwner(nil)
    end)
    
    if not success then
        warn("Failed to reset network owner:", error)
    end
    
    print("Player", player.Name, "dropped", actualObject.Name)
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