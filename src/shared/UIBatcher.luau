-- UI Batcher - Reduces frame drops by batching UI update operations
local RunService = game:GetService("RunService")
local FrameBudgetManager = require(script.Parent.FrameBudgetManager)

local UIBatcher = {}

-- Configuration
local UPDATE_INTERVAL = 1/30 -- 30fps UI updates
local MAX_UPDATES_PER_FRAME = 5

-- Batching state
local pendingUpdates = {}
local updateConnections = {
    heartbeat = nil :: RBXScriptConnection?
}
local lastUpdateTime = 0

-- ENHANCED: Queue a UI update with validation and memory management
function UIBatcher.queueUpdate(uiObject, updateFunction, priority)
    priority = priority or 1 -- Lower number = higher priority
    
    -- ENHANCED: Validate inputs
    if not uiObject then
        warn("UIBATCHER WARNING: Attempted to queue update for nil uiObject")
        return
    end
    
    if type(updateFunction) ~= "function" then
        warn("UIBATCHER WARNING: updateFunction must be a function")
        return
    end
    
    -- ENHANCED: Prevent memory leaks from too many pending updates
    local pendingCount = 0
    for _ in pairs(pendingUpdates) do
        pendingCount += 1
    end
    
    if pendingCount >= 100 then
        warn("UIBATCHER WARNING: Too many pending updates (", pendingCount, ") - forcing flush")
        UIBatcher.flushAll()
    end
    
    local updateId = tostring(uiObject) .. "_" .. tostring(tick())
    
    pendingUpdates[updateId] = {
        uiObject = uiObject,
        updateFunction = updateFunction,
        priority = priority,
        timestamp = tick()
    }
    
    -- Start processing if not already running
    if not updateConnections.heartbeat then
        UIBatcher.startProcessing()
    end
end

-- Queue a hotbar-specific update with batching
function UIBatcher.queueHotbarUpdate(updateFunction, priority)
    priority = priority or 2 -- Medium priority for hotbar
    
    -- Use a fixed key for hotbar to ensure only one update is queued
    local updateId = "hotbar_update"
    
    pendingUpdates[updateId] = {
        uiObject = "hotbar",
        updateFunction = updateFunction,
        priority = priority,
        timestamp = tick()
    }
    
    -- Start processing if not already running
    if not updateConnections.heartbeat then
        UIBatcher.startProcessing()
    end
end

-- Start processing updates
function UIBatcher.startProcessing()
    if updateConnections.heartbeat then
        return -- Already running
    end
    
    updateConnections.heartbeat = RunService.Heartbeat:Connect(function()
        UIBatcher.processUpdates()
    end)
end

-- Stop processing updates
function UIBatcher.stopProcessing()
    if updateConnections.heartbeat then
        updateConnections.heartbeat:Disconnect()
        updateConnections.heartbeat = nil
    end
end

-- Process pending updates with frame budgeting
function UIBatcher.processUpdates()
    local currentTime = tick()
    
    -- Throttle update frequency
    if currentTime - lastUpdateTime < UPDATE_INTERVAL then
        return
    end
    
    lastUpdateTime = currentTime
    
    -- Get updates sorted by priority
    local sortedUpdates = {}
    for updateId, update in pairs(pendingUpdates) do
        table.insert(sortedUpdates, {id = updateId, update = update})
    end
    
    -- Sort by priority (lower number = higher priority)
    table.sort(sortedUpdates, function(a, b)
        return a.update.priority < b.update.priority
    end)
    
    -- Process updates with frame budgeting
    local processed = 0
    for _, updateData in ipairs(sortedUpdates) do
        if processed >= MAX_UPDATES_PER_FRAME then
            break -- Hit frame limit
        end
        
        -- Check frame budget before processing
        FrameBudgetManager.yieldIfNeeded(0.003) -- 3ms estimate for UI update
        
        local updateId = updateData.id
        local update = updateData.update
        
        -- Execute the update
        local success, errorMsg = pcall(function()
            update.updateFunction()
        end)
        
        if success then
            -- Remove completed update
            pendingUpdates[updateId] = nil
            processed += 1
        else
            warn("UIBatcher: Update failed for", updateId, ":", errorMsg)
            -- Remove failed update
            pendingUpdates[updateId] = nil
        end
    end
    
    -- Stop processing if no more updates
    if next(pendingUpdates) == nil then
        UIBatcher.stopProcessing()
    end
end

-- Force process all pending updates immediately
function UIBatcher.flushAll()
    for updateId, update in pairs(pendingUpdates) do
        local success, errorMsg = pcall(function()
            update.updateFunction()
        end)
        
        if not success then
            warn("UIBatcher: Flush failed for", updateId, ":", errorMsg)
        end
        
        pendingUpdates[updateId] = nil
    end
    
    UIBatcher.stopProcessing()
end

-- Get pending update count
function UIBatcher.getPendingCount()
    local count = 0
    for _ in pairs(pendingUpdates) do
        count += 1
    end
    return count
end

-- Clear all pending updates
function UIBatcher.clearAll()
    pendingUpdates = {}
    UIBatcher.stopProcessing()
end

-- Cleanup method
function UIBatcher.cleanup()
    UIBatcher.clearAll()
end

return UIBatcher 