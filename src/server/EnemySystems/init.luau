-- Systems/init.lua
-- Exports all ECS systems for the StayAlive game

local Systems = {
	AISystem = require(script.AISystem),
	CombatSystem = require(script.CombatSystem),
	EnemyChatSystem = require(script.EnemyChatSystem),
	ModelCreationSystem = require(script.ModelCreationSystem),
	EnemySpawnSystem = require(script.EnemySpawnSystem),
	VisualEffectsSystem = require(script.VisualEffectsSystem),
	MovementSystem = require(script.MovementSystem),
}

return Systems 