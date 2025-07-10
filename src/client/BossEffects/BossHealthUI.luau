-- BossHealthUI.luau
-- Legend of Zelda: Breath of the Wild style boss health bar

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BossHealthUI = {}

-- UI State
local isVisible = false
local currentHealth = 0
local maxHealth = 0
local bossName = "Boss"
local healthStacks = 1 -- For multi-phase bosses (x2, x3, etc.)
local currentStack = 1

-- UI Components
local screenGui = nil
local mainFrame = nil
local bossNameLabel = nil
local healthBarFrame = nil
local healthBarFill = nil
local multiplierLabel = nil

-- Configuration - Authentic BotW Style
local CONFIG = {
    -- Health bar dimensions (authentic BotW - thinner bar)
    BAR_WIDTH = 480,
    BAR_HEIGHT = 8, -- Much thinner like real BotW
    CORNER_RADIUS = 4, -- Proportional to thinner bar
    
    -- BotW Color Scheme
    ACTIVE_HEALTH_COLOR = Color3.fromRGB(255, 200, 50), -- Bright yellow/orange
    EMPTY_HEALTH_COLOR = Color3.fromRGB(60, 60, 60), -- Dark gray
    BAR_BACKGROUND_COLOR = Color3.fromRGB(25, 25, 25), -- Very dark background
    BAR_BORDER_COLOR = Color3.fromRGB(200, 200, 200), -- Light gray border
    
    -- Typography (BotW style)
    NAME_COLOR = Color3.fromRGB(255, 255, 255),
    NAME_OUTLINE_COLOR = Color3.fromRGB(0, 0, 0),
    MULTIPLIER_COLOR = Color3.fromRGB(255, 200, 50),
    
    -- BotW Positioning
    TOP_MARGIN = 40, -- Closer to top edge
    NAME_HEIGHT = 32, -- Increased height for larger text
    BAR_MARGIN_TOP = 8,
    
    -- Animation timings
    APPEAR_DURATION = 0.6,
    HEALTH_DRAIN_DURATION = 0.4,
    PHASE_TRANSITION_DURATION = 0.8,
    
    -- Transparency states
    IDLE_TRANSPARENCY = 0.15, -- Slight transparency when not taking damage
    ACTIVE_TRANSPARENCY = 0, -- Full opacity when taking damage
    TRANSITION_DURATION = 0.3,
}

