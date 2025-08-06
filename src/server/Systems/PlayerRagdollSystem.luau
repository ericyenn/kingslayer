-- PlayerRagdollSystem.luau
-- Applies enemy-style ragdoll and drag to players on death

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

-- Reference to ReviveSystem (will be set after initialization)
local ReviveSystem = nil

-- Track characters that have already been ragdolled to prevent multiple flings
local ragdolledCharacters = {}

local function createAttachment(part, cframeOffset)
    local attachment = Instance.new("Attachment")
    attachment.Name = part.Name .. "Attachment"
    attachment.CFrame = cframeOffset
    attachment.Parent = part
    return attachment
end

local function createSocket(torso, part, c0, c1)
    local ballSocket = Instance.new("BallSocketConstraint")
    ballSocket.Name = part.Name .. "Socket"
    local attachment0 = createAttachment(torso, c0)
    local attachment1 = createAttachment(part, c1)
    ballSocket.Attachment0 = attachment0
    ballSocket.Attachment1 = attachment1
    ballSocket.Parent = torso
end

local deadHealthConnections = {}
local enforcingHealth = {} -- Track when we're actively enforcing health to prevent feedback loops
local healthChangedConnections = {} -- Track HealthChanged connections to disconnect them after ragdoll

local function enforceZeroHealth(player)
    if not player.Character then return end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    -- Only enforce zero health for players, not NPCs
    -- Check if this is actually a player (not an NPC)
    if not Players:GetPlayerFromCharacter(player.Character) then
        return -- This is an NPC, don't enforce zero health
    end
    
    -- Prevent feedback loops
    if enforcingHealth[player] then
        return
    end
    
    -- Disconnect any previous connection
    if deadHealthConnections[player] then
        deadHealthConnections[player]:Disconnect()
    end
    
    -- Mark that we're enforcing health
    enforcingHealth[player] = true
    
    -- Enforce health stays at 0
    deadHealthConnections[player] = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        if not enforcingHealth[player] then return end -- Prevent feedback loops
        if humanoid.Health > 0 then
            humanoid.Health = 0
        end
    end)
    
    -- Immediately set to 0 if not already
    if humanoid.Health > 0 then
        humanoid.Health = 0
    end
end

local function clearZeroHealthEnforcement(player)
    if deadHealthConnections[player] then
        deadHealthConnections[player]:Disconnect()
        deadHealthConnections[player] = nil
    end
    enforcingHealth[player] = nil
end

-- Ensure collision groups are set up
local function setupCollisionGroups()
    -- Register groups if they don't exist (using new API)
    pcall(function() PhysicsService:RegisterCollisionGroup("Enemies") end)
    pcall(function() PhysicsService:RegisterCollisionGroup("Ragdolls") end)
    pcall(function() PhysicsService:RegisterCollisionGroup("Items") end)
    -- Enemies ignore ragdolls and items
    PhysicsService:CollisionGroupSetCollidable("Enemies", "Ragdolls", false)
    PhysicsService:CollisionGroupSetCollidable("Enemies", "Items", false)
    -- Ragdolls and items still collide with Default (ground, walls, etc.)
end
setupCollisionGroups()

