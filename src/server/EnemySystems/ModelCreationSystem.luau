-- ModelCreationSystem.lua
-- ECS System for creating and managing 3D models for spawned entities
-- Simplified version focused on enemy model creation

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Import custom ECS modules
local EntityManager = require(ReplicatedStorage.Shared.EntityManager)

-- Import Components from our custom ECS (find ModuleScript specifically to avoid folder conflict)
local Components = nil
for _, child in ipairs(ReplicatedStorage.Shared:GetChildren()) do
    if child.Name == "EnemyComponents" and child.ClassName == "ModuleScript" then
        Components = require(child)
        break
    end
end

if not Components then
    error("ModelCreationSystem: Could not find EnemyComponents ModuleScript")
end

local PrefabLibrary = require(ReplicatedStorage.Shared.PrefabLibrary)
local PhysicsService = game:GetService("PhysicsService")

local ModelCreationSystem = {}
ModelCreationSystem.name = "ModelCreationSystem"

-- Configuration
local CONFIG = {
	UPDATE_INTERVAL = 0.5, -- seconds between model updates
	MAX_MODELS_PER_FRAME = 10, -- limit model creation to maintain performance
	MODEL_PARENT_NAME = "GameEntities", -- workspace folder for all entity models
}

-- System state
local lastUpdate = 0
local modelParent = nil

-- Animation system removed - no longer needed

-- Initialize system
function ModelCreationSystem.initialize()
	print("🎨 ModelCreationSystem: Initializing...")
	
	-- Create model parent folder in workspace
	modelParent = Workspace:FindFirstChild(CONFIG.MODEL_PARENT_NAME)
	if not modelParent then
		modelParent = Instance.new("Folder")
		modelParent.Name = CONFIG.MODEL_PARENT_NAME
		modelParent.Parent = Workspace
	end
	
	-- Animation system removed - no longer needed
	
	print("✅ ModelCreationSystem: Initialized successfully")
	return true
end

-- Main update function
function ModelCreationSystem.update(deltaTime)
	local currentTime = tick()
	if currentTime - lastUpdate < CONFIG.UPDATE_INTERVAL then
		return
	end
	lastUpdate = currentTime
	
	local modelsProcessed = 0
	
	-- Find entities that need models created (enemies use Humanoid.Health directly)
	local enemyEntities = EntityManager.getEntitiesWithAll({"EnemyType"})
	
	for _, entityId in ipairs(enemyEntities) do
		if modelsProcessed >= CONFIG.MAX_MODELS_PER_FRAME then
			break
		end
		
		-- Skip if entity already has a model
		local existingModel = EntityManager.getComponent(entityId, "Model")
		if existingModel then
			-- Model already exists, skip
		else
			-- Create model for this entity
			ModelCreationSystem._createModelForEntity(entityId)
			modelsProcessed = modelsProcessed + 1
		end
	end
	
	-- REMOVED: _updateModelPositions() - Let Roblox MoveTo handle positioning!
	-- ModelCreationSystem should only CREATE models, not continuously move them
end

