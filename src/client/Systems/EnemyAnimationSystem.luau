-- EnemyAnimationSystem.luau
-- Client-side animation system for enemies
-- Purely visual system that sets up animations when enemies are spawned
-- No server communication or functionality changes required

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Import animation configuration
local EnemyAnimationConfig = require(ReplicatedStorage.Shared.EnemyAnimationConfig)

local EnemyAnimationSystem = {}

-- Store animation data per enemy
local enemyAnimations = {} -- {[model] = {tracks, humanoid, lastAttackTime, currentState, idleAnimations, lastIdlePlayedTimes, entityId, transitionData, aiState}}

-- Performance tracking
local lastCleanupTime = 0
local animatedEnemyCount = 0

-- Animation transition settings
local TRANSITION_DURATION = 0.3 -- Duration of crossfade in seconds
local MIN_WEIGHT = 0.0 -- Minimum weight for animations
local MAX_WEIGHT = 1.0 -- Maximum weight for animations

-- Initialize the animation system
function EnemyAnimationSystem.Initialize()
    print("🎭 EnemyAnimationSystem: Initializing client-side animation system")
    
    -- Set up RemoteEvent listener for enemy animations
    local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
    if RemoteEvents.SetupEnemyAnimations then
        RemoteEvents.SetupEnemyAnimations.OnClientEvent:Connect(function(enemyModel, entityId)
            print("🎭 EnemyAnimationSystem: Received animation setup request for enemy:", enemyModel.Name, "entity ID:", entityId)
            EnemyAnimationSystem.SetupEnemyAnimations(enemyModel, entityId)
        end)
        print("✅ EnemyAnimationSystem: Connected to SetupEnemyAnimations RemoteEvent")
    else
        print("⚠️ EnemyAnimationSystem: SetupEnemyAnimations RemoteEvent not found")
    end
    
    -- Set up AI state update listener
    if RemoteEvents.EnemyAIStateUpdate then
        RemoteEvents.EnemyAIStateUpdate.OnClientEvent:Connect(function(enemyModel, entityId, newState)
            print("🎭 EnemyAnimationSystem: Received AI state update for enemy:", enemyModel.Name, "entity ID:", entityId, "state:", newState)
            EnemyAnimationSystem.UpdateEnemyAIState(enemyModel, entityId, newState)
        end)
        print("✅ EnemyAnimationSystem: Connected to EnemyAIStateUpdate RemoteEvent")
    else
        print("⚠️ EnemyAnimationSystem: EnemyAIStateUpdate RemoteEvent not found")
    end
    
    -- Set up cleanup loop
    RunService.Heartbeat:Connect(EnemyAnimationSystem._update)
    
    print("✅ EnemyAnimationSystem: Initialized successfully")
end

-- Weighted random selection for idle animations
function EnemyAnimationSystem._selectWeightedRandomIdleAnimation(availableAnimations, lastPlayedTimes)
    if not availableAnimations or #availableAnimations == 0 then
        return nil
    end
    
    -- Adjust weights based on recently played animations
    local adjustedAnimations = {}
    local currentTime = tick()
    local decayFactor = EnemyAnimationConfig.IDLE_SETTINGS.WEIGHT_DECAY_FACTOR
    local decayWindow = EnemyAnimationConfig.IDLE_SETTINGS.WEIGHT_DECAY_WINDOW
    
    for i, animation in ipairs(availableAnimations) do
        local lastPlayed = lastPlayedTimes[i] or 0
        local timeSinceLastPlayed = currentTime - lastPlayed
        
        -- Reduce weight if animation was played recently
        local adjustedWeight = animation.weight or 1
        if timeSinceLastPlayed < decayWindow then
            local decayMultiplier = 1 - (decayFactor * (1 - timeSinceLastPlayed / decayWindow))
            adjustedWeight = adjustedWeight * decayMultiplier
        end
        
        table.insert(adjustedAnimations, {
            animation = animation,
            weight = adjustedWeight
        })
    end
    
    -- Calculate total weight
    local totalWeight = 0
    for _, item in ipairs(adjustedAnimations) do
        totalWeight = totalWeight + item.weight
    end
    
    if totalWeight <= 0 then
        -- Fallback to equal weights
        for _, item in ipairs(adjustedAnimations) do
            item.weight = 1
        end
        totalWeight = #adjustedAnimations
    end
    
    -- Generate random value
    local randomValue = math.random() * totalWeight
    
    -- Select animation based on weight
    local currentWeight = 0
    for _, item in ipairs(adjustedAnimations) do
        currentWeight = currentWeight + item.weight
        if randomValue <= currentWeight then
            return item.animation, adjustedAnimations
        end
    end
    
    -- Fallback to first animation
    return adjustedAnimations[1].animation, adjustedAnimations
