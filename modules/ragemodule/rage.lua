local RageModule = {}
RageModule.__index = RageModule

function RageModule.new(player)
	local self = setmetatable({}, RageModule)
	
	self.player = player
	self.Players = game:GetService("Players")
	self.RunService = game:GetService("RunService")
	self.Workspace = game:GetService("Workspace")
	self.Camera = self.Workspace.CurrentCamera
	
	self.enabled = false
	self.autoFire = true
	self.autoEquip = false
	self.hitboxes = {"Head"}
	self.maxDistance = math.huge
	self.teamCheck = true
	self.wallCheck = true
	self.predictionEnabled = true
	self.predictionMultiplier = 1.0
	
	self.hitchanceEnabled = false
	self.hitchanceValue = 80
	self.hitchanceIterations = 25
	self.minDamageEnabled = false
	self.minDamageValue = 20
	self.minDamageOverkill = true
	self.autoScope = true
	self.smartPoint = false
	
	self.fovCheck = false
	self.fovSize = 180
	self.velocityCheck = true
	self.maxVelocity = 150
	self.humanization = 0.02
	
	self.doubleTapEnabled = false
	self.doubleTapActive = false
	self.doubleTapDistance = 6
	self.lastDoubleTap = 0
	self.doubleTapCooldown = 0.3
	self.doubleTapReturnDelay = 0.15
	self.originalPosition = nil
	self.doubleTapMode = "Aggressive"
	
	self.rapidFireEnabled = false
	self.rapidFireShots = 10
	self.rapidFireReequip = true
	self.rapidFireActive = false
	
	self.fireRate = 0.1
	self.lastShot = 0
	self.isScoped = false
	self.frameCounter = 0
	self.nextFireDelay = 0
	
	self.targetCache = {}
	self.targetCacheTime = 0
	self.TARGET_CACHE_INTERVAL = 0.5
	self.weaponCache = nil
	self.weaponCacheTime = 0
	self.WEAPON_CACHE_INTERVAL = 2
	
	self.hitboxParts = {
		Head = {"Head"},
		Neck = {"UpperTorso"},
		Chest = {"UpperTorso"},
		Stomach = {"LowerTorso"},
		Pelvis = {"HumanoidRootPart"},
		LeftArm = {"LeftUpperArm", "LeftLowerArm"},
		RightArm = {"RightUpperArm", "RightLowerArm"},
		LeftLeg = {"LeftUpperLeg", "LeftLowerLeg"},
		RightLeg = {"RightUpperLeg", "RightLowerLeg"},
		Arms = {"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm"},
		Legs = {"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"},
	}
	
	self.damageMultipliers = {
		Head = 4.0,
		UpperTorso = 1.0,
		LowerTorso = 1.0,
		Torso = 1.0,
		HumanoidRootPart = 1.0,
		LeftUpperArm = 0.75,
		RightUpperArm = 0.75,
		LeftLowerArm = 0.75,
		RightLowerArm = 0.75,
		LeftUpperLeg = 0.6,
		RightUpperLeg = 0.6,
		LeftLowerLeg = 0.6,
		RightLowerLeg = 0.6,
	}
	
	self.scanPriority = {
		{name = "Head", parts = {"Head"}},
		{name = "Torso", parts = {"UpperTorso", "LowerTorso", "Torso"}},
		{name = "Pelvis", parts = {"HumanoidRootPart"}},
		{name = "Arms", parts = {"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm"}},
		{name = "Legs", parts = {"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"}},
	}
	
	self.baseDamage = 54
	
	return self
end

function RageModule:GetWeapon()
	local now = tick()
	if self.weaponCache and now - self.weaponCacheTime < self.WEAPON_CACHE_INTERVAL then
		return self.weaponCache
	end
	
	local char = self.player.Character
	if not char then 
		self.weaponCache = nil
		return nil 
	end
	
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then
		if self.autoEquip then
			local backpack = self.player:FindFirstChild("Backpack")
			if backpack then
				local ssg = backpack:FindFirstChild("SSG-08")
				if ssg and ssg:IsA("Tool") then
					char.Humanoid:EquipTool(ssg)
					task.wait(0.1)
					tool = char:FindFirstChildOfClass("Tool")
				end
			end
		end
		
		if not tool then
			self.weaponCache = nil
			return nil
		end
	end
	
	local remotes = tool:FindFirstChild("Remotes")
	if remotes then
		local fireShot = remotes:FindFirstChild("FireShot")
		local scope = remotes:FindFirstChild("Scope")
		local shotAck = remotes:FindFirstChild("ShotAck")
		
		if fireShot and fireShot:IsA("RemoteEvent") then
			self.weaponCache = {
				fireShot = fireShot,
				scope = scope,
				shotAck = shotAck,
				tool = tool
			}
			self.weaponCacheTime = now
			return self.weaponCache
		end
	end
	
	self.weaponCache = nil
	return nil
