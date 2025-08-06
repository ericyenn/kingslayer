-- EnemyManager.luau
-- Client-side enemy management system
-- Handles local enemy creation and movement using attributes

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- Import ECS modules
local EntityManager = require(ReplicatedStorage.Shared.EntityManager)

-- Import Components
local Components = nil
for _, child in ipairs(ReplicatedStorage.Shared:GetChildren()) do
    if child.Name == "EnemyComponents" and child.ClassName == "ModuleScript" then
        Components = require(child)
        break
    end
end

if not Components then
    error("EnemyManager: Could not find EnemyComponents ModuleScript")
end

local EnemyManager = {}
EnemyManager.name = "EnemyManager"

-- Configuration
local CONFIG = {
    MAX_ENEMIES = 100,
    ATTACK_CHECK_INTERVAL = 0.1, -- Check for attacks every 0.1 seconds
}

-- Local state
local localEnemies = {}
local modelParent = nil
local attackCheckConnections = {} -- Store attack check connections per enemy

-- Initialize system
function EnemyManager.Initialize()
    print("🎯 EnemyManager: Initializing client-side enemy management...")
    
    -- Create model parent folder
    modelParent = workspace:FindFirstChild("ClientEnemies")
    if not modelParent then
        modelParent = Instance.new("Folder")
        modelParent.Name = "ClientEnemies"
        modelParent.Parent = workspace
    end
    
    -- Set up enemy folder monitoring
    EnemyManager._setupEnemyFolderMonitoring()
    
    print("✅ EnemyManager: Initialized successfully")
    return true
end

-- Set up monitoring for enemy folders
function EnemyManager._setupEnemyFolderMonitoring()
    local enemiesFolder = workspace:WaitForChild("Enemies")
    
    -- Monitor existing enemy folders
    for _, folder in ipairs(enemiesFolder:GetChildren()) do
        EnemyManager._setupEnemyFolder(folder)
    end
    
    -- Monitor for new enemy folders
    enemiesFolder.ChildAdded:Connect(function(folder)
        if folder:IsA("Folder") then
            EnemyManager._setupEnemyFolder(folder)
        end
    end)
end

-- Set up individual enemy folder
function EnemyManager._setupEnemyFolder(folder)
    local entityId = tonumber(folder.Name)
    if not entityId then
        return
    end
    
    -- Create local entity
    local newEntityId = EntityManager.createEntity()
    
    -- Get enemy type from attribute
    local enemyType = folder:GetAttribute("EnemyType")
    if not enemyType then
        warn("EnemyManager: No EnemyType attribute found for folder", folder.Name)
        return
    end
    
    -- Get enemy definition
    local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
    local enemyDef = EnemyDefinitions:GetEnemy(enemyType)
    if not enemyDef then
        warn("EnemyManager: No enemy definition found for", enemyType)
        return
    end
    
    -- Add components
    EntityManager.addComponent(newEntityId, "EnemyType", Components.create("EnemyType", {
        enemyType = enemyDef.enemyType,
        enemyId = enemyType,
        config = enemyDef.customConfig or {}
    }))
    
    EntityManager.addComponent(newEntityId, "EnemyAI", Components.create("EnemyAI", {
        state = "idle",
        detectionRange = enemyDef.customConfig and enemyDef.customConfig.detectionRange or 30,
        speed = enemyDef.customConfig and enemyDef.customConfig.moveSpeed or 16,
        homePosition = folder:GetAttribute("Position")
    }))
    
    EntityManager.addComponent(newEntityId, "Combat", Components.create("Combat", {
        damage = enemyDef.customConfig and enemyDef.customConfig.damage or 10,
        attackCooldown = enemyDef.customConfig and enemyDef.customConfig.attackSpeed and (1 / enemyDef.customConfig.attackSpeed) or 1
    }))
    
    EntityManager.addComponent(newEntityId, "CombatStats", Components.create("CombatStats", {
        baseAttack = enemyDef.customConfig and enemyDef.customConfig.damage or 10,
        baseDefense = 5,
        critChance = 0.1,
        critMultiplier = 1.5,
        dodgeChance = 0.05
    }))
    
    -- Create model
    local model = EnemyManager._createEnemyModel(enemyType, folder:GetAttribute("Position"))
    if model then
        EntityManager.addComponent(newEntityId, "Model", Components.create("Model", {
            model = model,
            part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart"),
            humanoid = model:FindFirstChildOfClass("Humanoid")
        }))
        
        -- Store local enemy data
        localEnemies[entityId] = {
            localEntityId = newEntityId,
            model = model,
            folder = folder,
            spawnTime = tick(),
            lastAttackTime = 0
        }
        
        -- Set up animations for the enemy model
        local EnemyAnimationSystem = require(script.Parent.Systems.EnemyAnimationSystem)
        EnemyAnimationSystem.SetupEnemyAnimations(model, entityId)
        
        -- Set up attribute change monitoring
        EnemyManager._setupAttributeMonitoring(folder, entityId)
        
        -- Set up attack checking for melee enemies
        if enemyDef.enemyType == "melee" then
            EnemyManager._setupAttackChecking(entityId, enemyDef)
        end
        
        print("🎯 EnemyManager: Created local enemy", entityId, "at", folder:GetAttribute("Position"))
    end
