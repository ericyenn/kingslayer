-- Orbital Strike Renderer - Handles visual effects for orbital strike ability
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BossConfig = require(ReplicatedStorage.Shared.BossConfig)

local OrbitalStrikeRenderer = {}

-- Private variables
local activeCircles: {[number]: {part: BasePart, gui: SurfaceGui, position: Vector3}} = {}
local activeBeams: {[number]: {part: BasePart, beam: Beam}} = {}

-- Private functions
local function createWarningCircle(position: Vector3, index: number): {part: BasePart, gui: SurfaceGui, position: Vector3}
    local config = BossConfig.abilities.orbitalStrike
    
    -- Create invisible part at ground level
    local part = Instance.new("Part")
    part.Name = "OrbitalStrikeWarning_" .. index
    part.Size = Vector3.new(0.1, 0.1, 0.1)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Parent = workspace
    
    -- Create surface GUI for the circle
    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Face = Enum.NormalId.Top
    surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surfaceGui.PixelsPerStud = 10
    surfaceGui.Parent = part
    
    -- Create the warning circle frame
    local circle = Instance.new("Frame")
    circle.Name = "WarningCircle"
    circle.Size = UDim2.new(0, config.visualRadius * 20, 0, config.visualRadius * 20) -- 20 pixels per stud
    circle.Position = UDim2.new(0.5, -config.visualRadius * 10, 0.5, -config.visualRadius * 10)
    circle.BackgroundColor3 = config.circleColor
    circle.BackgroundTransparency = 0.5
    circle.BorderSizePixel = 0
    circle.Parent = surfaceGui
    
    -- Make it circular
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = circle
    
    -- Add pulsing animation
    local pulseInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    local pulseTween = TweenService:Create(circle, pulseInfo, {BackgroundTransparency = 0.8})
    pulseTween:Play()
    
    return {part = part, gui = surfaceGui, position = position}
end

local function createOrbitalBeam(position: Vector3, index: number): {part: BasePart, beam: Beam}
    local config = BossConfig.abilities.orbitalStrike
    
    -- Create beam start position high in the sky
    local skyHeight = 200
    local startPos = Vector3.new(position.X, position.Y + skyHeight, position.Z)
    
    -- Create start attachment part
    local startPart = Instance.new("Part")
    startPart.Name = "MeteorBeam_" .. index
    startPart.Size = Vector3.new(0.1, 0.1, 0.1)
    startPart.Position = startPos
    startPart.Anchored = true
    startPart.CanCollide = false
    startPart.Transparency = 1
    startPart.Parent = workspace
    
    -- Create end attachment part
    local endPart = Instance.new("Part")
    endPart.Name = "MeteorImpact_" .. index
    endPart.Size = Vector3.new(0.1, 0.1, 0.1)
    endPart.Position = position
    endPart.Anchored = true
    endPart.CanCollide = false
    endPart.Transparency = 1
    endPart.Parent = workspace
    
    -- Create attachments
    local startAttachment = Instance.new("Attachment")
    startAttachment.Parent = startPart
    
    local endAttachment = Instance.new("Attachment")
    endAttachment.Parent = endPart
    
    -- Create beam
    local beam = Instance.new("Beam")
    beam.Attachment0 = startAttachment
    beam.Attachment1 = endAttachment
    beam.Color = ColorSequence.new(config.beamColor)
    beam.Width0 = config.visualRadius * 0.5
    beam.Width1 = config.visualRadius * 0.5
    beam.Transparency = NumberSequence.new(0.2)
    beam.FaceCamera = true
    beam.Parent = startPart
    
    -- Create explosion effect at impact
    local explosion = Instance.new("Explosion")
    explosion.Position = position
    explosion.BlastRadius = config.visualRadius
    explosion.BlastPressure = 0 -- No physics effect
    explosion.Parent = workspace
    
    return {part = startPart, beam = beam}
end

-- Public functions
function OrbitalStrikeRenderer.handleOrbitalStrike(data: {[string]: any})
    local phase = data.phase
    local position = data.position
    local index = data.index
    
    if phase == "addCircle" and position and index then
        print("Adding meteor warning circle", index, "at position:", position)
        
        -- Create warning circle for this strike
        local circleData = createWarningCircle(position, index)
        activeCircles[index] = circleData
        
    elseif phase == "fireSingleStrike" and position and index then
        print("Firing meteor strike", index, "at position:", position)
        
        -- Remove warning circle for this strike
        local circleData = activeCircles[index]
        if circleData then
            circleData.part:Destroy()
            activeCircles[index] = nil
        end
        
        -- Create orbital beam for this strike
        local beamData = createOrbitalBeam(position, index)
        activeBeams[index] = beamData
        
    elseif phase == "cleanup" then
        print("Cleaning up meteor shower effects")
        
        -- Clean up any remaining circles
        for index, circleData in pairs(activeCircles) do
            circleData.part:Destroy()
            activeCircles[index] = nil
        end
        
        -- Clean up beams after duration
        for index, beamData in pairs(activeBeams) do
            -- Schedule cleanup
            Debris:AddItem(beamData.part, BossConfig.abilities.orbitalStrike.beamDuration)
            activeBeams[index] = nil
        end
    end
end

function OrbitalStrikeRenderer.cleanup()
    -- Clean up all active effects
    for index, circleData in pairs(activeCircles) do
        circleData.part:Destroy()
        activeCircles[index] = nil
    end
    
    for index, beamData in pairs(activeBeams) do
        beamData.part:Destroy()
        activeBeams[index] = nil
    end
end

return OrbitalStrikeRenderer 