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

local function getToolComponents()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    for _, obj in pairs(char:GetChildren()) do
        if obj:IsA("Tool") then
            local remotes = obj:FindFirstChild("Remotes")
            if remotes then
                local fireShot = remotes:FindFirstChild("FireShot")
                if fireShot then
                    return {
                        tool = obj,
                        fireShot = fireShot,
                        reload = remotes:FindFirstChild("Reload"),
                        handle = obj:FindFirstChild("Handle")
                    }
                end
            end
        end
    end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local remotes = tool:FindFirstChild("Remotes")
        if remotes then
            local fireShot = remotes:FindFirstChild("FireShot")
            if fireShot then
                return {
                    tool = tool,
                    fireShot = fireShot,
                    reload = remotes:FindFirstChild("Reload"),
                    handle = tool:FindFirstChild("Handle")
                }
            end
        end
        
        for _, child in pairs(tool:GetChildren()) do
            if child.Name:lower():find("fire") or child.Name:lower():find("shoot") then
                return {
                    tool = tool,
                    fireShot = child,
                    handle = tool:FindFirstChild("Handle")
                }
            end
        end
    end
    
    return nil
end

local function findTarget()
    local char = LocalPlayer.Character
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    if not head then return nil end
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local tChar = plr.Character
            local tHum = tChar:FindFirstChild("Humanoid")
            local tRoot = tChar:FindFirstChild("HumanoidRootPart")
            
            if tHum and tHum.Health > 0 and tRoot then
                local targetPart = nil
                
                if RageModule.Settings.Hitboxes.Head then
                    targetPart = tChar:FindFirstChild("Head")
                end
                
                if not targetPart and RageModule.Settings.Hitboxes.Body then
                    targetPart = tChar:FindFirstChild("UpperTorso") or 
                                tChar:FindFirstChild("Torso") or 
                                tChar:FindFirstChild("LowerTorso")
                end
                
                if not targetPart and RageModule.Settings.Hitboxes.Arms then
                    targetPart = tChar:FindFirstChild("LeftUpperArm") or 
                                tChar:FindFirstChild("RightUpperArm")
                end
                
                if not targetPart and RageModule.Settings.Hitboxes.Legs then
                    targetPart = tChar:FindFirstChild("LeftUpperLeg") or 
                                tChar:FindFirstChild("RightUpperLeg") or
                                tChar:FindFirstChild("Left Leg") or
                                tChar:FindFirstChild("Right Leg")
                end
                
                if targetPart then
                    local pos = targetPart.Position
                    if RageModule.Settings.Prediction then
                        local vel = tRoot.AssemblyLinearVelocity or Vector3.zero
                        if vel.Magnitude >= 3 then
                            pos = pos + vel * RageModule.Settings.PredictionStrength
                        end
                    end
                    
                    local dist = (head.Position - pos).Magnitude
                    if dist <= 1000 then
                        return {
                            player = plr,
                            character = tChar,
                            targetPart = targetPart,
                            position = pos,
                            distance = dist
                        }
                    end
                end
            end
        end
    end
    
    return nil
end

local function shoot(target)
    if shooting then return end
    
    local now = tick()
    if now - lastShot < 1.3 then return end
    
    local toolData = getToolComponents()
    if not toolData then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local head = char:FindFirstChild("Head")
    if not head then return end
    
    shooting = true
    lastShot = now
    
    local origin = head.Position
    local direction = (target.position - origin).Unit
    
    local success, err = pcall(function()
        toolData.fireShot:FireServer(origin, direction, target.targetPart)
    end)
    
    if success then
        print("[Rage] Shot fired at", target.player.Name)
    end
    
    task.wait(0.1)
    shooting = false
end

function RageModule:Start()
    if connection then return end
    
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
end

function RageModule:Stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    currentTarget = nil
    shooting = false
end

function RageModule:GetCurrentTarget()
    return currentTarget
end

return RageModule
