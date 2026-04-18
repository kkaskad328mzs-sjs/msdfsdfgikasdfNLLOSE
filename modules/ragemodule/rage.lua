local RageModule = {}
RageModule.__index = RageModule

function RageModule.new(player)
	local self = setmetatable({}, RageModule)
	
	self.player = player
	self.Players = game:GetService("Players")
	self.RunService = game:GetService("RunService")
	self.Workspace = game:GetService("Workspace")
	
	self.enabled = false
	self.autoFire = true
	self.hitbox = "Head"
	self.maxDistance = 500
	self.teamCheck = true
	self.wallCheck = true
	self.hitchanceEnabled = false
	self.hitchanceValue = 80
	self.hitchanceIterations = 100
	self.predictionEnabled = true
	self.predictionMultiplier = 1.0
	self.minDamageEnabled = false
	self.minDamageValue = 20
	self.minDamageOverkill = true
	self.autoScope = true
	self.multiPoint = true
	self.autoStop = false
	
	self.fireRate = 0.1
	self.lastShot = 0
	self.isScoped = false
	
	self.hitboxParts = {
		Head = {"Head"},
		Torso = {"UpperTorso", "LowerTorso", "Torso"},
		Pelvis = {"HumanoidRootPart"},
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
	local char = self.player.Character
	if not char then return nil end
	
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") and tool.Name == "SSG-08" then
			local remotes = tool:FindFirstChild("Remotes")
			if remotes then
				local fireShot = remotes:FindFirstChild("FireShot")
				local scope = remotes:FindFirstChild("Scope")
				local shotAck = remotes:FindFirstChild("ShotAck")
				
				if fireShot and fireShot:IsA("RemoteEvent") then
					return {
						fireShot = fireShot,
						scope = scope,
						shotAck = shotAck,
						tool = tool
					}
				end
			end
		end
	end
	
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
	local targets = {}
	local myChar = self.player.Character
	if not myChar then return targets end
	
	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then return targets end
	
	for _, targetPlayer in ipairs(self.Players:GetPlayers()) do
		if targetPlayer ~= self.player and self:IsEnemy(targetPlayer) then
			local targetChar = targetPlayer.Character
			if targetChar and self:IsAlive(targetChar) then
				local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
				if targetRoot then
					local distance = (myRoot.Position - targetRoot.Position).Magnitude
					if distance <= self.maxDistance then
						table.insert(targets, {
							player = targetPlayer,
							character = targetChar,
							root = targetRoot,
							distance = distance
						})
					end
				end
			end
		end
	end
	
	table.sort(targets, function(a, b)
		return a.distance < b.distance
	end)
	
	return targets
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
	if humanoid then
		return humanoid.Health
	end
	return 100
end

function RageModule:ScanBestHitbox(myHead, target)
	if not self.minDamageEnabled then
		return self:GetHitboxPart(target.character)
	end
	
	local targetHealth = self:GetTargetHealth(target.character)
	local bestPart = nil
	local bestDamage = 0
	
	for _, group in ipairs(self.scanPriority) do
		for _, partName in ipairs(group.parts) do
			local part = target.character:FindFirstChild(partName)
			if part then
				local canSee, visiblePos = false, part.Position
				if self.wallCheck then
					canSee, visiblePos = self:MultiPointCheck(myHead.Position, part, {self.player.Character, target.character})
				else
					canSee = true
				end
				
				if canSee then
					local damage = self:CalculateDamage(partName, target.distance)
					
					if self.minDamageOverkill then
						if damage >= targetHealth then
							return part, visiblePos
						end
					end
					
					if damage >= self.minDamageValue and damage > bestDamage then
						bestPart = part
						bestDamage = damage
					end
				end
			end
		end
	end
	
	return bestPart, bestPart and bestPart.Position or nil
end

function RageModule:GetHitboxPart(character)
	local parts = self.hitboxParts[self.hitbox] or self.hitboxParts.Head
	
	for _, partName in ipairs(parts) do
		local part = character:FindFirstChild(partName)
		if part then
			return part
		end
	end
	
	return character:FindFirstChild("Head")
end

function RageModule:WallCheck(origin, targetPos, ignoreList)
	local direction = targetPos - origin
	local distance = direction.Magnitude
	
	if distance < 0.1 then return true end
	
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}
	
	for _, item in ipairs(ignoreList) do
		if item and typeof(item) == "Instance" then
			table.insert(params.FilterDescendantsInstances, item)
		end
	end
	
	params.IgnoreWater = true
	
	local result = self.Workspace:Raycast(origin, direction, params)
	
	if not result then
		return true
	end
	
	for _, char in ipairs(ignoreList) do
		if char and typeof(char) == "Instance" and result.Instance:IsDescendantOf(char) then
			return true
		end
	end
	
	return false
