-- EnemyAnimationSystem.luau
-- Client-side animation system for enemies
-- Simple direct call system - no RemoteEvents needed

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
-- Transition duration removed - animations now change instantly
local MIN_WEIGHT = 0.0 -- Minimum weight for animations
local MAX_WEIGHT = 1.0 -- Maximum weight for animations

-- Initialize the animation system
function EnemyAnimationSystem.Initialize()
    print("🎭 EnemyAnimationSystem: Initializing client-side animation system")
    
    -- Set up simple RemoteEvent listener for AI state updates
    local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
    if RemoteEvents.EnemyAIStateUpdate then
        RemoteEvents.EnemyAIStateUpdate.OnClientEvent:Connect(function(enemyModel, entityId, newState)
            EnemyAnimationSystem.UpdateEnemyAIState(enemyModel, entityId, newState)
        end)
        print("✅ EnemyAnimationSystem: Connected to AI state updates")
    end
    
    -- Set up simple RemoteEvent listener for animation setup
    if RemoteEvents.SetupEnemyAnimations then
        RemoteEvents.SetupEnemyAnimations.OnClientEvent:Connect(function(enemyModel, entityId)
            EnemyAnimationSystem.SetupEnemyAnimations(enemyModel, entityId)
        end)
        print("✅ EnemyAnimationSystem: Connected to animation setup")
    end
    
    -- Set up cleanup loop
    RunService.Heartbeat:Connect(EnemyAnimationSystem._update)
    
    -- Make system globally accessible for direct calls
    _G.EnemyAnimationSystem = EnemyAnimationSystem
    
    print("✅ EnemyAnimationSystem: Initialized successfully")
end

-- Weighted random selection for idle animations
function EnemyAnimationSystem._selectWeightedRandomIdleAnimation(availableAnimations, lastPlayedTimes)
    if not availableAnimations or #availableAnimations == 0 then
        return nil
    end
    
    -- Calculate total weight
    local totalWeight = 0
    for _, animation in ipairs(availableAnimations) do
        totalWeight = totalWeight + (animation.weight or 1)
    end
    
    if totalWeight <= 0 then
        -- Fallback to equal weights
        totalWeight = #availableAnimations
    end
    
    -- Generate random value
    local randomValue = math.random() * totalWeight
    
    -- Select animation based on weight
    local currentWeight = 0
    for _, animation in ipairs(availableAnimations) do
        currentWeight = currentWeight + (animation.weight or 1)
        if randomValue <= currentWeight then
            return animation
        end
    end
    
    -- Fallback to first animation
    return availableAnimations[1]
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
                    
                    -- Special handling for talk animation
                    if state == "talk" then
                        tracks[state].Looped = true -- Talk animation should loop
                        tracks[state].Priority = Enum.AnimationPriority.Action -- Higher priority than movement
                    end
                    
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
        -- Transition data removed - animations now change instantly
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
    
    -- Check if we should play a new idle animation (continuous playing during idle state)
    local currentTime = tick()
    local shouldPlayNewAnimation = false
    
    -- If no current animation is playing, start a new one
    if not animationData.currentIdleAnimation or not animationData.currentIdleAnimation.track.IsPlaying then
        shouldPlayNewAnimation = true
    else
        -- If current animation has been playing for a while, consider playing a new one
        local animationStartTime = animationData.idleAnimationStartTime or currentTime
        local animationElapsed = currentTime - animationStartTime
        
        -- Get the duration of the current animation
        local currentAnimation = animationData.currentIdleAnimation
        if currentAnimation and currentAnimation.duration then
            local minDuration = currentAnimation.duration[1] or 2.0
            local maxDuration = currentAnimation.duration[2] or 4.0
            local avgDuration = (minDuration + maxDuration) / 2
            
            -- If animation has been playing longer than average duration, play a new one
            if animationElapsed >= avgDuration then
                shouldPlayNewAnimation = true
            end
        end
    end
    
    if shouldPlayNewAnimation then
        -- Stop current idle animation if playing
        if animationData.currentIdleAnimation and animationData.currentIdleAnimation.track.IsPlaying then
            animationData.currentIdleAnimation.track:Stop()
        end
        
        -- Select random idle animation
        local selectedAnimation = EnemyAnimationSystem._selectWeightedRandomIdleAnimation(
            animationData.idleAnimations, 
            animationData.lastIdlePlayedTimes
        )
        
        if selectedAnimation then
            -- Play the selected animation
            selectedAnimation.track:Play()
            animationData.currentIdleAnimation = selectedAnimation
            animationData.idleAnimationStartTime = currentTime
            
            -- Update last played time
            animationData.lastIdlePlayedTimes[selectedAnimation.index] = currentTime
            
            print("🎭 EnemyAnimationSystem: Playing idle animation", selectedAnimation.index, "for enemy:", enemyModel.Name)
        else
            print("⚠️ EnemyAnimationSystem: No idle animation selected for enemy:", enemyModel.Name)
        end
    end
