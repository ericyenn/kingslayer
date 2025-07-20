-- PrefabLibrary.lua
-- Prefab model library for creating standardized models for different entity types
-- Supports generic model variations and extensible prefab definitions

local PrefabLibrary = {}

-- Prefab configuration
local PREFAB_CONFIG = {
	defaultSize = Vector3.new(2, 2, 2),
	defaultMaterial = Enum.Material.Plastic,
	scaleVariation = 0.2, -- +/- 20% size variation
	enableRandomRotation = true,
	maxPrefabsPerType = 10, -- Maximum prefab variations per entity type
}

-- Entity type definitions with prefab configurations
local ENTITY_PREFABS = {
	-- Trees and natural structures
	tree = {
		category = "natural",
		variations = {
			{
				name = "OakTree",
				description = "Standard oak tree with trunk and canopy",
				baseSize = Vector3.new(3, 12, 3),
				parts = {
					{name = "Trunk", size = Vector3.new(1.5, 8, 1.5), position = Vector3.new(0, 0, 0), material = "Wood"},
					{name = "Canopy", size = Vector3.new(8, 6, 8), position = Vector3.new(0, 6, 0), material = "Leaf", shape = "Ball"}
				}
			},
			{
				name = "PineTree",
				description = "Coniferous tree with triangular shape",
				baseSize = Vector3.new(2, 15, 2),
				parts = {
					{name = "Trunk", size = Vector3.new(1, 10, 1), position = Vector3.new(0, 0, 0), material = "Wood"},
					{name = "Branches1", size = Vector3.new(6, 3, 6), position = Vector3.new(0, 7, 0), material = "Leaf", shape = "Cylinder"},
					{name = "Branches2", size = Vector3.new(4, 3, 4), position = Vector3.new(0, 9, 0), material = "Leaf", shape = "Cylinder"},
					{name = "Top", size = Vector3.new(2, 3, 2), position = Vector3.new(0, 11, 0), material = "Leaf", shape = "Cylinder"}
				}
			}
		}
	},
	
	-- Enemy entities
	enemy = {
		category = "hostile",
		variations = {
			{
				name = "HumanoidEnemy",
				description = "Standard humanoid enemy",
				baseSize = Vector3.new(2, 6, 2),
				parts = {
					{name = "Head", shape = "Ball", size = Vector3.new(2, 2, 2), position = Vector3.new(0, 2.5, 0), material = "Flesh"},
					{name = "Torso", size = Vector3.new(2, 2, 1), position = Vector3.new(0, 0, 0), material = "Flesh"},
					{name = "LeftArm", size = Vector3.new(1, 2, 1), position = Vector3.new(-1.5, 0, 0), material = "Flesh"},
					{name = "RightArm", size = Vector3.new(1, 2, 1), position = Vector3.new(1.5, 0, 0), material = "Flesh"},
					{name = "LeftLeg", size = Vector3.new(1, 2, 1), position = Vector3.new(-0.5, -2, 0), material = "Flesh"},
					{name = "RightLeg", size = Vector3.new(1, 2, 1), position = Vector3.new(0.5, -2, 0), material = "Flesh"}
				},
				attachments = {},
				humanoid = {
					health = 100,
					walkSpeed = 16,
					jumpPower = 50,
				}
			},
			{
				name = "Orc",
				description = "Basic enemy with humanoid shape",
				baseSize = Vector3.new(2, 6, 2),
				parts = {
					{name = "Torso", size = Vector3.new(2, 3, 1), position = Vector3.new(0, 0, 0), material = "Flesh"},
					{name = "Head", size = Vector3.new(1.5, 1.5, 1.5), position = Vector3.new(0, 2.25, 0), material = "Flesh", shape = "Ball"},
					{name = "LeftArm", size = Vector3.new(0.8, 2.5, 0.8), position = Vector3.new(-1.4, 0, 0), material = "Flesh"},
					{name = "RightArm", size = Vector3.new(0.8, 2.5, 0.8), position = Vector3.new(1.4, 0, 0), material = "Flesh"},
					{name = "LeftLeg", size = Vector3.new(0.8, 2.5, 0.8), position = Vector3.new(-0.6, -2.75, 0), material = "Flesh"},
					{name = "RightLeg", size = Vector3.new(0.8, 2.5, 0.8), position = Vector3.new(0.6, -2.75, 0), material = "Flesh"}
				}
			},
			{
				name = "Spider",
				description = "Multi-legged creature",
				baseSize = Vector3.new(4, 2, 4),
				parts = {
					{name = "Body", size = Vector3.new(3, 1.5, 2), position = Vector3.new(0, 0, 0), material = "Chitin", shape = "Ball"},
					{name = "Head", size = Vector3.new(1.5, 1, 1.5), position = Vector3.new(0, 0, 1.75), material = "Chitin"},
					{name = "Leg1", size = Vector3.new(0.3, 0.3, 3), position = Vector3.new(-1.5, 0, 1), material = "Chitin"},
					{name = "Leg2", size = Vector3.new(0.3, 0.3, 3), position = Vector3.new(1.5, 0, 1), material = "Chitin"},
					{name = "Leg3", size = Vector3.new(0.3, 0.3, 3), position = Vector3.new(-1.5, 0, -1), material = "Chitin"},
					{name = "Leg4", size = Vector3.new(0.3, 0.3, 3), position = Vector3.new(1.5, 0, -1), material = "Chitin"}
				}
			}
		}
	},
	
	-- Boss entities
	boss = {
		category = "elite",
		variations = {
			{
				name = "DragonBoss",
				description = "Large dragon with wings and breath attack",
				baseSize = Vector3.new(12, 8, 20),
				parts = {
					{name = "Body", size = Vector3.new(8, 6, 12), position = Vector3.new(0, 0, 0), material = "DragonScale"},
					{name = "Head", size = Vector3.new(4, 3, 6), position = Vector3.new(0, 3, 8), material = "DragonScale"},
					{name = "LeftWing", size = Vector3.new(12, 1, 8), position = Vector3.new(-6, 2, -2), material = "Membrane"},
					{name = "RightWing", size = Vector3.new(12, 1, 8), position = Vector3.new(6, 2, -2), material = "Membrane"},
					{name = "Tail", size = Vector3.new(2, 2, 10), position = Vector3.new(0, 0, -8), material = "DragonScale"}
				}
			}
		}
	},
	
	-- Structures and buildings
	structure = {
		category = "building",
		variations = {
			{
				name = "Hut",
				description = "Small dwelling structure",
				baseSize = Vector3.new(8, 8, 8),
				parts = {
					{name = "Walls", size = Vector3.new(8, 6, 8), position = Vector3.new(0, 0, 0), material = "Wood"},
					{name = "Roof", size = Vector3.new(10, 3, 10), position = Vector3.new(0, 4.5, 0), material = "Thatch", shape = "Wedge"},
					{name = "Door", size = Vector3.new(2, 4, 0.5), position = Vector3.new(0, -1, 4), material = "Wood"}
				}
			},
			{
				name = "Tower",
				description = "Tall defensive structure",
				baseSize = Vector3.new(6, 20, 6),
				parts = {
					{name = "Base", size = Vector3.new(6, 16, 6), position = Vector3.new(0, 0, 0), material = "Stone"},
					{name = "Roof", size = Vector3.new(8, 5, 8), position = Vector3.new(0, 10.5, 0), material = "Stone", shape = "Cylinder"},
					{name = "Window1", size = Vector3.new(1, 2, 0.5), position = Vector3.new(3, 4, 0), material = "Glass"},
					{name = "Window2", size = Vector3.new(1, 2, 0.5), position = Vector3.new(-3, 4, 0), material = "Glass"},
					{name = "Window3", size = Vector3.new(1, 2, 0.5), position = Vector3.new(0, 8, 3), material = "Glass"}
				}
			}
		}
	},
	
	-- Resource nodes
	resource = {
		category = "harvestable",
		variations = {
			{
				name = "RockNode",
				description = "Mineable rock formation",
				baseSize = Vector3.new(4, 3, 4),
				parts = {
					{name = "MainRock", size = Vector3.new(4, 3, 4), position = Vector3.new(0, 0, 0), material = "Rock", shape = "Ball"},
					{name = "Crystal", size = Vector3.new(1, 2, 1), position = Vector3.new(1, 1, 1), material = "Crystal"}
				}
			},
			{
				name = "BerryBush",
				description = "Harvestable food source",
				baseSize = Vector3.new(3, 2, 3),
				parts = {
					{name = "Bush", size = Vector3.new(3, 2, 3), position = Vector3.new(0, 0, 0), material = "Leaf", shape = "Ball"},
					{name = "Berries", size = Vector3.new(0.3, 0.3, 0.3), position = Vector3.new(1, 1, 0), material = "Berry", shape = "Ball"},
					{name = "Berries2", size = Vector3.new(0.3, 0.3, 0.3), position = Vector3.new(-0.5, 0.8, 1), material = "Berry", shape = "Ball"},
					{name = "Berries3", size = Vector3.new(0.3, 0.3, 0.3), position = Vector3.new(0, 1.2, -1), material = "Berry", shape = "Ball"}
				}
			}
		}
	},
	
	-- Spawner objects
	spawner = {
		category = "system",
		variations = {
			{
				name = "GenericSpawner",
				description = "A generic spawner object",
				baseSize = Vector3.new(3, 3, 3),
				parts = {
					{name = "Base", size = Vector3.new(3, 1, 3), position = Vector3.new(0, 0, 0), material = "Metal", shape = "Cylinder"},
					{name = "Core", size = Vector3.new(1, 1, 1), position = Vector3.new(0, 1.5, 0), material = "Neon", shape = "Ball"}
				}
			}
		}
	},
	
	-- Default fallback
	default = {
		category = "misc",
		variations = {
			{
				name = "Placeholder",
				description = "Generic placeholder object",
				baseSize = Vector3.new(2, 2, 2),
				parts = {
					{name = "Main", size = Vector3.new(2, 2, 2), position = Vector3.new(0, 0, 0), material = "Neon", shape = "Ball"}
				}
			}
		}
	}
}

