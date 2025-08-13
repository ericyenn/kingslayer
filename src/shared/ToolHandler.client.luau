-- This script runs on the client and is attached to each tool when equipped.
-- It handles the "use" action (left-click) and dispatches to the correct system based on category.

local Tool = script.Parent
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

print("DEBUG: ToolHandler script starting for tool:", Tool.Name)

-- Shared Modules
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local Categories = require(ReplicatedStorage.Shared.ItemCategory)
local HitboxSystem = require(ReplicatedStorage.Shared.HitboxSystem)

-- Client Systems - Access through StarterPlayerScripts
local player = Players.LocalPlayer
local ClientSystems = player.PlayerScripts.Client.Systems
local ToolSystem = require(ClientSystems.ToolSystem)
local ArmorSystem = require(ClientSystems.ArmorSystem)
local FunctionalSystem = require(ClientSystems.FunctionalSystem)

local camera = workspace.CurrentCamera

-- Debounce to prevent spamming the use action
local debounce = false
local DEBOUNCE_TIME = 0.1 -- 100ms (minimum UI debounce)

-- Charged attack configuration
local CHARGE_CONFIG = {
    CHARGE_THRESHOLD = 1.5, -- Seconds to hold for charged attack
}

-- Charge state tracking
local isCharging = false
local chargeStartTime = 0
local chargeConnection = nil
local isToolEquipped = false
local isCriticalWindowActive = false -- Track if critical window is open
local chargeAnimationConnection = nil -- Track charge animation connection

-- R6 Animation system for charged attacks
local R6_ANIMATION = {
    MAX_ANGLE = 120, -- degrees (0° to 120° overhead swing)
    PHASES = {
        {duration = 0.5, progress = 0.6}, -- Fast phase: 60% of angle in first 0.5s
        {duration = 0.5, progress = 0.3}, -- Medium phase: 30% of angle in next 0.5s  
        {duration = 0.5, progress = 0.1}, -- Slow phase: 10% of angle in final 0.5s
    }
}

-- Animation state tracking
local originalRightShoulderC0 = nil
local currentRightShoulder = nil
local lastAngleUpdate = 0

-- Animation configuration
local SWING_ANIMATION_ID = "rbxassetid://110625725642736" -- Custom swing animation

-- Shape cast configuration - easy to adjust
local SHAPE_CAST_CONFIG = {
    radius = Vector3.new(2, 5, 2), -- Size of the detection area (player-sized: 2 wide, 5 tall, 2 deep)
    distance = 1, -- Distance in front of player (closer for more precise combat)
    ignoreFloor = true, -- Whether to ignore floor/ground
    visualDuration = 0.1, -- How long visual feedback lasts
}

print("DEBUG: ToolHandler modules loaded, setting up functions...")

local function createVisualShapeCast(centerPosition, radius, color, hasHit, orientation)
    -- Create the main detection area visualization
    local shapePart = Instance.new("Part")
    shapePart.Name = "DebugShapeCast"
    shapePart.Anchored = true
    shapePart.CanCollide = false
    shapePart.Shape = Enum.PartType.Block
    shapePart.Material = Enum.Material.ForceField
    shapePart.BrickColor = BrickColor.new(color)
    shapePart.Transparency = 0.7
    shapePart.Size = radius
    shapePart.CFrame = CFrame.new(centerPosition) * (orientation or CFrame.new())
    shapePart.Parent = workspace
    
    -- Create center indicator (smaller cube in the middle)
    local centerPart = Instance.new("Part")
    centerPart.Name = "DebugShapeCastCenter"
    centerPart.Anchored = true
    centerPart.CanCollide = false
    centerPart.Shape = Enum.PartType.Block
    centerPart.Material = Enum.Material.Neon
    local centerColor = hasHit and "Bright green" or "Bright red"
    centerPart.BrickColor = BrickColor.new(centerColor)
    centerPart.Transparency = 0.3
    centerPart.Size = Vector3.new(1, 1, 1) -- Small center square
    centerPart.CFrame = CFrame.new(centerPosition) * (orientation or CFrame.new())
    centerPart.Parent = workspace
    
    -- Remove after configured duration
    Debris:AddItem(shapePart, SHAPE_CAST_CONFIG.visualDuration)
    Debris:AddItem(centerPart, SHAPE_CAST_CONFIG.visualDuration)
    
    return shapePart, centerPart
end

