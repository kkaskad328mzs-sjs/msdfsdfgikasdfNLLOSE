--[[
    Mirage HvH Rage Module
    Based on original game logic
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
    TargetMode = "Highest Damage",
    Hitboxes = {Head = true, Body = true, Arms = false, Legs = false},
    Multipoint = true,
    MultipointScale = 0.75,
    HitChance = 100,
    MinDamage = 0,
    Prediction = true,
    PredictionStrength = 0.25,
    PingCompensation = true,
    AutoStop = true,
    AutoStopModes = {Early = true, InAir = false, BetweenShot = true, ForceAccurate = true},
    QuickScope = false,
    Backtrack = "High",
    DelayShot = false,
    DoubleTap = false,
    WallCheck = true,
    WallPenetration = false
}

local DamageMultipliers = {
    Head = 4, UpperTorso = 1, LowerTorso = 1, Torso = 1, HumanoidRootPart = 1,
    LeftUpperArm = 0.75, LeftLowerArm = 0.75, LeftHand = 0.75,
    RightUpperArm = 0.75, RightLowerArm = 0.75, RightHand = 0.75,
    LeftUpperLeg = 0.6, LeftLowerLeg = 0.6, LeftFoot = 0.6,
    RightUpperLeg = 0.6, RightLowerLeg = 0.6, RightFoot = 0.6,
    ["Left Leg"] = 0.6, ["Right Leg"] = 0.6
}

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

local CurrentTarget = nil
local LastShotTime = 0
local IsShooting = false
local ActivePlayers = {}
local LastPlayerUpdate = 0
local RandomGen = Random.new()

local function GetToolComponents()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return nil end
    
    local remotes = tool:FindFirstChild("Remotes")
    if not remotes then return nil end
    
    local fireShot = remotes:FindFirstChild("FireShot")
    if not fireShot then return nil end
    
    return {tool = tool, fireShot = fireShot, handle = tool:FindFirstChild("Handle")}
end

local function CanPassThrough(part)
    if not part or not part:IsA("BasePart") then return false end
    return part:IsA("WedgePart") or part.Transparency > 0.2 or not part.CanCollide
end

local function WallCheck(origin, target, localChar, targetChar)
    if not origin or not target then return false end
    
    local dir = target - origin
    if dir.Magnitude < 0.1 or dir.Magnitude > 1000 then return false end
    
    RayParams.FilterDescendantsInstances = {localChar, targetChar}
    local result = Workspace:Raycast(origin, dir, RayParams)
    
    if not result then return true end
    if result.Instance:IsDescendantOf(targetChar) then return true end
    
    if CanPassThrough(result.Instance) then
        local newOrigin = result.Position + dir.Unit * 0.1
        local newDir = target - newOrigin
        if newDir.Magnitude < 0.1 then return true end
        
        RayParams.FilterDescendantsInstances = {localChar, targetChar, result.Instance}
        local result2 = Workspace:Raycast(newOrigin, newDir, RayParams)
        
        if not result2 then return true end
        if result2.Instance:IsDescendantOf(targetChar) then return true end
    end
    
    return false
end

local function PredictPos(part, rootPart, ping)
    if not RageModule.Settings.Prediction or not rootPart then return part.Position end
    
    local vel = rootPart.AssemblyLinearVelocity or Vector3.zero
    if vel.Magnitude < 3 then return part.Position end
    
    local predTime = RageModule.Settings.PredictionStrength
    if RageModule.Settings.PingCompensation and ping then
        predTime = predTime + (ping / 1000)
    end
    
    return part.Position + vel * predTime
end

local function IsInFOV(pos)
    if RageModule.Settings.FOV >= 360 then return true end
    
    local screenPos, onScreen = CurrentCamera:WorldToViewportPoint(pos)
    if not onScreen then return false end
    
    local vpSize = CurrentCamera.ViewportSize
    local dx = screenPos.X - vpSize.X * 0.5
    local dy = screenPos.Y - vpSize.Y * 0.5
    
    return (dx * dx + dy * dy) <= (RageModule.Settings.FOV * RageModule.Settings.FOV)
end

local function CalcDamage(partName, dist)
    local mult = DamageMultipliers[partName] or 0.5
    local base = 54 * mult
    
    if dist > 300 then return math.floor(base * 0.3)
    elseif dist > 200 then return math.floor(base * 0.5)
    elseif dist > 100 then return math.floor(base * 0.8)
    end
    
    return math.floor(base)
end

local function CheckHitChance()
    if RageModule.Settings.HitChance >= 100 then return true end
    if RageModule.Settings.HitChance <= 0 then return false end
    return RandomGen:NextInteger(1, 100) <= RageModule.Settings.HitChance
end

local function UpdatePlayers()
    table.clear(ActivePlayers)
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and (not plr.Team or not LocalPlayer.Team or plr.Team ~= LocalPlayer.Team) then
            local char = plr.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                local root = char:FindFirstChild("HumanoidRootPart")
                
                if hum and hum.Health > 0 and root then
                    table.insert(ActivePlayers, {
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

local function GetPing()
    local s, p = pcall(function() return LocalPlayer:GetNetworkPing() * 1000 end)
    return s and p or 0
end

local function FindTarget()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    
    local head = char:FindFirstChild("Head")
    if not head then return nil end
    
    local now = tick()
    if now - LastPlayerUpdate >= 0.5 then
        LastPlayerUpdate = now
        UpdatePlayers()
    end
    
    if #ActivePlayers == 0 then return nil end
    
    local best = nil
    local bestScore = -math.huge
    local ping = GetPing()
    
    local hitboxes = {
        {names = {"Head"}, enabled = RageModule.Settings.Hitboxes.Head, priority = 4},
        {names = {"UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart"}, enabled = RageModule.Settings.Hitboxes.Body, priority = 2},
        {names = {"LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm"}, enabled = RageModule.Settings.Hitboxes.Arms, priority = 1},
        {names = {"LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg", "Left Leg", "Right Leg"}, enabled = RageModule.Settings.Hitboxes.Legs, priority = 1}
    }
    
    for _, tgt in ipairs(ActivePlayers) do
        for _, hbGroup in ipairs(hitboxes) do
            if hbGroup.enabled then
                for _, pName in ipairs(hbGroup.names) do
                    local part = tgt.character:FindFirstChild(pName)
                    if part then
                        local predPos = PredictPos(part, tgt.rootPart, ping)
                        
                        if IsInFOV(predPos) then
                            local dist = (predPos - head.Position).Magnitude
                            local dmg = CalcDamage(part.Name, dist)
                            
                            if dmg >= RageModule.Settings.MinDamage then
                                if RageModule.Settings.WallCheck then
                                    if WallCheck(head.Position, predPos, char, tgt.character) or RageModule.Settings.AimThroughWalls then
                                        local score = dmg * hbGroup.priority - dist * 0.05
                                        
                                        if score > bestScore then
                                            bestScore = score
                                            best = {
                                                player = tgt.player,
                                                character = tgt.character,
                                                humanoid = tgt.humanoid,
                                                rootPart = tgt.rootPart,
                                                targetPart = part,
                                                predictedPos = predPos,
                                                distance = dist,
                                                damage = dmg
                                            }
                                        end
                                    end
                                else
                                    local score = dmg * hbGroup.priority - dist * 0.05
                                    
                                    if score > bestScore then
                                        bestScore = score
                                        best = {
                                            player = tgt.player,
                                            character = tgt.character,
                                            humanoid = tgt.humanoid,
                                            rootPart = tgt.rootPart,
                                            targetPart = part,
                                            predictedPos = predPos,
                                            distance = dist,
                                            damage = dmg
                                        }
                                    end
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

local function DisableAA(dir)
    local char = LocalPlayer.Character
    if not char then return end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local aa1 = ReplicatedStorage:FindFirstChild("aahelp")
    local aa2 = ReplicatedStorage:FindFirstChild("aahelp1")
    
    if aa1 then pcall(function() aa1:FireServer("disable") end) end
    if aa2 then pcall(function() aa2:FireServer("disable") end) end
    
    task.wait(0.01)
    
    local flatDir = Vector3.new(dir.X, 0, dir.Z).Unit
    if flatDir.Magnitude > 0.1 then
        root.CFrame = CFrame.new(root.Position, root.Position + flatDir)
    end
    
    task.delay(0.15, function()
        if aa1 then pcall(function() aa1:FireServer("enable") end) end
        if aa2 then pcall(function() aa2:FireServer("enable") end) end
    end)
end

local function Shoot(target)
    if IsShooting then return end
    
    local now = tick()
    if now - LastShotTime < 1.3 then return end
    
    local tool = GetToolComponents()
    if not tool then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local head = char:FindFirstChild("Head")
    if not head then return end
    
    if not CheckHitChance() then return end
    
    IsShooting = true
    LastShotTime = now
    
    local dir = (target.predictedPos - head.Position).Unit
    
    task.spawn(function()
        if RageModule.Settings.AutoStop and RageModule.Settings.AutoStopModes.Early then
            AutoStop()
        end
        
        if RageModule.Settings.RotateCamera and not RageModule.Settings.SilentAim then
            CurrentCamera.CFrame = CFrame.new(CurrentCamera.CFrame.Position, target.predictedPos)
        end
        
        DisableAA(dir)
        
        task.wait(0.05)
        
        if RageModule.Settings.DoubleTap then
            pcall(function()
                tool.fireShot:FireServer(head.Position, dir, target.targetPart)
            end)
            
            task.wait(0.05)
            
            pcall(function()
                tool.fireShot:FireServer(head.Position, dir, target.targetPart)
            end)
        else
            pcall(function()
                tool.fireShot:FireServer(head.Position, dir, target.targetPart)
            end)
        end
        
        task.wait(0.1)
        IsShooting = false
    end)
end

local Connection = nil

function RageModule:Start()
    if Connection then return end
    
    Connection = RunService.RenderStepped:Connect(function()
        if not RageModule.Settings.Enabled then
            CurrentTarget = nil
            return
        end
        
        if IsShooting then return end
        
        local target = FindTarget()
        CurrentTarget = target
        
        if not target then return end
        
        if RageModule.Settings.AutoFire then
            Shoot(target)
        end
    end)
end

function RageModule:Stop()
    if Connection then
        Connection:Disconnect()
        Connection = nil
    end
    CurrentTarget = nil
end

function RageModule:GetCurrentTarget()
    return CurrentTarget
end

return RageModule
