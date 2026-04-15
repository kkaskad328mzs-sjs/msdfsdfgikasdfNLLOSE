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
    MultipointScale = 0.5,
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
local playerCache = {}
local cacheUpdateTime = 0
local frame = 0

local myChar, myHead, myHRP, myHum = nil, nil, nil, nil
local fireShotRemote = nil
local remoteCheckTime = 0

local aahelp = ReplicatedStorage:WaitForChild("aahelp", 5)
local aahelp1 = ReplicatedStorage:WaitForChild("aahelp1", 5)

local RayP = RaycastParams.new()
RayP.FilterType = Enum.RaycastFilterType.Exclude
RayP.IgnoreWater = true

local DAMAGE_MULTIPLIERS = {
    Head = 4, UpperTorso = 1, LowerTorso = 1, Torso = 1, HumanoidRootPart = 1,
    LeftUpperArm = 0.75, LeftLowerArm = 0.75, LeftHand = 0.75,
    RightUpperArm = 0.75, RightLowerArm = 0.75, RightHand = 0.75,
    LeftUpperLeg = 0.6, LeftLowerLeg = 0.6, LeftFoot = 0.6,
    RightUpperLeg = 0.6, RightLowerLeg = 0.6, RightFoot = 0.6,
    ["Left Leg"] = 0.6, ["Right Leg"] = 0.6
}
local function CacheLocalPlayer()
    local c = LocalPlayer.Character
    if c then
        myChar = c
        myHRP = c:FindFirstChild("HumanoidRootPart")
        myHead = c:FindFirstChild("Head")
        myHum = c:FindFirstChild("Humanoid")
    else
        myChar, myHRP, myHead, myHum = nil, nil, nil, nil
    end
end

local function GetFireShotRemote()
    local now = tick()
    if fireShotRemote and fireShotRemote.Parent and now - remoteCheckTime < 5 then
        return fireShotRemote
    end
    if not myChar then return nil end
    
    for _, child in ipairs(myChar:GetChildren()) do
        if child:IsA("Tool") then
            local remotes = child:FindFirstChild("Remotes")
            if remotes then
                local fs = remotes:FindFirstChild("FireShot") or remotes:FindFirstChild("fireShot")
                if fs then
                    fireShotRemote, remoteCheckTime = fs, now
                    return fs
                end
            end
        end
    end
    return nil
end

local function CalculateDamage(partName, distance)
    local multiplier = DAMAGE_MULTIPLIERS[partName] or 0.5
    local damage = 54 * multiplier
    if distance > 300 then damage = damage * 0.3
    elseif distance > 200 then damage = damage * 0.5
    elseif distance > 100 then damage = damage * 0.8 end
    return math.floor(damage)
end

local function BreakAntiAim(state)
    if not RageModule.Settings.AntiAimBreaker then return end
    if aahelp then pcall(function() aahelp:FireServer(state) end) end
    if aahelp1 then pcall(function() aahelp1:FireServer(state) end) end
end


local function UpdatePlayerCache()
    local now = tick()
    if now - cacheUpdateTime < 0.4 then return end 
    cacheUpdateTime = now
    
    table.clear(playerCache)
    if not myHRP then return end
    
    local myPos = myHRP.Position
    local myTeam = LocalPlayer.Team
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local c = p.Character
            if c then
                local h = c:FindFirstChild("Humanoid")
                local r = c:FindFirstChild("HumanoidRootPart")
                if h and h.Health > 0 and r then
                    local dist = (myPos - r.Position).Magnitude
                    if dist < 500 and (not myTeam or p.Team ~= myTeam) then
                        table.insert(playerCache, {
                            p = p, c = c, h = h, r = r,
                            head = c:FindFirstChild("Head"),
                            torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso"),
                            dist = dist
                        })
                    end
                end
            end
        end
    end
    
    table.sort(playerCache, function(a, b) return a.dist < b.dist end)
end

-- ==================== ГЛАВНЫЙ ЦИКЛ ====================

