-- Client-side audio system for handling game sound effects
local AudioSystem = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local SystemManager = require(ReplicatedStorage.Shared.SystemManager)
local FrameBudgetManager = require(ReplicatedStorage.Shared.FrameBudgetManager)

local player = Players.LocalPlayer

-- Audio configuration
local AUDIO_CONFIG = {
    -- Critical attack sound effects
    CRITICAL_SOUNDS = {
        timing_success = "rbxassetid://90888363530177", -- Success timing sound
        critical_hit = "rbxassetid://133571969001119", -- Critical hit impact sound
        swing_miss = "rbxassetid://91413392394116", -- Tool swing with no hit
        hit_success = { -- Random selection for successful hits
            "rbxassetid://108593693294419",
            "rbxassetid://74950311934371"
        }
    },
    
    -- Dialogue sound effects
    DIALOGUE_SOUNDS = {
        typewriter = "rbxassetid://93715887251564", -- Character-by-character typing sound
        instant_reveal = "rbxassetid://93715887251564", -- Instant text reveal sound (same as typewriter)
        choice_hover = "rbxassetid://133240016897321", -- Choice button hover sound
    },
    
    -- Volume settings
    CRITICAL_VOLUME = 0.7, -- Volume for critical effects
    DIALOGUE_VOLUME = 0.4, -- Volume for dialogue sounds (subtle)
    MASTER_VOLUME = 1.0,
    
    -- Sound properties
    SOUND_PITCH_VARIATION = 0.1, -- Random pitch variation for variety
    TYPEWRITER_THROTTLE = 0.05, -- Minimum time between typewriter sounds (seconds)
}

-- Sound cache to avoid creating new sounds every time
local soundCache = {}

-- PERFORMANCE OPTIMIZATION: Sound pooling for frequently used sounds
local soundPools = {}
local poolSizes = {
    hit_success = 5,    -- Multiple hit sounds can play simultaneously
    swing_miss = 3,     -- Multiple swings possible
    typewriter = 2,     -- Dialogue sounds
    critical_hit = 3,   -- Critical effects
    timing_success = 2  -- Timing feedback
}

-- Preloading status tracking
local preloadingStatus = {
    isPreloading = false,
    totalSounds = 0,
    loadedSounds = 0,
    failedSounds = 0
}

function AudioSystem:Initialize()
    -- Register with SystemManager
    SystemManager.RegisterSystem("AudioSystem", self)
    
    -- Set up global reference for other systems
    _G.AudioSystem = self
    
    -- Damage audio is now handled client-side in ToolSystem
    
    -- Pre-load common sounds
    self:PreloadSounds()
    
    print("AudioSystem initialized")
end

function AudioSystem:PreloadSounds()
    preloadingStatus.isPreloading = true
    preloadingStatus.totalSounds = 0
    preloadingStatus.loadedSounds = 0
    preloadingStatus.failedSounds = 0
    
    -- PERFORMANCE OPTIMIZATION: Async sound preloading with frame budgeting
    task.spawn(function()
        local loadOperations = {}
        
        -- Prepare all sound loading operations
        for soundName, soundId in pairs(AUDIO_CONFIG.CRITICAL_SOUNDS) do
            if type(soundId) == "table" then
                -- Handle arrays of sound IDs (like hit_success)
                for i, id in ipairs(soundId) do
                    local finalSoundName = soundName .. "_" .. i
                    table.insert(loadOperations, function()
                        self:AsyncLoadSound(finalSoundName, id)
                    end)
                    preloadingStatus.totalSounds += 1
                end
            else
                table.insert(loadOperations, function()
                    self:AsyncLoadSound(soundName, soundId)
                end)
                preloadingStatus.totalSounds += 1
            end
        end
        
        -- Pre-load dialogue sounds
        for soundName, soundId in pairs(AUDIO_CONFIG.DIALOGUE_SOUNDS) do
            table.insert(loadOperations, function()
                self:AsyncLoadSound(soundName, soundId)
            end)
            preloadingStatus.totalSounds += 1
        end
        
        -- Execute loading with frame budgeting (max 2 sounds per frame)
        FrameBudgetManager.executeWithLimit(loadOperations, 2)
        
        -- Initialize sound pools after loading
        self:InitializeSoundPools()
        
        preloadingStatus.isPreloading = false
        print("AudioSystem: Async preloading complete -", 
              preloadingStatus.loadedSounds, "loaded,", 
              preloadingStatus.failedSounds, "failed")
    end)
