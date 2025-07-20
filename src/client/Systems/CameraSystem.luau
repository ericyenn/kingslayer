-- New Camera System with third-person/first-person toggle
local CameraSystem = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- Camera system variables
local mobileDragging = false
local dragging = false
local distance = 0.5 -- Start in first-person mode

-- Rotation variables
local xRot = 0
local yRot = 0

-- Walk bobbing variables
local func1 = 0
local func2 = 0
local func3 = 0
local func4 = 0
local val = 0
local val2 = 0

-- Camera sway variables
local Turn = 0

-- Crosshair UI elements
local crosshairGui = nil

-- Connections
local renderStepConnection = nil
local inputBeganConnection = nil
local inputEndedConnection = nil
local cameraChangedConnection = nil

-- Cache for performance optimization
local lastFrameTime = tick()
local TARGET_FPS = 60
local FRAME_TIME_BUDGET = 1/TARGET_FPS

-- Helper function for linear interpolation
local function lerp(a, b, c)
    return a + (b - a) * c
end

-- Initialize camera rotation from current camera
local function initializeCameraRotation()
    local camX, camY, camZ = camera.CFrame:ToEulerAnglesXYZ()
    xRot = camY
    yRot = camX
end

-- Handle body transparency - hide head and accessories in first-person
local function updateBodyTransparency()
    if not camera.CameraSubject or not camera.CameraSubject.Parent then return end
    
    for _, v in pairs(camera.CameraSubject.Parent:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture")) and not v:FindFirstAncestorOfClass("Tool") then
            -- In first-person mode, hide head and accessories but keep body visible
            if distance <= 0.5 then
                -- Make head and accessories completely invisible in first-person
                if v.Name == "Head" or v.Parent.Name == "Head" or v:FindFirstAncestor("Head") then
                    v.LocalTransparencyModifier = 1
                elseif v:FindFirstAncestorOfClass("Accessory") then
                    -- Hide all accessory parts (hats, hair, etc.)
                    v.LocalTransparencyModifier = 1
                else
                    v.LocalTransparencyModifier = 0 -- Keep body visible
                end
            else
                -- Make everything visible in third-person
                v.LocalTransparencyModifier = 0
            end
        end
    end
end

-- Calculate movement-based bobbing effects
local function calculateMovementBobbing(deltaTime)
    local character = player.Character
    if not character then return CFrame.new() end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return CFrame.new()
    end
    
    local rootPart = humanoid.RootPart
    if not rootPart then
        return CFrame.new()
    end
    
    local rootMagnitude = Vector3.new(rootPart.Velocity.X, 0, rootPart.Velocity.Z).Magnitude
    
    -- Smooth deltaTime scaling for consistent bobbing with performance protection
    local scaledDeltaTime = math.min(deltaTime * 30, 2) -- Cap scaled deltaTime to prevent spikes
    
    -- Handle delta time spikes and movement-based bobbing calculations
    if scaledDeltaTime > 1.5 then
        func1 = lerp(func1, 0, 0.1)
        func2 = lerp(func2, 0, 0.1)
    else
        -- Only calculate bobbing if player is moving
        if rootMagnitude > 0.5 then
            -- Pre-calculate time-based values with bobbing intensity
            local timeValue = tick() * 14
            local cosTimeValue = math.cos(timeValue)
            local cosTimeValueSlow = math.cos(timeValue * 0.9)
            
            func1 = lerp(func1, cosTimeValue * 0.25 * scaledDeltaTime, 0.08 * scaledDeltaTime)
            func2 = lerp(func2, cosTimeValueSlow * 0.15 * scaledDeltaTime, 0.08 * scaledDeltaTime)
        else
            -- Gradually reduce bobbing when stationary
            local lerpFactor = 0.1 * deltaTime
            func1 = lerp(func1, 0, lerpFactor)
            func2 = lerp(func2, 0, lerpFactor)
        end
    end
    
    -- Reset some sway-related variables
    val2 = lerp(val2, 0, 0.2 * deltaTime)
    func4 = lerp(func4, 0, 0.2 * deltaTime)
    val = lerp(val, 0, 0.15 * deltaTime)
    
    -- Create bobbing CFrame
    local isMoving = rootMagnitude > 0.5
    if isMoving then
        -- Apply vertical bobbing and slight horizontal sway
        return CFrame.fromEulerAnglesXYZ(math.rad(func1 * 1.5), math.rad(func2 * 1.0), math.rad(func1 * 0.5))
    else
        -- No movement bobbing when stationary
        return CFrame.new()
    end
end

-- Calculate mouse-based sway effects
local function calculateMouseSway(mouseDelta, deltaTime)
    -- Update sway variables using mouse input
    local clampedMouseX = math.clamp(mouseDelta.X, -5.0, 5.0)
    local clampedMouseXSway = math.clamp(mouseDelta.X, -3.5, 3.5)
    
    Turn = lerp(Turn, clampedMouseX, math.min(6 * deltaTime, 0.5))
    func3 = lerp(func3, clampedMouseXSway, 0.25 * deltaTime)
    
    -- Return sway CFrame
    return CFrame.Angles(0, 0, math.rad(Turn * 0.8))
end

-- Main camera update function
local function updateCamera(deltaTime)
    local currentFrameTime = tick()
    
    -- Performance protection: skip frame if budget exceeded
    if currentFrameTime - lastFrameTime < FRAME_TIME_BUDGET * 0.8 then
        return
    end
    
    -- Get character and humanoid for body rotation
    local character = player.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    -- Set mouse behavior based on distance
    if distance <= 0.5 then
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    else
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
    
    local mouseDelta = UserInputService:GetMouseDelta()
    local mouseSensitivity = UserGameSettings.MouseSensitivity
    
    if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
        dragging = false
    end
    
    -- Update rotation if dragging or in first-person mode
    if dragging or mobileDragging or UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
        if dragging then
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
        end
        xRot += math.rad((mouseDelta.X * 0.25) * mouseSensitivity * -1)
        yRot += math.rad((mouseDelta.Y * 0.25) * mouseSensitivity * -1)
    end
    
    -- Clamp vertical rotation
    yRot = math.clamp(yRot, math.rad(-75), math.rad(75))
    
    -- Make body follow camera direction (rotate character to match camera horizontal rotation)
    if rootPart and humanoid and humanoid.Health > 0 then
        -- Create rotation CFrame from camera's horizontal rotation
        local bodyRotation = CFrame.fromEulerAnglesYXZ(0, xRot, 0)
        -- Apply rotation while keeping the character's position
        rootPart.CFrame = CFrame.new(rootPart.Position) * bodyRotation
    end
    
    -- Calculate effects for enhanced camera feel
    local movementBobbing = CFrame.new()
    local mouseSway = CFrame.new()
    
    -- Only apply bobbing and sway in first-person mode
    if distance <= 0.5 then
        movementBobbing = calculateMovementBobbing(deltaTime)
        mouseSway = calculateMouseSway(mouseDelta, deltaTime)
    end
    
    -- Combine effects
    local effectsTransform = movementBobbing * mouseSway
    
    -- Update camera position and rotation
    if camera.CameraSubject and camera.CameraSubject.Position then
        camera.Focus = CFrame.new(camera.CameraSubject.Position)
        camera.CFrame = camera.Focus
        
        -- Add camera offset to reduce body visibility in first-person
        local cameraOffset = Vector3.new(0, 0, 0)
        if distance <= 0.5 then
            -- Move camera slightly back and up to reduce body visibility
            cameraOffset = Vector3.new(0, 1.1, -0.2)
        end
        
        camera.CFrame = camera.CFrame * CFrame.fromEulerAnglesYXZ(yRot, xRot, 0) * CFrame.new(cameraOffset.X, cameraOffset.Y, distance + cameraOffset.Z)
        
        -- Apply effects in first-person mode
        if distance <= 0.5 then
            camera.CFrame = camera.CFrame * effectsTransform
        end
    end
    
    lastFrameTime = currentFrameTime
end

function CameraSystem:Initialize()
    -- Set up global reference for other systems
    _G.CameraSystem = self
    
    -- Wait for character and set camera subject
    local character = player.Character or player.CharacterAdded:Wait()
    local head = character:WaitForChild("Head")
    
    -- Set up camera
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CameraSubject = head
    
    -- Initialize camera rotation
    initializeCameraRotation()
    
    -- Create crosshair for first-person mode
    self:CreateCrosshair()
    
    -- Set up input connections
    inputBeganConnection = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            dragging = true
        end
        if input.UserInputType == Enum.UserInputType.Touch then
            mobileDragging = true
        end
    end)
    
    inputEndedConnection = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            dragging = false
        end
        if input.UserInputType == Enum.UserInputType.Touch then
            mobileDragging = false
        end
    end)
    
    -- Set up camera property changed connection for transparency
    cameraChangedConnection = camera:GetPropertyChangedSignal("CFrame"):Connect(updateBodyTransparency)
    
    -- Set up main camera update loop with deltaTime
    renderStepConnection = RunService:BindToRenderStep("Camera", Enum.RenderPriority.Camera.Value, updateCamera)
    
    -- Handle character respawning
    player.CharacterAdded:Connect(function(newCharacter)
        local newHead = newCharacter:WaitForChild("Head")
        camera.CameraSubject = newHead
        initializeCameraRotation()
    end)
    
    print("Enhanced Camera System initialized - Distance:", distance, "(0.5 = first-person with bobbing/sway, higher = third-person)")
