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
local activePlayers = {}
local lastPlayerUpdate = 0
local aahelp = ReplicatedStorage:WaitForChild("aahelp", 5)
local aahelp1 = ReplicatedStorage:WaitForChild("aahelp1", 5)

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

local RaycastParams_new = RaycastParams.new()
RaycastParams_new.FilterType = Enum.RaycastFilterType.Exclude
RaycastParams_new.IgnoreWater = true

local function getToolComponents()
    local Character = LocalPlayer.Character
    if not Character then
        print("[Rage] No character")
        return nil
    end
    local Tool = Character:FindFirstChildOfClass("Tool")
    if not Tool then
        print("[Rage] No tool equipped")
        return nil
    end
    print("[Rage] Tool found:", Tool.Name)
    local Remotes = Tool:FindFirstChild("Remotes")
    if not Remotes then
        print("[Rage] No Remotes folder in tool")
        return nil
    end
    local FireShot = Remotes:FindFirstChild("FireShot")
    if not FireShot then
        print("[Rage] No FireShot remote in Remotes")
        return nil
    end
    print("[Rage] FireShot remote found")
    return {
        tool = Tool,
        fireShot = FireShot,
        reload = Remotes:FindFirstChild("Reload"),
        handle = Tool:FindFirstChild("Handle")
    }
end

local function updateActivePlayersList()
    table.clear(activePlayers)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and (not player.Team or not LocalPlayer.Team or player.Team ~= LocalPlayer.Team) then
            local Character = player.Character
            if Character then
                local Humanoid = Character:FindFirstChild("Humanoid")
                if Humanoid and Humanoid.Health > 0 and Character:FindFirstChild("HumanoidRootPart") then
                    local playerData = {
                        player = player,
                        character = Character,
                        humanoid = Humanoid
                    }
                    playerData.rootPart = Character:FindFirstChild("HumanoidRootPart")
                    table.insert(activePlayers, playerData)
                end
            end
        end
    end
end

local function predictPartPosition(part, rootPart)
    if not RageModule.Settings.Prediction or not rootPart then
        return part.Position
    end
    local velocity = rootPart.AssemblyLinearVelocity
    if not velocity then
        velocity = Vector3.new()
    end
    if not RageModule.Settings.VelocityResolver and velocity.Magnitude < 3 then
        return part.Position
    end
    local predictionStrength = RageModule.Settings.PredictionStrength
    if RageModule.Settings.VelocityResolver then
        predictionStrength = predictionStrength * 1.2
    end
    return part.Position + velocity * predictionStrength
end

local function isInFOV(position)
    if RageModule.Settings.FOV >= 360 then
        return true
    end
    local screenPos, onScreen = CurrentCamera:WorldToViewportPoint(position)
    if not onScreen then
        return false
    end
    local ViewportSize = CurrentCamera.ViewportSize
    local deltaX = screenPos.X - ViewportSize.X * 0.5
    local deltaY = screenPos.Y - ViewportSize.Y * 0.5
    local fov = RageModule.Settings.FOV
    return deltaX * deltaX + deltaY * deltaY <= fov * fov
end

local function canBulletPassThrough(part)
    if not part or not part:IsA("BasePart") then
        return false
    end
    if part:IsA("WedgePart") then
        return true
    end
    local partName = part.Name:lower()
    if partName:find("hamik") or partName:find("paletka") then
        return true
    end
    if part.Parent then
        local parentName = part.Parent.Name:lower()
        if parentName:find("hamik") or parentName:find("paletka") then
            return true
        end
    end
    if part.Transparency > 0.2 then
        return true
    end
    if not part.CanCollide then
        return true
    end
    return false
end

local function isPartOfCharacter(part)
    if not part or not part:IsA("BasePart") then
        return false
    end
    local parent = part.Parent
    if not parent then
        return false
    end
    if parent:FindFirstChild("Humanoid") then
        return true
    end
    if parent:IsA("Accessory") or parent:IsA("Hat") then
        return true
    end
    return false
end

