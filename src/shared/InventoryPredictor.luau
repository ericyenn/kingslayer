-- Inventory Prediction System - Provides immediate feedback while maintaining server authority
local InventoryPredictor = {}

-- Prediction state
local predictedOperations = {}
local operationIdCounter = 1

-- Configuration
local PREDICTION_TIMEOUT = 5.0 -- Seconds before prediction is considered failed

-- Generate unique operation ID
local function generateOperationId()
    local id = "pred_" .. operationIdCounter
    operationIdCounter += 1
    return id
end

-- Validate if prediction should be applied
local function canPredict(operation, ...)
    local args = {...}
    
    if operation == "pickup_to_inventory" then
        local object, slot = args[1], args[2]
        return object and object.Parent and slot and slot >= 1 and slot <= 10
    elseif operation == "drop_from_inventory" then
        local slot = args[1]
        return slot and slot >= 1 and slot <= 10
    elseif operation == "equip_slot" then
        local slot = args[1]
        return slot == nil or (slot >= 1 and slot <= 10)
    elseif operation == "swap_slots" then
        local slot1, slot2 = args[1], args[2]
        return slot1 and slot2 and slot1 >= 1 and slot1 <= 10 and slot2 >= 1 and slot2 <= 10
    end
    
    return false
end

-- Apply prediction locally
function InventoryPredictor.predict(operation, ...)
    local args = {...}
    
    -- Check if we can predict this operation
    if not canPredict(operation, ...) then
        return nil, "Cannot predict operation"
    end
    
    -- Generate operation ID
    local operationId = generateOperationId()
    
    -- Store prediction
    predictedOperations[operationId] = {
        operation = operation,
        args = args,
        timestamp = tick(),
        applied = false
    }
    
    -- Apply prediction optimistically
    local success, result = InventoryPredictor.applyPrediction(operationId, operation, args)
    
    if success then
        predictedOperations[operationId].applied = true
        return operationId, result
    else
        -- Remove failed prediction
        predictedOperations[operationId] = nil
        return nil, result
    end
end

-- Apply prediction to local state
function InventoryPredictor.applyPrediction(operationId, operation, args)
    -- Get current inventory system
    local InventorySystem = _G.InventorySystem
    if not InventorySystem then
        return false, "InventorySystem not available"
    end
    
    local inventory = InventorySystem:GetInventory()
    local equippedSlot = InventorySystem:GetEquippedSlot()
    
    if operation == "pickup_to_inventory" then
        local object, slot = args[1], args[2]
        
        -- Check if slot is empty
        if inventory[slot] then
            return false, "Slot already occupied"
        end
        
        -- Predict pickup
        return true, {
            type = "pickup",
            slot = slot,
            object = object
        }
        
    elseif operation == "drop_from_inventory" then
        local slot = args[1]
        
        -- Check if slot has item
        if not inventory[slot] then
            return false, "Slot is empty"
        end
        
        -- Predict drop
        return true, {
            type = "drop",
            slot = slot,
            item = inventory[slot]
        }
        
    elseif operation == "equip_slot" then
        local slot = args[1]
        
        -- Predict equip/unequip
        return true, {
            type = "equip",
            previousSlot = equippedSlot,
            newSlot = slot
        }
        
    elseif operation == "swap_slots" then
        local slot1, slot2 = args[1], args[2]
        
        -- Predict swap
        return true, {
            type = "swap",
            slot1 = slot1,
            slot2 = slot2,
            item1 = inventory[slot1],
            item2 = inventory[slot2]
        }
    end
    
    return false, "Unknown operation"
end

-- Confirm prediction when server responds
function InventoryPredictor.confirm(operationId)
    local prediction = predictedOperations[operationId]
    if prediction then
        predictedOperations[operationId] = nil
        return true
    end
    return false
end

-- Rollback prediction if server rejects
function InventoryPredictor.rollback(operationId, reason)
    local prediction = predictedOperations[operationId]
    if not prediction or not prediction.applied then
        return false
    end
    
    warn("Rolling back prediction", operationId, ":", reason or "Server rejected")
    
    -- Get current inventory system
    local InventorySystem = _G.InventorySystem
    if not InventorySystem then
        return false
    end
    
    -- Rollback based on operation type
    local operation = prediction.operation
    local args = prediction.args
    
    if operation == "pickup_to_inventory" then
        -- Remove predicted item from inventory
        local slot = args[2]
        local inventory = InventorySystem:GetInventory()
        inventory[slot] = nil
        
    elseif operation == "drop_from_inventory" then
        -- Restore predicted item to inventory
        local slot = args[1]
        -- Note: We'd need to store the original item data for full rollback
        
    elseif operation == "equip_slot" then
        -- Restore previous equipped slot
        -- This would require more complex state tracking
        
    end
    
    -- Update UI
    InventorySystem:UpdateHotbarUI()
    
    -- Clean up prediction
    predictedOperations[operationId] = nil
    return true
end

-- Clean up expired predictions
function InventoryPredictor.cleanupExpired()
    local currentTime = tick()
    
    for operationId, prediction in pairs(predictedOperations) do
        if currentTime - prediction.timestamp > PREDICTION_TIMEOUT then
            warn("Prediction timed out:", operationId)
            InventoryPredictor.rollback(operationId, "Timeout")
        end
    end
end

-- Get pending predictions
function InventoryPredictor.getPendingCount()
    local count = 0
    for _ in pairs(predictedOperations) do
        count += 1
    end
    return count
end

-- Clear all predictions (for debugging)
function InventoryPredictor.clearAll()
    predictedOperations = {}
end

return InventoryPredictor 