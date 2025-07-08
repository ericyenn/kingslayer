-- Simple event system for inter-system communication
local EventSystem = {}

-- Registry of event listeners
local eventListeners = {}

-- Subscribe to an event
function EventSystem.Subscribe(eventName, callback, systemName)
    if not eventName or not callback then
        error("EventSystem: eventName and callback are required")
    end
    
    if not eventListeners[eventName] then
        eventListeners[eventName] = {}
    end
    
    local listenerId = #eventListeners[eventName] + 1
    eventListeners[eventName][listenerId] = {
        callback = callback,
        systemName = systemName or "Unknown"
    }
    
    print("EventSystem:", (systemName or "Unknown"), "subscribed to", eventName)
    return listenerId
end

-- Unsubscribe from an event
function EventSystem.Unsubscribe(eventName, listenerId)
    if not eventListeners[eventName] then
        return false
    end
    
    if eventListeners[eventName][listenerId] then
        local listener = eventListeners[eventName][listenerId]
        eventListeners[eventName][listenerId] = nil
        print("EventSystem:", listener.systemName, "unsubscribed from", eventName)
        return true
    end
    
    return false
end

-- Publish an event to all subscribers
function EventSystem.Publish(eventName, data, publisherName)
    if not eventName then
        error("EventSystem: eventName is required")
    end
    
    local listeners = eventListeners[eventName]
    if not listeners then
        return 0 -- No listeners
    end
    
    local notified = 0
    for listenerId, listener in pairs(listeners) do
        if listener and listener.callback then
            local success, errorMessage = pcall(listener.callback, data, publisherName)
            if success then
                notified = notified + 1
            else
                warn("EventSystem: Error notifying", listener.systemName, "for event", eventName .. ":", errorMessage)
            end
        end
    end
    
    if notified > 0 then
        print("EventSystem:", (publisherName or "Unknown"), "published", eventName, "to", notified, "listeners")
    end
    
    return notified
end

-- Get all event names that have listeners
function EventSystem.GetActiveEvents()
    local events = {}
    for eventName, listeners in pairs(eventListeners) do
        local count = 0
        for _ in pairs(listeners) do
            count = count + 1
        end
        if count > 0 then
            events[eventName] = count
        end
    end
    return events
end

-- Clear all event listeners (for testing/cleanup)
function EventSystem.ClearAll()
    eventListeners = {}
    print("EventSystem: All event listeners cleared")
end

return EventSystem 