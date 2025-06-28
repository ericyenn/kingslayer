-- Server initialization
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create remote events first
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

-- Import systems
local ItemSpawnSystem = require(script.Systems.ItemSpawnSystem)
local DragServerSystem = require(script.Systems.DragServerSystem)
local InventoryServerSystem = require(script.Systems.InventoryServerSystem)
local ArmorServerSystem = require(script.Systems.ArmorServerSystem)

print("Server starting...")

-- Initialize server systems
ItemSpawnSystem:Initialize()
DragServerSystem:Initialize()
InventoryServerSystem:Initialize()
ArmorServerSystem:Initialize()

print("Server systems initialized!")