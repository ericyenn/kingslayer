-- Data module
-- Exports all data modules for the StayAlive survival game
-- Import this module to access all data: local Data = require(path.to.data)

local Data = {}

-- Import data modules
local SpawnRules = require(script.SpawnRules)

-- Export data modules
Data.SpawnRules = SpawnRules

print("📚 Data module loaded with SpawnRules")

return Data