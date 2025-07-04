-- Server-side armor system (independent from InventoryServerSystem)
local ArmorServerSystem = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local ECS = require(ReplicatedStorage.Shared.ECS)
local Categories = require(ReplicatedStorage.Shared.ItemCategory)

local InventoryServerSystem = require(script.Parent.InventoryServerSystem)

-- Player armor storage (server-side, separate from inventory)
local playerArmor = {}

function ArmorServerSystem:Initialize()
    -- Handle armor requests (separate from inventory requests)
    RemoteEvents.ArmorRequest.OnServerInvoke = function(player, action, ...)
        return self:HandleArmorRequest(player, action, ...)
    end
    
    -- Initialize empty armor for existing players
    for _, player in pairs(Players:GetPlayers()) do
        self:InitializePlayerArmor(player)
    end
    
    -- Initialize for new players
    Players.PlayerAdded:Connect(function(player)
        self:InitializePlayerArmor(player)
    end)
    
    -- Clean up when players leave
    Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayerArmor(player)
    end)
    
    print("Armor server system initialized")
end

function ArmorServerSystem:InitializePlayerArmor(player)
    playerArmor[player] = {
        helmet = nil,
        chestplate = nil,
        boots = nil
    }
    
    print("Initialized armor for player:", player.Name)
end

function ArmorServerSystem:CleanupPlayerArmor(player)
    -- Drop any equipped armor back to world
    if playerArmor[player] then
        for armorSlot, armorItem in pairs(playerArmor[player]) do
            if armorItem then
                self:DropArmorToWorld(player, armorItem.object)
            end
        end
    end
    
    playerArmor[player] = nil
    
    print("Cleaned up armor for player:", player.Name)
end

