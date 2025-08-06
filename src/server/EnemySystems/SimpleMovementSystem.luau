-- SimpleMovementSystem.luau
-- Simple movement system that sets positions for enemies
-- Clients handle the actual movement toward positions

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SimpleMovementSystem = {}

-- Set enemy position using attributes
function SimpleMovementSystem.setPosition(entityId, position)
    local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
    if enemyFolder then
        -- Don't move dead enemies
        if enemyFolder:GetAttribute("Dead") == true then
            return false
        end
        enemyFolder:SetAttribute("Position", position)
        enemyFolder:SetAttribute("MovementTarget", position) -- Set movement target
        return true
    end
    return false
end

-- Clear enemy position (stop movement)
function SimpleMovementSystem.clearPosition(entityId)
    local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
    if enemyFolder then
        enemyFolder:SetAttribute("Position", nil)
        return true
    end
    return false
end

-- Get random position within movement zone
function SimpleMovementSystem.getRandomPositionInZone(entityId)
    local zoneData = _G.enemyMovementZones and _G.enemyMovementZones[entityId]
    if not zoneData then
        return nil
    end
    
    -- Calculate random offset within the zone
    local offset = Vector3.new(
        math.random(-zoneData.size.X / 2, zoneData.size.X / 2),
        0,
        math.random(-zoneData.size.Z / 2, zoneData.size.Z / 2)
    )
    
    -- Convert to world position using the zone's CFrame
    return zoneData.cFrame:PointToWorldSpace(offset)
end

-- Move enemy to random position within their zone (sets position)
function SimpleMovementSystem.moveToRandomPosition(entityId)
    local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
    if enemyFolder then
        -- Don't move dead enemies
        if enemyFolder:GetAttribute("Dead") == true then
            return false
        end
    end
    
    local randomPosition = SimpleMovementSystem.getRandomPositionInZone(entityId)
    if randomPosition then
        return SimpleMovementSystem.setPosition(entityId, randomPosition)
    end
    return false
end

return SimpleMovementSystem 