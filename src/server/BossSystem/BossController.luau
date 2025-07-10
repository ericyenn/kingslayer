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

-- PERFORMANCE OPTIMIZATION: Async boss model creation to prevent lag
local function createBossModelAsync(callback: (Model?) -> ())
    -- Load boss from template asynchronously
    TemplateManager.loadBossTemplateAsync(function(boss)
        if boss then
            boss.Name = "Boss"
            boss.Parent = workspace
            print("Boss created from template:", boss.Name)
            callback(boss)
        else
            warn("Failed to create boss model")
            callback(nil)
        end
    end)
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

-- ENHANCED: Boss state validation and recovery
local function validateBossState(boss: Types.BossData): boolean
    -- Validate boss has required components
    if not boss.model or not boss.model.Parent then
        warn("BOSS ERROR: Boss model is destroyed or not parented")
        return false
    end
    
    if not boss.humanoid or not boss.humanoid.Parent then
        warn("BOSS ERROR: Boss humanoid is destroyed or not parented")
        return false
    end
    
    if not boss.rootPart or not boss.rootPart.Parent then
        warn("BOSS ERROR: Boss root part is destroyed or not parented")
        return false
    end
    
    return true
end

local function recoverStuckBoss(boss: Types.BossData)
    local currentTime = tick()
    
    -- Check if boss has been falling too long
    if boss.state == "Falling" then
        local fallDuration = currentTime - (boss.landingTime or 0)
        if fallDuration > 20 then -- If falling for more than 20 seconds, something is wrong
            warn("BOSS RECOVERY: Boss stuck in Falling state for", fallDuration, "seconds - forcing recovery")
            
            -- Force transition to Moving state
            boss.state = "Moving"
            boss.landingTime = currentTime
            boss.inGracePeriod = true
            
            -- Start movement
            BossMovement.moveToRandomPlayer(boss)
            
            -- Trigger screen shake manually
            local remoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
            pcall(function()
                remoteEvents.BossLanded:FireAllClients()
            end)
            
            print("BOSS RECOVERY: Boss recovered from stuck Falling state")
        end
    end
    
    -- Check if boss has no target for too long
    if boss.state == "Moving" and not boss.currentTarget then
        local noTargetDuration = currentTime - (boss.lastDebugTime or currentTime)
        if noTargetDuration > 10 then -- No target for 10+ seconds
            print("BOSS RECOVERY: Boss has no target - finding new one")
            BossMovement.moveToRandomPlayer(boss)
            boss.lastDebugTime = currentTime
        end
    end
end

