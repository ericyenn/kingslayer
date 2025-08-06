-- Client initialization with comprehensive error handling
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Disable Roblox's default inventory system
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
print("✅ Disabled Roblox default inventory")

local player = Players.LocalPlayer

-- Wait for character to load with timeout
local function waitForCharacterWithTimeout(timeoutSeconds)
    local startTime = tick()
    
    while not player.Character do
        if tick() - startTime > timeoutSeconds then
            error("Character failed to load within " .. timeoutSeconds .. " seconds")
        end
        wait(0.1)
    end
    
    return player.Character
end

-- Wait for RemoteEvents with validation and timeout
local function waitForRemoteEventsWithTimeout(timeoutSeconds)
    local startTime = tick()
    
    repeat
        local success, result = pcall(function()
            local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 1)
            return require(sharedFolder:WaitForChild("RemoteEvents", 1))
        end)
        
        if success then
            print("✅ RemoteEvents loaded successfully")
            return result
        end
        
        wait(0.1)
    until tick() - startTime > timeoutSeconds
    
    error("RemoteEvents failed to load within " .. timeoutSeconds .. " seconds")
end

-- Initialize with error handling and retries
local function initializeSystemWithRetry(systemName, systemModule, maxRetries, validatePrerequisites)
    maxRetries = maxRetries or 3
    
    for attempt = 1, maxRetries do
        local success, errorMessage = pcall(function()
            -- Validate prerequisites if provided
            if validatePrerequisites then
                local prereqValid, prereqError = pcall(validatePrerequisites)
                if not prereqValid then
                    error("Prerequisites validation failed: " .. tostring(prereqError))
                end
            end
            
            -- Initialize the system
            systemModule:Initialize()
        end)
        
        if success then
            print("✅ " .. systemName .. " initialized successfully" .. (attempt > 1 and " (attempt " .. attempt .. ")" or ""))
            return true
        else
            warn("⚠️ " .. systemName .. " attempt " .. attempt .. " failed: " .. tostring(errorMessage))
            if attempt < maxRetries then
                wait(0.5) -- Wait before retry
            end
        end
    end
    
    error("❌ " .. systemName .. " failed after " .. maxRetries .. " attempts")
end

-- Validate camera system prerequisites
local function validateCameraPrerequisites()
    if not player.Character then
        error("Character not available")
    end
    
    if not workspace.CurrentCamera then
        error("Camera not available")
    end
    
    print("✅ Camera prerequisites validated")
end

-- Validate RemoteEvents-dependent system prerequisites  
local function validateRemoteEventsPrerequisites()
    -- This will be called after RemoteEvents are confirmed loaded
    print("✅ RemoteEvents prerequisites validated")
end

print("🚀 Client starting...")

-- Step 1: Wait for character with timeout
local character = waitForCharacterWithTimeout(30)
print("✅ Character loaded:", character.Name)

-- Step 2: Wait for RemoteEvents with timeout
local RemoteEvents = waitForRemoteEventsWithTimeout(15)

