-- Server initialization
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create remote events first
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

-- Import systems
local ServerSystems = script:WaitForChild("systems") -- Corrected path to the systems folder (child of this script)
local ItemSpawnSystem = require(ServerSystems.ItemSpawnSystem)
local DragServerSystem = require(ServerSystems.DragServerSystem)
local InventoryServerSystem = require(ServerSystems.InventoryServerSystem)
local ArmorServerSystem = require(ServerSystems.ArmorServerSystem)

print("Server starting...")

-- Initialize server systems
ItemSpawnSystem:Initialize()
DragServerSystem:Initialize()
InventoryServerSystem:Initialize()
ArmorServerSystem:Initialize()

print("Server systems initialized!")