local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

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

local function GetMultipointPositions(part, scale)
    if not part or not part:IsA("BasePart") then
        return {part.Position}
    end

    local clampedScale = math.clamp(scale, 0, 100)
    if clampedScale <= 0 then
        return {part.Position}
    end

    local points = {}
    table.insert(points, part.Position)

    local level = math.ceil(clampedScale / 25)

    if clampedScale > 25 then
        local offset = (part.Size * (clampedScale / 100)) / 2

        table.insert(points, part.Position + part.CFrame.RightVector * offset.X * 0.5)
        table.insert(points, part.Position - part.CFrame.RightVector * offset.X * 0.5)

        if level >= 2 then
            table.insert(points, part.Position + part.CFrame.UpVector * offset.Y * 0.5)
            table.insert(points, part.Position - part.CFrame.UpVector * offset.Y * 0.5)
        end

        if level >= 3 then
            table.insert(points, part.Position + part.CFrame.LookVector * offset.Z * 0.5)
            table.insert(points, part.Position - part.CFrame.LookVector * offset.Z * 0.5)
        end

        if level >= 4 then
            table.insert(points, part.Position + part.CFrame.RightVector * offset.X * 0.7 + part.CFrame.UpVector * offset.Y * 0.7)
            table.insert(points, part.Position - part.CFrame.RightVector * offset.X * 0.7 - part.CFrame.UpVector * offset.Y * 0.7)
        end
    end

    return points
end

local function FindBestMultipointPosition(part, targetChar, scale)
    if not RageModule.Settings.Multipoint or not part or not myHead then
        return part and part.Position or Vector3.new()
    end

    local points = GetMultipointPositions(part, scale * 100)

    for _, point in ipairs(points) do
        local dir = point - myHead.Position
        RayP.FilterDescendantsInstances = {myChar}
        local res = Workspace:Raycast(myHead.Position, dir, RayP)

        if not res or res.Instance:IsDescendantOf(targetChar) then
            return point
        end
    end

    return part.Position
end

local function AdvancedPrediction(targetPart, rootPart, distance)
    local vel = rootPart.AssemblyLinearVelocity
    if vel.Magnitude < 1 then
        return targetPart.Position
    end

    local bulletSpeed = 2000
    local travelTime = distance / bulletSpeed
    local pingTime = LocalPlayer:GetNetworkPing()
    local totalTime = math.clamp(pingTime + travelTime, 0.05, 0.2)

    local predictionStrength = 1.0
    if vel.Magnitude > 10 then
        predictionStrength = 1.15
    end
    if vel.Magnitude > 20 then
        predictionStrength = 1.25
    end

    return targetPart.Position + (vel * totalTime * predictionStrength)
end

local function GetBestHitbox(character, distance, isInAir)
    if isInAir then
        local head = character:FindFirstChild("Head")
        if head and IsPartVisible(head, character, myChar) then
            return head
        end
    end

    local priorities = {}

    if distance < 150 then
        if RageModule.Settings.Hitboxes.Head then
            table.insert(priorities, "Head")
        end
        if RageModule.Settings.Hitboxes.Body then
            table.insert(priorities, "UpperTorso")
            table.insert(priorities, "LowerTorso")
            table.insert(priorities, "Torso")
        end
    elseif distance < 300 then
        if RageModule.Settings.Hitboxes.Body then
            table.insert(priorities, "UpperTorso")
            table.insert(priorities, "Torso")
        end
        if RageModule.Settings.Hitboxes.Head then
            table.insert(priorities, "Head")
        end
        if RageModule.Settings.Hitboxes.Body then
            table.insert(priorities, "LowerTorso")
        end
    else
        if RageModule.Settings.Hitboxes.Body then
            table.insert(priorities, "UpperTorso")
            table.insert(priorities, "Torso")
            table.insert(priorities, "HumanoidRootPart")
        end
        if RageModule.Settings.Hitboxes.Head then
            table.insert(priorities, "Head")
        end
    end

    for _, partName in ipairs(priorities) do
        local part = character:FindFirstChild(partName)
        if part and IsPartVisible(part, character, myChar) then
            return part
        end
    end

    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
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
    
    print("[Rage] Starting enhanced ragebot with multipoint system...")
    
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
            local bestPoint = nil

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

                    local predictedPos = AdvancedPrediction(tgt, d.r, d.dist)

                    local multipointPos = predictedPos
                    if RageModule.Settings.Multipoint then
                        multipointPos = FindBestMultipointPosition(tgt, d.c, RageModule.Settings.MultipointScale)
                        local mpOffset = multipointPos - tgt.Position
                        predictedPos = predictedPos + mpOffset
                    end

                    local dir = predictedPos - myHead.Position
                    RayP.FilterDescendantsInstances = {myChar}
                    local res = Workspace:Raycast(myHead.Position, dir, RayP)

                    if RageModule.Settings.WallCheck then
                        if res and not res.Instance:IsDescendantOf(d.c) then
                            continue
                        end
                    end

                    if not res or res.Instance:IsDescendantOf(d.c) then
                        local damage = CalculateDamage(tgt.Name, d.dist)
                        local score = damage - d.dist * 0.01

                        if d.inAir then
                            score = score + 100
                        end

                        if tgt.Name == "Head" then
                            score = score + 50
                        end

                        if RageModule.Settings.Multipoint then
                            score = score + 15
                        end

                        if score > bestScore then
                            bestScore = score
                            best = d
                            best.targetPart = tgt
                            best.damage = damage
                            bestPoint = predictedPos
                        end
                    end
                end
            end

            if best and bestPoint then
                local fs = GetFireShot()
                if fs then
                    if aahelp then pcall(function() aahelp:FireServer("disable") end) end
                    if aahelp1 then pcall(function() aahelp1:FireServer("disable") end) end

                    local shootPos = myHead.Position
                    local direction = (bestPoint - shootPos).Unit

                    local success, err = pcall(function()
                        fs:FireServer(shootPos, direction, best.targetPart)
                    end)

                    if success then
                        lastShot = now
                        currentTarget = best

                        local statusText = ""
                        if best.inAir then statusText = statusText .. " [AIRSHOT]" end
                        if RageModule.Settings.Multipoint then statusText = statusText .. " [MP]" end

                        print("[Rage] Shot at", best.p.Name, "- Damage:", best.damage, "- Distance:", math.floor(best.dist), statusText)

                        task.delay(0.25, function()
                            if best.h and best.h.Parent and best.h.Health < (best.h.MaxHealth * 0.8) then
                                print("[Rage] ✓ Hit confirmed!")
                            else
                                RecordMiss(best.p)
                                print("[Rage] ✗ Miss detected, adjusting...")
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
