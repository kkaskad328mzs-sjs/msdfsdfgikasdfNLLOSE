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
    AimThroughWalls = false,
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
    WallCheck = true,
    TargetMode = "Highest Damage",
    Multipoint = true,
    MultipointScale = 0.75,
    Backtrack = "Maximum",
    DelayShot = false
}

local FIRE_RATE = 1.3
local BULLET_SPEED = 800
local BASE_DAMAGE = 54

local DAMAGE_MULTS = {
    Head = 4, UpperTorso = 1, LowerTorso = 1, Torso = 1, HumanoidRootPart = 1,
    LeftUpperArm = 0.75, LeftLowerArm = 0.75, RightUpperArm = 0.75, RightLowerArm = 0.75,
    LeftUpperLeg = 0.6, LeftLowerLeg = 0.6, RightUpperLeg = 0.6, RightLowerLeg = 0.6,
    ["Left Leg"] = 0.6, ["Right Leg"] = 0.6
}

local lastShot = 0
local shooting = false
local currentTarget = nil
local connection = nil
local activePlayers = {}
local lastPlayerUpdate = 0
local targetLostTime = 0
local targetAcquired = false

local function getTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return nil end
    local remotes = tool:FindFirstChild("Remotes")
    if not remotes then return nil end
    local fireShot = remotes:FindFirstChild("FireShot")
    if not fireShot then return nil end
    return fireShot
end

local function calcDamage(partName, dist)
    local mult = DAMAGE_MULTS[partName] or 0.5
    local dmg = BASE_DAMAGE * mult
    if dist > 300 then
        dmg = dmg * 0.3
    elseif dist > 200 then
        dmg = dmg * 0.5
    elseif dist > 100 then
        dmg = dmg * 0.8
    end
    return math.floor(dmg)
end

local function canShootThrough(part)
    if not part or not part:IsA("BasePart") then return false end
    if part:IsA("WedgePart") then return true end
    local name = part.Name:lower()
    if name:find("hamik") or name:find("paletka") then return true end
    if part.Parent then
        local parentName = part.Parent.Name:lower()
        if parentName:find("hamik") or parentName:find("paletka") then return true end
    end
    if part.Transparency > 0.2 then return true end
    if not part.CanCollide then return true end
    return false
end

local function isPartOfChar(part)
    if not part or not part:IsA("BasePart") then return false end
    local parent = part.Parent
    if not parent then return false end
    if parent:FindFirstChild("Humanoid") then return true end
    if parent:IsA("Accessory") or parent:IsA("Hat") then return true end
    return false
end

local function strictWallCheck(from, to, ignoreChar, targetChar)
    if not from or not to then return false end
    local dir = to - from
    local dist = dir.Magnitude
    if dist < 0.1 or dist > 1000 then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {ignoreChar, targetChar}
    params.IgnoreWater = true
    local result = Workspace:Raycast(from, dir, params)
    if not result then return true end
    if result.Instance:IsDescendantOf(targetChar) then return true end
    if canShootThrough(result.Instance) or isPartOfChar(result.Instance) then
        local newFrom = result.Position + dir.Unit * 0.1
        local newDir = to - newFrom
        if newDir.Magnitude < 0.1 then return true end
        params.FilterDescendantsInstances = {ignoreChar, targetChar, result.Instance}
        local result2 = Workspace:Raycast(newFrom, newDir, params)
        if not result2 then return true end
        if result2.Instance:IsDescendantOf(targetChar) then return true end
        return false
    end
    return false
end

local function multiPointWallCheck(from, to, ignoreChar, targetChar)
    if not from or not to or not ignoreChar or not targetChar then return false end
    if strictWallCheck(from, to, ignoreChar, targetChar) then return true end
    local offsets = {Vector3.new(0, 0.3, 0), Vector3.new(0, -0.3, 0)}
    for _, offset in ipairs(offsets) do
        if strictWallCheck(from, to + offset, ignoreChar, targetChar) then return true end
    end
    return false
end

local function predict(part, root)
    if not RageModule.Settings.Prediction or not root then
        return part.Position
    end
    local vel = root.AssemblyLinearVelocity or Vector3.zero
    if vel.Magnitude < 3 then return part.Position end
    return part.Position + vel * RageModule.Settings.PredictionStrength
end

local function inFOV(pos)
    if RageModule.Settings.FOV >= 360 then return true end
    local screen, onScreen = Camera:WorldToViewportPoint(pos)
    if not onScreen then return false end
    local vp = Camera.ViewportSize
    local dx = screen.X - vp.X / 2
    local dy = screen.Y - vp.Y / 2
    return (dx * dx + dy * dy) <= (RageModule.Settings.FOV * RageModule.Settings.FOV)
end

local function isGrounded(hum, root)
    if not hum or not root then return false end
    if hum.FloorMaterial ~= Enum.Material.Air then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.IgnoreWater = true
    local result = Workspace:Raycast(root.Position, Vector3.new(0, -3.5, 0), params)
    return result ~= nil
