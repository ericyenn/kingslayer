-- HitboxTest.luau
-- Simple test script to verify hitbox system functionality

local HitboxSystem = require(script.Parent.HitboxSystem)
local HitboxConfig = require(script.Parent.HitboxConfig)

local HitboxTest = {}

function HitboxTest.runTests()
    print("=== Hitbox System Tests ===")
    
    -- Test 1: Configuration loading
    print("Test 1: Configuration loading")
    local config = HitboxSystem.getConfig()
    assert(config ~= nil, "Configuration should not be nil")
    print("✓ Configuration loaded successfully")
    
    -- Test 2: Item settings
    print("Test 2: Item settings")
    local swordSettings = HitboxSystem.getItemSettings("sword")
    assert(swordSettings ~= nil, "Sword settings should not be nil")
    assert(swordSettings.size ~= nil, "Sword size should not be nil")
    print("✓ Item settings working")
    
    -- Test 3: Enemy settings
    print("Test 3: Enemy settings")
    local meleeSettings = HitboxSystem.getEnemySettings("melee")
    assert(meleeSettings ~= nil, "Melee settings should not be nil")
    assert(meleeSettings.size ~= nil, "Melee size should not be nil")
    print("✓ Enemy settings working")
    
    -- Test 4: Default settings fallback
    print("Test 4: Default settings fallback")
    local unknownSettings = HitboxSystem.getItemSettings("unknown_item")
    assert(unknownSettings ~= nil, "Unknown item should return default settings")
    print("✓ Default settings fallback working")
    
    -- Test 5: GetPartsInPart detection
    print("Test 5: GetPartsInPart detection")
    assert(config.useGetPartsInPart == true, "Should use GetPartsInPart for detection")
    print("✓ GetPartsInPart detection configured")
    
    print("=== All tests passed! ===")
end

return HitboxTest 