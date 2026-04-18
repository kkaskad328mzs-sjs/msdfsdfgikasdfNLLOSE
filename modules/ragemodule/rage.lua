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
    Hitboxes = {Head = true, Body = false},
    Prediction = true,
    PredictionStrength = 1.0,
    WallCheck = false,
    TargetMode = "Closest"
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

local PLAYER_CACHE_INTERVAL = 0.4

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
                        playerData[count] = {
                            p = p, c = c, h = h, r = r,
                            head = c:FindFirstChild("Head"),
                            torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso"),
                            dist = dist, team = isTeam
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

    print("[Rage] Starting Arcanum-based ragebot...")

    connection = RunService.Heartbeat:Connect(function()
        if not RageModule.Settings.Enabled then
            return
        end

        CacheChar()
        if not myChar or not myHRP or not myHead then return end

        UpdatePlayerData()

        local now = tick()

        if RageModule.Settings.AutoFire and now - lastShot >= 0.1 then
            RayP.FilterDescendantsInstances = {myChar}
            local best = nil

            for i = 1, 4 do
                local d = playerData[i]
                if d and not d.team and d.dist < 500 then
                    local tgt = RageModule.Settings.Hitboxes.Head and d.head or d.torso or d.r
                    if tgt then
                        local dir = tgt.Position - myHead.Position
                        local res = Workspace:Raycast(myHead.Position, dir, RayP)

                        if RageModule.Settings.WallCheck then
                            if res and not res.Instance:IsDescendantOf(d.c) then
                                continue
                            end
                        end

                        if not res or res.Instance:IsDescendantOf(d.c) then
                            best = d
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

                    local tgt = RageModule.Settings.Hitboxes.Head and best.head or best.torso or best.r
                    local vel = best.r.AssemblyLinearVelocity
                    local pos = tgt.Position

                    if RageModule.Settings.Prediction and vel.Magnitude > 1 then
                        pos = pos + Vector3.new(vel.X, 0, vel.Z) * LocalPlayer:GetNetworkPing() * RageModule.Settings.PredictionStrength
                    end

                    local success = pcall(function()
                        fs:FireServer(myHead.Position, (pos - myHead.Position).Unit, tgt)
                    end)

                    if success then
                        lastShot = now
                        currentTarget = best
                        print("[Rage] Shot:", best.p.Name, "Dist:", math.floor(best.dist))
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

    print("[Rage] Ragebot stopped")
end

function RageModule:GetCurrentTarget()
    return currentTarget
end

return RageModule
