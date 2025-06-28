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
    
    print("Camera locked to first person with crosshair")
end

function CameraSystem:CreateCrosshair()
    -- Create crosshair GUI
    crosshairGui = Instance.new("ScreenGui")
    crosshairGui.Name = "CrosshairGui"
    crosshairGui.ResetOnSpawn = false
    crosshairGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    crosshairGui.Parent = playerGui
    
    -- Crosshair frame (center of screen)
    local crosshairFrame = Instance.new("Frame")
    crosshairFrame.Name = "Crosshair"
    crosshairFrame.Size = UDim2.new(0, 20, 0, 20)
    crosshairFrame.Position = UDim2.new(0.5, -10, 0.5, -10) -- Center of screen
    crosshairFrame.BackgroundTransparency = 1
    crosshairFrame.Parent = crosshairGui
    
    -- Horizontal line
    local horizontalLine = Instance.new("Frame")
    horizontalLine.Name = "HorizontalLine"
    horizontalLine.Size = UDim2.new(0, 12, 0, 2)
    horizontalLine.Position = UDim2.new(0.5, -6, 0.5, -1)
    horizontalLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    horizontalLine.BorderSizePixel = 0
    horizontalLine.Parent = crosshairFrame
    
    -- Vertical line
    local verticalLine = Instance.new("Frame")
    verticalLine.Name = "VerticalLine"
    verticalLine.Size = UDim2.new(0, 2, 0, 12)
    verticalLine.Position = UDim2.new(0.5, -1, 0.5, -6)
    verticalLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    verticalLine.BorderSizePixel = 0
    verticalLine.Parent = crosshairFrame
    
    -- Add black outline for visibility
    local hOutline = Instance.new("UIStroke")
    hOutline.Color = Color3.fromRGB(0, 0, 0)
    hOutline.Thickness = 1
    hOutline.Parent = horizontalLine
    
    local vOutline = Instance.new("UIStroke")
    vOutline.Color = Color3.fromRGB(0, 0, 0)
    vOutline.Thickness = 1
    vOutline.Parent = verticalLine
    
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

return CameraSystem 