-- RevivePromptSystem.luau
-- Client-side system for managing revive proximity prompts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local RevivePromptSystem = {}

local player = Players.LocalPlayer

-- Track revive prompts
local revivePrompts = {} -- [ragdollCharacter] = prompt

-- Configuration
local PROMPT_DISTANCE = 8 -- Distance to show revive prompt (changed from 5 to 8)
local PROMPT_HOLD_DURATION = 8 -- 8 second hold required for revive (changed from 0 to 8)

function RevivePromptSystem:Initialize()
    print("Initializing RevivePromptSystem...")
    
    -- Wait a moment for RemoteEvents to be ready
    task.wait(0.1)
    
    -- Wait for RemoteEvents to be available with error handling
    local success, errorMessage = pcall(function()
        -- Set up revive response handler
        RemoteEvents.ReviveResponse.OnClientEvent:Connect(function(success, message)
            self:HandleReviveResponse(success, message)
        end)
        
        print("RevivePromptSystem initialized successfully")
    end)
    
    if not success then
        warn("RevivePromptSystem initialization failed:", errorMessage)
    end
    
    -- Create prompts for any existing dead players
    self:CreatePromptsForDeadEntities()
    
    -- Monitor for new dead players
    self:SetupDeadEntityMonitoring()
end

-- Set up monitoring for new dead entities (players and NPCs)
function RevivePromptSystem:SetupDeadEntityMonitoring()
    -- Monitor workspace for new ragdoll characters and dead NPCs
    local function checkForNewDeadEntities()
        for _, descendant in pairs(workspace:GetDescendants()) do
            if descendant:IsA("Model") then
                local playerFromCharacter = Players:GetPlayerFromCharacter(descendant)
                
                -- Check for dead players
                if playerFromCharacter and CollectionService:HasTag(playerFromCharacter, "Dead") and CollectionService:HasTag(descendant, "Draggable") then
                    -- Check if we already have a prompt for this ragdoll
                    if not revivePrompts[descendant] then
                        print("RevivePromptSystem: Found new dead player:", playerFromCharacter.Name)
                        self:CreateRevivePrompt(playerFromCharacter, descendant)
                    end
                end
                
                -- Check for dead NPCs
                if not playerFromCharacter and CollectionService:HasTag(descendant, "Dead") and CollectionService:HasTag(descendant, "NPC") then
                    -- Check if we already have a prompt for this NPC
                    if not revivePrompts[descendant] then
                        print("RevivePromptSystem: Found new dead NPC:", descendant.Name)
                        self:CreateRevivePrompt(descendant, descendant)
                    end
                end
            end
        end
    end
    
    -- Check periodically for new dead entities
    task.spawn(function()
        while true do
            task.wait(1) -- Check every second
            checkForNewDeadEntities()
        end
    end)
end

-- Create prompts for all dead entities (players and NPCs) in workspace
function RevivePromptSystem:CreatePromptsForDeadEntities()
    print("RevivePromptSystem: Creating prompts for dead entities...")
    
    local foundDeadPlayers = 0
    local foundDeadNPCs = 0
    
    -- Find all dead entities in workspace
    for _, descendant in pairs(workspace:GetDescendants()) do
        if descendant:IsA("Model") then
            local playerFromCharacter = Players:GetPlayerFromCharacter(descendant)
            
            -- Check for dead players
            if playerFromCharacter and CollectionService:HasTag(playerFromCharacter, "Dead") and CollectionService:HasTag(descendant, "Draggable") then
                foundDeadPlayers = foundDeadPlayers + 1
                print("RevivePromptSystem: Creating prompt for dead player:", playerFromCharacter.Name)
                self:CreateRevivePrompt(playerFromCharacter, descendant)
            end
            
            -- Check for dead NPCs
            if not playerFromCharacter and CollectionService:HasTag(descendant, "Dead") and CollectionService:HasTag(descendant, "NPC") then
                foundDeadNPCs = foundDeadNPCs + 1
                print("RevivePromptSystem: Creating prompt for dead NPC:", descendant.Name)
                self:CreateRevivePrompt(descendant, descendant)
            end
        end
    end
    print("RevivePromptSystem: Found", foundDeadPlayers, "dead players and", foundDeadNPCs, "dead NPCs in workspace")
end

-- Remove all revive prompts
function RevivePromptSystem:RemoveAllPrompts()
    print("RevivePromptSystem: Removing all prompts...")
    for ragdollCharacter, prompt in pairs(revivePrompts) do
        if prompt and prompt.Parent then
            prompt:Destroy()
        end
    end
    revivePrompts = {}
end

