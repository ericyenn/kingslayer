-- Placeholder for Tool-related client-side logic
local ToolSystem = {}

function ToolSystem:Initialize()
	_G.ToolSystem = self
	print("Tool system initialized")
end

function ToolSystem:Use(itemDef, player, target)
	print("ToolSystem: Use called for", itemDef.name)
	if target then
		print("ToolSystem: Target is", target:GetFullName())
	else
		print("ToolSystem: No target was hit.")
	end
end

return ToolSystem 