local function ragdollCharacter(character)
    -- Prevent multiple ragdolls on the same character
    if ragdolledCharacters[character] then
        print("PlayerRagdollSystem: Character already ragdolled, skipping:", character.Name)
        return
    end
    ragdolledCharacters[character] = true
    
    print("PlayerRagdollSystem: Starting ragdoll for character:", character.Name)
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then 
        print("PlayerRagdollSystem: No humanoid found for character:", character.Name)
        return 
    end
    
    -- Disconnect the HealthChanged event to prevent repeated calls
    if healthChangedConnections[character] then
        healthChangedConnections[character]:Disconnect()
        healthChangedConnections[character] = nil
        print("PlayerRagdollSystem: Disconnected HealthChanged event for:", character.Name)
    end
    
    -- Prevent respawn and enforce zero health early to prevent feedback loops
    local player = Players:GetPlayerFromCharacter(character)
    if player then
        player.Neutral = true
        -- Add Dead tag for spectate/respawn logic
        CollectionService:AddTag(player, "Dead")
        enforceZeroHealth(player)
    end
    
    -- Disable joint breaking
    humanoid.BreakJointsOnDeath = false
    humanoid.RequiresNeck = false
    -- Hide health bar
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    -- Prevent Roblox from deleting the character
    character.Parent = workspace
    -- Set CanCollide = true and assign to Ragdolls group for all limb parts
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and (part.Name:find("Arm") or part.Name:find("Leg") or part.Name == "Torso" or part.Name == "Head") then
            part.CanCollide = true
            part.CollisionGroup = "Ragdolls"
        end
    end
    
    -- Set PlatformStand to prevent standing up
    humanoid.PlatformStand = true
    
    -- Replace Motor6Ds with BallSocketConstraints (except Neck) FIRST
    local torso = character:FindFirstChild("Torso")
    if torso then
        for _, joint in ipairs(torso:GetChildren()) do
            if joint:IsA("Motor6D") and joint.Name ~= "Neck" then
                createSocket(torso, joint.Part1, joint.C0, joint.C1)
                joint:Destroy()
            end
        end
    end
    
    -- Add a small delay to ensure ragdoll state is established
    task.wait(0.1)
    
    -- NOW apply fling effect AFTER joints are destroyed
    if torso then
        print("PlayerRagdollSystem: Found torso, applying fling effect")
        
        -- Generate random direction for torso (angled, not straight up)
        local randomDirection = Vector3.new(
            math.random(-1, 1), -- Random X direction
            math.random(0.3, 0.8), -- Reduced upward bias for more angle
            math.random(-1, 1)  -- Random Z direction
        ).Unit -- Normalize to unit vector
        
        local torsoMass = torso:GetMass()
        local randomForce = math.random(30, 60) -- Reduced force range for more reasonable fling
        local upwardImpulse = randomDirection * randomForce * torsoMass
        print("PlayerRagdollSystem: Torso mass:", torsoMass, "Impulse:", upwardImpulse)
        torso:ApplyImpulse(upwardImpulse)
        
        -- Add moderate rotation to make the whole character spin
        local torsoAngularVelocity = Vector3.new(
            math.random(-15, 15), -- Moderate rotation on X axis
            math.random(-15, 15), -- Moderate rotation on Y axis
            math.random(-15, 15)  -- Moderate rotation on Z axis
        )
        torso.AssemblyAngularVelocity = torsoAngularVelocity
        
        -- Also try BodyVelocity as backup
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(5000, 5000, 5000) -- Reduced force
        bodyVelocity.Velocity = randomDirection * 25 -- Reduced velocity
        bodyVelocity.Parent = torso
        game:GetService("Debris"):AddItem(bodyVelocity, 0.3) -- Shorter duration
        
        print("Player flung into the air on death!")
    else
        print("PlayerRagdollSystem: No torso found for character:", character.Name)
    end
    
    print("PlayerRagdollSystem: Applied impulses to 0 limbs (removed individual limb impulses)")
    
    -- Tag as Draggable and PlayerSacrifice
    CollectionService:AddTag(character, "Draggable")
    CollectionService:AddTag(character, "PlayerSacrifice")
    
    -- Track dead player for revive system
    if ReviveSystem then
        ReviveSystem:TrackDeadPlayer(player, character)
    end
    
    -- Drop all inventory items when player dies
    if player and _G.InventoryServerSystem then
        _G.InventoryServerSystem:DropAllItemsOnDeath(player)
    end
    
    print("PlayerRagdollSystem: Completed ragdoll for character:", character.Name)
end

local function onCharacterAdded(character)
    character.Parent = workspace -- Ensure always in workspace
    character.Destroying:Connect(function()
        warn("[PlayerRagdollSystem] Character is being destroyed!", character)
        -- Clean up ragdoll tracking when character is destroyed
        ragdolledCharacters[character] = nil
        -- Clean up health changed connection
        if healthChangedConnections[character] then
            healthChangedConnections[character]:Disconnect()
            healthChangedConnections[character] = nil
        end
    end)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local player = Players:GetPlayerFromCharacter(character)
    if player then
        -- Remove Dead tag on respawn
        if CollectionService:HasTag(player, "Dead") then
            CollectionService:RemoveTag(player, "Dead")
            clearZeroHealthEnforcement(player)
        end
        -- Clean up ragdoll tracking when player respawns
        ragdolledCharacters[character] = nil
        -- Clean up health changed connection
        if healthChangedConnections[character] then
            healthChangedConnections[character]:Disconnect()
            healthChangedConnections[character] = nil
        end
    end
    if humanoid then
        humanoid.BreakJointsOnDeath = false
        humanoid.RequiresNeck = false
        humanoid.Destroying:Connect(function()
            warn("[PlayerRagdollSystem] Humanoid is being destroyed!", humanoid)
        end)
        -- Only set up HealthChanged connection for players, not NPCs
        if player then
            -- Store the HealthChanged connection so we can disconnect it later
            healthChangedConnections[character] = humanoid.HealthChanged:Connect(function(health)
                if health <= 0 then
                    humanoid.EvaluateStateMachine = false -- Disable state machine on 'death'
                    ragdollCharacter(character)
                end
            end)
        end
        -- Remove or comment out the Died event handler
        -- humanoid.Died:Connect(function()
        --     ragdollCharacter(character)
        -- end)
    end
end

local PlayerRagdollSystem = {}

function PlayerRagdollSystem:Initialize()
    -- Hook up all current and future players
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            onCharacterAdded(player.Character)
        end
        player.CharacterAdded:Connect(onCharacterAdded)
    end
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(onCharacterAdded)
    end)
    print("PlayerRagdollSystem initialized: players will ragdoll and be draggable on death.")
end

-- Set ReviveSystem reference (called after ReviveSystem is initialized)
function PlayerRagdollSystem:SetReviveSystem(reviveSystem)
    ReviveSystem = reviveSystem
    print("PlayerRagdollSystem: ReviveSystem reference set")
end

return PlayerRagdollSystem 