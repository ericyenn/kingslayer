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
    
    -- Set up ConsumeItem handler
    RemoteEvents.ConsumeItemRequest.OnServerEvent:Connect(function(player, slot)
        local success, message = self:ConsumeItem(player, slot)
        -- Send response back to client
        RemoteEvents.ConsumeItemResponse:FireClient(player, success, message, slot)
    end)
    
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
    local originalCFrame = object:IsA("Model") and object.PrimaryPart and object.PrimaryPart.CFrame or object.CFrame
    local itemInfo = {
        object = object,
        itemName = object.Name,
        originalCFrame = originalCFrame,
        originalParent = object.Parent,
        icon = itemIcon
    }
    
    -- Add to player's inventory
    playerInventories[player][slot] = itemInfo
    
    -- Reset network ownership before moving to ReplicatedStorage
    -- This prevents issues with models that had network ownership set during dragging
    local success, error = pcall(function()
        if object:IsA("Model") then
            -- For models, reset network ownership on the primary part
            local mainPart = object.PrimaryPart or object:FindFirstChild("Torso") or object:FindFirstChild("HumanoidRootPart")
            if mainPart then
                mainPart:SetNetworkOwner(nil)
            end
        else
            -- For regular parts, reset network ownership directly
            object:SetNetworkOwner(nil)
        end
    end)
    
    if not success then
        warn("Failed to reset network ownership for", object.Name, ":", error)
    end
    
    -- Hide item from world (move to ReplicatedStorage for safekeeping)
    object.Parent = ReplicatedStorage
    
    -- Anchor the object (handle both parts and models)
    if object:IsA("Model") then
        -- For models, anchor all parts
        for _, part in ipairs(object:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = true
            end
        end
    else
        -- For parts, anchor directly
        object.Anchored = true
    end
    
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
    if object:IsA("Model") and object.PrimaryPart then
        object:SetPrimaryPartCFrame(dropPosition)
        -- Ensure all parts are unanchored
        for _, part in ipairs(object:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = false
            end
        end
    else
        object.CFrame = dropPosition
        object.Anchored = false
    end
    
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
    
    -- Get the position to check distance from
    local objectPosition
    if object:IsA("Model") and object.PrimaryPart then
        objectPosition = object.PrimaryPart.Position
    else
        objectPosition = object.Position
    end
    
    local distance = (character.HumanoidRootPart.Position - objectPosition).Magnitude
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
        if object:IsA("Model") and object.PrimaryPart then
            object:SetPrimaryPartCFrame(dropPosition)
            -- Ensure all parts are unanchored
            for _, part in ipairs(object:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = false
                end
            end
        else
            object.CFrame = dropPosition
            object.Anchored = false
        end
    else
        -- Fallback: drop at spawn location
        object.Parent = workspace
        if object:IsA("Model") and object.PrimaryPart then
            object:SetPrimaryPartCFrame(CFrame.new(0, 10, 0))
            -- Ensure all parts are unanchored
            for _, part in ipairs(object:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = false
                end
            end
        else
            object.CFrame = CFrame.new(0, 10, 0)
            object.Anchored = false
        end
    end
    
    -- WorldCleanupSystem removed - no longer needed
end

function InventoryServerSystem:GetPlayerInventory(player)
    return playerInventories[player] or {}
end

function InventoryServerSystem:GetPlayerEquippedSlot(player)
    return playerEquippedSlots[player]
end

-- Debug method to get player inventories
function InventoryServerSystem:GetPlayerInventories()
    return playerInventories
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
    -- Use default grip orientation for natural tool positioning
    tool.GripForward = Vector3.new(0, 1, 0)
    tool.GripRight = Vector3.new(1, 0, -1)
    tool.GripUp = Vector3.new(0, 0, -1)
    tool.GripPos = Vector3.new(0, 0, 0)

    local handle
    if originalObject:IsA("Model") then
        -- Clone the model
        local modelClone = originalObject:Clone()
        -- Find the part named 'Handle' inside the model
        handle = modelClone:FindFirstChild("Handle")
        if not handle or not handle:IsA("BasePart") then
            warn("Model does not contain a BasePart named 'Handle'")
            return
        end
        -- Parent the handle directly to the tool
        handle.Parent = tool
        -- Parent all other parts (that are welded) directly to the tool as well
        for _, obj in ipairs(modelClone:GetChildren()) do
            if obj ~= handle and obj:IsA("BasePart") then
                obj.Parent = tool
            end
        end
        -- Unanchor and set physics for all parts
        for _, part in ipairs(tool:GetChildren()) do
            if part:IsA("BasePart") then
                part.Anchored = false
                part.CanCollide = false
                part.TopSurface = Enum.SurfaceType.Smooth
                part.BottomSurface = Enum.SurfaceType.Smooth
                part.CollisionGroup = "Default"
            end
        end
    else
        -- Single-part item
        handle = originalObject:Clone()
        handle.Name = "Handle"
        handle.Anchored = false
        handle.CanCollide = false
        handle.TopSurface = Enum.SurfaceType.Smooth
        handle.BottomSurface = Enum.SurfaceType.Smooth
        handle.CollisionGroup = "Default"
        handle.Parent = tool
    end
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

-- Method to consume an item from inventory (for functional items)
function InventoryServerSystem:ConsumeItem(player, slot)
    -- Validate slot
    if slot < 1 or slot > 10 then
        return false, "Invalid slot number"
    end
    
    if not playerInventories[player] then
        return false, "Player inventory not found"
    end
    
    local inventoryItem = playerInventories[player][slot]
    if not inventoryItem then
        return false, "Slot is empty"
    end
    
    print("Server consuming item:", inventoryItem.itemName, "from slot", slot, "for player", player.Name)
    
    -- Remove tool from character if this slot is equipped
    if playerEquippedSlots[player] == slot then
        self:RemoveToolFromCharacter(player)
        playerEquippedSlots[player] = nil
    end
    
    -- Destroy the item object completely (it's consumed)
    if inventoryItem.object and inventoryItem.object.Parent then
        pcall(function()
            inventoryItem.object:Destroy()
        end)
    end
    
    -- Remove from inventory
    playerInventories[player][slot] = nil
    
    print("Successfully consumed item:", inventoryItem.itemName, "for player", player.Name)
    print("DEBUG: Server returning success=true, message='Item consumed'")
    return true, "Item consumed"
end

-- Method to drop all items when player dies (without full cleanup)
function InventoryServerSystem:DropAllItemsOnDeath(player)
    if not playerInventories[player] then
        return
    end
    
    print("Dropping all items for dead player:", player.Name)
    
    -- Remove any equipped tool first
    if playerEquippedSlots[player] then
        self:RemoveToolFromCharacter(player)
        playerEquippedSlots[player] = nil
    end
    
    -- Drop all inventory items to world
    for slot, inventoryItem in pairs(playerInventories[player]) do
        if inventoryItem and inventoryItem.object then
            pcall(function()
                self:DropItemToWorld(player, inventoryItem.object)
            end)
        end
    end
    
    -- Clear the inventory (but keep the player data structure)
    for i = 1, 10 do
        playerInventories[player][i] = nil
    end
    
    -- Notify client of inventory update
    RemoteEvents.UpdateInventory:FireClient(player, self:GetPlayerInventory(player))
    
    print("Successfully dropped all items for player:", player.Name)
end

-- REMOVED: Cleanup function - let Roblox handle object lifecycle

return InventoryServerSystem 