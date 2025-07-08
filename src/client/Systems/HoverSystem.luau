-- Hover system for detecting mouse hover over items
local HoverSystem = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ECS = require(ReplicatedStorage.Shared.ECS)
-- Removed ItemNameDisplay - using rich tooltip from DragSystem instead

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local currentHoveredItem = nil
local heartbeatConnection = nil

function HoverSystem:Initialize()
    -- Connect to heartbeat for continuous hover detection
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        self:Update()
    end)
    
    print("Hover system initialized")
end

-- Cleanup method for proper connection management
function HoverSystem:Cleanup()
    -- Disconnect heartbeat connection
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end
    
    -- Clear any active hover state
    if currentHoveredItem then
        self:StopHover(currentHoveredItem)
        currentHoveredItem = nil
    end
end

function HoverSystem:Update()
    local target = mouse.Target
    
    -- Check if we're hovering over a new item
    if target and ECS:HasComponent(target, "Hoverable") then
        -- If it's a different item than what we're currently hovering
        if target ~= currentHoveredItem then
            -- Stop hovering the previous item
            if currentHoveredItem then
                self:StopHover(currentHoveredItem)
            end
            
            -- Start hovering the new item
            self:StartHover(target)
            currentHoveredItem = target
        end
        
        -- No position updates needed - DragSystem handles tooltips
    else
        -- Not hovering over any hoverable item
        if currentHoveredItem then
            self:StopHover(currentHoveredItem)
            currentHoveredItem = nil
        end
    end
end

function HoverSystem:StartHover(item)
    local hoverableComponent = ECS:GetComponent(item, "Hoverable")
    if hoverableComponent then
        -- Start the hover effect on the component
        hoverableComponent:StartHover(item)
        
        -- Name display handled by DragSystem's rich tooltip
        local itemName = hoverableComponent:GetDisplayName()
        print("Started hovering:", itemName)
    end
end

function HoverSystem:StopHover(item)
    local hoverableComponent = ECS:GetComponent(item, "Hoverable")
    if hoverableComponent then
        -- Stop the hover effect on the component
        hoverableComponent:StopHover(item)
        
        -- Name display handled by DragSystem's rich tooltip
        
        print("Stopped hovering:", hoverableComponent:GetDisplayName())
    end
end

return HoverSystem 