end

function RageModule:IsAlive(character)
	if not character then return false end
	local humanoid = character:FindFirstChild("Humanoid")
	return humanoid and humanoid.Health > 0
end

function RageModule:IsEnemy(targetPlayer)
	if not self.teamCheck then return true end
	if self.player.Team and targetPlayer.Team then
		return self.player.Team ~= targetPlayer.Team
	end
	return true
end

function RageModule:GetTargets()
	local now = tick()
	if now - self.targetCacheTime < self.TARGET_CACHE_INTERVAL and #self.targetCache > 0 then
		return self.targetCache
	end
	
	local targets = {}
	local myChar = self.player.Character
	if not myChar then return targets end
	
	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then return targets end
	
	local myPos = myRoot.Position
	local camCF = self.Camera.CFrame
	local camLook = camCF.LookVector
	
	for _, targetPlayer in ipairs(self.Players:GetPlayers()) do
		if targetPlayer ~= self.player and self:IsEnemy(targetPlayer) then
			local targetChar = targetPlayer.Character
			if targetChar and self:IsAlive(targetChar) then
				local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
				if targetRoot then
					local distance = (myPos - targetRoot.Position).Magnitude
					if distance <= self.maxDistance then
						local velocity = targetRoot.AssemblyLinearVelocity or targetRoot.Velocity or Vector3.new()
						if self.velocityCheck and velocity.Magnitude > self.maxVelocity then
							continue
						end
						
						local fovAngle = 360
						if self.fovCheck then
							local dirToTarget = (targetRoot.Position - camCF.Position).Unit
							local dotProduct = camLook.X * dirToTarget.X + camLook.Z * dirToTarget.Z
							local magA = math.sqrt(camLook.X * camLook.X + camLook.Z * camLook.Z)
							local magB = math.sqrt(dirToTarget.X * dirToTarget.X + dirToTarget.Z * dirToTarget.Z)
							if magA > 0 and magB > 0 then
								fovAngle = math.deg(math.acos(math.clamp(dotProduct / (magA * magB), -1, 1)))
							end
							if fovAngle > self.fovSize then
								continue
							end
						end
						
						table.insert(targets, {
							player = targetPlayer,
							character = targetChar,
							root = targetRoot,
							distance = distance,
							fovAngle = fovAngle
						})
					end
				end
			end
		end
	end
	
	table.sort(targets, function(a, b)
		return a.distance < b.distance
	end)
	
	self.targetCache = targets
	self.targetCacheTime = now
	
	return targets
end

function RageModule:WallCheck(origin, targetPos, ignoreList)
	local direction = targetPos - origin
	local distance = direction.Magnitude
	
	if distance < 0.1 then return true end
	
	local filterList = {}
	for _, item in ipairs(ignoreList) do
		if item and typeof(item) == "Instance" then
			table.insert(filterList, item)
		end
	end
	
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = filterList
	rayParams.IgnoreWater = true
	
	local result = self.Workspace:Raycast(origin, direction, rayParams)
	
	if not result then return true end
	
	for _, char in ipairs(filterList) do
		if result.Instance:IsDescendantOf(char) then
			return true
		end
	end
	
	return false
end

function RageModule:SmartPointCheck(origin, targetPart, ignoreList)
	if not self.smartPoint then
		local canSee = self:WallCheck(origin, targetPart.Position, ignoreList)
		return canSee, targetPart.Position
	end
	
	local offsets = {
		Vector3.new(0, 0, 0),
		Vector3.new(0, 0.4, 0),
	}
	
	for _, offset in ipairs(offsets) do
		local targetPos = targetPart.Position + offset
		if self:WallCheck(origin, targetPos, ignoreList) then
			return true, targetPos
		end
	end
	
	return false, targetPart.Position
