-- AnimationSet.lua
-- Data structure for entity animations

return {
    idle = nil,   -- AnimationTrack
    walk = nil,   -- AnimationTrack  
    attack = nil, -- AnimationTrack
    current = nil, -- Currently playing AnimationTrack
    animationSource = "state", -- "movement" or "state" - tracks what's controlling current animation
} 