end

-- Set up animations for a specific enemy (called when enemy is spawned)
function EnemyAnimationSystem.SetupEnemyAnimations(enemyModel, entityId)
    if not enemyModel or not enemyModel:IsA("Model") then
        print("⚠️ EnemyAnimationSystem: Invalid enemy model provided")
        return false
    end
    
    local humanoid = enemyModel:FindFirstChild("Humanoid")
    if not humanoid then 
        print("⚠️ EnemyAnimationSystem: No humanoid found for enemy:", enemyModel.Name)
        return false
    end
    
    print("🎭 EnemyAnimationSystem: Setting up animations for enemy:", enemyModel.Name, "entity ID:", entityId)
    
    -- Check if we're already at the animation limit
    if animatedEnemyCount >= EnemyAnimationConfig.SETTINGS.MAX_ANIMATED_ENEMIES then
        print("⚠️ EnemyAnimationSystem: Animation limit reached, skipping enemy:", enemyModel.Name)
        return false
    end
    
    -- Create animation tracks
    local animator = humanoid:FindFirstChild("Animator")
    if not animator then
        print("🎭 EnemyAnimationSystem: Creating animator for enemy:", enemyModel.Name)
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    else
        print("🎭 EnemyAnimationSystem: Found existing animator for enemy:", enemyModel.Name)
    end
    
    local tracks = {}
    local idleAnimations = {}
    local animations = EnemyAnimationConfig.ANIMATIONS
    
    print("🎭 EnemyAnimationSystem: Loading animations for enemy:", enemyModel.Name)
    
    -- Load animation tracks
    for state, animationData in pairs(animations) do
        if state == "idle" then
            -- Handle multiple idle animations
            print("🎭 EnemyAnimationSystem: Loading idle animations for enemy:", enemyModel.Name)
            
            for i, idleAnimation in ipairs(animationData) do
                print("🎭 EnemyAnimationSystem: Loading idle animation", i, ":", idleAnimation.id)
                
                -- Skip placeholder animation IDs
                if idleAnimation.id:find("ANIMATION_ID") then
                    print("⚠️ EnemyAnimationSystem: Skipping placeholder idle animation", i)
                else
                    local success, result = pcall(function()
                        local animation = Instance.new("Animation")
                        animation.AnimationId = idleAnimation.id
                        return animator:LoadAnimation(animation)
                    end)
                    
                    if success then
                        result.Looped = false -- Idle animations should not loop
                        result.Priority = Enum.AnimationPriority.Movement
                        
                        table.insert(idleAnimations, {
                            track = result,
                            duration = idleAnimation.duration,
                            weight = idleAnimation.weight,
                            index = i
                        })
                        
                        print("🎭 EnemyAnimationSystem: Loaded idle animation", i, "successfully")
                    else
                        print("❌ EnemyAnimationSystem: Failed to load idle animation", i, ":", result)
                    end
                end
            end
        else
            -- Handle single animations (walk, attack)
            local animationId = animationData
            print("🎭 EnemyAnimationSystem: Loading", state, "animation:", animationId)
            
            -- Skip placeholder animation IDs
            if animationId:find("ANIMATION_ID") then
                print("⚠️ EnemyAnimationSystem: Skipping placeholder animation for", state)
            else
                local success, result = pcall(function()
                    local animation = Instance.new("Animation")
                    animation.AnimationId = animationId
                    return animator:LoadAnimation(animation)
                end)
                
                if success then
                    tracks[state] = result
                    
                    -- Configure animation tracks
                    tracks[state].Looped = (state == "walk")
                    tracks[state].Priority = Enum.AnimationPriority.Movement
                    
                    print("🎭 EnemyAnimationSystem: Loaded", state, "animation track successfully")
                else
                    print("❌ EnemyAnimationSystem: Failed to load", state, "animation:", result)
                end
            end
        end
    end
    
    -- Set up background idle animation (similar to Roblox's default Animate script)
    local backgroundIdleTrack1 = nil
    local backgroundIdleTrack2 = nil
    
    -- Create background idle animations
    local success1, result1 = pcall(function()
        local animation1 = Instance.new("Animation")
        animation1.AnimationId = "rbxassetid://136904906232786" -- Background idle animation 1
        return animator:LoadAnimation(animation1)
    end)
    
    local success2, result2 = pcall(function()
        local animation2 = Instance.new("Animation")
        animation2.AnimationId = "rbxassetid://131783126711981" -- Background idle animation 2
        return animator:LoadAnimation(animation2)
    end)
    
    if success1 then
        backgroundIdleTrack1 = result1
        backgroundIdleTrack1.Looped = true
        backgroundIdleTrack1.Priority = Enum.AnimationPriority.Idle
        backgroundIdleTrack1:Play()
        print("🎭 EnemyAnimationSystem: Started background idle animation 1 for enemy:", enemyModel.Name)
    else
        print("⚠️ EnemyAnimationSystem: Failed to load background idle animation 1:", result1)
    end
    
    if success2 then
        backgroundIdleTrack2 = result2
        backgroundIdleTrack2.Looped = true
        backgroundIdleTrack2.Priority = Enum.AnimationPriority.Idle
        backgroundIdleTrack2:Play()
        print("🎭 EnemyAnimationSystem: Started background idle animation 2 for enemy:", enemyModel.Name)
    else
        print("⚠️ EnemyAnimationSystem: Failed to load background idle animation 2:", result2)
    end
    
    -- Store animation data
    enemyAnimations[enemyModel] = {
        tracks = tracks,
        idleAnimations = idleAnimations,
        humanoid = humanoid,
        lastAttackTime = 0,
        currentState = "idle",
        lastIdlePlayedTimes = {},
        currentIdleAnimation = nil,
        idleAnimationStartTime = 0,
        entityId = entityId, -- Store the entity ID
        backgroundIdleTrack1 = backgroundIdleTrack1,
        backgroundIdleTrack2 = backgroundIdleTrack2,
        transitionData = {
            isTransitioning = false,
            startTime = 0,
            fromState = nil,
            toState = nil,
            fromWeight = 0,
            toWeight = 0
        },
        aiState = "idle" -- Initialize AI state
    }
    
    animatedEnemyCount = animatedEnemyCount + 1
    
    -- Start with a random idle animation
    EnemyAnimationSystem._playRandomIdleAnimation(enemyModel)
    
    -- Connect to humanoid events
    EnemyAnimationSystem._connectHumanoidEvents(enemyModel, humanoid)
    
    print("✅ EnemyAnimationSystem: Set up animations for enemy:", enemyModel.Name)
    return true
end

-- Play a random idle animation
function EnemyAnimationSystem._playRandomIdleAnimation(enemyModel)
    local animationData = enemyAnimations[enemyModel]
    if not animationData or not animationData.idleAnimations then
        print("⚠️ EnemyAnimationSystem: No idle animations available for enemy:", enemyModel.Name)
        return
    end
    
    -- Only play idle animations when AI state is "idle"
    if animationData.aiState ~= "idle" then
        print("🎭 EnemyAnimationSystem: Skipping idle animation for enemy:", enemyModel.Name, "AI state:", animationData.aiState)
        return
    end
    
    -- Stop current idle animation if playing
    if animationData.currentIdleAnimation and animationData.currentIdleAnimation.track.IsPlaying then
        animationData.currentIdleAnimation.track:Stop()
    end
    
    -- Select random idle animation
    local selectedAnimation, adjustedAnimations = EnemyAnimationSystem._selectWeightedRandomIdleAnimation(
        animationData.idleAnimations, 
        animationData.lastIdlePlayedTimes
    )
    
    if selectedAnimation then
        -- Play the selected animation
        selectedAnimation.track:Play()
        animationData.currentIdleAnimation = selectedAnimation
        animationData.idleAnimationStartTime = tick()
        
        -- Update last played time
        animationData.lastIdlePlayedTimes[selectedAnimation.index] = tick()
        
        print("🎭 EnemyAnimationSystem: Playing idle animation", selectedAnimation.index, "for enemy:", enemyModel.Name)
        
        -- Set up completion detection
        EnemyAnimationSystem._setupIdleAnimationCompletion(enemyModel, selectedAnimation)
    else
        print("⚠️ EnemyAnimationSystem: No idle animation selected for enemy:", enemyModel.Name)
    end
end

-- Set up idle animation completion detection
function EnemyAnimationSystem._setupIdleAnimationCompletion(enemyModel, idleAnimation)
    local animationData = enemyAnimations[enemyModel]
    if not animationData then return end
    
    -- Calculate animation duration
    local duration = idleAnimation.duration
    local actualDuration = math.random(duration[1], duration[2])
    
    print("🎭 EnemyAnimationSystem: Setting up completion for", enemyModel.Name, "duration:", actualDuration, "seconds")
    
    -- Set up completion timer
    local startTime = tick()
    local connection
    
    connection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        local elapsed = currentTime - startTime
        
        if elapsed >= actualDuration then
            -- Animation completed, notify AI system
            print("🎭 EnemyAnimationSystem: Animation duration completed for", enemyModel.Name, "elapsed:", elapsed, "seconds")
            EnemyAnimationSystem._onIdleAnimationComplete(enemyModel)
            connection:Disconnect()
        end
    end)