end

-- Set up attack checking for melee enemies
function EnemyManager._setupAttackChecking(entityId, enemyDef)
    local enemyData = localEnemies[entityId]
    if not enemyData or not enemyData.model then
        return
    end
    
    local model = enemyData.model
    local raycastDistance = enemyDef.customConfig and enemyDef.customConfig.raycastDistance or 3.0
    
    -- Create attack check connection with less frequent checks
    local connection = RunService.Heartbeat:Connect(function()
        -- Only check every 10th frame (approximately 6 times per second)
        if tick() % 0.1 < 0.016 then -- Check roughly 6 times per second
            EnemyManager._checkForAttack(entityId, model, raycastDistance)
        end
    end)
    
    attackCheckConnections[entityId] = connection
end

-- Check if enemy should attack
function EnemyManager._checkForAttack(entityId, model, raycastDistance)
    local enemyData = localEnemies[entityId]
    if not enemyData then
        return
    end
    
    -- Check if enemy is in chase state
    local folder = enemyData.folder
    if not folder then
        return
    end
    
    local aiState = folder:GetAttribute("AIState")
    if aiState ~= "chase" and aiState ~= "attack_chase" then
        return
    end
    
    -- Get enemy definition for attack cooldown
    local enemyType = folder:GetAttribute("EnemyType")
    local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
    local enemyDef = EnemyDefinitions:GetEnemy(enemyType)
    local attackCooldown = 1.0 -- Default 1 second cooldown
    
    if enemyDef and enemyDef.customConfig and enemyDef.customConfig.attackCooldown then
        attackCooldown = enemyDef.customConfig.attackCooldown
    end
    
    -- Check client-side cooldown to prevent spam
    local currentTime = tick()
    if currentTime - enemyData.lastAttackTime < attackCooldown then
        return
    end
    
    -- Get enemy position
    local enemyPosition = folder:GetAttribute("Position")
    if not enemyPosition then
        return
    end
    
    -- Find closest player
    local closestPlayer = nil
    local closestDistance = math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local playerPosition = player.Character.HumanoidRootPart.Position
            local distance = (enemyPosition - playerPosition).Magnitude
            
            if distance < closestDistance and distance <= raycastDistance then
                closestPlayer = player
                closestDistance = distance
            end
        end
    end
    
    if not closestPlayer then
        return
    end
    
    -- Perform spherecast from enemy to player
    local spherecastResult = EnemyManager._performAttackSpherecast(enemyPosition, closestPlayer.Character.HumanoidRootPart.Position, model)
    
    if EnemyManager._isSpherecastHitPlayer(spherecastResult, closestPlayer) then
        -- Spherecast hit the player - perform attack
        EnemyManager._performAttack(entityId, closestPlayer, raycastDistance)
    end
end

-- Perform spherecast from enemy to target (more reliable than raycast for close combat)
function EnemyManager._performAttackSpherecast(enemyPosition, targetPosition, model)
    local direction = (targetPosition - enemyPosition).Unit
    local distance = (targetPosition - enemyPosition).Magnitude
    
    -- Create spherecast params (sphere sweep)
    local spherecastParams = RaycastParams.new()
    spherecastParams.FilterType = Enum.RaycastFilterType.Exclude
    spherecastParams.FilterDescendantsInstances = {model}
    
    -- Use a small sphere radius for detection
    local sphereRadius = 1.0 -- 1 stud radius sphere
    
    -- Perform spherecast (sphere sweep)
    local spherecastResult = workspace:Spherecast(enemyPosition, sphereRadius, direction * distance, spherecastParams)
    return spherecastResult