-- ENHANCED: Ability execution with comprehensive error handling and recovery
local function executeNextAbility(boss: Types.BossData)
    local abilityName = boss.currentSequence[boss.currentSequenceIndex]
    print("BOSS DEBUG: === EXECUTING ABILITY:", abilityName, "===")
    print("BOSS DEBUG: Current sequence index:", boss.currentSequenceIndex, "/", #boss.currentSequence)
    print("BOSS DEBUG: Move counter:", boss.moveCounter)
    print("BOSS DEBUG: Target:", boss.currentTarget and boss.currentTarget.Name or "none")
    
    -- ENHANCED: Validate boss state before ability execution
    if not validateBossState(boss) then
        warn("BOSS ERROR: Cannot execute ability - boss state invalid")
        return
    end
    
    if boss.state ~= "Moving" then
        warn("BOSS WARNING: Executing ability from non-Moving state:", boss.state)
    end
    
    -- Stop movement during attack and set state immediately
    local success, stopError = pcall(function()
    BossMovement.stopMovement(boss)
    end)
    
    if not success then
        warn("BOSS ERROR: Failed to stop movement:", stopError)
    end
    
    boss.state = "Attacking"
    boss.lastActionTime = tick() -- Set this immediately to prevent multiple triggers
    print("BOSS DEBUG: Boss state set to Attacking")
    
    -- Execute the specific ability
    task.spawn(function()
        local abilityStartTime = tick()
        print("BOSS DEBUG: Ability execution started at", abilityStartTime)
        
        -- Boss becomes invincible during attacks (simple flag)
        boss.isInvincible = true
        print("BOSS DEBUG: Boss invincibility enabled")
        
        local result: Types.AttackResult = {success = false}
        
        -- ENHANCED: Better error handling for ability execution
        local abilitySuccess, abilityError = pcall(function()
        if abilityName == "trackingShot" then
            result = TrackingShot.execute(boss, boss.currentTarget)
        elseif abilityName == "orbitalStrike" then
            result = OrbitalStrike.execute(boss, boss.currentTarget)
        elseif abilityName == "rippleSquares" then
            result = RippleSquares.execute(boss, boss.currentTarget)
        else
                warn("BOSS ERROR: Unknown ability:", abilityName)
                result = {success = false}
            end
        end)
        
        if not abilitySuccess then
            warn("BOSS ERROR: Ability execution crashed:", abilityError)
            result = {success = false}
        end
        
        local abilityDuration = tick() - abilityStartTime
        
        if result.success then
            print("BOSS DEBUG: Ability", abilityName, "completed successfully in", math.floor(abilityDuration * 1000), "ms")
            if result.damage then
                print("BOSS DEBUG: Ability dealt", result.damage, "damage")
            end
            if result.playersHit then
                print("BOSS DEBUG: Ability hit", #result.playersHit, "players")
            end
        else
            warn("BOSS ERROR: Ability", abilityName, "failed after", math.floor(abilityDuration * 1000), "ms")
        end
        
        -- Boss becomes vulnerable after attacks (simple flag)
        boss.isInvincible = false
        print("BOSS DEBUG: Boss invincibility disabled")
        
        -- Increment move counter and sequence index
        boss.moveCounter = boss.moveCounter + 1
        boss.currentSequenceIndex = boss.currentSequenceIndex + 1
        
        -- Wrap around sequence
        if boss.currentSequenceIndex > #boss.currentSequence then
            boss.currentSequenceIndex = 1
            print("BOSS DEBUG: Sequence wrapped around to start")
        end
        
        print("BOSS DEBUG: Next ability will be:", boss.currentSequence[boss.currentSequenceIndex])
        
        -- Set vulnerability phase - boss cannot attack for a period
        boss.lastActionTime = tick() + BossConfig.timing.vulnerabilityDuration
        print("BOSS DEBUG: Vulnerability period started for", BossConfig.timing.vulnerabilityDuration, "seconds")
        
        -- Always resume normal movement after attack
        boss.state = "Moving"
        print("BOSS DEBUG: Boss state set to Moving")
        
        local moveSuccess, moveError = pcall(function()
        BossMovement.moveToRandomPlayer(boss)
        end)
        
        if moveSuccess then
            print("BOSS DEBUG: Boss movement resumed")
        else
            warn("BOSS ERROR: Failed to resume movement:", moveError)
        end
        
        print("BOSS DEBUG: === ABILITY", abilityName, "COMPLETE ===")
    end)
end



local function updateBoss(deltaTime: number)
    if not activeBoss then return end
    
    local boss = activeBoss
    local currentTime = tick()
    
    -- ENHANCED: Validate boss state before processing
    if not validateBossState(boss) then
        warn("BOSS ERROR: Boss state validation failed - despawning")
        BossController.despawnBoss()
        return
    end
    
    -- ENHANCED: Recovery mechanisms for stuck states
    recoverStuckBoss(boss)
    
    -- Check if boss is dead
    if boss.health <= 0 then
        print("BOSS DEBUG: Boss health depleted - transitioning to Dead state")
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

-- ENHANCED: Landing detection with multiple backup methods for reliability
local function setupLandingDetection(boss: Types.BossData, originalSpawnPos: Vector3)
    local humanoid = boss.humanoid
    local rootPart = boss.rootPart
    
    -- Track if boss has landed
    local hasLanded = false
    local fallStartTime = tick()
    local maxFallTime = 15 -- Maximum time boss can fall before forcing landing
    
    print("BOSS DEBUG: Setting up landing detection at position:", originalSpawnPos)
    print("BOSS DEBUG: Boss current position:", rootPart.Position)
    print("BOSS DEBUG: Fall start time:", fallStartTime)
    
    -- Store references locally to prevent garbage collection issues
    local remoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
    local bossMovement = BossMovement
    
    -- Function to trigger landing (used by all detection methods)
    local function triggerLanding(detectionMethod: string)
        if hasLanded then return end -- Prevent multiple triggers
        
        hasLanded = true
        local currentTime = tick()
        local fallDuration = currentTime - fallStartTime
        
        print("BOSS DEBUG: Landing triggered by", detectionMethod)
        print("BOSS DEBUG: Fall duration:", math.floor(fallDuration * 100) / 100, "seconds")
        print("BOSS DEBUG: Boss position at landing:", rootPart.Position)
        
        -- Start grace period - boss can't attack or be damaged for 10 seconds
        boss.landingTime = currentTime
        boss.inGracePeriod = true
        print("BOSS DEBUG: Grace period started - 10 seconds of immunity")
        
        -- Transition boss to Moving state and start normal behavior
        boss.state = "Moving"
        print("BOSS DEBUG: Boss state changed to Moving")
        
        -- Now start targeting and movement
        bossMovement.moveToRandomPlayer(boss)
        print("BOSS DEBUG: Boss movement and targeting started")
        
        -- Fire remote event to all clients for screen shake and health bar
        local success, errorMsg = pcall(function()
            local bossData = {
                health = boss.health,
                maxHealth = boss.maxHealth,
                name = "Boss" -- You can customize this later
            }
            remoteEvents.BossLanded:FireAllClients(bossData)
        end)
        
        if success then
            print("BOSS DEBUG: Boss landed remote event fired successfully with health data")
        else
            warn("BOSS ERROR: Failed to fire boss landed remote:", errorMsg)
        end
        
        -- Cleanup all detection connections
        if boss.landingConnection then
            boss.landingConnection:Disconnect()
            boss.landingConnection = nil
            print("BOSS DEBUG: Primary landing connection cleaned up")
        end
        if boss.backupLandingConnection then
            boss.backupLandingConnection:Disconnect()
            boss.backupLandingConnection = nil
            print("BOSS DEBUG: Backup landing connection cleaned up")
        end
        if boss.forceLandingConnection then
            task.cancel(boss.forceLandingConnection)
            boss.forceLandingConnection = nil
            print("BOSS DEBUG: Force landing connection cleaned up")
        end
    end
    
    -- PRIMARY DETECTION: Humanoid state changes (original method)
    local stateConnection
    stateConnection = humanoid.StateChanged:Connect(function(oldState, newState)
        print("BOSS DEBUG: Humanoid state changed from", oldState, "to", newState)
        
        -- Check if boss landed after falling
        if not hasLanded and (newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running) then
            -- Verify boss is close to ground level (within reasonable range of original spawn position)
            local currentY = rootPart.Position.Y
            local groundY = originalSpawnPos.Y
            
            print("BOSS DEBUG: Potential landing detected - Current Y:", currentY, "Ground Y:", groundY, "Difference:", currentY - groundY)
            
            -- If boss is within 10 studs of ground level, consider it landed
            if currentY <= groundY + 10 then
                triggerLanding("primary_humanoid_state")
            else
                print("BOSS DEBUG: Boss not close enough to ground, continuing to fall")
            end
        end
    end)
                
    -- Store primary connection for cleanup
    boss.landingConnection = stateConnection
    print("BOSS DEBUG: Primary humanoid state detection setup complete")
                
    -- BACKUP DETECTION A: Position-based detection (checks every frame)
    local backupConnection = RunService.Heartbeat:Connect(function()
        if hasLanded then return end
        
        local currentY = rootPart.Position.Y
        local groundY = originalSpawnPos.Y
        local distanceToGround = currentY - groundY
        
        -- More forgiving position-based detection
        if distanceToGround <= 12 and rootPart.Velocity.Y >= -5 then -- Nearly stopped falling and close to ground
            print("BOSS DEBUG: Backup position detection triggered - Distance to ground:", distanceToGround, "Velocity Y:", rootPart.Velocity.Y)
            triggerLanding("backup_position_based")
        end
    end)
    
    boss.backupLandingConnection = backupConnection
    print("BOSS DEBUG: Backup position-based detection setup complete")
    
    -- BACKUP DETECTION B: Timer-based forced landing (ultimate fallback)
    local forceConnection = task.spawn(function()
        while not hasLanded do
            task.wait(1) -- Check every second
            
            local currentTime = tick()
            local fallDuration = currentTime - fallStartTime
            
            if fallDuration > maxFallTime then
                warn("BOSS WARNING: Landing detection failed after", fallDuration, "seconds - forcing landing!")
                print("BOSS DEBUG: Current position:", rootPart.Position)
                print("BOSS DEBUG: Target position:", originalSpawnPos)
                print("BOSS DEBUG: Current velocity:", rootPart.Velocity)
                triggerLanding("backup_timer_forced")
                break
            elseif fallDuration > maxFallTime * 0.5 then -- Warn at halfway point
                print("BOSS DEBUG: Fall duration:", math.floor(fallDuration * 100) / 100, "seconds - still falling")
            end
        end
    end)
    
    boss.forceLandingConnection = forceConnection
    print("BOSS DEBUG: Timer-based force landing detection setup complete")
    
    print("BOSS DEBUG: All landing detection methods active")
end

-- Public functions
function BossController.spawnBoss(position: Vector3?): boolean
    print("BOSS DEBUG: === STARTING BOSS SPAWN PROCESS ===")
    
    if activeBoss then
        warn("BOSS ERROR: Boss already exists! Despawn current boss first.")
        return false
    end
    
    -- ENHANCED: Store critical references locally before async operations
    local templateManager = TemplateManager
    local bossMovement = BossMovement
    local remoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
    local bossAbilitiesRemote = _G.BossAbilitiesRemote or ReplicatedStorage:FindFirstChild("BossAbilities")
    
    print("BOSS DEBUG: Critical references captured")
    print("BOSS DEBUG: - TemplateManager:", templateManager and "✓" or "✗")
    print("BOSS DEBUG: - BossMovement:", bossMovement and "✓" or "✗") 
    print("BOSS DEBUG: - RemoteEvents:", remoteEvents and "✓" or "✗")
    print("BOSS DEBUG: - BossAbilitiesRemote:", bossAbilitiesRemote and "✓" or "✗")
    
    -- Validate templates before spawning
    if not templateManager.validateTemplates() then
        error("BOSS ERROR: Cannot spawn boss - Template validation failed!")
        return false
    end
    print("BOSS DEBUG: Template validation passed")
    
    local spawnPos = position or BossConfig.boss.spawnPosition
    print("BOSS DEBUG: Spawn position determined:", spawnPos)
    
    -- Spawn boss in the sky (100 studs above the target position)
    local skySpawnPos = Vector3.new(spawnPos.X, spawnPos.Y + 100, spawnPos.Z)
    print("BOSS DEBUG: Sky spawn position calculated:", skySpawnPos)
    
    -- ENHANCED: Improved async boss creation with better error handling
    task.spawn(function()
        local spawnStartTime = tick()
        print("BOSS DEBUG: Async spawn process started at", spawnStartTime)
        
        -- Step 1: Create boss model asynchronously (prevents lag spike)
        print("BOSS DEBUG: Step 1 - Creating boss model...")
        createBossModelAsync(function(bossModel)
            local step1Time = tick()
            print("BOSS DEBUG: Step 1 completed in", math.floor((step1Time - spawnStartTime) * 1000), "ms")
            
            if not bossModel then
                warn("BOSS ERROR: Failed to create boss model - spawn aborted")
                return
            end
            
            -- Validate boss model components
            local humanoid = bossModel:FindFirstChild("Humanoid")
            local rootPart = bossModel:FindFirstChild("HumanoidRootPart")
            
            if not humanoid or not rootPart then
                warn("BOSS ERROR: Boss model missing required components - Humanoid:", humanoid and "✓" or "✗", "RootPart:", rootPart and "✓" or "✗")
                bossModel:Destroy()
                return
            end
            
            print("BOSS DEBUG: Boss model validation passed")
            print("BOSS DEBUG: Initial position:", rootPart.Position)
            
            -- Yield to next frame after model creation
            task.wait()
            
            -- Step 2: Position boss (quick operation)
            print("BOSS DEBUG: Step 2 - Positioning boss...")
            local step2Start = tick()
            
            -- ENHANCED: More robust positioning with validation
            local success, errorMsg = pcall(function()
                rootPart.CFrame = CFrame.new(skySpawnPos)
            end)
            
            if not success then
                warn("BOSS ERROR: Failed to position boss:", errorMsg)
                bossModel:Destroy()
                return
            end
            
            print("BOSS DEBUG: Step 2 completed - Position set to:", rootPart.Position)
            print("BOSS DEBUG: Position verification - Expected:", skySpawnPos, "Actual:", rootPart.Position)
            
            -- Step 3: Initialize boss data (moderate operation)
            print("BOSS DEBUG: Step 3 - Initializing boss data...")
            local step3Start = tick()
            
            local newBossData = initializeBossData(bossModel)
            if not newBossData then
                warn("BOSS ERROR: Failed to initialize boss data")
                bossModel:Destroy()
                return
            end
            
            -- ENHANCED: Set activeBoss only after validation
            activeBoss = newBossData
            print("BOSS DEBUG: Step 3 completed - Boss data initialized")
            print("BOSS DEBUG: Boss state:", activeBoss.state)
            print("BOSS DEBUG: Boss health:", activeBoss.health, "/", activeBoss.maxHealth)
            
            -- Yield to next frame after data initialization
            task.wait()
            
            -- Step 4: Setup landing detection (lightweight operation)
            print("BOSS DEBUG: Step 4 - Setting up landing detection...")
            local step4Start = tick()
            
            local landingSuccess, landingError = pcall(function()
            setupLandingDetection(activeBoss, spawnPos)
            end)
            
            if not landingSuccess then
                warn("BOSS ERROR: Failed to setup landing detection:", landingError)
                -- Continue anyway - we have backup detection methods
            else
                print("BOSS DEBUG: Step 4 completed - Landing detection active")
            end
            
            -- Step 5: Start the boss update loop
            print("BOSS DEBUG: Step 5 - Starting boss update loop...")
            
            if bossUpdateConnection then
                warn("BOSS WARNING: Boss update connection already exists - disconnecting old one")
                bossUpdateConnection:Disconnect()
            end
            
            bossUpdateConnection = RunService.Heartbeat:Connect(updateBoss)
            print("BOSS DEBUG: Step 5 completed - Update loop started")
            
            -- Yield to next frame before heavy operations
            task.wait()
            
            -- Step 6: Setup melee detection (can be expensive due to part creation)
            print("BOSS DEBUG: Step 6 - Setting up melee detection...")
            
            if activeBoss and activeBoss.state == "Falling" then
                local meleeSuccess, meleeError = pcall(function()
                    bossMovement.setupMeleeTouchDetection(activeBoss)
                end)
                
                if meleeSuccess then
                    print("BOSS DEBUG: Step 6 completed - Melee detection active")
                else
                    warn("BOSS ERROR: Failed to setup melee detection:", meleeError)
                end
            else
                warn("BOSS WARNING: Boss not in Falling state for melee setup - State:", activeBoss and activeBoss.state or "nil")
            end
            
            -- Yield to next frame before client notification
            task.wait()
            
            -- Step 7: Notify clients that boss spawned
            print("BOSS DEBUG: Step 7 - Notifying clients...")
            
            if bossAbilitiesRemote then
                local clientSuccess, clientError = pcall(function()
                    bossAbilitiesRemote:FireAllClients({
                    abilityType = "bossSpawned",
                    bossPosition = spawnPos
                })
                end)
                
                if clientSuccess then
                    print("BOSS DEBUG: Step 7 completed - Client notification sent")
                else
                    warn("BOSS ERROR: Failed to notify clients:", clientError)
                end
            else
                warn("BOSS ERROR: BossAbilities remote not found - clients not notified")
            end
            
            local totalTime = tick() - spawnStartTime
            print("BOSS DEBUG: === BOSS SPAWN COMPLETE ===")
            print("BOSS DEBUG: Total spawn time:", math.floor(totalTime * 1000), "ms")
            print("BOSS DEBUG: Final position:", activeBoss.rootPart.Position)
            print("BOSS DEBUG: Final state:", activeBoss.state)
        end)
    end)
    
    -- Return true to indicate spawn process has started
    print("BOSS DEBUG: Spawn process initiated - returning true")
    return true
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
    
    -- ENHANCED: Cleanup all landing connections
    if boss.landingConnection then
        boss.landingConnection:Disconnect()
        boss.landingConnection = nil
        print("BOSS DEBUG: Primary landing connection cleaned up during despawn")
    end
    
    if boss.backupLandingConnection then
        boss.backupLandingConnection:Disconnect()
        boss.backupLandingConnection = nil
        print("BOSS DEBUG: Backup landing connection cleaned up during despawn")
    end
    
    if boss.forceLandingConnection then
        task.cancel(boss.forceLandingConnection)
        boss.forceLandingConnection = nil
        print("BOSS DEBUG: Force landing connection cleaned up during despawn")
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
    local oldHealth = activeBoss.health
    activeBoss.health = math.max(0, activeBoss.health - damage)
    activeBoss.humanoid.Health = activeBoss.health
    
    -- Send health update to clients if health changed
    if oldHealth ~= activeBoss.health then
        BossController.sendHealthUpdate()
    end
    
    if source then
        print(source.Name, "dealt", damage, "damage to boss. Boss health:", activeBoss.health)
    else
        print("Boss took", damage, "damage. Boss health:", activeBoss.health)
    end
    
    return true
end

-- Send boss health update to all clients
function BossController.sendHealthUpdate()
    if not activeBoss then return end
    
    local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
    local success, errorMsg = pcall(function()
        RemoteEvents.BossHealthUpdate:FireAllClients({
            health = activeBoss.health,
            maxHealth = activeBoss.maxHealth
        })
    end)
    
    if not success then
        warn("BOSS ERROR: Failed to send health update:", errorMsg)
    end
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