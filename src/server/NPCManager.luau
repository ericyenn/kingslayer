-- NPCManager.luau
-- Handles NPC spawning and management on server

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local NPCManager = {}

-- Server-wide quest state
NPCManager.questActive = false
NPCManager.spawnedNPCs = {}

-- R6 Default Animation IDs
local R6_ANIMATIONS = {
	idle = "rbxassetid://180435571",
	walk = "rbxassetid://180426354",
	run = "rbxassetid://180426354", -- Same as walk for R6
}

-- Track NPC animations {[npcModel] = {animations = {}, currentAnim = nil, isMoving = false}}
NPCManager.npcAnimations = {}

-- ENHANCED: Track RunService connections for cleanup
NPCManager.followConnections = {} -- {[npcId] = connection}

-- NPC spawn positions (you can adjust these coordinates)
local spawnPositions = {
	wise_man = Vector3.new(0, 5, 0),
	trader = Vector3.new(20, 5, 0),
	regular_npc = Vector3.new(-20, 5, 0),
	princess = Vector3.new(0, 5, 30) -- Tower location
}

-- Create a simple NPC model
function NPCManager:CreateNPCModel(npcId)
	-- You'll need to have a "PlayerModel" in ServerStorage as a template
	-- Insert an R15 or R6 Dummy from the toolbox into ServerStorage and rename it to "PlayerModel"
	local ServerStorage = game:GetService("ServerStorage")
	local template = ServerStorage:FindFirstChild("PlayerModel")
	
	if not template then
		warn("PlayerModel template not found in ServerStorage!")
		warn("Please add an R15 or R6 Dummy from the toolbox to ServerStorage and rename it to 'PlayerModel'")
		warn("This is required for NPCs to have proper animations!")
		
		-- Fallback: Create a basic model (but animations won't work)
		local model = Instance.new("Model")
		model.Name = npcId
		
		local part = Instance.new("Part")
		part.Name = "HumanoidRootPart"
		part.Size = Vector3.new(2, 5, 1)
		part.Position = spawnPositions[npcId]
		part.Anchored = true
		part.CanCollide = false
		part.Parent = model
		
		-- Add basic Humanoid (but no animations)
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
		
		warn("Created basic NPC without animations. Add PlayerModel template for full functionality!")
		return model
	end
	
	-- Clone the player model template
	local model = template:Clone()
	model.Name = npcId
	
	-- Position the model
	if model:FindFirstChild("HumanoidRootPart") then
		model.HumanoidRootPart.Position = spawnPositions[npcId]
		model.HumanoidRootPart.Anchored = true
	end
	
	-- Ensure all NPCs have proper Humanoid setup for animations
	local humanoid = model:FindFirstChild("Humanoid")
	if humanoid then
		-- Configure Humanoid for proper NPC behavior
		humanoid.PlatformStand = false -- Allow normal movement
		humanoid.Sit = false -- Don't sit
		humanoid.WalkSpeed = 16 -- Default walking speed
		
		-- Ensure the Humanoid can use animations
		local animator = humanoid:FindFirstChild("Animator")
		if not animator then
			-- Create Animator if missing (needed for animations)
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		
		-- Load R6 animations for this NPC
		self:LoadNPCAnimations(model, humanoid, animator)
	else
		warn(npcId .. " model doesn't have a Humanoid! Make sure you're using an R15/R6 dummy as PlayerModel template.")
	end
	
	-- Special handling for Princess - configure existing Humanoid for mob behavior
	if npcId == "princess" then
		local humanoid = model:FindFirstChild("Humanoid")
		if humanoid then
			-- Configure the existing Humanoid (don't create a new one - this preserves animations)
			humanoid.MaxHealth = 100
			humanoid.Health = 100
			
			-- Handle death
			humanoid.Died:Connect(function()
				wait(2) -- Small delay before removal
				self:RemoveNPC("princess")
				print("Princess has been defeated!")
			end)
		else
			warn("Princess model doesn't have a Humanoid! Make sure you're using an R15/R6 dummy as PlayerModel template.")
		end
		
		-- Keep anchored initially so she doesn't fall before following
		model.HumanoidRootPart.Anchored = true
	end
	
	-- NPCs will use the default appearance from your PlayerModel template
	-- You can customize each NPC manually in Roblox Studio after they spawn
	
	-- Optional: Add accessories to NPCs
	self:AddNPCAccessories(model, npcId)
	
	-- Add ProximityPrompt to HumanoidRootPart
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Talk"
		prompt.ObjectText = npcId:gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest) return first:upper()..rest end)
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = rootPart
	end
	
	return model
