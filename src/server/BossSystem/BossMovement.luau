-- Boss Movement System - Simplified version with no pathfinding
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BossConfig = require(ReplicatedStorage.Shared.BossConfig)
local Types = require(ReplicatedStorage.Shared.Types)

local BossMovement = {}

-- Private functions
local function getRandomPlayer(): Player?
    local activePlayers = {}
    
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(activePlayers, player)
        end
    end
    
    if #activePlayers == 0 then return nil end
    
    return activePlayers[math.random(1, #activePlayers)]
end

local function setupMeleeTouchDetection(boss: Types.BossData)
    -- Create a larger invisible part for melee detection
    local meleePart = Instance.new("Part")
    meleePart.Name = "MeleeDetector"
    meleePart.Size = Vector3.new(BossConfig.movement.meleeRange * 2, BossConfig.movement.meleeRange * 2, BossConfig.movement.meleeRange * 2)
    meleePart.Transparency = 1
    meleePart.CanCollide = false
    meleePart.Anchored = false
    meleePart.Shape = Enum.PartType.Ball
    meleePart.Parent = boss.model
    
    -- Weld it to the boss
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = boss.rootPart
    weld.Part1 = meleePart
    weld.Parent = meleePart
    
    -- Handle touch events
    meleePart.Touched:Connect(function(hit)
        if boss.state ~= "Moving" then return end
        
        local character = hit.Parent
        local humanoid = character:FindFirstChild("Humanoid")
        local player = Players:GetPlayerFromCharacter(character)
        
        if player and humanoid then
            local currentTime = tick()
            local lastHitTime = boss.lastMeleeHit[player] or 0
            local cooldownPassed = currentTime - lastHitTime >= BossConfig.movement.meleeCooldown
            
            if cooldownPassed then
                dealMeleeDamage(boss, player)
                boss.lastMeleeHit[player] = currentTime
            end
        end
    end)
    
    return meleePart
end

function dealMeleeDamage(boss: Types.BossData, player: Player)
    local damage = BossConfig.movement.meleeDamage
    local knockback = BossConfig.movement.meleeKnockback
    
    -- Apply damage directly to avoid circular dependency
    if player.Character then
        local humanoid = player.Character:FindFirstChild("Humanoid") :: Humanoid?
        if humanoid then
            humanoid.Health = math.max(0, humanoid.Health - damage)
            print(player.Name, "took", damage, "melee damage from boss")
        end
    end
    
    -- Apply knockback
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local playerRootPart = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart
        local bossPosition = boss.rootPart.Position
        local playerPosition = playerRootPart.Position
        
        local knockbackDirection = (playerPosition - bossPosition).Unit
        local knockbackForce = Instance.new("BodyVelocity")
        knockbackForce.MaxForce = Vector3.new(4000, 0, 4000)
        knockbackForce.Velocity = knockbackDirection * knockback
        knockbackForce.Parent = playerRootPart
        
        -- Remove knockback after short duration
        game:GetService("Debris"):AddItem(knockbackForce, 0.5)
    end
    
    print("Boss dealt melee damage to", player.Name)
end

-- Public functions
function BossMovement.moveToRandomPlayer(boss: Types.BossData)
    local targetPlayer = getRandomPlayer()
    if not targetPlayer then
        warn("No active players found for boss to target")
        return
    end
    
    boss.currentTarget = targetPlayer
    print("Boss is now targeting:", targetPlayer.Name, "(no movement logic)")
end

function BossMovement.updateMovement(boss: Types.BossData, deltaTime: number)
    -- No movement logic - boss just stands still
    if boss.state ~= "Moving" then return end
    
    -- If boss has no target, try to find one
    if not boss.currentTarget then
        print("Boss has no target, trying to find one...")
        BossMovement.moveToRandomPlayer(boss)
    end
    
    -- Check if current target is still valid
    if boss.currentTarget and (not boss.currentTarget.Character or not boss.currentTarget.Character:FindFirstChild("HumanoidRootPart")) then
        print("Current target is no longer valid, finding new target...")
        BossMovement.moveToRandomPlayer(boss)
    end
end

function BossMovement.stopMovement(boss: Types.BossData)
    local humanoid = boss.humanoid
    local rootPart = boss.rootPart
    
    if humanoid and rootPart then
        -- Stop the humanoid by making it move to its current position
        humanoid:MoveTo(rootPart.Position)
        humanoid.WalkSpeed = 0
    end
    
    print("Boss movement stopped")
end

function BossMovement.resumeMovement(boss: Types.BossData)
    local humanoid = boss.humanoid
    
    if humanoid then
        -- Restore movement speed
        humanoid.WalkSpeed = BossConfig.movement.speed
    end
    
    -- Select new random player target (but don't move)
    BossMovement.moveToRandomPlayer(boss)
end

function BossMovement.isCloseToTarget(boss: Types.BossData): boolean
    if not boss.currentTarget or not boss.currentTarget.Character then
        return false
    end
    
    local targetRootPart = boss.currentTarget.Character:FindFirstChild("HumanoidRootPart")
    if not targetRootPart then 
        return false 
    end
    
    local distance = (boss.rootPart.Position - (targetRootPart :: BasePart).Position).Magnitude
    local isClose = distance <= BossConfig.movement.stoppingDistance
    
    -- Only print debug when boss first gets close (state change)
    if isClose and not boss.wasCloseToTarget then
        print("Boss is now close to target! Distance:", math.floor(distance), "/ Required:", BossConfig.movement.stoppingDistance)
        boss.wasCloseToTarget = true
    elseif not isClose and boss.wasCloseToTarget then
        boss.wasCloseToTarget = false
    end
    
    return isClose
end

function BossMovement.getCurrentTarget(boss: Types.BossData): Player?
    return boss.currentTarget
end

function BossMovement.getDistanceToTarget(boss: Types.BossData): number?
    if not boss.currentTarget or not boss.currentTarget.Character then
        return nil
    end
    
    local targetRootPart = boss.currentTarget.Character:FindFirstChild("HumanoidRootPart")
    if not targetRootPart then return nil end
    
    return (boss.rootPart.Position - targetRootPart.Position).Magnitude
end

function BossMovement.setupMeleeTouchDetection(boss: Types.BossData)
    return setupMeleeTouchDetection(boss)
end

-- Legacy compatibility functions (keeping the same interface)
function BossMovement.updatePathToTarget(boss: Types.BossData)
    -- No pathfinding logic
end

return BossMovement 