local function performHitboxDetection(character, playerPosition, playerForward, hitboxLength, hitboxSize)
    -- Use the new HitboxSystem for detection with player-centered bounding box
    local filters = {
        ignoreFloor = SHAPE_CAST_CONFIG.ignoreFloor
    }
    
    return HitboxSystem.performDetection(character, playerPosition, playerForward, hitboxLength, hitboxSize, filters)
end

-- Use unified damage detection from HitboxSystem
local function canPartTakeDamage(part)
    return HitboxSystem.canPartTakeDamage(part)
end

-- Helper function to find the best damage target from detected parts
local function findBestDamageTarget(detectedParts)
    return HitboxSystem.findBestDamageTarget(detectedParts)
end

-- Forward declaration for charge functions
local onUse
local cleanupR6ChargeAnimation
local cancelCharging

-- R6 Animation System Functions
local function validateR6Character(character)
    if not character then return false end
    
    local torso = character:FindFirstChild("Torso")
    if not torso then return false end
    
    local rightShoulder = torso:FindFirstChild("Right Shoulder")
    if not rightShoulder then return false end
    
    return true, torso, rightShoulder
end

local function calculateChargeAngle(elapsedTime)
    local maxAngle = R6_ANIMATION.MAX_ANGLE
    local progress = 0
    
    if elapsedTime <= 0.5 then
        -- Fast phase: 60% of angle in first 0.5s
        progress = (elapsedTime / 0.5) * 0.6
    elseif elapsedTime <= 1.0 then
        -- Medium phase: 30% of angle in next 0.5s
        local phaseProgress = (elapsedTime - 0.5) / 0.5
        progress = 0.6 + (phaseProgress * 0.3)
    else
        -- Slow phase: 10% of angle in final 0.5s
        local phaseProgress = math.min((elapsedTime - 1.0) / 0.5, 1.0)
        progress = 0.9 + (phaseProgress * 0.1)
    end
    
    return maxAngle * progress
end

local function updateR6ArmPosition(angleDegrees)
    if not currentRightShoulder or not originalRightShoulderC0 then return end
    
    -- Only update if angle changed significantly (performance optimization)
    if math.abs(angleDegrees - lastAngleUpdate) < 1 then return end
    
    local rotationAngle = math.rad(angleDegrees)
    local rotationCFrame = CFrame.Angles(0, 0, rotationAngle) -- Z-axis rotation for arm swing
    currentRightShoulder.C0 = originalRightShoulderC0 * rotationCFrame
    
    lastAngleUpdate = angleDegrees
end

local function restoreR6ArmPosition(duration)
    if not currentRightShoulder or not originalRightShoulderC0 then return end
    
    duration = duration or 0.2
    
    local tween = TweenService:Create(
        currentRightShoulder,
        TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {C0 = originalRightShoulderC0}
    )
    
    tween:Play()
    
    -- Clean up references after tween completes
    tween.Completed:Connect(function()
        lastAngleUpdate = 0
    end)
end

local function setupR6ChargeAnimation()
    local character = player.Character
    local isValid, torso, rightShoulder = validateR6Character(character)
    
    if not isValid then
        warn("ToolHandler: Cannot setup R6 charge animation - invalid character structure")
        return false
    end
    
    -- Clean up any existing animation first
    cleanupR6ChargeAnimation()
    
    -- Store references
    currentRightShoulder = rightShoulder
    originalRightShoulderC0 = rightShoulder.C0
    lastAngleUpdate = 0
    
    print("DEBUG: R6 charge animation setup complete")
    return true
end

cleanupR6ChargeAnimation = function()
    -- Stop animation updates
    if chargeAnimationConnection then
        chargeAnimationConnection:Disconnect()
        chargeAnimationConnection = nil
    end
    
    -- Restore arm position
    if currentRightShoulder and originalRightShoulderC0 then
        restoreR6ArmPosition(0.2)
    end
    
    -- Clean up references
    currentRightShoulder = nil
    originalRightShoulderC0 = nil
    lastAngleUpdate = 0
    
    print("DEBUG: R6 charge animation cleanup complete")
end

