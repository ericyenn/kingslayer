-- Frame Budget Manager - Prevents performance spikes by limiting operations per frame
local RunService = game:GetService("RunService")

local FrameBudgetManager = {}

-- Configuration
local MAX_FRAME_TIME = 1/60 * 0.8 -- Use 80% of 60fps frame time (13.33ms)
local MIN_YIELD_TIME = 1/240 -- Minimum time between operations

-- Private variables
local currentFrameBudget = MAX_FRAME_TIME
local lastFrameStart = 0

-- Reset frame budget at the start of each frame
local function resetFrameBudget()
    lastFrameStart = tick()
    currentFrameBudget = MAX_FRAME_TIME
end

-- Initialize frame budget tracking
RunService.Heartbeat:Connect(resetFrameBudget)

-- Check if we have budget remaining for an operation
function FrameBudgetManager.hasBudget(estimatedTime: number?): boolean
    local timeUsed = tick() - lastFrameStart
    local timeLeft = currentFrameBudget - timeUsed
    local requiredTime = estimatedTime or MIN_YIELD_TIME
    
    return timeLeft >= requiredTime
end

-- Yield if we're running out of frame budget
function FrameBudgetManager.yieldIfNeeded(estimatedTime: number?)
    if not FrameBudgetManager.hasBudget(estimatedTime) then
        task.wait() -- Yield to next frame
    end
end

-- Execute a batch of operations with frame budgeting
function FrameBudgetManager.executeBatch(operations: {() -> ()}, operationTime: number?)
    local timePerOp = operationTime or MIN_YIELD_TIME
    
    for _, operation in ipairs(operations) do
        -- Check if we have budget for this operation
        if not FrameBudgetManager.hasBudget(timePerOp) then
            task.wait() -- Yield to next frame
        end
        
        -- Execute the operation
        operation()
    end
end

-- Execute operations with a maximum count per frame
function FrameBudgetManager.executeWithLimit(operations: {() -> ()}, maxPerFrame: number)
    local executed = 0
    
    for _, operation in ipairs(operations) do
        if executed >= maxPerFrame then
            task.wait() -- Yield to next frame
            executed = 0
        end
        
        operation()
        executed += 1
    end
end

return FrameBudgetManager 