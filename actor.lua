--// SIMPLIFIED UNLOCK ALL WITH DEBUG PRINTS
--// Run this inside actor

local RS = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer

print("[Unlock] Actor started...")

-- Wait for Knit to load
local knit
local attempts = 0
while not knit and attempts < 30 do
    pcall(function()
        knit = require(RS.Packages.Knit)
    end)
    if not knit then
        task.wait(0.5)
        attempts = attempts + 1
    end
end

if not knit then
    print("[Unlock] Knit failed to load after 15 seconds")
    return
end
print("[Unlock] Knit loaded")

-- Get DataController
local dc
attempts = 0
while not dc and attempts < 20 do
    pcall(function()
        dc = knit.GetController("DataController")
    end)
    if not dc then
        task.wait(0.5)
        attempts = attempts + 1
    end
end

if not dc then
    print("[Unlock] DataController failed")
    return
end
print("[Unlock] DataController loaded")

local data = dc.Data
if not data then
    print("[Unlock] Data is nil")
    return
end

-- Get items module
local items
pcall(function()
    items = require(RS.Modules.Items)
end)

if not items then
    print("[Unlock] Items module not found – trying alternative path")
    pcall(function()
        items = require(RS.Packages.Knit.Modules.Items)
    end)
end

if not items then
    print("[Unlock] Items module failed to load. Game may have updated.")
    return
end
print("[Unlock] Items module loaded")

-- Inject all skins, effects, emotes
local ownedSkins = {}
local ownedEffects = {}
local ownedEmotes = {}

for itemKey, _ in pairs(items.Skins or {}) do
    table.insert(ownedSkins, {itemKey, false})
end
for itemKey, _ in pairs(items.Effects or {}) do
    table.insert(ownedEffects, {itemKey, false})
end
for itemKey, _ in pairs(items.Emotes or {}) do
    table.insert(ownedEmotes, {itemKey, false})
end

local function reinject()
    if data.Skins then
        data.Skins.Inventory = ownedSkins
    end
    if data.Effects then
        data.Effects.Inventory = ownedEffects
    end
    if data.Emotes then
        data.Emotes.Inventory = ownedEmotes
    end
end

reinject()

print("[Unlock] Injected " .. #ownedSkins .. " skins, " .. #ownedEffects .. " effects, " .. #ownedEmotes .. " emotes")

-- Force UI refresh
local uiController = knit.GetController("UIController")
if uiController and uiController.UIs and uiController.UIs.Inventory then
    local invUI = uiController.UIs.Inventory
    local oldUpdate = invUI.UpdateList
    invUI.UpdateList = function(self)
        reinject()
        return oldUpdate(self)
    end
    -- Refresh UI
    pcall(function()
        invUI:UpdateList()
    end)
    print("[Unlock] UI refresh triggered")
end

-- Block server effects (simplified)
local visuals = knit.GetController("VisualController")
if visuals then
    local oldEffect = visuals.Effect
    visuals.Effect = function(self, effect, ...)
        if effect == "StartBallEffect" or effect == "BallEffect" then
            return -- Block server effects entirely
        end
        return oldEffect(self, effect, ...)
    end
    print("[Unlock] Server effects blocked")
end

-- Mute all ball sounds
local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function()
    local char = localPlayer.Character
    if not char then return end
    local bball = char:FindFirstChild("Basketball")
    if not bball then return end
    local attach = bball:FindFirstChild("Attach")
    if not attach then return end
    for _, v in pairs(attach:GetDescendants()) do
        if v:IsA("Sound") then
            v.Volume = 0
        end
    end
end)

print("[Unlock] All done! Check your inventory now.")
