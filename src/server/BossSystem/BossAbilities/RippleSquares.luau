-- Ripple Squares Ability - Creates expanding square outlines from the boss
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local BossConfig = require(ReplicatedStorage.Shared.BossConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local FrameBudgetManager = require(ReplicatedStorage.Shared.FrameBudgetManager)
local RemoteEventBatcher = require(ReplicatedStorage.Shared.RemoteEventBatcher)

local RippleSquares = {}

-- Private variables
local activeRippleSquares: {[Types.BossData]: {squares: {{parts: {BasePart}, startTime: number}}, startTime: number?}} = {}

-- Get the RemoteEvent for client communication
local function getBossAbilitiesRemote(): RemoteEvent
    return _G.BossAbilitiesRemote or ReplicatedStorage:FindFirstChild("BossAbilities")
end

-- Send update to clients for visual effects
local function sendRippleUpdate(phase: string, bossPosition: Vector3, squareIndex: number?)
    local remote = getBossAbilitiesRemote()
    if not remote then
        warn("BossAbilities RemoteEvent not found!")
        return
    end
    
    local data = {
        abilityType = "rippleSquares",
        phase = phase,
        bossPosition = bossPosition,
        squareIndex = squareIndex,
    }
    
    -- PERFORMANCE OPTIMIZATION: Batch square spawns but send start/cleanup immediately
    if phase == "spawnSquare" then
        RemoteEventBatcher.queueEvent(remote, data)
    else
        -- Immediate for start/cleanup
        remote:FireAllClients(data)
    end
end

-- Find ground level at boss position
local function findGroundLevel(position: Vector3): Vector3
    -- Raycast downward to find ground
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    -- Filter out boss AND all player characters
    local filterList = {}
    if workspace:FindFirstChild("Boss") then
        table.insert(filterList, workspace:FindFirstChild("Boss"))
    end
    
    -- Add all player characters to filter
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(filterList, player.Character)
        end
    end
    
    raycastParams.FilterDescendantsInstances = filterList
    
    local raycast = workspace:Raycast(Vector3.new(position.X, position.Y + 20, position.Z), Vector3.new(0, -100, 0), raycastParams)
    if raycast then
        -- Debug: Print what we hit
        print("Raycast hit:", raycast.Instance.Name, "at Y:", raycast.Position.Y, "Parent:", raycast.Instance.Parent.Name)
        -- Position slightly above ground to ensure visibility
        return Vector3.new(position.X, raycast.Position.Y + 0.1, position.Z)
    else
        -- Debug: Print when no hit
        print("Raycast missed - using fallback position")
        -- Fallback to boss Y position minus some height to get to ground level
        return Vector3.new(position.X, position.Y - 5, position.Z)
    end
end

-- Create a hollow square outline made of 4 parts
local function createSquareOutlineHitbox(bossPosition: Vector3, squareIndex: number): {BasePart}
    local config = BossConfig.abilities.rippleSquares
    local parts = {}
    
    -- Find ground level for the squares
    local groundPosition = findGroundLevel(bossPosition)
    
    -- Create 4 parts that form a hollow square outline
    local partNames = {"Top", "Bottom", "Left", "Right"}
    
    for i, partName in ipairs(partNames) do
        local part = Instance.new("Part")
        part.Name = "RippleSquareOutline_" .. squareIndex .. "_" .. partName
        part.Size = config.initialSize -- Will be tweened to expand
        part.Position = groundPosition
        part.Transparency = 1 -- Invisible hitbox
        part.CanCollide = false
        part.Anchored = true
        part.Parent = workspace
        
        -- Position the parts to form a hollow square on the ground
        if partName == "Top" then
            part.Size = Vector3.new(config.initialSize.X, config.outlineThickness, config.outlineThickness)
            part.Position = groundPosition + Vector3.new(0, config.outlineThickness/2, config.initialSize.Z/2)
        elseif partName == "Bottom" then
            part.Size = Vector3.new(config.initialSize.X, config.outlineThickness, config.outlineThickness)
            part.Position = groundPosition + Vector3.new(0, config.outlineThickness/2, -config.initialSize.Z/2)
        elseif partName == "Left" then
            part.Size = Vector3.new(config.outlineThickness, config.outlineThickness, config.initialSize.Z)
            part.Position = groundPosition + Vector3.new(-config.initialSize.X/2, config.outlineThickness/2, 0)
        elseif partName == "Right" then
            part.Size = Vector3.new(config.outlineThickness, config.outlineThickness, config.initialSize.Z)
            part.Position = groundPosition + Vector3.new(config.initialSize.X/2, config.outlineThickness/2, 0)
        end
        
        -- Add damage detection
        local connection
        connection = part.Touched:Connect(function(hit)
            local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
            if humanoid then
                local player = Players:GetPlayerFromCharacter(hit.Parent)
                if player then
                    -- Deal damage
                    humanoid.Health = math.max(0, humanoid.Health - config.damage)
                    print(player.Name, "took", config.damage, "damage from expanding square", squareIndex)
                    
                    -- Disconnect to prevent multiple hits from same square
                    connection:Disconnect()
                end
            end
        end)
        
        table.insert(parts, part)
    end
    
    return parts
end

-- Animate the square outline expansion
local function animateSquareExpansion(parts: {BasePart}, bossPosition: Vector3, squareIndex: number)
    local config = BossConfig.abilities.rippleSquares
    
    -- Find ground level for expansion targets
    local groundPosition = findGroundLevel(bossPosition)
    
    -- Create expansion tween for each part
    local tweenInfo = TweenInfo.new(
        config.expansionDuration,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.Out
    )
    
    for i, part in ipairs(parts) do
        local partName = part.Name:match("_(%w+)$") -- Extract part name (Top, Bottom, etc.)
        local targetSize
        local targetPosition
        
        if partName == "Top" then
            targetSize = Vector3.new(config.maxSize.X, config.outlineThickness, config.outlineThickness)
            targetPosition = groundPosition + Vector3.new(0, config.outlineThickness/2, config.maxSize.Z/2)
        elseif partName == "Bottom" then
            targetSize = Vector3.new(config.maxSize.X, config.outlineThickness, config.outlineThickness)
            targetPosition = groundPosition + Vector3.new(0, config.outlineThickness/2, -config.maxSize.Z/2)
        elseif partName == "Left" then
            targetSize = Vector3.new(config.outlineThickness, config.outlineThickness, config.maxSize.Z)
            targetPosition = groundPosition + Vector3.new(-config.maxSize.X/2, config.outlineThickness/2, 0)
        elseif partName == "Right" then
            targetSize = Vector3.new(config.outlineThickness, config.outlineThickness, config.maxSize.Z)
            targetPosition = groundPosition + Vector3.new(config.maxSize.X/2, config.outlineThickness/2, 0)
        end
        
        -- Create and play the expansion tween
        local sizeTween = TweenService:Create(part, tweenInfo, {Size = targetSize})
        local positionTween = TweenService:Create(part, tweenInfo, {Position = targetPosition})
        
        sizeTween:Play()
        positionTween:Play()
        
        -- Cleanup when expansion completes
        if i == 1 then -- Only need to connect once per square
            sizeTween.Completed:Connect(function()
                -- Remove all parts of this square
                for _, squarePart in ipairs(parts) do
                    if squarePart and squarePart.Parent then
                        squarePart:Destroy()
                    end
                end
            end)
        end
    end
end

-- Public functions
function RippleSquares.execute(boss: Types.BossData, targetPlayer: Player?): Types.AttackResult
    -- Prevent multiple simultaneous executions
    if activeRippleSquares[boss] then
        warn("RippleSquares already active for this boss!")
        return {success = false}
    end
    
    print("Boss executing expanding square ripples ability")
    
    local config = BossConfig.abilities.rippleSquares
    
    -- Initialize tracking data
    activeRippleSquares[boss] = {
        squares = {},
        startTime = tick()
    }
    
    -- Tell clients to start the ability
    sendRippleUpdate("start", boss.rootPart.Position)
    
    -- Spawn expanding squares with timing - FRAME BUDGETED
    task.spawn(function()
        local squareOperations = {}
        for squareIndex = 1, config.maxActiveSquares do
            table.insert(squareOperations, function()
                print("Spawning expanding square", squareIndex)
                
                -- Yield to prevent frame drops during part creation
                FrameBudgetManager.yieldIfNeeded(0.005) -- 5ms estimate for part creation
                
                -- Create server hitbox outline
                local parts = createSquareOutlineHitbox(boss.rootPart.Position, squareIndex)
                
                -- Store square data
                table.insert(activeRippleSquares[boss].squares, {
                    parts = parts,
                    startTime = tick()
                })
                
                -- Tell clients to spawn visual square
                sendRippleUpdate("spawnSquare", boss.rootPart.Position, squareIndex)
                
                -- Start expansion animation
                animateSquareExpansion(parts, boss.rootPart.Position, squareIndex)
                
                -- Wait before next square (except for the last one)
                if squareIndex < config.maxActiveSquares then
                    task.wait(config.rippleInterval)
                end
            end)
        end
        
        -- Execute with frame budgeting (max 2 squares per frame to prevent lag)
        FrameBudgetManager.executeWithLimit(squareOperations, 2)
        
        -- Wait for all squares to finish expanding and disappear
        task.wait(config.expansionDuration + 0.5)
        
        -- Tell clients to cleanup
        sendRippleUpdate("cleanup", boss.rootPart.Position)
        
        -- Clear tracking data
        activeRippleSquares[boss] = nil
        
        print("Expanding square ripples ability completed")
    end)
    
    -- Calculate total duration
    local totalDuration = (config.rippleInterval * (config.maxActiveSquares - 1)) + config.expansionDuration + 0.5
    
    return {
        success = true,
        damage = config.damage,
        playersHit = {}, -- Could track which players were hit
        duration = totalDuration
    }
end

function RippleSquares.interrupt(boss: Types.BossData)
    local rippleData = activeRippleSquares[boss]
    if rippleData then
        -- Cleanup all hitbox parts
        for _, square in ipairs(rippleData.squares) do
            for _, part in ipairs(square.parts) do
                if part and part.Parent then
                    part:Destroy()
                end
            end
        end
        
        -- Tell clients to cleanup
        sendRippleUpdate("cleanup", boss.rootPart.Position)
        activeRippleSquares[boss] = nil
    end
end

function RippleSquares.isActive(boss: Types.BossData): boolean
    return activeRippleSquares[boss] ~= nil
end

function RippleSquares.cleanup(boss: Types.BossData)
    RippleSquares.interrupt(boss)
end

return RippleSquares 