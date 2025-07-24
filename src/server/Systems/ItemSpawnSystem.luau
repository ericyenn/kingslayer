-- ItemSpawnSystem.luau
-- Spawns items at item spawners (guaranteed and random), no respawn/cooldown, proximity-based

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ItemLootPools = require(ReplicatedStorage.Shared.ItemLootPools)
local ItemSpawnerSetup = require(script.Parent.ItemSpawnerSetup)
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local Constants = require(ReplicatedStorage.Shared.Constants)

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
                item.Name = itemDefinition.name
                print("Loaded custom model:", itemDefinition.model, "for", itemDefinition.name)
            else
                warn("Model not found in ReplicatedStorage/Models/:", itemDefinition.model)
            end
        else
            warn("Models folder not found in ReplicatedStorage")
        end
    end
    if not item then
        print("Using fallback basic part for:", itemDefinition.name)
        item = Instance.new("Part")
        item.Name = itemDefinition.name
        item.Size = Vector3.new(2, 1, 0.5)
        item.BrickColor = BrickColor.Random()
        item.TopSurface = Enum.SurfaceType.Smooth
        item.BottomSurface = Enum.SurfaceType.Smooth
        item.Material = Enum.Material.Metal
    end
    local primaryPart = item
    if item:IsA("Model") then
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
            end
        end
        primaryPart = item.PrimaryPart
    end
    if primaryPart then
        if item:IsA("Model") then
            item:SetPrimaryPartCFrame(CFrame.new(position))
        else
            primaryPart.Position = position
        end
        primaryPart.Anchored = false
    else
        warn("Could not position item - no primary part found:", itemDefinition.name)
    end
    item.Parent = workspace
    CollectionService:AddTag(item, Constants.TAGS.DRAGGABLE_ITEM)
    print("Spawned item:", itemDefinition.name, "at", position)
    return item
end

return ItemPoolSpawnSystem 