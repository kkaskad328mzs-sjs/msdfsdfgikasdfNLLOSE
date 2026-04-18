local RageModule = {}
RageModule.__index = RageModule

function RageModule.new(player)
	local self = setmetatable({}, RageModule)
	
	self.player = player
	self.Players = game:GetService("Players")
	self.RunService = game:GetService("RunService")
	self.Workspace = game:GetService("Workspace")
	
	self.rbEnabled = false
	self.rbAutoFire = true
	self.rbHitbox = "Head"
	self.rbMaxDist = 500
	self.rbFireRate = 0.1
	self.rbPredMulti = 1.0
	self.rbNoAir = true
	self.rbWallCheck = true
	self.rbTeamCheck = true
	self.rbHitchance = 100
	self.rbHitchanceEnabled = false
	self.rbMinDamage = 0
	self.rbMinDamageEnabled = false
	self.rbMultiPoint = true
	self.rbAutoStop = false
	
	self.fireShot = nil
	self.fireShotTime = 0
	self.rbLast = 0
	self.playerData = {}
	self.playerDataTime = 0
	self.myChar = nil
	self.myHRP = nil
	self.myHead = nil
	self.myHum = nil
	
	self.RayP = RaycastParams.new()
	self.RayP.FilterType = Enum.RaycastFilterType.Exclude
	self.RayP.IgnoreWater = true
	
	self.PLAYER_CACHE_INTERVAL = 0.4
	self.BULLET_SPEED = 1000
	self.frame = 0
	
	self.BODY_PART_MULTIPLIERS = {
		["Head"] = 4.0,
		["UpperTorso"] = 1.0,
		["LowerTorso"] = 1.0,
		["Torso"] = 1.0,
		["HumanoidRootPart"] = 1.0,
		["LeftUpperArm"] = 0.75,
		["RightUpperArm"] = 0.75,
		["LeftUpperLeg"] = 0.6,
		["RightUpperLeg"] = 0.6,
		["Left Leg"] = 0.6,
		["Right Leg"] = 0.6,
	}
	
	self.MIN_DAMAGE_PRIORITY = {
		{name = "Legs", parts = {"LeftUpperLeg", "RightUpperLeg", "Left Leg", "Right Leg"}},
		{name = "Arms", parts = {"LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm"}},
		{name = "Body", parts = {"UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart"}},
		{name = "Head", parts = {"Head"}},
	}
	
	return self
end

function RageModule:CacheChar()
	self.myChar = self.player.Character
	if self.myChar then
		self.myHRP = self.myChar:FindFirstChild("HumanoidRootPart")
		self.myHead = self.myChar:FindFirstChild("Head")
		self.myHum = self.myChar:FindFirstChild("Humanoid")
	else
		self.myHRP = nil
		self.myHead = nil
		self.myHum = nil
	end
end

function RageModule:GetFireShot()
	local now = tick()
	if self.fireShot and self.fireShot.Parent and now - self.fireShotTime < 5 then
		return self.fireShot
	end
	if not self.myChar then return nil end
	
	for _, child in ipairs(self.myChar:GetChildren()) do
		if child:IsA("Tool") then
			local remotes = child:FindFirstChild("Remotes")
			if remotes then
				local fs = remotes:FindFirstChild("FireShot") or remotes:FindFirstChild("fireShot")
				if fs then
					self.fireShot = fs
					self.fireShotTime = now
					return fs
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
	
	if part.Transparency > 0.3 then
		return true
	end
	
	if not part.CanCollide then
		return true
	end
	
	return false
end

