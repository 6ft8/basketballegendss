--// Basketball Legends - falzzz hub
--// Perfect shot by @falzzz, Steal + Magnet by Kali Hub, Unlock All by falzzz

--// Load Rayfield
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

--// Config
local Config = {
    ShootKey = Enum.KeyCode.E,
    TweenTime = 0.001,
}

--// Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local gui = player.PlayerGui

--// Guard Remote
local GuardRemote = ReplicatedStorage.Packages.Knit.Services.ControlService.RE.Guard

--// ================================
--// PERFECT SHOT LOGIC
--// ================================
local bar = gui.Visual.Shooting.Bar
local btn = gui.Main.Mobile.Holder.Shoot

local shotEnabled = true
local ShotAccuracy = 1.0

--// ================================
--// AUTO MIX LOGIC
--// ================================
local autoMixEnabled = false
local mixCurrentMode = "great"
local mixGreatCount = 0
local mixPerfectCount = 0
local mixGreatsNeeded = math.random(4, 5)
local mixPerfectsNeeded = math.random(1, 2)

local function getAutoMixAccuracy()
    local accuracy
    if mixCurrentMode == "great" then
        accuracy = 0.95
        mixGreatCount += 1
        if mixGreatCount >= mixGreatsNeeded then
            mixCurrentMode = "perfect"
            mixGreatCount = 0
            mixGreatsNeeded = math.random(4, 5)
        end
    else
        accuracy = 1.0
        mixPerfectCount += 1
        if mixPerfectCount >= mixPerfectsNeeded then
            mixCurrentMode = "great"
            mixPerfectCount = 0
            mixPerfectsNeeded = math.random(1, 2)
        end
    end
    return accuracy
end

local function shoot()
    if not shotEnabled then return end
    local char = player.Character
    if char and char:FindFirstChild("Basketball") then
        local accuracy = autoMixEnabled and getAutoMixAccuracy() or ShotAccuracy
        bar:TweenSize(UDim2.fromScale(1, accuracy), Enum.EasingDirection.Out, Enum.EasingStyle.Linear, Config.TweenTime, true)
        bar.Size = UDim2.fromScale(1, accuracy)
    end
end

for _, e in ipairs({"MouseButton1Click","MouseButton1Down","Activated"}) do
    btn[e]:Connect(shoot)
end

UserInputService.InputBegan:Connect(function(i, g)
    if not g and i.KeyCode == Config.ShootKey then
        shoot()
    end
end)

--// ================================
--// STEAL REACH LOGIC
--// ================================
local stealReachEnabled = false
local stealReachMultiplier = 1.5
local originalRightArmSize, originalLeftArmSize

local function updateHitboxSizes()
    local char = player.Character
    if not char then return end
    local rightArm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand") or char:FindFirstChild("RightLowerArm")
    local leftArm = char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftHand") or char:FindFirstChild("LeftLowerArm")
    if stealReachEnabled then
        if rightArm then
            if not originalRightArmSize then originalRightArmSize = rightArm.Size end
            rightArm.Size = Vector3.new(originalRightArmSize.X * stealReachMultiplier, originalRightArmSize.Y * stealReachMultiplier, originalRightArmSize.Z * stealReachMultiplier)
            rightArm.Transparency = 1
            rightArm.CanCollide = false
            rightArm.Massless = true
        end
        if leftArm then
            if not originalLeftArmSize then originalLeftArmSize = leftArm.Size end
            leftArm.Size = Vector3.new(originalLeftArmSize.X * stealReachMultiplier, originalLeftArmSize.Y * stealReachMultiplier, originalLeftArmSize.Z * stealReachMultiplier)
            leftArm.Transparency = 1
            leftArm.CanCollide = false
            leftArm.Massless = true
        end
    else
        if rightArm and originalRightArmSize then
            rightArm.Size = originalRightArmSize
            rightArm.Transparency = 0
            rightArm.CanCollide = false
            rightArm.Massless = false
            originalRightArmSize = nil
        end
        if leftArm and originalLeftArmSize then
            leftArm.Size = originalLeftArmSize
            leftArm.Transparency = 0
            leftArm.CanCollide = false
            leftArm.Massless = false
            originalLeftArmSize = nil
        end
    end
end

