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
    if vel.Magnitude < 1 then
        return targetPart.Position
    end
    
    local ping = LocalPlayer:GetNetworkPing()
    local bulletTime = distance / 2000
    local totalTime = ping + bulletTime
    
    local predictionStrength = 0.165
    if vel.Magnitude > 10 then
        predictionStrength = predictionStrength * 1.2
    end
    
    return targetPart.Position + vel * totalTime * predictionStrength
end

local function GetBestHitbox(character, distance)
    if distance < 150 then
        return character:FindFirstChild("Head")
    elseif distance < 300 then
        return character:FindFirstChild("Head") or character:FindFirstChild("UpperTorso")
    else
        return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
    end
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
                        
                        playerData[count] = {
                            p = p, c = c, h = h, r = r,
                            head = c:FindFirstChild("Head"),
                            torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso"),
                            dist = dist, team = isTeam,
                            bestHitbox = GetBestHitbox(c, dist)
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
    
    print("[Rage] Starting optimized ragebot...")
    
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
            
            for i = 1, 4 do
                local d = playerData[i]
                if d and not d.team and d.dist < 500 then
                    local tgt = d.bestHitbox or d.head or d.torso or d.r
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
                            best = d
                            best.predictedPos = predictedPos
                            best.targetPart = tgt
                            break
                        end
                    end
                end
            end
            
            if best then
                local fs = GetFireShot()
                if fs then
                    if aahelp then pcall(function() aahelp:FireServer("disable") end) end
                    if aahelp1 then pcall(function() aahelp1:FireServer("disable") end) end
                    
                    local shootPos = myHead.Position
                    local targetPos = best.predictedPos
                    local direction = (targetPos - shootPos).Unit
                    
                    local success, err = pcall(function()
                        fs:FireServer(shootPos, direction, best.targetPart)
                    end)
                    
                    if success then
                        lastShot = now
                        currentTarget = best
                        print("[Rage] Shot at", best.p.Name, "- Distance:", math.floor(best.dist))
                        
                        task.delay(0.3, function()
                            if best.h.Health < (best.h.MaxHealth * 0.8) then
                                print("[Rage] Hit confirmed!")
                            else
                                RecordMiss(best.p)
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