local function strictWallCheck(startPos, endPos, myChar, targetChar)
    if not startPos or not endPos then
        return false
    end
    local direction = endPos - startPos
    local distance = direction.Magnitude
    if distance < 0.1 or distance > 1000 then
        return false
    end
    RaycastParams_new.FilterDescendantsInstances = {myChar, targetChar}
    local rayResult = Workspace:Raycast(startPos, direction, RaycastParams_new)
    if not rayResult then
        return true
    end
    local hitPart = rayResult.Instance
    if hitPart:IsDescendantOf(targetChar) then
        return true
    end
    if canBulletPassThrough(hitPart) or isPartOfCharacter(hitPart) then
        local newStart = rayResult.Position + direction.Unit * 0.1
        local newDirection = endPos - newStart
        if newDirection.Magnitude < 0.1 then
            return true
        end
        RaycastParams_new.FilterDescendantsInstances = {myChar, targetChar, hitPart}
        local secondRay = Workspace:Raycast(newStart, newDirection, RaycastParams_new)
        if not secondRay then
            return true
        end
        if secondRay.Instance:IsDescendantOf(targetChar) then
            return true
        end
        return false
    end
    return false
end

local function multiPointWallCheck(startPos, endPos, myChar, targetChar)
    if not startPos or not endPos or not myChar or not targetChar then
        return false
    end
    if strictWallCheck(startPos, endPos, myChar, targetChar) then
        return true
    end
    for _, offset in ipairs({Vector3.new(0, 0.3, 0), Vector3.new(0, -0.3, 0)}) do
        if strictWallCheck(startPos, endPos + offset, myChar, targetChar) then
            return true
        end
    end
    return false
end

local function calculatePotentialDamage(partName, distance)
    local damage = 54 * (DAMAGE_MULTIPLIERS[partName] or 0.5)
    if distance > 300 then
        damage = damage * 0.3
    elseif distance > 200 then
        damage = damage * 0.5
    elseif distance > 100 then
        damage = damage * 0.8
    end
    return math.floor(damage)
end

local function checkMinDamage(part, distance)
    if RageModule.Settings.MinDamage <= 0 then
        return true
    end
    local damage = calculatePotentialDamage(part.Name, distance)
    return damage >= RageModule.Settings.MinDamage
end

local function findBestTarget()
    local Character = LocalPlayer.Character
    if not Character then
        return nil
    end
    local Humanoid = Character:FindFirstChild("Humanoid")
    if not Humanoid or Humanoid.Health <= 0 then
        return nil
    end
    
    local currentTime = tick()
    if currentTime - lastPlayerUpdate >= 0.5 then
        lastPlayerUpdate = currentTime
        updateActivePlayersList()
    end
    
    if #activePlayers == 0 then
        print("[Rage] No active players found")
        return nil
    end
    
    local myHead = Character:FindFirstChild("Head")
    if not myHead then
        return nil
    end
    
    local bestTarget = nil
    local bestScore = -math.huge
    
    for _, data in ipairs(activePlayers) do
        local targetChar = data.character
        local rootPart = data.rootPart
        local targetHumanoid = data.humanoid
        
        local targetParts = {}
        
        if RageModule.Settings.Hitboxes.Head then
            local head = targetChar:FindFirstChild("Head")
            if head then table.insert(targetParts, head) end
        end
        
        if RageModule.Settings.Hitboxes.Body then
            local upperTorso = targetChar:FindFirstChild("UpperTorso")
            local lowerTorso = targetChar:FindFirstChild("LowerTorso")
            local torso = targetChar:FindFirstChild("Torso")
            if upperTorso then table.insert(targetParts, upperTorso) end
            if lowerTorso then table.insert(targetParts, lowerTorso) end
            if torso then table.insert(targetParts, torso) end
        end
        
        if RageModule.Settings.Hitboxes.Arms then
            local leftArm = targetChar:FindFirstChild("LeftUpperArm")
            local rightArm = targetChar:FindFirstChild("RightUpperArm")
            if leftArm then table.insert(targetParts, leftArm) end
            if rightArm then table.insert(targetParts, rightArm) end
        end
        
        if RageModule.Settings.Hitboxes.Legs then
            local leftLeg = targetChar:FindFirstChild("LeftUpperLeg") or targetChar:FindFirstChild("Left Leg")
            local rightLeg = targetChar:FindFirstChild("RightUpperLeg") or targetChar:FindFirstChild("Right Leg")
            if leftLeg then table.insert(targetParts, leftLeg) end
            if rightLeg then table.insert(targetParts, rightLeg) end
        end
        
        for _, part in ipairs(targetParts) do
            local predictedPos = predictPartPosition(part, rootPart)
            
            if isInFOV(predictedPos) then
                local distance = (myHead.Position - predictedPos).Magnitude
                
                if checkMinDamage(part, distance) then
                    local damage = calculatePotentialDamage(part.Name, distance)
                    local score = damage - distance * 0.1
                    
                    if score > bestScore then
                        bestScore = score
                        bestTarget = {
                            player = data.player,
                            character = targetChar,
                            targetPart = part,
                            rootPart = rootPart,
                            humanoid = targetHumanoid,
                            predictedPos = predictedPos,
                            distance = distance
                        }
                    end
                end
            end
        end
    end
    
    if bestTarget then
        print("[Rage] Target found:", bestTarget.player.Name, "Part:", bestTarget.targetPart.Name)
    else
        print("[Rage] No valid target found")
    end
    
    return bestTarget
