-- PlayerRagdollSystem.luau
-- Applies enemy-style ragdoll and drag to players on death

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

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

local function ragdollCharacter(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    -- Disable joint breaking
    humanoid.BreakJointsOnDeath = false
    humanoid.RequiresNeck = false
    -- Hide health bar
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    -- Prevent standing up
    humanoid.PlatformStand = true
    -- Replace Motor6Ds with BallSocketConstraints (except Neck)
    local torso = character:FindFirstChild("Torso")
    if torso then
        for _, joint in ipairs(torso:GetChildren()) do
            if joint:IsA("Motor6D") and joint.Name ~= "Neck" then
                createSocket(torso, joint.Part1, joint.C0, joint.C1)
                joint:Destroy()
            end
        end
    end
    -- Tag as Draggable
    CollectionService:AddTag(character, "Draggable")
    -- Prevent respawn: set custom property to block respawn
    local player = Players:GetPlayerFromCharacter(character)
    if player then
        player.Neutral = true
        -- Prevent respawn by setting a flag
        player:SetAttribute("NoRespawn", true)
    end
end

local function onCharacterAdded(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.BreakJointsOnDeath = false
        humanoid.RequiresNeck = false
        humanoid.Died:Connect(function()
            ragdollCharacter(character)
        end)
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
    -- Prevent respawn by listening for CharacterAdded and blocking respawn if NoRespawn is set
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            if player:GetAttribute("NoRespawn") then
                -- Remove character immediately to prevent respawn
                task.defer(function()
                    character:Destroy()
                end)
            end
        end)
    end)
    print("PlayerRagdollSystem initialized: players will ragdoll and be draggable on death.")
end

return PlayerRagdollSystem 