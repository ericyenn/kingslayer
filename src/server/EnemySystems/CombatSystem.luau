--[[
CombatSystem.lua

Core Combat System for processing combat interactions between entities.
Handles damage calculation, application, and basic visual effects.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

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
    error("CombatSystem: Could not find EnemyComponents ModuleScript")
end

local CombatSystem = {}
CombatSystem.name = "CombatSystem"

-- Configuration
local CONFIG = {
	UPDATE_INTERVAL = 1/8, -- 8 FPS updates (much slower for performance)
	MAX_COMBATS_PER_FRAME = 8,
	
	-- Combat settings
	ATTACK_COOLDOWN = 1.5, -- Seconds between attacks
	INVINCIBILITY_TIME = 0.3, -- Invincibility after taking damage
	MAX_COMBAT_DISTANCE = 8, -- Max distance for melee attacks
	
	-- Visual effects
	DAMAGE_TEXT_LIFETIME = 2,
	HIT_EFFECT_DURATION = 0.5
}

-- System state
local lastUpdate = 0
local invincibilityTimers = {} -- [entityId] = endTime

-- Initialize system
function CombatSystem.initialize()
	print("⚔️ CombatSystem initializing...")
	
	lastUpdate = 0
	invincibilityTimers = {}
	
	print("✅ CombatSystem ready")
	return true
end

-- Main update function
function CombatSystem.update(deltaTime)
	local currentTime = tick()
	if currentTime - lastUpdate < CONFIG.UPDATE_INTERVAL then
		return
	end
	lastUpdate = currentTime
	
	-- Clean up expired invincibility timers
	for entityId, endTime in pairs(invincibilityTimers) do
		if currentTime >= endTime then
			invincibilityTimers[entityId] = nil
		end
	end
	
	local combatsProcessed = 0
	
	-- Get all entities with Combat and Model components (removed Position dependency)
	-- Note: Melee enemies are skipped in _processCombat to avoid duplicate damage
	local combatEntities = EntityManager.getEntitiesWithAll({"Combat", "Model"})
	
	for _, entityId in ipairs(combatEntities) do
		if combatsProcessed >= CONFIG.MAX_COMBATS_PER_FRAME then
			break
		end
		
		local combat = EntityManager.getComponent(entityId, "Combat")
		local model = EntityManager.getComponent(entityId, "Model")
		
		if combat and model and model.part then
			CombatSystem._processCombat(entityId, combat, model, currentTime)
			combatsProcessed = combatsProcessed + 1
		end
	end
	
	-- Process health regeneration (simple)
	CombatSystem._processHealthRegen(currentTime)
	
	-- Perform maintenance every 60 seconds
	if currentTime % 60 < CONFIG.UPDATE_INTERVAL then
		CombatSystem.performMaintenance()
	end
	
	-- Remove dead entities
	CombatSystem._removeDeadEntities()
end

-- Process a single combat interaction
function CombatSystem._processCombat(attackerEntityId, combat, attackerModel, currentTime)
	-- Skip melee enemies - they are handled by MeleeChaseHandler
	local enemyType = EntityManager.getComponent(attackerEntityId, "EnemyType")
	if enemyType and enemyType.enemyType == "melee" then
		-- Melee enemies are handled by MeleeChaseHandler, so we skip them here
		-- to avoid duplicate damage application
		return
	end
	
	-- Check attack cooldown (use per-enemy cooldown, fallback to global config)
	local attackCooldown = combat.attackCooldown or CONFIG.ATTACK_COOLDOWN
	if combat.lastAttackTime and (currentTime - combat.lastAttackTime) < attackCooldown then
		-- Debug: Show when attacks are blocked by cooldown
		local timeRemaining = attackCooldown - (currentTime - combat.lastAttackTime)
		if math.random() < 0.05 then -- Only print 5% of the time to avoid spam
			print("⏰ Entity", attackerEntityId, "attack on cooldown -", string.format("%.1f", timeRemaining), "seconds remaining")
		end
		return
	end
	
	print("🗡️ Entity", attackerEntityId, "ATTEMPTING ATTACK on target", combat.target)
	
	-- Get target entity
	local target = combat.target
	if not target then
		-- No target, remove combat component
		EntityManager.removeComponent(attackerEntityId, "Combat")
		return
	end
	
	-- Check if target is a player (has Character) or an entity (has Health component)
	local targetHealth = EntityManager.getComponent(target, "Health")
	local targetModel = EntityManager.getComponent(target, "Model")
	local isPlayer = false
	local playerHealth = nil
	
	-- Handle player targets - target is always a Character model from AISystem
	if not targetHealth then
		-- Target should be a Character model (has Humanoid directly)
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		if humanoid then
			isPlayer = true
			playerHealth = {current = humanoid.Health, max = humanoid.MaxHealth}
			targetModel = {part = target:FindFirstChild("HumanoidRootPart")}
			print("🎯 Player target detected - Character:", target.Name, "Health:", humanoid.Health)
			-- Check if player has Dead tag, if so, remove Combat and skip
			local player = game.Players:GetPlayerFromCharacter(target)
			if player then
				local CollectionService = game:GetService("CollectionService")
				print("[CombatSystem] Checking Dead tag for player:", player.Name, CollectionService:HasTag(player, "Dead"))
				if CollectionService:HasTag(player, "Dead") then
					print("[CombatSystem] Target player is dead, removing Combat for entity", attackerEntityId)
					EntityManager.removeComponent(attackerEntityId, "Combat")
					return
				end
			end
		else
			-- Not a valid player target
			print("⚠️ Invalid player target (no humanoid), removing Combat for entity", attackerEntityId)
			EntityManager.removeComponent(attackerEntityId, "Combat")
			return
		end
	end
	
	-- More lenient validation - don't remove combat component as aggressively
	if not isPlayer and not targetHealth then
		-- For entity targets, only remove if entity no longer exists
		print("⚠️ Entity target lost Health component, removing Combat for entity", attackerEntityId)
		EntityManager.removeComponent(attackerEntityId, "Combat")
		return
	end
	
	if not targetModel or not targetModel.part then
		-- Target lost model/part, but don't remove combat immediately for players
		if isPlayer then
			print("⏳ Player target has no model/part yet, keeping Combat component")
			return
		else
			print("❌ Entity target lost model/part, removing Combat for entity", attackerEntityId)
			EntityManager.removeComponent(attackerEntityId, "Combat")
			return
		end
	end
	
	-- Use appropriate health values
	local healthToCheck = isPlayer and playerHealth or targetHealth
	
	-- Check distance using model positions
	local attackerPosition = attackerModel.part.Position
	local targetPosition = targetModel.part.Position
	local distance = (attackerPosition - targetPosition).Magnitude
	
	-- Use per-enemy attack range if available, fallback to config
	local maxAttackDistance = combat.attackRange or CONFIG.MAX_COMBAT_DISTANCE
	
	if distance > maxAttackDistance then
		print("❌ Entity", attackerEntityId, "TOO FAR to attack:", math.floor(distance), "vs max", maxAttackDistance)
		return -- Too far to attack
	end
	
	print("✅ Entity", attackerEntityId, "WITHIN RANGE to attack - distance:", math.floor(distance))
	
	-- Check invincibility
	if invincibilityTimers[target] and currentTime < invincibilityTimers[target] then
		return -- Target is invincible
	end
	
	-- Apply damage to target
	local damage = combat.damage or 10
	
	if isPlayer then
		-- Apply damage to player using DamageSystem
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- Import DamageSystem here to avoid circular dependencies
			local DamageSystem = require(script.Parent.Parent.Systems.DamageSystem)
			DamageSystem:ApplyDamage(humanoid, damage, nil, "EnemyMeleeAttack")
		end
	else
		-- Apply damage to enemy using Humanoid.Health directly
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = math.max(0, humanoid.Health - damage)
		end
	end
	
	print("🎯 ATTACK EXECUTED! Entity", attackerEntityId, "attacked", target.Name, "(damage:", damage, ")")
	
	-- Set invincibility
	invincibilityTimers[target] = currentTime + CONFIG.INVINCIBILITY_TIME
	
	-- Update attack time
	combat.lastAttackTime = currentTime
	EntityManager.addComponent(attackerEntityId, "Combat", combat)
	
	-- Create visual effects
	CombatSystem._createDamageEffect(targetPosition, damage)
	CombatSystem._createHitEffect(targetModel)
	
	-- Check if target died
	if isPlayer then
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			print("💀 Player", target.Name, "defeated by entity", attackerEntityId)
		end
	else
		-- For enemies, let the Humanoid.Died event handle death/ragdoll
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			print("💀 Enemy", target.Name, "defeated by entity", attackerEntityId)
			-- Let ModelCreationSystem handle ragdoll via Humanoid.Died event
		end
	end
end

-- Simple health regeneration (removed for enemies - they use Humanoid.Health)
function CombatSystem._processHealthRegen(currentTime)
	-- Health regeneration removed for enemies
	-- Enemies now use Humanoid.Health directly, no custom Health component needed
end

-- Remove dead entities (only for players now, enemies handled by Humanoid.Died)
function CombatSystem._removeDeadEntities()
	-- This function is now only for cleanup, not entity removal
	-- Enemies are handled by ModelCreationSystem ragdoll system
	-- Players are handled by PlayerRagdollSystem
end

-- Clean up when entity is destroyed (called by external systems)
function CombatSystem.cleanup(entityId)
	invincibilityTimers[entityId] = nil
end

-- Perform maintenance to prevent memory leaks
function CombatSystem.performMaintenance()
	local currentTime = tick()
	
	-- Limit invincibility timers table size
	local timerCount = 0
	for _ in pairs(invincibilityTimers) do
		timerCount = timerCount + 1
	end
	
	if timerCount > 200 then -- Max 200 invincibility timers
		-- Remove expired timers more aggressively
		for entityId, endTime in pairs(invincibilityTimers) do
			if currentTime >= endTime then
				invincibilityTimers[entityId] = nil
			end
		end
	end
end

-- Create floating damage text
function CombatSystem._createDamageEffect(position, damage)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(2, 0, 1, 0)
	gui.Adornee = nil
	gui.StudsOffset = Vector3.new(0, 3, 0)
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "-" .. tostring(damage)
	label.TextColor3 = Color3.new(1, 0.2, 0.2)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Parent = gui
	
	-- Create a part to attach the GUI to
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Parent = workspace
	
	gui.Adornee = part
	gui.Parent = workspace
	
	-- Animate
	local tween = TweenService:Create(part, 
		TweenInfo.new(CONFIG.DAMAGE_TEXT_LIFETIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{Position = position + Vector3.new(0, 8, 0)}
	)
	
	local fadeTween = TweenService:Create(label,
		TweenInfo.new(CONFIG.DAMAGE_TEXT_LIFETIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{TextTransparency = 1}
	)
	
	tween:Play()
	fadeTween:Play()
	
	-- Clean up
	Debris:AddItem(gui, CONFIG.DAMAGE_TEXT_LIFETIME)
	Debris:AddItem(part, CONFIG.DAMAGE_TEXT_LIFETIME)
end

-- Create hit effect on model
function CombatSystem._createHitEffect(model)
	if not model or not model.part then
		return
	end
	
	-- Flash red
	local originalColor = model.part.Color
	model.part.Color = Color3.new(1, 0.3, 0.3)
	
	-- Restore color after brief flash
	spawn(function()
		wait(CONFIG.HIT_EFFECT_DURATION)
		if model.part and model.part.Parent then
			model.part.Color = originalColor
		end
	end)
end

-- Create death effect
function CombatSystem._createDeathEffect(model)
	if not model or not model.part then
		return
	end
	
	-- Fade out the model
	local tween = TweenService:Create(model.part,
		TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{Transparency = 1}
	)
	
	tween:Play()
end

return CombatSystem 