-- Create a revive prompt for a dead entity (player or NPC)
function RevivePromptSystem:CreateRevivePrompt(deadEntity, ragdollCharacter)
    -- Don't create duplicate prompts
    if revivePrompts[ragdollCharacter] then
        return
    end
    
    -- Find the primary part of the ragdoll
    local primaryPart = ragdollCharacter.PrimaryPart
    if not primaryPart then
        warn("RevivePromptSystem: No primary part found for ragdoll:", deadEntity.Name)
        return
    end
    
    -- Determine if this is a player or NPC
    local Players = game:GetService("Players")
    local isPlayer = Players:GetPlayerFromCharacter(deadEntity)
    local objectText = isPlayer and "Dead Player" or "Dead NPC"
    
    -- Create the proximity prompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = objectText
    prompt.ActionText = "Revive"
    prompt.HoldDuration = PROMPT_HOLD_DURATION
    prompt.MaxActivationDistance = PROMPT_DISTANCE
    prompt.RequiresLineOfSight = false
    
    -- Connect the triggered event
    prompt.Triggered:Connect(function()
        self:HandleReviveTriggered(deadEntity, ragdollCharacter)
    end)
    
    -- Parent the prompt to the ragdoll's primary part
    prompt.Parent = primaryPart
    
    -- Store the prompt
    revivePrompts[ragdollCharacter] = prompt
    
    print("RevivePromptSystem: Created revive prompt for:", deadEntity.Name)
end

-- Remove a revive prompt
function RevivePromptSystem:RemoveRevivePrompt(ragdollCharacter)
    local prompt = revivePrompts[ragdollCharacter]
    if prompt and prompt.Parent then
        prompt:Destroy()
    end
    revivePrompts[ragdollCharacter] = nil
end

-- Handle when a revive prompt is triggered
function RevivePromptSystem:HandleReviveTriggered(deadEntity, ragdollCharacter)
    print("RevivePromptSystem: Revive triggered for:", deadEntity.Name)
    
    -- Check if player has revive plush equipped at the time of trigger
    local hasRevivePlushEquipped = self:CheckRevivePlushEquipment()
    
    if not hasRevivePlushEquipped then
        print("RevivePromptSystem: Revive plush not equipped, ignoring trigger")
        return
    end
    
    -- Send revive request to server
    RemoteEvents.ReviveRequest:FireServer(deadEntity)
end

-- Check if player has revive plush equipped (only when needed)
function RevivePromptSystem:CheckRevivePlushEquipment()
    -- Get the inventory system to check for revive plush
    local SystemManager = require(ReplicatedStorage.Shared.SystemManager)
    local InventorySystem = SystemManager.GetSystem("InventorySystem")
    
    if InventorySystem then
        -- Check if player has revive plush equipped
        local equippedItem = InventorySystem:GetEquippedItem()
        if equippedItem then
            -- Check if the equipped item is a revive plush
            local itemId = equippedItem.itemId or InventorySystem:GetItemIdFromObject(equippedItem.object)
            local isRevivePlush = (itemId == "revive_plush")
            
            print("RevivePromptSystem: Checking equipped item:", equippedItem.itemName, "itemId:", itemId, "isRevivePlush:", isRevivePlush)
            return isRevivePlush
        else
            print("RevivePromptSystem: No item equipped")
            return false
        end
    else
        warn("RevivePromptSystem: Could not find InventorySystem")
        return false
    end
end

-- Handle revive response from server
function RevivePromptSystem:HandleReviveResponse(success, message)
    if success then
        print("RevivePromptSystem: Revive successful:", message)
        -- Remove all prompts since the player was revived
        self:RemoveAllPrompts()
    else
        print("RevivePromptSystem: Revive failed:", message)
    end
end

-- Manual test function (for debugging)
function RevivePromptSystem:TestRevivePlushDetection()
    print("=== RevivePromptSystem Test ===")
    
    local SystemManager = require(ReplicatedStorage.Shared.SystemManager)
    local InventorySystem = SystemManager.GetSystem("InventorySystem")
    
    if InventorySystem then
        local equippedItem = InventorySystem:GetEquippedItem()
        if equippedItem then
            local itemId = equippedItem.itemId or InventorySystem:GetItemIdFromObject(equippedItem.object)
            print("Equipped item:", equippedItem.itemName)
            print("Item ID:", itemId)
            print("Is revive plush:", itemId == "revive_plush")
        else
            print("No item equipped")
        end
    else
        print("InventorySystem not found")
    end
    
    local promptCount = 0
    for _ in pairs(revivePrompts) do
        promptCount = promptCount + 1
    end
    print("Number of revive prompts:", promptCount)
    
    -- Check for dead players in workspace
    local deadPlayerCount = 0
    for _, descendant in pairs(workspace:GetDescendants()) do
        if descendant:IsA("Model") and CollectionService:HasTag(descendant, "Draggable") then
            local playerFromCharacter = Players:GetPlayerFromCharacter(descendant)
            if playerFromCharacter and CollectionService:HasTag(playerFromCharacter, "Dead") then
                deadPlayerCount = deadPlayerCount + 1
                print("Found dead player in workspace:", playerFromCharacter.Name)
            end
        end
    end
    print("Dead players in workspace:", deadPlayerCount)
end

-- TEMPORARY: Test function to spawn revive plush
function RevivePromptSystem:TestSpawnRevivePlush()
    print("RevivePromptSystem: Testing revive plush spawn...")
    
    local testSpawnRemote = ReplicatedStorage:FindFirstChild("TestSpawnRevivePlush")
    if testSpawnRemote then
        testSpawnRemote:FireServer()
        print("RevivePromptSystem: Sent test spawn request to server")
    else
        warn("RevivePromptSystem: TestSpawnRevivePlush remote not found")
    end
end

return RevivePromptSystem 