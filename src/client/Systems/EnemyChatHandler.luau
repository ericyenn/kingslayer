-- EnemyChatHandler.luau
-- Client-side chat system for enemies using Roblox ChatService

local ChatService = game:GetService("Chat")
local RunService = game:GetService("RunService")

local EnemyChatHandler = {}

-- Store active chat sessions
local activeChats = {} -- {entityId = startTime}

-- Initialize the chat handler
function EnemyChatHandler.Initialize()
    print("💬 EnemyChatHandler: Initializing with ChatService")
    
    -- Set up periodic check for talking enemies
    RunService.Heartbeat:Connect(EnemyChatHandler._update)
    
    print("✅ EnemyChatHandler: Initialized successfully")
end

-- Main update function
function EnemyChatHandler._update()
    local currentTime = tick()
    
    -- Check for enemies in talking state
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return end
    
    for _, folder in ipairs(enemiesFolder:GetChildren()) do
        local entityId = tonumber(folder.Name)
        if entityId then
            local aiState = folder:GetAttribute("AIState")
            if aiState == "talking" and not activeChats[entityId] then
                EnemyChatHandler._startChat(entityId, folder, currentTime)
            end
        end
    end
    
    -- Clean up expired chats
    for entityId, startTime in pairs(activeChats) do
        if currentTime - startTime >= 6.0 then -- 6 second chat duration
            activeChats[entityId] = nil
        end
    end
end

-- Start a chat for an enemy
function EnemyChatHandler._startChat(entityId, folder, currentTime)
    -- Get enemy model
    local enemyData = require(script.Parent.Parent.EnemyManager).getLocalEnemy(entityId)
    if not enemyData or not enemyData.model then
        return
    end
    
    -- Find nearby enemy to chat with
    local partnerId = EnemyChatHandler._findNearbyEnemy(entityId, folder)
    if not partnerId then
        return
    end
    
    -- DISABLED: Chat bubble functionality
    -- Generate and send chat messages
    -- local message = EnemyChatHandler._getRandomMessage()
    -- ChatService:Chat(enemyData.model, message, Enum.ChatColor.White)
    
    -- Mark as active chat (KEEP THIS - maintains state and animations)
    activeChats[entityId] = currentTime
    activeChats[partnerId] = currentTime
    
    print("💬 EnemyChatHandler: Started chat between enemies", entityId, "and", partnerId, "(bubbles disabled)")
end

-- Find a nearby enemy to chat with
function EnemyChatHandler._findNearbyEnemy(entityId, folder)
    local currentPosition = folder:GetAttribute("Position")
    if not currentPosition then return nil end
    
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    for _, otherFolder in ipairs(enemiesFolder:GetChildren()) do
        local otherEntityId = tonumber(otherFolder.Name)
        if otherEntityId and otherEntityId ~= entityId then
            local otherPosition = otherFolder:GetAttribute("Position")
            if otherPosition then
                local distance = (currentPosition - otherPosition).Magnitude
                if distance <= 8 then -- 8 studs chat range
                    return otherEntityId
                end
            end
        end
    end
    return nil
end

-- Get a random chat message
function EnemyChatHandler._getRandomMessage()
    local messages = {
        "Hey there!",
        "How's it going?",
        "Nice weather today!",
        "Did you see that?",
        "What's new?",
        "Pretty quiet around here...",
        "Have a good day!",
        "Stay safe out there!"
    }
    return messages[math.random(1, #messages)]
end

-- Clean up all chats (for shutdown)
function EnemyChatHandler.cleanup()
    activeChats = {}
end

return EnemyChatHandler 