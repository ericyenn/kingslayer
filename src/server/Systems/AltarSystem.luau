-- AltarSystem.luau
-- Main altar management system for healing altars

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local AltarConfig = require(ReplicatedStorage.Shared.AltarConfig)
local SacrificeData = require(ReplicatedStorage.Shared.SacrificeData)
local RewardConfig = require(ReplicatedStorage.Shared.RewardConfig)

local AltarSystem = {}

-- Track all altars and their sacrifice data
local altars = {} -- [altar] = SacrificeTracker

-- Track prayer figures
local prayerFigures = {} -- [figure] = altar

function AltarSystem:Initialize()
    print("Initializing AltarSystem...")
    
    -- Find existing altars
    self:ScanForAltars()
    
    -- Find existing prayer figures
    self:ScanForPrayerFigures()
    
    -- Listen for new altars
    CollectionService:GetInstanceAddedSignal("Altar"):Connect(function(altar)
        self:RegisterAltar(altar)
    end)
    
    -- Listen for altar removal
    CollectionService:GetInstanceRemovedSignal("Altar"):Connect(function(altar)
        self:UnregisterAltar(altar)
    end)
    
    -- Listen for new prayer figures
    CollectionService:GetInstanceAddedSignal("Prayer"):Connect(function(figure)
        self:RegisterPrayerFigure(figure)
    end)
    
    -- Listen for prayer figure removal
    CollectionService:GetInstanceRemovedSignal("Prayer"):Connect(function(figure)
        self:UnregisterPrayerFigure(figure)
    end)
    
    print("AltarSystem initialized")
end

