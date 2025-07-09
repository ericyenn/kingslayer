-- Missile Physics System - Server-side authoritative missile simulation
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local BossConfig = require(ReplicatedStorage.Shared.BossConfig)
local Types = require(ReplicatedStorage.Shared.Types)

local MissilePhysics = {}

-- Types
type MissileData = {
    id: string,
    position: Vector3,
    velocity: Vector3,
    target: Player,
    bossPosition: Vector3,
    spawnTime: number,
    lastUpdateTime: number,
    isActive: boolean
}

-- Private variables
local activeMissiles: {[string]: MissileData} = {}
local missileUpdateConnection: RBXScriptConnection?
local nextMissileId = 1

-- Get the RemoteEvent for client communication
local function getBossAbilitiesRemote(): RemoteEvent
    return _G.BossAbilitiesRemote or ReplicatedStorage:FindFirstChild("BossAbilities")
end

-- Private functions
local function generateMissileId(): string
    local id = "missile_" .. tostring(nextMissileId)
    nextMissileId = nextMissileId + 1
    return id
end

local function sendMissileUpdate(missileId: string, updateType: string, data: {[string]: any})
    local remote = getBossAbilitiesRemote()
    if not remote then
        warn("BossAbilities RemoteEvent not found!")
        return
    end
    
    local updateData = {
        abilityType = "trackingShot",
        phase = "missile",
        updateType = updateType,
        missileId = missileId
    }
    
    -- Add missile-specific data
    for key, value in pairs(data) do
        updateData[key] = value
    end
    
    remote:FireAllClients(updateData)
end

local function calculateSteering(missile: MissileData, deltaTime: number): Vector3
    if not missile.target.Character or not missile.target.Character:FindFirstChild("HumanoidRootPart") then
        return missile.velocity -- Continue straight if no target
    end
    
    local targetRootPart = missile.target.Character:FindFirstChild("HumanoidRootPart") :: BasePart
    local targetPosition = targetRootPart.Position
    
    -- Aim for a point slightly above the player for better visibility and gameplay
    local adjustedTarget = targetPosition + Vector3.new(0, 2, 0)
    
    local toTarget = (adjustedTarget - missile.position)
    local distance = toTarget.Magnitude
    
    if distance < 0.1 then
        return missile.velocity -- Continue straight if very close
    end
    
    local desiredDirection = toTarget.Unit
    local currentDirection = missile.velocity.Unit
    
    -- Calculate maximum turn angle per frame based on turn rate
    local config = BossConfig.abilities.trackingShot
    local maxTurnAngle = config.missileTurnRate * deltaTime -- radians per frame
    
    -- Calculate angle between current and desired direction
    local dot = currentDirection:Dot(desiredDirection)
    local angle = math.acos(math.clamp(dot, -1, 1))
    
    -- Limit turning to realistic amounts
    if angle > maxTurnAngle then
        -- Can't turn all the way to target in one frame, turn partially
        local turnAxis = currentDirection:Cross(desiredDirection).Unit
        local partialRotation = CFrame.fromAxisAngle(turnAxis, maxTurnAngle)
        local newDirection = partialRotation:VectorToWorldSpace(currentDirection)
        return newDirection * config.missileSpeed
    else
        -- Can reach desired direction this frame
        return desiredDirection * config.missileSpeed
    end
end