RunService.RenderStepped:Connect(function()
    if stealReachEnabled then updateHitboxSizes() end
end)

player.CharacterAdded:Connect(function()
    originalRightArmSize = nil
    originalLeftArmSize = nil
    task.wait(1)
    if stealReachEnabled then updateHitboxSizes() end
end)

--// ================================
--// BALL MAGNET LOGIC
--// ================================
local MagsDist = 30
local magnetEnabled = false

RunService.Heartbeat:Connect(function()
    if not magnetEnabled then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, v in ipairs(workspace:GetChildren()) do
        if v:IsA("BasePart") and v.Name == "Basketball" then
            local dist = (hrp.Position - v.Position).Magnitude
            if dist <= MagsDist then
                local touch = v:FindFirstChildOfClass("TouchTransmitter")
                if touch then
                    firetouchinterest(hrp, v, 0)
                    firetouchinterest(hrp, v, 1)
                end
            end
        end
    end
end)

--// ================================
--// AUTO GUARD LOGIC
--// ================================
local autoGuardEnabled = false
local autoGuardConnection = nil
local lastPositions = {}
local predictionTime = 0.3
local guardDistance = 10

local function getPlayerFromModel(model)
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Character == model then return plr end
    end
    return nil
end

local function isOnDifferentTeam(otherModel)
    local otherPlayer = getPlayerFromModel(otherModel)
    if not otherPlayer then return false end
    if not player.Team or not otherPlayer.Team then return otherPlayer ~= player end
    return player.Team ~= otherPlayer.Team
end

