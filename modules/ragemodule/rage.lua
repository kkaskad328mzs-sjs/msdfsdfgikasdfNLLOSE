--[[
    Neverlose Rage Module
    Advanced Ragebot with Prediction, Wall Check, and Auto Stop
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = Workspace.CurrentCamera

local RageModule = {}
RageModule.Enabled = false
RageModule.Settings = {
    -- Main Settings
    Enabled = false,
    SilentAim = true,
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
    
    -- Prediction
    Prediction = true,
    PredictionStrength = 0.15,
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
    RemoveRecoil = true,
    RemoveSpread = true,
    DoubleTap = false,
    
    -- Wall Check
    WallCheck = true,
    WallPenetration = false
}

-- Damage multipliers for body parts (SSG-08 specific)
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

-- Raycast parameters for wall checking
local RaycastParams = RaycastParams.new()
RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
RaycastParams.IgnoreWater = true

-- Internal state
local CurrentTarget = nil
local LastShotTime = 0
local IsShooting = false
local ActivePlayers = {}
local LastPlayerUpdate = 0
local RandomState = Random.new()

-- Helper Functions

local function IsPlayerAlive()
    local character = LocalPlayer.Character
    if not character then return false end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    
    return true
end

local function GetToolComponents()
    local character = LocalPlayer.Character
    if not character then return nil end
    
    local tool = character:FindFirstChildOfClass("Tool")
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

local function CanBulletPassThrough(part)
    if not part or not part:IsA("BasePart") then return false end
    
    -- Wedges are penetrable
    if part:IsA("WedgePart") then return true end
    
    -- Check for specific names
    local name = part.Name:lower()
    if name:find("hamik") or name:find("paletka") then return true end
    
    -- Check parent names
    if part.Parent then
        local parentName = part.Parent.Name:lower()
        if parentName:find("hamik") or parentName:find("paletka") then return true end
    end
    
    -- Transparent parts
    if part.Transparency > 0.2 then return true end
    
    -- Non-collidable parts
    if not part.CanCollide then return true end
    
    -- Effects
    if part:IsA("Decal") or part:IsA("ParticleEmitter") or part:IsA("Beam") or part:IsA("Trail") then
        return true
    end
    
    return false
end

local function IsPartOfCharacter(part)
    if not part or not part:IsA("BasePart") then return false end
    
    local parent = part.Parent
    if not parent then return false end
    
    if parent:FindFirstChild("Humanoid") then return true end
    if parent:IsA("Accessory") or parent:IsA("Hat") then return true end
    
    return false
end

local function StrictWallCheck(origin, target, localChar, targetChar)
    if not origin or not target then return false, "invalid_positions" end
    
    local direction = target - origin
    local distance = direction.Magnitude
    
    if distance < 0.1 or distance > 1000 then return false, "invalid_distance" end
    
    RaycastParams.FilterDescendantsInstances = {localChar, targetChar}
    
    local result = Workspace:Raycast(origin, direction, RaycastParams)
    
    if not result then return true, "clear" end
    
    local hitPart = result.Instance
    
    -- Hit the target
    if hitPart:IsDescendantOf(targetChar) then return true, "hit_target" end
    
    -- Check if bullet can pass through
    if CanBulletPassThrough(hitPart) or IsPartOfCharacter(hitPart) then
        local newOrigin = result.Position + direction.Unit * 0.1
        local newDirection = target - newOrigin
        
        if newDirection.Magnitude < 0.1 then return true, "transparent_pass" end
        
        RaycastParams.FilterDescendantsInstances = {localChar, targetChar, hitPart}
        
        local secondResult = Workspace:Raycast(newOrigin, newDirection, RaycastParams)
        
        if not secondResult then return true, "passed_through" end
        if secondResult.Instance:IsDescendantOf(targetChar) then return true, "hit_target_after_pass" end
        
        return false, "wall_blocking_after_pass"
    end
    
    return false, "wall_blocking"
end

local function MultiPointWallCheck(origin, target, localChar, targetChar)
    if not origin or not target or not localChar or not targetChar then return false end
    
    -- Check center point
    local canHit, reason = StrictWallCheck(origin, target, localChar, targetChar)
    if canHit then return true end
    
    -- Check offset points (up and down)
    local offsets = {
        Vector3.new(0, 0.3, 0),
        Vector3.new(0, -0.3, 0)
    }
    
    for _, offset in ipairs(offsets) do
        canHit, reason = StrictWallCheck(origin, target + offset, localChar, targetChar)
        if canHit then return true end
    end
    
    return false
end

local function PredictPosition(part, rootPart, ping)
    if not RageModule.Settings.Prediction or not rootPart then
        return part.Position
    end
    
    local velocity = rootPart.AssemblyLinearVelocity or Vector3.new()
    
    -- Ignore slow movement
    if velocity.Magnitude < 3 then return part.Position end
    
    local predictionTime = RageModule.Settings.PredictionStrength
    
    -- Add ping compensation
    if RageModule.Settings.PingCompensation and ping then
        predictionTime = predictionTime + (ping / 1000)
    end
    
    return part.Position + velocity * predictionTime
end

local function IsInFOV(position)
    if RageModule.Settings.FOV >= 360 then return true end
    
    local screenPos, onScreen = CurrentCamera:WorldToViewportPoint(position)
    if not onScreen then return false end
    
    local viewportSize = CurrentCamera.ViewportSize
    local centerX = viewportSize.X * 0.5
    local centerY = viewportSize.Y * 0.5
    
    local deltaX = screenPos.X - centerX
    local deltaY = screenPos.Y - centerY
    local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY)
    
    return distance <= RageModule.Settings.FOV
end

local function CalculateDamage(partName, distance)
    local baseDamage = 54 * (DamageMultipliers[partName] or 0.5)
    
    -- Distance falloff
    if distance > 300 then
        baseDamage = baseDamage * 0.3
    elseif distance > 200 then
        baseDamage = baseDamage * 0.5
    elseif distance > 100 then
        baseDamage = baseDamage * 0.8
    end
    
    return math.floor(baseDamage)
end

local function CheckMinDamage(part, distance)
    if RageModule.Settings.MinDamage <= 0 then return true end
    
    local damage = CalculateDamage(part.Name, distance)
    return damage >= RageModule.Settings.MinDamage
end

local function CheckHitChance()
    if RageModule.Settings.HitChance >= 100 then return true end
    if RageModule.Settings.HitChance <= 0 then return false end
    
    return RandomState:NextInteger(1, 100) <= RageModule.Settings.HitChance
end

local function GetRandomPointInPart(part, scale)
    if not part then return part.Position end
    if scale <= 0 then return part.Position end
    
    local size = part.Size * scale
    
    return part.Position + 
        part.CFrame.RightVector * RandomState:NextNumber(-size.X / 2, size.X / 2) +
        part.CFrame.UpVector * RandomState:NextNumber(-size.Y / 2, size.Y / 2) +
        part.CFrame.LookVector * RandomState:NextNumber(-size.Z / 2, size.Z / 2)
end

local function UpdateActivePlayers()
    table.clear(ActivePlayers)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            -- Team check
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

local function GetPing()
    local ping = 0
    pcall(function()
        ping = LocalPlayer:GetNetworkPing() * 1000
    end)
    return ping
end

local function FindBestTarget()
    if not IsPlayerAlive() then return nil end
    
    -- Update player list periodically
    local now = tick()
    if now - LastPlayerUpdate >= 0.5 then
        LastPlayerUpdate = now
        UpdateActivePlayers()
    end
    
    if #ActivePlayers == 0 then return nil end
    
    local character = LocalPlayer.Character
    local head = character:FindFirstChild("Head")
    if not head then return nil end
    
    local bestTarget = nil
    local bestScore = -math.huge
    local ping = GetPing()
    
    for _, targetData in ipairs(ActivePlayers) do
        local targetChar = targetData.character
        local rootPart = targetData.rootPart
        
        -- Get valid hitboxes
        local validParts = {}
        
        if RageModule.Settings.Hitboxes.Head then
            local headPart = targetChar:FindFirstChild("Head")
            if headPart then table.insert(validParts, {part = headPart, priority = 4}) end
        end
        
        if RageModule.Settings.Hitboxes.Body then
            for _, name in ipairs({"UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart"}) do
                local part = targetChar:FindFirstChild(name)
                if part then table.insert(validParts, {part = part, priority = 2}) end
            end
        end
        
        if RageModule.Settings.Hitboxes.Arms then
            for _, name in ipairs({"LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm"}) do
                local part = targetChar:FindFirstChild(name)
                if part then table.insert(validParts, {part = part, priority = 1}) end
            end
        end
        
        if RageModule.Settings.Hitboxes.Legs then
            for _, name in ipairs({"LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg", "Left Leg", "Right Leg"}) do
                local part = targetChar:FindFirstChild(name)
                if part then table.insert(validParts, {part = part, priority = 1}) end
            end
        end
        
        for _, partData in ipairs(validParts) do
            local part = partData.part
            local predictedPos = PredictPosition(part, rootPart, ping)
            
            -- FOV check
            if not IsInFOV(predictedPos) then continue end
            
            -- Distance check
            local distance = (predictedPos - head.Position).Magnitude
            
            -- Min damage check
            if not CheckMinDamage(part, distance) then continue end
            
            -- Wall check
            if RageModule.Settings.WallCheck then
                local canHit = false
                
                if RageModule.Settings.Multipoint then
                    canHit = MultiPointWallCheck(head.Position, predictedPos, character, targetChar)
                else
                    canHit = StrictWallCheck(head.Position, predictedPos, character, targetChar)
                end
                
                if not canHit and not RageModule.Settings.AimThroughWalls then
                    continue
                end
            end
            
            -- Calculate score
            local damage = CalculateDamage(part.Name, distance)
            local score = damage * partData.priority - distance * 0.1
            
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
    
    return bestTarget
end

local function IsGrounded(humanoid, rootPart)
    if not humanoid or not rootPart then return false end
    
    if humanoid.FloorMaterial ~= Enum.Material.Air then return true end
    
    RaycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    local result = Workspace:Raycast(rootPart.Position, Vector3.new(0, -3.5, 0), RaycastParams)
    
    return result ~= nil
end

local function ApplyAutoStop()
    if not RageModule.Settings.AutoStop then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not rootPart then return end
    if humanoid.FloorMaterial == Enum.Material.Air then return end
    
    -- Create velocity constraint
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "AutoStopVelocity"
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
    bodyVelocity.P = 10000
    bodyVelocity.Parent = rootPart
    
    local originalWalkSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = 0
    
    task.delay(0.3, function()
        if bodyVelocity and bodyVelocity.Parent then
            bodyVelocity:Destroy()
        end
        if humanoid and humanoid.Parent then
            humanoid.WalkSpeed = originalWalkSpeed
        end
    end)
end

local function DisableAntiAim(direction)
    local character = LocalPlayer.Character
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    -- Disable anti-aim helpers
    local aahelp = ReplicatedStorage:FindFirstChild("aahelp")
    local aahelp1 = ReplicatedStorage:FindFirstChild("aahelp1")
    
    if aahelp then
        pcall(function() aahelp:FireServer("disable") end)
    end
    if aahelp1 then
        pcall(function() aahelp1:FireServer("disable") end)
    end
    
    task.wait(0.01)
    
    -- Rotate to target
    local flatDirection = Vector3.new(direction.X, 0, direction.Z).Unit
    if flatDirection.Magnitude > 0.1 then
        rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + flatDirection)
    end
    
    -- Re-enable after delay
    task.delay(0.15, function()
        if aahelp then
            pcall(function() aahelp:FireServer("enable") end)
        end
        if aahelp1 then
            pcall(function() aahelp1:FireServer("enable") end)
        end
    end)
