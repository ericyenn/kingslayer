-- AltarUISystem.luau
-- Client-side visual feedback for altar system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local AltarConfig = require(ReplicatedStorage.Shared.AltarConfig)

local AltarUISystem = {}

-- Track altar highlights
local altarHighlights = {} -- [altar] = highlight

function AltarUISystem:Initialize()
    print("Initializing AltarUISystem...")
    
    -- Find existing altars
    self:SetupExistingAltars()
    
    -- Listen for new altars
    CollectionService:GetInstanceAddedSignal("Altar"):Connect(function(altar)
        self:SetupAltarUI(altar)
    end)
    
    -- Listen for altar removal
    CollectionService:GetInstanceRemovedSignal("Altar"):Connect(function(altar)
        self:CleanupAltarUI(altar)
    end)
    
    print("AltarUISystem initialized")
end

-- Setup UI for existing altars
function AltarUISystem:SetupExistingAltars()
    local taggedAltars = CollectionService:GetTagged("Altar")
    for _, altar in ipairs(taggedAltars) do
        self:SetupAltarUI(altar)
    end
    print("Setup UI for", #taggedAltars, "existing altars")
end

-- Setup UI for a single altar
function AltarUISystem:SetupAltarUI(altar)
    -- Create highlight for altar
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Red for altar
    highlight.FillTransparency = 0.3
    highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
    highlight.OutlineTransparency = 0
    highlight.Parent = altar
    highlight.Name = "AltarHighlight"
    
    altarHighlights[altar] = highlight
    
    print("Setup UI for altar:", altar:GetFullName())
end

-- Cleanup UI for a single altar
function AltarUISystem:CleanupAltarUI(altar)
    if altarHighlights[altar] then
        altarHighlights[altar]:Destroy()
        altarHighlights[altar] = nil
        print("Cleaned up UI for altar:", altar:GetFullName())
    end
end

-- Update altar highlight based on sacrifice count
function AltarUISystem:UpdateAltarHighlight(altar, sacrificeCount)
    local highlight = altarHighlights[altar]
    if not highlight then
        return
    end
    
    local required = AltarConfig.SETTINGS.requiredSacrifices
    local progress = sacrificeCount / required
    
    -- Change color based on progress
    if progress >= 1 then
        -- Ready to trigger
        highlight.FillColor = Color3.fromRGB(0, 255, 0) -- Green
        highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
    elseif progress >= 0.5 then
        -- Getting close
        highlight.FillColor = Color3.fromRGB(255, 255, 0) -- Yellow
        highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
    else
        -- Just started
        highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Red
        highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
    end
end

-- Show sacrifice progress notification
function AltarUISystem:ShowSacrificeProgress(altar, sacrificeCount)
    local required = AltarConfig.SETTINGS.requiredSacrifices
    local remaining = required - sacrificeCount
    
    if remaining > 0 then
        print("Altar needs", remaining, "more sacrifices")
    else
        print("Altar is ready! Triggering reward...")
    end
end

return AltarUISystem 