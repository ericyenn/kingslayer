-- Armor system for handling armor equipment independently
local ArmorSystem = {}

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local Categories = require(ReplicatedStorage.Shared.ItemCategory)

local player = Players.LocalPlayer

-- Armor state (separate from hotbar inventory)
local playerArmor = {
    helmet = nil,
    chestplate = nil,
    boots = nil
}

-- UI reference
local ArmorMenu = nil

function ArmorSystem:Initialize()
    -- Set up global reference for UI callbacks
    _G.ArmorSystem = self
    
    -- Initialize armor menu UI
    ArmorMenu = require(script.Parent.Parent.UI.ArmorMenu)
    ArmorMenu:Initialize()
    
    -- Handle G key input (independent from other systems)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.G then
            print("[ARMOR DEBUG] G key pressed - toggling armor menu")
            self:HandleGKeyPress()
        end
    end)
    
    print("[ARMOR DEBUG] Armor system initialized")
end

function ArmorSystem:HandleGKeyPress()
    -- Toggle armor menu visibility
    print("[ARMOR DEBUG] Handling G key press - toggling menu")
    ArmorMenu:Toggle()
end

function ArmorSystem:HandleSlotClick(armorSlot)
    -- Handle clicking on armor slots
    print("[ARMOR DEBUG] ========== ARMOR SLOT CLICKED ==========")
    print("[ARMOR DEBUG] Clicked slot:", armorSlot)
    
    local currentArmor = playerArmor[armorSlot]
    print("[ARMOR DEBUG] Current armor in slot:", currentArmor and currentArmor.itemName or "EMPTY")
    
    if currentArmor then
        -- Unequip armor (move back to hotbar)
        print("[ARMOR DEBUG] Slot has armor - attempting to unequip")
        self:UnequipArmor(armorSlot)
    else
        -- Try to equip armor from hotbar
        print("[ARMOR DEBUG] Slot is empty - attempting to equip from hotbar")
        self:TryEquipArmorFromHotbar(armorSlot)
    end
    
    print("[ARMOR DEBUG] ========================================")
end

function ArmorSystem:TryEquipArmorFromHotbar(armorSlot)
    print("[ARMOR DEBUG] --- TryEquipArmorFromHotbar START ---")
    print("[ARMOR DEBUG] Target armor slot:", armorSlot)
    
    -- Check if player has compatible armor equipped in hotbar
    local equippedItem = self:GetEquippedHotbarItem()
    print("[ARMOR DEBUG] Equipped hotbar item:", equippedItem and equippedItem.itemName or "NONE")
    
    if not equippedItem then
        -- Nothing equipped – cannot proceed
        return
    end
    
    print("[ARMOR DEBUG] Equipped item details:")
    print("[ARMOR DEBUG]   - Name:", equippedItem.itemName)
    print("[ARMOR DEBUG]   - ID:", equippedItem.itemId)
    print("[ARMOR DEBUG]   - Object:", equippedItem.object)
    
    -- Check if equipped item is armor of the right type
    local itemDef = ItemDefinitions:GetItem(equippedItem.itemId)
    print("[ARMOR DEBUG] Item definition lookup result:", itemDef)
    
    if not itemDef then
        print("[ARMOR DEBUG] ERROR: No item definition found for ID:", equippedItem.itemId)
        return
    end
    
    print("[ARMOR DEBUG] Item definition details:")
    print("[ARMOR DEBUG]   - Category:", itemDef.category)
    print("[ARMOR DEBUG]   - Armor Slot:", itemDef.armorSlot)
    print("[ARMOR DEBUG]   - Expected slot:", armorSlot)
    
    if itemDef.category ~= Categories.Armor then
        print("[ARMOR DEBUG] ERROR: Equipped item is not armor (category:", itemDef.category, ")")
        return
    end
    
    if itemDef.armorSlot ~= armorSlot then
        print("[ARMOR DEBUG] ERROR: Equipped armor is for different slot")
        print("[ARMOR DEBUG]   - Item slot:", itemDef.armorSlot)
        print("[ARMOR DEBUG]   - Target slot:", armorSlot)
        return
    end
    
    print("[ARMOR DEBUG] SUCCESS: Item is compatible armor for", armorSlot)
    print("[ARMOR DEBUG] Proceeding to request armor equip from server")
    
    -- Request armor equip from server
    self:RequestArmorEquip(armorSlot, equippedItem)
    
    print("[ARMOR DEBUG] --- TryEquipArmorFromHotbar END ---")
end