end

function RageModule:MultiPointCheck(origin, targetPart, ignoreList)
	if not self.multiPoint then
		return self:WallCheck(origin, targetPart.Position, ignoreList)
	end
	
	local offsets = {
		Vector3.new(0, 0, 0),
		Vector3.new(0, 0.3, 0),
		Vector3.new(0, -0.3, 0),
		Vector3.new(0.3, 0, 0),
		Vector3.new(-0.3, 0, 0),
	}
	
	for _, offset in ipairs(offsets) do
		local targetPos = targetPart.Position + offset
		if self:WallCheck(origin, targetPos, ignoreList) then
			return true, targetPos
		end
	end
	
	return false, targetPart.Position
end

function RageModule:ApplyAutoStop()
	if not self.autoStop then return end
	
	local myChar = self.player.Character
	if not myChar then return end
	
	local humanoid = myChar:FindFirstChild("Humanoid")
	local rootPart = myChar:FindFirstChild("HumanoidRootPart")
	
	if not humanoid or not rootPart then return end
	if humanoid.FloorMaterial == Enum.Material.Air then return end
	
	local bodyVel = Instance.new("BodyVelocity")
	bodyVel.Velocity = Vector3.new(0, 0, 0)
	bodyVel.MaxForce = Vector3.new(100000, 0, 100000)
	bodyVel.P = 10000
	bodyVel.Parent = rootPart
	
	local oldSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	
	task.delay(0.15, function()
		if bodyVel and bodyVel.Parent then
			bodyVel:Destroy()
		end
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = oldSpeed
		end
	end)
end

function RageModule:HandleScope(weapon, shouldScope)
	if not self.autoScope or not weapon.scope then return end
	
	if shouldScope and not self.isScoped then
		local success = pcall(function()
			weapon.scope:FireServer(true)
		end)
		if success then
			self.isScoped = true
		end
	elseif not shouldScope and self.isScoped then
		pcall(function()
			weapon.scope:FireServer(false)
		end)
		self.isScoped = false
	end
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
	
	local spreadDirection = (direction + right * offsetX + up * offsetY).Unit
	
	return spreadDirection
end

function RageModule:CalculateHitChance(origin, targetPart, targetChar, spreadAngle)
	if not self.hitchanceEnabled then
		return 100
	end
	
	local hits = 0
	local targetPos = targetPart.Position
	local targetSize = targetPart.Size
	
	for i = 1, self.hitchanceIterations do
		local spreadDir = self:SimulateSpread(origin, targetPos, spreadAngle)
		
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {self.player.Character}
		params.IgnoreWater = true
		
		local maxDist = (targetPos - origin).Magnitude + targetSize.Magnitude
		local result = self.Workspace:Raycast(origin, spreadDir * maxDist, params)
		
		if result and result.Instance:IsDescendantOf(targetChar) then
			local hitPart = result.Instance
			if hitPart == targetPart or hitPart.Parent == targetChar then
				hits = hits + 1
			end
		end
	end
	
	return math.floor((hits / self.hitchanceIterations) * 100)
end

function RageModule:Shoot(weapon, origin, targetPos, targetPart)
	local direction = (targetPos - origin).Unit
	
	local success = pcall(function()
		weapon.fireShot:FireServer(origin, direction, targetPart)
		
		if weapon.shotAck then
			weapon.shotAck:FireServer()
		end
	end)
	
	return success
