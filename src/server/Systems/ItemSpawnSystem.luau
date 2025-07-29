-- ItemSpawnSystem.luau
-- Spawns items at item spawners (guaranteed and random), no respawn/cooldown, proximity-based

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ItemLootPools = require(ReplicatedStorage.Shared.ItemLootPools)
local ItemSpawnerSetup = require(script.Parent.ItemSpawnerSetup)
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local Constants = require(ReplicatedStorage.Shared.Constants)
local PhysicsService = game:GetService("PhysicsService")

local ItemPoolSpawnSystem = {}

local ACTIVATION_RANGE = 60 -- Fixed activation range for all item spawners
local CHECK_INTERVAL = 2 -- Seconds between proximity checks

local spawnedSpawners = {} -- [spawnerConfig] = true

local function isAnyPlayerNearSpawner(spawner)
    local spawnerPos = spawner.part.Position
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local playerPos = player.Character.HumanoidRootPart.Position
            if (playerPos - spawnerPos).Magnitude <= ACTIVATION_RANGE then
                return true
            end
        end
    end
    return false
end

function ItemPoolSpawnSystem._spawnAtSpawner(spawner)
    local pool = ItemLootPools[spawner.lootPool]
    if not pool then return end
    local spawned = {}
    -- Spawn guaranteed items first
    for _, guaranteedItem in ipairs(spawner.assignedGuaranteed) do
        ItemPoolSpawnSystem._spawnItemAtSpawner(spawner, guaranteedItem)
        spawned[guaranteedItem] = true
    end
    -- Determine how many more items to spawn
    local numToSpawn = math.random(spawner.countMin, spawner.countMax)
    local itemsSpawned = #spawner.assignedGuaranteed
    while itemsSpawned < numToSpawn do
        local item = ItemPoolSpawnSystem._chooseRandomItem(pool, spawned)
        if not item then break end
        ItemPoolSpawnSystem._spawnItemAtSpawner(spawner, item)
        spawned[item] = true
        itemsSpawned = itemsSpawned + 1
    end
    spawnedSpawners[spawner] = true
end

function ItemPoolSpawnSystem.spawnAllItems()
    local spawnerConfigs, spawnersByRegion = ItemSpawnerSetup.scanForItemSpawners()
    -- Destroy all spawner parts immediately after setup
    for _, spawner in ipairs(spawnerConfigs) do
        if spawner.part and spawner.part.Parent then
            spawner.part:Destroy()
        end
    end
    ItemSpawnerSetup.assignGuaranteedItems(spawnersByRegion)
    spawnedSpawners = {}

    -- Periodically check for player proximity and spawn items
    local function checkSpawners()
        local allSpawned = true
        for _, spawner in ipairs(spawnerConfigs) do
            if not spawnedSpawners[spawner] then
                allSpawned = false
                if isAnyPlayerNearSpawner(spawner) then
                    ItemPoolSpawnSystem._spawnAtSpawner(spawner)
                end
            end
        end
        if not allSpawned then
            -- Continue checking until all spawners have spawned
            task.delay(CHECK_INTERVAL, checkSpawners)
        end
    end
    checkSpawners()
end

function ItemPoolSpawnSystem._chooseRandomItem(pool, exclude)
    exclude = exclude or {}
    -- Weighted random selection, skipping excluded items
    local totalWeight = 0
    for i, item in ipairs(pool.items) do
        if not exclude[item] then
            totalWeight = totalWeight + (pool.rarities[i] or 0)
        end
    end
    if totalWeight == 0 then return nil end
    local r = math.random() * totalWeight
    local acc = 0
    for i, item in ipairs(pool.items) do
        if not exclude[item] then
            acc = acc + (pool.rarities[i] or 0)
            if r <= acc then
                return item
            end
        end
    end
    return nil
end

function ItemPoolSpawnSystem._spawnItemAtSpawner(spawner, itemId)
    local basePos = spawner.part.Position
    local radius = spawner.spawnRadius or 5
    local angle = math.random() * 2 * math.pi
    local dist = math.random() * radius
    local pos = basePos + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
    -- Spawn the item using the utility logic
    ItemPoolSpawnSystem.SpawnItem(itemId, pos)
