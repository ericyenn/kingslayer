-- Missile Renderer - Client-side visual effects for missiles
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local BossConfig = require(ReplicatedStorage.Shared.BossConfig)

local MissileRenderer = {}

-- Types
type MissileVisual = {
    id: string,
    model: Model,
    position: Vector3,
    velocity: Vector3,
    target: Player?,
    lastServerPosition: Vector3?,
    currentServerPosition: Vector3?,
    lastUpdateTime: number,
    trail: ParticleEmitter?
}

-- Private variables
local localPlayer = Players.LocalPlayer
local activeMissiles: {[string]: MissileVisual} = {}
local updateConnection: RBXScriptConnection?

-- Private functions
local function createMissileModel(position: Vector3, velocity: Vector3): Model
    local config = BossConfig.abilities.trackingShot
    
    -- Create missile model
    local missile = Instance.new("Model")
    missile.Name = "Missile"
    missile.Parent = workspace
    
    -- Main body
    local body = Instance.new("Part")
    body.Name = "Body"
    body.Size = config.missileSize
    body.Shape = Enum.PartType.Block
    body.Material = Enum.Material.Metal
    body.Color = config.missileColor
    body.Anchored = true
    body.CanCollide = false
    body.Position = position
    body.Parent = missile
    
    -- Point missile in direction of velocity
    if velocity.Magnitude > 0 then
        body.CFrame = CFrame.lookAt(position, position + velocity.Unit)
    end
    
    -- Add glowing effect
    local pointLight = Instance.new("PointLight")
    pointLight.Color = config.trailColor
    pointLight.Brightness = 2
    pointLight.Range = 10
    pointLight.Parent = body
    
    -- Add trail effect
    local trail = Instance.new("ParticleEmitter")
    trail.Color = ColorSequence.new(config.trailColor)
    trail.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 0)
    }
    trail.Lifetime = NumberRange.new(0.3, 0.8)
    trail.Rate = config.trailLength
    trail.SpreadAngle = Vector2.new(10, 10)
    trail.Speed = NumberRange.new(1, 3)
    trail.Acceleration = Vector3.new(0, -5, 0) -- Gravity effect on particles
    trail.Parent = body
    
    return missile
end

local function interpolatePosition(missile: MissileVisual, deltaTime: number): Vector3
    local currentTime = tick()
    
    -- Check if we have server data to interpolate between
    if not missile.lastServerPosition or not missile.currentServerPosition then
        -- No server data yet, stay at current position
        return missile.position
    end
    
    -- Calculate interpolation progress
    local timeSinceUpdate = currentTime - missile.lastUpdateTime
    local updateInterval = 1 / 30 -- 30Hz server updates
    local alpha = math.min(timeSinceUpdate / updateInterval, 1)
    
    -- Smooth interpolation with easing
    local easedAlpha = alpha * alpha * (3 - 2 * alpha) -- Smoothstep easing
    
    -- Interpolate position
    local interpolatedPosition = missile.lastServerPosition:Lerp(missile.currentServerPosition, easedAlpha)
    
    -- If we've reached the target, extrapolate slightly using velocity
    if alpha >= 1 and missile.velocity.Magnitude > 0 then
        local extrapolationTime = timeSinceUpdate - updateInterval
        interpolatedPosition = interpolatedPosition + (missile.velocity * extrapolationTime * 0.5) -- Gentle extrapolation
    end
    
    return interpolatedPosition
end

local function updateMissileVisuals(deltaTime: number)
    local currentTime = tick()
    
    for missileId, missile in pairs(activeMissiles) do
        if not missile.model or not missile.model.Parent then
            -- Model was destroyed, cleanup
            activeMissiles[missileId] = nil
            continue
        end
        
        -- Pure server interpolation - no competing prediction
        local newPosition = interpolatePosition(missile, deltaTime)
        missile.position = newPosition
        
        -- Update model position and rotation
        local body = missile.model:FindFirstChild("Body") :: Part?
        if body then
            body.Position = newPosition
            
            -- Point missile in direction of velocity
            if missile.velocity.Magnitude > 0 then
                body.CFrame = CFrame.lookAt(newPosition, newPosition + missile.velocity.Unit)
            end
        end
    end
    
    -- Stop updates if no missiles
    if next(activeMissiles) == nil and updateConnection then
        updateConnection:Disconnect()
        updateConnection = nil
        print("All missiles finished - stopping visual updates")
    end
