-- EnemyChatSystem.luau
-- Handles enemy-to-enemy chat when they're close during idle/patrol states

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Import ECS modules
local EntityManager = require(ReplicatedStorage.Shared.EntityManager)
local EnemyChatData = require(ReplicatedStorage.Shared.EnemyChatData)

-- Import Components from our custom ECS (find ModuleScript specifically to avoid folder conflict)
local Components = nil
for _, child in ipairs(ReplicatedStorage.Shared:GetChildren()) do
    if child.Name == "EnemyComponents" and child.ClassName == "ModuleScript" then
        Components = require(child)
        break
    end
end

if not Components then
    error("EnemyChatSystem: Could not find EnemyComponents ModuleScript")
end

local EnemyChatSystem = {}
EnemyChatSystem.name = "EnemyChatSystem"

-- Configuration
local CONFIG = {
    UPDATE_INTERVAL = 2.0, -- Check for chat opportunities every 2 seconds
    MAX_CHATS_PER_FRAME = 1, -- Limit concurrent chats to prevent spam
    DEFAULT_CHAT_RANGE = 5, -- Default chat range in studs (changed from 12 to 5)
    CHAT_CHANCE = 0.3, -- 30% chance to chat when conditions are met
}

-- System state
local lastUpdate = 0

-- Initialize system
function EnemyChatSystem.initialize()
    lastUpdate = 0
    return true
end

-- Main update function
function EnemyChatSystem.update(deltaTime)
    local currentTime = tick()
    if currentTime - lastUpdate < CONFIG.UPDATE_INTERVAL then
        return
    end
    lastUpdate = currentTime
    
    local chatsTriggered = 0
    
    -- Get all entities with EnemyAI, Model, EnemyType, and EnemyChat components
    local chatEntities = EntityManager.getEntitiesWithAll({"EnemyAI", "Model", "EnemyType", "EnemyChat"})
    
    for i, entityId1 in ipairs(chatEntities) do
        if chatsTriggered >= CONFIG.MAX_CHATS_PER_FRAME then
            break
        end
        
        local enemyAI1 = EntityManager.getComponent(entityId1, "EnemyAI")
        local model1 = EntityManager.getComponent(entityId1, "Model")
        local enemyType1 = EntityManager.getComponent(entityId1, "EnemyType")
        local enemyChat1 = EntityManager.getComponent(entityId1, "EnemyChat")
        
        -- Check if this enemy can chat
        if enemyAI1 and model1 and enemyType1 and enemyChat1 and 
           model1.part and enemyChat1.canChat and
           (enemyAI1.state == "idle" or enemyAI1.state == "patrol") and
           (currentTime - enemyChat1.lastChatTime >= enemyChat1.chatCooldown) then
            
            -- Look for nearby chat partners
            for j = i + 1, #chatEntities do
                local entityId2 = chatEntities[j]
                
                local enemyAI2 = EntityManager.getComponent(entityId2, "EnemyAI")
                local model2 = EntityManager.getComponent(entityId2, "Model")
                local enemyType2 = EntityManager.getComponent(entityId2, "EnemyType")
                local enemyChat2 = EntityManager.getComponent(entityId2, "EnemyChat")
                
                -- Check if partner can chat
                if enemyAI2 and model2 and enemyType2 and enemyChat2 and 
                   model2.part and enemyChat2.canChat and
                   (enemyAI2.state == "idle" or enemyAI2.state == "patrol") and
                   (currentTime - enemyChat2.lastChatTime >= enemyChat2.chatCooldown) and
                   not EnemyChatSystem._haveChattedRecently(entityId1, entityId2, enemyChat1, enemyChat2, currentTime) then
                    
                    -- Check distance
                    local distance = (model1.part.Position - model2.part.Position).Magnitude
                    local chatRange = math.min(enemyChat1.chatRange or CONFIG.DEFAULT_CHAT_RANGE, 
                                             enemyChat2.chatRange or CONFIG.DEFAULT_CHAT_RANGE)
                    
                    if distance <= chatRange then
                        -- Roll for chat chance
                        if math.random() <= CONFIG.CHAT_CHANCE then
                            -- Trigger chat!
                            EnemyChatSystem._triggerChat(entityId1, entityId2, enemyAI1, enemyAI2, 
                                                       enemyType1, enemyType2, enemyChat1, enemyChat2, currentTime)
                            chatsTriggered = chatsTriggered + 1
                            break -- Only one chat per entity per frame
                        end
                    end
                end
            end
        end
    end