function ArmorSystem:UnequipArmor(armorSlot)
    print("[ARMOR DEBUG] --- UnequipArmor START ---")
    print("[ARMOR DEBUG] Unequipping armor from slot:", armorSlot)
    
    -- Request armor unequip from server
    self:RequestArmorUnequip(armorSlot)
    
    print("[ARMOR DEBUG] --- UnequipArmor END ---")
end

function ArmorSystem:RequestArmorEquip(armorSlot, hotbarItem)
    print("[ARMOR DEBUG] --- RequestArmorEquip START ---")
    print("[ARMOR DEBUG] Requesting equip for slot:", armorSlot)
    print("[ARMOR DEBUG] Item to equip:", hotbarItem.itemName)
    
    local success, result, message = pcall(function()
        print("[ARMOR DEBUG] Calling RemoteEvents.ArmorRequest:InvokeServer...")
        return RemoteEvents.ArmorRequest:InvokeServer("equip_armor", armorSlot, hotbarItem)
    end)
    
    print("[ARMOR DEBUG] Server call completed")
    print("[ARMOR DEBUG] Call success:", success)
    
    if not success then
        print("[ARMOR DEBUG] ERROR: ArmorRequest call failed:", result)
        warn("ArmorRequest call failed:", result)
        return
    end
    
    local serverSuccess, serverMessage = result, message
    print("[ARMOR DEBUG] Server response success:", serverSuccess)
    print("[ARMOR DEBUG] Server response message:", serverMessage)
    
    if serverSuccess then
        -- Update local armor state
        playerArmor[armorSlot] = {
            itemName = hotbarItem.itemName,
            itemId = hotbarItem.itemId,
            object = hotbarItem.object
        }
        
        print("[ARMOR DEBUG] Updated local armor state for slot:", armorSlot)
        print("[ARMOR DEBUG] Local armor state:", playerArmor)
        
        -- Update armor menu display
        ArmorMenu:UpdateDisplay(playerArmor)
        print("[ARMOR DEBUG] Updated armor menu display")
        
        -- Notify inventory system to update hotbar (remove equipped item)
        self:NotifyInventorySystemArmorEquipped()
        print("[ARMOR DEBUG] Notified inventory system of armor equip")
        
        print("[ARMOR DEBUG] SUCCESS: Successfully equipped armor:", hotbarItem.itemName, "to", armorSlot)
    else
        print("[ARMOR DEBUG] ERROR: Server rejected armor equip:", serverMessage)
        warn("Failed to equip armor:", serverMessage)
    end
    
    print("[ARMOR DEBUG] --- RequestArmorEquip END ---")
end

function ArmorSystem:RequestArmorUnequip(armorSlot)
    print("[ARMOR DEBUG] --- RequestArmorUnequip START ---")
    print("[ARMOR DEBUG] Requesting unequip for slot:", armorSlot)
    
    local success, result, message = pcall(function()
        print("[ARMOR DEBUG] Calling RemoteEvents.ArmorRequest:InvokeServer for unequip...")
        return RemoteEvents.ArmorRequest:InvokeServer("unequip_armor", armorSlot)
    end)
    
    print("[ARMOR DEBUG] Server unequip call completed")
    print("[ARMOR DEBUG] Call success:", success)
    
    if not success then
        print("[ARMOR DEBUG] ERROR: ArmorRequest unequip call failed:", result)
        warn("ArmorRequest call failed:", result)
        return
    end
    
    local serverSuccess, serverMessage = result, message
    print("[ARMOR DEBUG] Server unequip response success:", serverSuccess)
    print("[ARMOR DEBUG] Server unequip response message:", serverMessage)
    
    if serverSuccess then
        -- Clear local armor state
        local unequippedArmor = playerArmor[armorSlot]
        playerArmor[armorSlot] = nil
        
        print("[ARMOR DEBUG] Cleared local armor state for slot:", armorSlot)
        print("[ARMOR DEBUG] Unequipped armor:", unequippedArmor and unequippedArmor.itemName or "UNKNOWN")
        
        -- Update armor menu display
        ArmorMenu:UpdateDisplay(playerArmor)
        print("[ARMOR DEBUG] Updated armor menu display after unequip")
        
        -- Notify inventory system to update hotbar (add back to hotbar)
        self:NotifyInventorySystemArmorUnequipped(unequippedArmor)
        print("[ARMOR DEBUG] Notified inventory system of armor unequip")
        
        print("[ARMOR DEBUG] SUCCESS: Successfully unequipped armor from", armorSlot)
    else
        print("[ARMOR DEBUG] ERROR: Server rejected armor unequip:", serverMessage)
        warn("Failed to unequip armor:", serverMessage)
    end
    
    print("[ARMOR DEBUG] --- RequestArmorUnequip END ---")
end

