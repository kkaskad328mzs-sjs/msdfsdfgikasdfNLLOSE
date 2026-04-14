local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local RageModule = {}
RageModule.Settings = {
    Enabled = false,
    SilentAim = true,
    RotateCamera = false,
    AutoFire = true,
    AimThroughWalls = true,
    FOV = 360,
    Hitboxes = {Head = true, Body = true, Arms = false, Legs = false},
    HitChance = 100,
    MinDamage = 0,
    Prediction = true,
    PredictionStrength = 0.165,
    VelocityResolver = false,
    PingCompensation = true,
    AutoStop = true,
    AutoStopModes = {Early = true, InAir = false, BetweenShot = true, ForceAccurate = true},
    DoubleTap = false,
    WallCheck = false,
    TargetMode = "Highest Damage",
    Multipoint = true,
    MultipointScale = 0.75,
    Backtrack = "Maximum",
    DelayShot = false
}

local lastShot = 0
local shooting = false
local currentTarget = nil
local connection = nil
local lastPlayerUpdate = 0
local activePlayers = {}

local DAMAGE_MULTS = {
    Head = 4,
    UpperTorso = 1,
    LowerTorso = 1,
    Torso = 1,
    HumanoidRootPart = 1,
    LeftUpperArm = 0.75,
    LeftLowerArm = 0.75,
    LeftHand = 0.75,
    RightUpperArm = 0.75,
    RightLowerArm = 0.75,
    RightHand = 0.75,
    LeftUpperLeg = 0.6,
    LeftLowerLeg = 0.6,
    LeftFoot = 0.6,
    RightUpperLeg = 0.6,
    RightLowerLeg = 0.6,
    RightFoot = 0.6,
    ["Left Leg"] = 0.6,
    ["Right Leg"] = 0.6
}

print("[Rage] Module loaded successfully")

local function getToolComponents()
    local char = LocalPlayer.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return nil end
    local remotes = tool:FindFirstChild("Remotes")
    if not remotes then return nil end
    local fireShot = remotes:FindFirstChild("FireShot")
    if not fireShot then return nil end
    return {
        tool = tool,
        fireShot = fireShot,
        reload = remotes:FindFirstChild("Reload"),
        handle = tool:FindFirstChild("Handle")
    }
end

local function updateActivePlayers()
    table.clear(activePlayers)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if not plr.Team or not LocalPlayer.Team or plr.Team ~= LocalPlayer.Team then
                local char = plr.Character
                if char then
                    local hum = char:FindFirstChild("Humanoid")
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if hum and hum.Health > 0 and root then
                        table.insert(activePlayers, {
                            player = plr,
                            character = char,
                            humanoid = hum,
                            rootPart = root
                        })
                    end
                end
            end
        end
    end
end

local function predictPosition(part, rootPart)
    if not RageModule.Settings.Prediction or not rootPart then
        return part.Position
    end
    local vel = rootPart.AssemblyLinearVelocity or Vector3.zero
    if not RageModule.Settings.VelocityResolver and vel.Magnitude < 3 then
        return part.Position
    end
    local predStrength = RageModule.Settings.PredictionStrength
    if RageModule.Settings.VelocityResolver then
        predStrength = predStrength * 1.2
    end
    return part.Position + vel * predStrength
end

local function isInFOV(position)
    if RageModule.Settings.FOV >= 360 then return true end
    local screenPos, onScreen = Camera:WorldToViewportPoint(position)
    if not onScreen then return false end
    local viewportSize = Camera.ViewportSize
    local centerX = viewportSize.X / 2
    local centerY = viewportSize.Y / 2
    local deltaX = screenPos.X - centerX
    local deltaY = screenPos.Y - centerY
    local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY)
    return distance <= RageModule.Settings.FOV
end

local function calculateDamage(partName, distance)
    local baseDamage = 54 * (DAMAGE_MULTS[partName] or 0.5)
    if distance > 300 then
        baseDamage = baseDamage * 0.3
    elseif distance > 200 then
        baseDamage = baseDamage * 0.5
    elseif distance > 100 then
        baseDamage = baseDamage * 0.8
    end
    return math.floor(baseDamage)
end