end

-- Check if spherecast hit the player
function EnemyManager._isSpherecastHitPlayer(spherecastResult, targetPlayer)
    if not spherecastResult then
        return false
    end
    
    -- Check if the hit instance is part of the target player's character
    local hitInstance = spherecastResult.Instance
    if not hitInstance then
        return false
    end
    
    -- Check if the hit instance is part of the target player's character
    local character = targetPlayer.Character
    if not character then
        return false
    end
    
    -- Check if the hit instance is a descendant of the player's character
    local isPartOfCharacter = hitInstance:IsDescendantOf(character)
    return isPartOfCharacter
end

-- Perform attack (client-side animation + server validation)
function EnemyManager._performAttack(entityId, targetPlayer, raycastDistance)
    local enemyData = localEnemies[entityId]
    if not enemyData then
        return
    end
    
    -- Check client-side cooldown to prevent spam
    local currentTime = tick()
    if currentTime - enemyData.lastAttackTime < 0.1 then -- 100ms client-side cooldown
        return
    end
    
    -- Update client-side cooldown
    enemyData.lastAttackTime = currentTime
    
    -- Play attack animation immediately
    local EnemyAnimationSystem = require(script.Parent.Systems.EnemyAnimationSystem)
    EnemyAnimationSystem.UpdateEnemyAIState(enemyData.model, entityId, "attack")
    
    -- Send attack request to server
    local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
    if RemoteEvents.EnemyAttackRequest then
        RemoteEvents.EnemyAttackRequest:FireServer(entityId, targetPlayer, raycastDistance, currentTime)
        print("🎯 Enemy", entityId, "attacking", targetPlayer.Name, "with raycast distance", raycastDistance)
    end
end