end

local function PerformShot(target)
    if IsShooting then return end
    if tick() - LastShotTime < 1.3 then return end
    
    local toolComponents = GetToolComponents()
    if not toolComponents then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local head = character:FindFirstChild("Head")
    if not head then return end
    
    -- Hit chance check
    if not CheckHitChance() then return end
    
    IsShooting = true
    
    local shootDirection = (target.predictedPos - head.Position).Unit
    
    task.spawn(function()
        -- Apply auto stop
        if RageModule.Settings.AutoStop and RageModule.Settings.AutoStopModes.Early then
            ApplyAutoStop()
        end
        
        -- Disable anti-aim and rotate
        DisableAntiAim(shootDirection)
        
        -- Fire shot
        local success, err = pcall(function()
            toolComponents.fireShot:FireServer(head.Position, shootDirection, target.targetPart)
        end)
        
        if success then
            LastShotTime = tick()
        else
            warn("Rage Shot Error:", err)
        end
        
        task.wait(0.1)
        IsShooting = false
    end)
end

-- Main Loop
local Connection = nil

function RageModule:Start()
    if Connection then return end
    
    Connection = RunService.RenderStepped:Connect(function()
        if not RageModule.Settings.Enabled then
            CurrentTarget = nil
            return
        end
        
        if not IsPlayerAlive() then
            CurrentTarget = nil
            return
        end
        
        if IsShooting then return end
        
        -- Find best target
        local target = FindBestTarget()
        CurrentTarget = target
        
        if not target then return end
        
        -- Auto fire
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
end

function RageModule:GetCurrentTarget()
    return CurrentTarget
end

return RageModule
