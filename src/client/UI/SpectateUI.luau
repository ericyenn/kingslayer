local SpectateUI = {}

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- UI Elements
local screenGui = nil
local frm_Spectate = nil
local BTN_Next = nil
local BTN_Previous = nil
local TXT_Player = nil
local BTN_Respawn = nil

-- Spectate System Variables
local WatchablePlayers = {}
local WatchIndex = 1
local DeathConnection = nil
local RespawnConnection = nil
local CharDeathConnection = nil

-- Cached player list for performance
local CachedAlivePlayers = {}

-- Helper function to check if a player is alive and watchable
local function isPlayerWatchable(p)
    return p.UserId ~= player.UserId and p.Character and p.Character:FindFirstChildOfClass("Humanoid") and p.Character:FindFirstChildOfClass("Humanoid").Health > 0
end

-- Update the cached player list
local function updateCachedPlayerList()
    CachedAlivePlayers = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if isPlayerWatchable(p) then
            table.insert(CachedAlivePlayers, p)
        end
    end
end

-- Helper: Clean up UI and camera
local function cleanupSpectate()
    print("[SpectateUI] cleanupSpectate called")
    
    if DeathConnection then
        DeathConnection:Disconnect()
        DeathConnection = nil
    end
    if RespawnConnection then
        RespawnConnection:Disconnect()
        RespawnConnection = nil
    end
    if CharDeathConnection then
        CharDeathConnection:Disconnect()
        CharDeathConnection = nil
    end
    if screenGui then
        screenGui:Destroy()
        screenGui = nil
        frm_Spectate = nil
        BTN_Next = nil
        BTN_Previous = nil
        TXT_Player = nil
        BTN_Respawn = nil
    end
    -- Remove client-side collision manipulation - let server handle collision settings
    -- The server is authoritative for ragdoll collision settings
    
    -- Let CameraSystem handle all camera restoration
    if _G.CameraSystem then
        print("[SpectateUI] Calling CameraSystem:ExitSpectateMode()")
        _G.CameraSystem:ExitSpectateMode()
    end
    
    print("[SpectateUI] cleanupSpectate completed")
end

