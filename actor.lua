--// FIX BYPASS (Speed/Jump)
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
            if playerController.Fix then
                playerController.Fix = function() end
            end
            print(">> Fix bypass injected")
        end
    end
end)

--// Main actor injection
run_on_actor(getactors()[1], [[
    local RS = game:GetService("ReplicatedStorage")
    local players = game:GetService("Players")
    local localPlayer = players.LocalPlayer
    local knit = require(RS.Packages.Knit)
    local items = require(RS.Modules.Items)
    local RunService = game:GetService("RunService")
    local selectedEffect = nil  -- will be set later

    task.wait(3)

    local dc = knit.GetController("DataController")
    local data = dc.Data
    local visuals = knit.GetController("VisualController")
    local uiController = knit.GetController("UIController")
    local invUI = uiController.UIs.Inventory

    -- ============================================================
    -- BLOCK EFFECT REMOTE (Server -> Client)
    -- ============================================================
    local effectRE = RS.Packages.Knit.Services.EconomyService.RE.Effect
    if effectRE then
        -- Disconnect all existing OnClientEvent connections
        local connections = getconnections(effectRE.OnClientEvent)
        if connections then
            for _, c in ipairs(connections) do
                pcall(function() c:Disconnect() end)
            end
            print("[Actor] Disconnected " .. #connections .. " effect remote connections")
        else
            -- Fallback: override the signal
            pcall(function()
                effectRE.OnClientEvent = Instance.new("BindableEvent").Event
            end)
        end
        -- Block FireServer (client->server) to prevent sending effect updates
        local rmt = getrawmetatable(effectRE)
        if rmt then
            local oldNC = rmt.__namecall
            setreadonly(rmt, false)
            rmt.__namecall = newcclosure(function(self, ...)
                if self == effectRE and getnamecallmethod() == "FireServer" then
                    print("[Actor] Blocked Effect FireServer")
                    return
                end
                return oldNC(self, ...)
            end)
            setreadonly(rmt, true)
        end
        print("[Actor] Effect remote fully blocked")
    end

    -- ============================================================
    -- OVERRIDE VISUAL CONTROLLER (Always use your equipped effect)
    -- ============================================================
    local oldEffect = visuals.Effect
    visuals.Effect = function(self, effect, ...)
        local args = {...}
        -- If the effect is StartBallEffect or BallEffect, ignore server's effect
        if effect == "StartBallEffect" or effect == "BallEffect" then
            local myEffect = data.Effects and data.Effects.Equipped
            if myEffect and myEffect ~= "None" then
                print("[Actor] Blocked server effect '" .. tostring(effect) .. "', applying local effect: " .. myEffect)
                -- Apply your own effect using the same arguments but with your effect name
                return oldEffect(self, effect, myEffect, args[2], args[3], args[4], args[5])
            else
                -- No equipped effect? Just block entirely.
                print("[Actor] Blocked server effect (no local effect)")
                return
            end
        end
        -- Allow other effects (e.g., StartDribble etc.)
        return oldEffect(self, effect, unpack(args))
    end
    print("[Actor] VisualController override active")

    -- ============================================================
    -- INJECT ALL ITEMS
    -- ============================================================
    local ownedSkins = {}
    for key, _ in pairs(items.Skins) do table.insert(ownedSkins, {key, false}) end
    local ownedEffects = {}
    for key, _ in pairs(items.Effects) do table.insert(ownedEffects, {key, false}) end
    local ownedEmotes = {}
    for key, _ in pairs(items.Emotes) do table.insert(ownedEmotes, {key, false}) end

    local function reinject()
        data.Skins.Inventory = ownedSkins
        data.Effects.Inventory = ownedEffects
        data.Emotes.Inventory = ownedEmotes
    end
    reinject()
    print("[Actor] Injected " .. #ownedSkins .. " skins, " .. #ownedEffects .. " effects, " .. #ownedEmotes .. " emotes")

    -- ============================================================
    -- UI HOOK
    -- ============================================================
    local oldUpdateList = invUI.UpdateList
    invUI.UpdateList = function(self)
        reinject()
        if self.CurrentTab == "Skins" then
            for i, v in ipairs(data.Skins.Inventory) do v[2] = (v[1] == data.Skins.Equipped) end
        elseif self.CurrentTab == "Effects" then
            for i, v in ipairs(data.Effects.Inventory) do v[2] = (v[1] == data.Effects.Equipped) end
        elseif self.CurrentTab == "Emotes" then
            for i, v in ipairs(data.Emotes.Inventory) do v[2] = (v[1] == data.Emotes.Equipped) end
        end
        return oldUpdateList(self)
    end
    pcall(function() invUI:UpdateList() end)

    -- ============================================================
    -- MUTE ALL BALL SOUNDS (Permanent & Aggressive)
    -- ============================================================
    local function muteSounds(parent)
        for _, v in pairs(parent:GetDescendants()) do
            if v:IsA("Sound") then
                v.Volume = 0
                pcall(function()
                    hookfunction(v.Play, function() return end)
                end)
            end
        end
    end

    RunService.Heartbeat:Connect(function()
        local char = localPlayer.Character
        if not char then return end
        local bball = char:FindFirstChild("Basketball")
        if not bball then return end
        local attach = bball:FindFirstChild("Attach")
        if attach then
            muteSounds(attach)
        end
        -- Also check the ball itself for sounds
        muteSounds(bball)
    end)

    print("[Actor] Audio mute active")

    -- ============================================================
    -- EQUIP HOOK (Preserve)
    -- ============================================================
    local equipRE = RS.Packages.Knit.Services.EconomyService.RE.Equip
    local rmt = getrawmetatable(equipRE)
    local oldNC = rmt.__namecall
    setreadonly(rmt, false)
    rmt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if self == equipRE and method == "FireServer" then
            local a = {...}
            local category, index = a[1], a[2]
            if category == "Effects" then
                local item = data.Effects.Inventory[index]
                if item then
                    data.Effects.Equipped = item[1]
                    for i, v in ipairs(data.Effects.Inventory) do v[2] = (i == index) end
                    -- Update UI
                    pcall(function()
                        for _, frame in pairs(localPlayer.PlayerGui.Main.Inventory.Glow.Inventory.Main.Selection.List:GetChildren()) do
                            if frame:IsA("Frame") and frame:GetAttribute("Display") == item[1] then
                                local btn = frame:FindFirstChild("Glow") and frame.Glow:FindFirstChild("Button")
                                if btn and btn:FindFirstChild("Equipped") then
                                    btn.Equipped.Visible = true
                                end
                            end
                        end
                        invUI:UpdateViewingFrame({Type="Effects", Info=items.Effects[item[1]], Name=item[1]})
                    end)
                end
                return -- don't send to server
            elseif category == "Skins" then
                local item = data.Skins.Inventory[index]
                if item then
                    data.Skins.Equipped = item[1]
                    for i, v in ipairs(data.Skins.Inventory) do v[2] = (i == index) end
                    -- Apply skin visually
                    -- (we keep the existing apply function, but it's not shown here for brevity)
                    pcall(function() invUI:UpdateViewingFrame({Type="Skins", Info=items.Skins[item[1]], Name=item[1]}) end)
                end
                return
            elseif category == "Emotes" then
                local item = data.Emotes.Inventory[index]
                if item then
                    data.Emotes.Equipped = item[1]
                    for i, v in ipairs(data.Emotes.Inventory) do v[2] = (i == index) end
                end
                return
            end
        end
        return oldNC(self, ...)
    end)
    setreadonly(rmt, true)

    -- ============================================================
    -- EMOTE HOOK (Block server)
    -- ============================================================
    local emoteRE = RS.Packages.Knit.Services.ControlService.RE.Emote
    local emoteRmt = getrawmetatable(emoteRE)
    local oldEmoteNC = emoteRmt.__namecall
    setreadonly(emoteRmt, false)
    emoteRmt.__namecall = newcclosure(function(self, ...)
        if self == emoteRE and getnamecallmethod() == "FireServer" then
            -- Play locally if possible
            return -- block server
        end
        return oldEmoteNC(self, ...)
    end)
    setreadonly(emoteRmt, true)

    -- ============================================================
    -- BALL APPEARANCE HOOKS (Keep existing)
    -- ============================================================
    local currentEffect = data.Effects and data.Effects.Equipped
    local currentSkin = data.Skins and data.Skins.Equipped

    -- ... (keep your existing applyBallAppearance and changeBallSkin functions)
    -- I'll omit them for brevity but they are unchanged; just ensure they use currentEffect/currentSkin.

    print("[Actor] All systems ready!")
]])
