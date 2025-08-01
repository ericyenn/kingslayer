-- Breakable component for objects that can be broken with tools
local Breakable = {}
Breakable.__index = Breakable

-- Create a new Breakable component
function Breakable.new(config)
    local self = setmetatable({
        -- Core properties
        health = config.health or 100,
        maxHealth = config.maxHealth or 100,
        breakableType = config.breakableType or "tree", -- "tree", "rock", "crystal"
        requiredTool = config.requiredTool or "axe", -- "axe", "pickaxe", "crystal_tool"
        
        -- Drop configuration
        dropItems = config.dropItems or {},
        respawnTime = config.respawnTime or 300, -- 5 minutes default
        
        -- State
        isBroken = false,
        lastDamageTime = 0,
        respawnTimer = 0,
        
        -- Visual/Audio
        breakAnimation = config.breakAnimation or "break",
        soundEffect = config.soundEffect or "break",
        
        -- Internal
        originalCFrame = nil,
        originalParent = nil
    }, Breakable)
    
    return self
end

-- Apply damage to the breakable object
function Breakable:TakeDamage(damage)
    if self.isBroken then
        return false, "Object is already broken"
    end
    
    -- Apply damage (client already validated tool type)
    self.health = math.max(0, self.health - damage)
    self.lastDamageTime = tick()
    
    print("Breakable took", damage, "damage. Health:", self.health, "/", self.maxHealth)
    
    -- Check if broken
    if self.health <= 0 then
        self.isBroken = true
        return true, "broken"
    end
    
    return true, "damaged"
end

-- Get health percentage
function Breakable:GetHealthPercentage()
    return self.health / self.maxHealth
end

-- Check if object is broken
function Breakable:IsBroken()
    return self.isBroken
end

-- Get required tool type
function Breakable:GetRequiredTool()
    return self.requiredTool
end

-- Get breakable type
function Breakable:GetBreakableType()
    return self.breakableType
end

-- Get drop items
function Breakable:GetDropItems()
    return self.dropItems
end

-- Start respawn timer
function Breakable:StartRespawn()
    self.respawnTimer = tick() + self.respawnTime
end

-- Check if respawn timer is complete
function Breakable:ShouldRespawn()
    return self.isBroken and tick() >= self.respawnTimer
end

-- Reset to full health (for respawning)
function Breakable:Reset()
    self.health = self.maxHealth
    self.isBroken = false
    self.respawnTimer = 0
end

return Breakable 