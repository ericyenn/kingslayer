-- Camera system for first-person lock with crosshair
local CameraSystem = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Crosshair UI elements
local crosshairGui = nil

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

return CameraSystem 