-- NPCManager.luau
-- Handles NPC spawning and management on server

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

-- Import NPCRagdollSystem
local NPCRagdollSystem = require(script.Parent.Systems.NPCRagdollSystem)

local NPCManager = {}

-- Server-wide quest state
NPCManager.questActive = false
NPCManager.spawnedNPCs = {}

-- Animation system removed - NPCs no longer use animations

-- ENHANCED: Track RunService connections for cleanup
NPCManager.followConnections = {} -- {[npcId] = connection}

-- NPC spawn positions (you can adjust these coordinates)
local spawnPositions = {
	wise_man = Vector3.new(0, 0, 0),
	trader = Vector3.new(20, 0, 0),
	regular_npc = Vector3.new(-20, 0, 0),
	princess = Vector3.new(0, 0, 30), -- Tower location
	lying_tom = Vector3.new(-40, 0, 0) -- Lying Tom position
}

-- Find proper ground position using raycast
local function findGroundPosition(spawnPosition)
	local rayOrigin = spawnPosition + Vector3.new(0, 50, 0) -- Start 50 studs above
	local rayDirection = Vector3.new(0, -100, 0) -- Cast 100 studs down
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {} -- Don't filter anything for now
	
	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	
	if result then
		-- Position above the ground (4 studs for humanoid height to prevent ground clipping)
		return result.Position + Vector3.new(0, 4, 0)
	else
		-- Fallback: use original position with height offset
		return spawnPosition + Vector3.new(0, 4, 0)
	end
end

-- Create a simple NPC model
function NPCManager:CreateNPCModel(npcId)
	local ServerStorage = game:GetService("ServerStorage")
	local npcModelsFolder = ServerStorage:FindFirstChild("NPCModels")
	local template = npcModelsFolder and npcModelsFolder:FindFirstChild(npcId)
	
	-- Fallback to old PlayerModel system if specific model not found
	if not template then
		template = ServerStorage:FindFirstChild("PlayerModel")
		if not template then
			warn("No model found for NPC:", npcId)
			warn("Please add an R15 or R6 Dummy from the toolbox to ServerStorage and rename it to 'PlayerModel'")
			
			-- Fallback: Create a basic model
			local model = Instance.new("Model")
			model.Name = npcId
			
			local part = Instance.new("Part")
			part.Name = "HumanoidRootPart"
			part.Size = Vector3.new(2, 5, 1)
			local groundPosition = findGroundPosition(spawnPositions[npcId])
			part.Position = groundPosition
			-- NPCs should be anchored when alive
			part.Anchored = true
			part.CanCollide = false
			part.Parent = model
			
			-- Add basic Humanoid (but no animations)
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = model
			
			warn("Created basic NPC. Add PlayerModel template for full functionality!")
			return model
		end
	end
	
	-- Clone the player model template
	local model = template:Clone()
	model.Name = npcId
	
	-- Position the model on the ground
	if model:FindFirstChild("HumanoidRootPart") then
		local groundPosition = findGroundPosition(spawnPositions[npcId])
		model.HumanoidRootPart.Position = groundPosition
		-- NPCs should be anchored when alive
		model.HumanoidRootPart.Anchored = true
		print("NPCManager: Positioned", npcId, "at ground level:", groundPosition)
	end
	
	-- Ensure all NPCs have proper Humanoid setup
	local humanoid = model:FindFirstChild("Humanoid")
	if humanoid then
		-- Configure Humanoid for proper NPC behavior
		humanoid.PlatformStand = false -- Allow normal movement
		humanoid.Sit = false -- Don't sit
		humanoid.WalkSpeed = 16 -- Default walking speed
	else
		warn(npcId .. " model doesn't have a Humanoid! Make sure you're using an R15/R6 dummy as PlayerModel template.")
	end
	
	-- Add NPC tag for AI detection
	local CollectionService = game:GetService("CollectionService")
	CollectionService:AddTag(model, "NPC")
	
	-- Configure Humanoid for all NPCs (including princess)
	local humanoid = model:FindFirstChild("Humanoid")
	if humanoid then
		-- Set health for all NPCs
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		
		-- Register with NPCRagdollSystem for death handling
		NPCRagdollSystem:RegisterNPC(model, npcId)
	else
		warn(npcId .. " model doesn't have a Humanoid! Make sure you're using an R15/R6 dummy as PlayerModel template.")
	end
	
	-- Anchor all NPCs initially (they should be anchored when alive)
	if model:FindFirstChild("HumanoidRootPart") then
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
		prompt.ActionText = "" -- No text shown on prompt
		prompt.ObjectText = "" -- No object text shown
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0.5 -- Require 0.5 second hold
		prompt.Parent = rootPart
	end
	
	return model
