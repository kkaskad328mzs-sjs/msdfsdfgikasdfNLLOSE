--[[
    Neverlose Rage Module
    Optimized Ragebot with Advanced Prediction and Performance
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = Workspace.CurrentCamera

local RageModule = {}
RageModule.Enabled = false
RageModule.Settings = {
    -- Main Settings
    Enabled = false,
    SilentAim = true,
    RotateCamera = false,
    AutoFire = true,
    AimThroughWalls = false,
    
    -- FOV Settings
    FOV = 360,
    
    -- Target Selection
    TargetMode = "Highest Damage",
    
    -- Hitboxes
    Hitboxes = {
        Head = true,
        Body = true,
        Arms = false,
        Legs = false
    },
    
    -- Advanced Settings
    Multipoint = true,
    MultipointScale = 0.75,
    HitChance = 100,
    MinDamage = 0,
    
    -- Prediction (всегда включено с максимальными значениями)
    Prediction = true,
    PredictionStrength = 0.25,
    PingCompensation = true,
    
    -- Auto Stop
    AutoStop = true,
    AutoStopModes = {
        Early = true,
        InAir = false,
        BetweenShot = true,
        ForceAccurate = true
    },
    
    -- Other
    QuickScope = false,
    Backtrack = "High",
    DelayShot = false,
    DoubleTap = false,
    
    -- Wall Check
    WallCheck = true,
    WallPenetration = false
}

-- Damage multipliers (SSG-08)
local DamageMultipliers = {
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

-- Cached values for performance
local CachedRaycastParams = RaycastParams.new()
CachedRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
CachedRaycastParams.IgnoreWater = true

local CurrentTarget = nil
local LastShotTime = 0
local IsShooting = false
local ActivePlayers = {}
local LastPlayerUpdate = 0
local RandomState = Random.new()
local CachedLocalCharacter = nil
local CachedLocalHead = nil
local LastCacheUpdate = 0

-- Performance: Cache local character
local function UpdateLocalCache()
    local now = tick()
    if now - LastCacheUpdate < 0.1 then return end
    
    LastCacheUpdate = now
    CachedLocalCharacter = LocalPlayer.Character
    if CachedLocalCharacter then
        CachedLocalHead = CachedLocalCharacter:FindFirstChild("Head")
    end
end

-- Optimized player alive check
local function IsPlayerAlive()
    if not CachedLocalCharacter then return false end
    local humanoid = CachedLocalCharacter:FindFirstChild("Humanoid")
    return humanoid and humanoid.Health > 0
end

-- Optimized tool check
local function GetToolComponents()
    if not CachedLocalCharacter then return nil end
    
    local tool = CachedLocalCharacter:FindFirstChildOfClass("Tool")
    if not tool then return nil end
    
    local remotes = tool:FindFirstChild("Remotes")
    if not remotes then return nil end
    
    local fireShot = remotes:FindFirstChild("FireShot")
    if not fireShot then return nil end
    
    return {
        tool = tool,
        fireShot = fireShot,
        handle = tool:FindFirstChild("Handle")
    }
end

-- Optimized wall check
local function CanBulletPassThrough(part)
    if not part or not part:IsA("BasePart") then return false end
    
    return part:IsA("WedgePart") 
        or part.Transparency > 0.2 
        or not part.CanCollide
end

local function StrictWallCheck(origin, target, localChar, targetChar)
    if not origin or not target then return false end
    
    local direction = target - origin
    local distance = direction.Magnitude
    
    if distance < 0.1 or distance > 1000 then return false end
    
    CachedRaycastParams.FilterDescendantsInstances = {localChar, targetChar}
    
    local result = Workspace:Raycast(origin, direction, CachedRaycastParams)
    
    if not result then return true end
    
    local hitPart = result.Instance
    
    if hitPart:IsDescendantOf(targetChar) then return true end
    
    if CanBulletPassThrough(hitPart) then
        local newOrigin = result.Position + direction.Unit * 0.1
        local newDirection = target - newOrigin
        
        if newDirection.Magnitude < 0.1 then return true end
        
        CachedRaycastParams.FilterDescendantsInstances = {localChar, targetChar, hitPart}
        local secondResult = Workspace:Raycast(newOrigin, newDirection, CachedRaycastParams)
        
        if not secondResult then return true end
        if secondResult.Instance:IsDescendantOf(targetChar) then return true end
    end
    
    return false
end

-- Optimized prediction with velocity extrapolation
local function PredictPosition(part, rootPart, ping)
    if not RageModule.Settings.Prediction or not rootPart then
        return part.Position
    end
    
    local velocity = rootPart.AssemblyLinearVelocity or Vector3.zero
    
    if velocity.Magnitude < 3 then return part.Position end
    
    local predictionTime = RageModule.Settings.PredictionStrength
    
    if RageModule.Settings.PingCompensation and ping then
        predictionTime = predictionTime + (ping / 1000)
    end
    
    -- Advanced prediction: учитываем ускорение
    local acceleration = Vector3.zero
    local humanoid = rootPart.Parent:FindFirstChild("Humanoid")
    if humanoid and humanoid.MoveDirection.Magnitude > 0 then
        acceleration = humanoid.MoveDirection * 16 * 0.1
    end
    
    return part.Position + velocity * predictionTime + acceleration * predictionTime * predictionTime * 0.5
end

-- Optimized FOV check
local function IsInFOV(position)
    if RageModule.Settings.FOV >= 360 then return true end
    
    local screenPos, onScreen = CurrentCamera:WorldToViewportPoint(position)
    if not onScreen then return false end
    
    local viewportSize = CurrentCamera.ViewportSize
    local centerX = viewportSize.X * 0.5
    local centerY = viewportSize.Y * 0.5
    
    local deltaX = screenPos.X - centerX
    local deltaY = screenPos.Y - centerY
    
    return (deltaX * deltaX + deltaY * deltaY) <= (RageModule.Settings.FOV * RageModule.Settings.FOV)
end

-- Optimized damage calculation
local function CalculateDamage(partName, distance)
    local multiplier = DamageMultipliers[partName] or 0.5
    local baseDamage = 54 * multiplier
    
    if distance > 300 then
        return math.floor(baseDamage * 0.3)
    elseif distance > 200 then
        return math.floor(baseDamage * 0.5)
    elseif distance > 100 then
        return math.floor(baseDamage * 0.8)
    end
    
    return math.floor(baseDamage)
end

-- Optimized hit chance
local function CheckHitChance()
    if RageModule.Settings.HitChance >= 100 then return true end
    if RageModule.Settings.HitChance <= 0 then return false end
    
    return RandomState:NextInteger(1, 100) <= RageModule.Settings.HitChance
end

-- Optimized player list update
local function UpdateActivePlayers()
    table.clear(ActivePlayers)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not player.Team or not LocalPlayer.Team or player.Team ~= LocalPlayer.Team then
                local character = player.Character
                if character then
                    local humanoid = character:FindFirstChild("Humanoid")
                    local rootPart = character:FindFirstChild("HumanoidRootPart")
                    
                    if humanoid and humanoid.Health > 0 and rootPart then
                        table.insert(ActivePlayers, {
                            player = player,
                            character = character,
                            humanoid = humanoid,
                            rootPart = rootPart
                        })
                    end
                end
            end
        end
    end
end

-- Get ping
local function GetPing()
    local success, ping = pcall(function()
        return LocalPlayer:GetNetworkPing() * 1000
    end)
    return success and ping or 0
end

-- Optimized target selection
local function FindBestTarget()
    if not IsPlayerAlive() or not CachedLocalHead then return nil end
    
    local now = tick()
    if now - LastPlayerUpdate >= 1.0 then
        LastPlayerUpdate = now
        UpdateActivePlayers()
    end
    
    if #ActivePlayers == 0 then return nil end
    
    local bestTarget = nil
    local bestScore = -math.huge
    local ping = GetPing()
    local headPos = CachedLocalHead.Position
    
    -- Приоритет хитбоксов
    local hitboxPriority = {
        {names = {"Head"}, enabled = RageModule.Settings.Hitboxes.Head, priority = 4},
        {names = {"UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart"}, enabled = RageModule.Settings.Hitboxes.Body, priority = 2},
        {names = {"LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm"}, enabled = RageModule.Settings.Hitboxes.Arms, priority = 1},
        {names = {"LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg", "Left Leg", "Right Leg"}, enabled = RageModule.Settings.Hitboxes.Legs, priority = 1}
    }
    
    for _, targetData in ipairs(ActivePlayers) do
        local targetChar = targetData.character
        local rootPart = targetData.rootPart
        
        for _, hitboxGroup in ipairs(hitboxPriority) do
            if hitboxGroup.enabled then
                for _, partName in ipairs(hitboxGroup.names) do
                    local part = targetChar:FindFirstChild(partName)
                    if part then
                        local predictedPos = PredictPosition(part, rootPart, ping)
                        
                        if not IsInFOV(predictedPos) then continue end
                        
                        local distance = (predictedPos - headPos).Magnitude
                        
                        local damage = CalculateDamage(part.Name, distance)
                        if damage < RageModule.Settings.MinDamage then continue end
                        
                        if RageModule.Settings.WallCheck then
                            if not StrictWallCheck(headPos, predictedPos, CachedLocalCharacter, targetChar) then
                                if not RageModule.Settings.AimThroughWalls then
                                    continue
                                end
                            end
                        end
                        
                        local score = damage * hitboxGroup.priority - distance * 0.05
                        
                        if score > bestScore then
                            bestScore = score
                            bestTarget = {
                                player = targetData.player,
                                character = targetChar,
                                humanoid = targetData.humanoid,
                                rootPart = rootPart,
                                targetPart = part,
                                predictedPos = predictedPos,
                                distance = distance,
                                damage = damage
                            }
                        end
                    end
                end
            end
        end
    end
    
    return bestTarget
end

-- Optimized auto stop
local function ApplyAutoStop()
    if not RageModule.Settings.AutoStop or not CachedLocalCharacter then return end
    
    local humanoid = CachedLocalCharacter:FindFirstChild("Humanoid")
    local rootPart = CachedLocalCharacter:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not rootPart or humanoid.FloorMaterial == Enum.Material.Air then return end
    
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "AutoStopVelocity"
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
    bodyVelocity.P = 10000
    bodyVelocity.Parent = rootPart
    
    local originalSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = 0
    
    task.delay(0.3, function()
        if bodyVelocity and bodyVelocity.Parent then
            bodyVelocity:Destroy()
        end
        if humanoid and humanoid.Parent then
            humanoid.WalkSpeed = originalSpeed
        end
    end)
end

-- Disable anti-aim
local function DisableAntiAim(direction)
    if not CachedLocalCharacter then return end
    
    local rootPart = CachedLocalCharacter:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local aahelp = ReplicatedStorage:FindFirstChild("aahelp")
    local aahelp1 = ReplicatedStorage:FindFirstChild("aahelp1")
    
    if aahelp then pcall(function() aahelp:FireServer("disable") end) end
    if aahelp1 then pcall(function() aahelp1:FireServer("disable") end) end
    
    task.wait(0.01)
    
    local flatDirection = Vector3.new(direction.X, 0, direction.Z).Unit
    if flatDirection.Magnitude > 0.1 then
        rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + flatDirection)
    end
    
    task.delay(0.15, function()
        if aahelp then pcall(function() aahelp:FireServer("enable") end) end
        if aahelp1 then pcall(function() aahelp1:FireServer("enable") end) end
    end)
end

-- Optimized shooting
local function PerformShot(target)
    if IsShooting then return end
    if tick() - LastShotTime < 1.3 then return end
    
    local toolComponents = GetToolComponents()
    if not toolComponents or not CachedLocalHead then return end
    
    if not CheckHitChance() then return end
    
    IsShooting = true
    
    local shootDirection = (target.predictedPos - CachedLocalHead.Position).Unit
    
    task.spawn(function()
        if RageModule.Settings.AutoStop and RageModule.Settings.AutoStopModes.Early then
            ApplyAutoStop()
        end
        
        if RageModule.Settings.RotateCamera and not RageModule.Settings.SilentAim then
            CurrentCamera.CFrame = CFrame.new(CurrentCamera.CFrame.Position, target.predictedPos)
        end
        
        DisableAntiAim(shootDirection)
        
        if RageModule.Settings.DoubleTap then
            local success1 = pcall(function()
                toolComponents.fireShot:FireServer(CachedLocalHead.Position, shootDirection, target.targetPart)
            end)
            
            if success1 then
                LastShotTime = tick()
                task.wait(0.05)
                pcall(function()
                    toolComponents.fireShot:FireServer(CachedLocalHead.Position, shootDirection, target.targetPart)
                end)
            end
        else
            local success = pcall(function()
                toolComponents.fireShot:FireServer(CachedLocalHead.Position, shootDirection, target.targetPart)
            end)
            
            if success then
                LastShotTime = tick()
            end
        end
        
        task.wait(0.1)
        IsShooting = false
    end)
end

-- Main loop (optimized)
local Connection = nil
local FrameCounter = 0

function RageModule:Start()
    if Connection then return end
    
    Connection = RunService.RenderStepped:Connect(function()
        if not RageModule.Settings.Enabled then
            CurrentTarget = nil
            return
        end
        
        -- Update cache every frame
        UpdateLocalCache()
        
        if not IsPlayerAlive() then
            CurrentTarget = nil
            return
        end
        
        if IsShooting then return end
        
        -- Throttle target finding (every 2 frames for performance)
        FrameCounter = FrameCounter + 1
        if FrameCounter % 2 ~= 0 then return end
        
        local target = FindBestTarget()
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
    FrameCounter = 0
end

function RageModule:GetCurrentTarget()
    return CurrentTarget
end

return RageModule