local function findPlayerWithBall()
    local looseBall = workspace:FindFirstChild("Basketball")
    if looseBall and looseBall:IsA("BasePart") then
        local closestPlayer = nil
        local closestDistance = math.huge
        for _, model in pairs(workspace:GetChildren()) do
            if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") and model ~= player.Character then
                if isOnDifferentTeam(model) then
                    local rootPart = model:FindFirstChild("HumanoidRootPart")
                    local distance = (looseBall.Position - rootPart.Position).Magnitude
                    if distance < closestDistance and distance < 15 then
                        closestDistance = distance
                        closestPlayer = model
                    end
                end
            end
        end
        if closestPlayer then return closestPlayer, closestPlayer:FindFirstChild("HumanoidRootPart") end
    end
    for _, model in pairs(workspace:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") and model ~= player.Character then
            if isOnDifferentTeam(model) then
                local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
                local basketball = model:FindFirstChild("Basketball")
                if basketball and basketball:IsA("Tool") then return model, humanoidRootPart end
            end
        end
    end
    return nil, nil
end

local function autoGuard()
    if not autoGuardEnabled then return end
    if player.Character and player.Character:FindFirstChild("Basketball") then return end
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end
    local ballCarrier, ballCarrierRoot = findPlayerWithBall()
    if ballCarrier and ballCarrierRoot then
        local distance = (rootPart.Position - ballCarrierRoot.Position).Magnitude
        local currentPos = ballCarrierRoot.Position
        local velocity = Vector3.new(0, 0, 0)
        if lastPositions[ballCarrier] then
            velocity = (currentPos - lastPositions[ballCarrier]) / 0.1
        end
        lastPositions[ballCarrier] = currentPos
        local predictedPos = currentPos + (velocity * predictionTime)
        local directionToOpponent = (predictedPos - rootPart.Position).Unit
        local defensivePosition = predictedPos - directionToOpponent * 5
        defensivePosition = Vector3.new(defensivePosition.X, rootPart.Position.Y, defensivePosition.Z)
        if distance <= guardDistance then
            humanoid:MoveTo(defensivePosition)
            GuardRemote:FireServer(true)
        else
            GuardRemote:FireServer(false)
        end
    else
        GuardRemote:FireServer(false)
    end
end

--// ================================
--// POST AIMBOT LOGIC
--// ================================
local postAimbotEnabled = false
local postUpdateInterval = 0.033
local lastPostUpdate = 0
local postActivationDistance = 10

local function playerHasBall()
    local char = player.Character
    if not char then return false end
    local basketballTool = char:FindFirstChild("Basketball")
    return basketballTool and basketballTool:IsA("Tool")
end

local function detectBallHand()
    local char = player.Character
    if not char then return "right" end
    local basketballTool = char:FindFirstChild("Basketball")
    if basketballTool and basketballTool:IsA("Tool") then
        local handle = basketballTool:FindFirstChild("Handle")
        if handle then
            local charRoot = char:FindFirstChild("HumanoidRootPart")
            if charRoot then
                local relativePos = charRoot.CFrame:ToObjectSpace(handle.CFrame)
                if relativePos.X > 0 then return "right" else return "left" end
            end
        end
    end
    return "right"
end

local function getClosestOpponent()
    local char = player.Character
    if not char then return nil end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local closest, minDist = nil, postActivationDistance
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            if isOnDifferentTeam(plr.Character) then
                local enemyRoot = plr.Character.HumanoidRootPart
                local dist = (enemyRoot.Position - myRoot.Position).Magnitude
                if dist < minDist then
                    closest = enemyRoot
                    minDist = dist
                end
            end
        end
    end
    return closest
end

RunService.Heartbeat:Connect(function()
    if not postAimbotEnabled then return end
    if not playerHasBall() then return end
    local currentTime = tick()
    if currentTime - lastPostUpdate < postUpdateInterval then return end
    lastPostUpdate = currentTime
    local char = player.Character
    if not char then return end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local target = getClosestOpponent()
    if target then
        local directionToTarget = (target.Position - myRoot.Position).Unit
        local faceTarget = CFrame.new(myRoot.Position, myRoot.Position + directionToTarget)
        local ballHand = detectBallHand()
        if ballHand == "left" then
            myRoot.CFrame = faceTarget * CFrame.Angles(0, math.rad(90), 0)
        else
            myRoot.CFrame = faceTarget * CFrame.Angles(0, math.rad(-90), 0)
        end
    end
end)

--// ================================
--// UNLOCK ALL — Load from GitHub
--// ================================
if run_on_actor and getactors then
    run_on_actor(getactors()[1], game:HttpGet("https://raw.githubusercontent.com/6ft8/basketballegendss/refs/heads/main/actor.lua"))
else
    print("Unlock All requires a compatible executor!")
end

--// ================================
--// RAYFIELD UI
--// ================================
local Window = Rayfield:CreateWindow({
    Name = "falzzz hub",
    LoadingTitle = "falzzz hub",
    LoadingSubtitle = "by falzzz",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

--// PERFECT SHOT TAB
local ShotTab = Window:CreateTab("Perfect Shot", "target")
ShotTab:CreateSection("Shot Settings")

ShotTab:CreateDropdown({
    Name = "Shot Mode",
    Options = {"Perfect", "Great", "Auto Mix", "Off"},
    CurrentOption = {"Perfect"},
    Flag = "ShotMode",
    MultipleOptions = false,
    Callback = function(option)
        option = option[1]
        if option == "Perfect" then
            shotEnabled = true
            autoMixEnabled = false
            ShotAccuracy = 1.0
        elseif option == "Great" then
            shotEnabled = true
            autoMixEnabled = false
            ShotAccuracy = 0.95
        elseif option == "Auto Mix" then
            shotEnabled = true
            autoMixEnabled = true
            mixCurrentMode = "great"
            mixGreatCount = 0
            mixPerfectCount = 0
            mixGreatsNeeded = math.random(4, 5)
            mixPerfectsNeeded = math.random(1, 2)
        elseif option == "Off" then
            shotEnabled = false
            autoMixEnabled = false
        end
        Rayfield:Notify({
            Title = "Shot Mode",
            Content = "Shot mode set to " .. option,
            Duration = 2,
            Image = 14309739645,
        })
    end,
})

--// STEAL REACH TAB
local StealTab = Window:CreateTab("Steal Reach", "hand")
StealTab:CreateSection("Hitbox Settings")

StealTab:CreateToggle({
    Name = "Steal Reach Enabled",
    CurrentValue = false,
    Flag = "StealEnabled",
    Callback = function(value)
        stealReachEnabled = value
        updateHitboxSizes()
        Rayfield:Notify({
            Title = "Steal Reach",
            Content = value and "Steal Reach enabled!" or "Steal Reach disabled!",
            Duration = 2,
            Image = 14309739645,
        })
    end,
})

StealTab:CreateSlider({
    Name = "Reach Multiplier",
    Range = {1, 20},
    Increment = 0.5,
    Suffix = "x",
    CurrentValue = 1.5,
    Flag = "ReachMultiplier",
    Callback = function(value)
        stealReachMultiplier = value
        if stealReachEnabled then updateHitboxSizes() end
    end,
})

--// BALL MAGNET TAB
local MagnetTab = Window:CreateTab("Ball Magnet", "magnet")
MagnetTab:CreateSection("Magnet Settings")

MagnetTab:CreateToggle({
    Name = "Ball Magnet Enabled",
    CurrentValue = false,
    Flag = "MagnetEnabled",
    Callback = function(value)
        magnetEnabled = value
        Rayfield:Notify({
            Title = "Ball Magnet",
            Content = value and "Ball Magnet enabled!" or "Ball Magnet disabled!",
            Duration = 2,
            Image = 14309739645,
        })
    end,
})

MagnetTab:CreateSlider({
    Name = "Magnet Range",
    Range = {5, 35},
    Increment = 5,
    Suffix = " studs",
    CurrentValue = 20,
    Flag = "MagnetRange",
    Callback = function(value)
        MagsDist = value
    end,
})

--// AUTO GUARD TAB
local GuardTab = Window:CreateTab("Auto Guard", 4483362458)
GuardTab:CreateSection("Guard Settings")

GuardTab:CreateToggle({
    Name = "Auto Guard",
    CurrentValue = false,
    Flag = "AutoGuard",
    Callback = function(value)
        autoGuardEnabled = value
        if value then
            lastPositions = {}
            if not autoGuardConnection then
                autoGuardConnection = RunService.Heartbeat:Connect(autoGuard)
            end
        else
            if autoGuardConnection then
                autoGuardConnection:Disconnect()
                autoGuardConnection = nil
            end
            lastPositions = {}
            GuardRemote:FireServer(false)
        end
        Rayfield:Notify({
            Title = "Auto Guard",
            Content = value and "Auto Guard enabled!" or "Auto Guard disabled!",
            Duration = 2,
            Image = 14309739645,
        })
    end,
})

GuardTab:CreateSlider({
    Name = "Guard Distance",
    Range = {5, 20},
    Increment = 1,
    CurrentValue = 10,
    Flag = "GuardDistance",
    Callback = function(value)
        guardDistance = value
    end,
})

GuardTab:CreateSlider({
    Name = "Prediction Time",
    Range = {1, 8},
    Increment = 1,
    CurrentValue = 3,
    Flag = "PredictionTime",
    Callback = function(value)
        predictionTime = value / 10
    end,
})

--// POST AIMBOT TAB
local PostTab = Window:CreateTab("Post Aimbot", 4483362458)
PostTab:CreateSection("Post Settings")

PostTab:CreateToggle({
    Name = "Post Aimbot",
    CurrentValue = false,
    Flag = "PostAimbot",
    Callback = function(value)
        postAimbotEnabled = value
        Rayfield:Notify({
            Title = "Post Aimbot",
            Content = value and "Post Aimbot enabled!" or "Post Aimbot disabled!",
            Duration = 2,
            Image = 14309739645,
        })
    end,
})

PostTab:CreateSlider({
    Name = "Jitter Speed",
    Range = {1, 20},
    Increment = 1,
    CurrentValue = 3,
    Flag = "JitterSpeed",
    Callback = function(value)
        postUpdateInterval = value / 100
    end,
})

PostTab:CreateSlider({
    Name = "Detection Distance",
    Range = {5, 30},
    Increment = 1,
    CurrentValue = 10,
    Flag = "PostDistance",
    Callback = function(value)
        postActivationDistance = value
    end,
})

--// UNLOCK ALL TAB
local UnlockTab = Window:CreateTab("Unlock All", 4483362458)
UnlockTab:CreateSection("Cosmetics")
UnlockTab:CreateLabel("All skins and effects unlocked! Open inventory to equip them.")
UnlockTab:CreateLabel("Compatible executors: Delta, Potassium, Volt, Volcano, Wave, Isaeva.")

--// Done
Rayfield:Notify({
    Title = "Script Loaded!",
    Content = "falzzz hub is ready.",
    Duration = 3,
    Image = 14309739645,
})
