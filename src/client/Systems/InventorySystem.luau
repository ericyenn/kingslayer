-- Independent inventory system for handling item pickup/drop to inventory
local InventorySystem = {}

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local ECS = require(ReplicatedStorage.Shared.ECS)
local InventoryPredictor = require(ReplicatedStorage.Shared.InventoryPredictor)
local UIBatcher = require(ReplicatedStorage.Shared.UIBatcher)

local player = Players.LocalPlayer

-- Inventory state
local playerInventory = {}
local equippedSlot = nil

function InventorySystem:Initialize()
    -- Initialize global state for DragSystem communication (avoid circular dependency)
    _G.PlayerHasEquippedTool = false
    
    -- Set up global reference for ArmorSystem communication (minimal coupling)
    _G.InventorySystem = self
    
    -- Register with SystemManager for ArmorSystem access
    local SystemManager = require(ReplicatedStorage.Shared.SystemManager)
    SystemManager.RegisterSystem("InventorySystem", self)
    
    -- Set up consumption response handler
    RemoteEvents.ConsumeItemResponse.OnClientEvent:Connect(function(success, message, slot)
        self:HandleConsumeItemResponse(success, message, slot)
    end)
    
    -- Independent input connection (separate from DragSystem)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.E then
            self:HandleEKeyPress()
        elseif input.KeyCode == Enum.KeyCode.Q then
            self:HandleQKeyPress()
        else
            local slotNumber = self:GetSlotFromKeyCode(input.KeyCode)
            if slotNumber then
                self:HandleSlotSelection(slotNumber)
            end
        end
    end)
    
    -- Listen for inventory updates from server
    RemoteEvents.UpdateInventory.OnClientEvent:Connect(function(serverInventory)
        self:UpdateInventoryFromServer(serverInventory)
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
        print("DEBUG: Attempting to pickup object:", hoveredObject.Name)
        print("DEBUG: Object type:", hoveredObject.ClassName)
        print("DEBUG: Object parent:", hoveredObject.Parent and hoveredObject.Parent.Name or "nil")
        print("DEBUG: Is model:", hoveredObject:IsA("Model"))
        
        local canPickup = self:CanPickup(hoveredObject)
        print("DEBUG: Can pickup:", canPickup)
        
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
    local hoveredObject = DragSystem:GetHoveredObject()
    
    -- If we're hovering over a child part of a model, get the parent model instead
    if hoveredObject and hoveredObject.Parent then
        local CollectionService = game:GetService("CollectionService")
        local Constants = require(ReplicatedStorage.Shared.Constants)
        
        -- Check if the parent is a draggable model
        if CollectionService:HasTag(hoveredObject.Parent, Constants.TAGS.DRAGGABLE_ITEM) then
            print("DEBUG: Converting child part to parent model:", hoveredObject.Name, "->", hoveredObject.Parent.Name)
            return hoveredObject.Parent
        end
    end
    
    return hoveredObject
end

function InventorySystem:CanPickup(object)
    -- Check if object has Inventoryable component with canPickup = true
    local hasComponent = ECS:HasComponent(object, "Inventoryable")
    print("DEBUG: Has Inventoryable component:", hasComponent)
    
    if hasComponent then
        local inventoryableComponent = ECS:GetComponent(object, "Inventoryable")
        local canPickup = inventoryableComponent.canPickup == true
        print("DEBUG: Component canPickup:", canPickup)
        return canPickup
    end
    
    -- Fallback: Check if object has DraggableItem tag
    local CollectionService = game:GetService("CollectionService")
    local Constants = require(ReplicatedStorage.Shared.Constants)
    local hasTag = CollectionService:HasTag(object, Constants.TAGS.DRAGGABLE_ITEM)
    print("DEBUG: Has DraggableItem tag:", hasTag)
    
    if hasTag then
        print("DEBUG: Allowing pickup via tag fallback")
        return true
    end
    
    print("DEBUG: No valid pickup method found")
    return false
end

function InventorySystem:PickupToInventory(object)
    -- Find first empty slot
    local emptySlot = self:FindEmptySlot()
    
    if not emptySlot then
        warn("Inventory full!")
        return
    end
    
    -- PERFORMANCE OPTIMIZATION: Use client-side prediction for instant feedback
    local predictionId, predictionResult = InventoryPredictor.predict("pickup_to_inventory", object, emptySlot)
    
    if predictionId then
        -- Apply prediction immediately
        local itemId = self:GetItemIdFromObject(object)
        local inventoryItem = {
            object = object,
            itemName = object.Name,
            itemId = itemId,
            icon = self:GetItemIcon(itemId), -- Temporary icon
            predicted = true,
            predictionId = predictionId
        }
        
        -- Store item in local inventory immediately
        playerInventory[emptySlot] = inventoryItem
        
        -- Update UI immediately
        self:UpdateHotbarUI()
        
        -- Update global state
        _G.PlayerHasEquippedTool = self:HasEquippedTool()
        
        print("Predicted pickup:", object.Name, "in slot", emptySlot)
    end
    
    -- Send async request to server (no blocking)
    task.spawn(function()
        local success, result, message, icon = pcall(function()
            return RemoteEvents.InventoryRequest:InvokeServer("pickup_to_inventory", object, emptySlot)
        end)
        
        if not success then
            warn("InventoryRequest call failed:", result)
            if predictionId then
                InventoryPredictor.rollback(predictionId, "Network error")
                self:UpdateHotbarUI()
            end
            return
        end
        
        local serverSuccess, serverMessage, serverIcon = result, message, icon
        
        if serverSuccess then
            -- Confirm prediction
            if predictionId then
                InventoryPredictor.confirm(predictionId)
                
                -- Update with server data
                if playerInventory[emptySlot] and playerInventory[emptySlot].predictionId == predictionId then
                    playerInventory[emptySlot].icon = serverIcon
                    playerInventory[emptySlot].predicted = nil
                    playerInventory[emptySlot].predictionId = nil
                    self:UpdateHotbarUI()
                end
            end
            
            print("Server confirmed pickup:", object.Name, "in slot", emptySlot)
        else
            -- Server rejected, rollback prediction
            if predictionId then
                InventoryPredictor.rollback(predictionId, serverMessage)
                playerInventory[emptySlot] = nil
                self:UpdateHotbarUI()
                _G.PlayerHasEquippedTool = self:HasEquippedTool()
            end
            warn("Server rejected pickup:", serverMessage)
        end
    end)
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
    -- PERFORMANCE OPTIMIZATION: Batch UI updates to prevent frame drops
    UIBatcher.queueHotbarUpdate(function()
        local Hotbar = require(script.Parent.Parent.UI.Hotbar)
        Hotbar:UpdateDisplay(playerInventory, equippedSlot)
    end, 2) -- Medium priority
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
    -- Simplified logging
    
    -- Get currently equipped item for armor system integration
    if equippedSlot and playerInventory[equippedSlot] then
        local inventoryItem = playerInventory[equippedSlot]
        
        -- Use stored itemId if available, otherwise generate from object
        local itemId = inventoryItem.itemId or self:GetItemIdFromObject(inventoryItem.object)
        
        local result = {
            itemName = inventoryItem.itemName,
            itemId = itemId,
            object = inventoryItem.object,
            slot = equippedSlot
        }
        
        return result
    else
        return nil
    end
end

function InventorySystem:GetItemIdFromObject(object)
    -- Helper function to get item ID from object name
    -- Convert object name to itemId format (lowercase with underscores)
    local itemId = string.lower(object.Name)
    itemId = string.gsub(itemId, " ", "_")  -- Replace spaces with underscores
    return itemId
end

function InventorySystem:HandleArmorEquipped()
    -- Called by ArmorSystem when armor is equipped from hotbar
    if equippedSlot and playerInventory[equippedSlot] then
        -- Remove equipped item from hotbar inventory
        playerInventory[equippedSlot] = nil
        equippedSlot = nil
        
        -- Update hotbar UI
        self:UpdateHotbarUI()
        
        -- Update global state
        _G.PlayerHasEquippedTool = self:HasEquippedTool()
    end
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
        itemId = armorItem.itemId,  -- Include itemId for proper item identification
        icon = self:GetItemIcon(armorItem.itemId)
    }
    
    print("[INVENTORY DEBUG] Created inventory item for slot:", inventoryItem)
    
    playerInventory[targetSlot] = inventoryItem
    print("[INVENTORY DEBUG] Added armor to hotbar slot", targetSlot)
    
    -- Leave player hands empty; unequip on both client and server
    equippedSlot = nil
    print("[INVENTORY DEBUG] Returned armor stored, hands left empty")

    -- Notify server to clear equipped slot (hands empty)
    pcall(function()
        RemoteEvents.InventoryRequest:InvokeServer("equip_slot", nil)
    end)
    
    -- Update hotbar UI
    self:UpdateHotbarUI()
    print("[INVENTORY DEBUG] Hotbar UI updated")
    
    -- Update global state
    _G.PlayerHasEquippedTool = self:HasEquippedTool()
    print("[INVENTORY DEBUG] Global state updated - HasEquippedTool:", _G.PlayerHasEquippedTool)
    
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
    -- Get current items
    local item1 = playerInventory[slot1]
    local item2 = playerInventory[slot2]
    
    -- Perform the swap
    playerInventory[slot1] = item2
    playerInventory[slot2] = item1
    
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

