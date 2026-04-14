local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
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

local function shoot(target)
    if shooting then return end
    
    local now = tick()
    if now - lastShot < 1.0 then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local head = char:FindFirstChild("Head")
    if not head then return end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then 
        warn("[Rage] No tool equipped")
        return 
    end
    
    local remotes = tool:FindFirstChild("Remotes")
    if not remotes then 
        warn("[Rage] No Remotes folder in tool")
        return 
    end
    
    local fireShot = remotes:FindFirstChild("FireShot")
    if not fireShot then 
        warn("[Rage] No FireShot remote")
        return 
    end
    
    shooting = true
    lastShot = now
    
    local origin = head.Position
    local direction = (target.position - origin).Unit
    
    task.spawn(function()
        local success, err = pcall(function()
            fireShot:FireServer(origin, direction, target.part)
        end)
        
        if success then
            print("[Rage] ✓ Shot fired at", target.player.Name)
        else
            warn("[Rage] ✗ Shot failed:", err)
        end
        
        task.wait(0.1)
        shooting = false
    end)
end

local function findTarget()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    local head = char:FindFirstChild("Head")
    if not head then return nil end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetChar = player.Character
            local humanoid = targetChar:FindFirstChild("Humanoid")
            
            if humanoid and humanoid.Health > 0 then
                local part = nil
                
                if RageModule.Settings.Hitboxes.Head then
                    part = targetChar:FindFirstChild("Head")
                end
                
                if not part and RageModule.Settings.Hitboxes.Body then
                    part = targetChar:FindFirstChild("UpperTorso") or 
                           targetChar:FindFirstChild("Torso")
                end
                
                if part then
                    local distance = (head.Position - part.Position).Magnitude
                    if distance <= 500 then
                        return {
                            player = player,
                            character = targetChar,
                            part = part,
                            position = part.Position,
                            distance = distance
                        }
                    end
                end
            end
        end
    end
    
    return nil
end

function RageModule:Start()
    if connection then return end
    
    print("[Rage] Starting ragebot...")
    
    connection = RunService.Heartbeat:Connect(function()
        if not RageModule.Settings.Enabled then
            currentTarget = nil
            return
        end
        
        if shooting then return end
        
        local target = findTarget()
        currentTarget = target
        
        if target and RageModule.Settings.AutoFire then
            shoot(target)
        end
    end)
    
    print("[Rage] Ragebot started!")
end

function RageModule:Stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    currentTarget = nil
    shooting = false
    print("[Rage] Ragebot stopped!")
end

function RageModule:GetCurrentTarget()
    return currentTarget
end

return RageModule