-- Create a 3D model for an entity
function ModelCreationSystem._createModelForEntity(entityId)
	local enemyType = EntityManager.getComponent(entityId, "EnemyType")
	
	if not enemyType then
		error("ModelCreationSystem: Entity " .. entityId .. " missing EnemyType component")
		return
	end
	
	-- Get the specific model name from EnemyDefinitions
	local modelName = ModelCreationSystem._getModelNameForEntity(entityId)
	if not modelName then
		error("ModelCreationSystem: Could not determine model name for entity " .. entityId)
		return
	end
	
	-- Create model from ReplicatedStorage.EnemyModels using specific model name
	local model = ModelCreationSystem._createModelFromReplicatedStorage(modelName)
	if not model then
		error("ModelCreationSystem: Required model '" .. modelName .. "' not found in ReplicatedStorage.EnemyModels")
		return
	end
	
	if model then
		-- Get spawn position from temporary component (set by EnemySpawnSystem) or use default
		local spawnPosComponent = EntityManager.getComponent(entityId, "SpawnPosition")
		local spawnPosition = spawnPosComponent and spawnPosComponent.value or Vector3.new(0, 0, 0)
		
		-- Remove the temporary spawn position component
		if spawnPosComponent then
			EntityManager.removeComponent(entityId, "SpawnPosition")
		end
		
		-- Find proper ground position using raycast
		local groundPosition = ModelCreationSystem._findGroundPosition(spawnPosition)
		
		if model.PrimaryPart then
			model.PrimaryPart.Position = groundPosition
			model.PrimaryPart.Anchored = false
			model.PrimaryPart.CanCollide = true -- HRP can now collide
		elseif model:FindFirstChildWhichIsA("BasePart") then
			local mainPart = model:FindFirstChildWhichIsA("BasePart")
			mainPart.Position = groundPosition
			mainPart.Anchored = false
			mainPart.CanCollide = true
		end
		
		-- Parent to workspace for visibility
		model.Parent = workspace
		
			-- Add Model component to entity
	EntityManager.addComponent(entityId, "Model", Components.create("Model", {
		model = model,
		part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart"),
		humanoid = model:FindFirstChildOfClass("Humanoid")
	}))

    -- Apply enemy-specific speed to humanoid
    ModelCreationSystem._applyEnemyStatsToHumanoid(entityId, model)

    -- Animation system removed - no longer needed

    -- Ragdoll system: connect Humanoid.Died event for all enemies
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        -- Tutorial: Set BreakJointsOnDeath and RequiresNeck to false for basic ragdoll
        humanoid.BreakJointsOnDeath = false
        humanoid.RequiresNeck = false
        humanoid.Died:Connect(function()
            onDeathOfTheEnemy(model)
        end)
    end

    -- Assign all parts to 'Enemies' collision group
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CollisionGroup = "Enemies"
        end
    end

    print("🎨 Created model '" .. modelName .. "' for", enemyType.enemyId, "entity", entityId, "at", groundPosition)
    
    -- Notify clients to set up animations for this enemy
    local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
    if RemoteEvents.SetupEnemyAnimations then
        RemoteEvents.SetupEnemyAnimations:FireAllClients(model, entityId)
        print("🎭 Notified clients to set up animations for enemy:", model.Name, "entity ID:", entityId)
    else
        print("⚠️ SetupEnemyAnimations RemoteEvent not found")
    end
	end
end



-- REMOVED: _updateModelPositions function - Position updates now handled by Roblox MoveTo only

-- Get the specific model name for an entity from EnemyDefinitions
function ModelCreationSystem._getModelNameForEntity(entityId)
	local enemyType = EntityManager.getComponent(entityId, "EnemyType")
	if not enemyType or not enemyType.enemyId then
		return nil
	end
	
	-- Get the enemy definition using the stored enemy ID
	local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
	local enemyDef = EnemyDefinitions:GetEnemy(enemyType.enemyId)
	
	if enemyDef and enemyDef.model then
		return enemyDef.model
	end
	
	return nil
end

-- Create model from ReplicatedStorage.EnemyModels using specific model name
function ModelCreationSystem._createModelFromReplicatedStorage(modelName)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	
	-- Check if EnemyModels folder exists
	local enemyModelsFolder = ReplicatedStorage:FindFirstChild("EnemyModels")
	if not enemyModelsFolder then
		error("❌ EnemyModels folder not found in ReplicatedStorage")
		return nil
	end
	
	-- Find the specific model in the folder
	local originalModel = enemyModelsFolder:FindFirstChild(modelName)
	if not originalModel then
		error("❌ Model '" .. modelName .. "' not found in EnemyModels folder")
		return nil
	end
	
	-- Clone the model
	local model = originalModel:Clone()
	
	print("✅ Using specific model '" .. modelName .. "' from EnemyModels folder")
	return model
end

