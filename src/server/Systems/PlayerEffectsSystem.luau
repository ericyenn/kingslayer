-- PlayerEffectsSystem.luau
-- Server-side system for managing player status effects like slow, jump disable, etc.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerEffectsSystem = {}

-- Store player effects data
local playerEffects = {} -- {[player] = {effects = {}, originalStats = {}}}

-- Effect types
local EFFECT_TYPES = {
    SLOW = "slow",
    JUMP_DISABLE = "jump_disable"
}

-- Default player stats
local DEFAULT_STATS = {
    walkSpeed = 16,
    jumpHeight = 7.2
}

-- Initialize the system
function PlayerEffectsSystem:Initialize()
    -- Handle player joining
    Players.PlayerAdded:Connect(function(player)
        playerEffects[player] = {
            effects = {},
            originalStats = {}
        }
        
        -- Handle character respawning
        player.CharacterAdded:Connect(function(character)
            print("🚫 Player", player.Name, "respawned - clearing effects")
            self:RemoveAllEffects(player)
        end)
    end)
    
    -- Handle player leaving
    Players.PlayerRemoving:Connect(function(player)
        -- Clean up effects before player leaves
        self:RemoveAllEffects(player)
        playerEffects[player] = nil
    end)
    
    -- Initialize existing players
    for _, player in pairs(Players:GetPlayers()) do
        playerEffects[player] = {
            effects = {},
            originalStats = {}
        }
        
        -- Handle character respawning for existing players
        if player.Character then
            player.CharacterAdded:Connect(function(character)
                print("🚫 Player", player.Name, "respawned - clearing effects")
                self:RemoveAllEffects(player)
            end)
        end
    end
    
    print("PlayerEffectsSystem initialized")
end

-- Apply a slow effect to a player
function PlayerEffectsSystem:ApplySlowEffect(player, duration, slowFactor)
    if not player or not player.Character then
        warn("PlayerEffectsSystem: Cannot apply slow effect - invalid player or no character")
        return false
    end
    
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid then
        warn("PlayerEffectsSystem: Cannot apply slow effect - no humanoid found")
        return false
    end
    
    -- Store original stats if not already stored
    if not playerEffects[player].originalStats.walkSpeed then
        playerEffects[player].originalStats.walkSpeed = humanoid.WalkSpeed
    end
    
    -- Add effect to tracking
    local effectId = "slow_" .. tick()
    playerEffects[player].effects[effectId] = {
        type = EFFECT_TYPES.SLOW,
        startTime = tick(),
        duration = duration,
        slowFactor = slowFactor
    }
    
    -- Apply the strongest slow effect (highest slow factor)
    self:_updatePlayerWalkSpeed(player)
    
    print("🐌 Applied slow effect to", player.Name, "- Speed:", humanoid.WalkSpeed, "Duration:", duration)
    
    -- Remove effect after duration using RunService
    local startTime = tick()
    local connection
    connection = game:GetService("RunService").Heartbeat:Connect(function()
        if tick() - startTime >= duration then
            connection:Disconnect()
            if player and player.Character and player.Character:FindFirstChild("Humanoid") then
                self:RemoveEffect(player, effectId)
            end
        end
    end)
    
    return true
end

-- Helper function to update player walk speed based on active slow effects
function PlayerEffectsSystem:_updatePlayerWalkSpeed(player)
    if not playerEffects[player] then
        return
    end
    
    local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
    if not humanoid then
        return
    end
    
    -- Store original walk speed if not already stored
    if not playerEffects[player].originalStats.walkSpeed then
        playerEffects[player].originalStats.walkSpeed = humanoid.WalkSpeed
    end
    
    -- Find the strongest slow effect (highest slow factor)
    local strongestSlowFactor = 0
    for _, effect in pairs(playerEffects[player].effects) do
        if effect.type == EFFECT_TYPES.SLOW then
            strongestSlowFactor = math.max(strongestSlowFactor, effect.slowFactor)
        end
    end
    
    -- Apply the strongest slow effect
    local walkSpeed = playerEffects[player].originalStats.walkSpeed or DEFAULT_STATS.walkSpeed
    local newSpeed = walkSpeed * (1 - strongestSlowFactor)
    humanoid.WalkSpeed = newSpeed
end