-- Material mappings
local MATERIAL_MAPPINGS = {
	Wood = Enum.Material.Wood,
	Leaf = Enum.Material.Grass,
	Flesh = Enum.Material.Plastic,
	Chitin = Enum.Material.Metal,
	DragonScale = Enum.Material.DiamondPlate,
	Membrane = Enum.Material.Fabric,
	Stone = Enum.Material.Concrete,
	Thatch = Enum.Material.Wood,
	Glass = Enum.Material.Glass,
	Rock = Enum.Material.Rock,
	Crystal = Enum.Material.Neon,
	Berry = Enum.Material.Neon,
	Neon = Enum.Material.Neon
}

-- Color mappings for materials
local MATERIAL_COLORS = {
	Wood = Color3.new(0.6, 0.4, 0.2),
	Leaf = Color3.new(0.2, 0.8, 0.2),
	Flesh = Color3.new(0.8, 0.6, 0.5),
	Chitin = Color3.new(0.2, 0.2, 0.2),
	DragonScale = Color3.new(0.8, 0.2, 0.2),
	Membrane = Color3.new(0.4, 0.3, 0.2),
	Stone = Color3.new(0.6, 0.6, 0.6),
	Thatch = Color3.new(0.8, 0.7, 0.4),
	Glass = Color3.new(0.8, 0.9, 1),
	Rock = Color3.new(0.4, 0.4, 0.4),
	Crystal = Color3.new(0.3, 0.8, 1),
	Berry = Color3.new(0.8, 0.2, 0.4),
	Neon = Color3.new(0.2, 0.8, 1)
}

