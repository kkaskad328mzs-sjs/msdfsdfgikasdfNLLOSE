local RageModule = {}
RageModule.__index = RageModule

function RageModule.new(player)
	local self = setmetatable({}, RageModule)
	
	self.player = player
	self.Players = game:GetService("Players")
	self.RunService = game:GetService("RunService")
	self.Workspace = game:GetService("Workspace")
	self.ReplicatedStorage = game:GetService("ReplicatedStorage")
	
	self.RAGE_ENABLED = false
	self.RAGE_HITPART = "Head"
	self.RAGE_HITCHANCE = 100
	self.RAGE_HITCHANCE_ENABLED = false
	self.RAGE_AUTOSHOOT = false
	self.RAGE_NOSPREAD = false
	self.MAX_DISTANCE = 1000
	
	self.PREDICTION_ENABLED = true
	self.PREDICTION_STRENGTH = 0.15
	
	self.MIN_DAMAGE_ENABLED = false
	self.MIN_DAMAGE_VALUE = 0
	self.BASE_DAMAGE = 54
	
	self.lastShot = 0
	self.FIRE_RATE = 1.3
	self.ping = 0
	self.lastPingUpdate = 0
	self.activePlayers = {}
	self.lastPlayerListUpdate = 0
	
	self.BODY_PART_MULTIPLIERS = {
		["Head"] = 4.0,
		["UpperTorso"] = 1.0,
		["LowerTorso"] = 1.0,
		["Torso"] = 1.0,
		["HumanoidRootPart"] = 1.0,
		["LeftUpperArm"] = 0.75,
		["LeftLowerArm"] = 0.75,
		["LeftHand"] = 0.75,
		["RightUpperArm"] = 0.75,
		["RightLowerArm"] = 0.75,
		["RightHand"] = 0.75,
		["LeftUpperLeg"] = 0.6,
		["LeftLowerLeg"] = 0.6,
		["LeftFoot"] = 0.6,
		["RightUpperLeg"] = 0.6,
		["RightLowerLeg"] = 0.6,
		["RightFoot"] = 0.6,
		["Left Leg"] = 0.6,
		["Right Leg"] = 0.6,
	}
	
	self.MIN_DAMAGE_PRIORITY = {
		{name = "Legs", parts = {"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg"}},
		{name = "Arms", parts = {"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand", "Left Arm", "Right Arm"}},
		{name = "Body", parts = {"UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart"}},
		{name = "Head", parts = {"Head"}},
	}
	
	return self
end

function RageModule:IsAlive()
	local char = self.player.Character
	if not char then return false end
	local hum = char:FindFirstChild("Humanoid")
	return hum and hum.Health > 0
end

function RageModule:IsEnemy(target)
	if self.player.Team and target.Team then
		return self.player.Team ~= target.Team
	end
	return true
end

function RageModule:IsGrounded()
	local char = self.player.Character
	if not char then return false end
	
	local hum = char:FindFirstChild("Humanoid")
	if not hum then return false end
	
	if hum.FloorMaterial ~= Enum.Material.Air then
		return true
	end
	
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {char}
	params.FilterType = Enum.RaycastFilterType.Exclude
	
	local result = self.Workspace:Raycast(hrp.Position, Vector3.new(0, -3.5, 0), params)
	return result ~= nil
end

function RageModule:GetFireShot()
	local char = self.player.Character
	if not char then return nil end
	
	for _, tool in pairs(char:GetChildren()) do
		if tool:IsA("Tool") then
			local remotes = tool:FindFirstChild("Remotes")
			if remotes then
				local fireShot = remotes:FindFirstChild("FireShot") or remotes:FindFirstChild("fireShot")
				if fireShot then
					return fireShot
				end
			end
		end
	end
	
	return nil
end

