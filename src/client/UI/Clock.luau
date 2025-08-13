local ClockUI = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

-- Defer to HealthBar's clock title/value if present; otherwise create standalone UI
-- Removed standalone clock: HealthBar location is the ONLY display

local function formatClockHourAmPm(clockTime)
    local hour = math.floor(clockTime) % 24
    local period = (hour >= 12) and "PM" or "AM"
    local hour12 = hour % 12
    if hour12 == 0 then hour12 = 12 end
    return string.format("%d %s", hour12, period)
end

RemoteEvents.ClockUpdate.OnClientEvent:Connect(function(clockTime)
    -- HealthBar location is the ONLY display
    local hbGui = playerGui:FindFirstChild("HealthbarUI")
    local clockBg = hbGui and hbGui:FindFirstChild("ClockTitleBackground")
    local clockVal = clockBg and clockBg:FindFirstChild("ClockValue")
    if clockVal and clockVal:IsA("TextLabel") then
        local hasClock = player:GetAttribute("HasClock") == true
        clockVal.Text = hasClock and formatClockHourAmPm(clockTime) or "???"
    end
end)

function ClockUI:Initialize()
	-- Nothing needed, UI is set up on require
end

return ClockUI 