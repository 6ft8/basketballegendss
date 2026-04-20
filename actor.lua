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

        if pcOk and playerController then

            -- Instead of removing connections, override behavior
            if playerController.Fix then
                local oldFix = playerController.Fix

                playerController.Fix = function(...)
                    -- do nothing (block correction)
                    return
                end
            end

            -- OPTIONAL: soft-block speed/jump handlers
            if playerController.Connections then
                for name, connection in pairs(playerController.Connections) do
                    if name == "Speed" or name == "Jump" then
                        -- don’t delete it, just disable safely
                        pcall(function()
                            connection:Disable()
                        end)
                    end
                end
            end

            print(">> Soft bypass applied (less detectable)")
        end
    end
end)

-- Mute real server side effect sounds on startup
local RS = game:GetService("ReplicatedStorage")

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

run_on_actor(getactors()[1], [[
    local RS = game:GetService("ReplicatedStorage")
    local players = game:GetService("Players")
    local knit = require(RS.Packages.Knit)
    local items = require(RS.Modules.Items)
    local localPlayer = players.LocalPlayer
    local sharedUtil = require(RS.Modules.SharedUtil)

    task.wait(3)

    local dc = knit.GetController("DataController")
    local data = dc.Data
    local visuals = knit.GetController("VisualController")
    local uiController = knit.GetController("UIController")
    local invUI = uiController.UIs.Inventory

    local function getCharacter()
        return localPlayer.Character
    end

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

    local realEffect = data.Effects and data.Effects.Equipped
    if realEffect then
        muteEffectSounds(realEffect)
        print(">> Muted real effect: " .. tostring(realEffect))
    end

    -- Permanently mute ALL sounds on our basketball Attach every heartbeat
    -- This catches any cloned sounds the server fires for our real effect
    local RunService = game:GetService("RunService")
    RunService.Heartbeat:Connect(function()
        local char = getCharacter()
        if not char then return end
        local bball = char:FindFirstChild("Basketball")
        if not bball then return end
        local attach = bball:FindFirstChild("Attach")
        if not attach then return end
        for _, v in pairs(attach:GetChildren()) do
            if v:IsA("Sound") and v.Volume > 0 then
                v.Volume = 0
            end
        end
        -- Also check descendants in case sounds are nested deeper
        for _, v in pairs(attach:GetDescendants()) do
            if v:IsA("Sound") and v.Volume > 0 then
                v.Volume = 0
            end
        end
    end)

    local function WaitForChildWhichIsA(self, ClassName)
        while self:FindFirstChildWhichIsA(ClassName) == nil do
            task.wait()
        end
    end

    local ownedSkins = {}
    for itemKey, itemData in pairs(items.Skins) do
        table.insert(ownedSkins, {itemKey, false})
    end

    local ownedEffects = {}
    for itemKey, itemData in pairs(items.Effects) do
        table.insert(ownedEffects, {itemKey, false})
    end

    local function reinject()
        data.Skins.Inventory = ownedSkins
        data.Effects.Inventory = ownedEffects
    end
    reinject()

    print(">> Injected " .. #ownedSkins .. " skins and " .. #ownedEffects .. " effects!")

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
        end
        return oldUpdateList(self)
    end

    local ball = localPlayer.Character and localPlayer.Character:FindFirstChild("Basketball")
    local currentSkin = data.Skins.Equipped
    local currentEffect = data.Effects.Equipped
    local oldEffects = {}

    local selectionList = localPlayer.PlayerGui.Main.Inventory.Glow.Inventory.Main.Selection.List

    local function updateCheckmark(itemKey)
        for _, frame in pairs(selectionList:GetChildren()) do
            if frame:IsA("Frame") then
                local btn = frame:FindFirstChild("Glow") and frame.Glow:FindFirstChild("Button")
                if btn and btn:FindFirstChild("Equipped") then
                    local display = frame:GetAttribute("Display")
                    btn.Equipped.Visible = (display == itemKey)
                end
            end
        end
    end

    local function updateViewingFrame(category, itemKey)
        local itemData = items[category] and items[category][itemKey]
        if not itemData then return end
        pcall(function()
            invUI:UpdateViewingFrame({
                Type = category,
                Info = itemData,
                Name = itemKey
            })
        end)
    end

    local function applyBallAppearance(itemKey)
        local character = getCharacter()
        if not character then return end
        for i,v in next, oldEffects do
            v.Parent = nil
            v:Destroy()
        end
        oldEffects = {}
        local effects = RS.Assets.Ball:FindFirstChild(itemKey)
        if not effects then return end
        for _, possibleEffect in next, effects:GetChildren() do
            if possibleEffect:IsA("ParticleEmitter") then
                local newEffect = possibleEffect:Clone()
                newEffect.Parent = ball.Attach:FindFirstChildWhichIsA("SpecialMesh")
                table.insert(oldEffects, newEffect)
            end
        end
        if effects:FindFirstChild("CUSTOM_SKIN_HOLDER") then
            local skinHolder = effects.CUSTOM_SKIN_HOLDER.CUSTOM_SKIN_HOLDER
            for _, skinElement in next, skinHolder:GetChildren() do
                if skinElement:IsA("MeshPart") then
                    local newEffect = skinElement:Clone()
                    local weld = newEffect:FindFirstChildWhichIsA("WeldConstraint")
                    newEffect.CFrame = ball.Attach.CFrame
                    weld.Part0 = ball.Attach
                    newEffect.Parent = ball.Attach
                    table.insert(oldEffects, newEffect)
                end
            end
            if skinHolder:FindFirstChild("AttHolder") then
                for _, attEffect in next, skinHolder.AttHolder:GetChildren() do
                    local newAttEffect = attEffect:Clone()
                    newAttEffect.Parent = ball.Attach
                    table.insert(oldEffects, newAttEffect)
                end
            end
        end
        if effects:FindFirstChild("CUSTOM_AURA") then
            for _, bodyPart in next, effects.CUSTOM_AURA:GetChildren() do
                for _, effect in next, bodyPart:GetChildren() do
                    if effect:IsA("CFrameValue") then
                        local attachment = Instance.new("Attachment")
                        attachment.Parent = character[bodyPart.Name]
                        attachment.CFrame = effect.Value
                        for _, cfEffect in next, effect:GetChildren() do
                            local newCfEffect = cfEffect:Clone()
                            newCfEffect.Parent = attachment
                            table.insert(oldEffects, newCfEffect)
                        end
                        continue
                    end
                    if effect:IsA("BasePart") then
                        local newPart = effect:Clone()
                        local weld = Instance.new("WeldConstraint")
                        weld.Parent = newPart
                        newPart.CFrame = character[bodyPart.Name].CFrame * newPart:GetAttribute("Offset")
                        weld.Part0 = character[bodyPart.Name]
                        weld.Part1 = newPart
                        newPart.Parent = character[bodyPart.Name]
                        table.insert(oldEffects, newPart)
                        continue
                    end
                    local newEffect = effect:Clone()
                    newEffect.Parent = character[bodyPart.Name]
                    table.insert(oldEffects, newEffect)
                end
            end
        end
    end

    local function changeBallSkin(ballObj, itemKey)
        if not ballObj or not itemKey then return end
        local skinData = items.Skins[itemKey]
        if not skinData then return end
        local character = getCharacter()
        if not character then return end
        if ballObj.Parent == character then
            ballObj:WaitForChild("Attach")
        end
        local attach = ballObj:FindFirstChild("Attach") or ballObj
        WaitForChildWhichIsA(attach, "SpecialMesh")
        if typeof(skinData[3]) == "number" then
            attach.Transparency = 0
            attach:FindFirstChildWhichIsA("SpecialMesh").MeshId = "rbxassetid://14536927547"
            attach:FindFirstChildWhichIsA("SpecialMesh").TextureId = "rbxassetid://" .. skinData[3]
        end
        if typeof(skinData[3]) == "table" then
            attach.Transparency = 1
            attach:FindFirstChildWhichIsA("SpecialMesh").TextureId = ""
            attach:FindFirstChildWhichIsA("SpecialMesh").MeshId = "rbxassetid://" .. skinData[4]
        end
        if ballObj.Parent == character then
            applyBallAppearance(itemKey)
        end
    end

    local oldEffect = visuals.Effect
    visuals.Effect = function(self, effect, ...)
        local args = {...}
        if effect == "StartBallEffect" then
            local hrp = args[3]
            local liveChar = getCharacter()
            if hrp and liveChar and hrp.Parent == liveChar and currentEffect then
                return oldEffect(self, effect, currentEffect, args[2], args[3], args[4], args[5])
            end
        end
        if effect == "BallEffect" then
            local basketball = args[3]
            local owner = basketball and basketball:GetAttribute("Owner")
            if owner == localPlayer.UserId and currentEffect then
                return oldEffect(self, effect, currentEffect, args[2], args[3], args[4], args[5])
            end
        end
        return oldEffect(self, effect, unpack(args))
    end

    local equipRE = RS.Packages.Knit.Services.EconomyService.RE.Equip
    local rmt = getrawmetatable(equipRE)
    local oldNC = rmt.__namecall
    setreadonly(rmt, false)
    rmt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if self == equipRE and method == "FireServer" then
            local a = {...}
            local category = a[1]
            local index = a[2]
            if category == "Effects" then
                local item = data.Effects.Inventory[index]
                if item then
                    currentEffect = item[1]
                    print(">> currentEffect = " .. tostring(currentEffect))
                    for i, v in ipairs(data.Effects.Inventory) do
                        v[2] = (i == index)
                    end
                    data.Effects.Equipped = item[1]
                    updateCheckmark(item[1])
                    updateViewingFrame("Effects", item[1])
                end
            elseif category == "Skins" then
                local item = data.Skins.Inventory[index]
                if item then
                    currentSkin = item[1]
                    for i, v in ipairs(data.Skins.Inventory) do
                        v[2] = (i == index)
                    end
                    data.Skins.Equipped = item[1]
                    updateCheckmark(item[1])
                    updateViewingFrame("Skins", item[1])
                    if ball then changeBallSkin(ball, currentSkin) end
                end
            end
        end
        return oldNC(self, ...)
    end)
    setreadonly(rmt, true)

    local function getMyWorkspaceBall()
        for i,v in next, workspace:GetChildren() do
            if v.Name == "Basketball" and v:GetAttribute("Owner") == localPlayer.UserId then
                return v
            end
        end
    end

    local function onBallAdded(ballObj)
        if ballObj.Name ~= "Basketball" then return end
        ball = ballObj
        if currentSkin then changeBallSkin(ball, currentSkin) end
        ball.AncestryChanged:Connect(function()
            for i,v in next, oldEffects do
                v.Parent = nil
                v:Destroy()
            end
            oldEffects = {}
            local wb = getMyWorkspaceBall()
            if wb then changeBallSkin(wb, currentSkin) end
        end)
    end

    local character = getCharacter()
    if character then
        character.ChildAdded:Connect(onBallAdded)
    end

    localPlayer.CharacterAdded:Connect(function(newChar)
        newChar.ChildAdded:Connect(onBallAdded)
        if realEffect then muteEffectSounds(realEffect) end
    end)

    print(">> Done! Open inventory and equip any skin or effect!")
]])
