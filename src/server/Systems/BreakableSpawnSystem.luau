-- BreakableSpawnSystem.luau
-- Handles spawning breakable objects in the world

local BreakableSpawnSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ECS = require(ReplicatedStorage.Shared.ECS)
local BreakableDefinitions = require(ReplicatedStorage.Shared.BreakableDefinitions)
local SystemManager = require(ReplicatedStorage.Shared.SystemManager)

-- Configuration
local SPAWN_CONFIG = {
    -- Spawn settings
    maxBreakables = 50,
    spawnRadius = 100,
    minDistance = 10,
    
    -- Spawn distribution
    treeChance = 0.4,
    rockChance = 0.4,
    crystalChance = 0.2,
}

-- Internal state
local spawnedBreakables = {}

-- Helper function to check if StructureModels folder exists and list available models
function BreakableSpawnSystem:DebugStructureModels()
    local structureModels = ReplicatedStorage:FindFirstChild("StructureModels")
    if not structureModels then
        print("BreakableSpawnSystem: StructureModels folder not found in ReplicatedStorage")
        return
    end
    
    print("BreakableSpawnSystem: Available models in StructureModels:")
    for _, model in ipairs(structureModels:GetChildren()) do
        print("  -", model.Name)
    end
end

function BreakableSpawnSystem:Initialize()
    print("BreakableSpawnSystem: Initializing...")
    
    -- Register with system manager
    SystemManager.RegisterSystem("BreakableSpawnSystem", self)
    
    -- Debug: Check available structure models
    self:DebugStructureModels()
    
    -- Initial spawn of breakables
    self:SpawnInitialBreakables()
    
    print("BreakableSpawnSystem: Initialized")
end

function BreakableSpawnSystem:SpawnInitialBreakables()
    -- Spawn initial set of breakables
    local initialCount = math.min(20, SPAWN_CONFIG.maxBreakables)
    
    for i = 1, initialCount do
        self:SpawnRandomBreakable()
    end
    
    print("BreakableSpawnSystem: Spawned", initialCount, "initial breakables")
end

function BreakableSpawnSystem:SpawnNewBreakables()
    -- This function can be called manually if needed to spawn additional breakables
    local currentCount = #spawnedBreakables
    if currentCount >= SPAWN_CONFIG.maxBreakables then
        return
    end
    
    local spawnCount = math.min(5, SPAWN_CONFIG.maxBreakables - currentCount)
    
    for i = 1, spawnCount do
        self:SpawnRandomBreakable()
    end
end

function BreakableSpawnSystem:SpawnRandomBreakable()
    -- Determine breakable type based on chances
    local rand = math.random()
    local breakableType = "tree"
    
    if rand <= SPAWN_CONFIG.treeChance then
        breakableType = "tree"
    elseif rand <= SPAWN_CONFIG.treeChance + SPAWN_CONFIG.rockChance then
        breakableType = "rock"
    else
        breakableType = "crystal"
    end
    
    -- Get random breakable of this type
    local breakableId = BreakableDefinitions:GetRandomBreakableOfType(breakableType)
    if not breakableId then
        warn("BreakableSpawnSystem: No breakable found for type:", breakableType)
        return
    end
    
    -- Spawn the breakable
    self:SpawnBreakable(breakableId)
end

function BreakableSpawnSystem:SpawnBreakable(breakableId, position)
    local breakableDef = BreakableDefinitions:GetBreakable(breakableId)
    if not breakableDef then
        warn("BreakableSpawnSystem: Invalid breakable ID:", breakableId)
        return nil
    end
    
    -- Generate position if not provided
    if not position then
        position = self:GenerateSpawnPosition()
    end
    
    -- Create the breakable object
    local breakable = self:CreateBreakableObject(breakableDef, position)
    if not breakable then
        warn("BreakableSpawnSystem: Failed to create breakable object")
        return nil
    end
    
    -- Add to spawned list
    table.insert(spawnedBreakables, {
        object = breakable,
        definition = breakableDef,
        breakableId = breakableId,
        spawnTime = tick()
    })
    
    print("BreakableSpawnSystem: Spawned", breakableDef.name, "at", position)
    return breakable
end

