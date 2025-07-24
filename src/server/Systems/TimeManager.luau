local TimeManager = {}

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

-- CONFIG
local DAY_LENGTH = 5 * 60 -- seconds
local NIGHT_LENGTH = 5 * 60 -- seconds
local FULL_CYCLE = DAY_LENGTH + NIGHT_LENGTH

-- State
local elapsed = 0
local currentDay = 1
local playerData = {}

-- RemoteEvents (to be set up in shared/RemoteEvents.luau)
local RemoteEvents = require(game:GetService("ReplicatedStorage").Shared.RemoteEvents)

function TimeManager.Init()
	-- Initialize player data
	Players.PlayerAdded:Connect(function(player)
		playerData[player] = {playtime = 0, daysSurvived = 1}
	end)
	Players.PlayerRemoving:Connect(function(player)
		playerData[player] = nil
	end)

	RunService.Heartbeat:Connect(TimeManager.Update)

	-- Listen for stats requests from clients
	RemoteEvents.StatsUpdate.OnServerEvent:Connect(function(player)
		TimeManager.SendStatsToPlayer(player)
	end)
end

function TimeManager.Update(dt)
	elapsed = elapsed + dt
	-- Update Lighting.ClockTime smoothly
	local cycleTime = elapsed % FULL_CYCLE
	local clockTime
	if cycleTime < DAY_LENGTH then
		-- Day: 6 to 18 (Roblox default day)
		clockTime = 6 + (12 * (cycleTime / DAY_LENGTH))
	else
		-- Night: 18 to 30 (wraps to 6)
		local nightTime = cycleTime - DAY_LENGTH
		clockTime = 18 + (12 * (nightTime / NIGHT_LENGTH))
		if clockTime >= 24 then clockTime = clockTime - 24 end
	end
	Lighting.ClockTime = clockTime

	-- Update player playtime and days survived
	for player, data in pairs(playerData) do
		data.playtime = data.playtime + dt
		local newDay = math.floor(elapsed / FULL_CYCLE) + 1
		if newDay > data.daysSurvived then
			data.daysSurvived = newDay
		end
	end

	-- Fire clock update to clients
	RemoteEvents.ClockUpdate:FireAllClients(clockTime)
end

function TimeManager.SendStatsToPlayer(player)
	local data = playerData[player]
	if data then
		RemoteEvents.StatsUpdate:FireClient(player, data.daysSurvived, data.playtime)
	else
		RemoteEvents.StatsUpdate:FireClient(player, 1, 0)
	end
end

function TimeManager.GetPlayerStats(player)
	local data = playerData[player]
	if data then
		return data.daysSurvived, data.playtime
	else
		return 1, 0
	end
end

return TimeManager 