-- Placeholder for Tool-related client-side logic
local ToolSystem = {}

function ToolSystem:Use(item, player)
  print("[ToolSystem] Using tool:", item and item.name or "Unknown")
  -- TODO:
  -- 1. Play swing animation on the player's character
  -- 2. Perform a client-side raycast to see what was hit
  -- 3. Fire a RemoteEvent to the server with hit information to deal damage
end

return ToolSystem 