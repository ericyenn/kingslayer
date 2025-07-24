-- ItemSpawnerSetup.luau
-- Scans for tagged ItemSpawner parts, reads attributes, and groups spawners by pool region

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemLootPools = require(ReplicatedStorage.Shared.ItemLootPools)

local ItemSpawnerSetup = {}

-- Scan workspace for all tagged item spawner parts
function ItemSpawnerSetup.scanForItemSpawners()
    local taggedParts = CollectionService:GetTagged("ItemSpawner")
    local spawnersByRegion = {}
    local spawnerConfigs = {}

    for _, part in ipairs(taggedParts) do
        local lootPool = part:GetAttribute("LootPool")
        local countMin = part:GetAttribute("CountMin") or 1
        local countMax = part:GetAttribute("CountMax") or 1
        local spawnRadius = part:GetAttribute("SpawnRadius") or 5
        local pool = ItemLootPools[lootPool]
        local region = pool and pool.region or "default"

        local config = {
            part = part,
            lootPool = lootPool,
            countMin = countMin,
            countMax = countMax,
            spawnRadius = spawnRadius,
            assignedGuaranteed = {},
        }
        table.insert(spawnerConfigs, config)
        spawnersByRegion[region] = spawnersByRegion[region] or {}
        table.insert(spawnersByRegion[region], config)
    end

    return spawnerConfigs, spawnersByRegion
end

-- Assign guaranteed items to random spawners in each region
function ItemSpawnerSetup.assignGuaranteedItems(spawnersByRegion)
    for region, spawnerList in pairs(spawnersByRegion) do
        -- Find all pools for this region
        local pools = {}
        for poolName, pool in pairs(ItemLootPools) do
            if pool.region == region then
                table.insert(pools, pool)
            end
        end
        -- For each pool, assign each guaranteed item to a random spawner in this region
        for _, pool in ipairs(pools) do
            for _, guaranteedItem in ipairs(pool.guaranteed or {}) do
                if #spawnerList > 0 then
                    local idx = math.random(1, #spawnerList)
                    table.insert(spawnerList[idx].assignedGuaranteed, guaranteedItem)
                end
            end
        end
    end
end

return ItemSpawnerSetup 