end

function RageModule:MainLoop()
	if not self.enabled or not self.autoFire then return end
	
	local now = tick()
	if now - self.lastShot < self.fireRate then return end
	
	local myChar = self.player.Character
	if not myChar or not self:IsAlive(myChar) then return end
	
	local myHead = myChar:FindFirstChild("Head")
	if not myHead then return end
	
	local weapon = self:GetWeapon()
	if not weapon then return end
	
	local targets = self:GetTargets()
	if #targets == 0 then return end
	
	self:HandleScope(weapon, true)
	
	for _, target in ipairs(targets) do
		local hitboxPart, visiblePos = nil, nil
		
		if self.minDamageEnabled then
			hitboxPart, visiblePos = self:ScanBestHitbox(myHead, target)
		else
			hitboxPart = self:GetHitboxPart(target.character)
			
			if hitboxPart then
				if self.wallCheck then
					if self.multiPoint then
						local canSee, pos = self:MultiPointCheck(myHead.Position, hitboxPart, {myChar, target.character})
						if canSee then
							visiblePos = pos
						else
							hitboxPart = nil
						end
					else
						local canSee = self:WallCheck(myHead.Position, hitboxPart.Position, {myChar, target.character})
						if canSee then
							visiblePos = hitboxPart.Position
						else
							hitboxPart = nil
						end
					end
				else
					visiblePos = hitboxPart.Position
				end
			end
		end
		
		if not hitboxPart or not visiblePos then continue end
		
		local predictedPos = self:PredictPosition(hitboxPart, target.root)
		
		if self.hitchanceEnabled then
			local spreadAngle = 0.5
			local hitchance = self:CalculateHitChance(myHead.Position, hitboxPart, target.character, spreadAngle)
			
			if hitchance < self.hitchanceValue then
				continue
			end
		end
		
		if self.autoStop then
			self:ApplyAutoStop()
		end
		
		local success = self:Shoot(weapon, myHead.Position, predictedPos, hitboxPart)
		
		if success then
			self.lastShot = now
			break
		end
	end
end

function RageModule:Start()
	self.RunService.Heartbeat:Connect(function()
		if self.enabled then
			self:MainLoop()
		end
	end)
	
	print("[Rage] Module started")
	print("[Rage] Auto-fire:", self.autoFire)
	print("[Rage] Wall check:", self.wallCheck)
	print("[Rage] Multi-point:", self.multiPoint)
end

function RageModule:SetEnabled(value)
	self.enabled = value
end

function RageModule:SetAutoFire(value)
	self.autoFire = value
end

function RageModule:SetHitbox(value)
	self.hitbox = value
end

function RageModule:SetMaxDistance(value)
	self.maxDistance = value
end

function RageModule:SetTeamCheck(value)
	self.teamCheck = value
end

function RageModule:SetWallCheck(value)
	self.wallCheck = value
end

function RageModule:SetHitchanceEnabled(value)
	self.hitchanceEnabled = value
end

function RageModule:SetHitchanceValue(value)
	self.hitchanceValue = value
end

function RageModule:SetHitchanceIterations(value)
	self.hitchanceIterations = value
end

function RageModule:SetPredictionEnabled(value)
	self.predictionEnabled = value
end

function RageModule:SetPredictionMultiplier(value)
	self.predictionMultiplier = value
end

function RageModule:SetFireRate(value)
	self.fireRate = value / 1000
end

function RageModule:SetMinDamageEnabled(value)
	self.minDamageEnabled = value
end

function RageModule:SetMinDamageValue(value)
	self.minDamageValue = value
end

function RageModule:SetMinDamageOverkill(value)
	self.minDamageOverkill = value
end

function RageModule:SetAutoScope(value)
	self.autoScope = value
end

function RageModule:SetMultiPoint(value)
	self.multiPoint = value
end

function RageModule:SetAutoStop(value)
	self.autoStop = value
end

return RageModule