-- Find proper ground position using raycast
function ModelCreationSystem._findGroundPosition(spawnPosition)
	local rayOrigin = spawnPosition + Vector3.new(0, 50, 0) -- Start 50 studs above
	local rayDirection = Vector3.new(0, -100, 0) -- Cast 100 studs down
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {} -- Don't filter anything for now
	
	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	
	if result then
		-- Position slightly above the ground (2 studs for humanoid height)
		return result.Position + Vector3.new(0, 2, 0)
	else
		-- Fallback: use original position with small offset
		return spawnPosition + Vector3.new(0, 2, 0)
	end
end

-- Apply enemy-specific stats to humanoid (speed, health, etc.)
function ModelCreationSystem._applyEnemyStatsToHumanoid(entityId, model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("⚠️ No humanoid found for entity " .. entityId .. ", skipping stat application")
		return
	end
	
	-- Apply speed from EnemyAI component
	local enemyAI = EntityManager.getComponent(entityId, "EnemyAI")
	if enemyAI and enemyAI.speed then
		humanoid.WalkSpeed = enemyAI.speed
		print("🏃 Set entity", entityId, "WalkSpeed to", enemyAI.speed)
	else
		humanoid.WalkSpeed = 16 -- Fallback to default
		warn("⚠️ No EnemyAI speed found for entity " .. entityId .. ", using default speed 16")
	end
	
	-- Apply health from EnemyDefinitions
	local enemyType = EntityManager.getComponent(entityId, "EnemyType")
	if enemyType and enemyType.enemyId then
		local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
		local enemyDef = EnemyDefinitions:GetEnemy(enemyType.enemyId)
		if enemyDef and enemyDef.health then
			humanoid.MaxHealth = enemyDef.health
			humanoid.Health = enemyDef.health
			print("❤️ Set entity", entityId, "health to", enemyDef.health .. "/" .. enemyDef.health)
		else
			-- Fallback to default health
			humanoid.MaxHealth = 100
			humanoid.Health = 100
			print("❤️ Set entity", entityId, "health to default 100/100")
		end
	else
		-- Fallback to default health
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		print("❤️ Set entity", entityId, "health to default 100/100")
	end
end

-- Update humanoid speed when EnemyAI component changes (for dynamic speed changes)
function ModelCreationSystem.updateHumanoidSpeed(entityId)
	local model = EntityManager.getComponent(entityId, "Model")
	local enemyAI = EntityManager.getComponent(entityId, "EnemyAI")
	
	if model and model.humanoid and enemyAI and enemyAI.speed then
		model.humanoid.WalkSpeed = enemyAI.speed
		print("🔄 Updated entity", entityId, "WalkSpeed to", enemyAI.speed)
		return true
	end
	
	return false
end

-- Clean up when entity is destroyed
function ModelCreationSystem.cleanup(entityId)
	-- Check if the enemy is dead (ragdolled) - if so, preserve the model
	local model = EntityManager.getComponent(entityId, "Model")
	if model and model.model and model.model.Parent then
		local humanoid = model.model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			-- Enemy is dead/ragdolled - preserve the model for ragdoll physics
			print("💀 Entity", entityId, "is dead/ragdolled - preserving model for ragdoll physics")
			-- Remove the model component but keep the actual model in workspace
			EntityManager.removeComponent(entityId, "Model")
		else
			-- Enemy is alive - destroy the model normally
			print("🧹 Entity", entityId, "is alive - destroying model")
			model.model:Destroy()
		end
	end
end

-- Animation system removed - no longer needed

-- Animation system removed - no longer needed

-- Add ragdoll logic for all enemies
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

-- Ensure collision groups are set up
local function setupCollisionGroups()
    -- Register groups if they don't exist (using new API)
    pcall(function() PhysicsService:RegisterCollisionGroup("Enemies") end)
    pcall(function() PhysicsService:RegisterCollisionGroup("Ragdolls") end)
    pcall(function() PhysicsService:RegisterCollisionGroup("Items") end)
    -- Enemies ignore ragdolls and items
    PhysicsService:CollisionGroupSetCollidable("Enemies", "Ragdolls", false)
    PhysicsService:CollisionGroupSetCollidable("Enemies", "Items", false)
    -- Ragdolls and items still collide with Default (ground, walls, etc.)
end
setupCollisionGroups()

function onDeathOfTheEnemy(enemy)
    local humanoid = enemy:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    -- Find the entity ID for this enemy model
    local entityId = nil
    for _, id in ipairs(EntityManager.getEntitiesWith("Model")) do
        local model = EntityManager.getComponent(id, "Model")
        if model and model.model == enemy then
            entityId = id
            break
        end
    end
    
    if entityId then
        print("💀 Enemy entity", entityId, "died - removing AI/combat components, preserving ragdoll")
        
        -- Remove all enemy functionality components while preserving ragdoll physics
        EntityManager.removeComponent(entityId, "EnemyAI")
        EntityManager.removeComponent(entityId, "Combat") 
        EntityManager.removeComponent(entityId, "EnemyType")
        EntityManager.removeComponent(entityId, "CombatStats")
        EntityManager.removeComponent(entityId, "EnemyChat")
        
        -- Remove the Model component but keep the actual model in workspace for ragdoll
        EntityManager.removeComponent(entityId, "Model")
        
        print("🧹 Removed all enemy functionality components for entity", entityId)
    end
    
    -- Hide health bar
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    -- Disable joint breaking to preserve ragdoll physics
    humanoid.BreakJointsOnDeath = false
    humanoid.RequiresNeck = false
    -- Disable state machine to allow falling over
    humanoid.EvaluateStateMachine = false
    -- Prevent standing up
    humanoid.PlatformStand = true
    
    -- Set CanCollide = true and assign to Ragdolls group for all limb parts
    for _, part in ipairs(enemy:GetChildren()) do
        if part:IsA("BasePart") and (part.Name:find("Arm") or part.Name:find("Leg") or part.Name == "Torso" or part.Name == "Head") then
            part.CanCollide = true
            part.CollisionGroup = "Ragdolls"
        end
    end
    
    -- Set HumanoidRootPart collision group to Default for consistency with player ragdolls
    local humanoidRootPart = enemy:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart then
        humanoidRootPart.CanCollide = false
        humanoidRootPart.CollisionGroup = "Default"
    end
    
    -- Replace Motor6Ds with BallSocketConstraints (except Neck)
    local torso = enemy:FindFirstChild("Torso")
    if torso then
        for _, joint in ipairs(torso:GetChildren()) do
            if joint:IsA("Motor6D") and joint.Name ~= "Neck" then
                createSocket(torso, joint.Part1, joint.C0, joint.C1)
                joint:Destroy()
            end
        end
    end
    
    -- Add a small delay to ensure ragdoll state is established
    task.wait(0.1)
    -- Tag as Draggable
    CollectionService:AddTag(enemy, "Draggable")
    
    -- Tag as Sacrifice for altar system
    CollectionService:AddTag(enemy, "Sacrifice")
    
    print("✅ Ragdoll physics preserved for enemy:", enemy.Name)
end

function createSocket(torso, part, c0, c1)
    local ballSocket = Instance.new("BallSocketConstraint")
    ballSocket.Name = part.Name .. "Socket"
    -- Attachments
    local attachment0 = createAttachment(torso, c0)
    local attachment1 = createAttachment(part, c1)
    ballSocket.Attachment0 = attachment0
    ballSocket.Attachment1 = attachment1
    -- Optionally configure limits here if desired
    ballSocket.Parent = torso
end

function createAttachment(part, cframeOffset)
    local attachment = Instance.new("Attachment")
    attachment.Name = part.Name .. "Attachment"
    attachment.CFrame = cframeOffset
    attachment.Parent = part
    return attachment
end

return ModelCreationSystem 