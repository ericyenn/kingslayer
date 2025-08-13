-- DialogueUI.luau
-- Handles client-side dialogue UI and interactions

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local DialogueUI = {}

-- Track active dialogue state
DialogueUI.activeDialogue = nil
DialogueUI.activeBillboard = nil
DialogueUI.modalButton = nil -- Track modal button for cursor management

-- Create BOTW-style dialogue system with main dialogue box at bottom
function DialogueUI:CreateDialogueSystem()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BOTWDialogueSystem"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = player.PlayerGui
	
	-- Speaker name container (above main dialogue box)
	local speakerContainer = Instance.new("Frame")
	speakerContainer.Name = "SpeakerContainer"
	speakerContainer.Size = UDim2.new(0, 200, 0, 35)
	speakerContainer.Position = UDim2.new(0.5, -100, 1, -200) -- Above main dialogue box
	speakerContainer.BackgroundTransparency = 1 -- Fully transparent - no bubble
	speakerContainer.BorderSizePixel = 0
	speakerContainer.Parent = screenGui
	
	-- Speaker name label
	local speakerLabel = Instance.new("TextLabel")
	speakerLabel.Name = "SpeakerName"
	speakerLabel.Size = UDim2.new(1, -16, 1, -8)
	speakerLabel.Position = UDim2.new(0, 8, 0, 4)
	speakerLabel.BackgroundTransparency = 1
	speakerLabel.Text = "Speaker"
	speakerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	speakerLabel.TextSize = 22
	speakerLabel.TextWrapped = true
	speakerLabel.Font = Enum.Font.GothamBold
	speakerLabel.TextXAlignment = Enum.TextXAlignment.Center
	speakerLabel.Parent = speakerContainer
	
	-- Main dialogue box (bottom center of screen)
	local dialogueBox = Instance.new("Frame")
	dialogueBox.Name = "MainDialogueBox"
	dialogueBox.Size = UDim2.new(0, 800, 0, 150) -- Wide rectangular shape
	dialogueBox.Position = UDim2.new(0.5, -400, 1, -170) -- Bottom center, low enough to see characters
	dialogueBox.BackgroundColor3 = Color3.fromRGB(45, 45, 45) -- Muted grey
	dialogueBox.BackgroundTransparency = 0.25 -- Semi-transparent to see game world
	dialogueBox.BorderSizePixel = 0
	dialogueBox.Parent = screenGui
	
	-- No rounded corners for main dialogue box
	
	-- Dialogue text area
	local textArea = Instance.new("TextLabel")
	textArea.Name = "DialogueText"
	textArea.Size = UDim2.new(1, -40, 1, -30)
	textArea.Position = UDim2.new(0, 20, 0, 15)
	textArea.BackgroundTransparency = 1
	textArea.Text = ""
	textArea.TextColor3 = Color3.fromRGB(255, 255, 255)
	textArea.TextSize = 18
	textArea.TextWrapped = true
	textArea.Font = Enum.Font.Gotham -- Clean, legible font
	textArea.TextXAlignment = Enum.TextXAlignment.Left
	textArea.TextYAlignment = Enum.TextYAlignment.Top
	textArea.Parent = dialogueBox
	
	-- Choice container (to the right of main dialogue box)
	local choiceContainer = Instance.new("Frame")
	choiceContainer.Name = "ChoiceContainer"
	choiceContainer.Size = UDim2.new(0, 350, 0, 200) -- Narrower width to fit on right side
	choiceContainer.Position = UDim2.new(0.5, 420, 1, -245) -- To the right of dialogue box, vertically centered with it
	choiceContainer.BackgroundTransparency = 1 -- Invisible container
	choiceContainer.Parent = screenGui
	
	-- Layout for choice boxes (vertical list)
	local choiceLayout = Instance.new("UIListLayout")
	choiceLayout.FillDirection = Enum.FillDirection.Vertical
	choiceLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	choiceLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	choiceLayout.Padding = UDim.new(0, 8) -- Spacing between choices
	choiceLayout.Parent = choiceContainer
	
	return screenGui, dialogueBox, textArea, speakerLabel, choiceContainer
