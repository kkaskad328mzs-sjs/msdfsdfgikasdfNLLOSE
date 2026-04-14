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

local function InitializeResolverData(player)
    if not resolverData[player] then
        resolverData[player] = {
            lastPositions = {},
            velocityHistory = {},
            angleHistory = {},
            missCount = 0,
            hitCount = 0,
            lastMissTime = 0,
            resolverMode = "normal",
            fakeAngle = 0,
            realAngle = 0,
            isAntiAiming = false,
            lastUpdateTime = 0,
            predictedPosition = Vector3.new(),
            confidence = 0
        }
    end
end

local function UpdateResolverData(player, rootPart)
    InitializeResolverData(player)
    local data = resolverData[player]
    local now = tick()
    
    if now - data.lastUpdateTime < 0.05 then return end
    data.lastUpdateTime = now
    
    local pos = rootPart.Position
    local vel = rootPart.AssemblyLinearVelocity
    local angle = math.deg(math.atan2(rootPart.CFrame.LookVector.X, rootPart.CFrame.LookVector.Z))
    
    table.insert(data.lastPositions, {pos = pos, time = now})
    table.insert(data.velocityHistory, {vel = vel, time = now})
    table.insert(data.angleHistory, {angle = angle, time = now})
    
    if #data.lastPositions > 10 then
        table.remove(data.lastPositions, 1)
    end
    if #data.velocityHistory > 8 then
        table.remove(data.velocityHistory, 1)
    end
    if #data.angleHistory > 6 then
        table.remove(data.angleHistory, 1)
    end
    
    if #data.angleHistory >= 3 then
        local angleDiff1 = math.abs(data.angleHistory[#data.angleHistory].angle - data.angleHistory[#data.angleHistory-1].angle)
        local angleDiff2 = math.abs(data.angleHistory[#data.angleHistory-1].angle - data.angleHistory[#data.angleHistory-2].angle)
        
        data.isAntiAiming = angleDiff1 > 45 or angleDiff2 > 45
        
        if data.isAntiAiming then
            data.fakeAngle = data.angleHistory[#data.angleHistory].angle
            if #data.angleHistory >= 4 then
                data.realAngle = data.angleHistory[#data.angleHistory-2].angle
            end
        end
    end
    
    data.confidence = math.min(100, data.hitCount * 10 - data.missCount * 5)
end

local function ResolveAntiAim(player, rootPart)
    if not RageModule.Settings.Resolver then
        return rootPart.CFrame
    end
    
    InitializeResolverData(player)
    local data = resolverData[player]
    
    if not data.isAntiAiming then
        return rootPart.CFrame
    end
    
    local resolvedAngle = data.realAngle
    
    if RageModule.Settings.ResolverMode == "Smart" then
        if data.missCount > 2 then
            resolvedAngle = data.fakeAngle + (math.random(-30, 30))
        elseif data.confidence < 30 then
            resolvedAngle = data.realAngle + (math.random(-15, 15))
        end
    elseif RageModule.Settings.ResolverMode == "Bruteforce" then
        local modes = {0, 90, -90, 45, -45, 180}
        resolvedAngle = data.fakeAngle + modes[(data.missCount % #modes) + 1]
    end
    
    local radAngle = math.rad(resolvedAngle)
    local lookVector = Vector3.new(math.sin(radAngle), 0, math.cos(radAngle))
    
    return CFrame.new(rootPart.Position, rootPart.Position + lookVector)
end

local function AdvancedPrediction(targetPart, rootPart, distance)
    if not RageModule.Settings.AdvancedPrediction then
        return targetPart.Position
    end
    
    local vel = rootPart.AssemblyLinearVelocity
    if vel.Magnitude < 1 then
        return targetPart.Position
    end
    
    local ping = LocalPlayer:GetNetworkPing()
    local bulletTime = distance / 2000
    local totalTime = ping + bulletTime
    
    local predictionStrength = RageModule.Settings.PredictionStrength
    
    if RageModule.Settings.VelocityResolver then
        local player = Players:GetPlayerFromCharacter(rootPart.Parent)
        if player and resolverData[player] then
            local data = resolverData[player]
            if #data.velocityHistory >= 3 then
                local avgVel = Vector3.new()
                for i = math.max(1, #data.velocityHistory - 2), #data.velocityHistory do
                    avgVel = avgVel + data.velocityHistory[i].vel
                end
                avgVel = avgVel / 3
                vel = avgVel
            end
        end
        predictionStrength = predictionStrength * 1.3
    end
    
    local predictedPos = targetPart.Position + vel * totalTime * predictionStrength
    
    if distance > 200 then
        predictedPos = predictedPos + Vector3.new(0, -0.5 * totalTime * totalTime, 0)
    end
    
    return predictedPos
end

local function GetSmartHitbox(player, character, distance)
    if not RageModule.Settings.SmartHitbox then
        if RageModule.Settings.Hitboxes.Head then
            return character:FindFirstChild("Head")
        elseif RageModule.Settings.Hitboxes.Body then
            return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
        end
        return character:FindFirstChild("HumanoidRootPart")
    end
    
    InitializeResolverData(player)
    local data = resolverData[player]
    
    if distance < 100 and data.confidence > 70 then
        return character:FindFirstChild("Head")
    elseif distance < 200 and data.confidence > 50 then
        return character:FindFirstChild("Head") or character:FindFirstChild("UpperTorso")
    else
        return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
    end
end

local function CalculateDamage(partName, distance)
    local baseDamage = 54
    local multiplier = DAMAGE_MULTIPLIERS[partName] or 0.5
    local damage = baseDamage * multiplier
    
    if distance > 300 then
        damage = damage * 0.3
    elseif distance > 200 then
        damage = damage * 0.5
    elseif distance > 100 then
        damage = damage * 0.8
    end
    
    return math.floor(damage)
end

local function DisableAntiAims()
    if RageModule.Settings.AntiAimBreaker then
        if aahelp then
            pcall(function() aahelp:FireServer("disable") end)
        end
        if aahelp1 then
            pcall(function() aahelp1:FireServer("disable") end)
        end
    end
end

local function EnableAntiAims()
    if RageModule.Settings.AntiAimBreaker then
        task.delay(0.1, function()
            if aahelp then
                pcall(function() aahelp:FireServer("enable") end)
            end
            if aahelp1 then
                pcall(function() aahelp1:FireServer("enable") end)
            end
        end)
    end
end

local function RecordHit(player, hit)
    InitializeResolverData(player)
    local data = resolverData[player]
    
    if hit then
        data.hitCount = data.hitCount + 1
        print("[Resolver] Hit confirmed on", player.Name, "- Confidence:", data.confidence)
    else
        data.missCount = data.missCount + 1
        data.lastMissTime = tick()
        print("[Resolver] Miss on", player.Name, "- Adjusting resolver")
    end
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
                    if dist < 600 then
                        count = count + 1
                        local isTeam = myTeam and (p.Team == myTeam or p.TeamColor == myColor)
                        
                        UpdateResolverData(p, r)
                        
                        playerData[count] = {
                            p = p, c = c, h = h, r = r,
                            head = c:FindFirstChild("Head"),
                            torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso"),
                            dist = dist, team = isTeam,
                            smartHitbox = GetSmartHitbox(p, c, dist),
                            resolvedCFrame = ResolveAntiAim(p, r)
                        }
                    end
                end
            end
        end
    end
    
    for i = 1, count - 1 do
        for j = i + 1, count do
            if playerData[j] and playerData[i] and playerData[j].dist < playerData[i].dist then
                playerData[i], playerData[j] = playerData[j], playerData[i]
            end
        end
    end
end

function RageModule:Start()
    if connection then return end
    
    print("[Rage] Starting advanced ragebot with resolver...")
    
    connection = RunService.Heartbeat:Connect(function()
        if not RageModule.Settings.Enabled then
            return
        end
        
        CacheChar()
        if not myChar or not myHRP or not myHead then return end
        
        UpdatePlayerData()
        
        local now = tick()
        local fireRate = RageModule.Settings.AdaptiveFireRate and 0.08 or 0.1
        
        if RageModule.Settings.AutoFire and now - lastShot >= fireRate then
            RayP.FilterDescendantsInstances = {myChar}
            local best = nil
            local bestScore = -1
            
            for i = 1, 6 do
                local d = playerData[i]
                if d and not d.team and d.dist < 500 then
                    local tgt = d.smartHitbox or d.head or d.torso or d.r
                    if tgt then
                        local predictedPos = AdvancedPrediction(tgt, d.r, d.dist)
                        local dir = predictedPos - myHead.Position
                        local res = Workspace:Raycast(myHead.Position, dir, RayP)
                        
                        if RageModule.Settings.WallCheck then
                            if res and not res.Instance:IsDescendantOf(d.c) then
                                continue
                            end
                        end
                        
                        if not res or res.Instance:IsDescendantOf(d.c) then
                            local damage = CalculateDamage(tgt.Name, d.dist)
                            local score = damage - d.dist * 0.05
                            
                            if RageModule.Settings.MinDamage > 0 and damage < RageModule.Settings.MinDamage then
                                continue
                            end
                            
                            if resolverData[d.p] then
                                score = score + resolverData[d.p].confidence * 0.1
                            end
                            
                            if score > bestScore then
                                bestScore = score
                                best = d
                                best.predictedPos = predictedPos
                                best.targetPart = tgt
                                best.damage = damage
                            end
                        end
                    end
                end
            end
            
            if best then
                local fs = GetFireShot()
                if fs then
                    DisableAntiAims()
                    
                    local shootPos = myHead.Position
                    local targetPos = best.predictedPos
                    local direction = (targetPos - shootPos).Unit
                    
                    print("[Rage] Advanced shot at", best.p.Name, "- Damage:", best.damage, "- Distance:", math.floor(best.dist))
                    
                    local success, err = pcall(function()
                        fs:FireServer(shootPos, direction, best.targetPart)
                    end)
                    
                    if success then
                        lastShot = now
                        currentTarget = best
                        
                        task.delay(0.2, function()
                            local hit = best.h.Health < (best.h.MaxHealth * 0.9)
                            RecordHit(best.p, hit)
                        end)
                        
                        print("[Rage] Shot fired successfully! Target:", best.targetPart.Name)
                    else
                        warn("[Rage] Shot failed:", err)
                    end
                    
                    EnableAntiAims()
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
    
    print("[Rage] Advanced ragebot stopped - Resolver data cleared")
end

function RageModule:GetCurrentTarget()
    return currentTarget
end

function RageModule:GetResolverData()
    return resolverData
end

function RageModule:GetPlayerStats(player)
    if resolverData[player] then
        return {
            hitRate = resolverData[player].hitCount / math.max(1, resolverData[player].hitCount + resolverData[player].missCount) * 100,
            confidence = resolverData[player].confidence,
            isAntiAiming = resolverData[player].isAntiAiming,
            resolverMode = resolverData[player].resolverMode
        }
    end
    return nil
end

Players.PlayerRemoving:Connect(function(player)
    if resolverData[player] then
        resolverData[player] = nil
        print("[Resolver] Cleared data for", player.Name)
    end
end)

return RageModule