-- Helper function to update player jump height based on active jump disable effects
function PlayerEffectsSystem:_updatePlayerJumpHeight(player)
    if not playerEffects[player] then
        return
    end
    
    local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
    if not humanoid then
        return
    end
    
    -- Store original jump height if not already stored
    if not playerEffects[player].originalStats.jumpHeight then
        playerEffects[player].originalStats.jumpHeight = humanoid.JumpHeight
        print("🚫 Stored original jump height for", player.Name, ":", humanoid.JumpHeight)
    end
    
    -- Check if there are any jump disable effects
    local hasJumpDisable = false
    for _, effect in pairs(playerEffects[player].effects) do
        if effect.type == EFFECT_TYPES.JUMP_DISABLE then
            hasJumpDisable = true
            break
        end
    end
    
    -- Apply jump disable or restore original jump height
    if hasJumpDisable then
        humanoid.JumpHeight = 0
        print("🚫 Jump disabled for", player.Name, "- JumpHeight set to 0")
    else
        humanoid.JumpHeight = DEFAULT_STATS.jumpHeight
        print("🚫 Jump enabled for", player.Name, "- JumpHeight restored to:", DEFAULT_STATS.jumpHeight)
    end
end

-- Apply a jump disable effect to a player
function PlayerEffectsSystem:ApplyJumpDisableEffect(player, duration)
    if not player or not player.Character then
        warn("PlayerEffectsSystem: Cannot apply jump disable effect - invalid player or no character")
        return false
    end
    
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid then
        warn("PlayerEffectsSystem: Cannot apply jump disable effect - no humanoid found")
        return false
    end
    
    -- Store original stats if not already stored
    if not playerEffects[player].originalStats.jumpHeight then
        -- Use the current jump height, or default if it's 0
        local originalJumpHeight = humanoid.JumpHeight
        if originalJumpHeight == 0 then
            originalJumpHeight = DEFAULT_STATS.jumpHeight
        end
        playerEffects[player].originalStats.jumpHeight = originalJumpHeight
        print("🚫 Stored original jump height for", player.Name, ":", originalJumpHeight)
    end
    
    -- Check if player already has a jump disable effect
    for effectId, effect in pairs(playerEffects[player].effects) do
        if effect.type == EFFECT_TYPES.JUMP_DISABLE then
            print("🚫 Player", player.Name, "already has jump disable effect, skipping")
            return false
        end
    end
    
    -- Add effect to tracking
    local effectId = "jump_disable_" .. tick()
    playerEffects[player].effects[effectId] = {
        type = EFFECT_TYPES.JUMP_DISABLE,
        startTime = tick(),
        duration = duration
    }
    
    -- Apply jump disable effect
    self:_updatePlayerJumpHeight(player)
    
    print("🚫 Applied jump disable effect to", player.Name, "- Duration:", duration)
    
    -- Remove effect after duration using RunService
    local startTime = tick()
    local connection
    connection = game:GetService("RunService").Heartbeat:Connect(function()
        if tick() - startTime >= duration then
            connection:Disconnect()
            if player and player.Character and player.Character:FindFirstChild("Humanoid") then
                self:RemoveEffect(player, effectId)
            end
        end
    end)
    
    return true
end

-- Remove a specific effect from a player
function PlayerEffectsSystem:RemoveEffect(player, effectId)
    print("TEST: RemoveEffect called for", player.Name)
    
    if not playerEffects[player] or not playerEffects[player].effects[effectId] then
        print("TEST: Effect not found")
        return false
    end
    
    local effect = playerEffects[player].effects[effectId]
    local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
    
    print("TEST: Effect type:", effect.type)
    
    -- Remove effect from tracking FIRST
    playerEffects[player].effects[effectId] = nil
    print("TEST: Effect removed from tracking")
    
    if humanoid then
        if effect.type == EFFECT_TYPES.SLOW then
            -- Update walk speed based on remaining slow effects
            self:_updatePlayerWalkSpeed(player)
            print("🐌 Removed slow effect from", player.Name, "- Speed restored to:", humanoid.WalkSpeed)
        elseif effect.type == EFFECT_TYPES.JUMP_DISABLE then
            -- Update jump height based on remaining jump disable effects
            self:_updatePlayerJumpHeight(player)
            print("🚫 Removed jump disable effect from", player.Name, "- Jump height restored to:", humanoid.JumpHeight)
        end
    end
    
    return true
end

-- Remove all effects from a player
function PlayerEffectsSystem:RemoveAllEffects(player)
    if not playerEffects[player] then
        return false
    end
    
    local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
    
    if humanoid then
        -- Restore to default stats
        humanoid.WalkSpeed = DEFAULT_STATS.walkSpeed
        humanoid.JumpHeight = DEFAULT_STATS.jumpHeight
    end
    
    -- Clear all effects
    playerEffects[player].effects = {}
    
    print("🧹 Removed all effects from", player.Name)
    
    return true
end

-- Get current effects for a player
function PlayerEffectsSystem:GetPlayerEffects(player)
    if not playerEffects[player] then
        return {}
    end
    
    return playerEffects[player].effects
end

-- Check if player has a specific effect type
function PlayerEffectsSystem:HasEffect(player, effectType)
    if not playerEffects[player] then
        return false
    end
    
    for _, effect in pairs(playerEffects[player].effects) do
        if effect.type == effectType then
            return true
        end
    end
    
    return false
end

return PlayerEffectsSystem 