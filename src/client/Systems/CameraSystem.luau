-- Camera system for first-person lock with crosshair, walk bobbing, sway, and R6 body visibility
local CameraSystem = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- Crosshair UI elements
local crosshairGui = nil

-- Screen shake variables (Perlin noise implementation)
local ShakeIntensity = 0.1 -- How strong the shake is
local ShakeSpeed = 15 -- How fast the shake oscillates  
local ShakeDuration = 0 -- How long the shake should last
local ElapsedShakeTime = 0
local InitialShakeIntensity = 0.1 -- Store the original intensity for fade out

local IsShaking = false
local ShakeStartTime = 0

-- Walk bobbing variables
local func1 = 0
local func2 = 0
local func3 = 0
local func4 = 0
local val = 0
local val2 = 0
local int = 5
local int2 = 5
local vect3 = Vector3.new()

-- Camera sway variables
local Turn = 0

-- Unified camera update connection
local mainCameraConnection = nil
local bodyVisibilityConnection = nil

-- Helper function for linear interpolation
local function lerp(a, b, c)
    return a + (b - a) * c
end

-- Calculate movement-based bobbing effects (vertical only, no sway)
local function calculateMovementBobbing(deltaTime, humanoid)
    if not humanoid or humanoid.Health <= 0 then
        return CFrame.new()
    end
    
    local rootPart = humanoid.RootPart
    local rootMagnitude = rootPart and Vector3.new(rootPart.Velocity.X, 0, rootPart.Velocity.Z).Magnitude or 0
    
    -- Smooth deltaTime scaling for consistent bobbing
    local scaledDeltaTime = math.min(deltaTime * 30, 2) -- Cap scaled deltaTime to prevent spikes
    
    -- Handle delta time spikes and movement-based bobbing calculations
    if scaledDeltaTime > 1.5 then
        func1 = lerp(func1, 0, 0.1)
        func2 = lerp(func2, 0, 0.1)
    else
        -- Only calculate vertical bobbing if player is moving
        if rootMagnitude > 0.5 then
            -- Pre-calculate time-based values with increased bobbing intensity (vertical only)
            local timeValue = tick() * 14
            func1 = lerp(func1, math.cos(timeValue) * 0.25 * scaledDeltaTime, 0.08 * scaledDeltaTime)
            func2 = lerp(func2, math.cos(timeValue * 0.9) * 0.15 * scaledDeltaTime, 0.08 * scaledDeltaTime)
        else
            -- Gradually reduce bobbing when stationary
            func1 = lerp(func1, 0, 0.1 * deltaTime)
            func2 = lerp(func2, 0, 0.1 * deltaTime)
        end
    end
    
    -- Reset sway-related variables to prevent any leftover sway effects
    val2 = lerp(val2, 0, 0.2 * deltaTime)
    func4 = lerp(func4, 0, 0.2 * deltaTime)
    val = lerp(val, 0, 0.15 * deltaTime)
    
    -- Create subtle vertical-only bobbing CFrame
    local isMoving = rootMagnitude > 0.5
    if isMoving then
        -- Only apply vertical bobbing (func1, func2) without any sway components
        return CFrame.fromEulerAnglesXYZ(math.rad(func1 * 1.5), math.rad(func2 * 1.0), 0)
    else
        -- No movement bobbing when stationary
        return CFrame.new()
    end
    
    -- Update camera zoom limits and look vector
    player.CameraMaxZoomDistance = 128
    player.CameraMinZoomDistance = 0.5
    vect3 = lerp(vect3, camera.CFrame.LookVector, 0.125 * deltaTime)
end

-- Calculate mouse-based sway effects (using mouse input)
local function calculateMouseSway(mouseDelta, deltaTime)
    -- Update both sway variables using the same mouse input
    Turn = lerp(Turn, math.clamp(mouseDelta.X, -5.0, 5.0), math.min(6 * deltaTime, 0.5))
    func3 = lerp(func3, math.clamp(mouseDelta.X, -3.5, 3.5), 0.25 * deltaTime)
    
    -- Return sway CFrame
    return CFrame.Angles(0, 0, math.rad(Turn * 0.8))
end

