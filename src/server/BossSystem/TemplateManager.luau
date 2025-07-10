-- Template Manager - Handles loading and validation of R6 character templates
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossConfig = require(ReplicatedStorage.Shared.BossConfig)
local FrameBudgetManager = require(ReplicatedStorage.Shared.FrameBudgetManager)

local TemplateManager = {}

-- Private functions
local function validateR6Character(template: Model): boolean
    -- Check if it's a valid R6 character
    local requiredParts = {
        "Humanoid",
        "HumanoidRootPart", 
        "Head",
        "Torso",
        "Left Arm",
        "Right Arm",
        "Left Leg",
        "Right Leg"
    }
    
    for _, partName in pairs(requiredParts) do
        if not template:FindFirstChild(partName) then
            warn("Template", template.Name, "missing required part:", partName)
            return false
        end
    end
    
    -- Check humanoid type
    local humanoid = template:FindFirstChild("Humanoid") :: Humanoid?
    if humanoid and humanoid.RigType ~= Enum.HumanoidRigType.R6 then
        warn("Template", template.Name, "is not R6 rig type")
        return false
    end
    
    return true
end

-- Public functions
function TemplateManager.validateTemplates(): boolean
    local success = true
    
    -- Check boss template
    local bossTemplate = ServerStorage:FindFirstChild(BossConfig.templates.bossName)
    if not bossTemplate then
        error("BossTemplate not found in ServerStorage! Please create a Dummy named '" .. BossConfig.templates.bossName .. "'")
        return false
    end
    
    if not validateR6Character(bossTemplate) then
        error("BossTemplate is not a valid R6 character!")
        return false
    end
    
    -- Check enemy template (optional - only needed if you add abilities that spawn enemies)
    local enemyTemplate = ServerStorage:FindFirstChild(BossConfig.templates.enemyName)
    if enemyTemplate and not validateR6Character(enemyTemplate) then
        warn("EnemyTemplate exists but is not a valid R6 character!")
    end
    
    print("✅ Boss template validated successfully!")
    print("  - Boss template:", bossTemplate.Name)
    if enemyTemplate then
        print("  - Enemy template:", enemyTemplate.Name, "(optional)")
    end
    
    return true
end

function TemplateManager.loadBossTemplate(): Model
    local template = ServerStorage:FindFirstChild(BossConfig.templates.bossName)
    if not template then
        error("BossTemplate not found! Did you create it in ServerStorage?")
    end
    
    -- PERFORMANCE OPTIMIZATION: The original synchronous clone was causing lag
    -- We still need to return synchronously for compatibility, but we'll optimize the process
    
    local boss = template:Clone()
    
    -- Ensure proper setup
    local humanoid = boss:FindFirstChild("Humanoid") :: Humanoid
    if humanoid then
        humanoid.MaxHealth = BossConfig.boss.health
        humanoid.Health = BossConfig.boss.health
        humanoid.WalkSpeed = BossConfig.boss.walkSpeed
        humanoid.JumpPower = 0 -- Prevent jumping
        humanoid.PlatformStand = false -- Allow normal movement
        -- Disable default health bar and nametag
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end
    
    -- Set default properties but DON'T set position (will be set by caller)
    local rootPart = boss:FindFirstChild("HumanoidRootPart") :: BasePart
    if rootPart then
        rootPart.Anchored = false
        -- Position will be set by BossController.spawnBoss()
    end
    
    return boss
end

