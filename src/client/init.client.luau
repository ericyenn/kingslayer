-- Client initialization
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Disable Roblox's default inventory system
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
print("Disabled Roblox default inventory")

local player = Players.LocalPlayer

-- Wait for character to load
local character = player.CharacterAdded:Wait()

print("Client starting...")

-- Initialize systems
local CameraSystem = require(script.Systems.CameraSystem)
local CriticalAttackUI = require(script.Systems.CriticalAttackUI)
local DragSystem = require(script.Systems.DragSystem)
local HoverSystem = require(script.Systems.HoverSystem)
local ItemSetupSystem = require(script.Systems.ItemSetupSystem)
local InventorySystem = require(script.Systems.InventorySystem)
local ArmorSystem = require(script.Systems.ArmorSystem)
local AudioSystem = require(script.Systems.AudioSystem)

-- Initialize UI
local Hotbar = require(script.UI.Hotbar)

-- Initialize dialogue systems
local DialogueUI = require(script.DialogueUI)
local TraderUI = require(script.TraderUI)
local ItemDetailUI = require(script.ItemDetailUI)

-- Initialize boss system client-side
local BossUI = require(script.BossEffects.BossUI)

-- Import ability renderers for visual effects
local LaserEyeRenderer = require(script.AbilityRenderers.LaserEyeRenderer)
local MissileRenderer = require(script.AbilityRenderers.MissileRenderer)
local OrbitalStrikeRenderer = require(script.AbilityRenderers.OrbitalStrikeRenderer)
local RippleSquareRenderer = require(script.AbilityRenderers.RippleSquareRenderer)

-- Start systems
CameraSystem:Initialize()
CriticalAttackUI:Initialize()
DragSystem:Initialize()
HoverSystem:Initialize()
ItemSetupSystem:Initialize()
InventorySystem:Initialize()
ArmorSystem:Initialize()
AudioSystem:Initialize()

-- Initialize UI
Hotbar:Initialize()

-- Initialize dialogue systems
ItemDetailUI:Initialize()
TraderUI:Initialize(ItemDetailUI)
DialogueUI:Initialize()

-- Initialize boss system
BossUI.Initialize()

-- Wait for BossAbilities RemoteEvent and connect visual effects
local bossAbilitiesRemote = ReplicatedStorage:WaitForChild("BossAbilities")

-- Wait for boss landed remote event and connect screen shake
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
RemoteEvents.BossLanded.OnClientEvent:Connect(function()
    print("Boss landed! Triggering screen shake.")
    -- Get camera system and trigger screen shake
    local cameraSystem = _G.CameraSystem
    if cameraSystem then
        cameraSystem:StartShake(3.0, 3.0, 30) -- duration 3.0s, intensity 3.0, speed 30
    else
        warn("CameraSystem not found for screen shake")
    end
end)
print("Boss landed remote event connected successfully")

-- Handle boss ability events from server for visual effects
bossAbilitiesRemote.OnClientEvent:Connect(function(abilityData)
    if abilityData.abilityType == "trackingShot" then
        if abilityData.phase == "missile" then
            -- Handle missile phase with MissileRenderer
            MissileRenderer.handleMissile(abilityData)
        else
            -- Handle laser phases with LaserEyeRenderer
            LaserEyeRenderer.handleLaserUpdate(abilityData)
        end
    elseif abilityData.abilityType == "orbitalStrike" then
        OrbitalStrikeRenderer.handleOrbitalStrike(abilityData)
    elseif abilityData.abilityType == "rippleSquares" then
        RippleSquareRenderer.handleRippleSquares(abilityData)
    elseif abilityData.abilityType == "bossSpawned" then
        print("Boss spawned - showing boss UI")
        -- BossUI.showBossUI() -- Method doesn't exist yet
    elseif abilityData.abilityType == "bossDestroyed" then
        print("Boss destroyed - hiding boss UI")
        -- BossUI.hideBossUI() -- Method doesn't exist yet
        -- Cleanup all ability renderers
        LaserEyeRenderer.cleanup()
        MissileRenderer.cleanup()
        OrbitalStrikeRenderer.cleanup()
        RippleSquareRenderer.cleanup()
    end
end)

print("Client systems initialized!")
print("Boss ability visual effects connected!")