-- Set up attribute monitoring for an enemy folder
function EnemyManager._setupAttributeMonitoring(folder, entityId)
    local enemyData = localEnemies[entityId]
    if not enemyData or not enemyData.model then
        return
    end
    
    local model = enemyData.model
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end
    
    -- Set initial position
    local initialPosition = folder:GetAttribute("Position")
    if initialPosition then
        model:SetPrimaryPartCFrame(CFrame.new(initialPosition))
    end
    
    -- Set initial health
    local initialHealth = folder:GetAttribute("Health")
    local initialMaxHealth = folder:GetAttribute("MaxHealth") or 100
    if initialHealth and humanoid then
        humanoid.Health = initialHealth
        humanoid.MaxHealth = initialMaxHealth
        print("💚 EnemyManager: Set initial health for enemy", entityId, "to", initialHealth .. "/" .. initialMaxHealth)
    end
    
    -- Handle MoveToFinished events
    humanoid.MoveToFinished:Connect(function(reached)
        if reached == false then
            -- Movement failed, reposition to target
            local currentPosition = folder:GetAttribute("Position")
            if currentPosition then
                model:SetPrimaryPartCFrame(CFrame.new(currentPosition))
                print("🎯 EnemyManager: Movement failed for enemy", entityId, ", repositioned to", currentPosition)
            end
        end
    end)
    
    -- Monitor position changes
    folder:GetAttributeChangedSignal("Position"):Connect(function()
        local newPosition = folder:GetAttribute("Position")
        if newPosition then
            humanoid:MoveTo(newPosition)
            print("🎯 EnemyManager: Updated position for enemy", entityId, "to", newPosition)
        end
    end)
    
    -- Monitor AI state changes for animations
    folder:GetAttributeChangedSignal("AIState"):Connect(function()
        local newState = folder:GetAttribute("AIState")
        if newState then
            -- Update ECS state
            EnemyManager._updateEnemyState(entityId, newState)
            
            -- Update animations directly
            local EnemyAnimationSystem = require(script.Parent.Systems.EnemyAnimationSystem)
            EnemyAnimationSystem.UpdateEnemyAIState(model, entityId, newState)
            print("🎭 EnemyManager: Updated animation state for enemy", entityId, "to", newState)
        end
    end)
    
    -- Monitor death state
    folder:GetAttributeChangedSignal("Dead"):Connect(function()
        local isDead = folder:GetAttribute("Dead")
        if isDead == true then
            print("💀 EnemyManager: Enemy", entityId, "has died")
            -- Stop attack checking for dead enemies
            if attackCheckConnections[entityId] then
                attackCheckConnections[entityId]:Disconnect()
                attackCheckConnections[entityId] = nil
                print("🎯 EnemyManager: Stopped attack checking for dead enemy", entityId)
            end
            
            -- Destroy the original enemy model
            if enemyData.model then
                enemyData.model:Destroy()
                print("💀 EnemyManager: Destroyed original enemy model", entityId)
            end
            
            -- Change collision group to prevent damage
            if enemyData.model then
                for _, part in pairs(enemyData.model:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CollisionGroup = "Dead"
                        part.CanCollide = false -- Disable collision entirely
                    end
                end
                print("💀 EnemyManager: Disabled collision for dead enemy", entityId)
            end
            
            -- The server will handle ragdoll logic
        end
    end)
end

-- Update enemy state
function EnemyManager._updateEnemyState(entityId, newState)
    local enemyData = localEnemies[entityId]
    if not enemyData then
        return
    end
    
    local localEntityId = enemyData.localEntityId
    local enemyAI = EntityManager.getComponent(localEntityId, "EnemyAI")
    if enemyAI then
        enemyAI.state = newState
        enemyAI.stateStartTime = tick()
        EntityManager.addComponent(localEntityId, "EnemyAI", enemyAI)
        print("🎯 EnemyManager: Updated state for enemy", entityId, "to", newState)
    end
end

-- Create enemy model from ReplicatedStorage
function EnemyManager._createEnemyModel(enemyId, position)
    -- Get model name from enemy definition
    local modelName = EnemyManager._getModelNameForEnemy(enemyId)
    if not modelName then
        warn("EnemyManager: Could not determine model for enemy", enemyId)
        return nil
    end
    
    -- Get model from ReplicatedStorage.EnemyModels
    local enemyModels = ReplicatedStorage:FindFirstChild("EnemyModels")
    if not enemyModels then
        warn("EnemyManager: EnemyModels folder not found in ReplicatedStorage")
        return nil
    end
    
    local model = enemyModels:FindFirstChild(modelName)
    if not model then
        warn("EnemyManager: Model not found in ReplicatedStorage.EnemyModels:", modelName)
        return nil
    end
    
    -- Clone the model
    local enemyModel = model:Clone()
    
    -- Position the model
    if enemyModel.PrimaryPart then
        enemyModel.PrimaryPart.Position = position
        enemyModel.PrimaryPart.Anchored = false
        enemyModel.PrimaryPart.CanCollide = true
    elseif enemyModel:FindFirstChildWhichIsA("BasePart") then
        local mainPart = enemyModel:FindFirstChildWhichIsA("BasePart")
        mainPart.Position = position
        mainPart.Anchored = false
        mainPart.CanCollide = true
    end
    
    -- Parent to workspace
    enemyModel.Parent = modelParent
    
    -- Set collision group
    for _, part in ipairs(enemyModel:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CollisionGroup = "Enemies"
        end
    end
    
    -- Add tag
    CollectionService:AddTag(enemyModel, "Enemies")
    
    return enemyModel
end

-- Get model name for enemy
function EnemyManager._getModelNameForEnemy(enemyId)
    -- This should match the server's logic
    local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
    local enemyDef = EnemyDefinitions:GetEnemy(enemyId)
    return enemyDef and enemyDef.model or "Jason"
end

-- Get local enemy data
function EnemyManager.getLocalEnemy(entityId)
    return localEnemies[entityId]
end

-- Get all local enemies
function EnemyManager.getAllLocalEnemies()
    return localEnemies
end

-- Cleanup on shutdown
function EnemyManager.cleanup()
    -- Clean up attack check connections
    for entityId, connection in pairs(attackCheckConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    attackCheckConnections = {}
    
    for entityId, enemyData in pairs(localEnemies) do
        if enemyData.model and enemyData.model.Parent then
            enemyData.model:Destroy()
        end
    end
    
    localEnemies = {}
end

return EnemyManager 