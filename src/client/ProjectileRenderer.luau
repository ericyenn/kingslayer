-- ProjectileRenderer.luau
-- Client-side projectile rendering system
-- Handles visual creation, movement, and effects of projectiles

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local ProjectileRenderer = {}

-- Store active projectiles on client
local activeProjectiles = {} -- {[projectileId] = {part, trail, bodyVelocity, startTime, lifetime}}

-- Remote events for server communication
local ProjectileEvents = ReplicatedStorage:WaitForChild("ProjectileEvents")

-- Create visual projectile on client
function ProjectileRenderer.createProjectile(projectileId, startPosition, targetPosition, config)
    -- Calculate distance and direction
    local direction = (targetPosition - startPosition).Unit
    local distance = (targetPosition - startPosition).Magnitude
    
    -- Create full-length beam that spans from weapon to target
    local projectile = Instance.new("Part")
    projectile.Name = "ClientProjectile_" .. projectileId
    projectile.Size = Vector3.new(0.1, 0.1, distance) -- Beam spans full distance
    projectile.Color = Color3.fromRGB(255, 255, 255) -- Pure white
    projectile.Material = Enum.Material.Plastic
    projectile.Shape = Enum.PartType.Block
    projectile.CanCollide = false
    projectile.Anchored = true -- Anchored so it doesn't move
    
    -- Position beam to span from start to target
    local midpoint = (startPosition + targetPosition) / 2
    local lookAt = CFrame.lookAt(startPosition, targetPosition)
    projectile.CFrame = lookAt * CFrame.new(0, 0, 0) -- Center the beam
    projectile.Position = midpoint
    
    projectile.Parent = workspace
    
    -- Store projectile data
    activeProjectiles[projectileId] = {
        part = projectile,
        startTime = tick(),
        lifetime = 0.1, -- Very short lifetime for instant hit effect
        targetPosition = targetPosition,
        config = config
    }
    
    print("⚡ Client created instant beam", projectileId, "from", startPosition, "to", targetPosition)
    
    -- Auto cleanup after very short time (instant hit effect)
    Debris:AddItem(projectile, 0.1)
end

-- Destroy projectile on client
function ProjectileRenderer.destroyProjectile(projectileId)
    local projectileData = activeProjectiles[projectileId]
    if projectileData then
        if projectileData.part then
            projectileData.part:Destroy()
        end
        activeProjectiles[projectileId] = nil
        print("🗑️ Client destroyed projectile", projectileId)
    end
end

-- Hit effects removed for now - can be added later

-- Initialize client projectile system
function ProjectileRenderer.Initialize()
    print("🎨 ProjectileRenderer: Initializing client-side projectile system")
    
    -- Connect to server projectile events
    if ProjectileEvents then
        -- Handle projectile spawn events from server
        local spawnEvent = ProjectileEvents:WaitForChild("SpawnProjectile")
        spawnEvent.OnClientEvent:Connect(function(projectileId, startPosition, targetPosition, config)
            ProjectileRenderer.createProjectile(projectileId, startPosition, targetPosition, config)
        end)
        
        -- Handle projectile destroy events from server
        local destroyEvent = ProjectileEvents:WaitForChild("DestroyProjectile")
        destroyEvent.OnClientEvent:Connect(function(projectileId)
            ProjectileRenderer.destroyProjectile(projectileId)
        end)
        
        -- Handle projectile hit events from server (hit effects removed for now)
        local hitEvent = ProjectileEvents:WaitForChild("ProjectileHit")
        hitEvent.OnClientEvent:Connect(function(projectileId, hitPosition)
            ProjectileRenderer.destroyProjectile(projectileId)
        end)
        
        print("✅ ProjectileRenderer: Connected to server projectile events")
    else
        warn("⚠️ ProjectileRenderer: ProjectileEvents not found in ReplicatedStorage")
    end
end

-- Clean up all client projectiles
function ProjectileRenderer.cleanup()
    for projectileId, projectileData in pairs(activeProjectiles) do
        if projectileData.part then
            projectileData.part:Destroy()
        end
    end
    activeProjectiles = {}
    print("🧹 ProjectileRenderer: Cleaned up all client projectiles")
end

return ProjectileRenderer 