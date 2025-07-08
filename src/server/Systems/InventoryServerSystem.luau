-- Server-side inventory system (completely independent from DragServerSystem)
local InventoryServerSystem = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ECS = require(ReplicatedStorage.Shared.ECS)
local Constants = require(ReplicatedStorage.Shared.Constants)

-- Player inventory storage (server-side)
local playerInventories = {}
local playerEquippedSlots = {}

function InventoryServerSystem:Initialize()
    -- Initialize player inventories and equipped slots tracking
    Players.PlayerAdded:Connect(function(player)
        playerInventories[player] = {}
        playerEquippedSlots[player] = nil
        print("Initialized inventory for player:", player.Name)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayerInventory(player)
    end)
    
    -- Set up RemoteFunction connections
    RemoteEvents.InventoryRequest.OnServerInvoke = function(player, action, ...)
        return self:HandleInventoryRequest(player, action, ...)
    end
    
    -- SIMPLIFIED: No periodic cleanup needed
    
    print("Inventory server system initialized")
end

function InventoryServerSystem:InitializePlayerInventory(player)
    playerInventories[player] = {}
    playerEquippedSlots[player] = nil
    
    -- Initialize 10 empty slots
    for i = 1, 10 do
        playerInventories[player][i] = nil
    end
    
    print("Initialized inventory for player:", player.Name)
end

function InventoryServerSystem:CleanupPlayerInventory(player)
    -- Clean up all tools in character first
    if player.Character then
        for _, child in pairs(player.Character:GetChildren()) do
            if child:IsA("Tool") then
                pcall(function() child:Destroy() end)
            end
        end
    end
    
    -- Drop all inventory items to world
    if playerInventories[player] then
        for slot, inventoryItem in pairs(playerInventories[player]) do
            if inventoryItem then
                pcall(function()
                    self:DropItemToWorld(player, inventoryItem.object)
                end)
            end
        end
    end
    
    -- Clear player data
    playerInventories[player] = nil
    playerEquippedSlots[player] = nil
end

-- Cleanup method for system shutdown
function InventoryServerSystem:Cleanup()
    -- Clean up all players
    for player, _ in pairs(playerInventories) do
        pcall(function()
            self:CleanupPlayerInventory(player)
        end)
    end
    
    -- Clear tracking tables
    playerInventories = {}
    playerEquippedSlots = {}
end

function InventoryServerSystem:HandleInventoryRequest(player, action, ...)
    local args = {...}
    
    if action == "pickup_to_inventory" then
        local object, slot = args[1], args[2]
        return self:PickupToInventory(player, object, slot)
    elseif action == "drop_from_inventory" then
        local slot = args[1]
        return self:DropFromInventory(player, slot)
    elseif action == "equip_slot" then
        local slot = args[1]
        return self:EquipSlot(player, slot)
    elseif action == "swap_slots" then
        local slot1, slot2 = args[1], args[2]
        return self:SwapSlots(player, slot1, slot2)
    else
        warn("Unknown inventory action:", action)
        return false, "Unknown action"
    end
end

function InventoryServerSystem:PickupToInventory(player, object, slot)
    if not object or not object.Parent then
        return false, "Invalid object"
    end
    
    local isValidItem = self:IsValidItem(object)
    
    if not isValidItem then
        return false, "Object is not a valid item"
    end
    
    -- Check if player can pickup this item
    local canPlayerPickup = self:CanPlayerPickup(player, object)
    
    if not canPlayerPickup then
        return false, "Cannot pickup this item"
    end
    
    -- Check if slot is available
    local slotOccupied = playerInventories[player][slot] ~= nil
    
    if slotOccupied then
        return false, "Slot is occupied"
    end
    
    -- Store item information
    local itemIcon = self:GetItemIcon(object)
    local itemInfo = {
        object = object,
        itemName = object.Name,
        originalCFrame = object.CFrame,
        originalParent = object.Parent,
        icon = itemIcon
    }
    
    -- Add to player's inventory
    playerInventories[player][slot] = itemInfo
    
    -- Hide item from world (move to ReplicatedStorage for safekeeping)
    object.Parent = ReplicatedStorage
    object.Anchored = true
    
    -- WorldCleanupSystem removed - no longer needed
    
    return true, "Successfully picked up", itemIcon
end

