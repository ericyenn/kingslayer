-- Armor system for handling armor equipment independently
local ArmorSystem = {}

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local Categories = require(ReplicatedStorage.Shared.ItemCategory)
local SystemManager = require(ReplicatedStorage.Shared.SystemManager)

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
    -- Register with SystemManager instead of global
    SystemManager.RegisterSystem("ArmorSystem", self)
    
    -- Set up global reference for other systems (like Hotbar)
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
    local currentArmor = playerArmor[armorSlot]
    
    if currentArmor then
        -- Unequip armor (move back to hotbar)
        self:UnequipArmor(armorSlot)
    else
        -- Try to equip armor from hotbar
        self:TryEquipArmorFromHotbar(armorSlot)
    end
end

function ArmorSystem:TryEquipArmorFromHotbar(armorSlot)
    -- Check if player has compatible armor equipped in hotbar
    local equippedItem = self:GetEquippedHotbarItem()
    
    if not equippedItem then
        -- Nothing equipped – cannot proceed
        return
    end
    
    -- Check if equipped item is armor of the right type
    local itemDef = ItemDefinitions:GetItem(equippedItem.itemId)
    
    if not itemDef then
        warn("No item definition found for ID:", equippedItem.itemId)
        return
    end
    
    if itemDef.category ~= Categories.Armor then
        return
    end
    
    if itemDef.armorSlot ~= armorSlot then
        return
    end
    
    -- Request armor equip from server
    self:RequestArmorEquip(armorSlot, equippedItem)
end

function ArmorSystem:UnequipArmor(armorSlot)
    -- Request armor unequip from server
    self:RequestArmorUnequip(armorSlot)
end

function ArmorSystem:RequestArmorEquip(armorSlot, hotbarItem)
    local success, result, message = pcall(function()
        return RemoteEvents.ArmorRequest:InvokeServer("equip_armor", armorSlot, hotbarItem)
    end)
    
    if not success then
        warn("ArmorRequest call failed:", result)
        return
    end
    
    local serverSuccess, serverMessage = result, message
    
    if serverSuccess then
        -- Update local armor state
        playerArmor[armorSlot] = {
            itemName = hotbarItem.itemName,
            itemId = hotbarItem.itemId,
            object = hotbarItem.object
        }
        
        -- Update armor menu display
        ArmorMenu:UpdateDisplay(playerArmor)
        
        -- Notify inventory system to update hotbar (remove equipped item)
        self:NotifyInventorySystemArmorEquipped()
    else
        warn("Failed to equip armor:", serverMessage)
    end
end

function ArmorSystem:RequestArmorUnequip(armorSlot)
    local success, result, message = pcall(function()
        return RemoteEvents.ArmorRequest:InvokeServer("unequip_armor", armorSlot)
    end)
    
    if not success then
        warn("ArmorRequest call failed:", result)
        return
    end
    
    local serverSuccess, serverMessage = result, message
    
    if serverSuccess then
        -- Clear local armor state
        local unequippedArmor = playerArmor[armorSlot]
        playerArmor[armorSlot] = nil
        
        -- Update armor menu display
        ArmorMenu:UpdateDisplay(playerArmor)
        
        -- Notify inventory system to update hotbar (add back to hotbar)
        self:NotifyInventorySystemArmorUnequipped(unequippedArmor)
    else
        warn("Failed to unequip armor:", serverMessage)
    end
end

function ArmorSystem:GetEquippedHotbarItem()
    -- Get currently equipped item from inventory system through SystemManager
    return SystemManager.CallSystem("InventorySystem", "GetEquippedItem")
end

function ArmorSystem:NotifyInventorySystemArmorEquipped()
    -- Notify inventory system that armor was equipped (remove from hotbar)
    SystemManager.CallSystem("InventorySystem", "HandleArmorEquipped")
end

function ArmorSystem:NotifyInventorySystemArmorUnequipped(armorItem)
    -- Notify inventory system that armor was unequipped (add back to hotbar)
    SystemManager.CallSystem("InventorySystem", "HandleArmorUnequipped", armorItem)
end

function ArmorSystem:TryEquipFromUse(heldItem)
    if not heldItem or not heldItem.itemId then
        return
    end

    local itemDef = ItemDefinitions:GetItem(heldItem.itemId)
    if not itemDef or itemDef.category ~= Categories.Armor or not itemDef.armorSlot then
        return
    end

    local armorSlot = itemDef.armorSlot

    -- Check if the target armor slot is already occupied
    if playerArmor[armorSlot] then
        -- Optionally, open the armor menu here to allow manual swapping
        self:Show()
        return
    end
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
    -- Equip the slot first (client + server)
    local success = SystemManager.CallSystem("InventorySystem", "EquipSlotDirect", slotIndex)
    if not success then 
        print("[ARMOR DEBUG] Failed to equip slot through InventorySystem")
        return 
    end

    -- Now attempt normal equip flow
    self:TryEquipArmorFromHotbar(armorSlot)
end

-- Armor has no click functionality - all interaction is through equip system
function ArmorSystem:Use(itemDef, player, target)
    print("ArmorSystem: Armor has no click functionality")
    print("  - Use G key to open armor menu and equip", itemDef.name)
    print("  - Armor provides health when equipped")
end

return ArmorSystem 