function BreakableSpawnSystem:CreateBreakableObject(breakableDef, position)
    local breakable = nil
    
    -- Try to load custom model from StructureModels folder
    if breakableDef.model then
        local structureModels = ReplicatedStorage:FindFirstChild("StructureModels")
        if structureModels then
            local modelTemplate = structureModels:FindFirstChild(breakableDef.model)
            if modelTemplate then
                breakable = modelTemplate:Clone()
                print("BreakableSpawnSystem: Loaded custom model:", breakableDef.model, "for", breakableDef.name)
            else
                warn("BreakableSpawnSystem: Model not found in ReplicatedStorage/StructureModels/:", breakableDef.model)
                local availableModels = {}
                for _, model in ipairs(structureModels:GetChildren()) do
                    table.insert(availableModels, model.Name)
                end
                print("BreakableSpawnSystem: Available models:", table.concat(availableModels, ", "))
            end
        else
            warn("BreakableSpawnSystem: StructureModels folder not found in ReplicatedStorage")
        end
    end
    
    -- Create fallback part if no model found
    if not breakable then
        print("BreakableSpawnSystem: Using fallback basic part for:", breakableDef.name)
        breakable = Instance.new("Part")
        breakable.Size = Vector3.new(3, 6, 3)
        breakable.Anchored = true
        breakable.CanCollide = true
        
        -- Set material and color based on type
        if breakableDef.breakableType == "tree" then
            breakable.Material = Enum.Material.Wood
            breakable.Color = Color3.fromRGB(139, 69, 19)
        elseif breakableDef.breakableType == "rock" then
            breakable.Material = Enum.Material.Concrete
            breakable.Color = Color3.fromRGB(128, 128, 128)
        elseif breakableDef.breakableType == "crystal" then
            breakable.Material = Enum.Material.Glass
            breakable.Color = Color3.fromRGB(138, 43, 226)
        end
    end
    
    -- Set the correct name from breakable definition
    breakable.Name = breakableDef.name
    
    -- Position the breakable
    if breakable:IsA("Model") then
        -- Ensure model has a primary part
        if not breakable.PrimaryPart then
            local largestPart = nil
            local largestVolume = 0
            for _, part in pairs(breakable:GetChildren()) do
                if part:IsA("BasePart") then
                    local volume = part.Size.X * part.Size.Y * part.Size.Z
                    if volume > largestVolume then
                        largestVolume = volume
                        largestPart = part
                    end
                end
            end
            if largestPart then
                breakable.PrimaryPart = largestPart
                print("BreakableSpawnSystem: Set PrimaryPart for model:", breakableDef.name, "to:", largestPart.Name)
            else
                warn("BreakableSpawnSystem: No suitable part found for PrimaryPart in model:", breakableDef.name)
            end
        end
        
        -- Position the model using its primary part
        if breakable.PrimaryPart then
            -- Find the lowest point of the model
            local lowestY = math.huge
            for _, part in ipairs(breakable:GetDescendants()) do
                if part:IsA("BasePart") then
                    local partBottom = part.Position.Y - (part.Size.Y / 2)
                    if partBottom < lowestY then
                        lowestY = partBottom
                    end
                end
            end
            
            -- Calculate how much we need to raise the model to place its bottom at ground level
            local modelBottom = breakable.PrimaryPart.Position.Y - (breakable.PrimaryPart.Size.Y / 2)
            local raiseAmount = modelBottom - lowestY
            
            -- Position the model so its actual bottom touches the ground
            local adjustedPosition = position + Vector3.new(0, raiseAmount, 0)
            
            breakable:SetPrimaryPartCFrame(CFrame.new(adjustedPosition))
            
            print("BreakableSpawnSystem: Model bottom at Y:", lowestY)
            print("BreakableSpawnSystem: PrimaryPart bottom at Y:", modelBottom)
            print("BreakableSpawnSystem: Raise amount:", raiseAmount)
            print("BreakableSpawnSystem: Ground position:", position)
            print("BreakableSpawnSystem: Adjusted position:", adjustedPosition)
            
            -- Make all parts anchored and collidable
            for _, part in ipairs(breakable:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = true
                    part.CanCollide = true
                end
            end
        else
            warn("BreakableSpawnSystem: Could not position model - no primary part found:", breakableDef.name)
        end
    else
        -- Handle single part breakables
        breakable.Position = position
        breakable.Anchored = true
        breakable.CanCollide = true
    end
    
    -- Add ECS components
    local components = BreakableDefinitions:CreateBreakableComponents(breakableDef.breakableType)
    if components then
        for componentName, component in pairs(components) do
            ECS:AddComponent(breakable, componentName, component)
        end
    end
    
    -- Add Breakable tag to the object
    local CollectionService = game:GetService("CollectionService")
    CollectionService:AddTag(breakable, "Breakable")
    
    -- Add specific type tag for tool validation
    if breakableDef.breakableType == "tree" then
        CollectionService:AddTag(breakable, "Tree")
    elseif breakableDef.breakableType == "rock" then
        CollectionService:AddTag(breakable, "Rock")
    elseif breakableDef.breakableType == "crystal" then
        CollectionService:AddTag(breakable, "Crystal")
    end
    
    -- Add to workspace
    breakable.Parent = workspace
    
    return breakable
end

function BreakableSpawnSystem:GenerateSpawnPosition()
    local center = Vector3.new(0, 0, 0) -- You can change this to your map center
    local angle = math.random() * 2 * math.pi
    local distance = math.random(SPAWN_CONFIG.minDistance, SPAWN_CONFIG.spawnRadius)
    
    local position = center + Vector3.new(
        math.cos(angle) * distance,
        0,
        math.sin(angle) * distance
    )
    
    -- Raycast to find ground level
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {workspace.Terrain}
    
    local raycastResult = workspace:Raycast(position + Vector3.new(0, 100, 0), Vector3.new(0, -200, 0), raycastParams)
    if raycastResult then
        position = raycastResult.Position + Vector3.new(0, 3, 0) -- Slightly above ground
    end
    
    return position
end

-- Removed respawn functionality - objects are destroyed when broken

function BreakableSpawnSystem:RemoveBreakable(breakableObject)
    for i, spawnData in ipairs(spawnedBreakables) do
        if spawnData.object == breakableObject then
            table.remove(spawnedBreakables, i)
            break
        end
    end
end

function BreakableSpawnSystem:GetSpawnedBreakables()
    return spawnedBreakables
end

return BreakableSpawnSystem 