end

-- Set up idle animation completion detection (REMOVED - Animation system is purely reactive)
function EnemyAnimationSystem._setupIdleAnimationCompletion(enemyModel, idleAnimation)
    -- No longer needed - animation system is purely reactive
end

-- Handle idle animation completion (REMOVED - Animation system is now purely reactive)
function EnemyAnimationSystem._onIdleAnimationComplete(enemyModel)
    -- Animation system no longer triggers state changes
    -- AISystem controls all state transitions
    print("🎭 EnemyAnimationSystem: Idle animation completed for", enemyModel.Name, "- no state change triggered")
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
    elseif animationData.aiState == "talking" then
        newState = "talk"
    end
    
    -- Only change animation if state actually changed
    if newState ~= currentState then
        print("🔄 EnemyAnimationSystem: State change for", enemyModel.Name, "from", currentState, "to", newState, "AI state:", animationData.aiState)
        
        -- Stop idle animations when entering talking state
        if newState == "talk" and animationData.currentIdleAnimation and animationData.currentIdleAnimation.track.IsPlaying then
            print("🎭 EnemyAnimationSystem: Stopping idle animation for talking state")
            animationData.currentIdleAnimation.track:Stop()
            animationData.currentIdleAnimation = nil
        end
        
        EnemyAnimationSystem._changeAnimation(enemyModel, newState)
    end
end

-- Transition functions removed - animations now change instantly

-- Change animation state instantly (no crossfade)
function EnemyAnimationSystem._changeAnimation(enemyModel, newState)
    local animationData = enemyAnimations[enemyModel]
    if not animationData then return end
    
    local currentState = animationData.currentState
    
    print("🎭 EnemyAnimationSystem: Changing animation for", enemyModel.Name, "from", currentState, "to", newState)
    
    -- Stop all current animations immediately
    for _, track in pairs(animationData.tracks) do
        if track.IsPlaying then
            track:Stop()
        end
    end
    
    -- Stop idle animations if transitioning away from idle
    if currentState == "idle" and newState ~= "idle" then
        if animationData.currentIdleAnimation and animationData.currentIdleAnimation.track.IsPlaying then
            print("🎭 EnemyAnimationSystem: Stopping idle animation for", enemyModel.Name)
            animationData.currentIdleAnimation.track:Stop()
            animationData.currentIdleAnimation = nil
        end
    end
    
    -- Handle idle state specially
    if newState == "idle" then
        -- Play idle animation immediately
        EnemyAnimationSystem._playRandomIdleAnimation(enemyModel)
    else
        -- Play the new animation immediately
        if animationData.tracks[newState] then
            animationData.tracks[newState]:Play()
            print("🎭 EnemyAnimationSystem: Started", newState, "animation for", enemyModel.Name)
        else
            print("⚠️ EnemyAnimationSystem: No", newState, "animation track found for", enemyModel.Name)
        end
    end
    
    -- Update current state immediately
    animationData.currentState = newState
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

-- Update function for cleanup (no more transitions)
function EnemyAnimationSystem._update()
    local currentTime = tick()
    
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
        print("🧪 Current AI state:", animationData.aiState)
        print("🧪 Current animation state:", animationData.currentState)
        
        -- Force idle state and test idle animation
        animationData.aiState = "idle"
        EnemyAnimationSystem._updateEnemyAnimation(enemyModel)
        
        return -- Test with first enemy found
    end
    
    print("🧪 EnemyAnimationSystem: No enemies found for testing")
end

-- Debug function to check animation status
function EnemyAnimationSystem.DebugAnimationStatus()
    print("🔍 EnemyAnimationSystem: Animation Status Report")
    print("🔍 Total animated enemies:", animatedEnemyCount)
    
    for enemyModel, animationData in pairs(enemyAnimations) do
        print("🔍 Enemy:", enemyModel.Name)
        print("  - AI State:", animationData.aiState)
        print("  - Animation State:", animationData.currentState)
        print("  - Has Idle Animations:", #(animationData.idleAnimations or {}))
        print("  - Current Idle Animation:", animationData.currentIdleAnimation and "Playing" or "None")
        print("  - Entity ID:", animationData.entityId)
        
        -- Check if idle animation is actually playing
        if animationData.currentIdleAnimation then
            print("  - Idle Animation Playing:", animationData.currentIdleAnimation.track.IsPlaying)
            print("  - Idle Animation Index:", animationData.currentIdleAnimation.index)
        end
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