function RageModule:CanBulletPassThrough(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	
	if part:IsA("WedgePart") then
		return true
	end
	
	local name = part.Name:lower()
	if name:find("hamik") or name:find("paletka") then
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

function RageModule:IsPartOfCharacter(part)
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

function RageModule:StrictWallCheck(origin, targetPos, myChar, targetChar)
	if not origin or not targetPos then
		return false
	end
	
	local direction = targetPos - origin
	local distance = direction.Magnitude
	
	if distance < 0.1 or distance > 1000 then
		return false
	end
	
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {myChar, targetChar}
	params.IgnoreWater = true
	
	local result = self.Workspace:Raycast(origin, direction, params)
	
	if not result then
		return true
	end
	
	local hitPart = result.Instance
	
	if hitPart:IsDescendantOf(targetChar) then
		return true
	end
	
	if self:CanBulletPassThrough(hitPart) or self:IsPartOfCharacter(hitPart) then
		local newOrigin = result.Position + direction.Unit * 0.1
		local newDirection = targetPos - newOrigin
		
		if newDirection.Magnitude < 0.1 then
			return true
		end
		
		params.FilterDescendantsInstances = {myChar, targetChar, hitPart}
		local result2 = self.Workspace:Raycast(newOrigin, newDirection, params)
		
		if not result2 then
			return true
		end
		
		if result2.Instance:IsDescendantOf(targetChar) then
			return true
		end
		
		return false
	end
	
	return false
end

function RageModule:MultiPointWallCheck(origin, targetPos, myChar, targetChar)
	if not origin or not targetPos or not myChar or not targetChar then
		return false
	end
	
	if self:StrictWallCheck(origin, targetPos, myChar, targetChar) then
		return true
	end
	
	for _, offset in ipairs({Vector3.new(0, 0.3, 0), Vector3.new(0, -0.3, 0)}) do
		if self:StrictWallCheck(origin, targetPos + offset, myChar, targetChar) then
			return true
		end
	end
	
	return false
end

function RageModule:PredictPosition(part, rootPart)
	if not self.PREDICTION_ENABLED or not rootPart then
		return part.Position
	end
	
	local velocity = rootPart.AssemblyLinearVelocity or Vector3.new()
	
	if velocity.Magnitude < 3 then
		return part.Position
	end
	
	return part.Position + velocity * self.PREDICTION_STRENGTH
end

function RageModule:CalculatePotentialDamage(partName, distance)
	local multiplier = self.BODY_PART_MULTIPLIERS[partName] or 0.5
	local damage = self.BASE_DAMAGE * multiplier
	
	if distance > 300 then
		damage = damage * 0.3
	elseif distance > 200 then
		damage = damage * 0.5
	elseif distance > 100 then
		damage = damage * 0.8
	end
	
	return math.floor(damage)
end

function RageModule:CheckMinDamage(part, distance)
	if self.MIN_DAMAGE_VALUE <= 0 then
		return true
	end
	
	local damage = self:CalculatePotentialDamage(part.Name, distance)
	return damage >= self.MIN_DAMAGE_VALUE
end

function RageModule:CheckHitchance()
	if not self.RAGE_HITCHANCE_ENABLED then
		return true
	end
	
	if self.RAGE_HITCHANCE <= 0 then
		return false
	end
	
	if self.RAGE_HITCHANCE >= 100 then
		return true
	end
	
	return math.random(1, 100) <= self.RAGE_HITCHANCE
end

function RageModule:UpdateActivePlayersList()
	table.clear(self.activePlayers)
	
	for _, targetPlayer in ipairs(self.Players:GetPlayers()) do
		if targetPlayer ~= self.player and self:IsEnemy(targetPlayer) then
			local targetChar = targetPlayer.Character
			if targetChar then
				local hum = targetChar:FindFirstChild("Humanoid")
				local rootPart = targetChar:FindFirstChild("HumanoidRootPart")
				if hum and hum.Health > 0 and rootPart then
					table.insert(self.activePlayers, {
						player = targetPlayer,
						character = targetChar,
						humanoid = hum,
						rootPart = rootPart
					})
				end
			end
		end
	end
end

function RageModule:GetTargetParts(char)
	local parts = {}
	
	if self.RAGE_HITPART == "Head" then
		local head = char:FindFirstChild("Head")
		if head then table.insert(parts, head) end
	elseif self.RAGE_HITPART == "Body" then
		for _, name in ipairs({"UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart"}) do
			local part = char:FindFirstChild(name)
			if part then table.insert(parts, part) end
		end
	elseif self.RAGE_HITPART == "Arms" then
		for _, name in ipairs({"RightUpperArm", "LeftUpperArm", "Right Arm", "Left Arm"}) do
			local part = char:FindFirstChild(name)
			if part then table.insert(parts, part) end
		end
	elseif self.RAGE_HITPART == "Legs" then
		for _, name in ipairs({"RightUpperLeg", "LeftUpperLeg", "Right Leg", "Left Leg"}) do
			local part = char:FindFirstChild(name)
			if part then table.insert(parts, part) end
		end
	end
	
	return parts
end

function RageModule:FindBestTarget()
	if not self:IsAlive() then return nil end
	
	local char = self.player.Character
	local myHead = char and char:FindFirstChild("Head")
	if not myHead then return nil end
	
	local now = tick()
	if now - self.lastPlayerListUpdate >= 0.5 then
		self.lastPlayerListUpdate = now
		self:UpdateActivePlayersList()
	end
	
	if #self.activePlayers == 0 then
		return nil
	end
	
	local bestTarget = nil
	local bestDist = self.MAX_DISTANCE
	
	for _, data in ipairs(self.activePlayers) do
		if not data.humanoid or data.humanoid.Health <= 0 then
			continue
		end
		
		if not data.rootPart or not data.rootPart.Parent then
			continue
		end
		
		local dist = (data.rootPart.Position - myHead.Position).Magnitude
		if dist > bestDist then
			continue
		end
		
		local targetParts = self:GetTargetParts(data.character)
		local validPart = nil
		
		if self.MIN_DAMAGE_ENABLED then
			for _, group in ipairs(self.MIN_DAMAGE_PRIORITY) do
				for _, partName in ipairs(group.parts) do
					local part = data.character:FindFirstChild(partName)
					if part and self:CheckMinDamage(part, dist) then
						if self:MultiPointWallCheck(myHead.Position, part.Position, char, data.character) then
							validPart = part
							break
						end
					end
				end
				if validPart then break end
			end
		else
			for _, part in ipairs(targetParts) do
				if self:MultiPointWallCheck(myHead.Position, part.Position, char, data.character) then
					validPart = part
					break
				end
			end
		end
		
		if validPart then
			bestDist = dist
			bestTarget = {
				player = data.player,
				character = data.character,
				targetPart = validPart,
				rootPart = data.rootPart,
				distance = dist
			}
		end
	end
	
	return bestTarget
end

function RageModule:Start()
	self.RunService.Heartbeat:Connect(function()
		if not self.RAGE_ENABLED then return end
		if not self:IsAlive() then return end
		
		if not self:IsGrounded() and not self.RAGE_NOSPREAD then
			return
		end
		
		if not self.RAGE_AUTOSHOOT then
			return
		end
		
		local currentTime = tick()
		if currentTime - self.lastShot < self.FIRE_RATE then
			return
		end
		
		if currentTime - self.lastPingUpdate >= 1 then
			self.lastPingUpdate = currentTime
			self.ping = self.player:GetNetworkPing() * 1000
		end
		
		local fireShot = self:GetFireShot()
		if not fireShot then return end
		
		local target = self:FindBestTarget()
		if not target then return end
		
		if not self:CheckHitchance() then
			return
		end
		
		local char = self.player.Character
		local head = char and char:FindFirstChild("Head")
		if not head then return end
		
		local targetPos = self:PredictPosition(target.targetPart, target.rootPart)
		local origin = head.Position
		local direction = (targetPos - origin).Unit
		
		local success = pcall(function()
			fireShot:FireServer(origin, direction, target.targetPart)
		end)
		
		if success then
			self.lastShot = currentTime
		end
	end)
end

function RageModule:SetEnabled(value)
	self.RAGE_ENABLED = value
end

function RageModule:SetHitpart(value)
	self.RAGE_HITPART = value
end

function RageModule:SetHitchance(value)
	self.RAGE_HITCHANCE = value
end

function RageModule:SetHitchanceEnabled(value)
	self.RAGE_HITCHANCE_ENABLED = value
end

function RageModule:SetAutoShoot(value)
	self.RAGE_AUTOSHOOT = value
end

function RageModule:SetNoSpread(value)
	self.RAGE_NOSPREAD = value
end

function RageModule:SetMaxDistance(value)
	self.MAX_DISTANCE = value
end

function RageModule:SetPredictionEnabled(value)
	self.PREDICTION_ENABLED = value
end

function RageModule:SetPredictionStrength(value)
	self.PREDICTION_STRENGTH = value
end

function RageModule:SetMinDamageEnabled(value)
	self.MIN_DAMAGE_ENABLED = value
end

function RageModule:SetMinDamageValue(value)
	self.MIN_DAMAGE_VALUE = value
end

return RageModule
