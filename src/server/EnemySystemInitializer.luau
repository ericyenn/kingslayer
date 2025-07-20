-- EnemySystemInitializer.luau
-- Initialize enemy systems for godslayer while preserving existing functionality
-- This mirrors the stayalive-1 initialization but integrates with godslayer

print("🎮 Enemy System Initializer Starting...")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Import enemy ECS modules (with error handling)
local EntityManager
local EnemySystemManager  
local EnemyComponents

-- Check if modules exist first and list what's available
print("🔍 Checking ReplicatedStorage.Shared contents:")
for _, child in ipairs(ReplicatedStorage.Shared:GetChildren()) do
    print("   - " .. child.Name .. " (" .. child.ClassName .. ")")
end

if ReplicatedStorage.Shared:FindFirstChild("EntityManager") then
    local success, result = pcall(function()
        return require(ReplicatedStorage.Shared.EntityManager)
    end)
    if success then
        EntityManager = result
        print("✅ EntityManager loaded successfully")
    else
        error("❌ Failed to load EntityManager: " .. tostring(result))
    end
else
    error("❌ EntityManager module not found in ReplicatedStorage.Shared")
end

if ReplicatedStorage.Shared:FindFirstChild("EnemySystemManager") then
    local success, result = pcall(function()
        return require(ReplicatedStorage.Shared.EnemySystemManager)
    end)
    if success then
        EnemySystemManager = result
        print("✅ EnemySystemManager loaded successfully")
    else
        error("❌ Failed to load EnemySystemManager: " .. tostring(result))
    end
else
    error("❌ EnemySystemManager module not found in ReplicatedStorage.Shared")
end

-- Find EnemyComponents ModuleScript specifically (avoid folder conflict)
local enemyComponentsModule = nil
for _, child in ipairs(ReplicatedStorage.Shared:GetChildren()) do
    if child.Name == "EnemyComponents" and child.ClassName == "ModuleScript" then
        enemyComponentsModule = child
        break
    end
end

if enemyComponentsModule then
    print("🔍 Found EnemyComponents ModuleScript:", enemyComponentsModule.Name)
    local success, result = pcall(function()
        return require(enemyComponentsModule)
    end)
    if success then
        EnemyComponents = result
        print("✅ EnemyComponents loaded successfully")
    else
        error("❌ Failed to load EnemyComponents: " .. tostring(result))
    end
else
    error("❌ EnemyComponents ModuleScript not found in ReplicatedStorage.Shared")
end

-- Import enemy systems (with error handling)
local EnemySystems = script.Parent.EnemySystems
local EnemySpawnSystem, EnemyAISystem, EnemyCombatSystem, EnemyModelSystem

local success, result = pcall(function()
    return require(EnemySystems.EnemySpawnSystem)
end)
if success then
    EnemySpawnSystem = result
    print("✅ EnemySpawnSystem loaded successfully")
else
    error("❌ Failed to load EnemySpawnSystem: " .. tostring(result))
end

local success, result = pcall(function()
    return require(EnemySystems.AISystem)
end)
if success then
    EnemyAISystem = result
    print("✅ EnemyAISystem loaded successfully")
else
    error("❌ Failed to load EnemyAISystem: " .. tostring(result))
end

local success, result = pcall(function()
    return require(EnemySystems.CombatSystem)
end)
if success then
    EnemyCombatSystem = result
    print("✅ EnemyCombatSystem loaded successfully")
else
    error("❌ Failed to load EnemyCombatSystem: " .. tostring(result))
end

local success, result = pcall(function()
    return require(EnemySystems.ModelCreationSystem)
end)
if success then
    EnemyModelSystem = result
    print("✅ EnemyModelSystem loaded successfully")
else
    error("❌ Failed to load EnemyModelSystem: " .. tostring(result))
end

-- Test enemy ECS core
print("📦 Enemy ECS loaded: EntityManager, EnemySystemManager, EnemyComponents")

-- Only register systems if all modules loaded successfully
if EntityManager and EnemySystemManager and EnemyComponents and 
   EnemySpawnSystem and EnemyAISystem and EnemyCombatSystem and EnemyModelSystem then
   
    -- Register enemy systems
    EnemySystemManager.registerSystem(EnemySpawnSystem)
    EnemySystemManager.registerSystem(EnemyAISystem)
    EnemySystemManager.registerSystem(EnemyCombatSystem)
    EnemySystemManager.registerSystem(EnemyModelSystem)

    -- Start enemy system game loop
    EnemySystemManager.startGameLoop()
    
    print("✅ All enemy systems registered and started")
else
    warn("❌ Some enemy systems failed to load - enemy system disabled")
    return {initialized = false, error = "Failed to load enemy modules"}
end

print("✅ Enemy System initialization complete")
print("🔧 Enemy ECS Status: Custom Enemy ECS Active")

-- NOTE: Spawner creation is now handled by SpawnerSetup.luau
-- This allows for visual placement of spawners in Roblox Studio using tagged parts
-- Fallback spawners will be created automatically if no tagged parts are found
print("🎯 Spawner creation delegated to SpawnerSetup system")

-- Player management for enemy spawning
Players.PlayerAdded:Connect(function(player)
    print("🎯 Player joined (enemy system):", player.Name)
    -- Enemy spawners already exist, enemies will spawn for any player to battle
end)

-- Return module data
return {
    initialized = true,
    systems = {
        EnemySpawnSystem,
        EnemyAISystem,
        EnemyCombatSystem,
        EnemyModelSystem
    }
} 