local function checkEnvironmentCollision(missile: MissileData, newPosition: Vector3): (boolean, Vector3?)
    local rayDirection = newPosition - missile.position
    local distance = rayDirection.Magnitude
    
    if distance < 0.1 then
        return false, nil
    end
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {}
    
    -- Filter out boss
    local boss = workspace:FindFirstChild("Boss")
    if boss then
        table.insert(raycastParams.FilterDescendantsInstances, boss)
    end
    
    -- Filter out all player characters (we handle player collision separately)
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(raycastParams.FilterDescendantsInstances, player.Character)
        end
    end
    
    -- Filter out missile visual models (client-side only, shouldn't affect server raycasting)
    
    local raycastResult = workspace:Raycast(missile.position, rayDirection, raycastParams)
    
    if raycastResult then
        print("Missile", missile.id, "hit environment:", raycastResult.Instance.Name, "at", raycastResult.Position)
        return true, raycastResult.Position
    end
    
    return false, nil
end

local function checkPlayerCollision(missile: MissileData): Player?
    local config = BossConfig.abilities.trackingShot
    local missileRadius = math.max(config.missileSize.X, config.missileSize.Y, config.missileSize.Z) / 2
    
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local playerRootPart = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart
            local playerPosition = playerRootPart.Position
            local distance = (missile.position - playerPosition).Magnitude
            
            if distance <= (missileRadius + 1.5) then -- 1.5 stud player collision radius (reduced)
                return player
            end
        end
    end
    
    return nil
end

local function createMissileExplosion(missileId: string, position: Vector3, hitPlayer: Player?)
    local config = BossConfig.abilities.trackingShot
    
    -- Deal damage to all players in radius
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local playerRootPart = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart
            local playerPosition = playerRootPart.Position
            local distance = (position - playerPosition).Magnitude
            
            if distance <= config.explosionRadius then
                local humanoid = player.Character:FindFirstChild("Humanoid") :: Humanoid?
                if humanoid then
                    humanoid.Health = math.max(0, humanoid.Health - config.damage)
                    print(player.Name, "took", config.damage, "damage from missile explosion")
                end
            end
        end
    end
    
    -- Send explosion event to clients for visual effects
    sendMissileUpdate("explosion_" .. tostring(math.random(1000, 9999)), "explode", {
        position = position,
        hitPlayer = hitPlayer and hitPlayer.UserId or nil
    })
    
    -- Send destroy event to clean up the missile visual
    sendMissileUpdate(missileId, "destroy", {})
end

local function updateMissilePhysics(deltaTime: number)
    local config = BossConfig.abilities.trackingShot
    local currentTime = tick()
    
    for missileId, missile in pairs(activeMissiles) do
        if not missile.isActive then
            continue
        end
        
        -- Check lifetime
        if currentTime - missile.spawnTime > config.missileLifetime then
            -- Self-destruct
            createMissileExplosion(missileId, missile.position, nil)
            missile.isActive = false
            activeMissiles[missileId] = nil
            continue
        end
        
        -- Calculate new velocity with realistic steering
        missile.velocity = calculateSteering(missile, deltaTime)
        
        -- Calculate new position
        local newPosition = missile.position + (missile.velocity * deltaTime)
        
        -- Check environment collision
        local hitEnvironment, hitPosition = checkEnvironmentCollision(missile, newPosition)
        if hitEnvironment and hitPosition then
            createMissileExplosion(missileId, hitPosition, nil)
            missile.isActive = false
            activeMissiles[missileId] = nil
            continue
        end
        
        -- Update position
        missile.position = newPosition
        
        -- Check player collision
        local hitPlayer = checkPlayerCollision(missile)
        if hitPlayer then
            print("Missile", missileId, "hit player:", hitPlayer.Name, "at position:", missile.position)
            createMissileExplosion(missileId, missile.position, hitPlayer)
            missile.isActive = false
            activeMissiles[missileId] = nil
            continue
        end
        
        -- Send periodic updates to clients
        if currentTime - missile.lastUpdateTime >= (1 / config.updateRate) then
            sendMissileUpdate(missileId, "update", {
                position = missile.position,
                velocity = missile.velocity,
                targetId = missile.target.UserId
            })
            missile.lastUpdateTime = currentTime
            
            -- Debug: Print missile position occasionally
            if math.random() < 0.02 then -- 2% chance (reduced)
                print("Missile", missileId, "at position:", 
                    math.floor(missile.position.X), math.floor(missile.position.Y), math.floor(missile.position.Z),
                    "targeting", missile.target.Name)
            end
        end
    end
    
    -- Clean up finished missiles
    if next(activeMissiles) == nil and missileUpdateConnection then
        missileUpdateConnection:Disconnect()
        missileUpdateConnection = nil
        print("All missiles finished - stopping physics updates")
    end
end

-- Public functions
function MissilePhysics.spawnMissile(bossPosition: Vector3, target: Player): string?
    print("MissilePhysics.spawnMissile called for", target.Name)
    
    if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
        print("Failed to spawn missile - target has no character or HumanoidRootPart")
        return nil
    end
    
    local config = BossConfig.abilities.trackingShot
    local missileId = generateMissileId()
    
    -- Calculate initial velocity towards target
    local targetRootPart = target.Character:FindFirstChild("HumanoidRootPart") :: BasePart
    local targetPosition = targetRootPart.Position
    local direction = (targetPosition - bossPosition).Unit
    local initialVelocity = direction * config.missileSpeed
    
    -- Create missile data
    local spawnOffset = direction * 8 + Vector3.new(0, 2, 0) -- Spawn 8 studs in front of boss, 2 studs up
    local missile: MissileData = {
        id = missileId,
        position = bossPosition + spawnOffset,
        velocity = initialVelocity,
        target = target,
        bossPosition = bossPosition,
        spawnTime = tick(),
        lastUpdateTime = tick(),
        isActive = true
    }
    
    activeMissiles[missileId] = missile
    
    -- Start physics updates if not already running
    if not missileUpdateConnection then
        missileUpdateConnection = RunService.Heartbeat:Connect(updateMissilePhysics)
        print("Started missile physics updates")
    end
    
    -- Send spawn event to clients
    sendMissileUpdate(missileId, "spawn", {
        position = missile.position,
        velocity = missile.velocity,
        targetId = target.UserId,
        bossPosition = bossPosition
    })
    
    print("Spawned missile", missileId, "targeting", target.Name)
    return missileId
end

function MissilePhysics.destroyMissile(missileId: string)
    local missile = activeMissiles[missileId]
    if missile then
        missile.isActive = false
        activeMissiles[missileId] = nil
        
        -- Send destroy event to clients
        sendMissileUpdate(missileId, "destroy", {})
    end
end

function MissilePhysics.destroyAllMissiles()
    for missileId, _ in pairs(activeMissiles) do
        MissilePhysics.destroyMissile(missileId)
    end
    
    if missileUpdateConnection then
        missileUpdateConnection:Disconnect()
        missileUpdateConnection = nil
    end
end

function MissilePhysics.getActiveMissileCount(): number
    local count = 0
    for _, missile in pairs(activeMissiles) do
        if missile.isActive then
            count = count + 1
        end
    end
    return count
end

function MissilePhysics.cleanup()
    MissilePhysics.destroyAllMissiles()
end

return MissilePhysics 