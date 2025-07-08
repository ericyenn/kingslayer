-- Tool system with shared action registry for different tool types
local ToolSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ActionRegistry = require(ReplicatedStorage.Shared.ActionRegistry)
local ActionConstants = require(ReplicatedStorage.Shared.ActionConstants)
local SystemManager = require(ReplicatedStorage.Shared.SystemManager)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

-- Create tool-specific action registry
local toolRegistry = ActionRegistry.new("ToolSystem")

-- Register generic tool attack action (all tools use this)
toolRegistry:RegisterAction(ActionConstants.Tool.ATTACK, function(player, itemDef, target, actionData, attackType)
    local baseDamage = actionData.damage or 10
    local chargeMultiplier = actionData.chargeMultiplier or 1.0
    local criticalMultiplier = actionData.criticalMultiplier or 3.0 -- Critical attacks do 3x damage
    local weaponName = itemDef.name or "Tool"
    
    -- Calculate final damage based on attack type
    local finalDamage = baseDamage
    local isCharged = attackType == "charged"
    local isCritical = attackType == "critical"
    
    if isCritical then
        finalDamage = math.floor(baseDamage * criticalMultiplier)
    elseif isCharged then
        finalDamage = math.floor(baseDamage * chargeMultiplier)
    end
    
    -- Display attack type with appropriate styling
    if isCritical then
        print("💥 CRITICAL", weaponName, "Attack!")
        print("  - Base Damage:", baseDamage)
        print("  - Critical Multiplier:", criticalMultiplier .. "x")
        print("  - Final Damage:", finalDamage)
    elseif isCharged then
        print("⚔️", weaponName, "CHARGED Attack!")
        print("  - Base Damage:", baseDamage)
        print("  - Charge Multiplier:", chargeMultiplier .. "x")
        print("  - Final Damage:", finalDamage)
    else
        print("⚔️", weaponName, "Attack!")
        print("  - Final Damage:", finalDamage)
    end
    
    if target then
        print("  - Attacking target:", target:GetFullName())
        
        -- Play appropriate hit sound based on attack type
        if _G.AudioSystem then
            if isCritical then
                -- Delay critical hit sound by 0.1 seconds after timing success
                task.wait(0.1)
                _G.AudioSystem:PlayCriticalHitSound()
            else
                _G.AudioSystem:PlayHitSuccessSound() -- Random hit success sound
            end
        end
        
        -- Send damage request to server
        RemoteEvents.ApplyDamage:FireServer(target, weaponName, finalDamage)
        print("  - Sent damage request to server")
    else
        print("  - Swinging", weaponName, "in the air")
        
        -- Play swing miss sound when no target is hit
        if _G.AudioSystem then
            _G.AudioSystem:PlaySwingMissSound()
        end
    end
end)

-- Set default action for tools without specific actions
toolRegistry:SetDefaultAction(function(player, itemDef, target, actionData)
    local displayMessage = actionData and actionData.displayMessage or "Generic tool use"
    
    print("⚡ Tool Action!", displayMessage)
    
    if target then
        print("  - Using", itemDef.name, "on", target:GetFullName())
    else
        print("  - Using", itemDef.name, "in general")
    end
end)

function ToolSystem:Initialize()
    SystemManager.RegisterSystem("ToolSystem", self)
    print("Tool system initialized with", toolRegistry:GetActionCount(), "tool actions")
end

function ToolSystem:Use(itemDef, player, target, attackType)
    attackType = attackType or "normal" -- Default to normal attack
    print("ToolSystem: Use called for", itemDef.name, "- Attack Type:", attackType)
    
    local actionType = itemDef.actionType or ActionConstants.Tool.DEFAULT
    local actionData = itemDef.actionData or {}
    
    print("  - Action Type:", actionType)
    print("  - Action Data:", actionData)
    
    if target then
        print("  - Target:", target:GetFullName())
    else
        print("  - No target was hit.")
    end
    
    -- Execute using shared registry (this will trigger the animation)
    toolRegistry:ExecuteAction(actionType, player, itemDef, target, actionData, attackType)
end

-- Legacy methods for backward compatibility
function ToolSystem:ExecuteAction(actionName, player, itemDef, target, actionData)
    return toolRegistry:ExecuteAction(actionName, player, itemDef, target, actionData)
end

function ToolSystem:RegisterAction(actionName, actionFunction)
    return toolRegistry:RegisterAction(actionName, actionFunction)
end

function ToolSystem:GetRegisteredActions()
    return toolRegistry:GetRegisteredActions()
end

return ToolSystem 