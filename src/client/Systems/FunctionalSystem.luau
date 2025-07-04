-- Placeholder for Functional Item-related client-side logic
local FunctionalSystem = {}

function FunctionalSystem:Initialize()
	_G.FunctionalSystem = self
	print("Functional system initialized")
end

function FunctionalSystem:Use(itemDef, player, target)
	print("FunctionalSystem: Use called for", itemDef.name)
	if target then
		print("FunctionalSystem: Target is", target:GetFullName())
	else
		print("FunctionalSystem: No target was hit.")
	end
end

return FunctionalSystem 