end

function RageModule:CalculateDamage(partName, distance)
	local multiplier = self.damageMultipliers[partName] or 1.0
	local damage = self.baseDamage * multiplier
	
	if distance > 300 then
		damage = damage * 0.3
	elseif distance > 200 then
		damage = damage * 0.5
	elseif distance > 100 then
		damage = damage * 0.8
	end
	
	return math.floor(damage)
end

function RageModule:GetTargetHealth(character)
	local humanoid = character:FindFirstChild("Humanoid")
	return humanoid and humanoid.Health or 100
end

function RageModule:PredictPosition(targetPart, targetRoot)
	if not self.predictionEnabled then
		return targetPart.Position
	end
	
	local velocity = targetRoot.AssemblyLinearVelocity or targetRoot.Velocity or Vector3.new()
	
	if velocity.Magnitude < 1 then
		return targetPart.Position
	end
	
	local ping = self.player:GetNetworkPing()
	local predictionTime = ping * self.predictionMultiplier
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	
	return targetPart.Position + horizontalVelocity * predictionTime
end

function RageModule:SimulateSpread(origin, targetPos, spreadAngle)
	local direction = (targetPos - origin).Unit
	local randomAngle = math.rad(math.random() * spreadAngle)
	local randomRotation = math.random() * math.pi * 2
	
	local right = direction:Cross(Vector3.new(0, 1, 0)).Unit
	local up = direction:Cross(right).Unit
	
	local offsetX = math.cos(randomRotation) * math.sin(randomAngle)
	local offsetY = math.sin(randomRotation) * math.sin(randomAngle)
	
	return (direction + right * offsetX + up * offsetY).Unit
end

function RageModule:CalculateHitChance(origin, targetPart, targetChar, spreadAngle)
	if not self.hitchanceEnabled then return 100 end
	
	local iterations = math.min(self.hitchanceIterations, 25)
	local hits = 0
	local targetPos = targetPart.Position
	local targetSize = targetPart.Size
	
	local myChar = self.player.Character
	if not myChar then return 0 end
	
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {myChar}
	rayParams.IgnoreWater = true
	
	for _ = 1, iterations do
		local spreadDir = self:SimulateSpread(origin, targetPos, spreadAngle)
		local maxDist = (targetPos - origin).Magnitude + targetSize.Magnitude
		local result = self.Workspace:Raycast(origin, spreadDir * maxDist, rayParams)
		
		if result and result.Instance:IsDescendantOf(targetChar) then
			hits = hits + 1
		end
	end
	
	return math.floor((hits / iterations) * 100)
end

function RageModule:GetHitboxPart(character)
	for _, hitboxName in ipairs(self.hitboxes) do
		local parts = self.hitboxParts[hitboxName]
		if parts then
			for _, partName in ipairs(parts) do
				local part = character:FindFirstChild(partName)
				if part then return part, hitboxName end
			end
		end
	end
	
	local head = character:FindFirstChild("Head")
	return head, "Head"
end

function RageModule:ScanBestHitbox(myHead, target)
	if not self.minDamageEnabled then
		return self:GetHitboxPart(target.character)
	end
	
	local targetHealth = self:GetTargetHealth(target.character)
	local bestPart, bestDamage, bestPos = nil, 0, nil
	local myChar = self.player.Character
	
	for _, hitboxName in ipairs(self.hitboxes) do
		local parts = self.hitboxParts[hitboxName]
		if parts then
			for _, partName in ipairs(parts) do
				local part = target.character:FindFirstChild(partName)
				if part then
					local canSee, visiblePos = self:SmartPointCheck(myHead.Position, part, {myChar, target.character})
					
					if canSee then
						local damage = self:CalculateDamage(partName, target.distance)
						
						if self.minDamageOverkill and damage >= targetHealth then
							return part, visiblePos
						end
						
						if damage >= self.minDamageValue and damage > bestDamage then
							bestPart = part
							bestDamage = damage
							bestPos = visiblePos
						end
					end
				end
			end
		end
	end
	
	return bestPart, bestPos
end

function RageModule:HandleScope(weapon, shouldScope)
	if not self.autoScope or not weapon.scope then return end
	
	if shouldScope and not self.isScoped then
		pcall(function()
			weapon.scope:FireServer(true)
		end)
		self.isScoped = true
	elseif not shouldScope and self.isScoped then
		pcall(function()
			weapon.scope:FireServer(false)
		end)
		self.isScoped = false
	end