end

function AudioSystem:AsyncLoadSound(soundName, soundId)
    -- Create the sound first
    local sound = Instance.new("Sound")
    sound.Name = soundName
    sound.SoundId = soundId
    sound.Volume = AUDIO_CONFIG.CRITICAL_VOLUME * AUDIO_CONFIG.MASTER_VOLUME
    sound.Parent = SoundService
    
    -- Cache immediately for access
    soundCache[soundName] = sound
    
    -- Async load the content
    task.spawn(function()
        local success, errorMsg = pcall(function()
            ContentProvider:PreloadAsync({sound})
        end)
        
        if success then
            preloadingStatus.loadedSounds += 1
            print("AudioSystem: Preloaded", soundName)
        else
            preloadingStatus.failedSounds += 1
            warn("AudioSystem: Failed to preload", soundName, ":", errorMsg)
        end
    end)
end

function AudioSystem:InitializeSoundPools()
    -- PERFORMANCE OPTIMIZATION: Create sound pools for frequently used sounds
    for soundName, poolSize in pairs(poolSizes) do
        if not soundPools[soundName] then
            soundPools[soundName] = {
                available = {},
                inUse = {},
                maxSize = poolSize
            }
            
            -- Create initial pool
            for i = 1, poolSize do
                local pooledSound = self:CreatePooledSound(soundName)
                if pooledSound then
                    table.insert(soundPools[soundName].available, pooledSound)
                end
            end
            
            print("AudioSystem: Created sound pool for", soundName, "with", #soundPools[soundName].available, "sounds")
        end
    end
end

function AudioSystem:CreatePooledSound(baseSoundName)
    -- Find the base sound in cache
    local baseSound = soundCache[baseSoundName]
    if not baseSound then
        -- Try to find a numbered variant (like hit_success_1)
        for cachedName, cachedSound in pairs(soundCache) do
            if cachedName:match("^" .. baseSoundName .. "_") then
                baseSound = cachedSound
                break
            end
        end
    end
    
    if not baseSound then
        warn("AudioSystem: Could not find base sound for pool:", baseSoundName)
        return nil
    end
    
    -- Create pooled sound with same properties
    local pooledSound = Instance.new("Sound")
    pooledSound.Name = baseSoundName .. "_pooled_" .. tostring(math.random(1000, 9999))
    pooledSound.SoundId = baseSound.SoundId
    pooledSound.Volume = baseSound.Volume
    pooledSound.PlaybackSpeed = baseSound.PlaybackSpeed
    pooledSound.Parent = SoundService
    
    -- Return to pool when finished
    pooledSound.Ended:Connect(function()
        self:ReturnSoundToPool(baseSoundName, pooledSound)
    end)
    
    return pooledSound
end

function AudioSystem:GetOrCreateSound(soundName, soundId)
    -- Check if sound is already cached
    if soundCache[soundName] then
        return soundCache[soundName]
    end
    
    -- Create new sound
    local sound = Instance.new("Sound")
    sound.Name = soundName
    sound.SoundId = soundId
    sound.Volume = AUDIO_CONFIG.CRITICAL_VOLUME * AUDIO_CONFIG.MASTER_VOLUME
    sound.Parent = SoundService -- Use SoundService for global sounds
    
    -- Cache the sound
    soundCache[soundName] = sound
    
    return sound
end

-- PERFORMANCE OPTIMIZATION: Sound pooling methods
function AudioSystem:GetPooledSound(soundName)
    local pool = soundPools[soundName]
    if not pool then
        -- No pool for this sound, use regular method
        return self:GetOrCreateSound(soundName, nil)
    end
    
    -- Get available sound from pool
    if #pool.available > 0 then
        local sound = table.remove(pool.available)
        table.insert(pool.inUse, sound)
        return sound
    end
    
    -- Pool exhausted, create new sound if under limit
    if #pool.inUse < pool.maxSize * 2 then -- Allow 2x expansion under load
        local newSound = self:CreatePooledSound(soundName)
        if newSound then
            table.insert(pool.inUse, newSound)
            return newSound
        end
    end
    
    -- Fallback to cached sound (may cause audio overlap)
    warn("AudioSystem: Pool exhausted for", soundName, "- using cached sound")
    return soundCache[soundName]
end

function AudioSystem:ReturnSoundToPool(soundName, sound)
    local pool = soundPools[soundName]
    if not pool then return end
    
    -- Remove from in-use
    for i, inUseSound in ipairs(pool.inUse) do
        if inUseSound == sound then
            table.remove(pool.inUse, i)
            break
        end
    end
    
    -- Add back to available if pool not full
    if #pool.available < pool.maxSize then
        table.insert(pool.available, sound)
    else
        -- Pool full, destroy excess sound
        sound:Destroy()
    end
end

-- Enhanced play method with pooling
function AudioSystem:PlayPooledSound(soundName, volume, pitch)
    volume = volume or AUDIO_CONFIG.CRITICAL_VOLUME
    pitch = pitch or 1.0
    
    local sound = self:GetPooledSound(soundName)
    if not sound then
        warn("AudioSystem: Could not get sound:", soundName)
        return
    end
    
    sound.Volume = volume * AUDIO_CONFIG.MASTER_VOLUME
    sound.PlaybackSpeed = pitch
    sound:Play()
    
    return sound
end



function AudioSystem:PlaySound(soundName, soundId, volume, pitch)
    volume = volume or AUDIO_CONFIG.CRITICAL_VOLUME
    pitch = pitch or 1.0
    
    local sound = self:GetOrCreateSound(soundName, soundId)
    sound.Volume = volume * AUDIO_CONFIG.MASTER_VOLUME
    sound.PlaybackSpeed = pitch
    sound:Play()
end

function AudioSystem:PlayCriticalTimingSuccess()
    -- PERFORMANCE OPTIMIZATION: Use pooled sound
    self:PlayPooledSound("timing_success", AUDIO_CONFIG.CRITICAL_VOLUME, 1.0)
    print("AudioSystem: Played critical timing success sound")
end

function AudioSystem:PlayCriticalHitSound()
    -- PERFORMANCE OPTIMIZATION: Use pooled sound
    self:PlayPooledSound("critical_hit", AUDIO_CONFIG.CRITICAL_VOLUME, 1.0)
    print("AudioSystem: Played critical hit impact sound")
end

function AudioSystem:PlaySwingMissSound()
    -- PERFORMANCE OPTIMIZATION: Use pooled sound
    self:PlayPooledSound("swing_miss", AUDIO_CONFIG.CRITICAL_VOLUME, 1.0)
    print("AudioSystem: Played swing miss sound")
end

function AudioSystem:PlayHitSuccessSound()
    -- PERFORMANCE OPTIMIZATION: Use pooled sound with random selection
    self:PlayPooledSound("hit_success", AUDIO_CONFIG.CRITICAL_VOLUME, 1.0)
    print("AudioSystem: Played hit success sound")
end

-- Dialogue Sound Methods

-- Track last typewriter sound time for throttling
local lastTypewriterSoundTime = 0

function AudioSystem:PlayTextAdvanceSound()
    -- Throttle typewriter sounds to prevent audio spam
    local currentTime = tick()
    if currentTime - lastTypewriterSoundTime < AUDIO_CONFIG.TYPEWRITER_THROTTLE then
        return -- Skip this sound to prevent spam
    end
    
    -- PERFORMANCE OPTIMIZATION: Use pooled sound
    self:PlayPooledSound("typewriter", AUDIO_CONFIG.DIALOGUE_VOLUME, 1.0)
    
    lastTypewriterSoundTime = currentTime
    print("AudioSystem: Played text advance sound")
end

function AudioSystem:PlayInstantRevealSound()
    -- PERFORMANCE OPTIMIZATION: Use pooled sound
    self:PlayPooledSound("instant_reveal", AUDIO_CONFIG.DIALOGUE_VOLUME, 1.0)
    print("AudioSystem: Played instant reveal sound")
end

function AudioSystem:PlayChoiceHoverSound()
    -- PERFORMANCE OPTIMIZATION: Use pooled sound
    self:PlayPooledSound("choice_hover", AUDIO_CONFIG.DIALOGUE_VOLUME, 1.0)
    print("AudioSystem: Played choice hover sound")
end

function AudioSystem:SetMasterVolume(volume)
    AUDIO_CONFIG.MASTER_VOLUME = math.clamp(volume, 0, 1)
    
    -- Update all cached sounds
    for _, sound in pairs(soundCache) do
        sound.Volume = sound.Volume * AUDIO_CONFIG.MASTER_VOLUME
    end
    
    print("AudioSystem: Set master volume to", AUDIO_CONFIG.MASTER_VOLUME)
end

function AudioSystem:SetCriticalVolume(volume)
    AUDIO_CONFIG.CRITICAL_VOLUME = math.clamp(volume, 0, 1)
    print("AudioSystem: Set critical volume to", AUDIO_CONFIG.CRITICAL_VOLUME)
end

-- Public methods for other systems
function AudioSystem:GetCachedSoundCount()
    local count = 0
    for _ in pairs(soundCache) do
        count = count + 1
    end
    return count
end

function AudioSystem:GetAudioConfig()
    return AUDIO_CONFIG
end

function AudioSystem:ClearSoundCache()
    for _, sound in pairs(soundCache) do
        sound:Destroy()
    end
    soundCache = {}
    
    -- Also clear sound pools
    for _, pool in pairs(soundPools) do
        for _, sound in pairs(pool.available) do
            sound:Destroy()
        end
        for _, sound in pairs(pool.inUse) do
            sound:Destroy()
        end
    end
    soundPools = {}
    
    print("AudioSystem: Cleared sound cache and pools")
end

-- PERFORMANCE OPTIMIZATION: Status and diagnostics methods
function AudioSystem:GetPreloadingStatus()
    return {
        isPreloading = preloadingStatus.isPreloading,
        progress = preloadingStatus.totalSounds > 0 and 
                  (preloadingStatus.loadedSounds / preloadingStatus.totalSounds) or 0,
        loaded = preloadingStatus.loadedSounds,
        failed = preloadingStatus.failedSounds,
        total = preloadingStatus.totalSounds
    }
end

function AudioSystem:GetPoolStatus()
    local status = {}
    for soundName, pool in pairs(soundPools) do
        status[soundName] = {
            available = #pool.available,
            inUse = #pool.inUse,
            maxSize = pool.maxSize
        }
    end
    return status
end

function AudioSystem:PrintDiagnostics()
    local preloadStatus = self:GetPreloadingStatus()
    local poolStatus = self:GetPoolStatus()
    
    print("=== AudioSystem Diagnostics ===")
    print("Preloading:", preloadStatus.isPreloading and "IN PROGRESS" or "COMPLETE")
    print("Sounds loaded:", preloadStatus.loaded .. "/" .. preloadStatus.total)
    if preloadStatus.failed > 0 then
        print("Failed sounds:", preloadStatus.failed)
    end
    
    print("\nSound Pools:")
    for soundName, status in pairs(poolStatus) do
        print("  " .. soundName .. ": " .. status.available .. " available, " .. 
              status.inUse .. " in use (max: " .. status.maxSize .. ")")
    end
    
    print("Total cached sounds:", self:GetCachedSoundCount())
    print("===============================")
end

return AudioSystem 