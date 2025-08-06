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
                    
                    -- Special handling for attack animation
                    if state == "attack" then
                        tracks[state].Looped = false -- Attack animation should not loop
                        tracks[state].Priority = Enum.AnimationPriority.Action -- Higher priority than movement
                        
                        -- Connect to Stopped event to return to previous state
                        tracks[state].Stopped:Connect(function()
                            EnemyAnimationSystem._returnFromAttackAnimation(enemyModel)
                        end)
                    end
                    
                    print("🎭 EnemyAnimationSystem: Loaded", state, "animation track successfully")
                else
                    print("❌ EnemyAnimationSystem: Failed to load", state, "animation:", result)
                end
            end
        end
    end
    
    -- Set up manual animation system for walk and idle
    local walkAnimation = Instance.new("Animation")
    walkAnimation.AnimationId = "rbxassetid://121278793466470" -- Walk/run animation
    
    local idleAnimation1 = Instance.new("Animation")
    idleAnimation1.AnimationId = "rbxassetid://136904906232786" -- Idle animation 1
    
    local idleAnimation2 = Instance.new("Animation")
    idleAnimation2.AnimationId = "rbxassetid://131783126711981" -- Idle animation 2
    
    -- Load animation tracks
    local walkTrack = animator:LoadAnimation(walkAnimation)
    local idleTrack1 = animator:LoadAnimation(idleAnimation1)
    local idleTrack2 = animator:LoadAnimation(idleAnimation2)
    
    -- Configure tracks
    walkTrack.Priority = Enum.AnimationPriority.Movement
    walkTrack.Looped = true -- Walk animation should loop when playing
    idleTrack1.Priority = Enum.AnimationPriority.Idle
    idleTrack2.Priority = Enum.AnimationPriority.Idle
    
    -- Set default Humanoid Animator idle animations to prevent animation gaps
    -- These will always play in the background when no other animation is active
    local defaultIdle1 = humanoid:LoadAnimation(idleAnimation1)
    local defaultIdle2 = humanoid:LoadAnimation(idleAnimation2)
    defaultIdle1.Looped = true
    defaultIdle2.Looped = true
    defaultIdle1.Priority = Enum.AnimationPriority.Idle -- Lowest priority so movement can override
    defaultIdle2.Priority = Enum.AnimationPriority.Idle -- Lowest priority so movement can override
    
    -- Start the default idle animations
    defaultIdle1:Play()
    defaultIdle2:Play()
    
    print("🎭 EnemyAnimationSystem: Set and started default Humanoid idle animations for enemy:", enemyModel.Name)
    
    print("🎭 EnemyAnimationSystem: Set up manual animation system for enemy:", enemyModel.Name)
    
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
        walkTrack = walkTrack,
        idleTrack1 = idleTrack1,
        idleTrack2 = idleTrack2,
        defaultIdle1 = defaultIdle1, -- Store default idle animations
        defaultIdle2 = defaultIdle2,
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
    
    -- If we already have a current idle animation playing, don't change it
    if animationData.currentIdleAnimation and animationData.currentIdleAnimation.track.IsPlaying then
        return
    end
    
    -- Stop any current idle animation
    if animationData.currentIdleAnimation and animationData.currentIdleAnimation.track.IsPlaying then
        animationData.currentIdleAnimation.track:Stop()
    end
    
    -- Select random idle animation (only when entering idle state or when no animation is playing)
    local selectedAnimation = EnemyAnimationSystem._selectWeightedRandomIdleAnimation(
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
    else
        print("⚠️ EnemyAnimationSystem: No idle animation selected for enemy:", enemyModel.Name)
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
    humanoid.Died:Connect(function()
        -- Clean up animations when enemy dies
        EnemyAnimationSystem.CleanupEnemyAnimations(enemyModel)
    end)
    
    -- Monitor movement state for walk animation
    local lastPosition = humanoid.RootPart and humanoid.RootPart.Position or Vector3.new(0, 0, 0)
    local isMoving = false
    local movementThreshold = 0.1 -- Minimum distance to consider as movement
    
    -- Check movement every frame
    local connection
    connection = game:GetService("RunService").Heartbeat:Connect(function()
        if not humanoid or not humanoid.Parent or not humanoid.RootPart then
            connection:Disconnect()
            return
        end
        
        local currentPosition = humanoid.RootPart.Position
        local distance = (currentPosition - lastPosition).Magnitude
        local wasMoving = isMoving
        isMoving = distance > movementThreshold
        
        -- Update walk animation based on movement
        if isMoving and not wasMoving then
            -- Started moving
            if animationData.walkTrack and not animationData.walkTrack.IsPlaying then
                animationData.walkTrack:Play()
                print("🎭 EnemyAnimationSystem: Started walk animation for", enemyModel.Name, "- movement detected")
            end
        elseif not isMoving and wasMoving then
            -- Stopped moving
            if animationData.walkTrack and animationData.walkTrack.IsPlaying then
                animationData.walkTrack:Stop()
                print("🎭 EnemyAnimationSystem: Stopped walk animation for", enemyModel.Name, "- movement stopped")
            end
        end
        
        lastPosition = currentPosition
    end)
    
    print("✅ EnemyAnimationSystem: Connected events for enemy:", enemyModel.Name)
end

-- Update enemy animation based on AI state (walk animation now handled by movement detection)
function EnemyAnimationSystem._updateEnemyAnimation(enemyModel)
    local animationData = enemyAnimations[enemyModel]
    if not animationData then return end
    
    -- Check if enemy is dead
    local entityId = animationData.entityId
    local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(entityId))
    if enemyFolder and enemyFolder:GetAttribute("Dead") == true then
        -- Stop all animations for dead enemies
        for _, track in pairs(animationData.tracks) do
            if track.IsPlaying then
                track:Stop()
            end
        end
        
        -- Stop idle animations
        if animationData.currentIdleAnimation and animationData.currentIdleAnimation.track.IsPlaying then
            animationData.currentIdleAnimation.track:Stop()
            animationData.currentIdleAnimation = nil
        end
        
        -- Stop walk animation
        if animationData.walkTrack and animationData.walkTrack.IsPlaying then
            animationData.walkTrack:Stop()
        end
        
        print("🎭 EnemyAnimationSystem: Stopped all animations for dead enemy:", enemyModel.Name)
        return
    end
    
    local currentState = animationData.currentState
    local newState = "idle"
    
    -- Determine animation state based on AI state (excluding walk which is movement-based)
    if animationData.aiState == "idle" then
        newState = "idle"
    elseif animationData.aiState == "talking" then
        newState = "talk"
    elseif animationData.aiState == "patrol" then
        newState = "idle" -- Patrol uses idle animations when not moving
    end
    -- Note: Walk animation is now handled by movement detection, not AI state
    -- Note: "attack" animations are handled via client raycast, not AI state changes
    
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