-- Create the authentic BotW-style health bar UI
local function createHealthBarUI()
    -- Main screen GUI
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BossHealthUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 100
    screenGui.Parent = playerGui
    
    -- Main container frame (top-center positioning)
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, CONFIG.BAR_WIDTH + 100, 0, CONFIG.NAME_HEIGHT + CONFIG.BAR_HEIGHT + CONFIG.BAR_MARGIN_TOP + 20)
    mainFrame.Position = UDim2.new(0.5, -(CONFIG.BAR_WIDTH + 100) / 2, 0, CONFIG.TOP_MARGIN)
    mainFrame.BackgroundTransparency = 1
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.Parent = screenGui
    
    -- Boss name label (BotW typography) - Centered on health bar
    bossNameLabel = Instance.new("TextLabel")
    bossNameLabel.Name = "BossNameLabel"
    bossNameLabel.Size = UDim2.new(0, CONFIG.BAR_WIDTH, 0, CONFIG.NAME_HEIGHT) -- Match bar width for perfect centering
    bossNameLabel.Position = UDim2.new(0.5, -CONFIG.BAR_WIDTH / 2, 0, 0) -- Center relative to main frame
    bossNameLabel.BackgroundTransparency = 1
    bossNameLabel.Text = bossName
    bossNameLabel.TextColor3 = CONFIG.NAME_COLOR
    bossNameLabel.TextSize = 24 -- Increased from 20 to 24 for larger text
    bossNameLabel.TextStrokeTransparency = 0.3 -- Subtle outline
    bossNameLabel.TextStrokeColor3 = CONFIG.NAME_OUTLINE_COLOR
    bossNameLabel.Font = Enum.Font.GothamMedium -- Clean, readable font
    bossNameLabel.TextXAlignment = Enum.TextXAlignment.Center
    bossNameLabel.Parent = mainFrame
    
    -- Health stack multiplier (x2, x3, etc.)
    multiplierLabel = Instance.new("TextLabel")
    multiplierLabel.Name = "MultiplierLabel"
    multiplierLabel.Size = UDim2.new(0, 50, 0, CONFIG.NAME_HEIGHT)
    multiplierLabel.Position = UDim2.new(1, -50, 0, 0)
    multiplierLabel.BackgroundTransparency = 1
    multiplierLabel.Text = ""
    multiplierLabel.TextColor3 = CONFIG.MULTIPLIER_COLOR
    multiplierLabel.TextSize = 20 -- Increased from 18 to 20
    multiplierLabel.TextStrokeTransparency = 0.3
    multiplierLabel.TextStrokeColor3 = CONFIG.NAME_OUTLINE_COLOR
    multiplierLabel.Font = Enum.Font.GothamBold
    multiplierLabel.TextXAlignment = Enum.TextXAlignment.Center
    multiplierLabel.Visible = false
    multiplierLabel.Parent = mainFrame
    
    -- Health bar background frame with rounded corners
    healthBarFrame = Instance.new("Frame")
    healthBarFrame.Name = "HealthBarFrame"
    healthBarFrame.Size = UDim2.new(0, CONFIG.BAR_WIDTH, 0, CONFIG.BAR_HEIGHT)
    healthBarFrame.Position = UDim2.new(0.5, -CONFIG.BAR_WIDTH / 2, 0, CONFIG.NAME_HEIGHT + CONFIG.BAR_MARGIN_TOP)
    healthBarFrame.BackgroundColor3 = CONFIG.BAR_BACKGROUND_COLOR
    healthBarFrame.BorderColor3 = CONFIG.BAR_BORDER_COLOR
    healthBarFrame.BorderSizePixel = 1
    healthBarFrame.Parent = mainFrame
    
    -- Rounded corners for health bar background
    local healthBarCorner = Instance.new("UICorner")
    healthBarCorner.CornerRadius = UDim.new(0, CONFIG.CORNER_RADIUS)
    healthBarCorner.Parent = healthBarFrame
    
    -- Health bar fill (smooth continuous bar)
    healthBarFill = Instance.new("Frame")
    healthBarFill.Name = "HealthBarFill"
    healthBarFill.Size = UDim2.new(1, -2, 1, -2) -- Start at full width, subtract border
    healthBarFill.Position = UDim2.new(0, 1, 0, 1) -- Account for border
    healthBarFill.BackgroundColor3 = CONFIG.ACTIVE_HEALTH_COLOR
    healthBarFill.BorderSizePixel = 0
    healthBarFill.Parent = healthBarFrame
    
    -- Rounded corners for health bar fill
    local healthFillCorner = Instance.new("UICorner")
    healthFillCorner.CornerRadius = UDim.new(0, CONFIG.CORNER_RADIUS - 1)
    healthFillCorner.Parent = healthBarFill
    
    print("BossHealthUI: Authentic BotW-style continuous health bar created")
end