function InventoryServerSystem:DropFromInventory(player, slot)
    local inventoryItem = playerInventories[player][slot]
    if not inventoryItem then
        return false, "Slot is empty"
    end
    
    local object = inventoryItem.object
    if not object or not object.Parent then
        return false, "Item object is invalid"
    end
    
    -- Calculate drop position (in front of player)
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return false, "Player character not found"
    end
    
    local humanoidRootPart = character.HumanoidRootPart
    local dropPosition = humanoidRootPart.CFrame * CFrame.new(0, 0, -5) -- 5 studs in front
    
    -- Remove tool from character if this slot is equipped
    if playerEquippedSlots[player] == slot then
        self:RemoveToolFromCharacter(player)
        playerEquippedSlots[player] = nil
    end
    
    -- Return item to world
    object.Parent = workspace
    object.CFrame = dropPosition
    object.Anchored = false
    
    -- Remove from inventory
    playerInventories[player][slot] = nil
    
    return true, "Successfully dropped"
end

function InventoryServerSystem:EquipSlot(player, slot)
    -- Handle unequip request (slot = nil means unequip)
    if slot == nil then
        -- Remove any currently equipped tool
        self:RemoveToolFromCharacter(player)
        playerEquippedSlots[player] = nil
        return true, "Unequipped - hands are empty"
    end
    
    -- If already equipped to this slot, don't do anything
    if playerEquippedSlots[player] == slot then
        return true, "Already equipped slot " .. slot
    end
    
    -- Remove any currently equipped tool first
    self:RemoveToolFromCharacter(player)
    
    -- Check if slot has an item
    if not playerInventories[player][slot] then
        -- Unequip if trying to equip empty slot
        playerEquippedSlots[player] = nil
        return true, "Unequipped"
    end
    
    -- Equip the slot
    playerEquippedSlots[player] = slot
    
    -- Create tool in character
    self:CreateToolInCharacter(player, slot)
    
    local equippedItem = playerInventories[player][slot]
    
    return true, "Equipped slot " .. slot .. " with " .. equippedItem.itemName
end

function InventoryServerSystem:IsValidItem(object)
    -- Check if object has required tag (components are client-side only)
    return CollectionService:HasTag(object, "DraggableItem")
end

function InventoryServerSystem:CanPlayerPickup(player, object)
    -- Check distance (anti-exploit)
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local distance = (character.HumanoidRootPart.Position - object.Position).Magnitude
    if distance > 15 then -- Same as drag detection distance
        return false
    end
    
    -- Server-side validation: all tagged items can be picked up
    -- Client-side will handle detailed component validation
    return true
end

function InventoryServerSystem:GetItemIcon(object)
    -- Get icon from item definition or use default
    if ECS:HasComponent(object, "Inventoryable") then
        local inventoryComponent = ECS:GetComponent(object, "Inventoryable")
        return inventoryComponent.inventoryIcon or object.Name:sub(1, 2):upper()
    end
    
    return object.Name:sub(1, 2):upper()
end

function InventoryServerSystem:DropItemToWorld(player, object)
    if not object or not object.Parent then return end
    
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local dropPosition = character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
        object.Parent = workspace
        object.CFrame = dropPosition
        object.Anchored = false
    else
        -- Fallback: drop at spawn location
        object.Parent = workspace
        object.CFrame = CFrame.new(0, 10, 0)
        object.Anchored = false
    end
    
    -- WorldCleanupSystem removed - no longer needed
end

function InventoryServerSystem:GetPlayerInventory(player)
    return playerInventories[player] or {}
end

function InventoryServerSystem:GetPlayerEquippedSlot(player)
    return playerEquippedSlots[player]
end

function InventoryServerSystem:CreateToolInCharacter(player, slot)
    local inventoryItem = playerInventories[player][slot]
    
    if not inventoryItem or not inventoryItem.object then
        warn("Cannot create tool: invalid inventory item in slot", slot)
        return
    end
    
    local character = player.Character
    if not character then
        warn("Cannot create tool: player has no character")
        return
    end
    
    -- Remove any existing tool first
    self:RemoveToolFromCharacter(player)
    
    local originalObject = inventoryItem.object
    
    -- Create Tool object
    local tool = Instance.new("Tool")
    tool.Name = originalObject.Name
    tool.RequiresHandle = true
    tool.CanBeDropped = false -- Prevent default Roblox dropping
    
    -- Set grip properties to control tool orientation
    tool.GripForward = Vector3.new(0, 1, 0)   -- Point upward
    tool.GripRight = Vector3.new(0, 0, -1)    -- Keep right vector
    tool.GripUp = Vector3.new(1, 0, 0)        -- What was forward is now up
    tool.GripPos = Vector3.new(0, 0, 0)       -- Grip position offset
    
    -- Clone the original object as Handle
    local handle = originalObject:Clone()
    handle.Name = "Handle"
    handle.Anchored = false
    
    -- Ensure handle has proper physics
    if handle:IsA("BasePart") then
        handle.CanCollide = false
        handle.TopSurface = Enum.SurfaceType.Smooth
        handle.BottomSurface = Enum.SurfaceType.Smooth
    end
    
    handle.Parent = tool
    
    -- Add tool interaction script
    self:AddToolScript(tool)
    
    -- Equip the tool
    tool.Parent = character
    
    -- Store reference for cleanup
    inventoryItem.activeTool = tool
