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
local hasRevivePlushEquipped = false

-- Configuration
local PROMPT_DISTANCE = 8 -- Distance to show revive prompt
local PROMPT_HOLD_DURATION = 0 -- No hold required for revive

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
        
        -- Monitor for revive plush equipment changes
        self:SetupEquipmentMonitoring()
        
        print("RevivePromptSystem initialized successfully")
    end)
    
    if not success then
        warn("RevivePromptSystem initialization failed:", errorMessage)
    end
end

-- Set up monitoring for revive plush equipment
function RevivePromptSystem:SetupEquipmentMonitoring()
    -- Monitor for inventory updates with error handling
    local success, errorMessage = pcall(function()
        RemoteEvents.UpdateInventory.OnClientEvent:Connect(function()
            self:CheckRevivePlushEquipment()
        end)
    end)
    
    if not success then
        warn("Failed to connect to UpdateInventory RemoteEvent:", errorMessage)
    end
    
    -- Also monitor for slot selection changes (when player equips/unequips items)
    local SystemManager = require(ReplicatedStorage.Shared.SystemManager)
    local InventorySystem = SystemManager.GetSystem("InventorySystem")
    if InventorySystem then
        -- We'll check equipment status periodically since there's no direct event
        -- This is a simple solution - in a more robust system, we'd add events to InventorySystem
        task.spawn(function()
            while true do
                task.wait(0.5) -- Check every 0.5 seconds
                self:CheckRevivePlushEquipment()
            end
        end)
    end
    
    -- Initial check
    self:CheckRevivePlushEquipment()
end

-- Check if player has revive plush equipped
function RevivePromptSystem:CheckRevivePlushEquipment()
    local hadRevivePlush = hasRevivePlushEquipped
    
    -- Get the inventory system to check for revive plush
    local SystemManager = require(ReplicatedStorage.Shared.SystemManager)
    local InventorySystem = SystemManager.GetSystem("InventorySystem")
    
    if InventorySystem then
        -- Check if player has revive plush equipped
        local equippedItem = InventorySystem:GetEquippedItem()
        if equippedItem then
            -- Check if the equipped item is a revive plush
            local itemId = equippedItem.itemId or InventorySystem:GetItemIdFromObject(equippedItem.object)
            hasRevivePlushEquipped = (itemId == "revive_plush")
            
            print("RevivePromptSystem: Checking equipped item:", equippedItem.itemName, "itemId:", itemId, "isRevivePlush:", hasRevivePlushEquipped)
        else
            hasRevivePlushEquipped = false
            print("RevivePromptSystem: No item equipped")
        end
    else
        warn("RevivePromptSystem: Could not find InventorySystem")
        hasRevivePlushEquipped = false
    end
    
    -- Update prompts if equipment status changed
    if hadRevivePlush ~= hasRevivePlushEquipped then
        print("RevivePromptSystem: Equipment status changed to:", hasRevivePlushEquipped)
        self:UpdateAllPrompts()
    end
end

-- Update all revive prompts based on equipment status
function RevivePromptSystem:UpdateAllPrompts()
    if hasRevivePlushEquipped then
        -- Create prompts for all dead players
        self:CreatePromptsForDeadPlayers()
    else
        -- Remove all prompts
        self:RemoveAllPrompts()
    end
end

-- Create prompts for all dead players in workspace
function RevivePromptSystem:CreatePromptsForDeadPlayers()
    print("RevivePromptSystem: Creating prompts for dead players...")
    
    local foundDeadPlayers = 0
    -- Find all dead players in workspace
    for _, descendant in pairs(workspace:GetDescendants()) do
        if descendant:IsA("Model") and CollectionService:HasTag(descendant, "Draggable") then
            local playerFromCharacter = Players:GetPlayerFromCharacter(descendant)
            if playerFromCharacter and CollectionService:HasTag(playerFromCharacter, "Dead") then
                foundDeadPlayers = foundDeadPlayers + 1
                print("RevivePromptSystem: Creating prompt for dead player:", playerFromCharacter.Name)
                self:CreateRevivePrompt(playerFromCharacter, descendant)
            end
        end
    end
    print("RevivePromptSystem: Found", foundDeadPlayers, "dead players in workspace")
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

-- Create a revive prompt for a dead player
function RevivePromptSystem:CreateRevivePrompt(deadPlayer, ragdollCharacter)
    -- Don't create duplicate prompts
    if revivePrompts[ragdollCharacter] then
        return
    end
    
    -- Find the primary part of the ragdoll
    local primaryPart = ragdollCharacter.PrimaryPart
    if not primaryPart then
        warn("RevivePromptSystem: No primary part found for ragdoll:", deadPlayer.Name)
        return
    end
    
    -- Create the proximity prompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = "Dead Player"
    prompt.ActionText = "Revive"
    prompt.HoldDuration = PROMPT_HOLD_DURATION
    prompt.MaxActivationDistance = PROMPT_DISTANCE
    prompt.RequiresLineOfSight = false
    
    -- Connect the triggered event
    prompt.Triggered:Connect(function()
        self:HandleReviveTriggered(deadPlayer, ragdollCharacter)
    end)
    
    -- Parent the prompt to the ragdoll's primary part
    prompt.Parent = primaryPart
    
    -- Store the prompt
    revivePrompts[ragdollCharacter] = prompt
    
    print("RevivePromptSystem: Created revive prompt for:", deadPlayer.Name)
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
function RevivePromptSystem:HandleReviveTriggered(deadPlayer, ragdollCharacter)
    print("RevivePromptSystem: Revive triggered for:", deadPlayer.Name)
    
    -- Double-check that we have the revive plush equipped
    if not hasRevivePlushEquipped then
        print("RevivePromptSystem: Revive plush not equipped, ignoring trigger")
        return
    end
    
    -- Send revive request to server
    RemoteEvents.ReviveRequest:FireServer(deadPlayer)
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
    print("Current hasRevivePlushEquipped:", hasRevivePlushEquipped)
    
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