-- ReviveSystem.luau
-- Server-side system for handling player revives with revive plush

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local ReviveSystem = {}

-- Track dead players and their ragdolls
local deadPlayerRagdolls = {} -- [player] = ragdollCharacter

-- Track dead NPCs (for checking if they're dead, not for revival)
local deadNPCRagdolls = {} -- [npcModel] = true

-- Track original NPC state for restoration
local originalNPCState = {} -- {[npcModel] = {cframe = CFrame}}

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
function ReviveSystem:HandleReviveRequest(reviver, target)
    print("Revive request from", reviver.Name, "for", target.Name)
    
    -- Validate target exists and is dead
    if not target or not target.Parent then
        self:SendReviveResponse(reviver, false, "Target not found")
        return
    end
    
    -- Check if target is actually dead
    if not CollectionService:HasTag(target, "Dead") then
        self:SendReviveResponse(reviver, false, "Target is not dead")
        return
    end
    
    -- Check distance
    if not self:IsWithinReviveDistance(reviver, target) then
        self:SendReviveResponse(reviver, false, "Target is too far away")
        return
    end
    
    -- Check if reviver has revive plush equipped
    if not self:HasRevivePlushEquipped(reviver) then
        self:SendReviveResponse(reviver, false, "You need a revive plush equipped")
        return
    end
    
    -- Perform the revive
    local success = self:PerformRevive(reviver, target)
    if success then
        local targetName = target.Name
        self:SendReviveResponse(reviver, true, "Successfully revived " .. targetName)
    else
        self:SendReviveResponse(reviver, false, "Failed to revive target")
    end
end





-- Check if reviver is within distance of target
function ReviveSystem:IsWithinReviveDistance(reviver, target)
    if not reviver.Character or not reviver.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local targetRootPart
    local Players = game:GetService("Players")
    
    -- Check if target is a Player or NPC model
    if Players:GetPlayerFromCharacter(target) then
        -- Target is a Player
        if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
            return false
        end
        targetRootPart = target.Character.HumanoidRootPart
    else
        -- Target is an NPC model
        targetRootPart = target:FindFirstChild("HumanoidRootPart")
        if not targetRootPart then
            return false
        end
    end
    
    local targetPosition = targetRootPart.Position
    local distance = (reviver.Character.HumanoidRootPart.Position - targetPosition).Magnitude
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
function ReviveSystem:PerformRevive(reviver, target)
    print("ReviveSystem: Performing revive:", reviver.Name, "->", target.Name)
    
    -- Remove dead tag
    CollectionService:RemoveTag(target, "Dead")
    
    local Players = game:GetService("Players")
    
    -- Check if target is a Player or NPC model
    if Players:GetPlayerFromCharacter(target) then
        -- Target is a Player - Load character (this will respawn the player)
        target:LoadCharacter()
        
        -- Clean up ragdoll tracking
        deadPlayerRagdolls[target] = nil
    else
        -- Target is an NPC model - Restore NPC to alive state
        self:RestoreNPC(target)
        
        -- Clean up ragdoll tracking
        deadNPCRagdolls[target] = nil
    end
    
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
    
    print("ReviveSystem: Successfully revived", target.Name)
    return true
end

-- Restore NPC to alive state
function ReviveSystem:RestoreNPC(npcModel)
    print("ReviveSystem: Restoring NPC:", npcModel.Name)
    
    local humanoid = npcModel:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        warn("ReviveSystem: No humanoid found for NPC:", npcModel.Name)
        return false
    end
    
    -- Get original state from local tracking
    local originalState = originalNPCState[npcModel]
    
    if not originalState then
        warn("ReviveSystem: No original state found for NPC:", npcModel.Name)
        return false
    end
    
    -- Remove Dead tag from NPC to prevent health interference
    CollectionService:RemoveTag(npcModel, "Dead")
    
    -- Simple health restoration
    humanoid.MaxHealth = 100
    humanoid.Health = 100
    
    -- Re-anchor the NPC and restore original position and orientation
    local humanoidRootPart = npcModel:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart then
        humanoidRootPart.Anchored = true
        humanoidRootPart.CFrame = originalState.cframe
        print("ReviveSystem: Restored NPC to original CFrame:", originalState.cframe)
    end
    
    -- Restore Motor6D joints from BallSocketConstraints
    for _, part in pairs(npcModel:GetDescendants()) do
        if part:IsA("BallSocketConstraint") then
            -- Find the attachments
            local attachment0 = part.Attachment0
            local attachment1 = part.Attachment1
            
            if attachment0 and attachment1 then
                -- Create new Motor6D joint
                local motor6D = Instance.new("Motor6D")
                motor6D.Name = "RestoredJoint"
                motor6D.Part0 = attachment0.Parent
                motor6D.Part1 = attachment1.Parent
                motor6D.C0 = attachment0.CFrame
                motor6D.C1 = attachment1.CFrame
                motor6D.Parent = attachment0.Parent
                
                -- Destroy the BallSocketConstraint and attachments
                attachment0:Destroy()
                attachment1:Destroy()
                part:Destroy()
            end
        end
    end
    
    -- Re-enable state machine and normal behavior
    humanoid.EvaluateStateMachine = true
    humanoid.PlatformStand = false
    
    -- Re-enable ProximityPrompt for dialogue interaction
    local prompt = humanoidRootPart and humanoidRootPart:FindFirstChild("ProximityPrompt")
    if prompt then
        prompt.Enabled = true
    end
    
    -- Restore torso collision
    local torso = npcModel:FindFirstChild("Torso")
    if torso then
        torso.CanCollide = true
    end
    
    -- Clean up original state tracking
    originalNPCState[npcModel] = nil
    
    print("ReviveSystem: Successfully restored NPC:", npcModel.Name, "with health:", humanoid.Health, "/", humanoid.MaxHealth)
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

-- Track a dead NPC (for checking if dead, not for revival)
function ReviveSystem:TrackDeadNPC(npcModel)
    deadNPCRagdolls[npcModel] = true
    print("ReviveSystem: Tracking dead NPC:", npcModel.Name)
end

-- Store original NPC state when NPC is first created
function ReviveSystem:StoreOriginalNPCState(npcModel)
    local humanoidRootPart = npcModel:FindFirstChild("HumanoidRootPart")
    
    if humanoidRootPart then
        originalNPCState[npcModel] = {
            cframe = humanoidRootPart.CFrame
        }
        print("ReviveSystem: Stored original state for NPC:", npcModel.Name, "at CFrame:", humanoidRootPart.CFrame)
    end
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

-- Check if an NPC is dead
function ReviveSystem:IsNPCDead(npcModel)
    return deadNPCRagdolls[npcModel] == true
end

return ReviveSystem 