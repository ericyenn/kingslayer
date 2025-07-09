local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local BossConfig = require(game.ReplicatedStorage.Shared.BossConfig)

local localPlayer = Players.LocalPlayer

-- Renderer state
local laserBeam = nil
local currentTarget = nil
local activeConnection = nil
local blinkTween = nil
local isBlinking = false
local lockOnAchieved = false

local LaserEyeRenderer = {}

local function createLaserBeam(startPos: Vector3, endPos: Vector3)
    -- Create start part and attachment
    local startPart = Instance.new("Part")
    startPart.Name = "LaserStart"
    startPart.Size = Vector3.new(0.1, 0.1, 0.1)
    startPart.Transparency = 1
    startPart.Anchored = true
    startPart.CanCollide = false
    startPart.Position = startPos
    startPart.Parent = workspace
    
    local startAttachment = Instance.new("Attachment")
    startAttachment.Parent = startPart
    
    -- Create end part and attachment
    local endPart = Instance.new("Part")
    endPart.Name = "LaserEnd"
    endPart.Size = Vector3.new(0.1, 0.1, 0.1)
    endPart.Transparency = 1
    endPart.Anchored = true
    endPart.CanCollide = false
    endPart.Position = endPos
    endPart.Parent = workspace
    
    local endAttachment = Instance.new("Attachment")
    endAttachment.Parent = endPart
    
    -- Create the laser beam
    local config = BossConfig.abilities.trackingShot
    local beam = Instance.new("Beam")
    beam.Name = "LaserEye"
    beam.Attachment0 = startAttachment
    beam.Attachment1 = endAttachment
    beam.Color = ColorSequence.new(config.laserColor)
    beam.Transparency = NumberSequence.new(config.laserTransparency)
    beam.Width0 = config.laserWidth
    beam.Width1 = config.laserWidth
    beam.FaceCamera = true
    beam.Parent = startPart
    
    -- Add particle effects at laser end
    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(config.laserColor)
    particles.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 0)
    }
    particles.Lifetime = NumberRange.new(0.1, 0.3)
    particles.Rate = config.particleRate
    particles.SpreadAngle = Vector2.new(45, 45)
    particles.Speed = NumberRange.new(2, 5)
    particles.Parent = endAttachment
    
    return {
        beam = beam,
        startAttachment = startAttachment,
        endAttachment = endAttachment
    }
end

local function updateLaserPosition(bossPos: Vector3, targetPos: Vector3)
    if not laserBeam then return end
    
    -- Raycast from boss to target to check for obstacles
    local direction = (targetPos - bossPos)
    local distance = direction.Magnitude
    local rayDirection = direction.Unit * distance
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {workspace:FindFirstChild("Boss")} -- Don't hit the boss itself
    
    local raycastResult = workspace:Raycast(bossPos, rayDirection, raycastParams)
    
    local finalEndPos = targetPos
    if raycastResult then
        -- Hit something, stop the beam at the hit point
        finalEndPos = raycastResult.Position
    end
    
    -- Update positions
    local startPart = laserBeam.startAttachment.Parent :: Part
    local endPart = laserBeam.endAttachment.Parent :: Part
    if startPart and endPart then
        startPart.Position = bossPos
        endPart.Position = finalEndPos
    end
end

local function getTargetPosition(targetPlayer: Player): Vector3?
    if targetPlayer == localPlayer then
        -- Use own real-time position for smooth tracking
        if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local rootPart = localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart
            return rootPart.Position
        end
    else
        -- Use last known replicated position for other players
        if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local rootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart
            return rootPart.Position
        end
    end
    return nil
end

local function startBlinkingEffect(blinkCount: number)
    if not laserBeam or isBlinking then return end
    
    isBlinking = true
    local config = BossConfig.abilities.trackingShot
    local blinkSpeed = config.blinkSpeed
    local blinkTransparency = config.blinkTransparency
    
    task.spawn(function()
        for i = 1, blinkCount do
            -- Blink on (more visible)
            laserBeam.beam.Transparency = NumberSequence.new(blinkTransparency[1])
            task.wait(blinkSpeed / 2)
            
            -- Blink off (less visible)
            laserBeam.beam.Transparency = NumberSequence.new(blinkTransparency[2])
            task.wait(blinkSpeed / 2)
        end
        
        isBlinking = false
    end)
end

local function cleanupLaser()
    if activeConnection then
        activeConnection:Disconnect()
        activeConnection = nil
    end
    
    if blinkTween then
        blinkTween:Cancel()
        blinkTween = nil
    end
    
    if laserBeam then
        local startPart = laserBeam.startAttachment.Parent
        local endPart = laserBeam.endAttachment.Parent
        if startPart then startPart:Destroy() end
        if endPart then endPart:Destroy() end
        laserBeam = nil
    end
    
    currentTarget = nil
    isBlinking = false
end

-- Public functions
function LaserEyeRenderer.handleLaserUpdate(data)
    if data.phase == "tracking" then
        -- Cleanup any existing laser first
        if laserBeam then
            cleanupLaser()
        end
        
        lockOnAchieved = false
        
        -- Start tracking phase
        local targetPlayer = Players:GetPlayerByUserId(data.targetPlayerId)
        if not targetPlayer then return end
        
        currentTarget = targetPlayer
        
        -- Get initial positions
        local targetPos = getTargetPosition(targetPlayer)
        if not targetPos then return end
        
        -- Create laser beam (red for tracking)
        laserBeam = createLaserBeam(data.bossPosition, targetPos)
        
        -- Start real-time tracking
        activeConnection = RunService.Heartbeat:Connect(function()
            if not currentTarget then return end
            
            local newTargetPos = getTargetPosition(currentTarget)
            if newTargetPos then
                -- Get current boss position from workspace
                local boss = workspace:FindFirstChild("Boss")
                local bossPos = data.bossPosition
                if boss and boss:FindFirstChild("HumanoidRootPart") then
                    local bossRootPart = boss:FindFirstChild("HumanoidRootPart") :: BasePart
                    bossPos = bossRootPart.Position
                end
                updateLaserPosition(bossPos, newTargetPos)
            end
        end)
        
    elseif data.phase == "lockOnAttempt" then
        -- Start lock-on blinking sequence
        if data.blinkCount then
            startBlinkingEffect(data.blinkCount)
        end
        
    elseif data.phase == "lockOnSuccess" then
        -- Lock-on achieved - change laser color to orange
        lockOnAchieved = true
        if laserBeam then
            local config = BossConfig.abilities.trackingShot
            laserBeam.beam.Color = ColorSequence.new(config.lockOnColor)
            print("Lock-on successful - laser color changed")
        end
        
    elseif data.phase == "lockOnFailed" then
        -- Lock-on failed - cleanup laser
        print("Lock-on failed - no missile will be launched")
        cleanupLaser()
        
    elseif data.phase == "missileLaunch" then
        -- Missile launched - cleanup laser
        print("Missile launched - cleaning up laser")
        cleanupLaser()
        
    elseif data.phase == "missile" then
        -- This is handled by MissileRenderer, not LaserEyeRenderer
        -- But we should cleanup any remaining laser just in case
        cleanupLaser()
        
    elseif data.phase == "inactive" then
        cleanupLaser()
    end
end

function LaserEyeRenderer.cleanup()
    cleanupLaser()
end

function LaserEyeRenderer.isActive(): boolean
    return laserBeam ~= nil
end

return LaserEyeRenderer 