end

local function isJumping(hum)
    if not hum then return true end
    local state = hum:GetState()
    return state == Enum.HumanoidStateType.Jumping or
           state == Enum.HumanoidStateType.Freefall or
           state == Enum.HumanoidStateType.FallingDown
end

local function updateActivePlayers()
    table.clear(activePlayers)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if not plr.Team or not LocalPlayer.Team or plr.Team ~= LocalPlayer.Team then
                local char = plr.Character
                if char then
                    local hum = char:FindFirstChild("Humanoid")
                    if hum and hum.Health > 0 then
                        local root = char:FindFirstChild("HumanoidRootPart")
                        if root then
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
    local bestScore = -math.huge
    for _, data in ipairs(activePlayers) do
        local tChar = data.character
        local tRoot = data.rootPart
        local tHum = data.humanoid
        local parts = {}
        if RageModule.Settings.Hitboxes.Head then
            table.insert(parts, {name = "Head", priority = 4})
        end
        if RageModule.Settings.Hitboxes.Body then
            table.insert(parts, {name = "UpperTorso", priority = 2})
            table.insert(parts, {name = "LowerTorso", priority = 2})
            table.insert(parts, {name = "Torso", priority = 2})
        end
        if RageModule.Settings.Hitboxes.Arms then
            table.insert(parts, {name = "LeftUpperArm", priority = 1})
            table.insert(parts, {name = "RightUpperArm", priority = 1})
        end
        if RageModule.Settings.Hitboxes.Legs then
            table.insert(parts, {name = "LeftUpperLeg", priority = 1})
            table.insert(parts, {name = "RightUpperLeg", priority = 1})
        end
        for _, pData in ipairs(parts) do
            local part = tChar:FindFirstChild(pData.name)
            if part then
                local predPos = predict(part, tRoot)
                local dist = (head.Position - predPos).Magnitude
                if dist <= 1000 then
                    if inFOV(predPos) then
                        local dmg = calcDamage(pData.name, dist)
                        if dmg >= RageModule.Settings.MinDamage then
                            local canShoot = true
                            if RageModule.Settings.WallCheck and not RageModule.Settings.AimThroughWalls then
                                canShoot = multiPointWallCheck(head.Position, predPos, char, tChar)
                            end
                            if canShoot then
                                local score = dmg * pData.priority - dist * 0.1
                                if score > bestScore then
                                    bestScore = score
                                    best = {
                                        player = data.player,
                                        character = tChar,
                                        part = part,
                                        root = tRoot,
                                        humanoid = tHum,
                                        predictedPos = predPos,
                                        distance = dist
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function autoStop()
    if not RageModule.Settings.AutoStop then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    if hum.FloorMaterial == Enum.Material.Air then return end
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(100000, 0, 100000)
    bv.P = 10000
    bv.Parent = root
    local speed = hum.WalkSpeed
    hum.WalkSpeed = 0
    task.delay(0.3, function()
        if bv.Parent then bv:Destroy() end
        if hum.Parent then hum.WalkSpeed = speed end
    end)
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
    if now - lastShot < FIRE_RATE then return end
    local fireShot = getTool()
    if not fireShot then return end
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
        local dir = (target.predictedPos - origin).Unit
        if RageModule.Settings.RotateCamera and not RageModule.Settings.SilentAim then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.predictedPos)
        end
        if not RageModule.Settings.SilentAim then
            disableAA(dir)
        end
        if RageModule.Settings.AutoStop then
            autoStop()
        end
        task.wait(0.05)
        if RageModule.Settings.DoubleTap then
            pcall(function()
                fireShot:FireServer(origin, dir, target.part)
            end)
            task.wait(0.05)
            pcall(function()
                fireShot:FireServer(origin, dir, target.part)
            end)
        else
            pcall(function()
                fireShot:FireServer(origin, dir, target.part)
            end)
        end
        task.wait(0.1)
        if _G.FakeDuckActive then
            _G.FakeDuckPause = false
        end
        shooting = false
    end)
end

local hit = ReplicatedStorage:FindFirstChild("hit")
if hit then
    hit.OnClientEvent:Connect(function()
        autoStop()
    end)
end

function RageModule:Start()
    if connection then return end
    connection = RunService.Heartbeat:Connect(function()
        if not RageModule.Settings.Enabled then
            currentTarget = nil
            targetAcquired = false
            return
        end
        if shooting then return end
        local char = LocalPlayer.Character
        if not char then
            currentTarget = nil
            return
        end
        local hum = char:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then
            currentTarget = nil
            return
        end
        local now = tick()
        if now - lastShot < FIRE_RATE then return end
        local target = findTarget()
        if not target then
            if not targetAcquired then
                targetAcquired = true
                targetLostTime = now
            end
            currentTarget = nil
            return
        end
        if targetAcquired then
            targetAcquired = false
            targetLostTime = now
        end
        if now - targetLostTime < 0.05 then return end
        currentTarget = target
        if RageModule.Settings.AutoFire then
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
