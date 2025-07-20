-- IdleState.lua
-- Simple data structure for idle state behavior

return {
    homePosition = Vector3.new(0, 0, 0),
    wanderRadius = 20,
    wanderCooldown = 5,
    lastWanderTime = 0,
    isWandering = false,
} 