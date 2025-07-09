-- Camera system for first-person lock with crosshair
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
local shakeConnection = nil

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
    
    print("Camera locked to first person mode")
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
    
    -- Start RenderStepped connection for smooth camera shake
    if not shakeConnection then
        shakeConnection = RunService.RenderStepped:Connect(function(deltaTime)
            if IsShaking then
                ElapsedShakeTime = tick() - ShakeStartTime

                if ShakeDuration > 0 and ElapsedShakeTime >= ShakeDuration then
                    CameraSystem:StopShake()
                    return
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

                -- Apply the offsets to the camera's CFrame
                -- We create a new CFrame with the offset and then multiply it by the current camera CFrame.
                -- This ensures the player's rotation input is still respected.
                local shakeCFrame = CFrame.new(xOffset, yOffset, zOffset)
                camera.CFrame = camera.CFrame * shakeCFrame
            end
        end)
    end
    
    print("Screen shake started - duration:", duration, "intensity:", intensity, "speed:", speed)
end

function CameraSystem:StopShake()
    IsShaking = false
    if shakeConnection then
        shakeConnection:Disconnect()
        shakeConnection = nil
    end
end

-- Legacy function for backward compatibility
function CameraSystem:ShakeScreen(intensity, duration)
    self:StartShake(duration, intensity, 15) -- Convert old parameters to new format
end

return CameraSystem 