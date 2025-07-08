-- Client initialization
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

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

print("Client systems initialized!")