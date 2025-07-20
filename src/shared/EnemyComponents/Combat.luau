-- Combat.lua
-- Simple data structure for entity combat state

return {
    target = nil, -- Entity being attacked
    damage = 10, -- Damage per attack
    lastAttackTime = 0, -- When last attack occurred
    
    -- Attack state for moving shapecast
    isAttacking = false, -- Whether currently performing an attack
    attackStartTime = 0, -- When current attack started
    attackTargetPlayer = nil, -- Player being attacked during current attack
}
