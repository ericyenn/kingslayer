-- Shared action registry system for consistent action handling across all systems
local ActionRegistry = {}

-- Create a new action registry instance
function ActionRegistry.new(systemName)
    local registry = {
        systemName = systemName or "Unknown",
        actions = {},
        defaultAction = nil
    }
    
    -- Set a default action for this registry
    function registry:SetDefaultAction(actionFunction)
        self.defaultAction = actionFunction
    end
    
    -- Register an action with this registry
    function registry:RegisterAction(actionName, actionFunction)
        if type(actionName) ~= "string" then
            error(self.systemName .. ": Action name must be a string")
        end
        if type(actionFunction) ~= "function" then
            error(self.systemName .. ": Action function must be a function")
        end
        
        self.actions[actionName] = actionFunction
        print(self.systemName .. ": Registered action:", actionName)
    end
    
    -- Execute an action by name with consistent error handling
    function registry:ExecuteAction(actionName, player, itemDef, target, actionData, extraParam)
        -- Validate inputs
        if not actionName then
            warn(self.systemName .. ": No action name provided")
            return false
        end
        
        if not itemDef then
            warn(self.systemName .. ": No item definition provided")
            return false
        end
        
        -- Try to find the action
        local actionFunction = self.actions[actionName]
        
        if actionFunction then
            -- Execute with error handling
            local success, errorMessage = pcall(function()
                actionFunction(player, itemDef, target, actionData, extraParam)
            end)
            
            if not success then
                warn(self.systemName .. ": Error executing action", actionName .. ":", errorMessage)
                return false
            end
            
            return true
        else
            -- Try default action if available
            if self.defaultAction then
                print(self.systemName .. ": Unknown action", actionName, "- using default")
                
                local success, errorMessage = pcall(function()
                    self.defaultAction(player, itemDef, target, actionData, extraParam)
                end)
                
                if not success then
                    warn(self.systemName .. ": Error executing default action:", errorMessage)
                    return false
                end
                
                return true
            else
                warn(self.systemName .. ": Unknown action", actionName, "and no default action available")
                return false
            end
        end
    end
    
    -- Get all registered action names
    function registry:GetRegisteredActions()
        local actionNames = {}
        for name, _ in pairs(self.actions) do
            table.insert(actionNames, name)
        end
        return actionNames
    end
    
    -- Check if an action is registered
    function registry:HasAction(actionName)
        return self.actions[actionName] ~= nil
    end
    
    -- Get action count
    function registry:GetActionCount()
        local count = 0
        for _ in pairs(self.actions) do
            count = count + 1
        end
        return count
    end
    
    return registry
end

-- Validate action data structure (basic validation)
function ActionRegistry.ValidateActionData(actionData, itemDef)
    if not actionData then
        return true -- nil is valid
    end
    
    if type(actionData) ~= "table" then
        warn("ActionRegistry: actionData must be a table, got", type(actionData))
        return false
    end
    
    -- Basic validation passed
    return true
end

-- Standard action function signature validator
function ActionRegistry.ValidateActionFunction(actionFunction)
    if type(actionFunction) ~= "function" then
        return false, "Action must be a function"
    end
    
    -- Could add more sophisticated validation here (parameter count, etc.)
    return true
end

return ActionRegistry 