end

-- Handle idle animation completion
function EnemyAnimationSystem._onIdleAnimationComplete(enemyModel)
    local animationData = enemyAnimations[enemyModel]
    if not animationData then 
        print("⚠️ EnemyAnimationSystem: No animation data found for enemy:", enemyModel.Name)
        return 
    end
    
    print("🎭 EnemyAnimationSystem: Idle animation completed for enemy:", enemyModel.Name)
    
    -- Notify AI system via RemoteEvent with entity ID
    local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
    if RemoteEvents.IdleAnimationComplete then
        print("🎭 EnemyAnimationSystem: Firing IdleAnimationComplete RemoteEvent for enemy:", enemyModel.Name, "entity ID:", animationData.entityId)
        RemoteEvents.IdleAnimationComplete:FireServer(enemyModel, animationData.entityId)
        print("🎭 EnemyAnimationSystem: Successfully fired IdleAnimationComplete RemoteEvent")
    else
        print("⚠️ EnemyAnimationSystem: IdleAnimationComplete RemoteEvent not found")
    end
end

-- Connect to humanoid events for animation state detection
function EnemyAnimationSystem._connectHumanoidEvents(enemyModel, humanoid)
    local animationData = enemyAnimations[enemyModel]
    if not animationData then return end
    
    print("🔗 EnemyAnimationSystem: Connecting events for enemy:", enemyModel.Name)
    
    -- Monitor for death (no death animations, just cleanup)
    
    -- Monitor for death (no death animations, just cleanup)
    humanoid.Died:Connect(function()
        -- Clean up animations when enemy dies
        EnemyAnimationSystem.CleanupEnemyAnimations(enemyModel)
    end)
    
    print("✅ EnemyAnimationSystem: Connected events for enemy:", enemyModel.Name)
