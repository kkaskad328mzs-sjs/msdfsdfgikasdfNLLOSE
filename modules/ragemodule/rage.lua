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
    PredictionStrength = 0.25,
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

local function findTarget()
    local char = LocalPlayer.Character
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    if not head then return nil end
    local best = nil
    local bestDist = math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local tChar = plr.Character
            if tChar then
                local tHum = tChar:FindFirstChild("Humanoid")
                local tRoot = tChar:FindFirstChild("HumanoidRootPart")
                if tHum and tHum.Health > 0 and tRoot then
                    local targetPart = nil
                    if RageModule.Settings.Hitboxes.Head then
                        targetPart = tChar:FindFirstChild("Head")
                    end
                    if not targetPart and RageModule.Settings.Hitboxes.Body then
                        targetPart = tChar:FindFirstChild("UpperTorso") or tChar:FindFirstChild("Torso")
                    end
                    if targetPart then
                        local pos = targetPart.Position
                        if RageModule.Settings.Prediction then
                            local vel = tRoot.AssemblyLinearVelocity or Vector3.zero
                            if vel.Magnitude >= 3 then
                                pos = pos + vel * RageModule.Settings.PredictionStrength
                            end
                        end
                        local dist = (head.Position - pos).Magnitude
                        if dist < bestDist and dist <= 1000 then
                            bestDist = dist
                            best = {
                                player = plr,
                                character = tChar,
                                part = targetPart,
                                position = pos,
                                distance = dist
                            }
                        end
                    end
                end
            end
        end
    end
    return best
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
        local origin = head.Position
        local dir = (target.position - origin).Unit
        pcall(function()
            fireShot:FireServer(origin, dir, target.part)
        end)
        task.wait(0.1)
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