end

-- Check if two enemies have chatted recently with each other
function EnemyChatSystem._haveChattedRecently(entityId1, entityId2, enemyChat1, enemyChat2, currentTime)
    -- Check if entity1 has chatted with entity2 recently
    local lastChatTime1 = enemyChat1.chattedWith[entityId2]
    if lastChatTime1 and (currentTime - lastChatTime1) < enemyChat1.partnerCooldown then
        return true
    end
    
    -- Check if entity2 has chatted with entity1 recently
    local lastChatTime2 = enemyChat2.chattedWith[entityId1]
    if lastChatTime2 and (currentTime - lastChatTime2) < enemyChat2.partnerCooldown then
        return true
    end
    
    return false
end

-- Trigger a chat between two enemies
function EnemyChatSystem._triggerChat(entityId1, entityId2, enemyAI1, enemyAI2, 
                                     enemyType1, enemyType2, enemyChat1, enemyChat2, currentTime)
    -- Randomly decide who speaks first
    local firstId, firstAI, firstType, firstChat
    local secondId, secondAI, secondType, secondChat
    if math.random() < 0.5 then
        firstId, firstAI, firstType, firstChat = entityId1, enemyAI1, enemyType1, enemyChat1
        secondId, secondAI, secondType, secondChat = entityId2, enemyAI2, enemyType2, enemyChat2
    else
        firstId, firstAI, firstType, firstChat = entityId2, enemyAI2, enemyType2, enemyChat2
        secondId, secondAI, secondType, secondChat = entityId1, enemyAI1, enemyType1, enemyChat1
    end

    -- Get chat phrases
    local firstPhrase = EnemyChatData:GetRandomPhrase(firstType.enemyType, firstAI.state)
    local secondPhrase = EnemyChatData:GetRandomPhrase(secondType.enemyType, secondAI.state)
    if not firstPhrase or not secondPhrase then
        return -- No appropriate phrase found
    end

    -- Get models
    local firstModel = EntityManager.getComponent(firstId, "Model")
    local secondModel = EntityManager.getComponent(secondId, "Model")
    if not firstModel or not firstModel.part or not secondModel or not secondModel.part then
        return
    end

    -- First enemy chats immediately
    EnemyChatSystem._displayChatBubble(firstModel.part, firstPhrase)
    print("💬 Enemy", firstId, "said to", secondId, ":", firstPhrase)

    -- Second enemy chats after 0.5s delay
    task.delay(0.5, function()
        EnemyChatSystem._displayChatBubble(secondModel.part, secondPhrase)
        print("💬 Enemy", secondId, "responded to", firstId, ":", secondPhrase)
    end)

    -- Update chat cooldowns and tracking for both
    firstChat.lastChatTime = currentTime
    secondChat.lastChatTime = currentTime
    firstChat.chattedWith[secondId] = currentTime
    secondChat.chattedWith[firstId] = currentTime
    EntityManager.addComponent(firstId, "EnemyChat", firstChat)
    EntityManager.addComponent(secondId, "EnemyChat", secondChat)
end

-- Display chat bubble using Roblox's built-in chat system
function EnemyChatSystem._displayChatBubble(characterPart, message)
    local ChatService = game:GetService("Chat")
    local character = characterPart.Parent
    if character then
        local Head = character:FindFirstChild("Head")
        if Head then
            ChatService:Chat(Head, message)
        end
    end
end

-- Clean up tracking data when entity is destroyed
function EnemyChatSystem.cleanup(entityId)
    -- Clean up any references to this entity in other entities' chattedWith tables
    local allChatEntities = EntityManager.getEntitiesWithAll({"EnemyChat"})
    
    for _, otherEntityId in ipairs(allChatEntities) do
        if otherEntityId ~= entityId then
            local otherChat = EntityManager.getComponent(otherEntityId, "EnemyChat")
            if otherChat and otherChat.chattedWith[entityId] then
                otherChat.chattedWith[entityId] = nil
                EntityManager.addComponent(otherEntityId, "EnemyChat", otherChat)
            end
        end
    end
end

return EnemyChatSystem 