local function findBestTarget()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    local now = tick()
    if now - lastPlayerUpdate >= 0.5 then
        lastPlayerUpdate = now
        updateActivePlayers()
    end
    if #activePlayers == 0 then return nil end
    local head = char:FindFirstChild("Head")
    if not head then return nil end
    local best = nil
    local bestScore = -math.huge
    for _, data in ipairs(activePlayers) do
        local tChar = data.character
        local tRoot = data.rootPart
        local tHum = data.humanoid
        local targetParts = {}
        if RageModule.Settings.Hitboxes.Head then
            local headPart = tChar:FindFirstChild("Head")
            if headPart then table.insert(targetParts, {part = headPart, priority = 4}) end
        end
        if RageModule.Settings.Hitboxes.Body then
            local torso = tChar:FindFirstChild("UpperTorso") or tChar:FindFirstChild("Torso")
            if torso then table.insert(targetParts, {part = torso, priority = 2}) end
            local lowerTorso = tChar:FindFirstChild("LowerTorso")
            if lowerTorso then table.insert(targetParts, {part = lowerTorso, priority = 2}) end
        end
        if RageModule.Settings.Hitboxes.Arms then
            local leftArm = tChar:FindFirstChild("LeftUpperArm")
            local rightArm = tChar:FindFirstChild("RightUpperArm")
            if leftArm then table.insert(targetParts, {part = leftArm, priority = 1}) end
            if rightArm then table.insert(targetParts, {part = rightArm, priority = 1}) end
        end
        if RageModule.Settings.Hitboxes.Legs then
            local leftLeg = tChar:FindFirstChild("LeftUpperLeg") or tChar:FindFirstChild("Left Leg")
            local rightLeg = tChar:FindFirstChild("RightUpperLeg") or tChar:FindFirstChild("Right Leg")
            if leftLeg then table.insert(targetParts, {part = leftLeg, priority = 1}) end
            if rightLeg then table.insert(targetParts, {part = rightLeg, priority = 1}) end
        end
        for _, partData in ipairs(targetParts) do
            local part = partData.part
            local priority = partData.priority
            local predPos = predictPosition(part, tRoot)
            if isInFOV(predPos) then
                local dist = (head.Position - predPos).Magnitude
                if dist <= 1000 then
                    local damage = calculateDamage(part.Name, dist)
                    if damage >= RageModule.Settings.MinDamage then
                        local score = damage * priority - dist * 0.01
                        if score > bestScore then
                            bestScore = score
                            best = {
                                player = data.player,
                                character = tChar,
                                targetPart = part,
                                rootPart = tRoot,
                                humanoid = tHum,
                                predictedPos = predPos,
                                distance = dist,
                                damage = damage
                            }
                        end
                    end
                end
            end
        end
    end
    return best
end

local function disableAntiAims(direction)
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local aahelp = ReplicatedStorage:FindFirstChild("aahelp")
    local aahelp1 = ReplicatedStorage:FindFirstChild("aahelp1")
    if aahelp then
        pcall(function() aahelp:FireServer("disable") end)
    end
    if aahelp1 then
        pcall(function() aahelp1:FireServer("disable") end)
    end
    task.wait(0.01)
    local flatDir = Vector3.new(direction.X, 0, direction.Z).Unit
    if flatDir.Magnitude > 0.1 then
        root.CFrame = CFrame.new(root.Position, root.Position + flatDir)
    end
    local rotation = root.CFrame.Rotation
    task.delay(0.15, function()
        if char and root and root.Parent then
            root.CFrame = CFrame.new(root.Position) * rotation
        end
        if aahelp then
            pcall(function() aahelp:FireServer("enable") end)
        end
        if aahelp1 then
            pcall(function() aahelp1:FireServer("enable") end)
        end
    end)
end

local function shoot(target)
    if shooting then return end
    local now = tick()
    if now - lastShot < 1.3 then return end
    local toolData = getToolComponents()
    if not toolData then return end
    local char = LocalPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    if RageModule.Settings.HitChance < 100 then
        if math.random(1, 100) > RageModule.Settings.HitChance then
            return
        end
    end
    shooting = true
    lastShot = now
    task.spawn(function()
        if _G.FakeDuckActive then
            _G.FakeDuckPause = true
            task.wait(0.15)
        end
        local origin = head.Position
        local direction = (target.predictedPos - origin).Unit
        if not RageModule.Settings.SilentAim then
            disableAntiAims(direction)
        end
        task.wait(0.05)
        local success, err = pcall(function()
            toolData.fireShot:FireServer(origin, direction, target.targetPart)
        end)
        if success then
            print("[Rage] Shot fired at", target.player.Name, "->", target.targetPart.Name)
        else
            warn("[Rage] Shot failed:", err)
        end
        task.wait(0.1)
        if _G.FakeDuckActive then
            _G.FakeDuckPause = false
        end
        shooting = false
    end)
end

function RageModule:Start()
    print("[Rage] Starting ragebot...")
    if connection then return end
    connection = RunService.Heartbeat:Connect(function()
        if not RageModule.Settings.Enabled then
            currentTarget = nil
            return
        end
        if shooting then return end
        local target = findBestTarget()
        currentTarget = target
        if target and RageModule.Settings.AutoFire then
            shoot(target)
        end
    end)
    print("[Rage] Ragebot started successfully!")
end

function RageModule:Stop()
    print("[Rage] Stopping ragebot...")
    if connection then
        connection:Disconnect()
        connection = nil
    end
    currentTarget = nil
    shooting = false
    print("[Rage] Ragebot stopped!")
end

function RageModule:GetCurrentTarget()
    return currentTarget
end

return RageModule
