-- Independent inventory system for handling item pickup/drop to inventory
local InventorySystem = {}

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local ECS = require(ReplicatedStorage.Shared.ECS)

local player = Players.LocalPlayer

-- Inventory state
local playerInventory = {}
local equippedSlot = nil

function InventorySystem:Initialize()
    -- Initialize global state for DragSystem communication (avoid circular dependency)
    _G.PlayerHasEquippedTool = false
    
    -- Set up global reference for ArmorSystem communication (minimal coupling)
    _G.InventorySystem = self
    
    -- Independent input connection (separate from DragSystem)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.E then
            self:HandleEKeyPress()
        elseif input.KeyCode == Enum.KeyCode.Q then
            self:HandleQKeyPress()
        else
            -- Handle number key slot selection
            local slotNumber = self:GetSlotFromKeyCode(input.KeyCode)
            if slotNumber then
                self:HandleSlotSelection(slotNumber)
            end
        end
    end)
    
    -- Initialize empty inventory (10 slots)
    for i = 1, 10 do
        playerInventory[i] = nil
    end
    
    print("Inventory system initialized")
end

function InventorySystem:HandleEKeyPress()
    -- Get what player is hovering (reuse HoverSystem's detection)
    local hoveredObject = self:GetCurrentHoveredObject()
    
    if hoveredObject then
        local canPickup = self:CanPickup(hoveredObject)
        
        if canPickup then
            print("Attempting to pickup to inventory:", hoveredObject.Name)
            self:PickupToInventory(hoveredObject)
        else
            print("Object cannot be picked up:", hoveredObject.Name)
        end
    else
        print("No object being hovered")
    end
end

function InventorySystem:HandleQKeyPress()
    -- Drop currently equipped item
    if equippedSlot and playerInventory[equippedSlot] then
        print("Attempting to drop from inventory slot:", equippedSlot)
        self:DropFromInventory(equippedSlot)
    else
        print("No item equipped to drop")
    end
end

function InventorySystem:GetCurrentHoveredObject()
    -- Access the DragSystem's hovered object (minimal coupling)
    local DragSystem = require(script.Parent.DragSystem)
    return DragSystem:GetHoveredObject()
end

function InventorySystem:CanPickup(object)
    -- Check if object has Inventoryable component with canPickup = true
    local hasComponent = ECS:HasComponent(object, "Inventoryable")
    
    if not hasComponent then 
        return false 
    end
    
    local inventoryableComponent = ECS:GetComponent(object, "Inventoryable")
    return inventoryableComponent.canPickup == true
end

function InventorySystem:PickupToInventory(object)
    -- Find first empty slot
    local emptySlot = self:FindEmptySlot()
    
    if not emptySlot then
        warn("Inventory full!")
        return
    end
    
    -- Request pickup from server
    local success, result, message, icon = pcall(function()
        return RemoteEvents.InventoryRequest:InvokeServer("pickup_to_inventory", object, emptySlot)
    end)
    
    if not success then
        warn("InventoryRequest call failed:", result)
        return
    end
    
    local serverSuccess, serverMessage, serverIcon = result, message, icon
    
    if serverSuccess then
        -- Add to local inventory
        local inventoryItem = {
            object = object,
            itemName = object.Name,
            icon = serverIcon -- Use icon from server response
        }
        
        -- Store item in local inventory
        playerInventory[emptySlot] = inventoryItem
        
        -- Update hotbar UI (no auto-equipping)
        self:UpdateHotbarUI()
        
        -- Update global state for DragSystem (avoid circular dependency)
        _G.PlayerHasEquippedTool = self:HasEquippedTool()
        
        print("Successfully picked up to inventory:", object.Name, "in slot", emptySlot)
    else
        warn("Failed to pickup to inventory:", serverMessage)
    end
end

function InventorySystem:DropFromInventory(slot)
    local inventoryItem = playerInventory[slot]
    if not inventoryItem then return end
    
    -- Request drop from server
    local success, result, message = pcall(function()
        return RemoteEvents.InventoryRequest:InvokeServer("drop_from_inventory", slot)
    end)
    
    if not success then
        warn("InventoryRequest call failed:", result)
    else
        local serverSuccess, serverMessage = result, message
        
        if serverSuccess then
            -- Remove from local inventory
            playerInventory[slot] = nil
            
            -- Unequip if this was equipped
            if equippedSlot == slot then
                equippedSlot = nil
            end
            
            -- Update hotbar UI
            self:UpdateHotbarUI()
            
            -- Update global state for DragSystem (avoid circular dependency)
            _G.PlayerHasEquippedTool = self:HasEquippedTool()
            
            print("Successfully dropped from inventory slot:", slot)
        else
            warn("Failed to drop from inventory:", serverMessage)
        end
    end
end

function InventorySystem:FindEmptySlot()
    for i = 1, 10 do
        if not playerInventory[i] then
            return i
        end
    end
    return nil
end

function InventorySystem:EquipSlot(slot)
    if playerInventory[slot] then
        equippedSlot = slot
        self:UpdateHotbarUI()
        print("Equipped slot:", slot)
    else
        -- Unequip if trying to equip empty slot
        equippedSlot = nil
        self:UpdateHotbarUI()
    end
    
    -- Update global state for DragSystem (avoid circular dependency)
    _G.PlayerHasEquippedTool = self:HasEquippedTool()
end

function InventorySystem:UpdateHotbarUI()
    local Hotbar = require(script.Parent.Parent.UI.Hotbar)
    Hotbar:UpdateDisplay(playerInventory, equippedSlot)
end

function InventorySystem:GetInventory()
    return playerInventory
end

function InventorySystem:GetEquippedSlot()
    return equippedSlot
end

function InventorySystem:HasEquippedTool()
    return equippedSlot ~= nil and playerInventory[equippedSlot] ~= nil
end

function InventorySystem:GetEquippedToolName()
    if self:HasEquippedTool() then
        return playerInventory[equippedSlot].itemName
    end
    return nil
end

function InventorySystem:GetSlotFromKeyCode(keyCode)
    -- Map key codes to slot numbers
    if keyCode == Enum.KeyCode.One then return 1
    elseif keyCode == Enum.KeyCode.Two then return 2
    elseif keyCode == Enum.KeyCode.Three then return 3
    elseif keyCode == Enum.KeyCode.Four then return 4
    elseif keyCode == Enum.KeyCode.Five then return 5
    elseif keyCode == Enum.KeyCode.Six then return 6
    elseif keyCode == Enum.KeyCode.Seven then return 7
    elseif keyCode == Enum.KeyCode.Eight then return 8
    elseif keyCode == Enum.KeyCode.Nine then return 9
    elseif keyCode == Enum.KeyCode.Zero then return 10
    end
    return nil
end

function InventorySystem:HandleSlotSelection(slotNumber)
    print("=== SLOT SELECTION DEBUG START ===")
    print("User pressed key for slot:", slotNumber)
    print("Current equipped slot:", equippedSlot)
    print("Item in requested slot:", playerInventory[slotNumber] and playerInventory[slotNumber].itemName or "EMPTY")
    
    -- If pressing the same slot number that's already equipped, unequip (empty hands)
    local targetSlot = slotNumber
    if equippedSlot == slotNumber then
        targetSlot = nil -- Unequip by sending nil
        print("SLOT SELECTION: Same slot pressed, will unequip")
    else
        print("SLOT SELECTION: Different slot pressed, will equip slot", slotNumber)
    end
    
    -- Request slot equip from server
    print("SLOT SELECTION: Sending equip request to server for slot:", targetSlot)
    local success, result, message = pcall(function()
        return RemoteEvents.InventoryRequest:InvokeServer("equip_slot", targetSlot)
    end)
    
    if not success then
        warn("SLOT SELECTION ERROR: InventoryRequest call failed:", result)
        return
    end
    
    local serverSuccess, serverMessage = result, message
    print("SLOT SELECTION: Server response - Success:", serverSuccess, "Message:", serverMessage)
    
    if serverSuccess then
        -- Update local equipped slot
        if targetSlot == nil then
            equippedSlot = nil
            print("SLOT SELECTION: Unequipped - hands are now empty")
        else
            self:EquipSlot(slotNumber)
            print("SLOT SELECTION: Successfully equipped slot:", slotNumber)
        end
        
        -- Update hotbar UI
        self:UpdateHotbarUI()
        
        -- Update global state for DragSystem (avoid circular dependency)
        _G.PlayerHasEquippedTool = self:HasEquippedTool()
    else
        warn("SLOT SELECTION: Failed to equip slot:", serverMessage)
    end
    
    print("=== SLOT SELECTION DEBUG END ===")
end

function InventorySystem:GetEquippedItem()
    print("[INVENTORY DEBUG] --- GetEquippedItem START ---")
    print("[INVENTORY DEBUG] Current equipped slot:", equippedSlot)
    print("[INVENTORY DEBUG] Player inventory state:")
    for i = 1, 10 do
        local item = playerInventory[i]
        print("[INVENTORY DEBUG]   Slot", i, ":", item and item.itemName or "EMPTY")
    end
    
    -- Get currently equipped item for armor system integration
    if equippedSlot and playerInventory[equippedSlot] then
        local inventoryItem = playerInventory[equippedSlot]
        print("[INVENTORY DEBUG] Found equipped item:", inventoryItem.itemName)
        print("[INVENTORY DEBUG] Item object:", inventoryItem.object)
        
        local itemId = self:GetItemIdFromObject(inventoryItem.object)
        print("[INVENTORY DEBUG] Calculated item ID:", itemId)
        
        local result = {
            itemName = inventoryItem.itemName,
            itemId = itemId,
            object = inventoryItem.object,
            slot = equippedSlot
        }
        
        print("[INVENTORY DEBUG] Returning equipped item result:", result)
        print("[INVENTORY DEBUG] --- GetEquippedItem END ---")
        return result
    else
        print("[INVENTORY DEBUG] No equipped item found")
        print("[INVENTORY DEBUG] --- GetEquippedItem END ---")
        return nil
    end
end

function InventorySystem:GetItemIdFromObject(object)
    -- Helper function to get item ID from object name
    -- This assumes object name matches item definition key
    return string.lower(object.Name)
end

function InventorySystem:HandleArmorEquipped()
    print("[INVENTORY DEBUG] --- HandleArmorEquipped START ---")
    print("[INVENTORY DEBUG] Called by ArmorSystem - armor was equipped from hotbar")
    print("[INVENTORY DEBUG] Current equipped slot before removal:", equippedSlot)
    
    -- Called by ArmorSystem when armor is equipped from hotbar
    if equippedSlot and playerInventory[equippedSlot] then
        local removedItem = playerInventory[equippedSlot]
        print("[INVENTORY DEBUG] Removing item from hotbar:", removedItem.itemName, "in slot", equippedSlot)
        
        -- Remove equipped item from hotbar inventory
        playerInventory[equippedSlot] = nil
        equippedSlot = nil
        
        print("[INVENTORY DEBUG] Item removed, equipped slot cleared")
        
        -- Update hotbar UI
        self:UpdateHotbarUI()
        print("[INVENTORY DEBUG] Hotbar UI updated")
        
        -- Update global state
        _G.PlayerHasEquippedTool = self:HasEquippedTool()
        print("[INVENTORY DEBUG] Global state updated - HasEquippedTool:", _G.PlayerHasEquippedTool)
        
        print("[INVENTORY DEBUG] SUCCESS: Hotbar item moved to armor slot")
    else
        print("[INVENTORY DEBUG] WARNING: No equipped item to remove from hotbar")
    end
    
    print("[INVENTORY DEBUG] --- HandleArmorEquipped END ---")
end

function InventorySystem:HandleArmorUnequipped(armorItem)
    print("[INVENTORY DEBUG] --- HandleArmorUnequipped START ---")
    print("[INVENTORY DEBUG] Called by ArmorSystem - armor was unequipped back to hotbar")
    print("[INVENTORY DEBUG] Armor item to restore:", armorItem and armorItem.itemName or "UNKNOWN")
    
    -- Called by ArmorSystem when armor is unequipped back to hotbar
    -- Find empty slot or replace equipped slot
    local targetSlot = self:FindEmptySlot()
    print("[INVENTORY DEBUG] Looking for empty slot, found:", targetSlot)
    
    if not targetSlot then
        -- If no empty slot, replace currently equipped slot
        targetSlot = equippedSlot or 1
        print("[INVENTORY DEBUG] No empty slot, using equipped slot or slot 1:", targetSlot)
    end
    
    print("[INVENTORY DEBUG] Target slot for armor return:", targetSlot)
    
    -- Add armor back to hotbar inventory
    local inventoryItem = {
        object = armorItem.object,
        itemName = armorItem.itemName,
        icon = self:GetItemIcon(armorItem.itemId)
    }
    
    print("[INVENTORY DEBUG] Created inventory item for slot:", inventoryItem)
    
    playerInventory[targetSlot] = inventoryItem
    print("[INVENTORY DEBUG] Added armor to hotbar slot", targetSlot)
    
    -- Auto-equip the returned armor
    equippedSlot = targetSlot
    print("[INVENTORY DEBUG] Auto-equipped returned armor in slot:", targetSlot)
    
    -- Update hotbar UI
    self:UpdateHotbarUI()
    print("[INVENTORY DEBUG] Hotbar UI updated")
    
    -- Update global state
    _G.PlayerHasEquippedTool = self:HasEquippedTool()
    print("[INVENTORY DEBUG] Global state updated - HasEquippedTool:", _G.PlayerHasEquippedTool)
    
    print("[INVENTORY DEBUG] SUCCESS: Armor item returned to hotbar slot:", targetSlot)
    print("[INVENTORY DEBUG] --- HandleArmorUnequipped END ---")
end

function InventorySystem:GetItemIcon(itemId)
    -- Helper function to get item icon for display
    local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
    local itemDef = ItemDefinitions:GetItem(itemId)
    
    if itemDef and itemDef.components and itemDef.components.Inventoryable then
        return itemDef.components.Inventoryable.inventoryIcon
    end
    
    return "❓" -- Default unknown icon
end

function InventorySystem:SwapSlots(slot1, slot2)
    -- Swap items between two slots while preserving equipped item
    print("=== SLOT SWAP DEBUG START ===")
    print("Swapping slots", slot1, "and", slot2)
    
    -- Debug: Log current state before swap
    print("BEFORE SWAP:")
    print("  - Slot", slot1, "contains:", playerInventory[slot1] and playerInventory[slot1].itemName or "EMPTY")
    print("  - Slot", slot2, "contains:", playerInventory[slot2] and playerInventory[slot2].itemName or "EMPTY")
    print("  - Currently equipped slot:", equippedSlot)
    print("  - Equipped item:", equippedSlot and playerInventory[equippedSlot] and playerInventory[equippedSlot].itemName or "NONE")
    
    -- Get current items
    local item1 = playerInventory[slot1]
    local item2 = playerInventory[slot2]
    
    -- Perform the swap
    playerInventory[slot1] = item2
    playerInventory[slot2] = item1
    
    -- Debug: Log state after local swap
    print("AFTER LOCAL SWAP:")
    print("  - Slot", slot1, "now contains:", playerInventory[slot1] and playerInventory[slot1].itemName or "EMPTY")
    print("  - Slot", slot2, "now contains:", playerInventory[slot2] and playerInventory[slot2].itemName or "EMPTY")
    
    -- CRITICAL: Preserve equipped item by updating equippedSlot if needed
    local originalEquippedSlot = equippedSlot
    local needsServerSync = false
    
    if equippedSlot == slot1 then
        -- The equipped item moved from slot1 to slot2
        equippedSlot = slot2
        needsServerSync = true
        print("EQUIPPED ITEM TRACKING: Equipped item moved from slot", slot1, "to slot", slot2)
    elseif equippedSlot == slot2 then
        -- The equipped item moved from slot2 to slot1
        equippedSlot = slot1
        needsServerSync = true
        print("EQUIPPED ITEM TRACKING: Equipped item moved from slot", slot2, "to slot", slot1)
    else
        print("EQUIPPED ITEM TRACKING: Equipped slot", equippedSlot, "not affected by swap")
    end
    
    -- Debug: Log final local state
    print("FINAL LOCAL STATE:")
    print("  - New equipped slot:", equippedSlot)
    print("  - Item in new equipped slot:", equippedSlot and playerInventory[equippedSlot] and playerInventory[equippedSlot].itemName or "NONE")
    
    -- CRITICAL FIX: Notify server about the slot swap so server inventory stays in sync
    print("SERVER SYNC: Notifying server about slot swap:", slot1, "↔", slot2)
    local swapSuccess, swapResult, swapMessage = pcall(function()
        return RemoteEvents.InventoryRequest:InvokeServer("swap_slots", slot1, slot2)
    end)
    
    if not swapSuccess then
        warn("SERVER SYNC ERROR: Failed to sync slot swap with server:", swapResult)
    else
        local serverSwapSuccess, serverSwapMessage = swapResult, swapMessage
        if not serverSwapSuccess then
            warn("SERVER SYNC REJECTED: Server rejected slot swap:", serverSwapMessage)
        else
            print("SERVER SYNC SUCCESS: Server confirmed slot swap")
        end
    end
    
    -- Notify server about the equipped slot change (if equipped item moved)
    if needsServerSync then
        print("SERVER SYNC: Notifying server of equipped slot change to", equippedSlot)
        local success, result, message = pcall(function()
            return RemoteEvents.InventoryRequest:InvokeServer("equip_slot", equippedSlot)
        end)
        
        if not success then
            warn("SERVER SYNC ERROR: Failed to sync equipped slot with server:", result)
        else
            local serverSuccess, serverMessage = result, message
            if not serverSuccess then
                warn("SERVER SYNC REJECTED:", serverMessage)
            else
                print("SERVER SYNC SUCCESS: Server confirmed equipped slot:", equippedSlot)
            end
        end
    else
        print("SERVER SYNC: No equipped slot sync needed (equipped item not moved)")
    end
    
    -- Update hotbar UI to reflect the swap
    self:UpdateHotbarUI()
    
    -- Update global state for DragSystem
    _G.PlayerHasEquippedTool = self:HasEquippedTool()
    
    print("=== SLOT SWAP DEBUG END ===")
    print("Final result - equipped slot:", equippedSlot)
end

return InventorySystem 