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

-- Animation state storage by model (like princess system)
local enemyAnimations = {} -- {[model] = {animState}}

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
	
	-- Clear animation state on restart
	enemyAnimations = {}
	
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
	
	-- Find entities that need models created (removed Position dependency)
	local enemyEntities = EntityManager.getEntitiesWithAll({"EnemyType", "Health"})
	
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
			model.PrimaryPart.CanCollide = false -- HRP shouldn't collide
		elseif model:FindFirstChildWhichIsA("BasePart") then
			local mainPart = model:FindFirstChildWhichIsA("BasePart")
			mainPart.Position = groundPosition
			mainPart.Anchored = false
			mainPart.CanCollide = false
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

    -- Load animations for the enemy
    ModelCreationSystem._loadAnimationsForEntity(entityId, model)

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

    print("🎨 Created model '" .. modelName .. "' for", enemyType.enemyId, "entity", entityId, "at", groundPosition)
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
	
	-- Apply health from Health component
	local health = EntityManager.getComponent(entityId, "Health")
	if health then
		humanoid.MaxHealth = health.max
		humanoid.Health = health.current
		print("❤️ Set entity", entityId, "health to", health.current .. "/" .. health.max)
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
	-- Clean up animation state by finding the model
	local model = EntityManager.getComponent(entityId, "Model")
	if model and model.model and enemyAnimations[model.model] then
		enemyAnimations[model.model] = nil
		print("🧹 Cleaned up animation state for entity", entityId)
	end
	
	-- Clean up model
	if model and model.model and model.model.Parent then
		model.model:Destroy()
	end
end

-- Load animations for an entity's model
function ModelCreationSystem._loadAnimationsForEntity(entityId, model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("⚠️ No humanoid found for entity " .. entityId .. ", skipping animations")
		return
	end
	
	-- Animation IDs
	local ANIMATION_IDS = {
		idle = "rbxassetid://90478240073535",
		walk = "rbxassetid://180426354",  -- Default R6 walk animation
		attack = "rbxassetid://136814345857964"
	}
	
	local animationSet = Components.create("AnimationSet", {})
	
	-- Load idle animation
	if ANIMATION_IDS.idle then
		local idleAnimation = Instance.new("Animation")
		idleAnimation.AnimationId = ANIMATION_IDS.idle
		animationSet.idle = humanoid:LoadAnimation(idleAnimation)
	end
	
	-- Load walk animation
	if ANIMATION_IDS.walk then
		local walkAnimation = Instance.new("Animation")
		walkAnimation.AnimationId = ANIMATION_IDS.walk
		animationSet.walk = humanoid:LoadAnimation(walkAnimation)
	end
	
	-- Load attack animation
	if ANIMATION_IDS.attack then
		local attackAnimation = Instance.new("Animation")
		attackAnimation.AnimationId = ANIMATION_IDS.attack
		animationSet.attack = humanoid:LoadAnimation(attackAnimation)
	end
	
	-- Set up movement detection for real-time animation sync
	ModelCreationSystem._setupMovementDetection(entityId, humanoid, animationSet)
	
	-- Add AnimationSet component to entity
	EntityManager.addComponent(entityId, "AnimationSet", animationSet)
	
	print("🎬 Loaded animations for entity", entityId)
end

-- Set up movement detection for real-time animation synchronization
function ModelCreationSystem._setupMovementDetection(entityId, humanoid, animationSet)
	local model = EntityManager.getComponent(entityId, "Model")
	if not model or not model.model then
		return
	end
	
	-- Store animation state by model (like princess system)
	local animState = {
		isMoving = false,
		entityId = entityId
	}
	enemyAnimations[model.model] = animState
	
	-- Simple movement detection exactly like princess
	humanoid.Running:Connect(function(speed)
		if speed > 0.1 and not animState.isMoving then
			-- Started moving - play walk animation
			animState.isMoving = true
			ModelCreationSystem._playEnemyAnimation(model.model, "walk")
		elseif speed <= 0.1 and animState.isMoving then
			-- Stopped moving - DON'T play idle, let AI system handle it
			animState.isMoving = false
			-- Just stop the current animation if it's movement-driven
			local animationSet = EntityManager.getComponent(animState.entityId, "AnimationSet")
			if animationSet and animationSet.animationSource == "movement" and animationSet.current then
				animationSet.current:Stop()
				animationSet.current = nil
				animationSet.animationSource = "state"
				EntityManager.addComponent(animState.entityId, "AnimationSet", animationSet)
				print("🎭 Entity", animState.entityId, "stopped movement animation - AI will take over")
			end
		end
	end)
	
	print("🎯 Set up movement detection for entity", entityId, "- Princess-style system")
end

-- Play animation for an enemy (like princess system)
function ModelCreationSystem._playEnemyAnimation(model, animName)
	local animState = enemyAnimations[model]
	if not animState then
		return
	end
	
	-- Get current animation set from entity
	local animationSet = EntityManager.getComponent(animState.entityId, "AnimationSet")
	if not animationSet then
		return
	end
	
	-- Stop current animation
	if animationSet.current then
		animationSet.current:Stop()
	end
	
	-- Play new animation
	local newAnimation = animationSet[animName]
	if newAnimation then
		newAnimation:Play()
		animationSet.current = newAnimation
		animationSet.animationSource = "movement"
		
		-- Update component
		EntityManager.addComponent(animState.entityId, "AnimationSet", animationSet)
		
		print("🎭 Entity", animState.entityId, "playing", animName, "animation (movement-driven)")
	end
end

-- Add ragdoll logic for all enemies
local CollectionService = game:GetService("CollectionService")

function onDeathOfTheEnemy(enemy)
    local humanoid = enemy:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    -- Hide health bar
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    -- Prevent standing up
    humanoid.PlatformStand = true
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
    -- Tag as Draggable
    CollectionService:AddTag(enemy, "Draggable")
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