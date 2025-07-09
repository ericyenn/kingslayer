-- Server-side item spawning system
local ItemSpawnSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local Constants = require(ReplicatedStorage.Shared.Constants)

function ItemSpawnSystem:Initialize()
    -- Only spawn test items if there are very few items in the world
    -- This prevents accumulation while maintaining functionality for new servers
    local existingItems = CollectionService:GetTagged(Constants.TAGS.DRAGGABLE_ITEM)
    local itemsInWorkspace = 0
    
    for _, item in ipairs(existingItems) do
        if item.Parent == workspace then
            itemsInWorkspace = itemsInWorkspace + 1
        end
    end
    
    -- Only spawn if less than 10 items exist in workspace (fresh or nearly empty world)
    if itemsInWorkspace < 10 then
        print("Spawning test items - found only", itemsInWorkspace, "items in workspace")
        
        -- Spawn test items with your current item set
        self:SpawnItem("stick", Vector3.new(0, 10, 0))
        self:SpawnItem("cutlass", Vector3.new(5, 10, 0))
        
        -- Spawn armor for testing
        self:SpawnItem("chestplate", Vector3.new(10, 10, 0))
        
        -- Spawn functional items for testing
        self:SpawnItem("healing_essence", Vector3.new(15, 10, 0))
        self:SpawnItem("summoner", Vector3.new(20, 10, 0))
        
        -- Spawn trading materials for testing
        self:SpawnItem("wood", Vector3.new(-5, 10, 0))
        self:SpawnItem("stone", Vector3.new(-10, 10, 0))
        
        print("Item spawn system initialized - spawned current item set")
    else
        print("Item spawn system initialized - skipped spawning test items (", itemsInWorkspace, "items already exist)")
    end
end

function ItemSpawnSystem:SpawnItem(itemId, position)
    local itemDefinition = ItemDefinitions:GetItem(itemId)
    if not itemDefinition then
        warn("Item definition not found:", itemId)
        return nil
    end
    
    local item = nil
    
    -- Try to load custom model first
    if itemDefinition.model then
        local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
        if modelsFolder then
            local modelTemplate = modelsFolder:FindFirstChild(itemDefinition.model)
            if modelTemplate then
                -- Clone the custom model
                item = modelTemplate:Clone()
                item.Name = itemDefinition.name
                print("Loaded custom model:", itemDefinition.model, "for", itemDefinition.name)
            else
                warn("Model not found in ReplicatedStorage/Models/:", itemDefinition.model)
            end
        else
            warn("Models folder not found in ReplicatedStorage")
        end
    end
    
    -- Fallback to basic part if no model found
    if not item then
        print("Using fallback basic part for:", itemDefinition.name)
        item = Instance.new("Part")
        item.Name = itemDefinition.name
        item.Size = Vector3.new(2, 1, 0.5) -- Default size
        item.BrickColor = BrickColor.Random() -- Random color for testing
        item.TopSurface = Enum.SurfaceType.Smooth
        item.BottomSurface = Enum.SurfaceType.Smooth
        item.Material = Enum.Material.Metal
    end
    
    -- Ensure item has a primary part for positioning
    local primaryPart = item
    if item:IsA("Model") then
        if not item.PrimaryPart then
            -- Find the largest part to use as primary part
            local largestPart = nil
            local largestVolume = 0
            for _, part in pairs(item:GetChildren()) do
                if part:IsA("BasePart") then
                    local volume = part.Size.X * part.Size.Y * part.Size.Z
                    if volume > largestVolume then
                        largestVolume = volume
                        largestPart = part
                    end
                end
            end
            if largestPart then
                item.PrimaryPart = largestPart
            end
        end
        primaryPart = item.PrimaryPart
    end
    
    -- Position the item
    if primaryPart then
        if item:IsA("Model") then
            item:SetPrimaryPartCFrame(CFrame.new(position))
        else
            primaryPart.Position = position
        end
        
        -- CRITICAL: Make sure the item can be moved by physics
        primaryPart.Anchored = false
    else
        warn("Could not position item - no primary part found:", itemDefinition.name)
    end
    
    item.Parent = workspace
    
    -- Tag the item for client-side component setup
    CollectionService:AddTag(item, Constants.TAGS.DRAGGABLE_ITEM)
    
    print("Spawned item:", itemDefinition.name, "at", position)
    return item
end

-- Spawn an item at a random position (for testing)
function ItemSpawnSystem:SpawnRandomItem()
    local itemIds = ItemDefinitions:GetAllItemIds()
    local randomItemId = itemIds[math.random(1, #itemIds)]
    local randomPosition = Vector3.new(
        math.random(-10, 10),
        math.random(5, 15),
        math.random(-10, 10)
    )
    
    return self:SpawnItem(randomItemId, randomPosition)
end

return ItemSpawnSystem 