end

local function isGrounded(humanoid, rootPart)
    if not humanoid or not rootPart then
        return false
    end
    if humanoid.FloorMaterial ~= Enum.Material.Air then
        return true
    end
    RaycastParams_new.FilterDescendantsInstances = {LocalPlayer.Character}
    local rayResult = Workspace:Raycast(rootPart.Position, Vector3.new(0, -3.5, 0), RaycastParams_new)
    return rayResult ~= nil
end

local function isPlayerJumping(humanoid)
    if not humanoid then
        return true
    end
    local state = humanoid:GetState()
    return state == Enum.HumanoidStateType.Jumping or 
           state == Enum.HumanoidStateType.Freefall or 
           state == Enum.HumanoidStateType.FallingDown
end

local function disableAntiAimsAndRotate(direction)
    local Character = LocalPlayer.Character
    if not Character then return end
    local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    if not HumanoidRootPart then return end
    
    if aahelp then
        pcall(function() aahelp:FireServer("disable") end)
    end
    if aahelp1 then
        pcall(function() aahelp1:FireServer("disable") end)
    end
    
    task.wait(0.01)
    
    local Unit = Vector3.new(direction.X, 0, direction.Z).Unit
    if Unit.Magnitude > 0.1 then
        HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.Position, HumanoidRootPart.Position + Unit)
    end
    
    local Rotation = HumanoidRootPart.CFrame.Rotation
    task.defer(function()
        task.delay(0.15, function()
            if Character and HumanoidRootPart and HumanoidRootPart.Parent then
                HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.Position) * Rotation
            end
            if aahelp then
                pcall(function() aahelp:FireServer("enable") end)
            end
            if aahelp1 then
                pcall(function() aahelp1:FireServer("enable") end)
            end
        end)
    end)
end

function RageModule:Start()
    if connection then return end
    
    print("[Rage] Starting ragebot...")
    
    connection = RunService.RenderStepped:Connect(function()
        if not RageModule.Settings.Enabled then
            return
        end
        
        if shooting then return end
        
        local Character = LocalPlayer.Character
        if not Character then return end
        
        local Humanoid = Character:FindFirstChild("Humanoid")
        if not Humanoid or Humanoid.Health <= 0 then return end
        
        local currentTime = tick()
        if currentTime - lastShot < 1.0 then return end
        
        local toolComponents = getToolComponents()
        if not toolComponents then return end
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local targetChar = player.Character
                local targetHead = targetChar:FindFirstChild("Head")
                local targetHumanoid = targetChar:FindFirstChild("Humanoid")
                
                if targetHead and targetHumanoid and targetHumanoid.Health > 0 then
                    local myHead = Character:FindFirstChild("Head")
                    if myHead then
                        local distance = (myHead.Position - targetHead.Position).Magnitude
                        if distance < 500 then
                            shooting = true
                            
                            task.spawn(function()
                                local Position = myHead.Position
                                local Unit = (targetHead.Position - Position).Unit
                                
                                print("[Rage] Attempting to shoot at", player.Name)
                                
                                local success, err = pcall(function()
                                    toolComponents.fireShot:FireServer(Position, Unit, targetHead)
                                end)
                                
                                if success then
                                    lastShot = tick()
                                    print("[Rage] Shot fired successfully at", player.Name)
                                else
                                    warn("[Rage] Shot failed:", err)
                                end
                                
                                task.wait(0.1)
                                shooting = false
                            end)
                            
                            return
                        end
                    end
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
end

function RageModule:GetCurrentTarget()
    return currentTarget
end

return RageModule
