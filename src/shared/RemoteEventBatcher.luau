-- RemoteEvent Batcher - Reduces network overhead by batching multiple events
local RunService = game:GetService("RunService")

local RemoteEventBatcher = {}

-- Configuration
local BATCH_INTERVAL = 1/30 -- 30fps batching (33ms)
local MAX_BATCH_SIZE = 10 -- Maximum events per batch

-- Private variables
local pendingBatches: {[RemoteEvent]: {{[string]: any}}} = {}
local batchConnections: {[RemoteEvent]: thread} = {}

-- Send a batch of events
local function sendBatch(remote: RemoteEvent, events: {{[string]: any}})
    if #events == 0 then return end
    
    if #events == 1 then
        -- Single event, send directly for lower latency
        remote:FireAllClients(events[1])
    else
        -- Multiple events, send as batch
        remote:FireAllClients({
            batchedEvents = events,
            isBatch = true
        })
    end
end

-- Process pending batches for a specific RemoteEvent
local function processBatch(remote: RemoteEvent)
    local batch = pendingBatches[remote]
    if batch and #batch > 0 then
        sendBatch(remote, batch)
        pendingBatches[remote] = {} -- Clear the batch
    end
end

-- ENHANCED: Add an event to the batch queue with memory management
function RemoteEventBatcher.queueEvent(remote: RemoteEvent, eventData: {[string]: any})
    -- Validate remote exists and is still valid
    if not remote or not remote.Parent then
        warn("BATCHER WARNING: Attempted to queue event for invalid remote")
        return
    end
    
    -- Initialize batch for this remote if needed
    if not pendingBatches[remote] then
        pendingBatches[remote] = {}
        
        print("BATCHER DEBUG: Initializing batch for remote:", remote.Name)
        
        -- Set up batching timer for this remote
        batchConnections[remote] = task.spawn(function()
            local batchStartTime = tick()
            while pendingBatches[remote] do
                task.wait(BATCH_INTERVAL)
                
                -- ENHANCED: Check if remote is still valid
                if not remote or not remote.Parent then
                    warn("BATCHER WARNING: Remote became invalid, stopping batch processing")
                    break
                end
                
                processBatch(remote)
                
                -- ENHANCED: Prevent runaway batch connections
                local batchDuration = tick() - batchStartTime
                if batchDuration > 300 then -- 5 minutes max
                    print("BATCHER DEBUG: Batch connection timeout after", batchDuration, "seconds")
                    break
                end
            end
            
            -- Cleanup when done
            if batchConnections[remote] then
                batchConnections[remote] = nil
            end
        end)
    end
    
    -- ENHANCED: Prevent memory leaks from oversized batches
    if #pendingBatches[remote] >= MAX_BATCH_SIZE * 2 then
        warn("BATCHER WARNING: Batch size exceeded limit, forcing immediate send")
        processBatch(remote)
    end
    
    -- Add event to batch
    table.insert(pendingBatches[remote], eventData)
    
    -- Send immediately if batch is full
    if #pendingBatches[remote] >= MAX_BATCH_SIZE then
        processBatch(remote)
    end
end

-- Send all pending events immediately (for urgent events)
function RemoteEventBatcher.flushAll()
    for remote, _ in pairs(pendingBatches) do
        processBatch(remote)
    end
end

-- Send pending events for a specific RemoteEvent immediately
function RemoteEventBatcher.flush(remote: RemoteEvent)
    processBatch(remote)
end

-- Clean up batching for a specific RemoteEvent
function RemoteEventBatcher.cleanup(remote: RemoteEvent)
    -- Send any remaining events
    processBatch(remote)
    
    -- Clean up
    if batchConnections[remote] then
        task.cancel(batchConnections[remote])
        batchConnections[remote] = nil
    end
    pendingBatches[remote] = nil
end

-- Clean up all batching
function RemoteEventBatcher.cleanupAll()
    for remote, _ in pairs(pendingBatches) do
        RemoteEventBatcher.cleanup(remote)
    end
end

return RemoteEventBatcher 