-- VisualEffectsSystem.lua
-- Simple ECS System for handling visual effects

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
    error("VisualEffectsSystem: Could not find EnemyComponents ModuleScript")
end

local VisualEffectsSystem = {}
VisualEffectsSystem.name = "VisualEffectsSystem"
VisualEffectsSystem.priority = 9

-- Configuration
local CONFIG = {
	UPDATE_INTERVAL = 1/15, -- Reduced to 15 FPS - visual effects don't need high frequency
	MAX_EFFECTS_PER_FRAME = 10,
	MAX_EFFECT_DISTANCE = 200, -- Only show effects within this distance of players
	DAMAGE_TEXT_LIFETIME = 2,
	HIT_EFFECT_DURATION = 0.5
}

-- System state
local lastUpdate = 0
local playerPositions = {}
local lastPlayerScan = 0

-- Initialize system
function VisualEffectsSystem.initialize()
	lastUpdate = 0
	playerPositions = {}
	lastPlayerScan = 0
	return true
end

-- Main update function (temporarily disabled - needs conversion to custom ECS)
function VisualEffectsSystem.update(deltaTime)
	-- TODO: Convert this system from Matter ECS to custom ECS
	-- For now, visual effects are handled by CombatSystem directly
		return
end

-- Create floating damage text
function VisualEffectsSystem._createDamageEffect(position, damage)
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
function VisualEffectsSystem._createHitEffect(model)
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
function VisualEffectsSystem._createDeathEffect(model)
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

-- Update player positions for spatial partitioning
function VisualEffectsSystem._updatePlayerPositions()
	playerPositions = {}
	
	for _, player in pairs(game:GetService("Players"):GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			table.insert(playerPositions, player.Character.HumanoidRootPart.Position)
		end
	end
end

-- Check if position is near any player
function VisualEffectsSystem._isNearPlayer(position)
	for _, playerPos in ipairs(playerPositions) do
		if (position - playerPos).Magnitude <= CONFIG.MAX_EFFECT_DISTANCE then
			return true
		end
	end
	return false
end

return VisualEffectsSystem 