-- Scan workspace for existing altars
function AltarSystem:ScanForAltars()
    local taggedAltars = CollectionService:GetTagged("Altar")
    for _, altar in ipairs(taggedAltars) do
        self:RegisterAltar(altar)
    end
    print("Found", #taggedAltars, "existing altars")
end

-- Scan workspace for existing prayer figures
function AltarSystem:ScanForPrayerFigures()
    local taggedFigures = CollectionService:GetTagged("Prayer")
    for _, figure in ipairs(taggedFigures) do
        self:RegisterPrayerFigure(figure)
    end
    print("Found", #taggedFigures, "existing prayer figures")
end

-- Register a new altar
function AltarSystem:RegisterAltar(altar)
    if altars[altar] then
        return -- Already registered
    end
    
    -- Create sacrifice tracker for this altar
    local tracker = SacrificeData.SacrificeTracker.new()
    tracker.altar = altar
    altars[altar] = tracker
    
    -- Set up contact detection
    self:SetupContactDetection(altar, tracker)
    
    print("Registered altar:", altar:GetFullName())
end

-- Unregister an altar
function AltarSystem:UnregisterAltar(altar)
    if altars[altar] then
        altars[altar] = nil
        print("Unregistered altar:", altar:GetFullName())
    end
end

-- Register a new prayer figure
function AltarSystem:RegisterPrayerFigure(figure)
    if prayerFigures[figure] then
        return -- Already registered
    end
    
    -- Get the position of the prayer figure (handle both parts and models)
    local figurePosition
    if figure:IsA("Model") then
        -- For models, use the primary part or first part
        local primaryPart = figure.PrimaryPart
        if primaryPart then
            figurePosition = primaryPart.Position
        else
            -- Find first part in the model
            for _, child in ipairs(figure:GetChildren()) do
                if child:IsA("BasePart") then
                    figurePosition = child.Position
                    break
                end
            end
        end
    else
        -- For parts, use the part position directly
        figurePosition = figure.Position
    end
    
    if not figurePosition then
        print("Could not determine position for prayer figure:", figure:GetFullName())
        return
    end
    
    -- Find the closest altar to associate with this prayer figure
    local closestAltar = self:FindClosestAltar(figurePosition)
    if closestAltar then
        prayerFigures[figure] = closestAltar
        local tracker = altars[closestAltar]
        if tracker then
            tracker:setPrayerFigure(figure)
        end
        print("Registered prayer figure:", figure:GetFullName(), "for altar:", closestAltar:GetFullName())
    else
        print("No altar found for prayer figure:", figure:GetFullName())
    end
end

-- Unregister a prayer figure
function AltarSystem:UnregisterPrayerFigure(figure)
    if prayerFigures[figure] then
        prayerFigures[figure] = nil
        print("Unregistered prayer figure:", figure:GetFullName())
    end
end

-- Find the closest altar to a position
function AltarSystem:FindClosestAltar(position)
    local closestAltar = nil
    local closestDistance = math.huge
    
    for altar, _ in pairs(altars) do
        local distance = (altar.Position - position).Magnitude
        if distance < closestDistance then
            closestDistance = distance
            closestAltar = altar
        end
    end
    
    return closestAltar
end

-- Set up contact detection for an altar
function AltarSystem:SetupContactDetection(altar, tracker)
    -- Listen for parts touching the altar
    altar.Touched:Connect(function(hitPart)
        self:OnPartTouchedAltar(hitPart, altar, tracker)
    end)
    
    -- Listen for parts leaving the altar
    altar.TouchEnded:Connect(function(hitPart)
        self:OnPartLeftAltar(hitPart, altar, tracker)
    end)
end

-- Handle when a part touches the altar
function AltarSystem:OnPartTouchedAltar(hitPart, altar, tracker)
    -- Check if the touching part is a sacrifice ragdoll
    if self:IsValidSacrifice(hitPart) then
        -- Get the actual sacrifice object (whole ragdoll, not individual parts)
        local sacrificeObject = self:GetSacrificeObject(hitPart)
        if sacrificeObject then
            -- Check if it's a player sacrifice
            if CollectionService:HasTag(sacrificeObject, "PlayerSacrifice") then
                local added = tracker:addPlayerSacrifice(sacrificeObject)
                if added then
                    print("Player sacrifice added to altar:", sacrificeObject.Name)
                    self:CheckAltarTrigger(altar, tracker)
                end
            else
                -- Regular enemy sacrifice
                local added = tracker:addSacrifice(sacrificeObject)
                if added then
                    print("Sacrifice added to altar:", sacrificeObject.Name)
                    self:CheckAltarTrigger(altar, tracker)
                end
            end
        end
    end
end

-- Handle when a part leaves the altar
function AltarSystem:OnPartLeftAltar(hitPart, altar, tracker)
    -- Check if the leaving part is a sacrifice ragdoll
    if self:IsValidSacrifice(hitPart) then
        -- Get the actual sacrifice object (whole ragdoll, not individual parts)
        local sacrificeObject = self:GetSacrificeObject(hitPart)
        if sacrificeObject then
            -- Check if it's a player sacrifice
            if CollectionService:HasTag(sacrificeObject, "PlayerSacrifice") then
                tracker:removePlayerSacrifice(sacrificeObject)
                print("Player sacrifice removed from altar:", sacrificeObject.Name)
            else
                -- Regular enemy sacrifice
                tracker:removeSacrifice(sacrificeObject)
                print("Sacrifice removed from altar:", sacrificeObject.Name)
            end
        end
    end
end

-- Check if a part is a valid sacrifice
function AltarSystem:IsValidSacrifice(part)
    -- Check if the part or its parent has the "Sacrifice" tag
    if CollectionService:HasTag(part, "Sacrifice") then
        return true
    end
    
    -- Check if parent is a sacrifice (for model parts)
    if part.Parent and CollectionService:HasTag(part.Parent, "Sacrifice") then
        return true
    end
    
    -- Check if the part or its parent has the "PlayerSacrifice" tag
    if CollectionService:HasTag(part, "PlayerSacrifice") then
        return true
    end
    
    -- Check if parent is a player sacrifice (for model parts)
    if part.Parent and CollectionService:HasTag(part.Parent, "PlayerSacrifice") then
        return true
    end
    
    return false
end

-- Get the actual sacrifice object (handles model parts)
function AltarSystem:GetSacrificeObject(part)
    -- If the part itself is tagged, return it
    if CollectionService:HasTag(part, "Sacrifice") then
        return part
    end
    
    -- If the parent is tagged, return the parent
    if part.Parent and CollectionService:HasTag(part.Parent, "Sacrifice") then
        return part.Parent
    end
    
    -- If the part itself is player sacrifice tagged, return it
    if CollectionService:HasTag(part, "PlayerSacrifice") then
        return part
    end
    
    -- If the parent is player sacrifice tagged, return the parent
    if part.Parent and CollectionService:HasTag(part.Parent, "PlayerSacrifice") then
        return part.Parent
    end
    
    return nil
end

-- Check if altar should trigger reward
function AltarSystem:CheckAltarTrigger(altar, tracker)
    -- Check if altar is on cooldown
    if tracker:isOnCooldown() then
        print("Altar on cooldown, skipping trigger")
        return
    end
    
    -- Check if we have enough sacrifices
    if tracker:hasEnoughSacrifices() then
        print("Altar has enough sacrifices, ready for prayer!")
        -- Don't trigger reward automatically - wait for prayer
    end
end

-- Trigger the reward for an altar
function AltarSystem:TriggerReward(altar, tracker)
    -- Get the reward processor
    local RewardProcessor = require(script.Parent.RewardProcessor)
    
    -- Get all sacrifices (both enemy and player)
    local sacrifices = tracker:getSacrifices()
    local playerSacrifices = tracker:getPlayerSacrifices()
    
    -- Combine all sacrifices for cleanup
    for _, sacrifice in ipairs(playerSacrifices) do
        table.insert(sacrifices, sacrifice)
    end
    
    -- Check if there are any player sacrifices
    local hasPlayerSacrifices = tracker:hasPlayerSacrifices()
    
    -- Spawn reward
    local success = RewardProcessor:SpawnReward(altar, sacrifices, hasPlayerSacrifices)
    
    if success then
        -- Set trigger time for cooldown
        tracker:setTriggerTime()
        
        -- Clear sacrifices
        tracker:clearSacrifices()
        
        print("Reward triggered successfully for altar:", altar:GetFullName())
    else
        print("Failed to spawn reward for altar:", altar:GetFullName())
    end
end

-- Get all registered altars
function AltarSystem:GetAltars()
    return altars
end

-- Get tracker for a specific altar
function AltarSystem:GetTracker(altar)
    return altars[altar]
end

-- Handle prayer to figure
function AltarSystem:HandlePrayer(player, figure)
    local altar = prayerFigures[figure]
    if not altar then
        print("No altar associated with prayer figure")
        return false, "No altar found"
    end
    
    local tracker = altars[altar]
    if not tracker then
        print("No tracker found for altar")
        return false, "Altar not found"
    end
    
    -- Check if altar has enough sacrifices
    if not tracker:hasEnoughSacrifices() then
        print("Not enough sacrifices for prayer")
        return false, "Not enough sacrifices"
    end
    
    -- Check if altar is on cooldown
    if tracker:isOnCooldown() then
        print("Altar on cooldown")
        return false, "Altar on cooldown"
    end
    
    -- Set prayer state and trigger reward
    tracker:setPrayed(true)
    print("Player", player.Name, "prayed to figure, triggering reward!")
    self:TriggerReward(altar, tracker)
    
    return true, "Prayer successful"
end

-- Get prayer figure for an altar
function AltarSystem:GetPrayerFigure(altar)
    for figure, associatedAltar in pairs(prayerFigures) do
        if associatedAltar == altar then
            return figure
        end
    end
    return nil
end

return AltarSystem 