end

local function createExplosionEffect(position: Vector3)
    local config = BossConfig.abilities.trackingShot
    
    -- Create explosion visual
    local explosion = Instance.new("Part")
    explosion.Name = "MissileExplosion"
    explosion.Size = Vector3.new(0.1, 0.1, 0.1)
    explosion.Shape = Enum.PartType.Ball
    explosion.Material = Enum.Material.Neon
    explosion.BrickColor = BrickColor.new("Bright orange")
    explosion.Transparency = 0.2
    explosion.Anchored = true
    explosion.CanCollide = false
    explosion.Position = position
    explosion.Parent = workspace
    
    -- Add light
    local pointLight = Instance.new("PointLight")
    pointLight.Color = Color3.new(1, 0.5, 0)
    pointLight.Brightness = 5
    pointLight.Range = config.explosionRadius
    pointLight.Parent = explosion
    
    -- Expansion animation
    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local expandTween = TweenService:Create(explosion, tweenInfo, {
        Size = Vector3.new(config.explosionVisualSize, config.explosionVisualSize, config.explosionVisualSize),
        Transparency = 0.8
    })
    
    local lightTween = TweenService:Create(pointLight, tweenInfo, {
        Range = config.explosionVisualSize,
        Brightness = 1
    })
    
    expandTween:Play()
    lightTween:Play()
    
    -- Particle burst
    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(Color3.new(1, 0.5, 0))
    particles.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0)
    }
    particles.Lifetime = NumberRange.new(0.5, 1.5)
    particles.Rate = 200
    particles.SpreadAngle = Vector2.new(180, 180)
    particles.Speed = NumberRange.new(10, 25)
    particles.Acceleration = Vector3.new(0, -20, 0)
    particles.Parent = explosion
    
    -- Burst then stop
    task.wait(0.1)
    particles.Enabled = false
    
    -- Cleanup
    expandTween.Completed:Connect(function()
        explosion:Destroy()
    end)
end

-- Public functions
function MissileRenderer.handleMissile(data: {[string]: any})
    local updateType = data.updateType
    local missileId = data.missileId
    
    if updateType == "spawn" then
        local position = data.position
        local velocity = data.velocity
        local targetId = data.targetId
        
        print("Creating missile visual:", missileId, "at position:", position)
        
        -- Create missile visual
        local model = createMissileModel(position, velocity)
        local target = targetId and Players:GetPlayerByUserId(targetId) or nil
        
        local missile: MissileVisual = {
            id = missileId,
            model = model,
            position = position,
            velocity = velocity,
            target = target,
            lastServerPosition = position,
            currentServerPosition = position,
            lastUpdateTime = tick()
        }
        
        activeMissiles[missileId] = missile
        
        -- Start update loop if not running
        if not updateConnection then
            updateConnection = RunService.Heartbeat:Connect(updateMissileVisuals)
            print("Started missile visual updates")
        end
        
    elseif updateType == "update" then
        local missile = activeMissiles[missileId]
        if missile then
            -- Store previous position for interpolation
            missile.lastServerPosition = missile.currentServerPosition
            missile.currentServerPosition = data.position
            missile.velocity = data.velocity
            missile.lastUpdateTime = tick()
        end
        
    elseif updateType == "explode" then
        local position = data.position
        print("Creating explosion effect at:", position)
        
        createExplosionEffect(position)
        
    elseif updateType == "destroy" then
        local missile = activeMissiles[missileId]
        if missile then
            if missile.model and missile.model.Parent then
                missile.model:Destroy()
            end
            activeMissiles[missileId] = nil
            print("Destroyed missile visual:", missileId)
        end
    end
end

function MissileRenderer.cleanup()
    -- Cleanup all missiles
    for missileId, missile in pairs(activeMissiles) do
        if missile.model and missile.model.Parent then
            missile.model:Destroy()
        end
        activeMissiles[missileId] = nil
    end
    
    if updateConnection then
        updateConnection:Disconnect()
        updateConnection = nil
    end
end

return MissileRenderer 