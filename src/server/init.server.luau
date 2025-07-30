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
local TimeManager = require(ServerSystems.TimeManager)
local SanitySystem = require(ServerSystems.SanitySystem)
local PlayerRagdollSystem = require(ServerSystems.PlayerRagdollSystem)
local PlayerEffectsSystem = require(ServerSystems.PlayerEffectsSystem)
local ReviveSystem = require(ServerSystems.ReviveSystem)

-- Import altar systems
local AltarSystem = require(ServerSystems.AltarSystem)
local SacrificeValidator = require(ServerSystems.SacrificeValidator)
local RewardProcessor = require(ServerSystems.RewardProcessor)

-- Import dialogue systems
local NPCManager = require(script.NPCManager)
local DialogueHandler = require(script.DialogueHandler)
local TraderHandler = require(script.TraderHandler)

-- Import boss system
local BossController = require(script.BossSystem.BossController)

print("Server starting...")

-- Initialize server systems
-- ItemSpawnSystem:Initialize()
DragServerSystem:Initialize()
InventoryServerSystem:Initialize()
ArmorServerSystem:Initialize()
DamageSystem:Initialize()
TimeManager.Init()
SanitySystem:Initialize()
PlayerRagdollSystem:Initialize()
PlayerEffectsSystem:Initialize()
ReviveSystem:Initialize()

-- Initialize altar systems
AltarSystem:Initialize()

-- Set up ReviveSystem reference in PlayerRagdollSystem
PlayerRagdollSystem:SetReviveSystem(ReviveSystem)

-- Set up prayer handling
local function handlePrayerRequest(player, figure)
    print("Player", player.Name, "requested prayer to figure:", figure:GetFullName())
    
    local success, message = AltarSystem:HandlePrayer(player, figure)
    if success then
        print("Prayer successful for player:", player.Name)
    else
        print("Prayer failed for player:", player.Name, "-", message)
    end
end

-- Connect the prayer request remote
local prayerRequestRemote = ReplicatedStorage:FindFirstChild("PrayerRequest")
if prayerRequestRemote then
    prayerRequestRemote.OnServerEvent:Connect(handlePrayerRequest)
    print("Prayer request remote connected")
end

-- Set up global references for inter-system communication
_G.ItemSpawnSystem = ItemSpawnSystem
_G.InventoryServerSystem = InventoryServerSystem
_G.DamageSystem = DamageSystem
_G.PlayerEffectsSystem = PlayerEffectsSystem

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

-- Set up respawn RemoteEvent
local RequestRespawn = ReplicatedStorage:FindFirstChild("RequestRespawn")
if not RequestRespawn then
    RequestRespawn = Instance.new("RemoteEvent")
    RequestRespawn.Name = "RequestRespawn"
    RequestRespawn.Parent = ReplicatedStorage
end
RequestRespawn.OnServerEvent:Connect(function(player)
    player:LoadCharacter()
end)



-- Initialize dialogue systems
NPCManager:Initialize()
DialogueHandler:SetNPCManager(NPCManager)
DialogueHandler:Initialize()
TraderHandler:Initialize()

-- Initialize enemy systems (from stayalive-1 integration)
local EnemySystemInitializer = require(script.EnemySystemInitializer)
local SpawnerSetup = require(script.SpawnerSetup)

-- Initialize projectile system
local ProjectileManager = require(script.ProjectileManager)
ProjectileManager.initialize()

-- Initialize spawners BEFORE starting enemy systems
SpawnerSetup.initializeAllSpawners()

-- Initialize item spawners (pool-based)
local ItemPoolSpawnSystem = require(ServerSystems.ItemSpawnSystem)
ItemPoolSpawnSystem.spawnAllItems()

_G.EnemySystemInitializer = EnemySystemInitializer
_G.SpawnerSetup = SpawnerSetup
print("Enemy systems integrated:", EnemySystemInitializer.initialized)

print("Server systems initialized!")