end

-- Update enemy animation based on AI state
function EnemyAnimationSystem._updateEnemyAnimation(enemyModel)
    local animationData = enemyAnimations[enemyModel]
    if not animationData then return end
    
    local currentState = animationData.currentState
    local newState = "idle"
    
    -- Determine animation state based on AI state
    if animationData.aiState == "idle" then
        newState = "idle"
    elseif animationData.aiState == "patrol" then
        newState = "walk"
    elseif animationData.aiState == "chase" then
        newState = "walk"
    end
    
    -- Check for attack state (simplified detection)
    local currentTime = tick()
    if EnemyAnimationSystem._isEnemyAttacking(enemyModel) then
        if currentTime - animationData.lastAttackTime > EnemyAnimationConfig.SETTINGS.ATTACK_COOLDOWN then
            newState = "attack"
            animationData.lastAttackTime = currentTime
        end
    end
    
    -- Only change animation if state actually changed
    if newState ~= currentState then
        print("🔄 EnemyAnimationSystem: State change for", enemyModel.Name, "from", currentState, "to", newState, "AI state:", animationData.aiState)
        EnemyAnimationSystem._changeAnimation(enemyModel, newState)
    end
end

-- Simple attack detection (based on proximity to players)
function EnemyAnimationSystem._isEnemyAttacking(enemyModel)
    local humanoid = enemyModel:FindFirstChild("Humanoid")
    if not humanoid then return false end
    
    local enemyPosition = humanoid.RootPart and humanoid.RootPart.Position or enemyModel:GetPivot().Position
    
    -- Check if any player is within attack range
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (enemyPosition - player.Character.HumanoidRootPart.Position).Magnitude
            if distance <= EnemyAnimationConfig.SETTINGS.ATTACK_DETECTION_RANGE then
                return true
            end
        end
    end
    
    return false
