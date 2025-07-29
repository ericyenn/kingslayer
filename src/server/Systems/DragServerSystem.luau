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
    local isDraggableModel = object.Parent and CollectionService:HasTag(object.Parent, Constants.TAGS.DRAGGABLE_ITEM)
    if not (CollectionService:HasTag(object, Constants.TAGS.DRAGGABLE_ITEM) or isModel or isDraggableModel) then
        return false, "Object not draggable"
    end
    -- If it's a model, always drag the model itself
    if isModel or isDraggableModel then
        object = object.Parent
        -- Find the part to set network ownership on
        local mainPart = object.PrimaryPart or object:FindFirstChild("HumanoidRootPart") or object:FindFirstChild("Torso")
        if not mainPart then
            return false, "No suitable part to set network ownership"
        end
        
        -- Check if this is an enemy ragdoll (has humanoid and is in workspace)
        local humanoid = object:FindFirstChildOfClass("Humanoid")
        local isEnemyRagdoll = humanoid and object.Parent == workspace
        
        print("DEBUG: Object:", object.Name, "Humanoid:", humanoid ~= nil, "Parent:", object.Parent.Name, "IsEnemyRagdoll:", isEnemyRagdoll)
        
        -- Log collision state before network ownership change
        if isEnemyRagdoll then
            print("DEBUG: Collision state BEFORE network ownership change:")
            for _, part in ipairs(object:GetChildren()) do
                if part:IsA("BasePart") and (part.Name:find("Arm") or part.Name:find("Leg") or part.Name == "Torso" or part.Name == "Head") then
                    print("  ", part.Name, "CanCollide:", part.CanCollide)
                end
            end
        end
        
        -- Set network ownership to the player
        local success, error = pcall(function()
            mainPart:SetNetworkOwner(player)
        end)
        if not success then
            warn("Failed to set network owner:", error)
            return false, "Failed to set network ownership"
        end
        
        print("DEBUG: Network ownership set to player:", player.Name)
        
        -- For enemy ragdolls, restore collision settings after network ownership change
        if isEnemyRagdoll then
            print("DEBUG: Restoring collision settings for enemy ragdoll...")
            for _, part in ipairs(object:GetChildren()) do
                if part:IsA("BasePart") and (part.Name:find("Arm") or part.Name:find("Leg") or part.Name == "Torso" or part.Name == "Head") then
                    local oldCollide = part.CanCollide
                    part.CanCollide = true
                    print("  ", part.Name, "CanCollide:", oldCollide, "->", part.CanCollide)
                end
            end
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
    -- Check if object still exists
    if not object or not object.Parent then
        return false, "Object no longer exists"
    end
    
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
    
    -- Check if this is an enemy ragdoll before resetting network ownership
    local humanoid = actualObject:FindFirstChildOfClass("Humanoid")
    local isEnemyRagdoll = humanoid and actualObject.Parent == workspace
    
    print("DEBUG DROP: Object:", actualObject.Name, "Humanoid:", humanoid ~= nil, "Parent:", actualObject.Parent.Name, "IsEnemyRagdoll:", isEnemyRagdoll)
    
    -- Log collision state before network ownership reset
    if isEnemyRagdoll then
        print("DEBUG DROP: Collision state BEFORE network ownership reset:")
        for _, part in ipairs(actualObject:GetChildren()) do
            if part:IsA("BasePart") and (part.Name:find("Arm") or part.Name:find("Leg") or part.Name == "Torso" or part.Name == "Head") then
                print("  ", part.Name, "CanCollide:", part.CanCollide)
            end
        end
    end
    
    -- Reset network ownership to server
    local success, error = pcall(function()
        -- Check if object still exists before trying to reset network ownership
        if actualObject and actualObject.Parent then
            if actualObject:IsA("Model") then
                -- For models, find the primary part or a suitable part to reset network ownership
                local mainPart = actualObject.PrimaryPart or actualObject:FindFirstChild("HumanoidRootPart") or actualObject:FindFirstChild("Torso")
                if mainPart then
                    mainPart:SetNetworkOwner(nil)
                else
                    warn("No suitable part found to reset network ownership for model:", actualObject.Name)
                end
            else
                -- For regular parts, reset network ownership directly
                actualObject:SetNetworkOwner(nil)
            end
        end
    end)
    
    if not success then
        warn("Failed to reset network owner:", error)
    end
    
    print("DEBUG DROP: Network ownership reset to server")
    
    -- For enemy ragdolls, ensure collision settings are maintained after network ownership reset
    if isEnemyRagdoll then
        print("DEBUG DROP: Restoring collision settings for enemy ragdoll...")
        for _, part in ipairs(actualObject:GetChildren()) do
            if part:IsA("BasePart") and (part.Name:find("Arm") or part.Name:find("Leg") or part.Name == "Torso" or part.Name == "Head") then
                local oldCollide = part.CanCollide
                part.CanCollide = true
                print("  ", part.Name, "CanCollide:", oldCollide, "->", part.CanCollide)
            end
        end
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

function DragServerSystem:CleanupObjectDrags(object)
    -- Remove any drag references for a specific object
    if draggedObjects[object] then
        draggedObjects[object] = nil
        if object:GetAttribute("DraggedBy") then
            object:SetAttribute("DraggedBy", nil)
        end
        print("Cleaned up drag references for:", object.Name)
    end
    
    -- Also check if any child parts are being dragged
    if object:IsA("Model") then
        for _, child in ipairs(object:GetDescendants()) do
            if draggedObjects[child] then
                draggedObjects[child] = nil
                if child:GetAttribute("DraggedBy") then
                    child:SetAttribute("DraggedBy", nil)
                end
                print("Cleaned up drag references for child:", child.Name)
            end
        end
    end
end

return DragServerSystem 