-- Update health bar with smooth right-to-left depletion
local function updateHealthBar(healthPercent, animate, showDamageEffect)
    if not healthBarFill then return end
    
    local targetSize = UDim2.new(healthPercent, -2, 1, -2)
    
    if animate then
        -- Set active state for damage feedback
        if showDamageEffect then
            -- Flash effect for damage
            local flashTween = TweenService:Create(healthBarFill,
                TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
                {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}
            )
            flashTween:Play()
            
            -- Reset color after flash
            flashTween.Completed:Connect(function()
                healthBarFill.BackgroundColor3 = CONFIG.ACTIVE_HEALTH_COLOR
            end)
        end
        
        -- Smooth size transition
        local sizeTween = TweenService:Create(healthBarFill,
            TweenInfo.new(CONFIG.HEALTH_DRAIN_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {Size = targetSize}
        )
        sizeTween:Play()
    else
        -- Instant update
        healthBarFill.Size = targetSize
        healthBarFill.BackgroundColor3 = CONFIG.ACTIVE_HEALTH_COLOR
    end
end

-- Set transparency state (idle vs active)
local function setTransparencyState(isActive)
    if not mainFrame then return end
    
    local targetTransparency = isActive and CONFIG.ACTIVE_TRANSPARENCY or CONFIG.IDLE_TRANSPARENCY
    
    -- Apply transparency to individual elements since Frame doesn't have GroupTransparency
    if bossNameLabel then
        local nameTween = TweenService:Create(bossNameLabel,
            TweenInfo.new(CONFIG.TRANSITION_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {TextTransparency = targetTransparency}
        )
        nameTween:Play()
    end
    
    if healthBarFrame then
        local frameTween = TweenService:Create(healthBarFrame,
            TweenInfo.new(CONFIG.TRANSITION_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {BackgroundTransparency = targetTransparency}
        )
        frameTween:Play()
    end
    
    if healthBarFill then
        local fillTween = TweenService:Create(healthBarFill,
            TweenInfo.new(CONFIG.TRANSITION_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {BackgroundTransparency = targetTransparency}
        )
        fillTween:Play()
    end
    
    if multiplierLabel and multiplierLabel.Visible then
        local multiplierTween = TweenService:Create(multiplierLabel,
            TweenInfo.new(CONFIG.TRANSITION_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {TextTransparency = targetTransparency}
        )
        multiplierTween:Play()
    end
end

-- Update multiplier display
local function updateMultiplierDisplay()
    if not multiplierLabel then return end
    
    if healthStacks > 1 then
        multiplierLabel.Text = "x" .. currentStack
        multiplierLabel.Visible = true
    else
        multiplierLabel.Visible = false
    end
end

-- Public functions
function BossHealthUI:Show(health, maxHp, name, stacks)
    if isVisible then return end
    
    currentHealth = health or 1000
    maxHealth = maxHp or 1000
    bossName = name or "Boss"
    healthStacks = stacks or 1
    currentStack = healthStacks
    
    print("BossHealthUI: Showing authentic BotW health bar -", bossName, "(" .. currentHealth .. "/" .. maxHealth .. ") Stacks:", healthStacks)
    
    -- Create UI if it doesn't exist
    if not screenGui then
        createHealthBarUI()
    end
    
    -- Update boss name and multiplier
    if bossNameLabel then
        bossNameLabel.Text = bossName
    end
    updateMultiplierDisplay()
    
    -- Set initial health
    local healthPercent = currentHealth / maxHealth
    updateHealthBar(healthPercent, false)
    
    -- Show with BotW-style animation
    isVisible = true
    mainFrame.Visible = true
    mainFrame.Position = UDim2.new(0.5, -(CONFIG.BAR_WIDTH + 100) / 2, 0, CONFIG.TOP_MARGIN - 20) -- Start higher
    
    -- Set initial transparency for all elements
    if bossNameLabel then bossNameLabel.TextTransparency = 1 end
    if healthBarFrame then healthBarFrame.BackgroundTransparency = 1 end
    if healthBarFill then healthBarFill.BackgroundTransparency = 1 end
    if multiplierLabel then multiplierLabel.TextTransparency = 1 end
    
    -- Smooth slide-in animation
    local appearTween = TweenService:Create(mainFrame,
        TweenInfo.new(CONFIG.APPEAR_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -(CONFIG.BAR_WIDTH + 100) / 2, 0, CONFIG.TOP_MARGIN)}
    )
    appearTween:Play()
    
    -- Animate elements appearing
    task.spawn(function()
        task.wait(CONFIG.APPEAR_DURATION * 0.2)
        
        -- Animate name appearing
        if bossNameLabel then
            local nameTween = TweenService:Create(bossNameLabel,
                TweenInfo.new(CONFIG.APPEAR_DURATION * 0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                {TextTransparency = CONFIG.IDLE_TRANSPARENCY}
            )
            nameTween:Play()
        end
        
        -- Animate health bar frame appearing
        if healthBarFrame then
            local frameTween = TweenService:Create(healthBarFrame,
                TweenInfo.new(CONFIG.APPEAR_DURATION * 0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                {BackgroundTransparency = CONFIG.IDLE_TRANSPARENCY}
            )
            frameTween:Play()
        end
        
        -- Animate multiplier appearing
        if multiplierLabel and multiplierLabel.Visible then
            local multiplierTween = TweenService:Create(multiplierLabel,
                TweenInfo.new(CONFIG.APPEAR_DURATION * 0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                {TextTransparency = CONFIG.IDLE_TRANSPARENCY}
            )
            multiplierTween:Play()
        end
        
        -- Animate health bar fill appearing
        task.wait(CONFIG.APPEAR_DURATION * 0.2)
        updateHealthBar(healthPercent, true, false)
    end)
end

function BossHealthUI:Hide()
    if not isVisible then return end
    
    print("BossHealthUI: Hiding authentic BotW health bar")
    isVisible = false
    
    if mainFrame then
        -- Animate individual elements disappearing
        if bossNameLabel then
            local nameTween = TweenService:Create(bossNameLabel,
                TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
                {TextTransparency = 1}
            )
            nameTween:Play()
        end
        
        if healthBarFrame then
            local frameTween = TweenService:Create(healthBarFrame,
                TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
                {BackgroundTransparency = 1}
            )
            frameTween:Play()
        end
        
        if healthBarFill then
            local fillTween = TweenService:Create(healthBarFill,
                TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
                {BackgroundTransparency = 1}
            )
            fillTween:Play()
        end
        
        if multiplierLabel then
            local multiplierTween = TweenService:Create(multiplierLabel,
                TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
                {TextTransparency = 1}
            )
            multiplierTween:Play()
        end
        
        -- Animate position
        local hideTween = TweenService:Create(mainFrame,
            TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, -(CONFIG.BAR_WIDTH + 100) / 2, 0, CONFIG.TOP_MARGIN - 20)}
        )
        hideTween:Play()
        
        hideTween.Completed:Connect(function()
            mainFrame.Visible = false
        end)
    end
end

function BossHealthUI:UpdateHealth(newHealth, newMaxHealth)
    if not isVisible then return end
    
    local previousHealth = currentHealth
    currentHealth = newHealth or currentHealth
    maxHealth = newMaxHealth or maxHealth
    
    local healthPercent = currentHealth / maxHealth
    
    print("BossHealthUI: Updating health to", currentHealth .. "/" .. maxHealth, "(" .. math.floor(healthPercent * 100) .. "%)")
    
    -- Set active state for damage feedback
    setTransparencyState(true)
    
    -- Check for phase transition (health bar fully depleted)
    if healthPercent <= 0 and currentStack > 1 then
        -- Phase transition - new health bar
        task.spawn(function()
            task.wait(CONFIG.PHASE_TRANSITION_DURATION * 0.3)
            currentStack = currentStack - 1
            updateMultiplierDisplay()
            
            -- Reset to full health for next phase
            currentHealth = maxHealth
            updateHealthBar(1.0, true, false)
        end)
    else
        -- Normal health update with damage effect
        task.spawn(function()
            updateHealthBar(healthPercent, true, previousHealth > currentHealth)
        end)
    end
    
    -- Return to idle state after damage
    task.spawn(function()
        task.wait(1.0) -- Stay active for 1 second
        setTransparencyState(false)
    end)
end

function BossHealthUI:IsVisible()
    return isVisible
end

function BossHealthUI:Cleanup()
    if screenGui then
        screenGui:Destroy()
        screenGui = nil
        mainFrame = nil
        bossNameLabel = nil
        healthBarFrame = nil
        healthBarFill = nil
        multiplierLabel = nil
    end
    isVisible = false
    currentStack = 1
    healthStacks = 1
    print("BossHealthUI: Cleaned up")
end

-- Initialize
print("BossHealthUI: Authentic BotW-style module loaded")

return BossHealthUI 