end

-- Start smooth animation transition
function EnemyAnimationSystem._startTransition(enemyModel, fromState, toState)
    local animationData = enemyAnimations[enemyModel]
    if not animationData then return end
    
    local transitionData = animationData.transitionData
    local currentTime = tick()
    
    print("🔄 EnemyAnimationSystem: Starting transition for", enemyModel.Name, "from", fromState, "to", toState)
    
    -- Set up transition data
    transitionData.isTransitioning = true
    transitionData.startTime = currentTime
    transitionData.fromState = fromState
    transitionData.toState = toState
    transitionData.fromWeight = MAX_WEIGHT
    transitionData.toWeight = MIN_WEIGHT
    
    -- Start the target animation if not already playing
    if toState == "idle" then
        -- For idle, we'll handle this in the transition update
        -- Only play idle if AI state allows it
        if animationData.aiState == "idle" then
            EnemyAnimationSystem._playRandomIdleAnimation(enemyModel)
        end
    elseif animationData.tracks[toState] and not animationData.tracks[toState].IsPlaying then
        animationData.tracks[toState]:Play()
    end
    
    -- If transitioning away from idle, ensure idle animation is stopped
    if fromState == "idle" and toState ~= "idle" then
        if animationData.currentIdleAnimation and animationData.currentIdleAnimation.track.IsPlaying then
            print("🎭 EnemyAnimationSystem: Stopping idle animation during transition for", enemyModel.Name)
            animationData.currentIdleAnimation.track:Stop()
            animationData.currentIdleAnimation = nil
        end
    end
    
    -- Set initial weights
    EnemyAnimationSystem._updateTransitionWeights(enemyModel)
end

-- Update transition weights during crossfade
function EnemyAnimationSystem._updateTransitionWeights(enemyModel)
    local animationData = enemyAnimations[enemyModel]
    if not animationData then return end
    
    local transitionData = animationData.transitionData
    if not transitionData.isTransitioning then return end
    
    local currentTime = tick()
    local elapsed = currentTime - transitionData.startTime
    local progress = math.clamp(elapsed / TRANSITION_DURATION, 0, 1)
    
    -- Calculate weights using smooth easing
    local fromWeight = MAX_WEIGHT * (1 - progress)
    local toWeight = MAX_WEIGHT * progress
    
    -- Apply weights to animations
    if transitionData.fromState == "idle" and animationData.currentIdleAnimation then
        animationData.currentIdleAnimation.track:AdjustWeight(fromWeight)
    elseif animationData.tracks[transitionData.fromState] then
        animationData.tracks[transitionData.fromState]:AdjustWeight(fromWeight)
    end
    
    if transitionData.toState == "idle" and animationData.currentIdleAnimation then
        animationData.currentIdleAnimation.track:AdjustWeight(toWeight)
    elseif animationData.tracks[transitionData.toState] then
        animationData.tracks[transitionData.toState]:AdjustWeight(toWeight)
    end
    
    -- Check if transition is complete
    if progress >= 1.0 then
        EnemyAnimationSystem._completeTransition(enemyModel)
    end
