-- Server initialization
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

-- Create remote events first
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local Constants = require(ReplicatedStorage.Shared.Constants)

-- Import systems
local ServerSystems = script:WaitForChild("Systems") -- Corrected path to the Systems folder (child of this script)
local ItemSpawnSystem = require(ServerSystems.ItemSpawnSystem)
local DragServerSystem = require(ServerSystems.DragServerSystem)
local InventoryServerSystem = require(ServerSystems.InventoryServerSystem)
local ArmorServerSystem = require(ServerSystems.ArmorServerSystem)
local DamageSystem = require(ServerSystems.DamageSystem)

-- Import dialogue systems
local NPCManager = require(script.NPCManager)
local DialogueHandler = require(script.DialogueHandler)
local TraderHandler = require(script.TraderHandler)

print("Server starting...")

-- Initialize server systems
ItemSpawnSystem:Initialize()
DragServerSystem:Initialize()
InventoryServerSystem:Initialize()
ArmorServerSystem:Initialize()
DamageSystem:Initialize()

-- Set up global references for inter-system communication
_G.ItemSpawnSystem = ItemSpawnSystem
_G.InventoryServerSystem = InventoryServerSystem
_G.DamageSystem = DamageSystem

-- Initialize dialogue systems
NPCManager:Initialize()
DialogueHandler:SetNPCManager(NPCManager)
DialogueHandler:Initialize()
TraderHandler:Initialize()

print("Server systems initialized!")