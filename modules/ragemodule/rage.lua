-- ARCANUM RAGEBOT - Adapted for Neverlose UI
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local RageModule = {}
RageModule.Settings = {
    Enabled = false,
    rbHitbox = "Head",
    rbMaxDist = 500,
    rbFireRate = 0.1,
    rbPredMulti = 1.0,
    rbPrediction = true,
    rbTeamCheck = true,
    rbAutoFire = true,
    rbNoAir = true,
    rbWallCheck = true,
}

local R = {
    myChar = nil,
    myHRP = nil,
    myHead = nil,
    myHum = nil,
    fireShot = nil,
    fireShotTime = 0,
    playerData = {},
    playerDataTime = 0,
    rbLast = 0,
    running = true,
}

local aahelp = ReplicatedStorage:WaitForChild("aahelp", 5)
local aahelp1 = ReplicatedStorage:WaitForChild("aahelp1", 5)

local RayP = RaycastParams.new()
RayP.FilterType = Enum.RaycastFilterType.Exclude
RayP.IgnoreWater = true

local TICK = tick
local V3_NEW = Vector3.new
local PLAYER_CACHE_INTERVAL = 0.4

local function CacheChar()
    local c = LocalPlayer.Character
    if c then
        R.myChar = c
        R.myHRP = c:FindFirstChild("HumanoidRootPart")
        R.myHead = c:FindFirstChild("Head")
        R.myHum = c:FindFirstChild("Humanoid")
    else
        R.myChar, R.myHRP, R.myHead, R.myHum = nil, nil, nil, nil
    end
end

local function GetFireShot()
    local now = TICK()
    if R.fireShot and R.fireShot.Parent and now - R.fireShotTime < 5 then
        return R.fireShot
    end
    if not R.myChar then return nil end

    for _, child in ipairs(R.myChar:GetChildren()) do
        if child:IsA("Tool") then
            local remotes = child:FindFirstChild("Remotes")
            if remotes then
                local fs = remotes:FindFirstChild("FireShot") or remotes:FindFirstChild("fireShot")
                if fs then
                    R.fireShot, R.fireShotTime = fs, now
                    return fs
                end
            end
        end
    end
    return nil
end

local function UpdatePlayerData()
    local now = TICK()
    if now - R.playerDataTime < PLAYER_CACHE_INTERVAL then return end
    R.playerDataTime = now

    for k in pairs(R.playerData) do R.playerData[k] = nil end

    if not R.myHRP then return end
    local myPos = R.myHRP.Position
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
                        R.playerData[count] = {
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
            if R.playerData[j] and R.playerData[i] and R.playerData[j].dist < R.playerData[i].dist then
                R.playerData[i], R.playerData[j] = R.playerData[j], R.playerData[i]
            end
        end
    end
end

local frame = 0
local connection = nil

function RageModule:Start()
    if connection then return end

    print("[Rage] Starting Arcanum ragebot...")
    R.running = true

    connection = RunService.Heartbeat:Connect(function()
        if not RageModule.Settings.Enabled then
            return
        end

        frame = frame + 1

        if frame % 15 == 0 then CacheChar() end
        if not R.myChar or not R.myHRP then return end

        UpdatePlayerData()

        local now = TICK()
        local head = R.myHead

        -- RAGEBOT
        if RageModule.Settings.rbAutoFire and frame % 3 == 0 and head then
            if now - R.rbLast >= RageModule.Settings.rbFireRate then
                RayP.FilterDescendantsInstances = {R.myChar}
                local best = nil

                for i = 1, 4 do
                    local d = R.playerData[i]
                    if d and not d.team and d.dist < RageModule.Settings.rbMaxDist then
                        -- Air check
                        if RageModule.Settings.rbNoAir then
                            local enemyPos = d.r.Position
                            local groundRay = Workspace:Raycast(enemyPos, V3_NEW(0, -4, 0), RayP)
                            local isInAir = groundRay == nil

                            local enemyVelY = d.r.AssemblyLinearVelocity.Y
                            if isInAir or math.abs(enemyVelY) > 8 then
                                continue
                            end
                        end

                        local tgt = RageModule.Settings.rbHitbox == "Head" and d.head or d.torso or d.r
                        if tgt then
                            local dir = tgt.Position - head.Position
                            local res = Workspace:Raycast(head.Position, dir, RayP)

                            -- Wall check
                            if RageModule.Settings.rbWallCheck then
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

                        local tgt = RageModule.Settings.rbHitbox == "Head" and best.head or best.torso or best.r
                        local vel = best.r.AssemblyLinearVelocity
                        local pos = tgt.Position

                        if RageModule.Settings.rbPrediction and vel.Magnitude > 1 then
                            pos = pos + V3_NEW(vel.X, 0, vel.Z) * LocalPlayer:GetNetworkPing() * RageModule.Settings.rbPredMulti
                        end

                        pcall(fs.FireServer, fs, head.Position, (pos - head.Position).Unit, tgt)
                        R.rbLast = now

                        print("[Rage] Shot:", best.p.Name, "Dist:", math.floor(best.dist))

                        task.delay(0.05, function()
                            if aahelp then pcall(function() aahelp:FireServer("enable") end) end
                            if aahelp1 then pcall(function() aahelp1:FireServer("enable") end) end
                        end)
                    end
                end
            end
        end

        if frame > 1000 then frame = 0 end
    end)
end

function RageModule:Stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    R.running = false

    print("[Rage] Arcanum ragebot stopped")
end

function RageModule:GetCurrentTarget()
    return R.playerData[1]
end

return RageModule
