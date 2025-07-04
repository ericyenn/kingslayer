-- This script runs on the client and is attached to each tool when equipped.
-- It handles the "use" action (left-click) and dispatches to the correct system based on category.

local Tool = script.Parent
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

print("DEBUG: ToolHandler script starting for tool:", Tool.Name)

-- Shared Modules
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local Categories = require(ReplicatedStorage.Shared.ItemCategory)

-- Client Systems - Access through StarterPlayerScripts
local player = Players.LocalPlayer
local ClientSystems = player.PlayerScripts.Client.Systems
local ToolSystem = require(ClientSystems.ToolSystem)
local ArmorSystem = require(ClientSystems.ArmorSystem)
local FunctionalSystem = require(ClientSystems.FunctionalSystem)

local camera = workspace.CurrentCamera

-- Debounce to prevent spamming the use action
local debounce = false
local DEBOUNCE_TIME = 0.5 -- 500ms

-- Shape cast configuration - easy to adjust
local SHAPE_CAST_CONFIG = {
    radius = Vector3.new(8, 8, 8), -- Size of the detection area
    distance = 3, -- Distance in front of player
    ignoreFloor = true, -- Whether to ignore floor/ground
    visualDuration = 0.1, -- How long visual feedback lasts
}

print("DEBUG: ToolHandler modules loaded, setting up functions...")

local function createVisualShapeCast(centerPosition, radius, color, hasHit)
    -- Create the main detection area visualization
    local shapePart = Instance.new("Part")
    shapePart.Name = "DebugShapeCast"
    shapePart.Anchored = true
    shapePart.CanCollide = false
    shapePart.Shape = Enum.PartType.Block
    shapePart.Material = Enum.Material.ForceField
    shapePart.BrickColor = BrickColor.new(color)
    shapePart.Transparency = 0.7
    shapePart.Size = radius
    shapePart.CFrame = CFrame.new(centerPosition)
    shapePart.Parent = workspace
    
    -- Create center indicator (smaller cube in the middle)
    local centerPart = Instance.new("Part")
    centerPart.Name = "DebugShapeCastCenter"
    centerPart.Anchored = true
    centerPart.CanCollide = false
    centerPart.Shape = Enum.PartType.Block
    centerPart.Material = Enum.Material.Neon
    centerPart.BrickColor = BrickColor.new(hasHit and "Bright green" or "Bright red")
    centerPart.Transparency = 0.3
    centerPart.Size = Vector3.new(1, 1, 1) -- Small center square
    centerPart.CFrame = CFrame.new(centerPosition)
    centerPart.Parent = workspace
    
    -- Remove after configured duration
    Debris:AddItem(shapePart, SHAPE_CAST_CONFIG.visualDuration)
    Debris:AddItem(centerPart, SHAPE_CAST_CONFIG.visualDuration)
    
    return shapePart, centerPart
end

local function performShapeCast(character, centerPosition, radius)
    -- Use GetPartBoundsInBox for shape casting detection
    local partBounds = workspace:GetPartBoundsInBox(CFrame.new(centerPosition), radius)
    local detectedParts = {}
    
    -- Filter out unwanted parts
    for _, part in ipairs(partBounds) do
        -- Skip character parts
        if part.Parent ~= character and not part:IsDescendantOf(character) then
            -- Skip debug visualization parts (our own hitboxes)
            local isDebugPart = part.Name:find("DebugShapeCast") or 
                               part.Name:find("DebugHitbox") or 
                               part.Name:find("DebugRay")
            
            if not isDebugPart then
                -- Skip floor/ground if configured
                if SHAPE_CAST_CONFIG.ignoreFloor then
                    -- Check if part is likely floor (low Y position, large size, or named like ground)
                    local isFloor = part.Name:lower():find("floor") or 
                                   part.Name:lower():find("ground") or 
                                   part.Name:lower():find("baseplate") or
                                   part.Name:lower():find("spawn") or
                                   (part.Size.X > 50 and part.Size.Z > 50 and part.Position.Y < centerPosition.Y - 2)
                    
                    if not isFloor then
                        table.insert(detectedParts, part)
                    end
                else
                    table.insert(detectedParts, part)
                end
            end
        end
    end
    
    return detectedParts
end

local function onUse()
    if debounce then return end
    debounce = true
    
    print("DEBUG: ToolHandler onUse called for tool:", Tool.Name)
    
    local character = player.Character
    if not character then 
        print("DEBUG: No character found")
        debounce = false
        return 
    end
    
    local human = character:FindFirstChild("Humanoid")
    if not human or human.Health <= 0 then 
        print("DEBUG: No humanoid or dead")
        debounce = false
        return 
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then 
        print("DEBUG: No HumanoidRootPart")
        debounce = false
        return 
    end

    -- Perform shape cast in front of camera
    local cameraPosition = camera.CFrame.Position
    local cameraDirection = camera.CFrame.LookVector
    
    -- Calculate shape cast center position (3 studs in front of camera)
    local shapeCastCenter = cameraPosition + cameraDirection * SHAPE_CAST_CONFIG.distance
    
    -- Perform the shape cast
    local detectedParts = performShapeCast(character, shapeCastCenter, SHAPE_CAST_CONFIG.radius)
    
    local target = nil
    local hasHit = #detectedParts > 0
    
    if hasHit then
        -- Use the first detected part as target
        target = detectedParts[1]
        print("DEBUG: Shape cast hit:", target.Name, "at", target.Position)
        print("DEBUG: Total parts detected:", #detectedParts)
        
        -- Create visual shape cast (green for hit)
        createVisualShapeCast(shapeCastCenter, SHAPE_CAST_CONFIG.radius, "Bright green", true)
        
        -- List all detected parts for debugging
        for i, part in ipairs(detectedParts) do
            print("  - Part", i .. ":", part.Name, "at", part.Position)
        end
    else
        print("DEBUG: Shape cast missed - no parts detected")
        
        -- Create visual shape cast (red for miss)
        createVisualShapeCast(shapeCastCenter, SHAPE_CAST_CONFIG.radius, "Bright red", false)
    end

    -- Convert tool name to lowercase to match ItemDefinitions keys
    local itemKey = string.lower(Tool.Name)
    local itemDef = ItemDefinitions:GetItem(itemKey)

    if not itemDef then
        warn("ToolHandler: No item definition found for equipped tool:", Tool.Name, "(key:", itemKey .. ")")
        debounce = false
        return
    end

    print("DEBUG: Found item definition:", itemDef.name, "Category:", itemDef.category)

    -- Centralized dispatch based on category
    if itemDef.category == Categories.Tool then
        ToolSystem:Use(itemDef, player, target)
    elseif itemDef.category == Categories.Armor then
        ArmorSystem:Use(itemDef, player, target)
    elseif itemDef.category == Categories.Functional then
        FunctionalSystem:Use(itemDef, player, target)
    else
        warn("ToolHandler: Unknown category for item:", itemDef.name, itemDef.category)
    end
    
    -- Reset debounce after delay
    wait(DEBOUNCE_TIME)
    debounce = false
end

Tool.Activated:Connect(onUse)
print("DEBUG: ToolHandler script fully initialized for tool:", Tool.Name) 