function ArmorSystem:GetEquippedHotbarItem()
    print("[ARMOR DEBUG] --- GetEquippedHotbarItem START ---")
    
    -- Get currently equipped item from inventory system (minimal coupling)
    if _G.InventorySystem then
        print("[ARMOR DEBUG] InventorySystem found - getting equipped item")
        local equippedItem = _G.InventorySystem:GetEquippedItem()
        print("[ARMOR DEBUG] InventorySystem returned equipped item:", equippedItem and equippedItem.itemName or "NONE")
        return equippedItem
    else
        print("[ARMOR DEBUG] ERROR: InventorySystem not found in _G")
        return nil
    end
    
    print("[ARMOR DEBUG] --- GetEquippedHotbarItem END ---")
end

function ArmorSystem:NotifyInventorySystemArmorEquipped()
    print("[ARMOR DEBUG] --- NotifyInventorySystemArmorEquipped START ---")
    
    -- Notify inventory system that armor was equipped (remove from hotbar)
    if _G.InventorySystem then
        print("[ARMOR DEBUG] Notifying InventorySystem of armor equip")
        _G.InventorySystem:HandleArmorEquipped()
        print("[ARMOR DEBUG] InventorySystem notified successfully")
    else
        print("[ARMOR DEBUG] ERROR: InventorySystem not found for notification")
    end
    
    print("[ARMOR DEBUG] --- NotifyInventorySystemArmorEquipped END ---")
end

function ArmorSystem:NotifyInventorySystemArmorUnequipped(armorItem)
    print("[ARMOR DEBUG] --- NotifyInventorySystemArmorUnequipped START ---")
    print("[ARMOR DEBUG] Armor item to restore:", armorItem and armorItem.itemName or "UNKNOWN")
    
    -- Notify inventory system that armor was unequipped (add back to hotbar)
    if _G.InventorySystem then
        print("[ARMOR DEBUG] Notifying InventorySystem of armor unequip")
        _G.InventorySystem:HandleArmorUnequipped(armorItem)
        print("[ARMOR DEBUG] InventorySystem notified successfully")
    else
        print("[ARMOR DEBUG] ERROR: InventorySystem not found for notification")
    end
    
    print("[ARMOR DEBUG] --- NotifyInventorySystemArmorUnequipped END ---")
end

function ArmorSystem:TryEquipFromUse(heldItem)
    print("[ARMOR DEBUG] --- TryEquipFromUse START ---")
    print("[ARMOR DEBUG] Attempting to equip from use:", heldItem and heldItem.itemName or "UNKNOWN")

    if not heldItem or not heldItem.itemId then
        print("[ARMOR DEBUG] ERROR: Invalid held item data")
        return
    end

    local itemDef = ItemDefinitions:GetItem(heldItem.itemId)
    if not itemDef or itemDef.category ~= Categories.Armor or not itemDef.armorSlot then
        print("[ARMOR DEBUG] ERROR: Held item is not valid armor or has no armor slot defined")
        return
    end

    local armorSlot = itemDef.armorSlot
    print("[ARMOR DEBUG] Target armor slot:", armorSlot)

    -- Check if the target armor slot is already occupied
    if playerArmor[armorSlot] then
        print("[ARMOR DEBUG] Armor slot", armorSlot, "is already occupied by", playerArmor[armorSlot].itemName)
        -- Optionally, open the armor menu here to allow manual swapping
        self:Show()
        return
    end

    print("[ARMOR DEBUG] Armor slot", armorSlot, "is free. Proceeding with equip request.")
    -- The server request requires the full hotbarItem object, which includes the .object reference
    self:RequestArmorEquip(armorSlot, heldItem)

    print("[ARMOR DEBUG] --- TryEquipFromUse END ---")
end

-- Public methods for other systems
function ArmorSystem:GetEquippedArmor()
    return playerArmor
end

function ArmorSystem:IsArmorMenuVisible()
    return ArmorMenu and ArmorMenu:IsVisible()
end

-- Equip directly from a specific inventory slot (used by drag-drop)
function ArmorSystem:EquipFromInventorySlot(slotIndex, armorSlot)
    if not _G.InventorySystem then return end

    -- Equip the slot first (client + server)
    _G.InventorySystem:EquipSlotDirect(slotIndex)

    -- Now attempt normal equip flow
    self:TryEquipArmorFromHotbar(armorSlot)
end

function ArmorSystem:Use(itemDef, player, target)
	print("ArmorSystem: Use called for", itemDef.name)
	if target then
		print("ArmorSystem: Target is", target:GetFullName())
	else
		print("ArmorSystem: No target was hit.")
	end
end

return ArmorSystem 