-- Charge management functions
local function startCharging()
    if debounce or isCharging then return end
    
    -- Only Tools can charge
    local itemKey = string.lower(Tool.Name)
    local itemDef = ItemDefinitions:GetItem(itemKey)
    
    if not itemDef or itemDef.category ~= Categories.Tool then
        return -- Only Tools can charge
    end
    
    isCharging = true
    chargeStartTime = tick()
    
    print("DEBUG: Started charging attack")
    
    -- Start critical bar charging immediately
    if _G.CriticalAttackUI then
        _G.CriticalAttackUI:StartCharging()
    end
    
    -- Setup R6 charge animation
    if setupR6ChargeAnimation() then
        -- Start real-time animation updates
        chargeAnimationConnection = RunService.Heartbeat:Connect(function(deltaTime)
            if not isCharging then return end
            
            -- Safety check: ensure character and joint still exist
            if not validateR6Character(player.Character) then
                warn("DEBUG: Character became invalid during charging - cancelling")
                cancelCharging()
                return
            end
            
            local elapsedTime = tick() - chargeStartTime
            local currentAngle = calculateChargeAngle(elapsedTime)
            
            -- Apply to R6 character
            updateR6ArmPosition(currentAngle)
            
            -- Update critical bar progress
            if _G.CriticalAttackUI then
                local progress = math.min(elapsedTime / CHARGE_CONFIG.CHARGE_THRESHOLD, 1.0)
                _G.CriticalAttackUI:UpdateChargeProgress(progress)
                
                -- Check if we've reached full charge
                if elapsedTime >= CHARGE_CONFIG.CHARGE_THRESHOLD and not isCriticalWindowActive then
                    isCriticalWindowActive = true
                    print("DEBUG: Critical window activated")
                end
            end
        end)
        
        print("DEBUG: R6 charge animation started")
    else
        warn("DEBUG: Failed to setup R6 charge animation")
    end
end

local function stopCharging()
    if not isCharging then return end
    
    local holdDuration = tick() - chargeStartTime
    local isCharged = holdDuration >= CHARGE_CONFIG.CHARGE_THRESHOLD
    
    -- Determine attack type based on charge duration and critical timing
    local attackType = "normal"
    if isCharged then
        -- Check if critical window is active and if indicator is in critical zone
        if isCriticalWindowActive and _G.CriticalAttackUI and _G.CriticalAttackUI:IsIndicatorInCriticalZone() then
            attackType = "critical"
            print("DEBUG: CRITICAL ATTACK detected!")
            -- Show critical success effect
            _G.CriticalAttackUI:ShowCriticalSuccessEffect()
        else
            attackType = "charged"
        end
    end
    
    print("DEBUG: Stopped charging after", holdDuration, "seconds. Attack type:", attackType)
    
    -- Hide critical bar if it was shown
    if _G.CriticalAttackUI then
        _G.CriticalAttackUI:HideCriticalBar()
        isCriticalWindowActive = false
    end
    
    -- Stop charging state
    isCharging = false
    chargeStartTime = 0
    
    -- Clean up R6 charge animation
    cleanupR6ChargeAnimation()
    
    -- Execute attack based on determined type
    onUse(attackType)
end

cancelCharging = function()
    if not isCharging then return end
    
    print("DEBUG: Cancelled charging attack")
    
    -- Hide critical bar if it was shown
    if _G.CriticalAttackUI then
        _G.CriticalAttackUI:HideCriticalBar()
        isCriticalWindowActive = false
    end
    
    -- Stop charging state
    isCharging = false
    chargeStartTime = 0
    
    -- Clean up R6 charge animation
    cleanupR6ChargeAnimation()
end

-- Play swing animation (creates fresh animation each time like the working example)
local function playSwingAnimation()
    -- Only Tools play swing animations
    local itemKey = string.lower(Tool.Name)
    local itemDef = ItemDefinitions:GetItem(itemKey)
    
    if not itemDef or itemDef.category ~= Categories.Tool then
        return -- Only Tools play swing animations
    end
    
    local character = player.Character
    if not character then
        warn("ToolHandler: No character found for animation")
        return
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then
        warn("ToolHandler: No humanoid found for animation")
        return
    end
    
    local animator = humanoid:FindFirstChild("Animator")
    if not animator then
        warn("ToolHandler: No Animator found in character")
        return
    end
    
    -- Create fresh animation instance each time (like the working example)
    local animation = Instance.new("Animation")
    animation.AnimationId = SWING_ANIMATION_ID
    
    -- Load and play animation immediately
    local animationTrack = animator:LoadAnimation(animation)
    animationTrack.Priority = Enum.AnimationPriority.Action
    animationTrack:Play()
    
    print("ToolHandler: Playing fresh swing animation for", Tool.Name)
