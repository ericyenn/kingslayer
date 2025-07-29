--[[
EnemyRotationUtility.luau

Utility module for handling enemy rotation to face targets.
Provides smooth rotation functions for different enemy types.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Import custom ECS modules
local EntityManager = require(ReplicatedStorage.Shared.EntityManager)

local EnemyRotationUtility = {}

-- Configuration
local ROTATION_CONFIG = {
    ROTATION_SPEED = 5, -- Radians per second
    SMOOTH_ROTATION = true, -- Use tweening for smooth rotation
    ROTATION_THRESHOLD = 0.1, -- Minimum angle difference to trigger rotation
    MAX_ROTATION_DISTANCE = 50 -- Only rotate if target is within this distance
}

-- Rotate enemy to face target position
function EnemyRotationUtility.rotateToFaceTarget(entityId, targetPosition, instant)
    local model = EntityManager.getComponent(entityId, "Model")
    if not model or not model.part then
        return false
    end
    
    local enemyPosition = model.part.Position
    local distance = (enemyPosition - targetPosition).Magnitude
    
    -- Don't rotate if target is too far away
    if distance > ROTATION_CONFIG.MAX_ROTATION_DISTANCE then
        return false
    end
    
    -- Calculate the direction to face (only on X and Z axis - no Y rotation)
    local direction = (targetPosition - enemyPosition).Unit
    -- Zero out the Y component to keep enemy upright
    direction = Vector3.new(direction.X, 0, direction.Z).Unit
    local targetCFrame = CFrame.lookAt(enemyPosition, enemyPosition + direction)
    
    -- Get current rotation
    local currentCFrame = model.part.CFrame
    local currentLookVector = currentCFrame.LookVector
    local targetLookVector = targetCFrame.LookVector
    
    -- Check if rotation is needed (avoid unnecessary rotations)
    local dotProduct = currentLookVector:Dot(targetLookVector)
    local angleDifference = math.acos(math.clamp(dotProduct, -1, 1))
    
    if angleDifference < ROTATION_CONFIG.ROTATION_THRESHOLD then
        return false -- Already facing target
    end
    
    if instant then
        -- Instant rotation
        model.part.CFrame = targetCFrame
        return true
    elseif ROTATION_CONFIG.SMOOTH_ROTATION then
        -- Smooth rotation using tweening
        local tweenInfo = TweenInfo.new(
            angleDifference / ROTATION_CONFIG.ROTATION_SPEED,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.Out
        )
        
        local tween = TweenService:Create(model.part, tweenInfo, {
            CFrame = targetCFrame
        })
        
        tween:Play()
        return true
    else
        -- Direct rotation without tweening
        model.part.CFrame = targetCFrame
        return true
    end
end

-- Rotate enemy to face player during attack
function EnemyRotationUtility.rotateForAttack(entityId, playerData, instant)
    if not playerData or not playerData.player or not playerData.player.Character then
        return false
    end
    
    local humanoidRootPart = playerData.player.Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return false
    end
    
    return EnemyRotationUtility.rotateToFaceTarget(entityId, humanoidRootPart.Position, instant)
end

-- Rotate enemy to face player during chase (smoother)
function EnemyRotationUtility.rotateForChase(entityId, playerData)
    return EnemyRotationUtility.rotateForAttack(entityId, playerData, false)
end

-- Rotate enemy to face player during attack (instant for responsiveness)
function EnemyRotationUtility.rotateForAttackInstant(entityId, playerData)
    return EnemyRotationUtility.rotateForAttack(entityId, playerData, true)
end

-- Check if enemy is facing target (for debugging)
function EnemyRotationUtility.isFacingTarget(entityId, targetPosition, tolerance)
    tolerance = tolerance or 0.3 -- Default tolerance in radians
    
    local model = EntityManager.getComponent(entityId, "Model")
    if not model or not model.part then
        return false
    end
    
    local enemyPosition = model.part.Position
    local direction = (targetPosition - enemyPosition).Unit
    -- Zero out the Y component to match the rotation logic
    direction = Vector3.new(direction.X, 0, direction.Z).Unit
    local currentLookVector = model.part.CFrame.LookVector
    
    local dotProduct = currentLookVector:Dot(direction)
    local angleDifference = math.acos(math.clamp(dotProduct, -1, 1))
    
    return angleDifference <= tolerance
end

return EnemyRotationUtility 