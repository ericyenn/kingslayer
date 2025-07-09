-- Tracking Shot Ability - Missile-based lock-on system
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local BossConfig = require(ReplicatedStorage.Shared.BossConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local MissilePhysics = require(script.Parent.Parent.MissilePhysics)

local TrackingShot = {}

-- Private variables
local activeTrackingShots: {[Types.BossData]: {target: Player?, startTime: number?, lockOnAchieved: boolean?}} = {}

-- Get the RemoteEvent for client communication
local function getBossAbilitiesRemote(): RemoteEvent
    return _G.BossAbilitiesRemote or ReplicatedStorage:FindFirstChild("BossAbilities")
end

-- Private functions
local function sendLaserUpdate(phase: string, targetPlayer: Player?, bossPosition: Vector3, extraData: {[string]: any}?)
    local remote = getBossAbilitiesRemote()
    if not remote then
        warn("BossAbilities RemoteEvent not found!")
        return
    end
    
    local data = {
        abilityType = "trackingShot",
        phase = phase,
        targetPlayerId = targetPlayer and targetPlayer.UserId or nil,
        bossPosition = bossPosition,
    }
    
    -- Add any extra data
    if extraData then
        for key, value in pairs(extraData) do
            data[key] = value
        end
    end
    
    remote:FireAllClients(data)
end

local function checkLineOfSight(bossPosition: Vector3, targetPosition: Vector3, targetPlayer: Player): boolean
    local direction = targetPosition - bossPosition
    local distance = direction.Magnitude
    
    if distance < 0.1 then
        return true
    end
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {workspace:FindFirstChild("Boss")}
    
    -- Add all OTHER player characters to filter (we want to ignore other players but detect the target)
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character and player ~= targetPlayer then
            table.insert(raycastParams.FilterDescendantsInstances, player.Character)
        end
    end

    local raycastResult = workspace:Raycast(bossPosition, direction, raycastParams)
    
    -- If we hit the target player or nothing, we have line of sight
    if not raycastResult then
        return true -- Clear line of sight
    end
    
    -- Check if we hit the target player
    if raycastResult.Instance and targetPlayer.Character then
        local hitPart = raycastResult.Instance
        return hitPart:IsDescendantOf(targetPlayer.Character)
    end
    
    -- Hit something else (environment) - no line of sight
    return false
end

local function performLockOnSequence(boss: Types.BossData, targetPlayer: Player): boolean
    local config = BossConfig.abilities.trackingShot
    local lockOnTime = 0
    local lockOnRequired = config.lockOnDuration
    
    print("Starting lock-on sequence for", targetPlayer.Name)
    
    -- Phase 1: Start blinking and check for lock-on
    sendLaserUpdate("lockOnAttempt", targetPlayer, boss.rootPart.Position, {
        blinkCount = config.blinkCount
    })
    
    -- Monitor line of sight during blinking
    for i = 1, config.blinkCount do
        local blinkStartTime = tick()
        
        -- Each blink lasts blinkSpeed seconds
        while tick() - blinkStartTime < config.blinkSpeed do
            if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local rootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart
                local targetPosition = rootPart.Position
                
                local hasLineOfSight = true -- Default to true
                if config.requiresLineOfSight then
                    hasLineOfSight = checkLineOfSight(boss.rootPart.Position, targetPosition, targetPlayer)
                end
                
                if hasLineOfSight then
                    lockOnTime = lockOnTime + (1/30) -- Assuming 30 FPS check rate
                    
                    -- Check if we've achieved lock-on
                    if lockOnTime >= lockOnRequired then
                        print("Lock-on achieved for", targetPlayer.Name, "after", lockOnTime, "seconds")
                        sendLaserUpdate("lockOnSuccess", targetPlayer, boss.rootPart.Position)
                        return true
                    end
                else
                    -- Debug: print why line of sight failed
                    print("No line of sight to", targetPlayer.Name, "- target may be behind cover")
                end
            end
            
            task.wait(1/30) -- 30 FPS update rate
        end
        
        print("Blink", i, "completed. Lock-on time:", lockOnTime, "/", lockOnRequired)
    end
    
    -- Lock-on failed
    print("Lock-on failed for", targetPlayer.Name, "- insufficient line of sight time")
    sendLaserUpdate("lockOnFailed", targetPlayer, boss.rootPart.Position)
    return false
end



-- Public functions
function TrackingShot.execute(boss: Types.BossData, targetPlayer: Player?): Types.AttackResult
    -- Prevent multiple simultaneous executions
    if activeTrackingShots[boss] then
        warn("TrackingShot already active for this boss!")
        return {success = false}
    end
    
    print("Boss executing missile tracking shot")
    
    local config = BossConfig.abilities.trackingShot
    
    -- Select target player if none provided
    if not targetPlayer then
        local activePlayers = {}
        for _, player in pairs(Players:GetPlayers()) do
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                table.insert(activePlayers, player)
            end
        end
        
        if #activePlayers > 0 then
            targetPlayer = activePlayers[math.random(1, #activePlayers)]
        else
            return {success = false}
        end
    end
    
    if not targetPlayer or not targetPlayer.Character then
        return {success = false}
    end
    
    local targetRootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRootPart then
        return {success = false}
    end
    
    -- Store tracking data
    activeTrackingShots[boss] = {
        target = targetPlayer,
        startTime = tick(),
        lockOnAchieved = false
    }
    
    -- Phase 1: Start tracking phase - tell clients to render laser
    sendLaserUpdate("tracking", targetPlayer, boss.rootPart.Position)
    
    -- Track for specified duration
    task.wait(config.trackingDuration)
    
    -- Phase 2: Attempt lock-on sequence
    local lockOnSuccessful = performLockOnSequence(boss, targetPlayer)
    
    if lockOnSuccessful then
        -- Lock-on achieved - spawn missile
        activeTrackingShots[boss].lockOnAchieved = true
        
        -- Brief pause to show lock-on success
        task.wait(0.3)
        
        -- Phase 3: Launch missile
        sendLaserUpdate("missileLaunch", targetPlayer, boss.rootPart.Position)
        local missileId = MissilePhysics.spawnMissile(boss.rootPart.Position, targetPlayer)
        
        if missileId then
            print("Missile", missileId, "launched at", targetPlayer.Name)
            
            -- Wait for missile to complete (it will handle its own physics and cleanup)
            -- The missile system will send explosion events when done
            
            -- Cleanup laser visuals
            sendLaserUpdate("inactive", nil, boss.rootPart.Position)
            activeTrackingShots[boss] = nil
    
    return {
        success = true,
                damage = config.damage,
                playersHit = {targetPlayer},
                duration = config.trackingDuration + (config.blinkCount * config.blinkSpeed) + 0.3 -- lock-on pause
            }
        else
            -- Failed to spawn missile
            sendLaserUpdate("inactive", nil, boss.rootPart.Position)
            activeTrackingShots[boss] = nil
            return {success = false}
        end
    else
        -- Lock-on failed - no missile
        print("Lock-on failed - no missile launched")
        
        -- Cleanup
        sendLaserUpdate("inactive", nil, boss.rootPart.Position)
        activeTrackingShots[boss] = nil
        
        return {
            success = true, -- Still counts as ability used
            damage = 0,
            playersHit = {},
            duration = config.trackingDuration + (config.blinkCount * config.blinkSpeed)
        }
    end
end

function TrackingShot.interrupt(boss: Types.BossData)
    local trackingData = activeTrackingShots[boss]
    if trackingData then
        -- Tell clients to cleanup laser visuals
        sendLaserUpdate("inactive", nil, boss.rootPart.Position)
        activeTrackingShots[boss] = nil
    end
    
    -- Also cleanup any missiles (they handle their own cleanup)
    MissilePhysics.destroyAllMissiles()
end

function TrackingShot.isActive(boss: Types.BossData): boolean
    return activeTrackingShots[boss] ~= nil
end

function TrackingShot.cleanup(boss: Types.BossData)
    TrackingShot.interrupt(boss)
end

return TrackingShot 