function RageModule:Start()
    if connection then return end
    print("[Rage] Starting Arcanum-Sync Ragebot...")
    
    connection = RunService.Heartbeat:Connect(function(dt)
        if not RageModule.Settings.Enabled then return end
        
        frame = frame + 1
        if frame % 15 == 0 then CacheLocalPlayer() end -- Редкое обновление персонажа экономит FPS
        if not myChar or not myHRP or not myHead then return end
        
        if frame % 3 ~= 0 then return end
        
        local now = tick()
        if now - lastShot < 0.1 then return end
        
        local fs = GetFireShotRemote()
        if not fs then return end

        UpdatePlayerCache()

        local best = nil
        local bestTgt = nil
        local bestPos = nil
        for i = 1, math.min(4, #playerCache) do
            local d = playerCache[i]
            if not d then continue end

            -- Выбор хитбокса
            local tgt = nil
            if RageModule.Settings.Hitboxes.Head and d.head then
                tgt = d.head
            elseif RageModule.Settings.Hitboxes.Body and d.torso then
                tgt = d.torso
            else
                tgt = d.r
            end

            if not tgt then continue end

            -- Проверка MinDamage (мгновенная)
            if RageModule.Settings.MinDamage > 0 then
                if CalculateDamage(tgt.Name, d.dist) < RageModule.Settings.MinDamage then continue end
            end

            local vel = d.r.AssemblyLinearVelocity
            local pos = tgt.Position
            
            if vel.Magnitude > 1 then
                local ping = LocalPlayer:GetNetworkPing()
                -- Множитель подстраивается под ползунок в панели
                local predMulti = RageModule.Settings.PredictionStrength / 0.165 
                pos = pos + Vector3.new(vel.X, 0, vel.Z) * ping * predMulti
            end

            local dir = pos - myHead.Position
            RayP.FilterDescendantsInstances = {myChar}
            local res = Workspace:Raycast(myHead.Position, dir, RayP)

            local canShoot = false
            
            if RageModule.Settings.WallCheck then
                if res and res.Instance:IsDescendantOf(d.c) then
                    canShoot = true
                end
            else
                -- Если WallCheck выключен - стреляем в любую видимую цель
                if not res or res.Instance:IsDescendantOf(d.c) then
                    canShoot = true
                end
            end

            if canShoot then
                best = d
                bestTgt = tgt
                bestPos = pos
                break -- Нашли ближайшего видимого, берем его и выходим (быстрее всего)
            end
        end

        if best and bestPos then
            -- 1. FakeDuck обработка (синхронная)
            if _G.FakeDuckActive then
                _G.FakeDuckPause = true
            end

            -- 2. AutoStop (МГНОВЕННЫЙ, без task.wait)
            if RageModule.Settings.AutoStop and myHRP and myHum then
                if myHum.FloorMaterial ~= Enum.Material.Air then
                    myHRP.AssemblyLinearVelocity = Vector3.new(0, myHRP.AssemblyLinearVelocity.Y, 0)
                end
            end

            -- 3. Выключаем АА
            BreakAntiAim("disable")

            -- 4. ВЫСТРЕЛ
            pcall(fs.FireServer, fs, myHead.Position, (bestPos - myHead.Position).Unit, bestTgt)
            
            lastShot = now
            currentTarget = best
            currentTarget.targetPart = bestTgt

            -- 5. Сразу возвращаем АА в этом же кадре
            BreakAntiAim("enable")
            
            -- 6. Возвращаем FakeDuck
            if _G.FakeDuckActive then
                _G.FakeDuckPause = false
            end
        end
        
        -- Сброс кадров
        if frame > 1000 then frame = 0 end
    end)
end

function RageModule:Stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    currentTarget = nil
    BreakAntiAim("enable")
    print("[Rage] Ragebot stopped")
end

function RageModule:GetCurrentTarget()
    return currentTarget
end

Players.PlayerRemoving:Connect(function(player)
    if currentTarget and currentTarget.p == player then
        currentTarget = nil
    end
end)

return RageModule