end

onUse = function(attackType)
    attackType = attackType or "normal" -- Default to normal attack
    
    if debounce then return end
    debounce = true
    
    local character = player.Character
    if not character then 
        debounce = false
        return 
    end
    
    local human = character:FindFirstChild("Humanoid")
    if not human or human.Health <= 0 then 
        debounce = false
        return 
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then 
        debounce = false
        return 
    end

    -- Convert tool name to lowercase and replace spaces with underscores to match ItemDefinitions keys
    local itemKey = string.lower(Tool.Name)
    itemKey = string.gsub(itemKey, " ", "_")  -- Replace spaces with underscores
    local itemDef = ItemDefinitions:GetItem(itemKey)

    if not itemDef then
        warn("ToolHandler: No item definition found for equipped tool:", Tool.Name, "(key:", itemKey .. ")")
        debounce = false
        return
    end

    -- Initialize target as nil
    local target = nil

    -- Only perform hitbox detection for Tool category items
    if itemDef.category == Categories.Tool then
        
        -- Play swing animation for tools
        playSwingAnimation()
        
        -- Get item-specific hitbox settings
        local itemSettings = HitboxSystem.getItemSettings(itemDef.name)
        
        -- Perform hitbox detection in front of player
        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        local head = character and character:FindFirstChild("Head")
        
        if not rootPart then
            print("ToolHandler: No HumanoidRootPart found, skipping hitbox detection")
            return
        end
        
        -- Get player's forward direction (use camera direction for aiming)
        local cameraDirection = camera.CFrame.LookVector
        local playerForward = Vector3.new(cameraDirection.X, 0, cameraDirection.Z).Unit -- Keep horizontal only
        
        -- Perform the hitbox detection with player-centered bounding box
        local detectedParts = performHitboxDetection(character, rootPart.Position, playerForward, itemSettings.distance, itemSettings.size)
        
        local hasHit = #detectedParts > 0
        
        if hasHit then
            -- Use the best damage target from detected parts
            target = findBestDamageTarget(detectedParts)
            
            -- Create visual hitbox (green for hit) with proper orientation
            local cameraDirection = camera.CFrame.LookVector
            local playerForward = Vector3.new(cameraDirection.X, 0, cameraDirection.Z).Unit
            local orientation = CFrame.Angles(0, math.atan2(playerForward.X, playerForward.Z), 0)
            local hitboxCenter = rootPart.Position + playerForward * (itemSettings.distance / 2)
            createVisualShapeCast(hitboxCenter, Vector3.new(itemSettings.size.X, itemSettings.size.Y, itemSettings.distance), "Bright green", true, orientation)
        else
            -- Create visual hitbox (red for miss) with proper orientation
            local cameraDirection = camera.CFrame.LookVector
            local playerForward = Vector3.new(cameraDirection.X, 0, cameraDirection.Z).Unit
            local orientation = CFrame.Angles(0, math.atan2(playerForward.X, playerForward.Z), 0)
            local hitboxCenter = rootPart.Position + playerForward * (itemSettings.distance / 2)
            createVisualShapeCast(hitboxCenter, Vector3.new(itemSettings.size.X, itemSettings.size.Y, itemSettings.distance), "Bright red", false, orientation)
        end
    end

    -- Centralized dispatch based on category
    print("ToolHandler: Dispatching", itemDef.name, "with category:", itemDef.category)
    
    if itemDef.category == Categories.Tool then
        ToolSystem:Use(itemDef, player, target, attackType)
    elseif itemDef.category == Categories.Armor then
        ArmorSystem:Use(itemDef, player, target)
    elseif itemDef.category == Categories.Functional then
        FunctionalSystem:Use(itemDef, player, target)
    else
        warn("ToolHandler: Unknown category for item:", itemDef.name, itemDef.category)
    end
    
    -- Get item-specific cooldown for proper timing
    local itemKey = string.lower(Tool.Name)
    local itemDef = ItemDefinitions:GetItem(itemKey)
    local toolCooldown = 0.5 -- Default fallback
    
    if itemDef and itemDef.actionData and itemDef.actionData.cooldown then
        toolCooldown = itemDef.actionData.cooldown
    end
    
    -- Use the longer of UI debounce or tool cooldown
    local finalCooldown = math.max(DEBOUNCE_TIME, toolCooldown)
    
    -- Reset debounce after tool-specific delay
    wait(finalCooldown)
    debounce = false
