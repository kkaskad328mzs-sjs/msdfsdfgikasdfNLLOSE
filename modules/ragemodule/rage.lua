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
    VelocityResolver = false,
    PingCompensation = true,
    AutoStop = true,
    AutoStopModes = {Early = true, InAir = false, BetweenShot = true, ForceAccurate = true},
    DoubleTap = false,
    WallCheck = false,
    TargetMode = "Highest Damage",
    Multipoint = true,
    MultipointScale = 0.75,
    Backtrack = "Maximum",
    DelayShot = false
}

local lastShot = 0
local shooting = false
local currentTarget = nil
local connection = nil

print("[RAGE DEBUG] Module loaded")

local function getTool()
    local char = LocalPlayer.Character
    if not char then 
        print("[RAGE DEBUG] No character")
        return nil 
    end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then 
        print("[RAGE DEBUG] No tool found")
        return nil 
    end
    
    local remotes = tool:FindFirstChild("Remotes")
    if not remotes then 
        print("[RAGE DEBUG] No Remotes folder")
        return nil 
    end
    
    local fireShot = remotes:FindFirstChild("FireShot")
    if not fireShot then 
        print("[RAGE DEBUG] No FireShot remote")
        return nil 
    end
    
    print("[RAGE DEBUG] Tool found:", tool.Name)
    return fireShot
end

local function findTarget()
    print("[RAGE DEBUG] Looking for targets...")
    
    local char = LocalPlayer.Character
    if not char then 
        print("[RAGE DEBUG] No local character")
        return nil 
    end
    
    local head = char:FindFirstChild("Head")
    if not head then 
        print("[RAGE DEBUG] No local head")
        return nil 
    end
    
    local playerCount = 0
    local validTargets = 0
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            playerCount = playerCount + 1
            local tChar = plr.Character
            if tChar then
                local tHum = tChar:FindFirstChild("Humanoid")
                local tRoot = tChar:FindFirstChild("HumanoidRootPart")
                if tHum and tHum.Health > 0 and tRoot then
                    validTargets = validTargets + 1
                    local targetPart = tChar:FindFirstChild("Head")
                    if not targetPart then
                        targetPart = tChar:FindFirstChild("UpperTorso") or tChar:FindFirstChild("Torso")
                    end
                    if targetPart then
                        local dist = (head.Position - targetPart.Position).Magnitude
                        if dist <= 1000 then
                            print("[RAGE DEBUG] Found target:", plr.Name, "distance:", math.floor(dist))
                            return {
                                player = plr,
                                character = tChar,
                                targetPart = targetPart,
                                position = targetPart.Position,
                                distance = dist
                            }
                        end
                    end
                end
            end
        end
    end
    
    print("[RAGE DEBUG] Players:", playerCount, "Valid targets:", validTargets)
    return nil
end

local function shoot(target)
    print("[RAGE DEBUG] ATTEMPTING SHOOT at", target.player.Name)
    
    if shooting then 
        print("[RAGE DEBUG] Already shooting")
        return 
    end
    
    local now = tick()
    if now - lastShot < 1.3 then 
        print("[RAGE DEBUG] Cooldown active")
        return 
    end
    
    local fireShot = getTool()
    if not fireShot then 
        print("[RAGE DEBUG] No fireShot tool")
        return 
    end
    
    local char = LocalPlayer.Character
    if not char then 
        print("[RAGE DEBUG] No character in shoot")
        return 
    end
    
    local head = char:FindFirstChild("Head")
    if not head then 
        print("[RAGE DEBUG] No head in shoot")
        return 
    end
    
    print("[RAGE DEBUG] All checks passed - FIRING!")
    
    shooting = true
    lastShot = now
    
    local origin = head.Position
    local direction = (target.position - origin).Unit
    
    print("[RAGE DEBUG] Origin:", origin)
    print("[RAGE DEBUG] Direction:", direction)
    print("[RAGE DEBUG] Target part:", target.targetPart.Name)
    
    local success, err = pcall(function()
        fireShot:FireServer(origin, direction, target.targetPart)
    end)
    
    if success then
        print("[RAGE DEBUG] ✓ SHOT FIRED SUCCESSFULLY!")
    else
        print("[RAGE DEBUG] ✗ SHOT FAILED:", err)
    end
    
    task.wait(0.1)
    shooting = false
end

function RageModule:Start()
    print("[RAGE DEBUG] Starting ragebot...")
    
    if connection then 
        print("[RAGE DEBUG] Already running")
        return 
    end
    
    connection = RunService.Heartbeat:Connect(function()
        if not RageModule.Settings.Enabled then
            currentTarget = nil
            return
        end
        
        if shooting then 
            return 
        end
        
        local target = findTarget()
        currentTarget = target
        
        if target then
            print("[RAGE DEBUG] Target found, attempting shoot...")
            if RageModule.Settings.AutoFire then
                shoot(target)
            else
                print("[RAGE DEBUG] AutoFire disabled")
            end
        end
    end)
    
    print("[RAGE DEBUG] ✓ Ragebot connection established!")
end

function RageModule:Stop()
    print("[RAGE DEBUG] Stopping ragebot...")
    if connection then
        connection:Disconnect()
        connection = nil
    end
    currentTarget = nil
    shooting = false
    print("[RAGE DEBUG] ✓ Ragebot stopped!")
end

function RageModule:GetCurrentTarget()
    return currentTarget
end

print("[RAGE DEBUG] ✓ Module ready!")
return RageModule