end

function CameraSystem:CreateCrosshair()
    -- Clean up existing crosshair first
    if crosshairGui then
        crosshairGui:Destroy()
    end
    
    -- Create crosshair GUI
    crosshairGui = Instance.new("ScreenGui")
    crosshairGui.Name = "CrosshairGui"
    crosshairGui.ResetOnSpawn = false
    crosshairGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    crosshairGui.IgnoreGuiInset = true
    crosshairGui.Parent = playerGui
    
    -- Create a simple dot crosshair
    local crosshairDot = Instance.new("Frame")
    crosshairDot.Name = "CrosshairDot"
    crosshairDot.Size = UDim2.new(0, 6, 0, 6)
    crosshairDot.Position = UDim2.new(0.5, -3, 0.5, -3)
    crosshairDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    crosshairDot.BorderSizePixel = 0
    crosshairDot.Parent = crosshairGui
    
    -- Make it circular
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = crosshairDot
    
    -- Add black outline for visibility
    local outline = Instance.new("UIStroke")
    outline.Color = Color3.fromRGB(0, 0, 0)
    outline.Thickness = 1
    outline.Parent = crosshairDot
    
    -- Only show crosshair in first-person mode
    crosshairGui.Enabled = (distance <= 0.5)
    
    print("Crosshair created")
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