end

function RageModule:ReequipWeapon()
	local myChar = self.player.Character
	if not myChar then return false end
	
	local hum = myChar:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	
	local tool = myChar:FindFirstChildOfClass("Tool")
	if not tool then return false end
	
	local toolRef = tool
	hum:UnequipTools()
	task.wait(0.05)
	
	if toolRef and toolRef.Parent and hum and hum.Parent then
		hum:EquipTool(toolRef)
		self.weaponCache = nil
		return true
	end
	
	return false
end

function RageModule:RapidFireBurst(weapon, origin, targetPos, targetPart)
	if not self.rapidFireEnabled or not self.rapidFireActive then return 0 end
	
	local shots = math.floor(self.rapidFireShots)
	local fired = 0
	
	for i = 1, shots do
		local myChar = self.player.Character
		if not myChar or not myChar.Parent then break end
		
		local myHead = myChar:FindFirstChild("Head")
		if not myHead then break end
		
		local jitter = Vector3.new(
			(math.random() - 0.5) * 0.005,
			(math.random() - 0.5) * 0.005,
			(math.random() - 0.5) * 0.005
		)
		
		local jitteredOrigin = origin + jitter
		local direction = (targetPos - jitteredOrigin).Unit
		
		local success = pcall(function()
			weapon.fireShot:FireServer(jitteredOrigin, direction, targetPart)
			if weapon.shotAck then
				weapon.shotAck:FireServer()
			end
		end)
		
		if success then
			fired = fired + 1
		end
	end
	
	if self.rapidFireReequip and fired > 0 then
		task.spawn(function()
			task.wait(0.1)
			self:ReequipWeapon()
		end)
	end
	
	return fired
end

function RageModule:ExecuteDoubleTap()
	if not self.doubleTapEnabled or not self.doubleTapActive then return false end
	
	local now = tick()
	if now - self.lastDoubleTap < self.doubleTapCooldown then return false end
	
	local myChar = self.player.Character
	if not myChar then return false end
	
	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then return false end
	
	self.lastDoubleTap = now
	
	if self.doubleTapMode == "Legit" then
		return self:ExecuteDoubleTapLegit(myRoot)
	else
		return self:ExecuteDoubleTapAggressive(myRoot)
	end
end

function RageModule:ExecuteDoubleTapLegit(myRoot)
	local cam = self.Camera
	local camLook = cam and cam.CFrame.LookVector or myRoot.CFrame.LookVector
	camLook = Vector3.new(camLook.X, 0, camLook.Z).Unit
	
	local myChar = self.player.Character
	local peekDistance = 6.5
	local targetPos = myRoot.Position + camLook * peekDistance
	
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {myChar}
	rayParams.IgnoreWater = true
	
	local result = self.Workspace:Raycast(myRoot.Position, camLook * peekDistance, rayParams)
	
	if not result or result.Distance > peekDistance * 0.8 then
		myRoot.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, math.atan2(-camLook.X, -camLook.Z), 0)
	end
	
	return true
end

function RageModule:ExecuteDoubleTapAggressive(myRoot)
	local cam = self.Camera
	local camLook = cam and cam.CFrame.LookVector or myRoot.CFrame.LookVector
	camLook = Vector3.new(camLook.X, 0, camLook.Z).Unit
	
	self.originalPosition = myRoot.CFrame
	local peekPos = self.originalPosition.Position + camLook * self.doubleTapDistance
	
	myRoot.CFrame = CFrame.new(peekPos) * CFrame.Angles(0, math.atan2(-camLook.X, -camLook.Z), 0)
	
	task.delay(self.doubleTapReturnDelay, function()
		if myRoot and myRoot.Parent and self.originalPosition then
			myRoot.CFrame = self.originalPosition
			self.originalPosition = nil
		end
	end)
	
	return true
end

