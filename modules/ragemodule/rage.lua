-- NEVERLOSE RAGE MODULE v2.0 (Optimized for Mirage HvH)
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
    AimThroughWalls = true, -- Теперь работает корректно с hamik/paletka
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

-- Служебные переменные
local lastShot = 0
local currentTarget = nil
local connection = nil
local playerCache = {}
local cacheUpdateTime = 0

local myChar, myHead, myHRP, myHum = nil, nil, nil, nil
local fireShotRemote = nil
local remoteCheckTime = 0

-- Anti-Aim Remotes (специфика Mirage)
local aahelp = ReplicatedStorage:WaitForChild("aahelp", 5)
local aahelp1 = ReplicatedStorage:WaitForChild("aahelp1", 5)

-- Raycast параметры
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

-- ==================== УТИЛИТЫ ====================

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

-- Умный WallCheck с пробитием (из gameragebot)
local function CanBulletPassThrough(part)
    if not part or not part:IsA("BasePart") then return false end
    if part:IsA("WedgePart") then return true end
    
    local nameLower = part.Name:lower()
    if nameLower:find("hamik") or nameLower:find("paletka") then return true end
    if part.Parent and part.Parent.Name:lower():find("hamik") then return true end
    
    if part.Transparency > 0.2 then return true end
    if not part.CanCollide then return true end
    if part:IsA("Decal") or part:IsA("ParticleEmitter") or part:IsA("Trail") then return true end
    
    return false
end

local function IsPartOfCharacter(inst)
    if not inst or not inst.Parent then return false end
    if inst.Parent:FindFirstChild("Humanoid") then return true end
    if inst.Parent:IsA("Accessory") or inst.Parent:IsA("Hat") then return true end
    return false
end

-- Проверка видимости точки с учетом пробития стен
local function IsPointVisible(origin, targetPos, targetChar)
    local dir = targetPos - origin
    local dist = dir.Magnitude
    if dist < 0.1 or dist > 500 then return false end

    RayP.FilterDescendantsInstances = {myChar}
    local result = Workspace:Raycast(origin, dir, RayP)

    if not result then return true end
    if result.Instance:IsDescendantOf(targetChar) then return true end
    
    -- Логика пробития
    if CanBulletPassThrough(result.Instance) or IsPartOfCharacter(result.Instance) then
        local newPos = result.Position + dir.Unit * 0.1
        local newDir = targetPos - newPos
        if newDir.Magnitude < 0.1 then return true end
        
        RayP.FilterDescendantsInstances = {myChar, result.Instance}
        local secondResult = Workspace:Raycast(newPos, newDir, RayP)
        
        if not secondResult then return true end
        if secondResult.Instance:IsDescendantOf(targetChar) then return true end
    end
    
    return false
end

-- Генерация Multipoint точек
local function GetMultipointPositions(part, scale)
    if not part or not part:IsA("BasePart") then return {part.Position} end
    local clampedScale = math.clamp(scale, 0, 100)
    if clampedScale <= 0 then return {part.Position} end

    local points = {part.Position}
    local offset = (part.Size * (clampedScale / 100)) / 2

    table.insert(points, part.Position + part.CFrame.RightVector * offset.X * 0.5)
    table.insert(points, part.Position - part.CFrame.RightVector * offset.X * 0.5)
    table.insert(points, part.Position + part.CFrame.UpVector * offset.Y * 0.5)
    table.insert(points, part.Position - part.CFrame.UpVector * offset.Y * 0.5)

    if clampedScale > 50 then
        table.insert(points, part.Position + part.CFrame.RightVector * offset.X * 0.7 + part.CFrame.UpVector * offset.Y * 0.7)
        table.insert(points, part.Position - part.CFrame.RightVector * offset.X * 0.7 - part.CFrame.UpVector * offset.Y * 0.7)
    end
    return points
end

-- Пинг-зависимая предикция (как в arcanum, но улучшенная)
local function PredictPosition(part, rootPart)
    if not RageModule.Settings.Prediction or not rootPart then return part.Position end
    
    local vel = rootPart.AssemblyLinearVelocity
    if vel.Magnitude < 3 then return part.Position end

    local ping = LocalPlayer:GetNetworkPing()
    -- Предсказываем только X и Z (Y часто ломается из-за гравитации и десинка)
    local predicted = part.Position + Vector3.new(vel.X, vel.Y * 0.1, vel.Z) * ping * 1.2
    
    return predicted
end

local function CalculateDamage(partName, distance)
    local multiplier = DAMAGE_MULTIPLIERS[partName] or 0.5
    local damage = 54 * multiplier
    if distance > 300 then damage = damage * 0.3
    elseif distance > 200 then damage = damage * 0.5
    elseif distance > 100 then damage = damage * 0.8 end
    return math.floor(damage)
end

-- Брейк Anti-Aim (выключение деспинча)
local function BreakAntiAim(state)
    if not RageModule.Settings.AntiAimBreaker then return end
    if aahelp then pcall(function() aahelp:FireServer(state) end) end
    if aahelp1 then pcall(function() aahelp1:FireServer(state) end) end
end