end

-- Clear/remove dialogue system
function DialogueUI:ClearDialogueSystem()
	local existingSystem = player.PlayerGui:FindFirstChild("BOTWDialogueSystem")
	if existingSystem then
		existingSystem:Destroy()
	end
	
	-- Clear modal button reference since it's destroyed with the system
	self.modalButton = nil
end

-- Create BOTW-style individual choice box
function DialogueUI:CreateChoiceBox(choiceText, choiceIndex, container, npcId)
	local button = Instance.new("TextButton")
	button.Name = "ChoiceBox" .. choiceIndex
	button.Size = UDim2.new(0, 320, 0, 35) -- Shorter and narrower to fit in right-side container
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 50) -- Muted grey like main dialogue box
	button.BackgroundTransparency = 0.3 -- Semi-transparent
	button.BorderSizePixel = 0
	button.Text = choiceText
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 14 -- Slightly smaller text size to fit better
	button.TextWrapped = true
	button.Font = Enum.Font.Gotham -- Clean, legible font
	button.AutoButtonColor = false
	button.Parent = container
	
	-- No rounded corners for choice box
	
	-- Padding for text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = button
	
	-- BOTW-style hover effects (subtle glow and color change)
	button.MouseEnter:Connect(function()
		-- Play choice hover sound
		if _G.AudioSystem then
			_G.AudioSystem:PlayChoiceHoverSound()
		end
		
		button.BackgroundColor3 = Color3.fromRGB(80, 120, 200) -- Subtle blue highlight
		button.BackgroundTransparency = 0.1 -- More opaque when highlighted
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
	end)
	
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		button.BackgroundTransparency = 0.3
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
	end)
	
	-- Click handling
	button.MouseButton1Click:Connect(function()
		print("Choice box clicked:", choiceIndex, choiceText)
		-- Don't clear dialogue system immediately - let server response handle the flow
		-- Send choice to server and wait for response
		RemoteEvents.ProcessChoice:FireServer(npcId, choiceIndex)
	end)
	
	return button
end

-- Typewriter effect for dialogue text
function DialogueUI:TypewriterEffect(textLabel, fullText, speed, onComplete)
	speed = speed or 0.03 -- Characters per second
	local currentText = ""
	local textLength = string.len(fullText)
	local currentIndex = 0
	local completed = false -- Track if animation is complete to prevent duplicate onComplete calls
	local lastDisplayIndex = 0 -- Track last displayed character for sound triggering
	
	-- Clear existing text
	textLabel.Text = ""
	
	-- Create typewriter animation
	local typewriterConnection
	typewriterConnection = RunService.Heartbeat:Connect(function(deltaTime)
		currentIndex = currentIndex + (speed / deltaTime)
		
		if currentIndex >= textLength then
			-- Animation complete
			textLabel.Text = fullText
			typewriterConnection:Disconnect()
			if onComplete and not completed then
				completed = true
				onComplete()
			end
		else
			-- Update displayed text
			local displayIndex = math.floor(currentIndex)
			if displayIndex > lastDisplayIndex then
				-- Character added - play typewriter sound
				if _G.AudioSystem then
					_G.AudioSystem:PlayTextAdvanceSound()
				end
				lastDisplayIndex = displayIndex
			end
			currentText = string.sub(fullText, 1, displayIndex)
			textLabel.Text = currentText
		end
	end)
	
	-- Allow instant reveal on click
	local clickConnection
	clickConnection = textLabel.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Play instant reveal sound
			if _G.AudioSystem then
				_G.AudioSystem:PlayInstantRevealSound()
			end
			
			-- Instantly show full text
			textLabel.Text = fullText
			currentIndex = textLength
			typewriterConnection:Disconnect()
			clickConnection:Disconnect()
			if onComplete and not completed then
				completed = true
				onComplete()
			end
		end
	end)
	
	return typewriterConnection, clickConnection
