local TweenService = game:GetService("TweenService")

local StatsPanel = {}
StatsPanel.__index = StatsPanel

local STATS_FRAME_WIDTH = 400
local STATS_FRAME_HEIGHT = 180
local STATS_FRAME_Y = 0.25
local STATS_ANIM_TIME = 0.35
local STATS_ANIM_TIME_OUT = 0.12 -- Faster hide
local STATS_FRAME_X_HIDDEN = -STATS_FRAME_WIDTH
local STATS_FRAME_X_VISIBLE = 40
local STAT_LABEL_X_HIDDEN = -STATS_FRAME_WIDTH
local STAT_LABEL_X_VISIBLE = 0
local WAVE_DELAY = 0.15

function StatsPanel.new(parent)
	local self = setmetatable({}, StatsPanel)

	-- Main frame
	self.frame = Instance.new("Frame")
	self.frame.Name = "StatsFrame"
	self.frame.Size = UDim2.new(0, STATS_FRAME_WIDTH, 0, STATS_FRAME_HEIGHT)
	self.frame.Position = UDim2.new(0, STATS_FRAME_X_HIDDEN, 0.08, 0)
	self.frame.BackgroundTransparency = 1
	self.frame.Visible = false
	self.frame.Parent = parent

	-- Title
	self.title = Instance.new("TextLabel")
	self.title.Name = "RunStatsTitle"
	self.title.Size = UDim2.new(1, 0, 0, 48)
	self.title.Position = UDim2.new(0, 0, 0, 0)
	self.title.BackgroundTransparency = 1
	self.title.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.title.TextStrokeTransparency = 0.2
	self.title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	self.title.TextSize = 56 -- Larger than stats
	self.title.Font = Enum.Font.GothamBold
	self.title.TextXAlignment = Enum.TextXAlignment.Left
	self.title.TextYAlignment = Enum.TextYAlignment.Top
	self.title.Text = "Run Stats:"
	self.title.Parent = self.frame

	-- Days Survived label
	self.daysLabel = Instance.new("TextLabel")
	self.daysLabel.Name = "DaysLabel"
	self.daysLabel.Size = UDim2.new(1, 0, 0, 56)
	self.daysLabel.Position = UDim2.new(0, STAT_LABEL_X_HIDDEN, 0, 48)
	self.daysLabel.BackgroundTransparency = 1
	self.daysLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.daysLabel.TextStrokeTransparency = 0.2
	self.daysLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	self.daysLabel.TextSize = 40
	self.daysLabel.Font = Enum.Font.GothamBold
	self.daysLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.daysLabel.TextYAlignment = Enum.TextYAlignment.Top
	self.daysLabel.Text = "Days Survived: 1"
	self.daysLabel.Parent = self.frame

	-- Playtime label
	self.playtimeLabel = Instance.new("TextLabel")
	self.playtimeLabel.Name = "PlaytimeLabel"
	self.playtimeLabel.Size = UDim2.new(1, 0, 0, 56)
	self.playtimeLabel.Position = UDim2.new(0, STAT_LABEL_X_HIDDEN, 0, 104)
	self.playtimeLabel.BackgroundTransparency = 1
	self.playtimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.playtimeLabel.TextStrokeTransparency = 0.2
	self.playtimeLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	self.playtimeLabel.TextSize = 40
	self.playtimeLabel.Font = Enum.Font.GothamBold
	self.playtimeLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.playtimeLabel.TextYAlignment = Enum.TextYAlignment.Top
	self.playtimeLabel.Text = "Playtime: 00:00"
	self.playtimeLabel.Parent = self.frame

	self.statsTween = nil
	self.labelTweens = {}
	return self
end

function StatsPanel:SetStats(daysSurvived, playtime)
	self.daysLabel.Text = string.format("Days Survived: %d", daysSurvived)
	self.playtimeLabel.Text = string.format("Playtime: %s", self:FormatPlaytime(playtime))
end

function StatsPanel:FormatPlaytime(seconds)
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", mins, secs)
end

function StatsPanel:Show()
	self.frame.Visible = true
	if self.statsTween then self.statsTween:Cancel() end
	self.frame.Position = UDim2.new(0, STATS_FRAME_X_HIDDEN, 0.08, 0)
	self.statsTween = TweenService:Create(self.frame, TweenInfo.new(STATS_ANIM_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0, STATS_FRAME_X_VISIBLE, 0.08, 0)})
	self.statsTween:Play()

	-- Wave in labels with bounce/spring
	self.daysLabel.Position = UDim2.new(0, STAT_LABEL_X_HIDDEN, 0, 48)
	self.playtimeLabel.Position = UDim2.new(0, STAT_LABEL_X_HIDDEN, 0, 104)
	if self.labelTweens.days then self.labelTweens.days:Cancel() end
	if self.labelTweens.playtime then self.labelTweens.playtime:Cancel() end
	self.labelTweens.days = nil
	self.labelTweens.playtime = nil

	task.delay(0.05, function()
		self.labelTweens.days = TweenService:Create(self.daysLabel, TweenInfo.new(STATS_ANIM_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, STAT_LABEL_X_VISIBLE, 0, 48)})
		self.labelTweens.days:Play()
	end)
	task.delay(WAVE_DELAY + 0.05, function()
		self.labelTweens.playtime = TweenService:Create(self.playtimeLabel, TweenInfo.new(STATS_ANIM_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, STAT_LABEL_X_VISIBLE, 0, 104)})
		self.labelTweens.playtime:Play()
	end)
end

function StatsPanel:Hide()
	if self.statsTween then self.statsTween:Cancel() end
	self.statsTween = TweenService:Create(self.frame, TweenInfo.new(STATS_ANIM_TIME_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0, STATS_FRAME_X_HIDDEN, 0.08, 0)})
	self.statsTween:Play()

	-- Wave out labels (faster, together)
	if self.labelTweens.days then self.labelTweens.days:Cancel() end
	if self.labelTweens.playtime then self.labelTweens.playtime:Cancel() end
	self.labelTweens.days = TweenService:Create(self.daysLabel, TweenInfo.new(STATS_ANIM_TIME_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0, STAT_LABEL_X_HIDDEN, 0, 48)})
	self.labelTweens.playtime = TweenService:Create(self.playtimeLabel, TweenInfo.new(STATS_ANIM_TIME_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0, STAT_LABEL_X_HIDDEN, 0, 104)})
	self.labelTweens.days:Play()
	self.labelTweens.playtime:Play()
	task.delay(STATS_ANIM_TIME_OUT, function()
		self.frame.Visible = false
	end)
end

return StatsPanel 