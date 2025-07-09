-- Ripple Square Renderer - Handles visual effects for expanding square outlines
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BossConfig = require(ReplicatedStorage.Shared.BossConfig)

local RippleSquareRenderer = {}

-- Private variables
local activeSquares: {[number]: {parts: {BasePart}, startTime: number}} = {}

-- Find ground level at boss position (identical to server)
local function findGroundLevel(position: Vector3): Vector3
    -- Raycast downward to find ground
    local Players = game:GetService("Players")
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
        print("CLIENT Raycast hit:", raycast.Instance.Name, "at Y:", raycast.Position.Y, "Parent:", raycast.Instance.Parent.Name)
        -- Position slightly above ground to ensure visibility
        return Vector3.new(position.X, raycast.Position.Y + 0.1, position.Z)
    else
        -- Debug: Print when no hit
        print("CLIENT Raycast missed - using fallback position")
        -- Fallback to boss Y position minus some height to get to ground level
        return Vector3.new(position.X, position.Y - 5, position.Z)
    end
end

-- Create a visual square outline made of 4 parts
local function createVisualSquareOutline(bossPosition: Vector3, squareIndex: number): {BasePart}
    local config = BossConfig.abilities.rippleSquares
    local parts = {}
    
    -- Find ground level for the squares (matching server exactly)
    local groundPosition = findGroundLevel(bossPosition)
    
    -- Create 4 parts that form a hollow square outline (matching server exactly)
    local partNames = {"Top", "Bottom", "Left", "Right"}
    
    for i, partName in ipairs(partNames) do
        local part = Instance.new("Part")
        part.Name = "RippleSquareVisual_" .. squareIndex .. "_" .. partName
        part.Color = config.visualColor
        part.Material = config.visualMaterial
        part.Transparency = config.visualTransparency
        part.CanCollide = false
        part.Anchored = true
        part.Parent = workspace
        
        -- Position and size the parts to form a hollow square on the ground (identical to server)
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
        
        -- Add subtle glow effect
        local pointLight = Instance.new("PointLight")
        pointLight.Color = config.visualColor
        pointLight.Brightness = 0.3
        pointLight.Range = 3
        pointLight.Parent = part
        
        table.insert(parts, part)
    end
    
    return parts
end

-- Animate the visual square outline expansion (matching server exactly)
local function animateVisualExpansion(parts: {BasePart}, bossPosition: Vector3, squareIndex: number)
    local config = BossConfig.abilities.rippleSquares
    
    -- Find ground level for expansion targets (matching server exactly)
    local groundPosition = findGroundLevel(bossPosition)
    
    -- Create expansion tween for each part (identical to server timing)
    local tweenInfo = TweenInfo.new(
        config.expansionDuration,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.Out
    )
    
    for i, part in ipairs(parts) do
        local partName = part.Name:match("_(%w+)$") -- Extract part name (Top, Bottom, etc.)
        local targetSize
        local targetPosition
        
        -- Calculate target size and position (identical to server)
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
        
        -- Add fade out effect as it expands
        local fadeTween = TweenService:Create(part, tweenInfo, {Transparency = 1})
        
        sizeTween:Play()
        positionTween:Play()
        fadeTween:Play()
        
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
function RippleSquareRenderer.handleRippleSquares(data: {[string]: any})
    local phase = data.phase
    local bossPosition = data.bossPosition
    local squareIndex = data.squareIndex
    
    if phase == "start" then
        print("Starting expanding square ripples visual effect")
        -- Could add initial boss effect here (like a brief glow)
        
    elseif phase == "spawnSquare" and bossPosition and squareIndex then
        print("Spawning visual expanding square", squareIndex)
        
        -- Create visual square outline
        local parts = createVisualSquareOutline(bossPosition, squareIndex)
        activeSquares[squareIndex] = {
            parts = parts,
            startTime = tick()
        }
        
        -- Start expansion animation
        animateVisualExpansion(parts, bossPosition, squareIndex)
        
    elseif phase == "cleanup" then
        print("Cleaning up expanding square ripples visual effects")
        
        -- Clean up any remaining squares
        for squareIndex, squareData in pairs(activeSquares) do
            for _, part in ipairs(squareData.parts) do
                if part and part.Parent then
                    -- Add quick disappear animation
                    local disappearTween = TweenService:Create(
                        part,
                        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                        {Transparency = 1}
                    )
                    disappearTween:Play()
                    
                    -- Destroy after animation
                    disappearTween.Completed:Connect(function()
                        if part and part.Parent then
                            part:Destroy()
                        end
                    end)
                end
            end
            activeSquares[squareIndex] = nil
        end
    end
end

function RippleSquareRenderer.cleanup()
    -- Clean up all active squares
    for squareIndex, squareData in pairs(activeSquares) do
        for _, part in ipairs(squareData.parts) do
            if part and part.Parent then
                part:Destroy()
            end
        end
        activeSquares[squareIndex] = nil
    end
end

return RippleSquareRenderer 