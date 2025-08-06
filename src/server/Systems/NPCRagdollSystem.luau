-- NPCRagdollSystem.luau
-- Handles NPC death detection and ragdoll effects

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local NPCRagdollSystem = {}

-- Track ragdolled NPCs
local ragdolledNPCs = {} -- {[npcModel] = true}

-- Set up death detection for an NPC
local function setupNPCRagdoll(npcModel, npcId)
    local humanoid = npcModel:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        warn("NPCRagdollSystem: No humanoid found for NPC:", npcModel.Name)
        return
    end
    
    -- Store original state for restoration (when NPC is first created, not when it dies)
    local humanoidRootPart = npcModel:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart then
        -- Use delayed require to avoid cyclic dependency
        task.spawn(function()
            local ReviveSystem = require(script.Parent.ReviveSystem)
            ReviveSystem:StoreOriginalNPCState(npcModel)
        end)
    end
    
    -- Configure humanoid for ragdoll
    humanoid.BreakJointsOnDeath = false
    
    -- Set up death detection
    humanoid.Died:Connect(function()
        print("NPCRagdollSystem: NPC died, triggering ragdoll:", npcModel.Name)
        
        -- Add Dead tag for revive system (same as players)
        CollectionService:AddTag(npcModel, "Dead")
        
        -- Track dead NPC for revive system (same as players)
        -- Use delayed require to avoid cyclic dependency
        task.spawn(function()
            local ReviveSystem = require(script.Parent.ReviveSystem)
            ReviveSystem:TrackDeadNPC(npcModel)
        end)
        
        -- Convert Motor6D joints to BallSocketConstraints
        for _, part in pairs(npcModel:GetDescendants()) do
            if part:IsA("Motor6D") then
                local Socket = Instance.new("BallSocketConstraint")
                local a1 = Instance.new("Attachment")
                local a2 = Instance.new("Attachment")
                a1.Parent = part.Part0
                a2.Parent = part.Part1
                Socket.Parent = part.Parent
                Socket.Attachment0 = a1
                Socket.Attachment1 = a2
                a1.CFrame = part.C0
                a2.CFrame = part.C1
                Socket.LimitsEnabled = true
                Socket.TwistLimitsEnabled = true
                part:Destroy()
            end
        end
        
        -- Unanchor the NPC so it can ragdoll
        local humanoidRootPart = npcModel:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            humanoidRootPart.Anchored = false
        end
        
        -- Disable ProximityPrompt to prevent dialogue interaction when ragdolled
        local prompt = humanoidRootPart and humanoidRootPart:FindFirstChild("ProximityPrompt")
        if prompt then
            prompt.Enabled = false
        end
        
        ragdolledNPCs[npcModel] = true
        print("NPCRagdollSystem: NPC ragdoll complete:", npcModel.Name)
    end)
    
    print("NPCRagdollSystem: Set up ragdoll for NPC:", npcModel.Name)
end

-- Check if an NPC is ragdolled
function NPCRagdollSystem:IsNPCRagdolled(npcModel)
    return ragdolledNPCs[npcModel] == true
end

-- Register an NPC for ragdoll handling
function NPCRagdollSystem:RegisterNPC(npcModel, npcId)
    setupNPCRagdoll(npcModel, npcId)
end

-- Clean up when NPC is removed
function NPCRagdollSystem:CleanupNPC(npcModel)
    if ragdolledNPCs[npcModel] then
        ragdolledNPCs[npcModel] = nil
        print("NPCRagdollSystem: Cleaned up NPC ragdoll:", npcModel.Name)
    end
end

-- Get all ragdolled NPCs
function NPCRagdollSystem:GetRagdolledNPCs()
    return ragdolledNPCs
end

return NPCRagdollSystem 