-- Placeholder for Functional Item-related client-side logic
local FunctionalSystem = {}

function FunctionalSystem:Use(item, player)
  print("[FunctionalSystem] Using functional item:", item and item.name or "Unknown")
  -- TODO:
  -- This system will likely not have a generic handler.
  -- Instead, other systems responsible for specific functional items (e.g., a "MapSystem" for a map item)
  -- would listen for a generic "FunctionalItemUsed" event and check if the item is the one they care about.
end

return FunctionalSystem 