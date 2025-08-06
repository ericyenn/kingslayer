-- Tool system with shared action registry for different tool types
local ToolSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ActionRegistry = require(ReplicatedStorage.Shared.ActionRegistry)
local ActionConstants = require(ReplicatedStorage.Shared.ActionConstants)
local SystemManager = require(ReplicatedStorage.Shared.SystemManager)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

-- Import EnemyManager to get entity ID from enemy models
local EnemyManager = require(script.Parent.Parent.EnemyManager)

-- Create tool-specific action registry
local toolRegistry = ActionRegistry.new("ToolSystem")

-- Helper function to get enemy entity ID from hit part
local function getEnemyEntityIdFromHitPart(hitPart)
    if not hitPart then return nil end
    
    -- Look for enemy model in the hierarchy
    local model = hitPart.Parent
    while model and model ~= workspace do
        -- Check if this is an enemy model
        local CollectionService = game:GetService("CollectionService")
        if CollectionService:HasTag(model, "Enemies") then
            -- This is an enemy model, find its entity ID
            local allLocalEnemies = EnemyManager.getAllLocalEnemies()
            for entityId, enemyData in pairs(allLocalEnemies) do
                if enemyData.model == model then
                    return entityId
                end
            end
        end
        model = model.Parent
    end
    
    return nil
end

-- Helper function to highlight enemy red
local function highlightEnemyRed(enemyModel)
    if not enemyModel then return end
    
    -- Create a red highlight effect
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Red
    highlight.OutlineTransparency = 1 -- Make outline invisible
    highlight.FillTransparency = 0.3
    highlight.Parent = enemyModel
    
    -- Remove highlight after 0.2 seconds
    task.delay(0.2, function()
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end)
end

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
        
        -- Check if target is a breakable object (has "Breakable" tag)
        local CollectionService = game:GetService("CollectionService")
        local isBreakable = CollectionService:HasTag(target, "Breakable") or 
                           (target.Parent and CollectionService:HasTag(target.Parent, "Breakable"))
        
        if isBreakable then
            -- Get the equipped tool to validate compatibility
            local character = player.Character
            local equippedTool = character and character:FindFirstChildOfClass("Tool")
            
            -- Check if tool is correct for this breakable (TAG-BASED VALIDATION ONLY)
            local isToolCorrect = false
            if equippedTool then
                -- Get the required tool type from the breakable's tag
                local CollectionService = game:GetService("CollectionService")
                local requiredTool = nil
                
                -- Check breakable type tags
                if CollectionService:HasTag(target, "Rock") or (target.Parent and CollectionService:HasTag(target.Parent, "Rock")) then
                    requiredTool = "pickaxe"
                elseif CollectionService:HasTag(target, "Tree") or (target.Parent and CollectionService:HasTag(target.Parent, "Tree")) then
                    requiredTool = "axe"
                elseif CollectionService:HasTag(target, "Crystal") or (target.Parent and CollectionService:HasTag(target.Parent, "Crystal")) then
                    requiredTool = "pickaxe"
                end
                
                -- Debug logging
                print("  - Breakable type detected:", requiredTool)
                print("  - Equipped tool:", equippedTool.Name)
                
                -- Check if equipped tool has the correct tag
                local toolTags = CollectionService:GetTags(equippedTool)
                print("  - Tool tags:", table.concat(toolTags, ", "))
                
                if requiredTool == "axe" and CollectionService:HasTag(equippedTool, "Axe") then
                    isToolCorrect = true
                    print("  - Tool validation: Axe ✓")
                elseif requiredTool == "pickaxe" and CollectionService:HasTag(equippedTool, "Pickaxe") then
                    isToolCorrect = true
                    print("  - Tool validation: Pickaxe ✓")
                else
                    print("  - Tool validation: ✗ (required:", requiredTool, ", has tags:", table.concat(toolTags, ", "), ")")
                end
            else
                print("  - No equipped tool found")
            end
            
            if isToolCorrect then
                -- Correct tool: play hit sound and send to server
                if _G.AudioSystem then
                    if isCritical then
                        -- Delay critical hit sound by 0.1 seconds after timing success
                        task.wait(0.1)
                        _G.AudioSystem:PlayCriticalHitSound()
                    else
                        _G.AudioSystem:PlayHitSuccessSound()
                    end
                end
                
                -- Server will handle shake effect via remote event
                
                local breakableDamage = actionData.breakableDamage or finalDamage
                RemoteEvents.ApplyBreakableDamage:FireServer(target, breakableDamage)
                print("  - Correct tool, sent damage request to server")
            else
                -- Wrong tool: miss feedback, no server request
                print("  - Wrong tool for this breakable")
                if _G.AudioSystem then
                    _G.AudioSystem:PlaySwingMissSound()
                end
                return -- Don't proceed with damage
            end
        else
            -- Check if target is an enemy (has "Enemies" tag)
            local isEnemy = CollectionService:HasTag(target, "Enemies") or 
                           (target.Parent and CollectionService:HasTag(target.Parent, "Enemies"))
            
            if isEnemy then
                -- Get enemy entity ID from hit part
                local enemyEntityId = getEnemyEntityIdFromHitPart(target)
                
                if enemyEntityId then
                    -- Check if enemy is dead
                    local enemyFolder = workspace:FindFirstChild("Enemies"):FindFirstChild(tostring(enemyEntityId))
                    if enemyFolder and enemyFolder:GetAttribute("Dead") == true then
                        print("  - Enemy is dead, cannot attack")
                        if _G.AudioSystem then
                            _G.AudioSystem:PlaySwingMissSound()
                        end
                        return
                    end
                    
                    -- Find the enemy model for highlighting
                    local allLocalEnemies = EnemyManager.getAllLocalEnemies()
                    local enemyData = allLocalEnemies[enemyEntityId]
                    local enemyModel = enemyData and enemyData.model
                    
                    -- Immediately highlight enemy red
                    if enemyModel then
                        highlightEnemyRed(enemyModel)
                        print("  - Highlighted enemy red for immediate feedback")
                    end
                    
                    -- Play hit sound for enemies
                    if _G.AudioSystem then
                        if isCritical then
                            -- Delay critical hit sound by 0.1 seconds after timing success
                            task.wait(0.1)
                            _G.AudioSystem:PlayCriticalHitSound()
                        else
                            _G.AudioSystem:PlayHitSuccessSound()
                        end
                    end
                    
                    -- Send damage request to server with entity ID
                    RemoteEvents.ApplyDamage:FireServer(enemyEntityId, weaponName, finalDamage)
                    print("  - Sent enemy damage request to server with entity ID:", enemyEntityId)
                else
                    print("  - Could not find enemy entity ID for hit target")
                    if _G.AudioSystem then
                        _G.AudioSystem:PlaySwingMissSound()
                    end
                end
            else
                -- No valid target found - play miss sound
                print("  - No valid target found (not breakable or enemy)")
                if _G.AudioSystem then
                    _G.AudioSystem:PlaySwingMissSound()
                end
            end
        end
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