-- DialogueHandler.luau
-- Processes dialogue choices and executes actions

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DialogueData = require(ReplicatedStorage.Shared.DialogueData)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local DialogueHandler = {}

-- Track active dialogues {[player] = {npcId, startTime}}
DialogueHandler.activeDialogues = {}

-- ENHANCED: Track RunService connection for cleanup
local distanceMonitorConnection = nil

local NPCManager -- Will be set from init.server.luau

function DialogueHandler:SetNPCManager(manager)
	NPCManager = manager
end

-- Get dialogue data for an NPC based on current state
function DialogueHandler:GetDialogueForNPC(npcId, player)
	-- Handle wise man state changes
	if npcId == "wise_man" then
		if NPCManager.questActive then
			return DialogueData.NPCDialogues.wise_man_quest_active
		else
			return DialogueData.NPCDialogues.wise_man_default
		end
	end
	
	-- Return dialogue for other NPCs
	return DialogueData.NPCDialogues[npcId]
end

-- Start dialogue with an NPC
function DialogueHandler:StartDialogue(player, npcId)
	print("StartDialogue called by", player.Name, "for NPC:", npcId)
	
	-- Check if NPC exists
	if not NPCManager.spawnedNPCs[npcId] then
		print("NPC", npcId, "does not exist")
		local availableNPCs = {}
		for npcName, _ in pairs(NPCManager.spawnedNPCs) do
			table.insert(availableNPCs, npcName)
		end
		print("Available NPCs:", table.concat(availableNPCs, ", "))
		return
	end
	
	-- Get dialogue data
	local dialogueData = self:GetDialogueForNPC(npcId, player)
	if not dialogueData then
		print("No dialogue data for", npcId)
		return
	end
	
	print("Found dialogue data for", npcId, "- sending to client")
	
	-- Track active dialogue
	self.activeDialogues[player] = {
		npcId = npcId,
		startTime = tick()
	}
	
	-- Send dialogue to client
	RemoteEvents.DisplayDialogue:FireClient(player, npcId, dialogueData)
	print("Started dialogue between", player.Name, "and", npcId)
end

-- Process a dialogue choice
function DialogueHandler:ProcessChoice(player, npcId, choiceIndex)
	-- Validate active dialogue
	local activeDialogue = self.activeDialogues[player]
	if not activeDialogue or activeDialogue.npcId ~= npcId then
		print("Invalid dialogue state for", player.Name)
		return
	end
	
	-- Handle upgrade dialogue specially
	if activeDialogue.isUpgradeDialogue then
		local action = activeDialogue.upgradeResponse.actions[choiceIndex]
		if action then
			print("Processing upgrade action:", action, "for player", player.Name)
			self:ExecuteAction(player, npcId, action)
		else
			print("Invalid upgrade choice", choiceIndex)
		end
		return
	end
	
	-- Get dialogue data and action
	local dialogueData = self:GetDialogueForNPC(npcId, player)
	if not dialogueData or not dialogueData.actions[choiceIndex] then
		print("Invalid choice", choiceIndex, "for", npcId)
		return
	end
	
	local action = dialogueData.actions[choiceIndex]
	print("Processing action:", action, "for player", player.Name)
	
	-- Execute the action
	self:ExecuteAction(player, npcId, action)
end

