-- Orbital Strike Ability - Creates warning circles then strikes from above
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local BossConfig = require(ReplicatedStorage.Shared.BossConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local FrameBudgetManager = require(ReplicatedStorage.Shared.FrameBudgetManager)
local RemoteEventBatcher = require(ReplicatedStorage.Shared.RemoteEventBatcher)

local OrbitalStrike = {}

-- Private variables
local activeOrbitalStrikes: {[Types.BossData]: {strikePositions: {Vector3}, startTime: number?}} = {}

-- Get the RemoteEvent for client communication
local function getBossAbilitiesRemote(): RemoteEvent
    return _G.BossAbilitiesRemote or ReplicatedStorage:FindFirstChild("BossAbilities")
end

-- Private functions
local function sendOrbitalStrikeUpdate(phase: string, position: Vector3?, index: number?, bossPosition: Vector3)
    local remote = getBossAbilitiesRemote()
    if not remote then
        warn("BossAbilities RemoteEvent not found!")
        return
    end
    
    local data = {
        abilityType = "orbitalStrike",
        phase = phase,
        position = position,
        index = index,
        bossPosition = bossPosition,
    }
    
    -- PERFORMANCE OPTIMIZATION: Batch circle additions but send strikes immediately
    if phase == "addCircle" then
        RemoteEventBatcher.queueEvent(remote, data)
    else
        -- Immediate for strikes and cleanup
        remote:FireAllClients(data)
    end
end

local function generateStrikePositions(bossPosition: Vector3, count: number): {Vector3}
    local config = BossConfig.abilities.orbitalStrike
    local positions = {}
    
    for i = 1, count do
        -- Generate random angle and distance
        local angle = math.random() * math.pi * 2
        local distance = math.random(config.minDistance, config.maxDistance)
        
        -- Calculate position around boss
        local x = bossPosition.X + math.cos(angle) * distance
        local z = bossPosition.Z + math.sin(angle) * distance
        
        -- Raycast to find ground level
        local raycast = workspace:Raycast(Vector3.new(x, bossPosition.Y + 50, z), Vector3.new(0, -100, 0))
        local y = bossPosition.Y
        if raycast then
            y = raycast.Position.Y
        end
        
        table.insert(positions, Vector3.new(x, y, z))
    end
    
    return positions
end

local function dealSingleStrikeDamage(strikePos: Vector3, radius: number, damage: number, strikeIndex: number)
    print("Orbital strike", strikeIndex, "activating at position:", strikePos, "with radius:", radius)
    
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local playerPosition = player.Character.HumanoidRootPart.Position
            local distance = (strikePos - playerPosition).Magnitude
            
            print(player.Name, "distance from strike", strikeIndex, ":", math.floor(distance), "/ radius:", radius)
            
            if distance <= radius then
                local humanoid = player.Character:FindFirstChild("Humanoid") :: Humanoid?
                if humanoid then
                    humanoid.Health = math.max(0, humanoid.Health - damage)
                    print(player.Name, "took", damage, "damage from orbital strike", strikeIndex, "(distance:", math.floor(distance), ")")
                    return -- Player hit, no need to check other players for this strike
                end
            else
                print(player.Name, "outside strike", strikeIndex, "radius - no damage")
            end
        end
    end
end

-- Public functions
function OrbitalStrike.execute(boss: Types.BossData, targetPlayer: Player?): Types.AttackResult
    -- Prevent multiple simultaneous executions
    if activeOrbitalStrikes[boss] then
        warn("OrbitalStrike already active for this boss!")
        return {success = false}
    end
    
    print("Boss executing meteor shower orbital strike")
    
    local config = BossConfig.abilities.orbitalStrike
    
    -- Generate strike positions around the boss
    local strikePositions = generateStrikePositions(boss.rootPart.Position, config.circleCount)
    
    -- Store strike data
    activeOrbitalStrikes[boss] = {
        strikePositions = strikePositions,
        startTime = tick()
    }
    
    -- NEW APPROACH: Overlapping circle-then-strike pattern
    print("Starting overlapping meteor shower - circles can strike concurrently")
    
    -- Track active strikes for cleanup
    local activeStrikes = {}
    
    -- Spawn circles at regular intervals (independent of strike timing)
    task.spawn(function()
        for i = 1, config.circleCount do
            -- Step 1: Add warning circle
            print("Adding orbital strike circle", i, "of", config.circleCount)
            sendOrbitalStrikeUpdate("addCircle", strikePositions[i], i, boss.rootPart.Position)
            
            -- Step 2: Spawn independent strike task for this circle
            local strikeTask = task.spawn(function()
                -- Wait for strike delay
                task.wait(config.strikeDelay)
                
                -- Fire the strike for this circle
                print("Firing orbital strike", i, "at position:", strikePositions[i])
                sendOrbitalStrikeUpdate("fireSingleStrike", strikePositions[i], i, boss.rootPart.Position)
                
                -- Deal damage for this specific strike
                dealSingleStrikeDamage(strikePositions[i], config.damageRadius, config.damage, i)
                
                -- Mark this strike as completed
                activeStrikes[i] = nil
            end)
            
            -- Track this strike
            activeStrikes[i] = strikeTask
            
            -- Step 3: Wait before next circle (allows overlapping)
            if i < config.circleCount then
                task.wait(config.circleInterval)
            end
        end
        
        print("All circles spawned, waiting for strikes to complete...")
        
        -- Wait for all strikes to complete
        while next(activeStrikes) do
            task.wait(0.1) -- Check every 100ms
        end
        
        -- Wait for final beam visuals to finish
        task.wait(config.beamDuration)
        
        -- Final cleanup
        sendOrbitalStrikeUpdate("cleanup", nil, nil, boss.rootPart.Position)
        activeOrbitalStrikes[boss] = nil
        
        print("Overlapping meteor shower orbital strike completed")
    end)
    
    -- Calculate new total duration for overlapping strikes:
    -- Time to spawn all circles + strike delay for last circle + beam duration
    local totalDuration = (config.circleInterval * (config.circleCount - 1)) + 
                         config.strikeDelay + 
                         config.beamDuration
    
    return {
        success = true,
        damage = config.damage,
        playersHit = {}, -- Could track which players were hit
        duration = totalDuration
    }
end

function OrbitalStrike.interrupt(boss: Types.BossData)
    local strikeData = activeOrbitalStrikes[boss]
    if strikeData then
        -- Tell clients to cleanup
        sendOrbitalStrikeUpdate("cleanup", nil, nil, boss.rootPart.Position)
        activeOrbitalStrikes[boss] = nil
    end
end

function OrbitalStrike.isActive(boss: Types.BossData): boolean
    return activeOrbitalStrikes[boss] ~= nil
end

function OrbitalStrike.cleanup(boss: Types.BossData)
    OrbitalStrike.interrupt(boss)
end

return OrbitalStrike 