-- Calculate screen shake effects
local function calculateScreenShake(deltaTime)
    if not IsShaking then
        return CFrame.new()
    end
    
    ElapsedShakeTime = tick() - ShakeStartTime

    if ShakeDuration > 0 and ElapsedShakeTime >= ShakeDuration then
        CameraSystem:StopShake()
        return CFrame.new()
    end

    -- Calculate fade out factor (intensity decreases over time)
    local fadeOutFactor = 1
    if ShakeDuration > 0 then
        fadeOutFactor = math.max(0, 1 - (ElapsedShakeTime / ShakeDuration))
    end
    
    -- Apply fade out to current intensity
    local currentIntensity = InitialShakeIntensity * fadeOutFactor

    -- Generate Perlin noise offsets with fading intensity
    local xOffset = math.noise(ElapsedShakeTime * ShakeSpeed, 0, 0) * currentIntensity
    local yOffset = math.noise(0, ElapsedShakeTime * ShakeSpeed, 0) * currentIntensity
    local zOffset = math.noise(0, 0, ElapsedShakeTime * ShakeSpeed) * currentIntensity

    return CFrame.new(xOffset, yOffset, zOffset)
end

-- Combine all camera effects into a single transform
local function combineEffects(movementBobbing, mouseSway, screenShake)
    -- Apply effects in order: Movement Bobbing → Mouse Sway → Screen Shake
    return movementBobbing * mouseSway * screenShake
end

function CameraSystem:Initialize()
    -- Set up global reference for other systems
    _G.CameraSystem = self
    
    -- Lock to first person as shown in the DevForum guide
    -- https://devforum.roblox.com/t/how-to-make-player-lock-first-person/1785472/10
    player.CameraMode = Enum.CameraMode.LockFirstPerson
    
    -- Disable mouse cursor and create crosshair
    -- https://devforum.roblox.com/t/making-the-cursor-invisible/1143272
    UserInputService.MouseIconEnabled = false
    self:CreateCrosshair()
    
    -- Initialize unified camera system
    self:StartUnifiedCameraSystem()
    self:StartR6BodyVisibility()
    
    print("Camera locked to first person mode with unified dynamic effects")
    print("CameraSystem initialized successfully")
end

function CameraSystem:CreateCrosshair()
    -- Create crosshair GUI
    crosshairGui = Instance.new("ScreenGui")
    crosshairGui.Name = "CrosshairGui"
    crosshairGui.ResetOnSpawn = false
    crosshairGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    crosshairGui.IgnoreGuiInset = true -- This ensures proper centering
    crosshairGui.Parent = playerGui
    
    -- Create a simple dot crosshair
    local crosshairDot = Instance.new("Frame")
    crosshairDot.Name = "CrosshairDot"
    crosshairDot.Size = UDim2.new(0, 6, 0, 6) -- Small 6x6 pixel dot
    crosshairDot.Position = UDim2.new(0.5, -3, 0.5, -3) -- Perfect center
    crosshairDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- White dot
    crosshairDot.BorderSizePixel = 0
    crosshairDot.Parent = crosshairGui
    
    -- Make it circular
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0) -- Fully rounded = circle
    corner.Parent = crosshairDot
    
    -- Add black outline for visibility against all backgrounds
    local outline = Instance.new("UIStroke")
    outline.Color = Color3.fromRGB(0, 0, 0)
    outline.Thickness = 1
    outline.Parent = crosshairDot
    
    print("Crosshair dot created")
end

function CameraSystem:StartUnifiedCameraSystem()
    -- Wait for character and humanoid
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    
    -- Single unified camera update connection
    mainCameraConnection = RunService.RenderStepped:Connect(function(deltaTime)
        -- Stop all effects if character dies
        if humanoid.Health <= 0 then
            self:StopUnifiedCameraSystem()
            return
        end
        
        -- 1. Get mouse input ONCE
        local mouseDelta = UserInputService:GetMouseDelta()
        
        -- 2. Calculate movement-based effects (no mouse input)
        local movementBobbing = calculateMovementBobbing(deltaTime, humanoid)
        
        -- 3. Calculate mouse-based effects (using mouseDelta)
        local mouseSway = calculateMouseSway(mouseDelta, deltaTime)
        
        -- 4. Calculate screen shake (if active)
        local screenShake = calculateScreenShake(deltaTime)
        
        -- 5. Combine all effects into single transform
        local finalTransform = combineEffects(movementBobbing, mouseSway, screenShake)
        
        -- 6. Apply to camera ONCE
        camera.CFrame = camera.CFrame * finalTransform
    end)
    
    print("Unified camera system started")