-- ================================
-- PREFAB CREATION FUNCTIONS
-- ================================

-- Get prefab data for a specific entity type and variation
function PrefabLibrary.getPrefabData(entityType, variationName)
	local entityCategory = ENTITY_PREFABS[entityType] or ENTITY_PREFABS.default
	
	if variationName then
		for _, variation in ipairs(entityCategory.variations) do
			if variation.name == variationName then
				return variation
			end
		end
	end
	
	-- Return first variation if no name is specified
	return entityCategory.variations[1]
end

-- Create a prefab model for a given entity type
function PrefabLibrary.createPrefab(entityType, variationName)
	local prefabData = PrefabLibrary.getPrefabData(entityType, variationName)
	if not prefabData then
		warn("Prefab not found for type: " .. entityType .. " and variation: " .. (variationName or "default"))
		return nil
	end

	local model = Instance.new("Model")
	model.Name = prefabData.name

	for i, partData in ipairs(prefabData.parts) do
		local part = Instance.new("Part")
		part.Name = partData.name
		part.Size = partData.size
		part.Position = partData.position
		part.Anchored = false

		if partData.shape then
			part.Shape = Enum.PartType[partData.shape]
		end
		
		local materialName = partData.material or "Plastic"
		part.Material = MATERIAL_MAPPINGS[materialName] or Enum.Material.Plastic
		part.Color = MATERIAL_COLORS[materialName] or Color3.new(1, 1, 1)

		part.Parent = model
		
		if i == 1 then
			model.PrimaryPart = part
		else
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = model.PrimaryPart
			weld.Part1 = part
			weld.Parent = model.PrimaryPart
		end
	end
	
	if prefabData.humanoid then
		local humanoid = Instance.new("Humanoid")
		humanoid.Health = prefabData.humanoid.health or 100
		humanoid.MaxHealth = prefabData.humanoid.health or 100
		humanoid.WalkSpeed = prefabData.humanoid.walkSpeed or 16
		humanoid.JumpPower = prefabData.humanoid.jumpPower or 50
		humanoid.Parent = model
		
		if model.PrimaryPart then
			local rootPart = model.PrimaryPart
			rootPart.Name = "HumanoidRootPart"
			rootPart.CanCollide = true
			rootPart.Anchored = false
		end
	end

	return model