-- Step 3: Initialize systems in proper dependency order
local systemInitializationOrder = {
    -- Critical systems first (no dependencies)
    {
        name = "CameraSystem",
        module = require(script.Systems.CameraSystem),
        maxRetries = 3,
        validatePrerequisites = validateCameraPrerequisites
    },
    
    -- Core systems (depend on camera/character)
    {
        name = "InventorySystem", 
        module = require(script.Systems.InventorySystem),
        maxRetries = 2,
        validatePrerequisites = validateRemoteEventsPrerequisites
    },
    
    -- UI systems (depend on core systems)
    {
        name = "CriticalAttackUI",
        module = require(script.Systems.CriticalAttackUI),
        maxRetries = 2
    },
    
    -- Interaction systems (depend on inventory globals)
    {
        name = "DragSystem",
        module = require(script.Systems.DragSystem),
        maxRetries = 2,
        validatePrerequisites = validateRemoteEventsPrerequisites
    },
    
    {
        name = "HoverSystem",
        module = require(script.Systems.HoverSystem),
        maxRetries = 2
    },
    
    {
        name = "ItemSetupSystem",
        module = require(script.Systems.ItemSetupSystem),
        maxRetries = 2
    },
    
    {
        name = "ArmorSystem",
        module = require(script.Systems.ArmorSystem),
        maxRetries = 2,
        validatePrerequisites = validateRemoteEventsPrerequisites
    },
    
    {
        name = "FunctionalSystem",
        module = require(script.Systems.FunctionalSystem),
        maxRetries = 2
    },
    
    {
        name = "AudioSystem",
        module = require(script.Systems.AudioSystem),
        maxRetries = 2
    },
    
    -- Animation system (new)
    {
        name = "EnemyAnimationSystem",
        module = require(script.Systems.EnemyAnimationSystem),
        maxRetries = 2
    },
    
    -- Enemy management system (new)
    {
        name = "EnemyManager",
        module = require(script.EnemyManager),
        maxRetries = 2
    },
    
    -- Enemy chat handler (new)
    {
        name = "EnemyChatHandler",
        module = require(script.Systems.EnemyChatHandler),
        maxRetries = 2
    },
    

    
    -- UI components
    {
        name = "HealthBar",
        module = require(script.UI.HealthBar),
        maxRetries = 2
    },
    {
        name = "Hotbar",
        module = require(script.UI.Hotbar),
        maxRetries = 2
    },
    {
        name = "ClockUI",
        module = require(script.UI.Clock),
        maxRetries = 2
    },
    
    {
        name = "ItemDetailUI",
        module = require(script.ItemDetailUI),
        maxRetries = 2
    },
    
    {
        name = "TraderUI",
        module = require(script.TraderUI),
        maxRetries = 2,
        customInit = function(module)
            local ItemDetailUI = require(script.ItemDetailUI)
            module:Initialize(ItemDetailUI)
        end
    },
    
    {
        name = "DialogueUI",
        module = require(script.DialogueUI),
        maxRetries = 2
    },
    
    -- Altar systems
    {
        name = "AltarUISystem",
        module = require(script.Systems.AltarUISystem),
        maxRetries = 2
    },
    
    {
        name = "SacrificeIndicator",
        module = require(script.Systems.SacrificeIndicator),
        maxRetries = 2
    },
    
    {
        name = "PrayerSystem",
        module = require(script.Systems.PrayerSystem),
        maxRetries = 2
    },
    
    {
        name = "RevivePromptSystem",
        module = require(script.Systems.RevivePromptSystem),
        maxRetries = 2
    },

    -- Projectile system (new)
    {
        name = "ProjectileRenderer",
        module = require(script.ProjectileRenderer),
        maxRetries = 2
    },

    -- Spectate UI (new)
    {
        name = "SpectateUI",
        module = require(script.UI.SpectateUI),
        maxRetries = 2
    },
    
    -- Boss system
    {
        name = "BossUI",
        module = require(script.BossEffects.BossUI),
        maxRetries = 2,
        customInit = function(module)
            module.Initialize()
        end
    },
    
    {
        name = "BossHealthUI",
        module = require(script.BossEffects.BossHealthUI),
        maxRetries = 2,
        customInit = function(module)
            _G.BossHealthUI = module
        end
    }
}

-- Initialize all systems
local initializedSystems = {}
local failedSystems = {}

for _, systemInfo in ipairs(systemInitializationOrder) do
    local success, errorMessage = pcall(function()
        if systemInfo.customInit then
            -- Custom initialization for systems with special requirements
            systemInfo.customInit(systemInfo.module)
        else
            -- Standard initialization with error handling and retries
            initializeSystemWithRetry(
                systemInfo.name, 
                systemInfo.module, 
                systemInfo.maxRetries,
                systemInfo.validatePrerequisites
            )
        end
    end)
    
    if success then
        table.insert(initializedSystems, systemInfo.name)
    else
        table.insert(failedSystems, {name = systemInfo.name, error = tostring(errorMessage)})
        warn("❌ CRITICAL: " .. systemInfo.name .. " failed to initialize: " .. tostring(errorMessage))
    end
end

-- Initialize ability renderers (non-critical)
local abilityRenderers = {
    LaserEyeRenderer = require(script.AbilityRenderers.LaserEyeRenderer),
    MissileRenderer = require(script.AbilityRenderers.MissileRenderer),
    OrbitalStrikeRenderer = require(script.AbilityRenderers.OrbitalStrikeRenderer),
    RippleSquareRenderer = require(script.AbilityRenderers.RippleSquareRenderer)
}

print("✅ Ability renderers loaded")