function RageModule:MultiPointWallCheck(origin, targetPart, targetChar)
	if not origin or not targetPart or not targetChar then
		return false
	end
	
	self.RayP.FilterDescendantsInstances = {self.myChar}
	
	local checkPoint = function(offset)
		local targetPos = targetPart.Position + offset
		local dir = targetPos - origin
		local res = self.Workspace:Raycast(origin, dir, self.RayP)
		
		if not res then
			return true
		end
		
		if res.Instance:IsDescendantOf(targetChar) then
			return true
		end
		
		if self:CanBulletPassThrough(res.Instance) then
			local newOrigin = res.Position + dir.Unit * 0.1
			local newDir = targetPos - newOrigin
			
			if newDir.Magnitude < 0.1 then
				return true
			end
			
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = {self.myChar, res.Instance}
			params.IgnoreWater = true
			
			local res2 = self.Workspace:Raycast(newOrigin, newDir, params)
			
			if not res2 or res2.Instance:IsDescendantOf(targetChar) then
				return true
			end
		end
		
		return false
	end
	
	if checkPoint(Vector3.new(0, 0, 0)) then
		return true
	end
	
	if self.rbMultiPoint then
		for _, offset in ipairs({
			Vector3.new(0, 0.3, 0),
			Vector3.new(0, -0.3, 0),
			Vector3.new(0.2, 0, 0),
			Vector3.new(-0.2, 0, 0)
		}) do
			if checkPoint(offset) then
				return true
			end
		end
	end
	
	return false
end

function RageModule:CalculateDamage(partName, distance)
	local multiplier = self.BODY_PART_MULTIPLIERS[partName] or 0.5
	local damage = 54 * multiplier
	
	if distance > 300 then
		damage = damage * 0.3
	elseif distance > 200 then
		damage = damage * 0.5
	elseif distance > 100 then
		damage = damage * 0.8
	end
	
	return math.floor(damage)
end

function RageModule:CheckHitchance()
	if not self.rbHitchanceEnabled then
		return true
	end
	
	if self.rbHitchance >= 100 then
		return true
	end
	
	if self.rbHitchance <= 0 then
		return false
	end
	
	return math.random(1, 100) <= self.rbHitchance
end

function RageModule:GetBestTargetPart(data)
	if self.rbMinDamageEnabled and self.rbMinDamage > 0 then
		for _, group in ipairs(self.MIN_DAMAGE_PRIORITY) do
			for _, partName in ipairs(group.parts) do
				local part = data.c:FindFirstChild(partName)
				if part then
					local damage = self:CalculateDamage(partName, data.dist)
					if damage >= self.rbMinDamage then
						if self:MultiPointWallCheck(self.myHead.Position, part, data.c) then
							return part
						end
					end
				end
			end
		end
		return nil
	end
	
	local tgt = self.rbHitbox == "Head" and data.head or data.torso or data.r
	if tgt and self:MultiPointWallCheck(self.myHead.Position, tgt, data.c) then
		return tgt
	end
	
	return nil
end

function RageModule:PredictPosition(part, rootPart, distance)
	local vel = rootPart.AssemblyLinearVelocity
	if vel.Magnitude < 1 then
		return part.Position
	end
	
	local travelTime = distance / self.BULLET_SPEED
	local ping = self.player:GetNetworkPing()
	local predTime = (ping + travelTime) * self.rbPredMulti
	
	return part.Position + Vector3.new(vel.X, 0, vel.Z) * predTime
end

function RageModule:ApplyAutoStop()
	if not self.rbAutoStop or not self.myHum or not self.myHRP then
		return
	end
	
	if self.myHum.FloorMaterial == Enum.Material.Air then
		return
	end
	
	local bodyVel = Instance.new("BodyVelocity")
	bodyVel.Velocity = Vector3.new(0, 0, 0)
	bodyVel.MaxForce = Vector3.new(100000, 0, 100000)
	bodyVel.P = 10000
	bodyVel.Parent = self.myHRP
	
	local oldSpeed = self.myHum.WalkSpeed
	self.myHum.WalkSpeed = 0
	
	task.delay(0.1, function()
		if bodyVel and bodyVel.Parent then
			bodyVel:Destroy()
		end
		if self.myHum and self.myHum.Parent then
			self.myHum.WalkSpeed = oldSpeed
		end
	end)
end