end

local categoryCount = 0
for _ in pairs(ENTITY_PREFABS) do
	categoryCount = categoryCount + 1
end

print("📦 PrefabLibrary loaded with " .. categoryCount .. " entity categories.")

function PrefabLibrary.createEnemyPrefab()
    if prefabCache.enemy then
        return prefabCache.enemy:Clone()
    end
    
    local model = Instance.new("Model")
    model.Name = "EnemyPrefab"
    
    local humanoid = Instance.new("Humanoid")
    humanoid.Name = "Humanoid"
    humanoid.Health = 100
    humanoid.MaxHealth = 100
    humanoid.WalkSpeed = 16
    humanoid.Parent = model
    
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2, 2, 1)
    hrp.Position = Vector3.new(0, 3, 0)
    hrp.Anchored = false
    hrp.Massless = true
    hrp.Parent = model
    
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(2, 2, 2)
    head.Position = Vector3.new(0, 5, 0)
    head.Parent = model
    
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(4, 4, 2)
    torso.Position = Vector3.new(0, 2, 0)
    torso.Parent = model
    
    local leftArm = Instance.new("Part")
    leftArm.Name = "LeftArm"
    leftArm.Size = Vector3.new(1, 4, 1)
    leftArm.Position = Vector3.new(-2.5, 2, 0)
    leftArm.Parent = model
    
    local rightArm = Instance.new("Part")
    rightArm.Name = "RightArm"
    rightArm.Size = Vector3.new(1, 4, 1)
    rightArm.Position = Vector3.new(2.5, 2, 0)
    rightArm.Parent = model
    
    local leftLeg = Instance.new("Part")
    leftLeg.Name = "LeftLeg"
    leftLeg.Size = Vector3.new(1.5, 4, 1.5)
    leftLeg.Position = Vector3.new(-1, -2, 0)
    leftLeg.Parent = model
    
    local rightLeg = Instance.new("Part")
    rightLeg.Name = "RightLeg"
    rightLeg.Size = Vector3.new(1.5, 4, 1.5)
    rightLeg.Position = Vector3.new(1, -2, 0)
    rightLeg.Parent = model
    
    -- Create welds to hold the model together
    local rootWeld = Instance.new("WeldConstraint")
    rootWeld.Part0 = hrp
    rootWeld.Part1 = torso
    rootWeld.Parent = hrp
    
    local headWeld = Instance.new("WeldConstraint")
    headWeld.Part0 = torso
    headWeld.Part1 = head
    headWeld.Parent = torso
    
    local leftArmWeld = Instance.new("WeldConstraint")
    leftArmWeld.Part0 = torso
    leftArmWeld.Part1 = leftArm
    leftArmWeld.Parent = torso
    
    local rightArmWeld = Instance.new("WeldConstraint")
    rightArmWeld.Part0 = torso
    rightArmWeld.Part1 = rightArm
    rightArmWeld.Parent = torso
    
    local leftLegWeld = Instance.new("WeldConstraint")
    leftLegWeld.Part0 = torso
    leftLegWeld.Part1 = leftLeg
    leftLegWeld.Parent = torso
    
    local rightLegWeld = Instance.new("WeldConstraint")
    rightLegWeld.Part0 = torso
    rightLegWeld.Part1 = rightLeg
    rightLegWeld.Parent = torso
    
    prefabCache.enemy = model
    
    return model:Clone()
end

function PrefabLibrary.get(name)
    if prefabs[name] then
        return prefabs[name]
    end
    
    -- In a real scenario, you would load these from ReplicatedStorage
    -- For this test, we'll just create a simple part
    local prefab = Instance.new("Part")
    prefab.Size = Vector3.new(4, 4, 4)
    prefab.Anchored = true
    prefab.Name = name
    
    prefabs[name] = prefab
    return prefab
end

function PrefabLibrary.create(name, properties)
    local template = PrefabLibrary.get(name)
    local newInstance = template:Clone()
    
    for prop, value in pairs(properties) do
        newInstance[prop] = value
    end
    
    return newInstance
end

return PrefabLibrary 