-- Set up boss system connections with error handling
local function setupBossConnections()
    local success, errorMessage = pcall(function()
        -- Wait for BossAbilities RemoteEvent
        local bossAbilitiesRemote = ReplicatedStorage:WaitForChild("BossAbilities", 10)
        
        -- Get BossHealthUI reference
        local BossHealthUI = _G.BossHealthUI
        if not BossHealthUI then
            warn("BossHealthUI not found in global scope")
        end
        
        -- Check if RemoteEvents exist before connecting
        if RemoteEvents.BossLanded then
            -- Boss landed screen shake and health bar connection
            RemoteEvents.BossLanded.OnClientEvent:Connect(function(bossData)
                print("Boss landed! Triggering screen shake and showing health bar.")
                
                -- Trigger screen shake
                local cameraSystem = _G.CameraSystem
                if cameraSystem then
                    cameraSystem:StartShake(3.0, 1.0, 30)
                else
                    warn("CameraSystem not found for screen shake")
                end
                
                -- Show boss health bar with boss data
                if BossHealthUI then
                    local health = (bossData and bossData.health) or 1000
                    local maxHealth = (bossData and bossData.maxHealth) or 1000
                    local name = (bossData and bossData.name) or "Boss"
                    BossHealthUI:Show(health, maxHealth, name)
                end
            end)
        else
            warn("BossLanded RemoteEvent not found")
        end
        
        -- Boss health update connection
        if RemoteEvents.BossHealthUpdate then
            RemoteEvents.BossHealthUpdate.OnClientEvent:Connect(function(healthData)
                if BossHealthUI and BossHealthUI:IsVisible() then
                    BossHealthUI:UpdateHealth(healthData.health, healthData.maxHealth)
                end
            end)
        else
            warn("BossHealthUpdate RemoteEvent not found")
        end
        
        -- Boss ability visual effects connection with batch support
        if bossAbilitiesRemote then
            bossAbilitiesRemote.OnClientEvent:Connect(function(abilityData)
                -- PERFORMANCE OPTIMIZATION: Handle batched events
                if abilityData.isBatch and abilityData.batchedEvents then
                    -- Process all events in the batch
                    for _, event in ipairs(abilityData.batchedEvents) do
                        if event.abilityType == "trackingShot" then
                            if event.phase == "missile" then
                                abilityRenderers.MissileRenderer.handleMissile(event)
                            else
                                abilityRenderers.LaserEyeRenderer.handleLaserUpdate(event)
                            end
                        elseif event.abilityType == "orbitalStrike" then
                            abilityRenderers.OrbitalStrikeRenderer.handleOrbitalStrike(event)
                        elseif event.abilityType == "rippleSquares" then
                            abilityRenderers.RippleSquareRenderer.handleRippleSquares(event)
                        end
                    end
                else
                    -- Handle single event (immediate or unbatched)
                    if abilityData.abilityType == "trackingShot" then
                        if abilityData.phase == "missile" then
                            abilityRenderers.MissileRenderer.handleMissile(abilityData)
                        else
                            abilityRenderers.LaserEyeRenderer.handleLaserUpdate(abilityData)
                        end
                    elseif abilityData.abilityType == "orbitalStrike" then
                        abilityRenderers.OrbitalStrikeRenderer.handleOrbitalStrike(abilityData)
                    elseif abilityData.abilityType == "rippleSquares" then
                        abilityRenderers.RippleSquareRenderer.handleRippleSquares(abilityData)
                    elseif abilityData.abilityType == "bossSpawned" then
                        print("Boss spawned - showing boss UI")
                    elseif abilityData.abilityType == "bossDestroyed" then
                        print("Boss destroyed - hiding boss UI and health bar")
                        abilityRenderers.LaserEyeRenderer.cleanup()
                        abilityRenderers.MissileRenderer.cleanup()
                        abilityRenderers.OrbitalStrikeRenderer.cleanup()
                        abilityRenderers.RippleSquareRenderer.cleanup()
                        
                        -- Hide boss health bar
                        if BossHealthUI then
                            BossHealthUI:Hide()
                        end
                    end
                end
            end)
        else
            warn("BossAbilities RemoteEvent not found")
        end
        
        print("✅ Boss system connections established")
    end)
    
    if not success then
        warn("❌ Boss system connections failed: " .. tostring(errorMessage))
    end
end

setupBossConnections()

-- Final initialization report
print("🎯 CLIENT INITIALIZATION COMPLETE")
print("✅ Successfully initialized systems:", table.concat(initializedSystems, ", "))

if #failedSystems > 0 then
    warn("❌ Failed systems:")
    for _, failed in ipairs(failedSystems) do
        warn("  - " .. failed.name .. ": " .. failed.error)
    end
    
    if #failedSystems >= 3 then
        error("Too many critical systems failed - game may be unplayable")
    end
else
    print("🎉 All systems initialized successfully!")
end