end

-- Load R6 animations for an NPC
function NPCManager:LoadNPCAnimations(model, humanoid, animator)
	-- Create animation objects
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = R6_ANIMATIONS.idle
	
	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = R6_ANIMATIONS.walk
	
	-- Load animations
	local animations = {}
	animations.idle = animator:LoadAnimation(idleAnim)
	animations.walk = animator:LoadAnimation(walkAnim)
	
	-- Initialize animation state
	local animState = {
		animations = animations,
		currentAnim = nil,
		isMoving = false
	}
	
	-- Store animation state
	self.npcAnimations[model] = animState
	
	-- Set up movement detection
	self:SetupMovementDetection(model, humanoid, animState)
	
	-- Start with idle animation
	self:PlayNPCAnimation(model, "idle")
	
	print("Loaded R6 animations for", model.Name)
end

-- Play animation for an NPC
function NPCManager:PlayNPCAnimation(model, animName)
	local animState = self.npcAnimations[model]
	if not animState or not animState.animations[animName] then
		return
	end
	
	-- Stop current animation
	if animState.currentAnim then
		animState.currentAnim:Stop()
	end
	
	-- Play new animation
	animState.currentAnim = animState.animations[animName]
	animState.currentAnim:Play()
	
	print(model.Name .. " playing " .. animName .. " animation")
end

-- Set up movement detection for animation triggers
function NPCManager:SetupMovementDetection(model, humanoid, animState)
	-- Detect when humanoid starts/stops moving
	humanoid.Running:Connect(function(speed)
		if speed > 0.1 and not animState.isMoving then
			-- Started moving
			animState.isMoving = true
			self:PlayNPCAnimation(model, "walk")
		elseif speed <= 0.1 and animState.isMoving then
			-- Stopped moving
			animState.isMoving = false
			self:PlayNPCAnimation(model, "idle")
		end
	end)
end

-- Clean up animations when NPC is removed
function NPCManager:CleanupNPCAnimations(model)
	local animState = self.npcAnimations[model]
	if animState then
		-- Stop current animation
		if animState.currentAnim then
			animState.currentAnim:Stop()
		end
		
		-- Clean up animation tracks
		for _, anim in pairs(animState.animations) do
			anim:Destroy()
		end
		
		-- Remove from tracking
		self.npcAnimations[model] = nil
		print("Cleaned up animations for", model.Name)
	end
end

-- Optional: Add accessories to NPCs
function NPCManager:AddNPCAccessories(model, npcId)
	local ServerStorage = game:GetService("ServerStorage")
	local accessoriesFolder = ServerStorage:FindFirstChild("NPCAccessories")
	
	if not accessoriesFolder then
		return -- No accessories folder, skip
	end
	
	local npcFolder = accessoriesFolder:FindFirstChild(npcId)
	if not npcFolder then
		return -- No accessories for this NPC
	end
	
	-- Add each accessory to the model
	for _, accessory in pairs(npcFolder:GetChildren()) do
		if accessory:IsA("Accessory") then
			local clonedAccessory = accessory:Clone()
			clonedAccessory.Parent = model
		end
	end
end

-- Spawn an NPC
function NPCManager:SpawnNPC(npcId)
	if self.spawnedNPCs[npcId] then
		print("NPC", npcId, "already spawned")
		return
	end
	
	local npcModel = self:CreateNPCModel(npcId)
	npcModel.Parent = workspace
	self.spawnedNPCs[npcId] = npcModel
	
	print("Spawned NPC:", npcId)
	return npcModel
end

-- Remove an NPC
function NPCManager:RemoveNPC(npcId)
	if self.spawnedNPCs[npcId] then
		-- Clean up RunService connections before destroying
		if self.followConnections[npcId] then
			self.followConnections[npcId]:Disconnect()
			self.followConnections[npcId] = nil
		end
		
		-- Clean up animations before destroying
		self:CleanupNPCAnimations(self.spawnedNPCs[npcId])
		
		self.spawnedNPCs[npcId]:Destroy()
		self.spawnedNPCs[npcId] = nil
	end
end

-- Cleanup method for all NPCs and connections
function NPCManager:Cleanup()
	-- Clean up all follow connections
	for npcId, connection in pairs(self.followConnections) do
		connection:Disconnect()
	end
	self.followConnections = {}
	
	-- Clean up all NPCs
	for npcId, npcModel in pairs(self.spawnedNPCs) do
		self:CleanupNPCAnimations(npcModel)
		npcModel:Destroy()
	end
	self.spawnedNPCs = {}
	
	-- Clear all state
	self.questActive = false
	self.npcAnimations = {}
