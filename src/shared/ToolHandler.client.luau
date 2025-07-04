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

-- Shape cast settings - adjustable
local SHAPE_CAST_SIZE = Vector3.new(8, 8, 8) -- Large square region (player-sized)
local SHAPE_CAST_DISTANCE = 50 -- Maximum cast distance
local VISUAL_DURATION = 0.5 -- How long visual feedback stays

print("DEBUG: ToolHandler modules loaded, setting up functions...")

local function createVisualShapeCast(origin, direction, distance, size, color)
    -- Create a visual representation of the shape cast region
    local castPart = Instance.new("Part")
    castPart.Name = "DebugShapeCast"
    castPart.Anchored = true
    castPart.CanCollide = false
    castPart.Shape = Enum.PartType.Block
    castPart.Material = Enum.Material.ForceField
    castPart.BrickColor = BrickColor.new(color)
    castPart.Transparency = 0.6
    castPart.Size = size
    
    -- Position the cast region immediately in front of the player (closer to camera)
    local frontPosition = origin + direction * 3 -- Only 3 studs in front
    castPart.CFrame = CFrame.lookAt(frontPosition, frontPosition + direction)
    
    castPart.Parent = workspace
    
    -- Remove after specified duration
    Debris:AddItem(castPart, VISUAL_DURATION)
    
    return castPart
end

local function createVisualHitbox(position, size, color)
    -- Create a visual hitbox indicator
    local hitboxPart = Instance.new("Part")
    hitboxPart.Name = "DebugHitbox"
    hitboxPart.Anchored = true
    hitboxPart.CanCollide = false
    hitboxPart.Shape = Enum.PartType.Block
    hitboxPart.Material = Enum.Material.Neon
    hitboxPart.BrickColor = BrickColor.new(color)
    hitboxPart.Transparency = 0.5
    hitboxPart.Size = size or Vector3.new(2, 2, 2)
    hitboxPart.CFrame = CFrame.new(position)
    
    hitboxPart.Parent = workspace
    
    -- Remove after specified duration
    Debris:AddItem(hitboxPart, VISUAL_DURATION)
    
    return hitboxPart
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

    -- Perform shape cast from camera
    local castOrigin = camera.CFrame.Position
    local castDirection = camera.CFrame.LookVector
    
    print("DEBUG: Shape cast origin:", castOrigin)
    print("DEBUG: Shape cast direction:", castDirection)
    print("DEBUG: Shape cast distance:", SHAPE_CAST_DISTANCE)
    
    -- Create a part to define the shape for casting
    local castPart = Instance.new("Part")
    castPart.Size = SHAPE_CAST_SIZE
    castPart.CFrame = CFrame.new(castOrigin)
    
    -- Set up shape cast parameters
    local shapecastParams = RaycastParams.new()
    shapecastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    -- Build filter list: character, tool, and common floor/ground parts
    local filterList = {character, Tool}
    
    -- Add common floor/ground parts to filter
    local commonFloorNames = {"Baseplate", "Floor", "Ground", "Terrain", "SpawnLocation"}
    for _, floorName in pairs(commonFloorNames) do
        local floorPart = workspace:FindFirstChild(floorName)
        if floorPart then
            table.insert(filterList, floorPart)
        end
    end
    
    -- Also filter out any parts named with floor-related terms
    for _, obj in pairs(workspace:GetChildren()) do
        if obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if name:find("floor") or name:find("ground") or name:find("base") or name:find("spawn") then
                table.insert(filterList, obj)
            end
        end
    end
    
    shapecastParams.FilterDescendantsInstances = filterList
    
    print("DEBUG: Filtered instances:", #shapecastParams.FilterDescendantsInstances)
    
    -- Perform the shape cast using the part
    local shapecastResult = workspace:Shapecast(castPart, castDirection * SHAPE_CAST_DISTANCE, shapecastParams)
    
    -- Clean up the temporary part
    castPart:Destroy()
    
    print("DEBUG: Shape cast result:", shapecastResult and "HIT" or "MISS")
    if shapecastResult then
        print("DEBUG: Hit distance:", shapecastResult.Distance)
        print("DEBUG: Hit position:", shapecastResult.Position)
    end
    
    local target = nil
    local hitPosition = castOrigin + castDirection * SHAPE_CAST_DISTANCE
    
    if shapecastResult then
        target = shapecastResult.Instance
        hitPosition = shapecastResult.Position
        print("DEBUG: Shape cast hit:", target.Name, "at", hitPosition)
        
        -- Create visual shape cast region (green for hit)
        createVisualShapeCast(castOrigin, castDirection, shapecastResult.Distance, SHAPE_CAST_SIZE, "Bright green")
        
        -- Create visual hitbox in front of player (not at actual hit location)
        local frontHitPosition = castOrigin + castDirection * 3
        createVisualHitbox(frontHitPosition, Vector3.new(3, 3, 3), "Bright green")
    else
        print("DEBUG: Shape cast missed")
        
        -- Create visual shape cast region (red for miss)
        createVisualShapeCast(castOrigin, castDirection, SHAPE_CAST_DISTANCE, SHAPE_CAST_SIZE, "Bright red")
        
        -- Create visual hitbox in front of player (not at full cast distance)
        local frontMissPosition = castOrigin + castDirection * 3
        createVisualHitbox(frontMissPosition, Vector3.new(2, 2, 2), "Bright red")
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