-- Execute a dialogue action
function DialogueHandler:ExecuteAction(player, npcId, action)
	local responseDialogue = DialogueData.ResponseDialogues[action]
	
	if action == "start_quest" then
		-- Start the quest (spawn princess)
		NPCManager:StartQuest()
		if responseDialogue then
			-- Show response, then auto-end dialogue after delay
			RemoteEvents.DisplayDialogue:FireClient(player, npcId, responseDialogue)
			task.spawn(function()
				task.wait(3)
				self:EndDialogue(player)
			end)
		else
			self:EndDialogue(player)
		end
		
	elseif action == "show_lore" then
		-- Show lore text
		if responseDialogue then
			-- Show response, then auto-end dialogue after delay
			RemoteEvents.DisplayDialogue:FireClient(player, npcId, responseDialogue)
			task.spawn(function()
				task.wait(4) -- Longer delay for lore text
				self:EndDialogue(player)
			end)
		end
		
	elseif action == "quest_info" then
		-- Show quest information
		if responseDialogue then
			-- Show response, then auto-end dialogue after delay
			RemoteEvents.DisplayDialogue:FireClient(player, npcId, responseDialogue)
			task.spawn(function()
				task.wait(3)
				self:EndDialogue(player)
			end)
		end
		
	elseif action == "become_companion" then
		-- Make princess follow player
		NPCManager:MakePrincessFollow(player)
		if responseDialogue then
			-- Show response, then auto-end dialogue after delay
			RemoteEvents.DisplayDialogue:FireClient(player, npcId, responseDialogue)
			task.spawn(function()
				task.wait(3)
				self:EndDialogue(player)
			end)
		else
			self:EndDialogue(player)
		end
		
	elseif action == "enable_combat" then
		-- Enable princess combat mode
		NPCManager:EnablePrincessCombat()
		if responseDialogue then
			-- Show response, then auto-end dialogue after delay
			RemoteEvents.DisplayDialogue:FireClient(player, npcId, responseDialogue)
			task.spawn(function()
				task.wait(3)
				self:EndDialogue(player)
			end)
		else
			self:EndDialogue(player)
		end
		
	elseif action == "open_trade" then
		-- End dialogue immediately to prevent cursor conflicts with trader shop
		self:EndDialogue(player)
		
		-- Use new trader system instead of old trade menu
		local TraderHandler = require(script.Parent.TraderHandler)
		TraderHandler:OpenShop(player, npcId)
		
	elseif action == "upgrade" then
		-- Show upgrade response dialogue with current unlock request and options
		local TraderHandler = require(script.Parent.TraderHandler)
		local currentRequest = TraderHandler:GetCurrentUnlockRequest()
		
		if currentRequest then
			-- Create custom response with unlock request and dialogue options
			local upgradeResponse = {
				text = "To unlock the next level, I need:\n\n" .. currentRequest.description .. "\n\n• [Check Tradezone] - I have the items ready\n• [Leave] - Maybe later",
				actions = {"check_tradezone", "goodbye"}
			}
			
			-- Track this as an upgrade dialogue
			self.activeDialogues[player] = {
				npcId = npcId,
				startTime = tick(),
				isUpgradeDialogue = true,
				upgradeResponse = upgradeResponse
			}
			
			-- Show response with dialogue options
			RemoteEvents.DisplayDialogue:FireClient(player, npcId, upgradeResponse)
		else
			-- No more levels to unlock
			local maxLevelResponse = {
				text = "I have already unlocked all my levels!",
				actions = {}
			}
			
			RemoteEvents.DisplayDialogue:FireClient(player, npcId, maxLevelResponse)
			task.spawn(function()
				task.wait(3)
				self:EndDialogue(player)
			end)
		end
		
	elseif action == "check_tradezone" then
		-- Check if tradezone has required items and unlock level
		local TraderHandler = require(script.Parent.TraderHandler)
		local currentRequest = TraderHandler:GetCurrentUnlockRequest()
		
		print("DEBUG: Check tradezone called")
		print("DEBUG: Current request:", currentRequest and currentRequest.description or "None")
		print("DEBUG: Zone items:", TraderHandler.zoneItems)
		
		if currentRequest then
			-- Check if all requirements are met
			local allRequirementsMet = true
			for _, requirement in ipairs(currentRequest.requirements) do
				local currentQuantity = TraderHandler.zoneItems[requirement.item] or 0
				print("DEBUG: Checking requirement:", requirement.item, "needed:", requirement.quantity, "have:", currentQuantity)
				if currentQuantity < requirement.quantity then
					allRequirementsMet = false
					print("DEBUG: Requirement not met for", requirement.item)
					break
				end
			end
			
			print("DEBUG: All requirements met:", allRequirementsMet)
			
			if allRequirementsMet then
				-- Requirements met - unlock the level
				local successResponse = {
					text = "Excellent! I can see all the required items in the tradezone. The trader shop has been upgraded to the next level!",
					actions = {}
				}
				
				RemoteEvents.DisplayDialogue:FireClient(player, npcId, successResponse)
				
				-- Unlock the level
				TraderHandler:CompleteZoneRequest()
				
				task.spawn(function()
					task.wait(4)
					self:EndDialogue(player)
				end)
			else
				-- Requirements not met
				local missingResponse = {
					text = "I don't see all the required items in the tradezone. Please make sure all items are placed there before checking again.",
					actions = {}
				}
				
				RemoteEvents.DisplayDialogue:FireClient(player, npcId, missingResponse)
				
				task.spawn(function()
					task.wait(4)
					self:EndDialogue(player)
				end)
			end
		else
			-- No current request (shouldn't happen)
			local errorResponse = {
				text = "There are no levels to unlock at this time.",
				actions = {}
			}
			
			RemoteEvents.DisplayDialogue:FireClient(player, npcId, errorResponse)
			
			task.spawn(function()
				task.wait(3)
				self:EndDialogue(player)
			end)
		end
		
	elseif action == "tell_story" then
		-- Tell story
		if responseDialogue then
			-- Show response, then auto-end dialogue after delay
			RemoteEvents.DisplayDialogue:FireClient(player, npcId, responseDialogue)
			task.spawn(function()
				task.wait(5) -- Longer delay for story
				self:EndDialogue(player)
			end)
		end
		
	elseif action == "goodbye" then
		-- End dialogue immediately without showing response
		self:EndDialogue(player)
	elseif action == "end_dialogue" then
		-- Simply end the dialogue without showing any response
		self:EndDialogue(player)
	end
end

-- End dialogue for a player
function DialogueHandler:EndDialogue(player)
	if self.activeDialogues[player] then
		print("Ending dialogue for", player.Name)
		self.activeDialogues[player] = nil
		RemoteEvents.EndDialogue:FireClient(player)
	end
end

-- Monitor dialogue distances
function DialogueHandler:MonitorDistances()
	-- Clean up existing connection first
	if distanceMonitorConnection then
		distanceMonitorConnection:Disconnect()
	end
	
	-- Create new connection with tracking
	distanceMonitorConnection = RunService.Heartbeat:Connect(function()
		for player, dialogueInfo in pairs(self.activeDialogues) do
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local npc = NPCManager.spawnedNPCs[dialogueInfo.npcId]
				if npc and npc:FindFirstChild("HumanoidRootPart") then
					local distance = (player.Character.HumanoidRootPart.Position - npc.HumanoidRootPart.Position).Magnitude
					
					-- End dialogue if too far (20 studs)
					if distance > 20 then
						self:EndDialogue(player)
					end
				end
			end
		end
	end)
end

-- Add cleanup method
function DialogueHandler:Cleanup()
	-- Clean up distance monitor connection
	if distanceMonitorConnection then
		distanceMonitorConnection:Disconnect()
		distanceMonitorConnection = nil
	end
	
	-- End all active dialogues
	for player, dialogueInfo in pairs(self.activeDialogues) do
		RemoteEvents.EndDialogue:FireClient(player)
	end
	self.activeDialogues = {}
end

-- Initialize the dialogue handler
function DialogueHandler:Initialize()
	-- Set up RemoteEvent connections
	RemoteEvents.StartDialogue.OnServerEvent:Connect(function(player, npcId)
		self:StartDialogue(player, npcId)
	end)
	
	RemoteEvents.ProcessChoice.OnServerEvent:Connect(function(player, npcId, choiceIndex)
		self:ProcessChoice(player, npcId, choiceIndex)
	end)
	
	-- Start distance monitoring
	self:MonitorDistances()
	
	print("DialogueHandler initialized")
end

return DialogueHandler 