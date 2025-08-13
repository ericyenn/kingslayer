-- HitboxSystem.luau
-- Unified hitbox system for both client and server detection
-- Uses GetPartBoundsInBox for detection to cover the player as well

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local HitboxSystem = {}

-- Load configuration
local HitboxConfig = require(script.Parent.HitboxConfig)

-- Configuration
local HITBOX_CONFIG = {
    -- Detection settings
    useGetPartBoundsInBox = true, -- Use GetPartBoundsInBox for detection
    
    -- Performance settings
    maxHitboxesPerPlayer = 3,
    cleanupDelay = 0.1,
    
    -- Debug settings
    debugVisible = HitboxConfig.default.debugVisible,
    debugTransparency = 0.8,
    
    -- Default hitbox settings
    defaultSize = HitboxConfig.default.size,
    defaultDistance = HitboxConfig.default.distance,
    defaultSwingDuration = HitboxConfig.default.swingDuration,
    defaultCooldown = HitboxConfig.default.cooldown
}

-- Hitbox storage and management
local activeHitboxes = {}
local hitboxPool = {} -- For reusing hitbox parts

-- Unified damage detection logic (single source of truth)
local function canPartTakeDamage(part)
    if not part or not part.Parent then
        return false
    end
    
    -- Check if the part has the "Enemies" tag (for regular damage)
    local CollectionService = game:GetService("CollectionService")
    if CollectionService:HasTag(part, "Enemies") then
        return true
    end
    
    -- Check if the part's parent has the "Enemies" tag
    local parent = part.Parent
    if parent and CollectionService:HasTag(parent, "Enemies") then
        return true
    end
    
    -- Check if the part is part of a character model with "Enemies" tag
    -- Look for "Enemies" tag in the model hierarchy
    local model = part.Parent
    while model and model ~= workspace do
        if CollectionService:HasTag(model, "Enemies") then
            return true
        end
        model = model.Parent
    end
    
    -- Check if the part's parent has a Humanoid (NPCs, players)
    if parent and parent:FindFirstChild("Humanoid") then
        return true
    end
    
    -- Check if the part is part of a character model
    -- Look for Humanoid in the model hierarchy
    model = part.Parent
    while model and model ~= workspace do
        if model:FindFirstChild("Humanoid") then
            return true
        end
        model = model.Parent
    end
    
    return false
end

-- Create a detection part for hitbox
local function createDetectionPart(size, position, orientation)
    local part = Instance.new("Part")
    part.Name = "HitboxDetection"
    part.Size = size
    part.Shape = Enum.PartType.Block
    part.CanCollide = false
    part.Anchored = true
    part.Transparency = 1 -- Invisible by default
    
    -- Set position and orientation
    part.CFrame = CFrame.new(position) * orientation
    
    -- Debug visibility
    if HITBOX_CONFIG.debugVisible then
        part.Transparency = HITBOX_CONFIG.debugTransparency
        part.Material = Enum.Material.ForceField
        part.Color = Color3.fromRGB(255, 100, 100)
    end
    
    return part
end

-- Get hitbox from pool or create new one
local function getHitboxFromPool()
    if #hitboxPool > 0 then
        return table.remove(hitboxPool)
    else
        return createDetectionPart(Vector3.new(1, 1, 1), Vector3.new(0, 0, 0), CFrame.new())
    end
end

-- Return hitbox to pool
local function returnHitboxToPool(hitbox)
    if #hitboxPool < HITBOX_CONFIG.maxHitboxesPerPlayer then
        hitbox.Parent = nil
        table.insert(hitboxPool, hitbox)
    else
        hitbox:Destroy()
    end
end

-- Filter parts based on criteria (reused from GetPartsInPart logic)
local function filterParts(parts, filters)
    local filteredParts = {}
    
    for _, part in ipairs(parts) do
        local shouldInclude = true
        
        -- Character parts filter
        if filters.character and (part.Parent == filters.character or part:IsDescendantOf(filters.character)) then
            shouldInclude = false
        end
        
        -- Debug parts filter
        if part.Name:find("Debug") or part.Name:find("Hitbox") or part.Name:find("ShapeCast") then
            shouldInclude = false
        end
        
        -- Floor parts filter
        if filters.ignoreFloor then
            local isFloor = part.Name:lower():find("floor") or 
                           part.Name:lower():find("ground") or 
                           part.Name:lower():find("baseplate") or
                           part.Name:lower():find("spawn") or
                           (part.Size.X > 50 and part.Size.Z > 50 and part.Position.Y < (filters.centerPosition and filters.centerPosition.Y or 0) - 2)
            
            if isFloor then
                shouldInclude = false
            end
        end
        
        -- Tools and items filter
        if part.Name:find("Tool") or part.Name:find("Item") or (part.Parent and part.Parent.Name:find("Item")) then
            shouldInclude = false
        end
        
        -- Distance filter
        if filters.maxDistance and filters.centerPosition then
            if (part.Position - filters.centerPosition).Magnitude > filters.maxDistance then
                shouldInclude = false
            end
        end
        
        if shouldInclude then
            table.insert(filteredParts, part)
        end
    end
    
    return filteredParts