end

function InventoryServerSystem:RemoveToolFromCharacter(player)
    -- Simple approach: remove all tools from character
    local character = player.Character
    if not character then return end
    
    -- Clear activeTool references first
    if playerInventories[player] then
        for slot, inventoryItem in pairs(playerInventories[player]) do
            if inventoryItem then
                inventoryItem.activeTool = nil
            end
        end
    end
    
    -- Remove all tools from character
    for _, child in pairs(character:GetChildren()) do
        if child:IsA("Tool") then
            pcall(function() child:Destroy() end)
        end
    end
end



function InventoryServerSystem:AddToolScript(tool)
    -- Clone the pre-made tool handler script
    local toolHandlerTemplate = ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("ToolHandler")
    
    if toolHandlerTemplate then
        local toolScript = toolHandlerTemplate:Clone()
        toolScript.Parent = tool
    else
        -- Fallback: just add a simple identifier
        local toolId = Instance.new("StringValue")
        toolId.Name = "ToolId"
        toolId.Value = tool.Name
        toolId.Parent = tool
        warn("Tool script template not found - tools may not function properly")
    end
end

function InventoryServerSystem:SwapSlots(player, slot1, slot2)
    -- Validate slots
    if slot1 < 1 or slot1 > 10 or slot2 < 1 or slot2 > 10 then
        return false, "Invalid slot numbers"
    end
    
    if not playerInventories[player] then
        return false, "Player inventory not found"
    end
    
    -- Get current items
    local item1 = playerInventories[player][slot1]
    local item2 = playerInventories[player][slot2]
    
    -- Perform the swap on server
    playerInventories[player][slot1] = item2
    playerInventories[player][slot2] = item1
    
    return true, "Slots swapped successfully"
end

-- Public helper: remove an inventory item by its instance (object)
function InventoryServerSystem:RemoveItemByObject(player, object)
    if not playerInventories[player] or not object then return end

    for slot, inventoryItem in pairs(playerInventories[player]) do
        if inventoryItem and inventoryItem.object == object then
            -- Clear equipped slot tracking if needed
            if playerEquippedSlots[player] == slot then
                playerEquippedSlots[player] = nil
            end

            -- Destroy any active Tool instance held by the character
            if inventoryItem.activeTool and inventoryItem.activeTool.Parent then
                inventoryItem.activeTool:Destroy()
                inventoryItem.activeTool = nil
            end

            playerInventories[player][slot] = nil
            break
        end
    end
end

-- Add an item directly into the first available slot (used by ArmorServerSystem when unequipping)
function InventoryServerSystem:AddItemToFirstEmptySlot(player, object)
    if not playerInventories[player] or not object then
        return false, "Invalid player or object"
    end

    -- Find first empty slot
    local emptySlot = nil
    for i = 1, 10 do
        if not playerInventories[player][i] then
            emptySlot = i
            break
        end
    end

    if not emptySlot then
        return false, "Inventory full"
    end

    -- Build inventory item structure (re-using GetItemIcon helper)
    local itemInfo = {
        object = object,
        itemName = object.Name,
        originalCFrame = object.CFrame,
        originalParent = object.Parent,
        icon = self:GetItemIcon(object)
    }

    playerInventories[player][emptySlot] = itemInfo

    -- Ensure object is stored safely (anchor + ReplicatedStorage)
    object.Parent = ReplicatedStorage
    object.Anchored = true

    return true, emptySlot
end

-- Remove item from specific slot
function InventoryServerSystem:RemoveItemBySlot(player, slot)
    if not playerInventories[player] or not playerInventories[player][slot] then
        return false
    end
    
    local inventoryItem = playerInventories[player][slot]
    
    -- Clear equipped slot tracking if needed
    if playerEquippedSlots[player] == slot then
        playerEquippedSlots[player] = nil
    end
    
    -- Destroy any active Tool instance held by the character
    if inventoryItem.activeTool and inventoryItem.activeTool.Parent then
        inventoryItem.activeTool:Destroy()
        inventoryItem.activeTool = nil
    end
    
    -- Clear the slot
    playerInventories[player][slot] = nil
    
    return true
end

-- REMOVED: Cleanup function - let Roblox handle object lifecycle

return InventoryServerSystem 