function RageModule:Shoot(weapon, origin, targetPos, targetPart)
	local direction = (targetPos - origin).Unit
	
	local success = pcall(function()
		weapon.fireShot:FireServer(origin, direction, targetPart)
		if weapon.shotAck then
			weapon.shotAck:FireServer()
		end
	end)
	
	if success and self.rapidFireEnabled and self.rapidFireActive then
		task.spawn(function()
			task.wait(0.05)
			self:RapidFireBurst(weapon, origin, targetPos, targetPart)
		end)
	end
	
	if success and self.doubleTapEnabled and self.doubleTapActive and self.doubleTapMode == "Legit" then
		task.spawn(function()
			task.wait(0.06)
			local myChar = self.player.Character
			if myChar then
				local myHead = myChar:FindFirstChild("Head")
				if myHead then
					local dir = (targetPos - myHead.Position).Unit
					pcall(function()
						weapon.fireShot:FireServer(myHead.Position, dir, targetPart)
						if weapon.shotAck then
							weapon.shotAck:FireServer()
						end
					end)
				end
			end
		end)
	end
	
	return success
end

function RageModule:ManualShoot()
	if not self.enabled or not self.manualFire or not self.mouseDown then return end
	
	local now = tick()
	local currentDelay = self.fireRate + self.nextFireDelay
	
	if now - self.lastShot < currentDelay then return end
	
	local myChar = self.player.Character
	if not myChar or not self:IsAlive(myChar) then return end
	
	local myHead = myChar:FindFirstChild("Head")
	if not myHead then return end
	
	local weapon = self:GetWeapon()
	if not weapon then return end
	
	local mouse = self.player:GetMouse()
	if not mouse then return end
	
	self:HandleScope(weapon, true)
	
	local targetPos = mouse.Hit.Position
	local direction = (targetPos - myHead.Position).Unit
	
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {myChar}
	params.IgnoreWater = true
	
	local result = self.Workspace:Raycast(myHead.Position, direction * 1000, params)
	
	if result then
		local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
		if hitChar and hitChar:FindFirstChild("Humanoid") then
			local targetPlayer = self.Players:GetPlayerFromCharacter(hitChar)
			if targetPlayer and targetPlayer ~= self.player then
				if self:IsEnemy(targetPlayer) and self:IsAlive(hitChar) then
					local targetRoot = hitChar:FindFirstChild("HumanoidRootPart")
					if targetRoot then
						local predictedPos = self:PredictPosition(result.Instance, targetRoot)
						
						local success = self:Shoot(weapon, myHead.Position, predictedPos, result.Instance)
						
						if success then
							self.lastShot = now
							self.nextFireDelay = (math.random() - 0.5) * self.humanization
						end
						return
					end
				end
			end
		end
	end
	
	local success = self:Shoot(weapon, myHead.Position, targetPos, nil)
	if success then
		self.lastShot = now
		self.nextFireDelay = (math.random() - 0.5) * self.humanization
	end
end

function RageModule:MainLoop()
	if not self.enabled or not self.autoFire then return end
	
	self.frameCounter = self.frameCounter + 1
	if self.frameCounter % 3 ~= 0 then return end
	
	local now = tick()
	local currentDelay = self.fireRate + self.nextFireDelay
	
	if now - self.lastShot < currentDelay then return end
	
	local myChar = self.player.Character
	if not myChar or not self:IsAlive(myChar) then return end
	
	local myHead = myChar:FindFirstChild("Head")
	if not myHead then return end
	
	local weapon = self:GetWeapon()
	if not weapon then return end
	
	local targets = self:GetTargets()
	if #targets == 0 then return end
	
	if self.doubleTapEnabled and self.doubleTapActive then
		local visibleCount = 0
		local myRoot = myChar:FindFirstChild("HumanoidRootPart")
		
		if myRoot then
			for _, target in ipairs(targets) do
				local hitboxPart = self:GetHitboxPart(target.character)
				if hitboxPart then
					local canSee = self:WallCheck(myHead.Position, hitboxPart.Position, {myChar, target.character})
					if canSee then
						visibleCount = visibleCount + 1
					end
				end
			end
			
			if visibleCount == 1 then
				self:ExecuteDoubleTap()
			end
		end
	end
	
	self:HandleScope(weapon, true)
	
	for _, target in ipairs(targets) do
		local hitboxPart, visiblePos = nil, nil
		
		if self.minDamageEnabled then
			hitboxPart, visiblePos = self:ScanBestHitbox(myHead, target)
		else
			hitboxPart = self:GetHitboxPart(target.character)
			
			if hitboxPart then
				if self.wallCheck then
					local canSee, pos = self:SmartPointCheck(myHead.Position, hitboxPart, {myChar, target.character})
					if canSee then
						visiblePos = pos
					else
						hitboxPart = nil
					end
				else
					visiblePos = hitboxPart.Position
				end
			end
		end
		
		if not hitboxPart or not visiblePos then continue end
		
		local predictedPos = self:PredictPosition(hitboxPart, target.root)
		
		if self.hitchanceEnabled then
			local spreadAngle = 0.3
			local hitchance = self:CalculateHitChance(myHead.Position, hitboxPart, target.character, spreadAngle)
			if hitchance < self.hitchanceValue then
				continue
			end
		end
		
		local success = self:Shoot(weapon, myHead.Position, predictedPos, hitboxPart)
		
		if success then
			self.lastShot = now
			self.nextFireDelay = (math.random() - 0.5) * self.humanization
			break
		end
	end
