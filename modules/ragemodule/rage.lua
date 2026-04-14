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
    AimThroughWalls = true,
    FOV = 360,
    Hitboxes = {Head = true, Body = true, Arms = false, Legs = false},
    HitChance = 100,
    MinDamage = 0,
    Prediction = true,
    PredictionStrength = 0.165,
    VelocityResolver = true,
    PingCompensation = true,
    AutoStop = true,
    AutoStopModes = {Early = true, InAir = false, BetweenShot = true, ForceAccurate = true},
    DoubleTap = false,
    WallCheck = false,
    TargetMode = "Highest Damage",
    Multipoint = true,
    MultipointScale = 0.75,
    Backtrack = "Maximum",
    DelayShot = false,
    Resolver = true,
    ResolverMode = "Smart",
    AntiAimBreaker = true,
    AdvancedPrediction = true,
    SmartHitbox = true,
    AdaptiveFireRate = true
}

local lastShot = 0
local shooting = false
local currentTarget = nil
local connection = nil
local playerData = {}
local playerDataTime = 0
local myChar = nil
local myHead = nil
local myHRP = nil
local fireShot = nil
local fireShotTime = 0

local aahelp = ReplicatedStorage:WaitForChild("aahelp", 5)
local aahelp1 = ReplicatedStorage:WaitForChild("aahelp1", 5)

local RayP = RaycastParams.new()
RayP.FilterType = Enum.RaycastFilterType.Exclude
RayP.IgnoreWater = true

local PLAYER_CACHE_INTERVAL = 0.3
local resolverData = {}
local hitHistory = {}

