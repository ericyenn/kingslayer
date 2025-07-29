-- PrayerSystem.luau
-- Client-side prayer system for interacting with prayer figures using ProximityPrompt

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local AltarConfig = require(ReplicatedStorage.Shared.AltarConfig)

local PrayerSystem = {}

local player = Players.LocalPlayer

-- Track prayer figures and their prompts
local prayerFigures = {} -- [figure] = prompt

function PrayerSystem:Initialize()
    print("Initializing PrayerSystem...")
    
    -- Find existing prayer figures
    self:SetupExistingPrayerFigures()
    
    -- Listen for new prayer figures
    CollectionService:GetInstanceAddedSignal("Prayer"):Connect(function(figure)
        self:SetupPrayerFigure(figure)
    end)
    
    -- Listen for prayer figure removal
    CollectionService:GetInstanceRemovedSignal("Prayer"):Connect(function(figure)
        self:CleanupPrayerFigure(figure)
    end)
    
    print("PrayerSystem initialized")
end

-- Setup existing prayer figures
function PrayerSystem:SetupExistingPrayerFigures()
    local taggedFigures = CollectionService:GetTagged("Prayer")
    for _, figure in ipairs(taggedFigures) do
        self:SetupPrayerFigure(figure)
    end
    print("Setup", #taggedFigures, "existing prayer figures")
end

-- Setup a single prayer figure
function PrayerSystem:SetupPrayerFigure(figure)
    -- Create ProximityPrompt for the prayer figure
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = "Prayer Figure"
    prompt.ActionText = "Pray"
    prompt.HoldDuration = AltarConfig.PRAYER_CONFIG.prayerDuration
    prompt.MaxActivationDistance = AltarConfig.PRAYER_CONFIG.interactionDistance
    prompt.RequiresLineOfSight = false
    prompt.Triggered:Connect(function(playerWhoTriggered)
        if playerWhoTriggered == player then
            self:HandlePrayerTriggered(figure)
        end
    end)
    
    -- Attach prompt to the figure
    if figure:IsA("Model") then
        -- For models, attach to primary part or first part
        local primaryPart = figure.PrimaryPart
        if primaryPart then
            prompt.Parent = primaryPart
        else
            -- Find first part in the model
            for _, child in ipairs(figure:GetChildren()) do
                if child:IsA("BasePart") then
                    prompt.Parent = child
                    break
                end
            end
        end
    else
        -- For parts, attach directly
        prompt.Parent = figure
    end
    
    prayerFigures[figure] = prompt
    print("Setup prayer figure with ProximityPrompt:", figure:GetFullName())
end

-- Cleanup a single prayer figure
function PrayerSystem:CleanupPrayerFigure(figure)
    if prayerFigures[figure] then
        prayerFigures[figure]:Destroy()
        prayerFigures[figure] = nil
        print("Cleaned up prayer figure:", figure:GetFullName())
    end
end

-- Handle when prayer is triggered via ProximityPrompt
function PrayerSystem:HandlePrayerTriggered(figure)
    print("Prayer triggered for:", figure.Name)
    
    -- Send prayer request to server
    local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
    if RemoteEvents.PrayerRequest then
        RemoteEvents.PrayerRequest:FireServer(figure)
    end
end

return PrayerSystem 