-- Авто-стоп (остановка перед выстрелом)
local function ApplyAutoStop()
    if not RageModule.Settings.AutoStop or not myHRP or not myHum then return false end
    if myHum.FloorMaterial == Enum.Material.Air then return false end -- Не в воздухе
    
    local vel = myHRP.AssemblyLinearVelocity
    if Vector3.new(vel.X, 0, vel.Z).Magnitude < 1 then return false end -- Уже стоим

    myHRP.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
    return true
end

-- ==================== КАШИРОВАНИЕ ИГРОКОВ ====================

local function UpdatePlayerCache()
    local now = tick()
    if now - cacheUpdateTime < 0.2 then return end
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
    
    -- Сортировка по дистанции (ближайшие первыми)
    table.sort(playerCache, function(a, b) return a.dist < b.dist end)
end

-- Выбор хитбокса
local function GetTargetPart(data)
    if RageModule.Settings.Hitboxes.Head and data.head then return data.head end
    if RageModule.Settings.Hitboxes.Body and data.torso then return data.torso end
    return data.r
end

-- ==================== ГЛАВНЫЙ ЦИКЛ ====================

function RageModule:Start()
    if connection then return end
    print("[Rage] Starting Neverlose Enhanced Ragebot...")
    
    connection = RunService.Heartbeat:Connect(function()
        if not RageModule.Settings.Enabled then return end
        
        CacheLocalPlayer()
        if not myChar or not myHRP or not myHead then return end
        
        UpdatePlayerCache()
        
        local now = tick()
        -- Ограничение скорости стрельбы (адаптивное)
        local fireRate = RageModule.Settings.AdaptiveFireRate and 0.08 or 0.1
        if now - lastShot < fireRate then return end
        
        local fs = GetFireShotRemote()
        if not fs then return end

        local bestTarget = nil
        local bestPoint = nil
        local bestPart = nil
        local bestScore = -1

        -- Ищем цель среди 5 ближайших
        for i = 1, math.min(5, #playerCache) do
            local data = playerCache[i]
            if not data then continue end

            local targetPart = GetTargetPart(data)
            if not targetPart then continue end

            -- Проверка минимального урона
            local dmg = CalculateDamage(targetPart.Name, data.dist)
            if RageModule.Settings.MinDamage > 0 and dmg < RageModule.Settings.MinDamage then continue end

            -- Хитчанс (симуляция)
            if RageModule.Settings.HitChance < 100 and math.random(1, 100) > RageModule.Settings.HitChance then
                continue
            end

            -- Предикция
            local predictedPos = PredictPosition(targetPart, data.r)

            -- Ищем лучшую мультипойнт точку
            local pointsToCheck = {predictedPos}
            if RageModule.Settings.Multipoint then
                pointsToCheck = GetMultipointPositions(targetPart, RageModule.Settings.MultipointScale * 100)
                -- Сдвигаем мультипойнт точки на предикцию
                local delta = predictedPos - targetPart.Position
                for j = 1, #pointsToCheck do
                    pointsToCheck[j] = pointsToCheck[j] + delta
                end
            end

            for _, point in ipairs(pointsToCheck) do
                local isVisible = false
                
                if RageModule.Settings.WallCheck then
                    isVisible = IsPointVisible(myHead.Position, point, data.c)
                else
                    -- Если WallCheck выключен, стреляем в любую точку (даже в стены)
                    isVisible = true
                end

                if isVisible then
                    -- Скоринг: Урон - Дистанция + Бонус за голову
                    local score = (dmg * 10) - (data.dist * 0.1)
                    if targetPart.Name == "Head" then score = score + 500 end
                    
                    if score > bestScore then
                        bestScore = score
                        bestTarget = data
                        bestPoint = point
                        bestPart = targetPart
                    end
                    break -- Нашли видимую точку для этой части, идем к следующему игроку
                end
            end
        end

        -- ==================== ВЫСТРЕЛ ====================
        if bestTarget and bestPoint then
            -- 1. Фейкдук пауза
            if _G.FakeDuckActive then
                _G.FakeDuckPause = true
                task.wait(0.15)
                if not myHead then 
                    if _G.FakeDuckActive then _G.FakeDuckPause = false end
                    return 
                end
            end

            -- 2. Авто-стоп
            ApplyAutoStop()

            -- 3. Выключаем Анти-Аим
            BreakAntiAim("disable")
            
            -- Небольшая задержка для синхронизации с сервером (критично для Mirage)
            task.wait(0.01)

            -- 4. Вычисление направления и стрельба
            local shootOrigin = myHead.Position
            local direction = (bestPoint - shootOrigin).Unit

            local success, err = pcall(function()
                fs:FireServer(shootOrigin, direction, bestPart)
            end)

            if success then
                lastShot = now
                currentTarget = bestTarget
                currentTarget.targetPart = bestPart
            end

            -- 5. Возвращаем Анти-Аим
            task.delay(0.05, function()
                BreakAntiAim("enable")
                if _G.FakeDuckActive then _G.FakeDuckPause = false end
            end)
        end
    end)
end

function RageModule:Stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    currentTarget = nil
    BreakAntiAim("enable") -- Обязательно возвращаем АА при выключении
    print("[Rage] Neverlose Ragebot stopped")
end

function RageModule:GetCurrentTarget()
    return currentTarget
end

-- Очистка при уходе игрока
Players.PlayerRemoving:Connect(function(player)
    if currentTarget and currentTarget.p == player then
        currentTarget = nil
    end
end)

return RageModule
