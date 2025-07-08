-- Client-side audio system for handling game sound effects
local AudioSystem = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local SystemManager = require(ReplicatedStorage.Shared.SystemManager)

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
    -- Pre-load critical sounds
    for soundName, soundId in pairs(AUDIO_CONFIG.CRITICAL_SOUNDS) do
        if type(soundId) == "table" then
            -- Handle arrays of sound IDs (like hit_success)
            for i, id in ipairs(soundId) do
                self:GetOrCreateSound(soundName .. "_" .. i, id)
            end
        else
            self:GetOrCreateSound(soundName, soundId)
        end
    end
    
    -- Pre-load dialogue sounds
    for soundName, soundId in pairs(AUDIO_CONFIG.DIALOGUE_SOUNDS) do
        self:GetOrCreateSound(soundName, soundId)
    end
    
    print("AudioSystem: Pre-loaded", self:GetCachedSoundCount(), "sounds")
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



function AudioSystem:PlaySound(soundName, soundId, volume, pitch)
    volume = volume or AUDIO_CONFIG.CRITICAL_VOLUME
    pitch = pitch or 1.0
    
    local sound = self:GetOrCreateSound(soundName, soundId)
    sound.Volume = volume * AUDIO_CONFIG.MASTER_VOLUME
    sound.PlaybackSpeed = pitch
    sound:Play()
end

function AudioSystem:PlayCriticalTimingSuccess()
    -- Play the timing success sound when indicator hits critical zone
    local soundId = AUDIO_CONFIG.CRITICAL_SOUNDS.timing_success
    local sound = self:GetOrCreateSound("timing_success", soundId)
    
    -- Normal pitch for timing success
    sound.Volume = AUDIO_CONFIG.CRITICAL_VOLUME * AUDIO_CONFIG.MASTER_VOLUME
    sound.PlaybackSpeed = 1.0 -- Normal pitch
    sound:Play()
    
    print("AudioSystem: Played critical timing success sound")
end

function AudioSystem:PlayCriticalHitSound()
    -- Play the critical hit impact sound
    local soundId = AUDIO_CONFIG.CRITICAL_SOUNDS.critical_hit
    local sound = self:GetOrCreateSound("critical_hit", soundId)
    
    -- Normal pitch for critical hit
    sound.Volume = AUDIO_CONFIG.CRITICAL_VOLUME * AUDIO_CONFIG.MASTER_VOLUME
    sound.PlaybackSpeed = 1.0 -- Normal pitch
    sound:Play()
    
    print("AudioSystem: Played critical hit impact sound")
end

function AudioSystem:PlaySwingMissSound()
    -- Play the swing miss sound when tool swings but doesn't hit anything
    local soundId = AUDIO_CONFIG.CRITICAL_SOUNDS.swing_miss
    local sound = self:GetOrCreateSound("swing_miss", soundId)
    
    sound.Volume = AUDIO_CONFIG.CRITICAL_VOLUME * AUDIO_CONFIG.MASTER_VOLUME
    sound.PlaybackSpeed = 1.0
    sound:Play()
    
    print("AudioSystem: Played swing miss sound")
end

function AudioSystem:PlayHitSuccessSound()
    -- Play a random hit success sound
    local soundIds = AUDIO_CONFIG.CRITICAL_SOUNDS.hit_success
    local randomIndex = math.random(1, #soundIds)
    local soundId = soundIds[randomIndex]
    local soundName = "hit_success_" .. randomIndex
    
    local sound = self:GetOrCreateSound(soundName, soundId)
    
    sound.Volume = AUDIO_CONFIG.CRITICAL_VOLUME * AUDIO_CONFIG.MASTER_VOLUME
    sound.PlaybackSpeed = 1.0
    sound:Play()
    
    print("AudioSystem: Played hit success sound", randomIndex)
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
    
    local soundId = AUDIO_CONFIG.DIALOGUE_SOUNDS.typewriter
    local sound = self:GetOrCreateSound("typewriter", soundId)
    
    sound.Volume = AUDIO_CONFIG.DIALOGUE_VOLUME * AUDIO_CONFIG.MASTER_VOLUME
    sound.PlaybackSpeed = 1.0
    sound:Play()
    
    lastTypewriterSoundTime = currentTime
    print("AudioSystem: Played text advance sound")
end

function AudioSystem:PlayInstantRevealSound()
    -- Play sound when text is instantly revealed
    local soundId = AUDIO_CONFIG.DIALOGUE_SOUNDS.instant_reveal
    local sound = self:GetOrCreateSound("instant_reveal", soundId)
    
    sound.Volume = AUDIO_CONFIG.DIALOGUE_VOLUME * AUDIO_CONFIG.MASTER_VOLUME
    sound.PlaybackSpeed = 1.0
    sound:Play()
    
    print("AudioSystem: Played instant reveal sound")
end

function AudioSystem:PlayChoiceHoverSound()
    -- Play sound when hovering over dialogue choices
    local soundId = AUDIO_CONFIG.DIALOGUE_SOUNDS.choice_hover
    local sound = self:GetOrCreateSound("choice_hover", soundId)
    
    sound.Volume = AUDIO_CONFIG.DIALOGUE_VOLUME * AUDIO_CONFIG.MASTER_VOLUME
    sound.PlaybackSpeed = 1.0
    sound:Play()
    
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
    print("AudioSystem: Cleared sound cache")
end

return AudioSystem 