-- Set camera distance (0.5 = first-person, higher = third-person)
function CameraSystem:SetDistance(newDistance)
    distance = math.max(0.5, newDistance)
    
    -- Update crosshair visibility based on distance
    if crosshairGui then
        crosshairGui.Enabled = (distance <= 0.5)
    end
    
    -- Update mouse cursor visibility
    UserInputService.MouseIconEnabled = (distance > 0.5)
    
    print("Camera distance set to:", distance)
end

-- Get current camera distance
function CameraSystem:GetDistance()
    return distance
end

-- Toggle between first-person and third-person
function CameraSystem:ToggleDistance()
    if distance <= 0.5 then
        self:SetDistance(5) -- Switch to third-person
    else
        self:SetDistance(0.5) -- Switch to first-person
    end
end

-- Legacy compatibility functions for screen shake (simplified)
function CameraSystem:StartShake(duration, intensity, speed)
    -- This new camera system doesn't have built-in shake
    -- You could implement it here if needed
    print("Screen shake not implemented in this camera system")
end

function CameraSystem:StopShake()
    print("Screen shake not implemented in this camera system")
end

function CameraSystem:ShakeScreen(intensity, duration)
    self:StartShake(duration, intensity, 15)
end

-- Legacy compatibility for walk bobbing (not implemented in new system)
function CameraSystem:StartWalkBobbing()
    print("Walk bobbing not implemented in this camera system")
end

function CameraSystem:StopWalkBobbing()
    print("Walk bobbing not implemented in this camera system")
end

function CameraSystem:StartCameraSway()
    print("Camera sway not implemented in this camera system")
end

function CameraSystem:StopCameraSway()
    print("Camera sway not implemented in this camera system")
end

-- Cleanup function
function CameraSystem:Cleanup()
    -- Disconnect all connections
    if renderStepConnection then
        RunService:UnbindFromRenderStep("Camera")
        renderStepConnection = nil
    end
    
    if inputBeganConnection then
        inputBeganConnection:Disconnect()
        inputBeganConnection = nil
    end
    
    if inputEndedConnection then
        inputEndedConnection:Disconnect()
        inputEndedConnection = nil
    end
    
    if cameraChangedConnection then
        cameraChangedConnection:Disconnect()
        cameraChangedConnection = nil
    end
    
    -- Clean up crosshair GUI
    if crosshairGui then
        crosshairGui:Destroy()
        crosshairGui = nil
    end
    
    -- Reset camera and input settings
    camera.CameraType = Enum.CameraType.Custom
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
    
    -- Reset character transparency
    if camera.CameraSubject and camera.CameraSubject.Parent then
        for _, v in pairs(camera.CameraSubject.Parent:GetDescendants()) do
            if v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture") then
                v.LocalTransparencyModifier = 0
            end
        end
    end
    
    print("Enhanced Camera System cleanup completed")
end

return CameraSystem 