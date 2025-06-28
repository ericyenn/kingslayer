-- Server-side item spawning system
local ItemSpawnSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local Constants = require(ReplicatedStorage.Shared.Constants)

function ItemSpawnSystem:Initialize()
    -- Spawn existing test items (tools)
    self:SpawnItem("hammer", Vector3.new(0, 10, 0))
    self:SpawnItem("wrench", Vector3.new(5, 10, 0))
    self:SpawnItem("screwdriver", Vector3.new(-5, 10, 0))
    
    -- Spawn new armor items for testing
    self:SpawnItem("helmet", Vector3.new(10, 10, 0))
    self:SpawnItem("chestplate", Vector3.new(15, 10, 0))
    self:SpawnItem("boots", Vector3.new(20, 10, 0))
    
    print("Item spawn system initialized - spawned test items and armor")
end

function ItemSpawnSystem:SpawnItem(itemId, position)
    local itemDefinition = ItemDefinitions:GetItem(itemId)
    if not itemDefinition then
        warn("Item definition not found:", itemId)
        return nil
    end
    
    -- Create the physical item (for now, just a simple part)
    -- In a real game, you'd load the actual model
    local item = Instance.new("Part")
    item.Name = itemDefinition.name
    item.Size = Vector3.new(2, 1, 0.5) -- Default size
    item.Position = position
    item.BrickColor = BrickColor.Random() -- Random color for testing
    item.TopSurface = Enum.SurfaceType.Smooth
    item.BottomSurface = Enum.SurfaceType.Smooth
    
    -- CRITICAL: Make sure the part is unanchored so it can be moved by physics
    item.Anchored = false
    
    -- Add some mass so it feels substantial
    item.Material = Enum.Material.Metal
    
    item.Parent = workspace
    
    -- Tag the item for client-side component setup
    CollectionService:AddTag(item, Constants.TAGS.DRAGGABLE_ITEM)
    
    print("Spawned unanchored item:", itemDefinition.name, "at", position)
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