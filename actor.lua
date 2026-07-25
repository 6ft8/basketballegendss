--// FIX BYPASS (from Script 1, cleaned)
task.spawn(function()
    local RS = game:GetService("ReplicatedStorage")

    local ok, knit = pcall(function()
        return require(RS.Packages.Knit)
    end)

    if ok and knit then
        task.wait(3.5)

        local pcOk, playerController = pcall(function()
            return knit.GetController("PlayerController")
        end)

        if pcOk and playerController and playerController.Connections then
            for name, connection in pairs(playerController.Connections) do
                if name == "Speed" or name == "Jump" then
                    pcall(function()
                        connection:Disconnect()
                    end)
                    playerController.Connections[name] = nil
                end
            end

            -- Disable internal fix function safely
            if playerController.Fix then
                playerController.Fix = function() end
            end

            print(">> Fix bypass injected (Speed/Jump disabled)")
        end
    end
end)

--// MUTE ALL EFFECT SOUNDS PERMANENTLY
local RS = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local RunService = game:GetService("RunService")

local function muteEffectSounds(effectName)
    local effectFolder = RS.Assets.Effects:FindFirstChild(effectName)
    if not effectFolder then return end
    for _, v in pairs(effectFolder:GetDescendants()) do
        if v:IsA("Sound") then
            v.Volume = 0
            pcall(function()
                hookfunction(v.Play, function() return end)
            end)
        end
    end
end

--// PERMANENT AUDIO MUTE ON BALL
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
            pcall(function()
                hookfunction(v.Play, function() return end)
            end)
        end
    end
end)

--// RUN UNLOCK ALL INSIDE ACTOR
run_on_actor(getactors()[1], [[
    local RS = game:GetService("ReplicatedStorage")
    local players = game:GetService("Players")
    local localPlayer = players.LocalPlayer
    local knit = require(RS.Packages.Knit)
    local items = require(RS.Modules.Items)
    local sharedUtil = require(RS.Modules.SharedUtil)

    task.wait(3)

    local dc = knit.GetController("DataController")
    local data = dc.Data
    local visuals = knit.GetController("VisualController")
    local uiController = knit.GetController("UIController")
    local invUI = uiController.UIs.Inventory

    --// ============================================================
    --// FULL SERVER EFFECT BLOCK
    --// ============================================================

    -- Store your chosen effect
    local myEffect = data.Effects.Equipped or "Default"

    -- Completely override the VisualController Effect function
    local oldEffect = visuals.Effect
    visuals.Effect = function(self, effect, ...)
        local args = {...}
        
        -- BLOCK ALL SERVER EFFECTS
        if effect == "StartBallEffect" or effect == "BallEffect" then
            -- Do NOT call the old function for server effects
            -- Instead, apply YOUR effect
            local hrp = args[3]
            local char = localPlayer.Character
            local myHRP = char and char:FindFirstChild("HumanoidRootPart")
            
            if myHRP and hrp == myHRP then
                -- Your effect is already applied, just suppress server
                return
            end
        end
        
        -- Allow all other effects to pass through
        return oldEffect(self, effect, unpack(args))
    end

    -- Also intercept the remote that triggers server effects
    local effectRE = RS.Packages.Knit.Services.EconomyService.RE.Effect
    local rmt = getrawmetatable(effectRE)
    local oldNC = rmt.__namecall
    setreadonly(rmt, false)
    rmt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if self == effectRE and method == "FireServer" then
            -- BLOCK server effect calls entirely
            return
        end
        return oldNC(self, ...)
    end)
    setreadonly(rmt, true)

    --// ============================================================
    --// INJECT ALL ITEMS
    --// ============================================================

    local ownedSkins = {}
    for itemKey, itemData in pairs(items.Skins) do
        table.insert(ownedSkins, {itemKey, false})
    end

    local ownedEffects = {}
    for itemKey, itemData in pairs(items.Effects) do
        table.insert(ownedEffects, {itemKey, false})
    end

    local ownedEmotes = {}
    for itemKey, itemData in pairs(items.Emotes) do
        table.insert(ownedEmotes, {itemKey, false})
    end

    local function reinject()
        data.Skins.Inventory = ownedSkins
        data.Effects.Inventory = ownedEffects
        data.Emotes.Inventory = ownedEmotes
    end
    reinject()

    print(">> Injected " .. #ownedSkins .. " skins and " .. #ownedEffects .. " effects!")

    --// ============================================================
    --// UI HOOKS
    --// ============================================================

    local oldUpdateList = invUI.UpdateList
    invUI.UpdateList = function(self)
        reinject()
        if self.CurrentTab == "Skins" then
            for i, v in ipairs(data.Skins.Inventory) do
                v[2] = (v[1] == data.Skins.Equipped)
            end
        elseif self.CurrentTab == "Effects" then
            for i, v in ipairs(data.Effects.Inventory) do
                v[2] = (v[1] == data.Effects.Equipped)
            end
        elseif self.CurrentTab == "Emotes" then
            for i, v in ipairs(data.Emotes.Inventory) do
                v[2] = (v[1] == data.Emotes.Equipped)
            end
        end
        return oldUpdateList(self)
    end

    --// ============================================================
    --// EQUIP HOOKS
    --// ============================================================

    local equipRE = RS.Packages.Knit.Services.EconomyService.RE.Equip
    local equipRmt = getrawmetatable(equipRE)
    local oldEquipNC = equipRmt.__namecall
    setreadonly(equipRmt, false)
    equipRmt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if self == equipRE and method == "FireServer" then
            local args = {...}
            local category = args[1]
            local index = args[2]
            
            if category == "Effects" then
                local item = data.Effects.Inventory[index]
                if item then
                    data.Effects.Equipped = item[1]
                    myEffect = item[1]  -- Update your effect
                    for i, v in ipairs(data.Effects.Inventory) do
                        v[2] = (i == index)
                    end
                    -- Update UI checkmarks
                    for _, frame in pairs(localPlayer.PlayerGui.Main.Inventory.Glow.Inventory.Main.Selection.List:GetChildren()) do
                        if frame:IsA("Frame") then
                            local btn = frame:FindFirstChild("Glow") and frame.Glow:FindFirstChild("Button")
                            if btn and btn:FindFirstChild("Equipped") then
                                local display = frame:GetAttribute("Display")
                                btn.Equipped.Visible = (display == item[1])
                            end
                        end
                    end
                    -- Update viewing frame
                    local itemData = items.Effects and items.Effects[item[1]]
                    if itemData then
                        pcall(function()
                            invUI:UpdateViewingFrame({
                                Type = "Effects",
                                Info = itemData,
                                Name = item[1]
                            })
                        end)
                    end
                end
                return
            end
        end
        return oldEquipNC(self, ...)
    end)
    setreadonly(equipRmt, true)

    print(">> Done! Server effects are now fully blocked.")
]])
