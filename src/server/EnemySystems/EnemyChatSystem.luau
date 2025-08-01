-- EnemyChatSystem.luau
-- Handles enemy-to-enemy chat when they're close during idle/patrol states
-- Now a pure chat service - no state management, only conversation handling

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Import ECS modules
local EntityManager = require(ReplicatedStorage.Shared.EntityManager)
local EnemyChatData = require(ReplicatedStorage.Shared.EnemyChatData)

-- Import rotation utility for facing each other during conversations
local EnemyRotationUtility = require(script.Parent.EnemyRotationUtility)

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
    DEFAULT_CHAT_RANGE = 5, -- Default chat range in studs
    CHAT_CHANCE = 0.3, -- 30% chance to chat when conditions are met
}

-- Initialize system
function EnemyChatSystem.initialize()
    return true
end

-- Check if two enemies can chat (proximity and cooldown check)
function EnemyChatSystem.canEnemiesChat(entityId1, entityId2, currentTime)
    local enemyAI1 = EntityManager.getComponent(entityId1, "EnemyAI")
    local model1 = EntityManager.getComponent(entityId1, "Model")
    local enemyType1 = EntityManager.getComponent(entityId1, "EnemyType")
    local enemyChat1 = EntityManager.getComponent(entityId1, "EnemyChat")
    
    local enemyAI2 = EntityManager.getComponent(entityId2, "EnemyAI")
    local model2 = EntityManager.getComponent(entityId2, "Model")
    local enemyType2 = EntityManager.getComponent(entityId2, "EnemyType")
    local enemyChat2 = EntityManager.getComponent(entityId2, "EnemyChat")
    
    -- Check if both enemies exist and have required components
    if not enemyAI1 or not model1 or not enemyType1 or not enemyChat1 or
       not enemyAI2 or not model2 or not enemyType2 or not enemyChat2 then
        return false
    end
    
    -- Check if both enemies are in idle or patrol state
    if enemyAI1.state ~= "idle" and enemyAI1.state ~= "patrol" then
        return false
    end
    if enemyAI2.state ~= "idle" and enemyAI2.state ~= "patrol" then
        return false
    end
    
    -- Check if both enemies can chat
    if not enemyChat1.canChat or not enemyChat2.canChat then
        return false
    end
    
    -- Check chat cooldowns
    if currentTime - enemyChat1.lastChatTime < enemyChat1.chatCooldown then
        return false
    end
    if currentTime - enemyChat2.lastChatTime < enemyChat2.chatCooldown then
        return false
    end
    
    -- Check if they've chatted recently with each other
    if EnemyChatSystem._haveChattedRecently(entityId1, entityId2, enemyChat1, enemyChat2, currentTime) then
        return false
    end
    
    -- Check distance
    local distance = (model1.part.Position - model2.part.Position).Magnitude
    local chatRange = math.min(enemyChat1.chatRange or CONFIG.DEFAULT_CHAT_RANGE, 
                             enemyChat2.chatRange or CONFIG.DEFAULT_CHAT_RANGE)
    
    if distance > chatRange then
        return false
    end
    
    return true
end

-- Start a conversation between two enemies (called by AISystem)
function EnemyChatSystem.startConversation(entityId1, entityId2, currentTime)
    local enemyAI1 = EntityManager.getComponent(entityId1, "EnemyAI")
    local model1 = EntityManager.getComponent(entityId1, "Model")
    local enemyType1 = EntityManager.getComponent(entityId1, "EnemyType")
    local enemyChat1 = EntityManager.getComponent(entityId1, "EnemyChat")
    
    local enemyAI2 = EntityManager.getComponent(entityId2, "EnemyAI")
    local model2 = EntityManager.getComponent(entityId2, "Model")
    local enemyType2 = EntityManager.getComponent(entityId2, "EnemyType")
    local enemyChat2 = EntityManager.getComponent(entityId2, "EnemyChat")
    
    if not enemyAI1 or not model1 or not enemyType1 or not enemyChat1 or
       not enemyAI2 or not model2 or not enemyType2 or not enemyChat2 then
        print("⚠️ EnemyChatSystem: Missing components for conversation between", entityId1, "and", entityId2)
        return false
    end
    
    -- Roll for chat chance
    if math.random() > CONFIG.CHAT_CHANCE then
        print("🎲 EnemyChatSystem: Chat chance roll failed for", entityId1, "and", entityId2)
        return false
    end
    
    print("💬 EnemyChatSystem: Starting conversation between", entityId1, "and", entityId2)
    
    -- Trigger the chat (which will only show chat bubbles)
    EnemyChatSystem._triggerChat(entityId1, entityId2, enemyAI1, enemyAI2, 
                               enemyType1, enemyType2, enemyChat1, enemyChat2, currentTime)
    
    return true
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

    -- Get models for rotation
    local firstModel = EntityManager.getComponent(firstId, "Model")
    local secondModel = EntityManager.getComponent(secondId, "Model")
    if not firstModel or not firstModel.part or not secondModel or not secondModel.part then
        print("⚠️ EnemyChatSystem: Missing models for conversation")
        return
    end

    -- Rotate enemies to face each other
    print("🔄 EnemyChatSystem: Rotating enemies to face each other")
    local rotation1 = EnemyRotationUtility.rotateToFaceTarget(firstId, secondModel.part.Position, true)
    local rotation2 = EnemyRotationUtility.rotateToFaceTarget(secondId, firstModel.part.Position, true)
    print("🔄 EnemyChatSystem: Rotation results - First enemy:", rotation1, "Second enemy:", rotation2)
    
    -- Small delay to ensure rotation is complete before chat
    task.wait(0.1)

    -- Display one chat bubble for each enemy
    local firstPhrase = EnemyChatData:GetRandomPhrase(firstType.enemyType, "talking")
    if firstPhrase then
        EnemyChatSystem._displayChatBubble(firstModel.part, firstPhrase)
        print("💬 Enemy", firstId, "said:", firstPhrase)
    else
        print("   ⚠️ No phrase found for first enemy type:", firstType.enemyType)
    end
    
    -- Second enemy responds after a short delay
    task.delay(1.0, function()
        local secondPhrase = EnemyChatData:GetRandomPhrase(secondType.enemyType, "talking")
        if secondPhrase then
            EnemyChatSystem._displayChatBubble(secondModel.part, secondPhrase)
            print("💬 Enemy", secondId, "responded:", secondPhrase)
        else
            print("   ⚠️ No phrase found for second enemy type:", secondType.enemyType)
        end
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
    
    -- Find the character (model) that contains this part
    local character = characterPart
    if characterPart.Parent and characterPart.Parent:IsA("Model") then
        character = characterPart.Parent
    end
    
    if character then
        -- Look for Head part in the character
        local Head = character:FindFirstChild("Head")
        if Head then
            ChatService:Chat(Head, message)
            return true
        else
            -- Try to find any part that could work for chat
            local anyPart = character:FindFirstChildWhichIsA("BasePart")
            if anyPart then
                ChatService:Chat(anyPart, message)
                return true
            else
                print("   ❌ No suitable part found for chat in character:", character.Name)
                return false
            end
        end
    else
        print("   ❌ No character found for chat bubble")
        return false
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