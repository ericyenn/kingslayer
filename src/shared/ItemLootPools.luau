-- ItemLootPools.luau
-- Defines item pools, rarities, and guaranteed items for each region/pool

local ItemLootPools = {
    ForestLootPool = {
        items = { "cane", "cutlass", "chestplate", "summoner" },
        rarities = { 0.25, 0.15, 0.1, 0.2, 0.15, 0.1, 0.05 },
        guaranteed = { "summoner" },
        region = "forest"
    },
    DesertLootPool = {
        items = { "water_flask", "scimitar", "sand_shield", "dagger", "amulet", "main_quest_item_desert" },
        rarities = { 0.2, 0.2, 0.15, 0.2, 0.15, 0.1 },
        guaranteed = { "main_quest_item_desert" },
        region = "desert"
    },
    -- Add more pools as needed
}

return ItemLootPools 