end

-- Complete the transition
function EnemyAnimationSystem._completeTransition(enemyModel)
    local animationData = enemyAnimations[enemyModel]
    if not animationData then return end
    
    local transitionData = animationData.transitionData
    if not transitionData.isTransitioning then return end
    
    print("✅ EnemyAnimationSystem: Completed transition for", enemyModel.Name, "to", transitionData.toState)
    
    -- Stop the old animation
    if transitionData.fromState == "idle" and animationData.currentIdleAnimation then
        animationData.currentIdleAnimation.track:Stop()
        animationData.currentIdleAnimation = nil
    elseif animationData.tracks[transitionData.fromState] then
        animationData.tracks[transitionData.fromState]:Stop()
    end
    
    -- Set final weights
    if transitionData.toState == "idle" and animationData.currentIdleAnimation then
        animationData.currentIdleAnimation.track:AdjustWeight(MAX_WEIGHT)
    elseif animationData.tracks[transitionData.toState] then
        animationData.tracks[transitionData.toState]:AdjustWeight(MAX_WEIGHT)
    end
    
    -- Update current state
    animationData.currentState = transitionData.toState
    
    -- Reset transition data
    transitionData.isTransitioning = false
    transitionData.fromState = nil
    transitionData.toState = nil
    transitionData.fromWeight = 0
    transitionData.toWeight = 0
end

-- Change animation state with smooth transition
function EnemyAnimationSystem._changeAnimation(enemyModel, newState)
    local animationData = enemyAnimations[enemyModel]
    if not animationData then return end
    
    local currentState = animationData.currentState
    local transitionData = animationData.transitionData
    
    print("🎭 EnemyAnimationSystem: Changing animation for", enemyModel.Name, "from", currentState, "to", newState)
    
    -- If already transitioning, complete the current transition first
    if transitionData.isTransitioning then
        EnemyAnimationSystem._completeTransition(enemyModel)
    end
    
    -- If transitioning away from idle, immediately stop idle animation
    if currentState == "idle" and newState ~= "idle" then
        if animationData.currentIdleAnimation and animationData.currentIdleAnimation.track.IsPlaying then
            print("🎭 EnemyAnimationSystem: Immediately stopping idle animation for", enemyModel.Name)
            animationData.currentIdleAnimation.track:Stop()
            animationData.currentIdleAnimation = nil
        end
    end
    
    -- Start new transition
    EnemyAnimationSystem._startTransition(enemyModel, currentState, newState)
end

-- Update enemy AI state
function EnemyAnimationSystem.UpdateEnemyAIState(enemyModel, entityId, newState)
    local animationData = enemyAnimations[enemyModel]
    if not animationData then return end
    
    print("🎭 EnemyAnimationSystem: Updating AI state for enemy:", enemyModel.Name, "entity ID:", entityId, "new state:", newState)
    
    local oldState = animationData.aiState
    animationData.aiState = newState
    
    -- If transitioning away from idle, stop any playing idle animations
    if oldState == "idle" and newState ~= "idle" then
        if animationData.currentIdleAnimation and animationData.currentIdleAnimation.track.IsPlaying then
            print("🎭 EnemyAnimationSystem: Stopping idle animation for enemy:", enemyModel.Name, "AI state changed from", oldState, "to", newState)
            animationData.currentIdleAnimation.track:Stop()
            animationData.currentIdleAnimation = nil
        end
    end
    
    -- Update animations based on new AI state
    EnemyAnimationSystem._updateEnemyAnimation(enemyModel)
