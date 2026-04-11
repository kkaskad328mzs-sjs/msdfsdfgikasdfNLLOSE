--[[
    Neverlose Rage Module
    Based on Nemesis logic - optimized and working
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = Workspace.CurrentCamera

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
    PredictionStrength = 1.2,
    PingCompensation = true,
    AutoStop = true,
    DoubleTap = false,
    WallCheck = true
}

-- Constants
local BULLET_SPEED = 800
local BASE_DAMAGE = 54
local MAX_DISTANCE = 1000
local FIRE_RATE = 1.3

-- Damage multipliers
local BODY_PART_MULTIPLIERS = {
    Head = 4.0,
    UpperTorso = 1.0,
    LowerTorso = 1.0,
    Torso = 1.0,
    HumanoidRootPart = 1.0,
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

-- State
local LastShotTime = 0
local IsShooting = false
local ActivePlayers = {}
local LastPlayerUpdate = 0
local LastPingUpdate = 0
local CurrentPing = 0
local Random = Random.new()
local CurrentTarget = nil

-- Helper functions
local function IsAlive()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

local function IsInAir()
    local char = LocalPlayer.Character
    if not char then return true end
    
    local hum = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return true end
    
    if hum.FloorMaterial == Enum.Material.Air then
        return true
    end
    
    if math.abs(hrp.AssemblyLinearVelocity.Y) > 2 then
        return true
    end
    
    return false
end

local function GetToolComponents()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    for _, item in pairs(char:GetChildren()) do
        if item:IsA("Tool") then
            local remotes = item:FindFirstChild("Remotes")
            if remotes then
                local fireShot = remotes:FindFirstChild("FireShot")
                if fireShot then
                    return {type = "AWP", fireShot = fireShot, tool = item}
                end
            end
        end
    end
    
    return nil
end

local function CalculatePotentialDamage(partName, distance)
    local multiplier = BODY_PART_MULTIPLIERS[partName] or 0.5
    local damage = BASE_DAMAGE * multiplier
    
    if distance > 300 then
        damage = damage * 0.3
    elseif distance > 200 then
        damage = damage * 0.5
    elseif distance > 100 then
        damage = damage * 0.8
    end
    
    return math.floor(damage)
end

local function IsPartVisible(targetPart, targetChar)
    if not targetPart or not targetPart.Parent then return false end
    if not IsAlive() then return false end
    
    local myChar = LocalPlayer.Character
    if not myChar then return false end
    local myHead = myChar:FindFirstChild("Head")
    if not myHead then return false end
    
    local origin = myHead.Position
    local targetPos = targetPart.Position
    local dir = targetPos - origin
    local dist = dir.Magnitude
    
    if dist < 0.1 then return true end
    if dist > MAX_DISTANCE then return false end
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {myChar}
    params.IgnoreWater = true
    
    local unit = dir.Unit
    local curOrigin = origin
    
    -- Multi-pass raycast (like nemesis)
    for _ = 1, 6 do
        local res = Workspace:Raycast(curOrigin, targetPos - curOrigin, params)
        
        if not res then return true end
        
        local hit = res.Instance
        
        if hit and hit:IsDescendantOf(targetChar) then
            return true
        end
        
        if hit then
            local name = hit.Name:lower()
            local isHamik = name:find("hamik") or name:find("paletka")
            local isSoft = hit.Transparency > 0.3 or hit.CanCollide == false
            
            if isHamik or isSoft then
                curOrigin = res.Position + unit * 0.2
                continue
            end
        end
        
        return false
    end
    
    return false
end

local function PredictPosition(part, rootPart)
    if not RageModule.Settings.Prediction or not rootPart then
        return part.Position
    end
    
    local velocity = rootPart.AssemblyLinearVelocity or Vector3.zero
    if velocity.Magnitude < 2 then return part.Position end
    
    -- Horizontal velocity only (like nemesis)
    local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
    
    local distance = (part.Position - CurrentCamera.CFrame.Position).Magnitude
    local travelTime = distance / BULLET_SPEED
    local pingTime = CurrentPing / 2
    local dynamicTime = math.clamp(pingTime + travelTime, 0.05, 0.22)
    
    local predictedPos = part.Position + (horizontalVelocity * dynamicTime * RageModule.Settings.PredictionStrength)
    
    return predictedPos
end

local function IsInFOV(position)
    if RageModule.Settings.FOV >= 360 then return true end
    
    local screenPos, onScreen = CurrentCamera:WorldToViewportPoint(position)
    if not onScreen then return false end
    
    local vpSize = CurrentCamera.ViewportSize
    local dx = screenPos.X - vpSize.X * 0.5
    local dy = screenPos.Y - vpSize.Y * 0.5
    
    return (dx * dx + dy * dy) <= (RageModule.Settings.FOV * RageModule.Settings.FOV)
end

local function CheckHitChance()
    if RageModule.Settings.HitChance >= 100 then return true end
    if RageModule.Settings.HitChance <= 0 then return false end
    
    return Random:NextInteger(1, 100) <= RageModule.Settings.HitChance
end

local function UpdateActivePlayers()
    table.clear(ActivePlayers)
    
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= LocalPlayer then
            -- Team check
            if not targetPlayer.Team or not LocalPlayer.Team or targetPlayer.Team ~= LocalPlayer.Team then
                local targetChar = targetPlayer.Character
                if targetChar then
                    local hum = targetChar:FindFirstChild("Humanoid")
                    local rootPart = targetChar:FindFirstChild("HumanoidRootPart")
                    if hum and hum.Health > 0 and rootPart then
                        table.insert(ActivePlayers, {
                            player = targetPlayer,
                            character = targetChar,
                            humanoid = hum,
                            rootPart = rootPart
                        })
                    end
                end
            end
        end
    end
end

local function FindTarget()
    if not IsAlive() then return nil end
    
    local char = LocalPlayer.Character
    local myHead = char and char:FindFirstChild("Head")
    if not myHead then return nil end
    
    local now = tick()
    if now - LastPlayerUpdate >= 0.5 then
        LastPlayerUpdate = now
        UpdateActivePlayers()
    end
    
    local bestTarget = nil
    local bestDist = MAX_DISTANCE
    
    for _, data in ipairs(ActivePlayers) do
        if not data.humanoid or data.humanoid.Health <= 0 then continue end
        if not data.rootPart or not data.rootPart.Parent then continue end
        
        local dist = (data.rootPart.Position - myHead.Position).Magnitude
        if dist > bestDist then continue end
        
        -- Check visibility of any part first
        local visible = false
        local visibleParts = {
            "Head", "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart",
            "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"
        }
        
        for _, partName in ipairs(visibleParts) do
            local p = data.character:FindFirstChild(partName)
            if p and IsPartVisible(p, data.character) then
                visible = true
                break
            end
        end
        
        if not visible then continue end
        
        -- Find best hitbox based on settings
        local targetPart = nil
        
        if RageModule.Settings.Hitboxes.Head then
            local head = data.character:FindFirstChild("Head")
            if head and IsPartVisible(head, data.character) then
                local damage = CalculatePotentialDamage("Head", dist)
                if damage >= RageModule.Settings.MinDamage then
                    targetPart = head
                end
            end
        end
        
        if not targetPart and RageModule.Settings.Hitboxes.Body then
            for _, partName in ipairs({"UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart"}) do
                local part = data.character:FindFirstChild(partName)
                if part and IsPartVisible(part, data.character) then
                    local damage = CalculatePotentialDamage(partName, dist)
                    if damage >= RageModule.Settings.MinDamage then
                        targetPart = part
                        break
                    end
                end
            end
        end
        
        if not targetPart and RageModule.Settings.Hitboxes.Arms then
            for _, partName in ipairs({"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm"}) do
                local part = data.character:FindFirstChild(partName)
                if part and IsPartVisible(part, data.character) then
                    local damage = CalculatePotentialDamage(partName, dist)
                    if damage >= RageModule.Settings.MinDamage then
                        targetPart = part
                        break
                    end
                end
            end
        end
        
        if not targetPart and RageModule.Settings.Hitboxes.Legs then
            for _, partName in ipairs({"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg"}) do
                local part = data.character:FindFirstChild(partName)
                if part and IsPartVisible(part, data.character) then
                    local damage = CalculatePotentialDamage(partName, dist)
                    if damage >= RageModule.Settings.MinDamage then
                        targetPart = part
                        break
                    end
                end
            end
        end
        
        if not targetPart then continue end
        
        bestDist = dist
        bestTarget = {
            player = data.player,
            character = data.character,
            targetPart = targetPart,
            rootPart = data.rootPart,
            distance = dist
        }
    end
    
    return bestTarget
end

local function AutoStop()
    if not RageModule.Settings.AutoStop then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    
    if not hum or not root or hum.FloorMaterial == Enum.Material.Air then return end
    
    local bv = Instance.new("BodyVelocity")
    bv.Name = "AutoStopVelocity"
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(100000, 0, 100000)
    bv.P = 10000
    bv.Parent = root
    
    local origSpeed = hum.WalkSpeed
    hum.WalkSpeed = 0
    
    task.delay(0.3, function()
        if bv and bv.Parent then bv:Destroy() end
        if hum and hum.Parent then hum.WalkSpeed = origSpeed end
    end)
end

local function DisableAntiAim(direction)
    local char = LocalPlayer.Character
    if not char then return end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local aa1 = ReplicatedStorage:FindFirstChild("aahelp")
    local aa2 = ReplicatedStorage:FindFirstChild("aahelp1")
    
    if aa1 then pcall(function() aa1:FireServer("disable") end) end
    if aa2 then pcall(function() aa2:FireServer("disable") end) end
    
    task.wait(0.01)
    
    local flatDir = Vector3.new(direction.X, 0, direction.Z).Unit
    if flatDir.Magnitude > 0.1 then
        root.CFrame = CFrame.new(root.Position, root.Position + flatDir)
    end
    
    task.delay(0.15, function()
        if aa1 then pcall(function() aa1:FireServer("enable") end) end
        if aa2 then pcall(function() aa2:FireServer("enable") end) end
    end)
end

local function PerformShot(target)
    if IsShooting then return end
    
    local now = tick()
    if now - LastShotTime < FIRE_RATE then return end
    
    local tool = GetToolComponents()
    if not tool then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local head = char:FindFirstChild("Head")
    if not head then return end
    
    if not CheckHitChance() then return end
    
    IsShooting = true
    LastShotTime = now
    
    -- Update ping
    if now - LastPingUpdate >= 1 then
        LastPingUpdate = now
        CurrentPing = LocalPlayer:GetNetworkPing() * 1000
    end
    
    local targetPos = PredictPosition(target.targetPart, target.rootPart)
    
    task.spawn(function()
        if RageModule.Settings.AutoStop then
            AutoStop()
        end
        
        if RageModule.Settings.RotateCamera and not RageModule.Settings.SilentAim then
            CurrentCamera.CFrame = CFrame.new(CurrentCamera.CFrame.Position, targetPos)
        end
        
        local origin = head.Position
        local dirVec = targetPos - origin
        if dirVec.Magnitude < 0.01 then
            IsShooting = false
            return
        end
        
        local direction = dirVec.Unit
        
        DisableAntiAim(direction)
        
        task.wait(0.05)
        
        if RageModule.Settings.DoubleTap then
            pcall(function()
                tool.fireShot:FireServer(origin, direction, target.targetPart)
            end)
            
            task.wait(0.05)
            
            pcall(function()
                tool.fireShot:FireServer(origin, direction, target.targetPart)
            end)
        else
            pcall(function()
                tool.fireShot:FireServer(origin, direction, target.targetPart)
            end)
        end
        
        task.wait(0.1)
        IsShooting = false
    end)
end

-- Main loop
local Connection = nil

function RageModule:Start()
    if Connection then return end
    
    Connection = RunService.Heartbeat:Connect(function()
        if not RageModule.Settings.Enabled then
            CurrentTarget = nil
            return
        end
        
        if not IsAlive() then
            CurrentTarget = nil
            return
        end
        
        -- Don't shoot in air unless configured
        if IsInAir() and not RageModule.Settings.AutoFire then
            return
        end
        
        if IsShooting then return end
        
        local target = FindTarget()
        CurrentTarget = target
        
        if not target then return end
        
        if RageModule.Settings.AutoFire then
            PerformShot(target)
        end
    end)
end

function RageModule:Stop()
    if Connection then
        Connection:Disconnect()
        Connection = nil
    end
    CurrentTarget = nil
    IsShooting = false
end

function RageModule:GetCurrentTarget()
    return CurrentTarget
end

return RageModule