end

function CameraSystem:StartR6BodyVisibility()
    -- Wait for character to ensure proper setup
    local function setupBodyVisibility()
        local character = player.Character
        if not character then return end
        
        bodyVisibilityConnection = RunService.RenderStepped:Connect(function()
            -- Check for R6 limbs and make them visible in first person
            if character:FindFirstChild("Right Arm") and character:FindFirstChild("Left Arm") then
                character:FindFirstChild("Right Arm").LocalTransparencyModifier = 0
                character:FindFirstChild("Left Arm").LocalTransparencyModifier = 0
                character:FindFirstChild("Right Leg").LocalTransparencyModifier = 0
                character:FindFirstChild("Left Leg").LocalTransparencyModifier = 0
                character:FindFirstChild("Torso").LocalTransparencyModifier = 0
                
                -- Set camera offset for better first-person view
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid.CameraOffset = Vector3.new(0, 0, -1)
                end
            end
        end)
    end
    
    -- Setup for current character
    if player.Character then
        setupBodyVisibility()
    end
    
    -- Setup for future character spawns
    player.CharacterAdded:Connect(function(character)
        -- Wait a moment for character to fully load
        task.wait(0.1)
        setupBodyVisibility()
        
        -- Also restart unified camera system for new character
        self:StopUnifiedCameraSystem()
        task.wait(0.1)
        self:StartUnifiedCameraSystem()
    end)
    
    print("R6 body visibility system started")
end

function CameraSystem:StopUnifiedCameraSystem()
    if mainCameraConnection then
        mainCameraConnection:Disconnect()
        mainCameraConnection = nil
        print("Unified camera system stopped")
    end
end

function CameraSystem:StopR6BodyVisibility()
    if bodyVisibilityConnection then
        bodyVisibilityConnection:Disconnect()
        bodyVisibilityConnection = nil
        print("R6 body visibility stopped")
    end
end

function CameraSystem:ShowCrosshair()
    if crosshairGui then
        crosshairGui.Enabled = true
    end
end

function CameraSystem:HideCrosshair()
    if crosshairGui then
        crosshairGui.Enabled = false
    end
end

function CameraSystem:StartShake(duration, intensity, speed)
    ShakeDuration = duration or 0.5 -- Default duration if not provided
    ShakeIntensity = intensity or 0.1 -- Default intensity
    InitialShakeIntensity = intensity or 0.1 -- Store initial intensity for fade out
    ShakeSpeed = speed or 15 -- Default speed

    IsShaking = true
    ShakeStartTime = tick()
    ElapsedShakeTime = 0
    
    print("Screen shake started - duration:", duration, "intensity:", intensity, "speed:", speed)
end

function CameraSystem:StopShake()
    IsShaking = false
end

-- Legacy function for backward compatibility
function CameraSystem:ShakeScreen(intensity, duration)
    self:StartShake(duration, intensity, 15) -- Convert old parameters to new format
end

-- Legacy compatibility functions (now consolidated into unified system)
function CameraSystem:StartWalkBobbing()
    -- This is now handled by the unified system
    print("Walk bobbing is now handled by unified camera system")
end

function CameraSystem:StopWalkBobbing()
    -- This is now handled by the unified system
    print("Walk bobbing stop is now handled by unified camera system")
end

function CameraSystem:StartCameraSway()
    -- This is now handled by the unified system
    print("Camera sway is now handled by unified camera system")
end

function CameraSystem:StopCameraSway()
    -- This is now handled by the unified system
    print("Camera sway stop is now handled by unified camera system")
end

-- Cleanup function to stop all camera effects
function CameraSystem:Cleanup()
    self:StopUnifiedCameraSystem()
    self:StopR6BodyVisibility()
    self:StopShake()
    print("CameraSystem cleanup completed")
end

return CameraSystem 