function SpectateUI:WatchPlayer(index)
    print("[SpectateUI] WatchPlayer called with index:", index)
    
    if DeathConnection then
        DeathConnection:Disconnect()
        DeathConnection = nil
    end
    
    -- Use cached player list instead of scanning all players
    WatchablePlayers = CachedAlivePlayers
    print("[SpectateUI] Available players to watch:", #WatchablePlayers)
    
    if #WatchablePlayers == 0 then
        TXT_Player.Text = "No players alive"
        -- Let CameraSystem handle camera subject
        if _G.CameraSystem then
            _G.CameraSystem:SetSpectateTarget(nil)
        end
        return
    end
    
    -- Handle index bounds
    if index > #WatchablePlayers then
        WatchIndex = 1
    elseif index < 1 then
        WatchIndex = #WatchablePlayers
    else
        WatchIndex = index
    end
    
    -- Find a valid player to watch (prevent infinite loops)
    local attempts = 0
    local maxAttempts = #WatchablePlayers * 2 -- Allow checking each player twice
    
    while attempts < maxAttempts do
        local targetPlayer = WatchablePlayers[WatchIndex]
        
        -- Check if player and character are valid
        if targetPlayer and targetPlayer.Character then
            local targetCharacter = targetPlayer.Character
            local targetPart = targetCharacter:FindFirstChild("HumanoidRootPart") or 
                              targetCharacter:FindFirstChild("Head") or 
                              targetCharacter:FindFirstChild("Torso")
            
            -- Check if we have a valid part to watch
            if targetPart then
                local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
                
                if targetHumanoid and targetHumanoid.Health > 0 then
                    TXT_Player.Text = targetPlayer.Name
                    
                    -- Let CameraSystem handle all camera operations
                    if _G.CameraSystem then
                        _G.CameraSystem:SetSpectateTarget(targetPart)
                    end
                    
                    -- Set up death connection
                    DeathConnection = targetHumanoid.Died:Connect(function()
                        print("[SpectateUI] Player died:", targetPlayer.Name)
                        -- Update cached player list when someone dies
                        updateCachedPlayerList()
                        -- Try to watch the next player
                        self:WatchPlayer(WatchIndex + 1)
                    end)
                    
                    return -- Successfully found a valid player
                end
            end
        end
        
        -- Move to next player
        WatchIndex = WatchIndex + 1
        if WatchIndex > #WatchablePlayers then
            WatchIndex = 1
        end
        
        attempts = attempts + 1
    end
    
    -- If we get here, no valid players found after all attempts
    TXT_Player.Text = "No valid players to watch"
    if _G.CameraSystem then
        _G.CameraSystem:SetSpectateTarget(nil)
    end
end

local function createSpectateUI()
    if screenGui then return end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SpectateUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    frm_Spectate = Instance.new("Frame")
    frm_Spectate.Name = "frm_Spectate"
    frm_Spectate.Size = UDim2.new(0, 320, 0, 120)
    frm_Spectate.Position = UDim2.new(0, 30, 0, 170)
    frm_Spectate.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frm_Spectate.Parent = screenGui

    BTN_Next = Instance.new("TextButton")
    BTN_Next.Name = "BTN_Next"
    BTN_Next.Size = UDim2.new(0, 80, 0, 40)
    BTN_Next.Position = UDim2.new(1, -90, 0.5, -50)
    BTN_Next.AnchorPoint = Vector2.new(0, 0)
    BTN_Next.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
    BTN_Next.TextColor3 = Color3.fromRGB(255, 255, 255)
    BTN_Next.Text = ">>"
    BTN_Next.TextSize = 22
    BTN_Next.Font = Enum.Font.GothamBold
    BTN_Next.Parent = frm_Spectate

    BTN_Previous = Instance.new("TextButton")
    BTN_Previous.Name = "BTN_Previous"
    BTN_Previous.Size = UDim2.new(0, 80, 0, 40)
    BTN_Previous.Position = UDim2.new(0, 10, 0.5, -50)
    BTN_Previous.AnchorPoint = Vector2.new(0, 0)
    BTN_Previous.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
    BTN_Previous.TextColor3 = Color3.fromRGB(255, 255, 255)
    BTN_Previous.Text = "<<"
    BTN_Previous.TextSize = 22
    BTN_Previous.Font = Enum.Font.GothamBold
    BTN_Previous.Parent = frm_Spectate

    TXT_Player = Instance.new("TextLabel")
    TXT_Player.Name = "TXT_Player"
    TXT_Player.Size = UDim2.new(0, 120, 0, 40)
    TXT_Player.Position = UDim2.new(0.5, -60, 0.5, -50)
    TXT_Player.BackgroundTransparency = 1
    TXT_Player.TextColor3 = Color3.fromRGB(255, 255, 255)
    TXT_Player.TextStrokeTransparency = 0.5
    TXT_Player.Text = "PlayerName"
    TXT_Player.TextSize = 20
    TXT_Player.Font = Enum.Font.GothamBold
    TXT_Player.Parent = frm_Spectate

    BTN_Respawn = Instance.new("TextButton")
    BTN_Respawn.Name = "BTN_Respawn"
    BTN_Respawn.Size = UDim2.new(0, 180, 0, 40)
    BTN_Respawn.Position = UDim2.new(0.5, -90, 1, -50)
    BTN_Respawn.BackgroundColor3 = Color3.fromRGB(80, 120, 60)
    BTN_Respawn.TextColor3 = Color3.fromRGB(255, 255, 255)
    BTN_Respawn.Text = "Respawn"
    BTN_Respawn.TextSize = 22
    BTN_Respawn.Font = Enum.Font.GothamBold
    BTN_Respawn.Parent = frm_Spectate

    BTN_Next.Activated:Connect(function()
        SpectateUI:WatchPlayer(WatchIndex + 1)
    end)
    BTN_Previous.Activated:Connect(function()
        SpectateUI:WatchPlayer(WatchIndex - 1)
    end)
    BTN_Respawn.Activated:Connect(function()
        local event = ReplicatedStorage:FindFirstChild("RequestRespawn")
        if event then
            event:FireServer()
        end
    end)
end

function SpectateUI:Initialize()
    -- Initialize cached player list
    updateCachedPlayerList()
    
    -- Listen for player join/leave to update cache
    Players.PlayerAdded:Connect(function(joinedPlayer)
        task.wait(0.1) -- Wait for character to load
        updateCachedPlayerList()
    end)
    
    Players.PlayerRemoving:Connect(function(leavingPlayer)
        updateCachedPlayerList()
    end)
    
    -- Listen for the 'Dead' tag on the local player
    local function onDeadTagAdded(inst)
        if inst == player then
            createSpectateUI()
            -- Remove client-side collision manipulation - let server handle collision settings
            -- The server is authoritative for ragdoll collision settings
            
            -- Let CameraSystem handle all camera operations
            if _G.CameraSystem then
                _G.CameraSystem:EnterSpectateMode()
            end
            
            WatchIndex = 1
            SpectateUI:WatchPlayer(WatchIndex)
            if RespawnConnection then RespawnConnection:Disconnect() end
            RespawnConnection = player.CharacterAdded:Connect(function(newChar)
                cleanupSpectate()
            end)
        end
    end
    local function onDeadTagRemoved(inst)
        if inst == player then
            cleanupSpectate()
        end
    end
    -- Connect tag listeners
    CollectionService:GetInstanceAddedSignal("Dead"):Connect(onDeadTagAdded)
    CollectionService:GetInstanceRemovedSignal("Dead"):Connect(onDeadTagRemoved)
    -- If the player already has the tag (e.g., on join), trigger immediately
    if CollectionService:HasTag(player, "Dead") then
        onDeadTagAdded(player)
    end
end

return SpectateUI 