end

-- Start the quest (spawn princess)
function NPCManager:StartQuest()
	if not self.questActive then
		self.questActive = true
		self:SpawnNPC("princess")
		print("Quest started! Princess spawned.")
		
		-- Notify all clients that quest is active
		RemoteEvents.ShowOverheadText:FireAllClients("wise_man", "A princess lies trapped by dark magic! Find her in the tower!")
	end
end

-- Make Princess follow a player
function NPCManager:MakePrincessFollow(player)
	local princess = self.spawnedNPCs["princess"]
	if not princess then return end
	
	-- Clean up any existing follow connection first
	if self.followConnections["princess"] then
		self.followConnections["princess"]:Disconnect()
		self.followConnections["princess"] = nil
	end
	
	-- Disable the ProximityPrompt
	local prompt = princess.HumanoidRootPart:FindFirstChild("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
	
	-- Enable physics for walking (unanchor)
	if princess.HumanoidRootPart then
		princess.HumanoidRootPart.Anchored = false
	end
	
	local humanoid = princess:FindFirstChild("Humanoid")
	if not humanoid then
		warn("Princess doesn't have a Humanoid - cannot follow!")
		return
	end
	
	-- Zone-based following system
	local currentZone = "inner" -- Track current zone
	local INNER_ZONE_RADIUS = 12 -- 0-12 studs: don't move
	
	-- Get player's walking speed to match it
	local function getPlayerWalkSpeed()
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			return player.Character.Humanoid.WalkSpeed
		end
		return 16 -- Default fallback
	end
	
	-- Set initial princess speed to match player
	humanoid.WalkSpeed = getPlayerWalkSpeed()
	
	-- Zone-based movement behavior with connection tracking
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and princess.HumanoidRootPart then
			local targetPos = player.Character.HumanoidRootPart.Position
			local currentPos = princess.HumanoidRootPart.Position
			local distance = (targetPos - currentPos).Magnitude
			
			-- Determine current zone
			local newZone
			if distance <= INNER_ZONE_RADIUS then
				newZone = "inner"
			else
				newZone = "follow"
			end
			
			-- Only act when zone changes or when in follow zone
			if newZone ~= currentZone or newZone == "follow" then
				if newZone == "inner" then
					-- Inner zone: Stop moving
					humanoid:MoveTo(currentPos) -- Move to current position (stops movement)
					print("Princess entered inner zone - stopping")
				elseif newZone == "follow" then
					-- Follow zone: Match player speed and move toward player
					humanoid.WalkSpeed = getPlayerWalkSpeed()
					humanoid:MoveTo(targetPos)
					if currentZone ~= newZone then
						print("Princess entered follow zone - following at speed", humanoid.WalkSpeed)
					end
				end
				
				currentZone = newZone
			end
		else
			-- Player left or died, clean up connection properly
			connection:Disconnect()
			self.followConnections["princess"] = nil
			print("Princess follow connection cleaned up - player left or died")
		end
	end)
	
	-- Store connection for cleanup
	self.followConnections["princess"] = connection
	
	print("Princess is now following", player.Name)
end

-- Enable Princess combat mode
function NPCManager:EnablePrincessCombat()
	local princess = self.spawnedNPCs["princess"]
	if not princess then return end
	
	-- DISABLE the ProximityPrompt so she can't be talked to in combat
	local prompt = princess.HumanoidRootPart:FindFirstChild("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
	
	-- Enable physics for combat (unanchor if not already)
	if princess.HumanoidRootPart then
		princess.HumanoidRootPart.Anchored = false
	end
	
	-- Humanoid already exists from spawn, just verify it's there
	local humanoid = princess:FindFirstChild("Humanoid")
	if not humanoid then
		warn("Princess doesn't have a Humanoid - combat mode may not work properly!")
		warn("Make sure you're using an R15/R6 dummy as PlayerModel template in ServerStorage!")
		return
	end
	
	print("Princess is now in combat mode!")
end

-- Initialize the system
function NPCManager:Initialize()
	-- Spawn initial NPCs (not princess)
	self:SpawnNPC("wise_man")
	self:SpawnNPC("trader")
	self:SpawnNPC("regular_npc")
	
	print("NPCManager initialized - 3 NPCs spawned")
end

return NPCManager 