function InventorySystem:EquipSlotDirect(slot)
    -- Request equip slot to server
    local success, result, message = pcall(function()
        return RemoteEvents.InventoryRequest:InvokeServer("equip_slot", slot)
    end)

    if success and result then
        self:EquipSlot(slot)
        return true
    else
        warn("EquipSlotDirect failed:", message)
        return false
    end
end

-- Method called by ArmorSystem to get currently equipped item
function InventorySystem:GetEquippedItem()
    if equippedSlot and playerInventory[equippedSlot] then
        return playerInventory[equippedSlot]
    end
    return nil
end

-- Method called by ArmorSystem when armor is equipped (remove from hotbar)
function InventorySystem:HandleArmorEquipped()
    if equippedSlot and playerInventory[equippedSlot] then
        -- Clear the equipped slot since item was moved to armor
        playerInventory[equippedSlot] = nil
        equippedSlot = nil
        
        -- Update hotbar UI
        self:UpdateHotbarUI()
        
        -- Update global state
        _G.PlayerHasEquippedTool = self:HasEquippedTool()
        
        return true
    end
    return false
end

-- Update inventory from server data (used after trades)
function InventorySystem:UpdateInventoryFromServer(serverInventory)
    print("Updating inventory from server data")
    
    -- Clear current inventory
    for i = 1, 10 do
        playerInventory[i] = nil
    end
    
    -- Update with server data
    for slot, inventoryItem in pairs(serverInventory) do
        if inventoryItem then
            -- Get itemId from object name if not provided
            local itemId = inventoryItem.itemId or self:GetItemIdFromObject(inventoryItem.object or {Name = inventoryItem.itemName})
            
            playerInventory[slot] = {
                itemName = inventoryItem.itemName,
                itemId = itemId,  -- Include itemId
                icon = inventoryItem.icon,
                object = inventoryItem.object  -- Include object if available
            }
        end
    end
    
    -- Clear equipped slot since items were removed
    equippedSlot = nil
    
    -- Update the hotbar UI
    self:UpdateHotbarUI()
    
    -- Update global state
    _G.PlayerHasEquippedTool = self:HasEquippedTool()
    
    print("Inventory updated from server")
