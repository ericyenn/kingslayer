local ClockUI = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ClockUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local clockLabel = Instance.new("TextLabel")
clockLabel.Name = "ClockLabel"
clockLabel.Size = UDim2.new(0, 180, 0, 40)
clockLabel.Position = UDim2.new(1, -200, 0, 20) -- Top right
clockLabel.BackgroundTransparency = 0.3
clockLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
clockLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
clockLabel.TextStrokeTransparency = 0.5
clockLabel.TextSize = 28
clockLabel.Font = Enum.Font.GothamBold
clockLabel.Text = "00:00"
clockLabel.Parent = screenGui

local function formatClockTime(clockTime)
	local hour = math.floor(clockTime)
	local minute = math.floor((clockTime - hour) * 60)
	return string.format("%02d:%02d", hour, minute)
end

RemoteEvents.ClockUpdate.OnClientEvent:Connect(function(clockTime)
	clockLabel.Text = formatClockTime(clockTime)
end)

function ClockUI:Initialize()
	-- Nothing needed, UI is set up on require
end

return ClockUI 