end

function RageModule:Start()
	local UIS = game:GetService("UserInputService")
	
	self.doubleTapKeybind = Enum.KeyCode.E
	
	self.RunService.Heartbeat:Connect(function()
		if self.enabled then
			self:MainLoop()
		end
	end)
	
	UIS.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == self.doubleTapKeybind and self.doubleTapEnabled then
			self.doubleTapActive = not self.doubleTapActive
		end
		if input.KeyCode == Enum.KeyCode.R and self.rapidFireEnabled then
			self.rapidFireActive = not self.rapidFireActive
		end
	end)
	
	print("[Rage] Module started")
end

function RageModule:SetEnabled(value) self.enabled = value end
function RageModule:SetAutoFire(value) self.autoFire = value end
function RageModule:SetAutoEquip(value) self.autoEquip = value end
function RageModule:SetHitboxes(value) 
	if type(value) == "table" then
		self.hitboxes = value
	else
		self.hitboxes = {value}
	end
end
function RageModule:SetMaxDistance(value) self.maxDistance = value end
function RageModule:SetTeamCheck(value) self.teamCheck = value end
function RageModule:SetWallCheck(value) self.wallCheck = value end
function RageModule:SetPredictionEnabled(value) self.predictionEnabled = value end
function RageModule:SetPredictionMultiplier(value) self.predictionMultiplier = value end
function RageModule:SetFireRate(value) self.fireRate = value / 1000 end
function RageModule:SetHitchanceEnabled(value) self.hitchanceEnabled = value end
function RageModule:SetHitchanceValue(value) self.hitchanceValue = value end
function RageModule:SetHitchanceIterations(value) self.hitchanceIterations = math.min(value, 30) end
function RageModule:SetMinDamageEnabled(value) self.minDamageEnabled = value end
function RageModule:SetMinDamageValue(value) self.minDamageValue = value end
function RageModule:SetMinDamageOverkill(value) self.minDamageOverkill = value end
function RageModule:SetAutoScope(value) self.autoScope = value end
function RageModule:SetSmartPoint(value) self.smartPoint = value end
function RageModule:SetFovCheck(value) self.fovCheck = value end
function RageModule:SetFovSize(value) self.fovSize = value end
function RageModule:SetVelocityCheck(value) self.velocityCheck = value end
function RageModule:SetMaxVelocity(value) self.maxVelocity = value end
function RageModule:SetHumanization(value) self.humanization = value end
function RageModule:SetMultiPoint(value) self.smartPoint = value end
function RageModule:SetAutoStop(value) end
function RageModule:SetDoubleTapEnabled(value) self.doubleTapEnabled = value end
function RageModule:SetDoubleTapActive(value) self.doubleTapActive = value end
function RageModule:SetDoubleTapKeybind(key) self.doubleTapKeybind = key end
function RageModule:SetDoubleTapMode(value) self.doubleTapMode = value end
function RageModule:GetDoubleTapActive() return self.doubleTapActive end
function RageModule:SetRapidFireEnabled(value) self.rapidFireEnabled = value end
function RageModule:SetRapidFireShots(value) self.rapidFireShots = value end
function RageModule:SetRapidFireReequip(value) self.rapidFireReequip = value end
function RageModule:SetRapidFireActive(value) self.rapidFireActive = value end
function RageModule:GetRapidFireActive() return self.rapidFireActive end

return RageModule
