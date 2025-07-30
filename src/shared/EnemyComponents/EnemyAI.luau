-- EnemyAI.lua
-- Simple data structure for enemy AI state data

return {
    state = "idle", -- Current AI state: idle, patrol, chase, attack, dead
    stateStartTime = 0, -- When current state started
    speed = 16, -- Movement speed
    homePosition = Vector3.new(0,0,0), -- Starting position for patrol (set by spawn system)
    patrolRadius = 30, -- Maximum distance from homePosition during patrol
}