end

-- Input handling for charged attacks
local inputConnections = {}

local function setupInputHandling()
    print("DEBUG: setupInputHandling called for", Tool.Name)
    
    -- Clean up existing connections
    for _, connection in pairs(inputConnections) do
        connection:Disconnect()
    end
    inputConnections = {}
    
    -- Setup input handling for Tools and Functional items
    local itemKey = string.lower(Tool.Name)
    itemKey = string.gsub(itemKey, " ", "_")  -- Replace spaces with underscores
    local itemDef = ItemDefinitions:GetItem(itemKey)
    
    print("DEBUG: Item key:", itemKey, "Item def found:", itemDef ~= nil)
    if itemDef then
        print("DEBUG: Item category:", itemDef.category)
    end
    
    if not itemDef then
        print("DEBUG: No item definition found, exiting setupInputHandling")
        return -- Exit early - no item definition found
    end
    
    -- Only Tools use charged attack system, but Functional items need basic click handling
    local allowChargedAttacks = (itemDef.category == Categories.Tool)
    
    if itemDef.category ~= Categories.Tool and itemDef.category ~= Categories.Functional then
        print("DEBUG: Item category not supported for input handling:", itemDef.category)
        return -- Exit early - only Tools and Functional items need input handling
    end
    
    print("DEBUG: Setting up input handling for", itemDef.category, "item with chargedAttacks:", allowChargedAttacks)
    
    -- Mouse input handling
    inputConnections.mouseDown = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        print("DEBUG: Mouse input detected - gameProcessed:", gameProcessed, "isToolEquipped:", isToolEquipped, "inputType:", input.UserInputType)
        
        if gameProcessed then return end
        if not isToolEquipped then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            print("DEBUG: Left mouse button clicked for", Tool.Name, "allowChargedAttacks:", allowChargedAttacks)
            if allowChargedAttacks then
                startCharging() -- Tools use charged attack system
            else
                -- Functional items use immediate action on click
                print("DEBUG: Calling onUse for functional item")
                onUse("normal")
            end
        end
    end)
    
    print("DEBUG: Mouse input connections set up for", Tool.Name)
    
    inputConnections.mouseUp = UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if not isToolEquipped then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if allowChargedAttacks then
                stopCharging() -- Only Tools use charged system
            end
            -- Functional items don't need mouse up handling
        end
    end)
end

-- Additional edge case handling
local edgeCaseConnections = {}

local function setupEdgeCaseHandling()
            -- Cancel charging when player dies
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                edgeCaseConnections.died = humanoid.Died:Connect(function()
                    cancelCharging()
                end)
            end
            
            -- Handle character removal (respawn, etc.)
            edgeCaseConnections.ancestryChanged = character.AncestryChanged:Connect(function()
                if not character.Parent then
                    cancelCharging()
                end
            end)
        end
        
        -- Cancel charging when UI opens (like inventory, chat, etc.)
        edgeCaseConnections.guiService = game:GetService("GuiService").MenuOpened:Connect(function()
            cancelCharging()
        end)
        
        -- Handle player leaving
        edgeCaseConnections.playerRemoving = game:GetService("Players").PlayerRemoving:Connect(function(leavingPlayer)
            if leavingPlayer == player then
                cleanupR6ChargeAnimation()
            end
        end)
end

local function cleanupEdgeCaseHandling()
    for _, connection in pairs(edgeCaseConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    edgeCaseConnections = {}
end

-- Tool lifecycle events
Tool.Equipped:Connect(function()
    print("DEBUG: Tool.Equipped fired for", Tool.Name)
    isToolEquipped = true
    setupInputHandling()
    setupEdgeCaseHandling()
    print("DEBUG: Tool setup complete for", Tool.Name)
end)

Tool.Unequipped:Connect(function()
    print("DEBUG: Tool.Unequipped fired for", Tool.Name)
    isToolEquipped = false
    cancelCharging()
    
    -- Clean up input connections
    for _, connection in pairs(inputConnections) do
        connection:Disconnect()
    end
    inputConnections = {}
    
    -- Clean up edge case connections
    cleanupEdgeCaseHandling()
    
    -- Ensure R6 animation cleanup
    cleanupR6ChargeAnimation()
    print("DEBUG: Tool cleanup complete for", Tool.Name)
end) 