end

-- Create modal button for cursor management (similar to ArmorMenu)
function DialogueUI:CreateModalButton()
	if self.modalButton then
		return -- Already exists
	end
	
	local screenGui = player.PlayerGui:FindFirstChild("BOTWDialogueSystem")
	if not screenGui then
		return -- No dialogue UI active
	end
	
	-- Create invisible modal button to keep cursor unlocked
	local modalButton = Instance.new("TextButton")
	modalButton.Name = "DialogueModalButton"
	modalButton.Size = UDim2.new(1, 0, 1, 0)
	modalButton.Position = UDim2.new(0, 0, 0, 0)
	modalButton.BackgroundTransparency = 1
	modalButton.Text = ""
	modalButton.Modal = true -- This keeps the cursor unlocked
	modalButton.ZIndex = -1 -- Behind other UI elements
	modalButton.Parent = screenGui
	
	self.modalButton = modalButton
end

-- Note: RemoveModalButton function removed - modal button is now automatically destroyed with the dialogue system

-- Display dialogue using BOTW-style dialogue system
function DialogueUI:DisplayDialogue(npcId, dialogueData)
	local npcModel = workspace:FindFirstChild(npcId)
	if not npcModel then
		print("NPC model not found:", npcId)
		return
	end
	
	-- Only set cursor behavior if no dialogue is currently active
	if not self.activeDialogue then
		-- Unlock cursor and hide crosshair when dialogue starts
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		
		-- Hide crosshair when dialogue is open
		if _G.CameraSystem then
			_G.CameraSystem:HideCrosshair()
		end
	end

	-- Parse dialogue text to separate main text from choices
	local fullText = dialogueData.text
	local lines = {}
	for line in fullText:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end

	-- Find where choices start (lines that begin with "•")
	local mainTextLines = {}
	local choiceLines = {}
	local foundChoices = false

	for i, line in ipairs(lines) do
		if line:match("^•") then -- Line starts with bullet point
			foundChoices = true
			table.insert(choiceLines, line)
		else
			if not foundChoices then
				table.insert(mainTextLines, line)
			end
		end
	end

	-- Clear any existing dialogue system
	self:ClearDialogueSystem()

	-- Create new BOTW-style dialogue system
	local screenGui, dialogueBox, textArea, speakerLabel, choiceContainer = self:CreateDialogueSystem()

	-- Set speaker name (format NPC ID to readable name)
	local speakerName = npcId:gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest) 
		return first:upper()..rest 
	end)
	speakerLabel.Text = speakerName

	-- Get main dialogue text
	local mainText = table.concat(mainTextLines, "\n")
	
	-- Start typewriter effect for main text
	self:TypewriterEffect(textArea, mainText, 0.05, function()
		-- After typewriter completes, show choices if any exist
		if #choiceLines > 0 then
			for i, choiceLine in ipairs(choiceLines) do
				-- Remove bullet point and trim whitespace manually
				local choiceText = choiceLine:gsub("^•%s*", ""):gsub("^%[(.-)%]%s*%-", "%1:")
				choiceText = choiceText:gsub("^%s*(.-)%s*$", "%1") -- Manual trim
				self:CreateChoiceBox(choiceText, i, choiceContainer, npcId)
			end
		end
	end)

	-- Create modal button to keep cursor unlocked
	self:CreateModalButton()

	-- Store active dialogue reference
	self.activeDialogue = {
		npcId = npcId,
		dialogueSystem = screenGui,
		startTime = tick()
	}

	print("Displayed BOTW dialogue for", npcId)
end

-- Note: ShowOverheadText function removed - server now uses DisplayDialogue for all responses