function RageModule:UpdatePlayerData()
	local now = tick()
	if now - self.playerDataTime < self.PLAYER_CACHE_INTERVAL then return end
	self.playerDataTime = now
	
	table.clear(self.playerData)
	
	if not self.myHRP then return end
	local myPos = self.myHRP.Position
	local myTeam = self.player.Team
	local myColor = self.player.TeamColor
	local count = 0
	
	for _, p in ipairs(self.Players:GetPlayers()) do
		if p ~= self.player then
			local c = p.Character
			if c then
				local h = c:FindFirstChild("Humanoid")
				local r = c:FindFirstChild("HumanoidRootPart")
				if h and h.Health > 0 and r then
					local dist = (myPos - r.Position).Magnitude
					if dist < 600 then
						count = count + 1
						local isTeam = myTeam and (p.Team == myTeam or p.TeamColor == myColor)
						self.playerData[count] = {
							p = p,
							c = c,
							h = h,
							r = r,
							head = c:FindFirstChild("Head"),
							torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso"),
							dist = dist,
							team = isTeam
						}
					end
				end
			end
		end
	end
	
	for i = 1, count - 1 do
		for j = i + 1, count do
			if self.playerData[j] and self.playerData[i] and self.playerData[j].dist < self.playerData[i].dist then
				self.playerData[i], self.playerData[j] = self.playerData[j], self.playerData[i]
			end
		end
	end
end

function RageModule:MainLoop()
	self.frame = self.frame + 1
	
	if self.frame % 15 == 0 then
		self:CacheChar()
	end
	
	if not self.myChar or not self.myHRP then return end
	
	self:UpdatePlayerData()
	
	local now = tick()
	local head = self.myHead
	
	if self.rbEnabled and self.rbAutoFire and self.frame % 3 == 0 and head then
		if now - self.rbLast >= self.rbFireRate then
			local best = nil
			
			for i = 1, 4 do
				local d = self.playerData[i]
				if d and (not self.rbTeamCheck or not d.team) and d.dist < self.rbMaxDist then
					if self.rbNoAir then
						self.RayP.FilterDescendantsInstances = {self.myChar}
						local enemyPos = d.r.Position
						local groundRay = self.Workspace:Raycast(enemyPos, Vector3.new(0, -4, 0), self.RayP)
						local isInAir = groundRay == nil
						
						local enemyVelY = d.r.AssemblyLinearVelocity.Y
						if isInAir or math.abs(enemyVelY) > 8 then
							continue
						end
					end
					
					local tgt = self:GetBestTargetPart(d)
					if tgt then
						best = {data = d, part = tgt}
						break
					end
				end
			end
			
			if best then
				if not self:CheckHitchance() then
					return
				end
				
				if self.rbAutoStop then
					self:ApplyAutoStop()
				end
				
				local fs = self:GetFireShot()
				if fs then
					local pos = self:PredictPosition(best.part, best.data.r, best.data.dist)
					pcall(fs.FireServer, fs, head.Position, (pos - head.Position).Unit, best.part)
					self.rbLast = now
				end
			end
		end
	end
end

function RageModule:Start()
	self:CacheChar()
	
	self.player.CharacterAdded:Connect(function()
		self:CacheChar()
		self.fireShot = nil
		self.playerData = {}
		self.playerDataTime = 0
		self.fireShotTime = 0
	end)
	
	self.RunService.Heartbeat:Connect(function()
		if self.rbEnabled then
			self:MainLoop()
		end
	end)
end

function RageModule:SetEnabled(value)
	self.rbEnabled = value
end

function RageModule:SetAutoFire(value)
	self.rbAutoFire = value
end

function RageModule:SetHitbox(value)
	self.rbHitbox = value
end

function RageModule:SetMaxDist(value)
	self.rbMaxDist = value
end

function RageModule:SetFireRate(value)
	self.rbFireRate = value / 1000
end

function RageModule:SetPredMulti(value)
	self.rbPredMulti = value
end

function RageModule:SetNoAir(value)
	self.rbNoAir = value
end

function RageModule:SetWallCheck(value)
	self.rbWallCheck = value
end

function RageModule:SetTeamCheck(value)
	self.rbTeamCheck = value
end

function RageModule:SetHitchance(value)
	self.rbHitchance = value
end

function RageModule:SetHitchanceEnabled(value)
	self.rbHitchanceEnabled = value
end

function RageModule:SetMinDamage(value)
	self.rbMinDamage = value
end

function RageModule:SetMinDamageEnabled(value)
	self.rbMinDamageEnabled = value
end

function RageModule:SetMultiPoint(value)
	self.rbMultiPoint = value
end

function RageModule:SetAutoStop(value)
	self.rbAutoStop = value
end

return RageModule
