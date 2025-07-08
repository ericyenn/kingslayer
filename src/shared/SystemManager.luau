-- System manager for dependency injection and inter-system communication
local SystemManager = {}

-- Registry of all systems
local systems = {}

-- Register a system with the manager
function SystemManager.RegisterSystem(systemName, systemInstance)
    if not systemName or not systemInstance then
        error("SystemManager: systemName and systemInstance are required")
    end
    
    systems[systemName] = systemInstance
    print("SystemManager: Registered system:", systemName)
end

-- Get a system by name
function SystemManager.GetSystem(systemName)
    local system = systems[systemName]
    if not system then
        warn("SystemManager: System not found:", systemName)
    end
    return system
end

-- Check if a system is registered
function SystemManager.HasSystem(systemName)
    return systems[systemName] ~= nil
end

-- Get all registered system names
function SystemManager.GetRegisteredSystems()
    local systemNames = {}
    for name, _ in pairs(systems) do
        table.insert(systemNames, name)
    end
    return systemNames
end

-- Call a method on a system if it exists (safe call pattern)
function SystemManager.CallSystem(systemName, methodName, ...)
    local system = systems[systemName]
    if not system then
        warn("SystemManager: System not found:", systemName)
        return nil
    end
    
    local method = system[methodName]
    if not method or type(method) ~= "function" then
        warn("SystemManager: Method not found:", methodName, "on system:", systemName)
        return nil
    end
    
    local success, result = pcall(method, system, ...)
    if not success then
        warn("SystemManager: Error calling", methodName, "on", systemName .. ":", result)
        return nil
    end
    
    return result
end

-- Initialize all registered systems
function SystemManager.InitializeAllSystems()
    print("SystemManager: Initializing all systems...")
    
    for systemName, system in pairs(systems) do
        if system.Initialize and type(system.Initialize) == "function" then
            local success, errorMessage = pcall(system.Initialize, system)
            if success then
                print("SystemManager: Initialized", systemName)
            else
                warn("SystemManager: Failed to initialize", systemName .. ":", errorMessage)
            end
        else
            print("SystemManager:", systemName, "has no Initialize method")
        end
    end
    
    print("SystemManager: System initialization complete")
end

-- Clear all systems (for testing/cleanup)
function SystemManager.ClearSystems()
    systems = {}
    print("SystemManager: All systems cleared")
end

return SystemManager 