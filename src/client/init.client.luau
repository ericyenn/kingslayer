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
local DragSystem = require(script.Systems.DragSystem)
local HoverSystem = require(script.Systems.HoverSystem)
local ItemSetupSystem = require(script.Systems.ItemSetupSystem)
local InventorySystem = require(script.Systems.InventorySystem)
local ArmorSystem = require(script.Systems.ArmorSystem)

-- Initialize UI
local Hotbar = require(script.UI.Hotbar)

-- Start systems
CameraSystem:Initialize()
DragSystem:Initialize()
HoverSystem:Initialize()
ItemSetupSystem:Initialize()
InventorySystem:Initialize()
ArmorSystem:Initialize()

-- Initialize UI
Hotbar:Initialize()

print("Client systems initialized!")