end

-- Handle consumption response from server
function InventorySystem:HandleConsumeItemResponse(success, message, slot)
    print("DEBUG: Received consumption response - success:", success, "message:", message, "slot:", slot)
    
    if success then
        print("DEBUG: Server confirmed consumption, updating client state for slot", slot)
        
        local consumedItem = playerInventory[slot]
        local itemName = consumedItem and consumedItem.itemName or "Unknown Item"
        
        -- Remove from local inventory
        playerInventory[slot] = nil
        print("DEBUG: Cleared inventory slot", slot)
        
        -- Clear equipped slot if this was the equipped item
        if equippedSlot == slot then
            equippedSlot = nil
            print("DEBUG: Cleared equipped slot")
        end
        
        -- Update hotbar UI
        self:UpdateHotbarUI()
        print("DEBUG: Updated hotbar UI")
        
        -- Update global state
        _G.PlayerHasEquippedTool = self:HasEquippedTool()
        print("DEBUG: Updated global state")
        
        print("Successfully consumed item:", itemName)
    else
        warn("Server rejected item consumption:", message)
    end
end

-- Method to consume the currently equipped item (for functional items)
function InventorySystem:ConsumeEquippedItem()
    if not equippedSlot or not playerInventory[equippedSlot] then
        warn("No equipped item to consume")
        return false
    end
    
    local consumedItem = playerInventory[equippedSlot]
    print("Consuming equipped item:", consumedItem.itemName, "from slot", equippedSlot)
    
    -- Send consumption request to server (fire and forget)
    print("DEBUG: Sending ConsumeItemRequest to server for slot", equippedSlot)
    RemoteEvents.ConsumeItemRequest:FireServer(equippedSlot)
    
    -- The response will be handled by HandleConsumeItemResponse
    print("DEBUG: Consumption request sent, waiting for server response")
    return true -- Always return true since we're using async communication
end

return InventorySystem 