local DAMAGE_MULTIPLIERS = {
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

local function CacheChar()
    local c = LocalPlayer.Character
    if c then
        myChar = c
        myHRP = c:FindFirstChild("HumanoidRootPart")
        myHead = c:FindFirstChild("Head")
    else
        myChar, myHRP, myHead = nil, nil, nil
    end
end

local function GetFireShot()
    local now = tick()
    if fireShot and fireShot.Parent and now - fireShotTime < 5 then
        return fireShot
    end
    if not myChar then return nil end
    
    for _, child in ipairs(myChar:GetChildren()) do
        if child:IsA("Tool") then
            local remotes = child:FindFirstChild("Remotes")
            if remotes then
                local fs = remotes:FindFirstChild("FireShot") or remotes:FindFirstChild("fireShot")
                if fs then
                    fireShot, fireShotTime = fs, now
                    return fs
                end
            end
        end
    end
    return nil
end

local function AdvancedPrediction(targetPart, rootPart, distance)
    local vel = rootPart.AssemblyLinearVelocity
    if vel.Magnitude < 2 then
        return targetPart.Position
    end
    
    local horizontalVelocity = Vector3.new(vel.X, 0, vel.Z)
    local bulletSpeed = 2000
    local travelTime = distance / bulletSpeed
    local pingTime = LocalPlayer:GetNetworkPing()
    local dynamicTime = math.clamp(pingTime + travelTime, 0.05, 0.22)
    
    local predictionStrength = 1.2
    if vel.Magnitude > 15 then
        predictionStrength = predictionStrength * 1.1
    end
    
    return targetPart.Position + (horizontalVelocity * dynamicTime * predictionStrength)
end

local function IsPartVisible(targetPart, targetChar, myChar)
    if not targetPart or not targetPart.Parent then return false end
    if not myChar then return false end
    
    local myHead = myChar:FindFirstChild("Head")
    if not myHead then return false end
    
    local origin = myHead.Position
    local targetPos = targetPart.Position
    local dir = targetPos - origin
    local dist = dir.Magnitude
    
    if dist < 0.1 then return true end
    if dist > 500 then return false end
    
    RayP.FilterDescendantsInstances = {myChar}
    local unit = dir.Unit
    local curOrigin = origin
    
    for _ = 1, 6 do
        local res = Workspace:Raycast(curOrigin, targetPos - curOrigin, RayP)
        
        if not res then return true end
        
        local hit = res.Instance
        
        if hit and hit:IsDescendantOf(targetChar) then
            return true
        end
        
        if hit then
            local name = hit.Name:lower()
            local isWallbang = name:find("hamik") or name:find("paletka")
            local isSoft = hit.Transparency > 0.3 or hit.CanCollide == false
            
            if isWallbang or isSoft then
                curOrigin = res.Position + unit * 0.2
                continue
            end
        end
        
        return false
    end
    
    return false
end

local function GetBestHitbox(character, distance, isInAir)
    if isInAir then
        return character:FindFirstChild("Head")
    end
    
    local priorities = {}
    
    if RageModule.Settings.Hitboxes.Head then
        table.insert(priorities, "Head")
    end
    if RageModule.Settings.Hitboxes.Body then
        table.insert(priorities, "UpperTorso")
        table.insert(priorities, "LowerTorso") 
        table.insert(priorities, "Torso")
    end
    if RageModule.Settings.Hitboxes.Arms then
        table.insert(priorities, "RightUpperArm")
        table.insert(priorities, "LeftUpperArm")
    end
    if RageModule.Settings.Hitboxes.Legs then
        table.insert(priorities, "RightUpperLeg")
        table.insert(priorities, "LeftUpperLeg")
    end
    
    if distance < 150 then
        for _, partName in ipairs({"Head", "UpperTorso", "Torso"}) do
            local part = character:FindFirstChild(partName)
            if part and IsPartVisible(part, character, myChar) then
                return part
            end
        end
    end
    
    for _, partName in ipairs(priorities) do
        local part = character:FindFirstChild(partName)
        if part and IsPartVisible(part, character, myChar) then
            return part
        end
    end
    
    return character:FindFirstChild("HumanoidRootPart")
end

local function IsInAir(humanoid, rootPart)
    if not humanoid or not rootPart then return true end
    
    if humanoid.FloorMaterial == Enum.Material.Air then
        return true
    end
    
    if math.abs(rootPart.AssemblyLinearVelocity.Y) > 2 then
        return true
    end
    
    return false
end

local function CalculateDamage(partName, distance)
    local multiplier = DAMAGE_MULTIPLIERS[partName] or 0.5
    local damage = 54 * multiplier
    
    if distance > 300 then
        damage = damage * 0.3
    elseif distance > 200 then
        damage = damage * 0.5
    elseif distance > 100 then
        damage = damage * 0.8
    end
    
    return math.floor(damage)
end

local function CheckMinDamage(part, distance)
    if RageModule.Settings.MinDamage <= 0 then
        return true
    end
    
    local damage = CalculateDamage(part.Name, distance)
    return damage >= RageModule.Settings.MinDamage
end

local function SimpleResolver(player, rootPart)
    if not resolverData[player] then
        resolverData[player] = {missCount = 0, lastAngle = 0}
    end
    
    local data = resolverData[player]
    local currentAngle = math.deg(math.atan2(rootPart.CFrame.LookVector.X, rootPart.CFrame.LookVector.Z))
    
    if math.abs(currentAngle - data.lastAngle) > 45 then
        local resolveAngle = currentAngle + (data.missCount % 2 == 0 and 90 or -90)
        local radAngle = math.rad(resolveAngle)
        local lookVector = Vector3.new(math.sin(radAngle), 0, math.cos(radAngle))
        data.lastAngle = currentAngle
        return CFrame.new(rootPart.Position, rootPart.Position + lookVector)
    end
    
    return rootPart.CFrame
end

local function RecordMiss(player)
    if not resolverData[player] then
        resolverData[player] = {missCount = 0, lastAngle = 0}
    end
    resolverData[player].missCount = resolverData[player].missCount + 1
end

local function UpdatePlayerData()
    local now = tick()
    if now - playerDataTime < PLAYER_CACHE_INTERVAL then return end
    playerDataTime = now
    
    for k in pairs(playerData) do playerData[k] = nil end
    
    if not myHRP then return end
    local myPos = myHRP.Position
    local myTeam, myColor = LocalPlayer.Team, LocalPlayer.TeamColor
    local count = 0
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local c = p.Character
            if c then
                local h = c:FindFirstChild("Humanoid")
                local r = c:FindFirstChild("HumanoidRootPart")
                if h and h.Health > 0 and r then
                    local dist = (myPos - r.Position).Magnitude
                    if dist < 500 then
                        count = count + 1
                        local isTeam = myTeam and (p.Team == myTeam or p.TeamColor == myColor)
                        local inAir = IsInAir(h, r)
                        
                        playerData[count] = {
                            p = p, c = c, h = h, r = r,
                            head = c:FindFirstChild("Head"),
                            torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso"),
                            dist = dist, team = isTeam, inAir = inAir,
                            bestHitbox = GetBestHitbox(c, dist, inAir)
                        }
                    end
                end
            end
        end
    end
    
    table.sort(playerData, function(a, b)
        if a and b then
            return a.dist < b.dist
        end
        return false
    end)
end

function RageModule:Start()
    if connection then return end
    
    print("[Rage] Starting enhanced ragebot with nemesis improvements...")
    
    connection = RunService.Heartbeat:Connect(function()
        if not RageModule.Settings.Enabled then
            return
        end
        
        CacheChar()
        if not myChar or not myHRP or not myHead then return end
        
        UpdatePlayerData()
        
        local now = tick()
        
        if RageModule.Settings.AutoFire and now - lastShot >= 0.08 then
            RayP.FilterDescendantsInstances = {myChar}
            local best = nil
            local bestScore = -1
            
            for i = 1, 4 do
                local d = playerData[i]
                if d and not d.team and d.dist < 500 then
                    local tgt = d.bestHitbox
                    if not tgt then continue end
                    
                    if not IsPartVisible(tgt, d.c, myChar) then
                        continue
                    end
                    
                    if not CheckMinDamage(tgt, d.dist) then
                        continue
                    end
                    
                    if RageModule.Settings.HitChance < 100 then
                        local roll = math.random(1, 100)
                        if roll > RageModule.Settings.HitChance then
                            continue
                        end
                    end
                    
                    local damage = CalculateDamage(tgt.Name, d.dist)
                    local score = damage - d.dist * 0.02
                    
                    if d.inAir then
                        score = score + 50
                    end
                    
                    if score > bestScore then
                        bestScore = score
                        best = d
                        best.targetPart = tgt
                        best.damage = damage
                    end
                end
            end
            
            if best then
                local fs = GetFireShot()
                if fs then
                    if aahelp then pcall(function() aahelp:FireServer("disable") end) end
                    if aahelp1 then pcall(function() aahelp1:FireServer("disable") end) end
                    
                    local shootPos = myHead.Position
                    local predictedPos = AdvancedPrediction(best.targetPart, best.r, best.dist)
                    local direction = (predictedPos - shootPos).Unit
                    
                    local success, err = pcall(function()
                        fs:FireServer(shootPos, direction, best.targetPart)
                    end)
                    
                    if success then
                        lastShot = now
                        currentTarget = best
                        
                        local statusText = best.inAir and " [AIRSHOT]" or ""
                        print("[Rage] Enhanced shot at", best.p.Name, "- Damage:", best.damage, "- Distance:", math.floor(best.dist), statusText)
                        
                        task.delay(0.25, function()
                            if best.h.Health < (best.h.MaxHealth * 0.8) then
                                print("[Rage] Hit confirmed!")
                            else
                                RecordMiss(best.p)
                                print("[Rage] Miss detected, adjusting resolver")
                            end
                        end)
                    else
                        warn("[Rage] Shot failed:", err)
                    end
                    
                    task.delay(0.05, function()
                        if aahelp then pcall(function() aahelp:FireServer("enable") end) end
                        if aahelp1 then pcall(function() aahelp1:FireServer("enable") end) end
                    end)
                end
            end
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
    
    for player, _ in pairs(resolverData) do
        resolverData[player] = nil
    end
    
    print("[Rage] Optimized ragebot stopped")
end

function RageModule:GetCurrentTarget()
    return currentTarget
end

Players.PlayerRemoving:Connect(function(player)
    if resolverData[player] then
        resolverData[player] = nil
    end
end)

return RageModule
