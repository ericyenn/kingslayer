-- This script runs on the client and is attached to each tool when equipped.
-- It handles the "use" action (left-click) and dispatches to the correct system based on category.

local Tool = script.Parent
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Shared Modules
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local Categories = require(ReplicatedStorage.Shared.ItemCategory)

-- Client Systems
local ClientSystems = ReplicatedStorage.Parent.client.Systems
local ToolSystem = require(ClientSystems.ToolSystem)
local ArmorSystem = require(ClientSystems.ArmorSystem)
local FunctionalSystem = require(ClientSystems.FunctionalSystem)

local player = Players.LocalPlayer

-- Debounce to prevent spamming the use action
local debounce = false
local DEBOUNCE_TIME = 0.5 -- 500ms

local function onUse()
    if debounce then return end
    debounce = true
    task.delay(DEBOUNCE_TIME, function() debounce = false end)

    local character = player.Character
    if not character then return end

    local human = character:FindFirstChildOfClass("Humanoid")
    if not human or human.Health <= 0 then return end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end

    local equippedTool = player.Backpack:FindFirstChildOfClass("Tool") or character:FindFirstChildOfClass("Tool")
    if not equippedTool or equippedTool ~= Tool then return end -- Ensure the activated tool is the one held

    local itemDef = ItemDefinitions:GetItem(equippedTool.Name) -- Assuming tool name is the item ID

    if not itemDef then
        warn("ToolHandler: No item definition found for equipped tool:", equippedTool.Name)
        return
    end

    -- Centralized dispatch based on category
    local handlerPath = Categories.USE_HANDLERS[itemDef.category]
    if handlerPath then
        local systemName, funcName = handlerPath:match("([^.]+)\.([^.]+)")
        local systemModule = _G[systemName] -- Assuming systems are registered globally by their name

        if systemModule and systemModule[funcName] then
            systemModule[funcName](itemDef, player) -- Pass itemDef and player to the handler
        else
            warn("ToolHandler: Could not find handler function", handlerPath, "for item category", itemDef.category)
        end
    else
        print("ToolHandler: No specific use handler for category:", itemDef.category, "- performing no-op.")
    end
end

Tool.Activated:Connect(onUse) 