end


-- Clean up animations for a specific enemy
function EnemyAnimationSystem.CleanupEnemyAnimations(enemyModel)
    local animationData = enemyAnimations[enemyModel]
    if not animationData then return end
    
    print("🧹 EnemyAnimationSystem: Cleaning up animations for enemy:", enemyModel.Name)
    
    -- Stop all animation tracks
    for _, track in pairs(animationData.tracks) do
        if track.IsPlaying then
            track:Stop()
        end
    end
    
    -- Stop idle animations
    if animationData.idleAnimations then
        for _, idleAnimation in ipairs(animationData.idleAnimations) do
            if idleAnimation.track.IsPlaying then
                idleAnimation.track:Stop()
            end
        end
    end
    
    -- Stop background idle animations
    if animationData.backgroundIdleTrack1 and animationData.backgroundIdleTrack1.IsPlaying then
        animationData.backgroundIdleTrack1:Stop()
    end
    
    if animationData.backgroundIdleTrack2 and animationData.backgroundIdleTrack2.IsPlaying then
        animationData.backgroundIdleTrack2:Stop()
    end
    
    -- Remove from tracking
    enemyAnimations[enemyModel] = nil
    animatedEnemyCount = animatedEnemyCount - 1
    
    print("✅ EnemyAnimationSystem: Cleaned up animations for enemy:", enemyModel.Name)
end

-- Update function for cleanup and transition updates
function EnemyAnimationSystem._update()
    local currentTime = tick()
    
    -- Update ongoing transitions
    for enemyModel, animationData in pairs(enemyAnimations) do
        if animationData.transitionData.isTransitioning then
            EnemyAnimationSystem._updateTransitionWeights(enemyModel)
        end
    end
    
    -- Clean up destroyed enemies periodically
    if currentTime - lastCleanupTime > EnemyAnimationConfig.SETTINGS.CLEANUP_INTERVAL then
        lastCleanupTime = currentTime
        
        for enemyModel, animationData in pairs(enemyAnimations) do
            if not enemyModel.Parent or not animationData.humanoid.Parent then
                EnemyAnimationSystem.CleanupEnemyAnimations(enemyModel)
            end
        end
    end
end

-- Get system statistics
function EnemyAnimationSystem.GetStats()
    return {
        animatedEnemyCount = animatedEnemyCount,
        maxAnimatedEnemies = EnemyAnimationConfig.SETTINGS.MAX_ANIMATED_ENEMIES,
        lastCleanupTime = lastCleanupTime,
        animationData = enemyAnimations
    }
end

-- Test function to manually trigger animations (for debugging)
function EnemyAnimationSystem.TestAnimations()
    print("🧪 EnemyAnimationSystem: Testing animations")
    
    -- Find any enemy and test animations
    for enemyModel, animationData in pairs(enemyAnimations) do
        print("🧪 EnemyAnimationSystem: Testing animations for enemy:", enemyModel.Name)
        
        -- Test idle animations
        if animationData.idleAnimations then
            print("🧪 EnemyAnimationSystem: Testing idle animations")
            for i, idleAnimation in ipairs(animationData.idleAnimations) do
                print("🧪 EnemyAnimationSystem: Testing idle animation", i)
                idleAnimation.track:Play()
                task.wait(2)
                idleAnimation.track:Stop()
            end
        end
        
        -- Test walk animation
        if animationData.tracks.walk then
            print("🧪 EnemyAnimationSystem: Testing walk animation")
            animationData.tracks.walk:Play()
            task.wait(2)
            animationData.tracks.walk:Stop()
        end
        
        break -- Only test first enemy
    end
end

-- Clean up all animations (called when system is shut down)
function EnemyAnimationSystem.Cleanup()
    for enemyModel, _ in pairs(enemyAnimations) do
        EnemyAnimationSystem.CleanupEnemyAnimations(enemyModel)
    end
    print("🧹 EnemyAnimationSystem: Cleaned up all animations")
end

return EnemyAnimationSystem 