-- ReviveSystem.luau
-- Server-side system for handling player revives with revive plush

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local ReviveSystem = {}

-- Track dead players and their ragdolls
local deadPlayerRagdolls = {} -- [player] = ragdollCharacter

-- Configuration
local REVIVE_DISTANCE = 10 -- Maximum distance to revive

function ReviveSystem:Initialize()
    -- Set up RemoteEvent connections
    RemoteEvents.ReviveRequest.OnServerEvent:Connect(function(player, targetPlayer)
        self:HandleReviveRequest(player, targetPlayer)
    end)
    
    -- Track player leaving to clean up
    Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayer(player)
    end)
    
    print("ReviveSystem initialized")
end

-- Handle revive request from client
function ReviveSystem:HandleReviveRequest(reviver, targetPlayer)
    print("Revive request from", reviver.Name, "for", targetPlayer.Name)
    
    -- Validate target player exists and is dead
    if not targetPlayer or not targetPlayer.Parent then
        self:SendReviveResponse(reviver, false, "Target player not found")
        return
    end
    
    -- Check if target is actually dead
    if not CollectionService:HasTag(targetPlayer, "Dead") then
        self:SendReviveResponse(reviver, false, "Target player is not dead")
        return
    end
    

    
    -- Check distance
    if not self:IsWithinReviveDistance(reviver, targetPlayer) then
        self:SendReviveResponse(reviver, false, "Target player is too far away")
        return
    end
    
    -- Check if reviver has revive plush equipped
    if not self:HasRevivePlushEquipped(reviver) then
        self:SendReviveResponse(reviver, false, "You need a revive plush equipped")
        return
    end
    
    -- Perform the revive
    local success = self:PerformRevive(reviver, targetPlayer)
    if success then
        self:SendReviveResponse(reviver, true, "Successfully revived " .. targetPlayer.Name)
    else
        self:SendReviveResponse(reviver, false, "Failed to revive player")
    end
end



-- Check if reviver is within distance of target
function ReviveSystem:IsWithinReviveDistance(reviver, targetPlayer)
    if not reviver.Character or not reviver.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local distance = (reviver.Character.HumanoidRootPart.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
    return distance <= REVIVE_DISTANCE
end

-- Check if player has revive plush equipped
function ReviveSystem:HasRevivePlushEquipped(player)
    local InventoryServerSystem = _G.InventoryServerSystem
    if not InventoryServerSystem then
        warn("ReviveSystem: Could not find InventoryServerSystem to check revive plush")
        return false
    end
    
    -- Get the currently equipped slot
    local equippedSlot = InventoryServerSystem:GetPlayerEquippedSlot(player)
    if not equippedSlot then
        return false
    end
    
    -- Check if the equipped item is a revive plush
    local playerInventories = InventoryServerSystem:GetPlayerInventories()
    local inventoryItem = playerInventories[player] and playerInventories[player][equippedSlot]
    
    if not inventoryItem then
        return false
    end
    
    -- Check if the item is a revive plush by checking the object name
    local itemName = inventoryItem.itemName
    local isRevivePlush = (itemName == "Revive Plush")
    
    return isRevivePlush
end

-- Perform the actual revive
function ReviveSystem:PerformRevive(reviver, targetPlayer)
    print("ReviveSystem: Performing revive:", reviver.Name, "->", targetPlayer.Name)
    
    -- Remove dead tag
    CollectionService:RemoveTag(targetPlayer, "Dead")
    
    -- Load character (this will respawn the player)
    targetPlayer:LoadCharacter()
    
    -- Clean up ragdoll tracking
    deadPlayerRagdolls[targetPlayer] = nil
    
    -- Consume revive plush from reviver's inventory
    local InventoryServerSystem = _G.InventoryServerSystem
    
    if InventoryServerSystem then
        -- Get the currently equipped slot
        local equippedSlot = InventoryServerSystem:GetPlayerEquippedSlot(reviver)
        
        if equippedSlot then
            -- Direct server-side consumption (same as functional items but server-side)
            local success, message = InventoryServerSystem:ConsumeItem(reviver, equippedSlot)
            if success then
                print("ReviveSystem: Consumed revive plush from", reviver.Name)
                -- Send consumption response to client to update UI
                RemoteEvents.ConsumeItemResponse:FireClient(reviver, success, message, equippedSlot)
            else
                warn("ReviveSystem: Failed to consume revive plush from", reviver.Name, "error:", message)
            end
        end
    else
        warn("ReviveSystem: Could not find InventoryServerSystem to consume revive plush")
    end
    
    print("ReviveSystem: Successfully revived", targetPlayer.Name)
    return true
end

-- Send revive response to client
function ReviveSystem:SendReviveResponse(player, success, message)
    RemoteEvents.ReviveResponse:FireClient(player, success, message)
end

-- Track a dead player ragdoll
function ReviveSystem:TrackDeadPlayer(player, ragdollCharacter)
    deadPlayerRagdolls[player] = ragdollCharacter
    print("ReviveSystem: Tracking dead player ragdoll:", player.Name)
end

-- Clean up when player leaves
function ReviveSystem:CleanupPlayer(player)
    deadPlayerRagdolls[player] = nil
    print("Cleaned up revive data for:", player.Name)
end

-- Get all dead player ragdolls
function ReviveSystem:GetDeadPlayerRagdolls()
    return deadPlayerRagdolls
end

-- Check if a player is dead
function ReviveSystem:IsPlayerDead(player)
    return deadPlayerRagdolls[player] ~= nil
end



return ReviveSystem 