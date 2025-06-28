-- Shared constants for the game
local Constants = {}

-- Drag system settings
Constants.DRAG = {
    DEFAULT_FORCE = 16000,
    DEFAULT_MAX_DISTANCE = 50,
    DEFAULT_DAMPENING = 0.8,
    RAYCAST_DISTANCE = 15,
    MAX_DRAG_DISTANCE = 15,
    MIN_DRAG_DISTANCE = 3
}

-- Hover system settings
Constants.HOVER = {
    RAYCAST_DISTANCE = 15,
    HIGHLIGHT_COLOR = Color3.fromRGB(255, 255, 0),
    UI_OFFSET = Vector2.new(10, -30)
}

-- Item tags (for CollectionService)
Constants.TAGS = {
    DRAGGABLE_ITEM = "DraggableItem"
}

return Constants 