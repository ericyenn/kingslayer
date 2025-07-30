-- SystemManager.lua
-- Simple system execution manager
-- Single responsibility: Run all registered systems each frame

local SystemManager = {}

-- Storage for registered systems
SystemManager.systems = {}

-- Register a system to be updated each frame
function SystemManager.registerSystem(system)
    if system and system.update and type(system.update) == "function" then
        table.insert(SystemManager.systems, system)
        print("✅ Registered system:", system.name or "Unknown")
        
        -- Call initialize function if it exists
        if system.initialize and type(system.initialize) == "function" then
            local success, err = pcall(system.initialize)
            if success then
                print("✅ Initialized system:", system.name or "Unknown")
            else
                warn("❌ Failed to initialize system", system.name or "Unknown", ":", err)
            end
        end
    else
        warn("❌ Invalid system - must have an 'update' function")
    end
end

-- Run all registered systems
function SystemManager.runAllSystems(deltaTime)
    for _, system in ipairs(SystemManager.systems) do
        local success, err = pcall(system.update, deltaTime)
        if not success then
            warn("❌ System error in", system.name or "Unknown", ":", err)
        end
    end
end

-- Start the main game loop
function SystemManager.startGameLoop()
    local RunService = game:GetService("RunService")
    
    RunService.Heartbeat:Connect(function(deltaTime)
        SystemManager.runAllSystems(deltaTime)
    end)
    
    print("🎮 Game loop started with", #SystemManager.systems, "systems")
end

-- Get system count
function SystemManager.getSystemCount()
    return #SystemManager.systems
end

-- Debug: Print all registered systems
function SystemManager.debugPrint()
    print("🔍 SystemManager Debug:")
    print("  Registered Systems:", #SystemManager.systems)
    for i, system in ipairs(SystemManager.systems) do
        print("   ", i, system.name or "Unknown")
    end
end

return SystemManager 