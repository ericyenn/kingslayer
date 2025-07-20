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

-- Import boss system
local BossController = require(script.BossSystem.BossController)

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

-- Set up boss system RemoteEvent
local BossAbilitiesRemote = Instance.new("RemoteEvent")
BossAbilitiesRemote.Name = "BossAbilities"
BossAbilitiesRemote.Parent = ReplicatedStorage
_G.BossAbilitiesRemote = BossAbilitiesRemote

-- Initialize boss system (but don't auto-spawn boss)
_G.BossController = BossController

-- Set up boss spawn handling
local function handleBossSpawn(player, spawnPosition)
    print("Player", player.Name, "requested boss spawn at position:", spawnPosition)
    
    -- Get player's position for default spawn location
    local playerPosition = Vector3.new(0, 5, 0) -- Default fallback
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        playerPosition = player.Character.HumanoidRootPart.Position + Vector3.new(10, 0, 0) -- Spawn 10 studs away
    end
    
    local finalSpawnPosition = spawnPosition or playerPosition
    
    -- Spawn the boss
    BossController.spawnBoss(finalSpawnPosition)
end

-- Connect the boss spawn remote
local spawnBossRemote = ReplicatedStorage:FindFirstChild("SpawnBoss")
if spawnBossRemote then
    spawnBossRemote.OnServerEvent:Connect(handleBossSpawn)
    print("Boss spawn remote connected")
end

-- Initialize dialogue systems
NPCManager:Initialize()
DialogueHandler:SetNPCManager(NPCManager)
DialogueHandler:Initialize()
TraderHandler:Initialize()

-- Initialize enemy systems (from stayalive-1 integration)
local EnemySystemInitializer = require(script.EnemySystemInitializer)
local SpawnerSetup = require(script.SpawnerSetup)

-- Initialize spawners BEFORE starting enemy systems
SpawnerSetup.initializeAllSpawners()

_G.EnemySystemInitializer = EnemySystemInitializer
_G.SpawnerSetup = SpawnerSetup
print("Enemy systems integrated:", EnemySystemInitializer.initialized)

print("Server systems initialized!")