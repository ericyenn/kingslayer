-- ProjectileManager.luau
-- Server-side projectile management system
-- Handles projectile logic, collision detection, and damage while clients handle visuals

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local ProjectileManager = {}

-- Store active projectiles on server (logic only, no visual parts)
local activeProjectiles = {} -- {[projectileId] = {startPosition, targetPosition, direction, speed, damage, config, startTime, lifetime}}

-- Remote events for client communication
local ProjectileEvents = Instance.new("Folder")
ProjectileEvents.Name = "ProjectileEvents"
ProjectileEvents.Parent = ReplicatedStorage

local SpawnProjectileEvent = Instance.new("RemoteEvent")
SpawnProjectileEvent.Name = "SpawnProjectile"
SpawnProjectileEvent.Parent = ProjectileEvents

local DestroyProjectileEvent = Instance.new("RemoteEvent")
DestroyProjectileEvent.Name = "DestroyProjectile"
DestroyProjectileEvent.Parent = ProjectileEvents

local ProjectileHitEvent = Instance.new("RemoteEvent")
ProjectileHitEvent.Name = "ProjectileHit"
ProjectileHitEvent.Parent = ProjectileEvents

-- Import DamageSystem
local DamageSystem = require(script.Parent.Systems.DamageSystem)

-- Generate unique projectile ID
local projectileIdCounter = 0
local function generateProjectileId()
    projectileIdCounter = projectileIdCounter + 1
    return "projectile_" .. projectileIdCounter
end

-- Create projectile on server (logic only)
function ProjectileManager.createProjectile(startPosition, targetPosition, config)
    local projectileId = generateProjectileId()
    
    -- Calculate projectile trajectory
    local direction = (targetPosition - startPosition).Unit
    local distance = (targetPosition - startPosition).Magnitude
    local speed = config.speed or 70
    local travelTime = distance / speed
    
    -- Store projectile data (no visual part on server)
    activeProjectiles[projectileId] = {
        startPosition = startPosition,
        targetPosition = targetPosition,
        direction = direction,
        speed = speed,
        damage = config.damage or 15,
        config = config,
        startTime = tick(),
        lifetime = config.lifetime or 3,
        travelTime = travelTime
    }
    
    -- Tell all clients to create visual projectile
    SpawnProjectileEvent:FireAllClients(projectileId, startPosition, targetPosition, config)
    
    print("🚀 Server created projectile", projectileId, "from", startPosition, "to", targetPosition, "travel time:", math.floor(travelTime * 100) / 100, "s")
    
    -- Auto cleanup after lifetime
    task.delay(config.lifetime or 3, function()
        ProjectileManager.destroyProjectile(projectileId)
    end)
    
    return projectileId
end

-- Destroy projectile on server
function ProjectileManager.destroyProjectile(projectileId)
    if activeProjectiles[projectileId] then
        activeProjectiles[projectileId] = nil
        
        -- Tell all clients to destroy visual projectile
        DestroyProjectileEvent:FireAllClients(projectileId)
        
        print("🗑️ Server destroyed projectile", projectileId)
    end
end

-- Handle projectile hit (server-side collision detection)
function ProjectileManager.handleProjectileHit(projectileId, hitPosition, hitCharacter)
    local projectileData = activeProjectiles[projectileId]
    if not projectileData then
        return
    end
    
    local humanoid = hitCharacter:FindFirstChild("Humanoid")
    if humanoid and Players:GetPlayerFromCharacter(hitCharacter) then
        -- Hit a player - apply damage
        print("💥 Server: Projectile", projectileId, "hit player:", hitCharacter.Name)
        
        -- Apply damage using DamageSystem
        local damageAmount = projectileData.damage
        DamageSystem:ApplyDamage(humanoid, damageAmount, nil, "RangedEnemyProjectile")
        
        -- Check if this is a pirate buccaneer projectile and apply effects
        print("💥 DEBUG: Projectile config:", projectileData.config and projectileData.config.projectileType or "nil")
        if projectileData.config and projectileData.config.projectileType == "magic_bolt" then
            local player = Players:GetPlayerFromCharacter(hitCharacter)
            print("💥 DEBUG: Found player:", player and player.Name or "nil")
            print("💥 DEBUG: PlayerEffectsSystem available:", _G.PlayerEffectsSystem ~= nil)
            if player and _G.PlayerEffectsSystem then
                -- Apply slow effect (80% speed reduction for 1 second)
                _G.PlayerEffectsSystem:ApplySlowEffect(player, 1.0, 0.8)
                -- Apply jump disable effect for 1 second
                _G.PlayerEffectsSystem:ApplyJumpDisableEffect(player, 1.0)
                print("🐌🚫 Applied slow and jump disable effects to", player.Name, "from pirate buccaneer projectile")
            else
                print("💥 DEBUG: Failed to apply effects - player:", player ~= nil, "PlayerEffectsSystem:", _G.PlayerEffectsSystem ~= nil)
            end
        else
            print("💥 DEBUG: Not a magic_bolt projectile, skipping effects")
        end
        
        -- Tell all clients to create hit effect
        ProjectileHitEvent:FireAllClients(projectileId, hitPosition)
        
        -- Destroy projectile
        ProjectileManager.destroyProjectile(projectileId)
    end
end

-- Update projectile positions and check collisions
function ProjectileManager.updateProjectiles()
    local currentTime = tick()
    
    for projectileId, projectileData in pairs(activeProjectiles) do
        local elapsedTime = currentTime - projectileData.startTime
        
        -- Check if projectile has exceeded lifetime
        if elapsedTime >= projectileData.lifetime then
            ProjectileManager.destroyProjectile(projectileId)
        else
            -- Calculate current position based on time
            local progress = elapsedTime / projectileData.travelTime
            if progress >= 1 then
                -- Projectile reached target - destroy it
                ProjectileManager.destroyProjectile(projectileId)
            else
                local currentPosition = projectileData.startPosition + (projectileData.direction * projectileData.speed * elapsedTime)
                
                -- Check for player collisions by checking distance to all players
                for _, player in pairs(Players:GetPlayers()) do
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        local playerPosition = player.Character.HumanoidRootPart.Position
                        local distanceToPlayer = (currentPosition - playerPosition).Magnitude
                        
                        -- If projectile is close enough to player (within 3 studs)
                        if distanceToPlayer <= 3 then
                            print("💥 Server: Projectile", projectileId, "hit player:", player.Name, "at distance:", distanceToPlayer)
                            ProjectileManager.handleProjectileHit(projectileId, currentPosition, player.Character)
                            break -- Only hit one player per projectile
                        end
                    end
                end
            end
        end
    end
end

-- Initialize server projectile system
function ProjectileManager.initialize()
    print("🚀 ProjectileManager: Initializing server-side projectile system")
    
    -- Start update loop
    RunService.Heartbeat:Connect(function()
        ProjectileManager.updateProjectiles()
    end)
    
    print("✅ ProjectileManager: Server projectile system initialized")
end

-- Clean up all server projectiles
function ProjectileManager.cleanup()
    for projectileId, _ in pairs(activeProjectiles) do
        ProjectileManager.destroyProjectile(projectileId)
    end
    activeProjectiles = {}
    print("🧹 ProjectileManager: Cleaned up all server projectiles")
end

return ProjectileManager 