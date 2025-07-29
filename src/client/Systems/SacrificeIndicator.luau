-- SacrificeIndicator.luau
-- Shows which ragdolls are valid sacrifices

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local SacrificeIndicator = {}

-- Track sacrifice highlights
local sacrificeHighlights = {} -- [ragdoll] = highlight

function SacrificeIndicator:Initialize()
    print("Initializing SacrificeIndicator...")
    
    -- Find existing sacrifices
    self:SetupExistingSacrifices()
    
    -- Listen for new sacrifices
    CollectionService:GetInstanceAddedSignal("Sacrifice"):Connect(function(ragdoll)
        self:SetupSacrificeIndicator(ragdoll)
    end)
    
    -- Listen for sacrifice removal
    CollectionService:GetInstanceRemovedSignal("Sacrifice"):Connect(function(ragdoll)
        self:CleanupSacrificeIndicator(ragdoll)
    end)
    
    print("SacrificeIndicator initialized")
end

-- Setup indicators for existing sacrifices
function SacrificeIndicator:SetupExistingSacrifices()
    local taggedSacrifices = CollectionService:GetTagged("Sacrifice")
    for _, sacrifice in ipairs(taggedSacrifices) do
        self:SetupSacrificeIndicator(sacrifice)
    end
    print("Setup indicators for", #taggedSacrifices, "existing sacrifices")
end

-- Setup indicator for a single sacrifice
function SacrificeIndicator:SetupSacrificeIndicator(ragdoll)
    -- No visual changes - just track for debugging
    sacrificeHighlights[ragdoll] = true -- Just mark as tracked
    
    print("Setup indicator for sacrifice:", ragdoll.Name)
end

-- Cleanup indicator for a single sacrifice
function SacrificeIndicator:CleanupSacrificeIndicator(ragdoll)
    if sacrificeHighlights[ragdoll] then
        sacrificeHighlights[ragdoll] = nil
        print("Cleaned up indicator for sacrifice:", ragdoll.Name)
    end
end

-- Update sacrifice highlight when it's being dragged
function SacrificeIndicator:UpdateSacrificeHighlight(ragdoll, isBeingDragged)
    -- No visual changes - just track for debugging
    if sacrificeHighlights[ragdoll] then
        if isBeingDragged then
            print("Sacrifice being dragged:", ragdoll.Name)
        end
    end
end

return SacrificeIndicator 