end

-- Utility function to spawn a single item (from the old system)
function ItemPoolSpawnSystem.SpawnItem(itemId, position)
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
                item = modelTemplate:Clone()
                print("Loaded custom model:", itemDefinition.model, "for", itemDefinition.name)
            else
                warn("Model not found in ReplicatedStorage/Models/:", itemDefinition.model)
            end
        else
            warn("Models folder not found in ReplicatedStorage")
        end
    end
    
    -- Create fallback part if no model found
    if not item then
        print("Using fallback basic part for:", itemDefinition.name)
        item = Instance.new("Part")
        item.Size = Vector3.new(2, 1, 0.5)
        item.BrickColor = BrickColor.Random()
        item.TopSurface = Enum.SurfaceType.Smooth
        item.BottomSurface = Enum.SurfaceType.Smooth
        item.Material = Enum.Material.Metal
    end
    
    -- ALWAYS set the correct name from item definition
    item.Name = itemDefinition.name
    print("Spawned item with name:", item.Name, "for itemId:", itemId)
    local primaryPart = item
    if item:IsA("Model") then
        -- Ensure model has a primary part
        if not item.PrimaryPart then
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
                print("Set PrimaryPart for model:", itemDefinition.name, "to:", largestPart.Name)
            else
                warn("No suitable part found for PrimaryPart in model:", itemDefinition.name)
            end
        end
        primaryPart = item.PrimaryPart
        
        -- Position the model using its primary part
        if primaryPart then
            item:SetPrimaryPartCFrame(CFrame.new(position))
            -- Assign all parts to 'Items' collision group
            for _, part in ipairs(item:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CollisionGroup = "Items"
                    part.Anchored = false
                end
            end
        else
            warn("Could not position model - no primary part found:", itemDefinition.name)
        end
    else
        -- Handle single part items
        if primaryPart then
            primaryPart.Position = position
            primaryPart.CollisionGroup = "Items"
            primaryPart.Anchored = false
        else
            warn("Could not position item - no primary part found:", itemDefinition.name)
        end
    end
    item.Parent = workspace
    CollectionService:AddTag(item, Constants.TAGS.DRAGGABLE_ITEM)
    
    -- Add ECS components to the item (server-side setup)
    ItemPoolSpawnSystem:AddECSComponentsToItem(item, itemDefinition)
    
    print("Spawned item:", itemDefinition.name, "at", position)
    return item
end

-- Add ECS components to spawned items
function ItemPoolSpawnSystem:AddECSComponentsToItem(item, itemDefinition)
    local ECS = require(ReplicatedStorage.Shared.ECS)
    local Draggable = require(ReplicatedStorage.Shared.Components.Draggable)
    local Hoverable = require(ReplicatedStorage.Shared.Components.Hoverable)
    local Inventoryable = require(ReplicatedStorage.Shared.Components.Inventoryable)
    
    -- Add components based on item definition
    if itemDefinition.components then
        for componentName, config in pairs(itemDefinition.components) do
            local component = nil
            
            if componentName == "Draggable" then
                component = Draggable.new(config)
            elseif componentName == "Hoverable" then
                component = Hoverable.new(config)
            elseif componentName == "Inventoryable" then
                component = Inventoryable.new(config)
            end
            
            if component then
                ECS:AddComponent(item, componentName, component)
                print("Added", componentName, "component to", item.Name)
            else
                warn("Failed to create component:", componentName, "for", item.Name)
            end
        end
    else
        -- Add default components if none specified
        local defaultComponents = {
            Draggable = Draggable.new({ force = 8000, maxDistance = 35, dampening = 0.6 }),
            Hoverable = Hoverable.new({ displayName = item.Name, description = "A mysterious item." }),
            Inventoryable = Inventoryable.new({ canPickup = true, stackable = false, maxStack = 1 })
        }
        
        for componentName, component in pairs(defaultComponents) do
            ECS:AddComponent(item, componentName, component)
            print("Added default", componentName, "component to", item.Name)
        end
    end
end

return ItemPoolSpawnSystem 