end

-- Get parts using GetPartBoundsInBox with improved filtering
local function getPartsInHitboxBounds(playerPosition, playerForward, hitboxLength, hitboxSize, filters)
    -- Create a bounding box that starts from the player and extends forward
    -- The box should cover the player's character and extend in front of them
    
    -- Calculate the center of the bounding box (halfway between player and forward extent)
    local boxCenter = playerPosition + (playerForward * (hitboxLength / 2))
    
    -- Calculate the size of the bounding box
    -- Width: hitboxSize.X (character width)
    -- Height: hitboxSize.Y (character height) 
    -- Depth: hitboxLength (extends from player position forward)
    local boxSize = Vector3.new(hitboxSize.X, hitboxSize.Y, hitboxLength)
    
    -- Create orientation based on player's facing direction
    local orientation = CFrame.Angles(0, math.atan2(playerForward.X, playerForward.Z), 0)
    
    -- Use GetPartBoundsInBox with the bounding box
    local boundsCFrame = CFrame.new(boxCenter) * orientation
    local intersectingParts = workspace:GetPartBoundsInBox(boundsCFrame, boxSize)
    return filterParts(intersectingParts, filters)
end

-- Main detection function using GetPartBoundsInBox with player-centered bounding box
function HitboxSystem.performDetection(character, playerPosition, playerForward, hitboxLength, hitboxSize, filters)
    filters = filters or {}
    filters.character = character
    filters.centerPosition = playerPosition
    
    -- Get intersecting parts using GetPartBoundsInBox with player-centered bounding box
    local intersectingParts = getPartsInHitboxBounds(playerPosition, playerForward, hitboxLength, hitboxSize, filters)
    
    -- Debug output
    print("HitboxSystem: Detection from player position", playerPosition, "with length", hitboxLength, "found", #intersectingParts, "parts")
    
    return intersectingParts
end

-- Find the best damage target from detected parts
function HitboxSystem.findBestDamageTarget(detectedParts)
    -- Prioritize parts that can take damage
    for _, part in ipairs(detectedParts) do
        if canPartTakeDamage(part) then
            return part
        end
    end
    
    -- If no damageable targets, return the first part (for other interactions)
    return detectedParts[1]
end

-- Create visual hitbox for debugging
function HitboxSystem.createDebugHitbox(center, size, color, duration, orientation)
    if not HITBOX_CONFIG.debugVisible then return end
    
    local debugPart = Instance.new("Part")
    debugPart.Name = "DebugHitbox"
    debugPart.Size = size
    debugPart.CFrame = CFrame.new(center) * (orientation or CFrame.new())
    debugPart.Material = Enum.Material.ForceField
    debugPart.Color = color or Color3.fromRGB(255, 100, 100)
    debugPart.Transparency = 0.3
    debugPart.CanCollide = false
    debugPart.Anchored = true
    debugPart.Parent = workspace
    
    -- Auto-cleanup
    task.delay(duration or 0.5, function()
        if debugPart and debugPart.Parent then
            debugPart:Destroy()
        end
    end)
    
    return debugPart
end

-- Cleanup function
function HitboxSystem.cleanup()
    for _, hitboxData in pairs(activeHitboxes) do
        if hitboxData.part then
            hitboxData.part:Destroy()
        end
    end
    activeHitboxes = {}
    
    for _, hitbox in ipairs(hitboxPool) do
        if hitbox then
            hitbox:Destroy()
        end
    end
    hitboxPool = {}
end

-- Update configuration
function HitboxSystem.updateConfig(newConfig)
    for key, value in pairs(newConfig) do
        HITBOX_CONFIG[key] = value
    end
end

-- Get current configuration
function HitboxSystem.getConfig()
    return HITBOX_CONFIG
end

-- Get item-specific hitbox settings from ItemDefinitions
function HitboxSystem.getItemSettings(itemName)
    local itemKey = string.lower(itemName)
    itemKey = string.gsub(itemKey, " ", "_")
    
    -- Get base settings from HitboxConfig
    local settings = HitboxConfig.default
    
    -- Override with ItemDefinitions if available
    local ItemDefinitions = require(game:GetService("ReplicatedStorage").Shared.ItemDefinitions)
    local itemDef = ItemDefinitions:GetItem(itemKey)
    
    if itemDef and itemDef.actionData then
        -- Use hitboxLength from ItemDefinitions if available
        if itemDef.actionData.hitboxLength then
            settings.distance = itemDef.actionData.hitboxLength
        end
        
        -- Override cooldown with ItemDefinition if available
        if itemDef.actionData.cooldown then
            settings.cooldown = itemDef.actionData.cooldown
        end
    end
    
    return settings
end

-- Get enemy-specific hitbox settings (melee enemies now use raycasts)
function HitboxSystem.getEnemySettings(enemyType)
    if enemyType == "melee" then
        warn("HitboxSystem: Melee enemies now use raycasts instead of hitboxes")
        return nil
    end
    return HitboxConfig.enemySettings[enemyType] or HitboxConfig.default
end

-- Export the unified damage detection function
HitboxSystem.canPartTakeDamage = canPartTakeDamage

return HitboxSystem 