-- Main Boss Controller - Orchestrates all boss behavior
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local BossConfig = require(ReplicatedStorage.Shared.BossConfig)
local Types = require(ReplicatedStorage.Shared.Types)

-- Import other boss systems
local BossMovement = require(script.Parent.BossMovement)
local BossInvincibility = require(script.Parent.BossInvincibility)
local TemplateManager = require(script.Parent.TemplateManager)

-- Import boss abilities
local TrackingShot = require(script.Parent.BossAbilities.TrackingShot)
local OrbitalStrike = require(script.Parent.BossAbilities.OrbitalStrike)
local RippleSquares = require(script.Parent.BossAbilities.RippleSquares)

local BossController = {}

-- Active boss data
local activeBoss: Types.BossData? = nil
local bossUpdateConnection: RBXScriptConnection? = nil

-- Private functions
local function createBossModel(): Model
    -- Load boss from template
    local boss = TemplateManager.loadBossTemplate()
    boss.Name = "Boss"
    boss.Parent = workspace
    
    print("Boss created from template:", boss.Name)
    return boss
end

local function initializeBossData(model: Model): Types.BossData
    local humanoid = model:FindFirstChild("Humanoid") :: Humanoid
    local rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart
    
    return {
        model = model,
        humanoid = humanoid,
        rootPart = rootPart,
        health = BossConfig.boss.health,
        maxHealth = BossConfig.boss.maxHealth,
        state = "Falling",
        currentTarget = nil,
        moveCounter = 0,
        lastMeleeHit = {},
        isInvincible = false,
        invincibilityStartTime = nil,
        currentSequence = BossConfig.sequences.default,
        currentSequenceIndex = math.random(1, #BossConfig.sequences.default),
        lastActionTime = tick() - BossConfig.timing.vulnerabilityDuration, -- Allow immediate first attack
        lastDebugTime = 0,
        wasCloseToTarget = false,
        landingConnection = nil,
        landingTime = nil, -- Track when boss landed for grace period
        inGracePeriod = false, -- Track if boss is in grace period
    }
end

local function getActivePlayers(): {Player}
    local activePlayers = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(activePlayers, player)
        end
    end
    return activePlayers
end

local function executeNextAbility(boss: Types.BossData)
    local abilityName = boss.currentSequence[boss.currentSequenceIndex]
    print("Boss executing ability:", abilityName)
    
    -- Stop movement during attack and set state immediately
    BossMovement.stopMovement(boss)
    boss.state = "Attacking"
    boss.lastActionTime = tick() -- Set this immediately to prevent multiple triggers
    
    -- Execute the specific ability
    task.spawn(function()
        -- Boss becomes invincible during attacks (simple flag)
        boss.isInvincible = true
        
        local result: Types.AttackResult
        
        if abilityName == "trackingShot" then
            result = TrackingShot.execute(boss, boss.currentTarget)
        elseif abilityName == "orbitalStrike" then
            result = OrbitalStrike.execute(boss, boss.currentTarget)
        elseif abilityName == "rippleSquares" then
            result = RippleSquares.execute(boss, boss.currentTarget)
        else
            warn("Unknown ability:", abilityName)
            result = {success = false}
        end
        
        if result.success then
            print("Ability", abilityName, "completed successfully")
        else
            warn("Ability", abilityName, "failed")
        end
        
        -- Boss becomes vulnerable after attacks (simple flag)
        boss.isInvincible = false
        
        -- Increment move counter and sequence index
        boss.moveCounter = boss.moveCounter + 1
        boss.currentSequenceIndex = boss.currentSequenceIndex + 1
        
        -- Wrap around sequence
        if boss.currentSequenceIndex > #boss.currentSequence then
            boss.currentSequenceIndex = 1
        end
        
        -- Set vulnerability phase - boss cannot attack for a period
        boss.lastActionTime = tick() + BossConfig.timing.vulnerabilityDuration
        
        -- Always resume normal movement after attack
        boss.state = "Moving"
        BossMovement.moveToRandomPlayer(boss)
    end)
end

local function updateBoss(deltaTime: number)
    if not activeBoss then return end
    
    local boss = activeBoss
    local currentTime = tick()
    
    -- Check if boss is dead
    if boss.health <= 0 then
        boss.state = "Dead"
        BossController.despawnBoss()
        return
    end
    
    -- Update based on current state
    if boss.state == "Falling" then
        -- Boss is falling from sky, don't do anything until it lands
        return
    elseif boss.state == "Moving" then
        BossMovement.updateMovement(boss, deltaTime)
        
        -- Check if grace period has ended
        if boss.inGracePeriod and boss.landingTime then
            local gracePeriodElapsed = currentTime - boss.landingTime >= BossConfig.timing.gracePeriod
            if gracePeriodElapsed then
                boss.inGracePeriod = false
                print("Boss grace period ended - can now attack and be damaged")
            end
        end
        
        -- Check if should start next attack (if close enough to target and not in grace period)
        local shouldAttack = BossMovement.isCloseToTarget(boss)
        local vulnerabilityPassed = currentTime >= boss.lastActionTime
        local notInGracePeriod = not boss.inGracePeriod
        
        -- Only print debug messages when state changes or every few seconds
        local timeSinceLastDebug = currentTime - (boss.lastDebugTime or 0)
        if shouldAttack and not vulnerabilityPassed and timeSinceLastDebug >= 2 then
            local timeLeft = boss.lastActionTime - currentTime
            print("Boss is close to target but in vulnerability phase:", math.ceil(timeLeft), "seconds left")
            boss.lastDebugTime = currentTime
        elseif shouldAttack and vulnerabilityPassed and not notInGracePeriod and timeSinceLastDebug >= 2 then
            local graceTimeLeft = BossConfig.timing.gracePeriod - (currentTime - (boss.landingTime or 0))
            print("Boss is close to target but in grace period:", math.ceil(graceTimeLeft), "seconds left")
            boss.lastDebugTime = currentTime
        end
        
        if shouldAttack and vulnerabilityPassed and notInGracePeriod then
            print("Boss vulnerability phase ended - executing ability!")
            executeNextAbility(boss)
        end
        
    -- Removed old invincibility state handling - now using simple flag system
    end
end

-- Landing detection for sky spawn
local function setupLandingDetection(boss: Types.BossData, originalSpawnPos: Vector3)
    local humanoid = boss.humanoid
    local rootPart = boss.rootPart
    
    -- Track if boss has landed
    local hasLanded = false
    
    -- Listen for humanoid state changes
    local stateConnection
    stateConnection = humanoid.StateChanged:Connect(function(oldState, newState)
        -- Check if boss landed after falling
        if not hasLanded and (newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running) then
            -- Verify boss is close to ground level (within reasonable range of original spawn position)
            local currentY = rootPart.Position.Y
            local groundY = originalSpawnPos.Y
            
            -- If boss is within 10 studs of ground level, consider it landed
            if currentY <= groundY + 10 then
                hasLanded = true
                print("Boss has landed! Triggering screen shake for all players.")
                
                -- Start grace period - boss can't attack or be damaged for 10 seconds
                boss.landingTime = tick()
                boss.inGracePeriod = true
                print("Boss grace period started - 10 seconds of immunity")
                
                -- Transition boss to Moving state and start normal behavior
                boss.state = "Moving"
                
                -- Now start targeting and movement
                BossMovement.moveToRandomPlayer(boss)
                
                -- Fire remote event to all clients for screen shake
                local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
                RemoteEvents.BossLanded:FireAllClients()
                print("Screen shake remote event fired to all clients")
                
                -- Disconnect the state change listener
                if stateConnection then
                    stateConnection:Disconnect()
                end
            end
        end
    end)
    
    -- Store connection for cleanup
    boss.landingConnection = stateConnection
end

-- Public functions
function BossController.spawnBoss(position: Vector3?): Types.BossData?
    if activeBoss then
        warn("Boss already exists! Despawn current boss first.")
        return nil
    end
    
    -- Validate templates before spawning
    if not TemplateManager.validateTemplates() then
        error("Cannot spawn boss: Template validation failed!")
        return nil
    end
    
    local spawnPos = position or BossConfig.boss.spawnPosition
    print("DEBUG: Desired spawn position:", spawnPos)
    
    -- Spawn boss in the sky (100 studs above the target position)
    local skySpawnPos = Vector3.new(spawnPos.X, spawnPos.Y + 100, spawnPos.Z)
    print("DEBUG: Sky spawn position:", skySpawnPos)
    
    local bossModel = createBossModel()
    print("DEBUG: Boss model created, initial position:", bossModel.HumanoidRootPart.Position)
    
    -- Force the boss to the sky position using CFrame (more reliable)
    bossModel.HumanoidRootPart.CFrame = CFrame.new(skySpawnPos)
    print("DEBUG: Final position after CFrame set (sky):", bossModel.HumanoidRootPart.Position)
    
    activeBoss = initializeBossData(bossModel)
    
    -- Setup landing detection for sky spawn
    setupLandingDetection(activeBoss, spawnPos)
    
    -- Start the boss update loop (lightweight)
    bossUpdateConnection = RunService.Heartbeat:Connect(updateBoss)
    
    -- Defer heavy operations until after landing to reduce spawn lag
    task.spawn(function()
        -- Wait a frame to allow initial spawn to complete
        task.wait()
        
        -- Setup melee touch detection (deferred to reduce spawn lag)
        if activeBoss and activeBoss.state == "Falling" then
            BossMovement.setupMeleeTouchDetection(activeBoss)
        end
    end)
    
    -- Defer client notification to reduce spawn lag
    task.spawn(function()
        task.wait(0.1) -- Small delay to allow spawn to settle
        
        -- Notify clients that boss spawned
        local remote = _G.BossAbilitiesRemote or ReplicatedStorage:FindFirstChild("BossAbilities")
        if remote then
            remote:FireAllClients({
                abilityType = "bossSpawned",
                bossPosition = spawnPos
            })
        end
    end)
    
    print("Boss spawned at sky position:", skySpawnPos, "will land near:", spawnPos)
    return activeBoss
end

function BossController.despawnBoss()
    if not activeBoss then return end
    
    -- Store reference before cleanup
    local boss = activeBoss
    
    -- Notify clients that boss is being destroyed
    local remote = _G.BossAbilitiesRemote or ReplicatedStorage:FindFirstChild("BossAbilities")
    if remote then
        remote:FireAllClients({
            abilityType = "bossDestroyed"
        })
    end
    
    -- Cleanup abilities
    TrackingShot.cleanup(boss)
    OrbitalStrike.cleanup(boss)
    RippleSquares.cleanup(boss)
    BossInvincibility.cleanup(boss)
    
    -- Cleanup connections
    if bossUpdateConnection then
        bossUpdateConnection:Disconnect()
        bossUpdateConnection = nil
    end
    
    -- Cleanup landing connection
    if boss.landingConnection then
        boss.landingConnection:Disconnect()
        boss.landingConnection = nil
    end
    
    if activeBoss.model then
        activeBoss.model:Destroy()
    end
    
    activeBoss = nil
    print("Boss despawned")
end

function BossController.getBoss(): Types.BossData?
    return activeBoss
end

function BossController.damagePlayer(player: Player, damage: number, damageType: string?)
    if not player.Character then return end
    
    local humanoid = player.Character:FindFirstChild("Humanoid") :: Humanoid?
    if not humanoid then return end
    
    -- Apply damage
    humanoid.Health = math.max(0, humanoid.Health - damage)
    print(player.Name, "took", damage, "damage from boss", damageType or "unknown")
    
    -- TODO: Add visual damage indicators and sound effects
end

function BossController.getActivePlayers(): {Player}
    return getActivePlayers()
end

function BossController.damageBoss(damage: number, source: Player?): boolean
    if not activeBoss then return false end
    
    -- Grace period check - block all damage during grace period
    if activeBoss.inGracePeriod then
        if source then
            print(source.Name, "tried to damage boss but it's in grace period!")
        end
        return false
    end
    
    -- Simple invincibility check - block all damage during attacks
    if activeBoss.isInvincible then
        if source then
            print(source.Name, "tried to damage boss but it's invincible during attack!")
        end
        return false
    end
    
    -- Apply damage normally when vulnerable
    activeBoss.health = math.max(0, activeBoss.health - damage)
    activeBoss.humanoid.Health = activeBoss.health
    
    if source then
        print(source.Name, "dealt", damage, "damage to boss. Boss health:", activeBoss.health)
    else
        print("Boss took", damage, "damage. Boss health:", activeBoss.health)
    end
    
    return true
end

-- Initialize on server start
local function initialize()
    print("Boss Controller initialized")
    
    -- Initialize template manager
    if not TemplateManager.initialize() then
        error("Failed to initialize templates! Check ServerStorage for BossTemplate and EnemyTemplate")
        return
    end
    
    -- Auto-spawn removed - boss is spawned manually from init.server.luau
end

-- Start initialization
initialize()

return BossController 