-- Return from attack animation to previous state
function EnemyAnimationSystem._returnFromAttackAnimation(enemyModel)
    local animationData = enemyAnimations[enemyModel]
    if not animationData then return end
    
    print("🎭 EnemyAnimationSystem: Attack animation finished for", enemyModel.Name, "returning to AI state:", animationData.aiState)
    
    -- Reset current state to allow proper transitions
    animationData.currentState = "idle"
    
    -- Return to the appropriate animation based on AI state
    EnemyAnimationSystem._updateEnemyAnimation(enemyModel)
end

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
    
    -- Roblox handles idle animations automatically - no need to stop them manually
    
    -- Handle different animation states
    if newState == "idle" then
        -- Use our complex idle animation system
        EnemyAnimationSystem._playRandomIdleAnimation(enemyModel)
    elseif newState == "walk" then
        -- Walk animation is now handled by movement detection, not AI state
        -- This state is no longer used for walk animations
        print("🎭 EnemyAnimationSystem: Walk state triggered but movement detection handles walk animations")
    else
        -- Stop idle animations when transitioning to special states (talk, attack, etc.)
        if animationData.currentIdleAnimation and animationData.currentIdleAnimation.track.IsPlaying then
            animationData.currentIdleAnimation.track:Stop()
            animationData.currentIdleAnimation = nil
        end
        
        -- Play the new animation immediately (talk, attack, etc.)
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
    
    -- Handle attack state specially (triggered by client raycast)
    if newState == "attack" then
        -- Stop any current animations
        for _, track in pairs(animationData.tracks) do
            if track.IsPlaying then
                track:Stop()
            end
        end
        
        -- Stop idle animations
        if animationData.currentIdleAnimation and animationData.currentIdleAnimation.track.IsPlaying then
            animationData.currentIdleAnimation.track:Stop()
            animationData.currentIdleAnimation = nil
        end
        
        -- Play attack animation
        if animationData.tracks["attack"] then
            animationData.tracks["attack"]:Play()
            print("🎭 EnemyAnimationSystem: Started attack animation for", enemyModel.Name)
            
            -- Reset to chase state after attack animation
            task.delay(1.0, function()
                if animationData and animationData.aiState == "attack" then
                    animationData.aiState = "chase"
                    animationData.currentState = "idle" -- Reset current state
                    EnemyAnimationSystem._updateEnemyAnimation(enemyModel)
                    print("🎭 EnemyAnimationSystem: Reset to chase state for", enemyModel.Name)
                end
            end)
        else
            print("⚠️ EnemyAnimationSystem: No attack animation track found for", enemyModel.Name)
        end
        
        -- Update current state
        animationData.currentState = newState
        return
    end
    
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
    
    -- Stop manual idle and walk animations
    if animationData.idleTrack1 and animationData.idleTrack1.IsPlaying then
        animationData.idleTrack1:Stop()
    end
    
    if animationData.idleTrack2 and animationData.idleTrack2.IsPlaying then
        animationData.idleTrack2:Stop()
    end
    
    if animationData.walkTrack and animationData.walkTrack.IsPlaying then
        animationData.walkTrack:Stop()
    end
    
    -- Stop default idle animations
    if animationData.defaultIdle1 and animationData.defaultIdle1.IsPlaying then
        animationData.defaultIdle1:Stop()
    end
    
    if animationData.defaultIdle2 and animationData.defaultIdle2.IsPlaying then
        animationData.defaultIdle2:Stop()
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