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
    LeftUpperArm = 0.75,
    RightUpperArm = 0.75,
    LeftUpperLeg = 0.6,
    RightUpperLeg = 0.6
}

local function getTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return nil end
    local remotes = tool:FindFirstChild("Remotes")
    if not remotes then return nil end
    return remotes:FindFirstChild("FireShot")
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

local function findTarget()
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
    local bestDist = math.huge
    for _, data in ipairs(activePlayers) do
        local tChar = data.character
        local tRoot = data.rootPart
        local targetPart = nil
        if RageModule.Settings.Hitboxes.Head then
            targetPart = tChar:FindFirstChild("Head")
        end
        if not targetPart and RageModule.Settings.Hitboxes.Body then
            targetPart = tChar:FindFirstChild("UpperTorso") or tChar:FindFirstChild("Torso")
        end
        if targetPart then
            local pos = predictPosition(targetPart, tRoot)
            local dist = (head.Position - pos).Magnitude
            if dist < bestDist and dist <= 1000 then
                bestDist = dist
                best = {
                    player = data.player,
                    character = tChar,
                    part = targetPart,
                    position = pos,
                    distance = dist,
                    humanoid = data.humanoid
                }
            end
        end
    end
    return best
end

local function disableAA(dir)
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local aa1 = ReplicatedStorage:FindFirstChild("aahelp")
    local aa2 = ReplicatedStorage:FindFirstChild("aahelp1")
    if aa1 then pcall(function() aa1:FireServer("disable") end) end
    if aa2 then pcall(function() aa2:FireServer("disable") end) end
    task.wait(0.01)
    local flat = Vector3.new(dir.X, 0, dir.Z).Unit
    if flat.Magnitude > 0.1 then
        root.CFrame = CFrame.new(root.Position, root.Position + flat)
    end
    local rotation = root.CFrame.Rotation
    task.delay(0.15, function()
        if char and root and root.Parent then
            root.CFrame = CFrame.new(root.Position) * rotation
        end
        if aa1 then pcall(function() aa1:FireServer("enable") end) end
        if aa2 then pcall(function() aa2:FireServer("enable") end) end
    end)
end

local function shoot(target)
    if shooting then return end
    local now = tick()
    if now - lastShot < 1.3 then return end
    local fireShot = getTool()
    if not fireShot then return end
    local char = LocalPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    shooting = true
    lastShot = now
    task.spawn(function()
        if _G.FakeDuckActive then
            _G.FakeDuckPause = true
            task.wait(0.15)
        end
        local origin = head.Position
        local dir = (target.position - origin).Unit
        if not RageModule.Settings.SilentAim then
            disableAA(dir)
        end
        task.wait(0.05)
        pcall(function()
            fireShot:FireServer(origin, dir, target.part)
        end)
        task.wait(0.1)
        if _G.FakeDuckActive then
            _G.FakeDuckPause = false
        end
        shooting = false
    end)
end

function RageModule:Start()
    if connection then return end
    connection = RunService.Heartbeat:Connect(function()
        if not RageModule.Settings.Enabled then
            currentTarget = nil
            return
        end
        if shooting then return end
        local target = findTarget()
        currentTarget = target
        if target and RageModule.Settings.AutoFire then
            shoot(target)
        end
    end)
end

function RageModule:Stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    currentTarget = nil
    shooting = false
end

function RageModule:GetCurrentTarget()
    return currentTarget
end

return RageModule
