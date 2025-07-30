-- Systems/init.lua
-- Exports all ECS systems for the StayAlive game

local Systems = {
	AISystem = require(script.AISystem),
	CombatSystem = require(script.CombatSystem),
	ModelCreationSystem = require(script.ModelCreationSystem),
	EnemySpawnSystem = require(script.EnemySpawnSystem),
	VisualEffectsSystem = require(script.VisualEffectsSystem),
}

return Systems 