-- ENHANCED: Robust async boss template loading with better error handling
function TemplateManager.loadBossTemplateAsync(callback: (Model?) -> ())
    print("TEMPLATE DEBUG: Starting async boss template load")
    
    local template = ServerStorage:FindFirstChild(BossConfig.templates.bossName)
    if not template then
        local errorMsg = "BossTemplate '" .. BossConfig.templates.bossName .. "' not found in ServerStorage!"
        warn("TEMPLATE ERROR:", errorMsg)
        callback(nil)
        return
    end
    
    print("TEMPLATE DEBUG: Boss template found:", template.Name)
    
    task.spawn(function()
        local startTime = tick()
        
        -- ENHANCED: Better error handling and validation
        local success, result = pcall(function()
            -- Yield to prevent frame drop during clone operation
            FrameBudgetManager.yieldIfNeeded(0.010) -- 10ms estimate for model cloning
            
            print("TEMPLATE DEBUG: Cloning boss template...")
            local boss = template:Clone()
            
            if not boss then
                error("Failed to clone boss template")
            end
            
            -- Validate cloned model
            local humanoid = boss:FindFirstChild("Humanoid")
            local rootPart = boss:FindFirstChild("HumanoidRootPart")
            
            if not humanoid then
                error("Cloned boss missing Humanoid")
            end
            
            if not rootPart then
                error("Cloned boss missing HumanoidRootPart")
            end
            
            print("TEMPLATE DEBUG: Boss model validation passed")
            
            -- Yield again before property setup
            FrameBudgetManager.yieldIfNeeded(0.005) -- 5ms estimate for property setup
            
            -- ENHANCED: Setup with validation
            print("TEMPLATE DEBUG: Setting up boss properties...")
            humanoid.MaxHealth = BossConfig.boss.health
            humanoid.Health = BossConfig.boss.health
            humanoid.WalkSpeed = BossConfig.boss.walkSpeed
            humanoid.JumpPower = 0 -- Prevent jumping
            humanoid.PlatformStand = false -- Allow normal movement
            -- Disable default health bar and nametag
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            
            print("TEMPLATE DEBUG: Boss humanoid configured - Health:", humanoid.Health, "Speed:", humanoid.WalkSpeed, "DisplayDistance: None")
            
            -- Set default properties but DON'T set position (will be set by caller)
            rootPart.Anchored = false
            print("TEMPLATE DEBUG: Boss root part configured - Anchored:", rootPart.Anchored)
            
            return boss
        end)
        
        local loadTime = tick() - startTime
        
        if success and result then
            print("TEMPLATE DEBUG: Boss template loaded successfully in", math.floor(loadTime * 1000), "ms")
            callback(result)
        else
            warn("TEMPLATE ERROR: Failed to load boss template:", result)
            print("TEMPLATE DEBUG: Load failed after", math.floor(loadTime * 1000), "ms")
            callback(nil)
        end
    end)
end

function TemplateManager.loadEnemyTemplate(spawnPosition: Vector3, enemyConfig: any?): Model
    local template = ServerStorage:FindFirstChild(BossConfig.templates.enemyName)
    if not template then
        error("EnemyTemplate not found! Did you create it in ServerStorage?")
    end
    
    local enemy = template:Clone()
    
    -- Setup enemy properties (use provided config or defaults)
    local humanoid = enemy:FindFirstChild("Humanoid") :: Humanoid
    if humanoid and enemyConfig then
        humanoid.MaxHealth = enemyConfig.health or 30
        humanoid.Health = enemyConfig.health or 30
        humanoid.WalkSpeed = enemyConfig.speed or 8
        humanoid.JumpPower = 0
        humanoid.PlatformStand = false
    end
    
    -- Set spawn position
    local rootPart = enemy:FindFirstChild("HumanoidRootPart") :: BasePart
    if rootPart then
        rootPart.Position = spawnPosition
        rootPart.Anchored = false
    end
    
    return enemy
end

function TemplateManager.getBossTemplate(): Model?
    return ServerStorage:FindFirstChild(BossConfig.templates.bossName)
end

function TemplateManager.getEnemyTemplate(): Model?
    return ServerStorage:FindFirstChild(BossConfig.templates.enemyName)
end

-- Initialize template validation
function TemplateManager.initialize()
    if BossConfig.templates.validateOnStart then
        return TemplateManager.validateTemplates()
    end
    return true
end

return TemplateManager 