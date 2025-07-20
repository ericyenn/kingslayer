-- Spawner.lua
-- Simple data structure for spawning configuration

return {
    Enemies         = {},
    CountRange      = { min = 1, max = 1 },
    Radius          = 50,
    Cooldown        = 30,
    LastSpawnTime   = 0,
    SpawnedEntities = {},
}