-- End dialogue (cleanup)
function DialogueUI:EndDialogue()
	-- Clear dialogue system
	self:ClearDialogueSystem()

	-- Clear active dialogue
	self.activeDialogue = nil
	
	-- Restore cursor lock and show crosshair when dialogue ends
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	
	-- Show crosshair when dialogue is closed
	if _G.CameraSystem then
		_G.CameraSystem:ShowCrosshair()
	end

	print("Dialogue ended")
end

-- Handle proximity prompt triggered
function DialogueUI:OnProximityPromptTriggered(promptObject)
	print("OnProximityPromptTriggered called with:", promptObject)
	print("Prompt parent:", promptObject.Parent)
	print("Prompt parent name:", promptObject.Parent and promptObject.Parent.Name or "nil")
	
	-- The proximity prompt is attached to HumanoidRootPart, so we need to go up one more level
	local humanoidRootPart = promptObject.Parent
	local npcModel = humanoidRootPart and humanoidRootPart.Parent
	
	print("HumanoidRootPart:", humanoidRootPart)
	print("NPC Model:", npcModel)
	print("NPC Model Name:", npcModel and npcModel.Name or "nil")
	print("NPC Model Parent:", npcModel and npcModel.Parent or "nil")
	
	-- Check if this is actually an NPC (has NPC tag) and not a dead player
	if npcModel and npcModel.Parent == workspace and CollectionService:HasTag(npcModel, "NPC") then
		local npcId = npcModel.Name
		print("Proximity prompt triggered for NPC:", npcId)
		print("Firing StartDialogue to server for:", npcId)
		RemoteEvents.StartDialogue:FireServer(npcId)
	else
		print("Not an NPC or not in workspace - ignoring prompt")
		print("npcModel:", npcModel)
		print("npcModel.Parent:", npcModel and npcModel.Parent or "nil")
		print("Has NPC tag:", npcModel and CollectionService:HasTag(npcModel, "NPC") or "nil")
	end
end

-- Initialize the dialogue UI system
function DialogueUI:Initialize()
	-- Connect to RemoteEvents
	RemoteEvents.DisplayDialogue.OnClientEvent:Connect(function(npcId, dialogueData)
		self:DisplayDialogue(npcId, dialogueData)
	end)
	
	RemoteEvents.EndDialogue.OnClientEvent:Connect(function()
		self:EndDialogue()
	end)
	
	-- Connect to all proximity prompts (for NPCs) - future ones
	workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			print("Found new ProximityPrompt:", descendant.Name, "in", descendant.Parent.Name)
			descendant.Triggered:Connect(function(player)
				if player == Players.LocalPlayer then
					print("ProximityPrompt triggered by", player.Name)
					self:OnProximityPromptTriggered(descendant)
				end
			end)
		end
	end)
	
	-- Function to connect existing proximity prompts with retry logic
	local function connectExistingPrompts()
		local promptsFound = 0
		for _, descendant in pairs(workspace:GetDescendants()) do
			if descendant:IsA("ProximityPrompt") then
				promptsFound = promptsFound + 1
				print("Connecting to existing ProximityPrompt:", descendant.Name, "in", descendant.Parent.Name)
				descendant.Triggered:Connect(function(player)
					if player == Players.LocalPlayer then
						print("Existing ProximityPrompt triggered by", player.Name)
						self:OnProximityPromptTriggered(descendant)
					end
				end)
			end
		end
		print("Connected to", promptsFound, "existing proximity prompts")
		return promptsFound
	end
	
	-- Connect to existing proximity prompts immediately
	local initialPrompts = connectExistingPrompts()
	
	-- If no prompts found initially, retry after a delay (NPCs might still be loading)
	if initialPrompts == 0 then
		print("No proximity prompts found initially, retrying in 2 seconds...")
		wait(2)
		connectExistingPrompts()
	end
	
	print("DialogueUI initialized")
end

return DialogueUI 