end

-- Animation functions removed - NPCs no longer use animations

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
	
	-- Add NPC tag for AI detection
	local CollectionService = game:GetService("CollectionService")
	CollectionService:AddTag(npcModel, "NPC")
	
	print("Spawned NPC:", npcId)
	return npcModel
end

-- Remove an NPC
function NPCManager:RemoveNPC(npcId)
	if self.spawnedNPCs[npcId] then
		local npcModel = self.spawnedNPCs[npcId]
		
		-- Clean up NPCRagdollSystem
		NPCRagdollSystem:CleanupNPC(npcModel)
		
		-- Clean up RunService connections before destroying
		if self.followConnections[npcId] then
			self.followConnections[npcId]:Disconnect()
			self.followConnections[npcId] = nil
		end
		
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
		npcModel:Destroy()
	end
	self.spawnedNPCs = {}
	
	-- Clear all state
	self.questActive = false
	self.questCompleted = false
	self.rewardClaimed = false
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

-- Complete the quest when princess is brought to wise man
function NPCManager:CompleteQuest()
	if self.questActive and not self.questCompleted then
		self.questActive = false
		self.questCompleted = true
		
		-- Destroy princess
		local princess = self.spawnedNPCs["princess"]
		if princess then
			princess:Destroy()
			self.spawnedNPCs["princess"] = nil
		end
		
		-- Clean up follow connection
		if self.followConnections["princess"] then
			self.followConnections["princess"]:Disconnect()
			self.followConnections["princess"] = nil
		end
		
		-- Show quest completion notification to all players
		local NotificationSystem = require(ReplicatedStorage.Shared.NotificationSystem)
		NotificationSystem:ShowToAll("Quest Complete: Talk to the Wise Man!", NotificationSystem.TYPES.QUEST_COMPLETE, 8)
		
		print("Quest completed! Princess returned to wise man.")
	end
end

-- Spawn reward item (summoner)
function NPCManager:SpawnReward()
	local wiseMan = self.spawnedNPCs["wise_man"]
	if not wiseMan then return end
	
	-- Calculate position in front of wise man
	local wiseManRoot = wiseMan:FindFirstChild("HumanoidRootPart")
	if not wiseManRoot then return end
	
	local spawnPosition = wiseManRoot.Position + (wiseManRoot.CFrame.LookVector * 3)
	
	-- Use existing item spawn system
	_G.ItemSpawnSystem.SpawnItem("summoner", spawnPosition)
	
	print("Summoner reward spawned at", spawnPosition)
end

-- Check princess proximity to wise man (runs once per second)
function NPCManager:CheckPrincessProximity()
	if not self.questActive or self.questCompleted then return end
	
	local princess = self.spawnedNPCs["princess"]
	local wiseMan = self.spawnedNPCs["wise_man"]
	
	if not princess or not wiseMan then return end
	
	local princessRoot = princess:FindFirstChild("HumanoidRootPart")
	local wiseManRoot = wiseMan:FindFirstChild("HumanoidRootPart")
	
	if not princessRoot or not wiseManRoot then return end
	
	local distance = (princessRoot.Position - wiseManRoot.Position).Magnitude
	
	if distance <= 10 then
		print("Princess within 10 studs of wise man - completing quest!")
		self:CompleteQuest()
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



-- Initialize the system
function NPCManager:Initialize()
	-- Spawn initial NPCs (not princess)
	self:SpawnNPC("wise_man")
	self:SpawnNPC("trader")
	self:SpawnNPC("regular_npc")
	self:SpawnNPC("lying_tom")
	
	-- Set up proximity checking for quest completion (runs once per second)
	local proximityConnection
	proximityConnection = RunService.Heartbeat:Connect(function()
		-- Only check once per second to avoid performance issues
		if tick() % 1 < 0.016 then -- Check roughly once per second
			self:CheckPrincessProximity()
		end
	end)
	
	print("NPCManager initialized - 4 NPCs spawned")
end

return NPCManager 