function ArmorServerSystem:HandleArmorRequest(player, action, ...)
    local args = {...}
    
    print("[ARMOR SERVER DEBUG] ========== ARMOR REQUEST RECEIVED ==========")
    print("[ARMOR SERVER DEBUG] Player:", player.Name)
    print("[ARMOR SERVER DEBUG] Action:", action)
    print("[ARMOR SERVER DEBUG] Args count:", #args)
    for i, arg in ipairs(args) do
        print("[ARMOR SERVER DEBUG] Arg", i, ":", arg)
    end
    
    if action == "equip_armor" then
        local armorSlot, hotbarItem = args[1], args[2]
        print("[ARMOR SERVER DEBUG] Processing equip_armor request")
        print("[ARMOR SERVER DEBUG] Armor slot:", armorSlot)
        print("[ARMOR SERVER DEBUG] Hotbar item:", hotbarItem)
        return self:EquipArmor(player, armorSlot, hotbarItem)
    elseif action == "unequip_armor" then
        local armorSlot = args[1]
        print("[ARMOR SERVER DEBUG] Processing unequip_armor request")
        print("[ARMOR SERVER DEBUG] Armor slot:", armorSlot)
        return self:UnequipArmor(player, armorSlot)
    else
        print("[ARMOR SERVER DEBUG] ERROR: Unknown armor action:", action)
        warn("Unknown armor action:", action)
        return false, "Unknown action"
    end
    
    print("[ARMOR SERVER DEBUG] ================================================")
end

function ArmorServerSystem:EquipArmor(player, armorSlot, hotbarItem)
    print("[ARMOR SERVER DEBUG] --- EquipArmor START ---")
    print("[ARMOR SERVER DEBUG] Player:", player.Name)
    print("[ARMOR SERVER DEBUG] Armor slot:", armorSlot)
    print("[ARMOR SERVER DEBUG] Hotbar item:", hotbarItem)
    
    -- Validate armor slot
    if not self:IsValidArmorSlot(armorSlot) then
        print("[ARMOR SERVER DEBUG] ERROR: Invalid armor slot:", armorSlot)
        return false, "Invalid armor slot"
    end
    print("[ARMOR SERVER DEBUG] Armor slot validation passed")
    
    -- Check if armor slot is already occupied
    if playerArmor[player][armorSlot] then
        print("[ARMOR SERVER DEBUG] ERROR: Armor slot already occupied:", armorSlot)
        print("[ARMOR SERVER DEBUG] Current armor in slot:", playerArmor[player][armorSlot].itemName)
        return false, "Armor slot already occupied"
    end
    print("[ARMOR SERVER DEBUG] Armor slot is empty, proceeding")
    
    -- Validate hotbar item
    if not hotbarItem or not hotbarItem.object then
        print("[ARMOR SERVER DEBUG] ERROR: Invalid hotbar item")
        print("[ARMOR SERVER DEBUG] hotbarItem:", hotbarItem)
        print("[ARMOR SERVER DEBUG] hotbarItem.object:", hotbarItem and hotbarItem.object)
        return false, "Invalid hotbar item"
    end
    print("[ARMOR SERVER DEBUG] Hotbar item validation passed")
    print("[ARMOR SERVER DEBUG] Item name:", hotbarItem.itemName)
    print("[ARMOR SERVER DEBUG] Item ID:", hotbarItem.itemId)
    print("[ARMOR SERVER DEBUG] Item object:", hotbarItem.object)
    
    -- Validate that item is compatible armor
    local itemDef = ItemDefinitions:GetItem(hotbarItem.itemId)
    print("[ARMOR SERVER DEBUG] Item definition lookup result:", itemDef)
    
    if not itemDef then
        print("[ARMOR SERVER DEBUG] ERROR: No item definition found for ID:", hotbarItem.itemId)
        return false, "Item definition not found"
    end
    
    print("[ARMOR SERVER DEBUG] Item definition details:")
    print("[ARMOR SERVER DEBUG]   - Category:", itemDef.category)
    print("[ARMOR SERVER DEBUG]   - Armor Slot:", itemDef.armorSlot)
    
    if itemDef.category ~= Categories.Armor then
        print("[ARMOR SERVER DEBUG] ERROR: Item is not armor, category:", itemDef.category)
        return false, "Item is not armor"
    end
    
    if itemDef.armorSlot ~= armorSlot then
        print("[ARMOR SERVER DEBUG] ERROR: Armor slot mismatch")
        print("[ARMOR SERVER DEBUG]   - Item slot:", itemDef.armorSlot)
        print("[ARMOR SERVER DEBUG]   - Target slot:", armorSlot)
        return false, "Item is not compatible armor"
    end
    
    print("[ARMOR SERVER DEBUG] Item compatibility validation passed")

    -- Validate that player can equip this item (distance check)
    -- IMPORTANT: Skip distance check if item is already in ReplicatedStorage (i.e., in inventory)
    if hotbarItem.object.Parent ~= ReplicatedStorage then
        local canEquip = self:CanPlayerEquipItem(player, hotbarItem.object)
        print("[ARMOR SERVER DEBUG] Distance check result:", canEquip)
        
        if not canEquip then
            print("[ARMOR SERVER DEBUG] ERROR: Player too far from item")
            return false, "Player cannot equip this item"
        end
    end
    
    -- Store armor information
    local armorInfo = {
        object = hotbarItem.object,
        itemName = hotbarItem.itemName,
        itemId = hotbarItem.itemId,
        originalCFrame = hotbarItem.object.CFrame,
        originalParent = hotbarItem.object.Parent
    }
    
    print("[ARMOR SERVER DEBUG] Created armor info:", armorInfo)
    
    -- Equip armor (move to ReplicatedStorage for safekeeping)
    playerArmor[player][armorSlot] = armorInfo
    hotbarItem.object.Parent = ReplicatedStorage
    hotbarItem.object.Anchored = true
    
    print("[ARMOR SERVER DEBUG] Armor equipped successfully")
    print("[ARMOR SERVER DEBUG] Object moved to ReplicatedStorage and anchored")
    print("[ARMOR SERVER DEBUG] Player armor state:", playerArmor[player])
    
    print("[ARMOR SERVER DEBUG] SUCCESS: Player", player.Name, "equipped", hotbarItem.itemName, "to", armorSlot)
    print("[ARMOR SERVER DEBUG] --- EquipArmor END ---")

    InventoryServerSystem:RemoveItemByObject(player, hotbarItem.object)

    return true, "Successfully equipped armor"
end

function ArmorServerSystem:UnequipArmor(player, armorSlot)
    -- Validate armor slot
    if not self:IsValidArmorSlot(armorSlot) then
        return false, "Invalid armor slot"
    end
    
    -- Check if armor slot has item
    local armorItem = playerArmor[player][armorSlot]
    if not armorItem then
        return false, "Armor slot is empty"
    end
    
    -- Validate armor object
    if not armorItem.object or not armorItem.object.Parent then
        return false, "Armor object is invalid"
    end
    
    -- Instead of dropping to world, store back into player's inventory

    local success, slotOrMsg = InventoryServerSystem:AddItemToFirstEmptySlot(player, armorItem.object)

    if not success then
        -- If inventory full, fallback to world drop (maintain previous behaviour)
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local humanoidRootPart = character.HumanoidRootPart
            local spawnPosition = humanoidRootPart.CFrame * CFrame.new(0, 0, -3)
            armorItem.object.Parent = workspace
            armorItem.object.CFrame = spawnPosition
            armorItem.object.Anchored = false
        else
            armorItem.object.Parent = workspace
            armorItem.object.CFrame = CFrame.new(0, 10, 0)
            armorItem.object.Anchored = false
        end
        playerArmor[player][armorSlot] = nil
        return true, "Inventory full - dropped to world"
    end

    -- Successfully placed back into inventory
    playerArmor[player][armorSlot] = nil
    return true, "Returned to inventory slot " .. tostring(slotOrMsg)
end

function ArmorServerSystem:IsValidArmorSlot(armorSlot)
    return armorSlot == "helmet" or armorSlot == "chestplate" or armorSlot == "boots"
end

function ArmorServerSystem:CanPlayerEquipItem(player, object)
    -- Check if player is close enough to the item
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local humanoidRootPart = character.HumanoidRootPart
    local distance = (humanoidRootPart.Position - object.Position).Magnitude
    
    -- Use same distance limit as inventory system (15 studs)
    return distance <= 15
end

function ArmorServerSystem:DropArmorToWorld(player, armorObject)
    -- Helper function to drop armor back to world when player leaves
    if not armorObject or not armorObject.Parent then
        return
    end
    
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local humanoidRootPart = character.HumanoidRootPart
        local dropPosition = humanoidRootPart.CFrame * CFrame.new(0, 0, -3)
        
        armorObject.Parent = workspace
        armorObject.CFrame = dropPosition
        armorObject.Anchored = false
    else
        -- If no character, just drop at world origin
        armorObject.Parent = workspace
        armorObject.CFrame = CFrame.new(0, 10, 0)
        armorObject.Anchored = false
    end
end

-- Public methods for other systems
function ArmorServerSystem:GetPlayerArmor(player)
    return playerArmor[player] or {}
end

function ArmorServerSystem:IsArmorSlotOccupied(player, armorSlot)
    return playerArmor[player] and playerArmor[player][armorSlot] ~= nil
end

return ArmorServerSystem 