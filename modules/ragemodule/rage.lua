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
	self.AIRSHOT_ACTIVE = false
	self.AUTO_EQUIP_SSG = false
	self.MAX_DISTANCE = 1000
	
	self.PREDICTION_ENABLED = true
	self.PREDICTION_STRENGTH = 1.0
	self.BULLET_SPEED = 1000
	
	self.MIN_DAMAGE_ENABLED = false
	self.MIN_DAMAGE_VALUE = 0
	self.BASE_DAMAGE = 54
	
	self.lastShot = 0
	self.FIRE_RATE = 0.05
	self.FIRE_RATE_AWP = 1.0
	self.ping = 0
	self.lastPingUpdate = 0
	self.PING_UPDATE_RATE = 0.5
	self.activePlayers = {}
	self.lastPlayerListUpdate = 0
	self.PLAYER_LIST_UPDATE_RATE = 0.3
	self.autoEquippedOnce = false
	self.shotAttempts = 0
	self.maxShotAttempts = 3
	
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
		{name = "Legs", parts = {"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg"}, multiplier = 0.6},
		{name = "Arms", parts = {"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand", "Left Arm", "Right Arm"}, multiplier = 0.75},
		{name = "Body", parts = {"UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart"}, multiplier = 1.0},
		{name = "Head", parts = {"Head"}, multiplier = 4.0},
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

function RageModule:IsInAir()
	local char = self.player.Character
	if not char then return true end
	
	local hum = char:FindFirstChild("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return true end
	
	if hum.FloorMaterial == Enum.Material.Air then
		return true
	end
	
	local velocity = hrp.AssemblyLinearVelocity or hrp.Velocity or Vector3.new()
	if math.abs(velocity.Y) > 2 then
		return true
	end
	
	return false
end

function RageModule:GetGun()
	local char = self.player.Character
	if not char then return nil end
	
	for _, item in pairs(char:GetChildren()) do
		if item:IsA("Tool") then
			local handle = item:FindFirstChild("Handle")
			if not handle then continue end
			
			local remotes = item:FindFirstChild("Remotes")
			if remotes then
				local fireShot = remotes:FindFirstChild("FireShot")
				if fireShot then
					return {type = "AWP", fireShot = fireShot, fireRate = self.FIRE_RATE_AWP, tool = item, name = item.Name}
				end
				
				local castRay = remotes:FindFirstChild("CastRay")
				if castRay then
					local hole = item:FindFirstChild("Hole")
					return {type = "CastRay", castRay = castRay, hole = hole, fireRate = self.FIRE_RATE, tool = item, name = item.Name}
				end
				
				local shootRay = remotes:FindFirstChild("ShootRay")
				if shootRay then
					local hole = item:FindFirstChild("Hole") or item:FindFirstChild("Muzzle")
					return {type = "ShootRay", shootRay = shootRay, hole = hole, fireRate = self.FIRE_RATE, tool = item, name = item.Name}
				end
			end
			
			local shootEvent = item:FindFirstChild("ShootEvent") or item:FindFirstChild("Fire") or item:FindFirstChild("Shoot")
			if shootEvent and shootEvent:IsA("RemoteEvent") then
				local hole = item:FindFirstChild("Hole") or item:FindFirstChild("Muzzle") or item:FindFirstChild("FirePoint")
				return {type = "Generic", shootEvent = shootEvent, hole = hole, fireRate = self.FIRE_RATE, tool = item, name = item.Name}
			end
		end
	end
	
	return nil
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

function RageModule:GetBestVisiblePart(char)
	local priorities
	
	if self.RAGE_HITPART == "Head" then
		priorities = {
			"Head",
			"UpperTorso",
			"LowerTorso",
			"Torso",
			"HumanoidRootPart",
		}
	elseif self.RAGE_HITPART == "Body" then
		priorities = {
			"UpperTorso",
			"LowerTorso",
			"Torso",
			"HumanoidRootPart",
			"Head",
		}
	elseif self.RAGE_HITPART == "Arms" then
		priorities = {
			"RightUpperArm","LeftUpperArm","Right Arm","Left Arm",
			"UpperTorso","Torso",
		}
	elseif self.RAGE_HITPART == "Legs" then
		priorities = {
			"RightUpperLeg","LeftUpperLeg","Right Leg","Left Leg",
			"LowerTorso","Torso",
		}
	else
		priorities = {
			"Head","UpperTorso","Torso","HumanoidRootPart"
		}
	end
	
	for _, partName in ipairs(priorities) do
		local part = char:FindFirstChild(partName)
		if part and self:IsPartVisible(part, char) then
			return part
		end
	end
	
	return nil
end

function RageModule:GetTargetPart(char, distance)
	if self.AIRSHOT_ACTIVE then
		return char:FindFirstChild("Head")
	end
	
	if self.MIN_DAMAGE_ENABLED then
		for _, priorityGroup in ipairs(self.MIN_DAMAGE_PRIORITY) do
			for _, partName in ipairs(priorityGroup.parts) do
				local part = char:FindFirstChild(partName)
				if part then
					local damage = self:CalculatePotentialDamage(partName, distance)
					if damage >= self.MIN_DAMAGE_VALUE then
						return part
					end
				end
			end
		end
		return nil
	end
	
	if self.RAGE_HITPART == "Head" then
		return char:FindFirstChild("Head")
	end
	if self.RAGE_HITPART == "Body" then
		return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
	end
	if self.RAGE_HITPART == "Arms" then
		return char:FindFirstChild("RightUpperArm") or char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Right Arm") or char:FindFirstChild("Left Arm")
	end
	if self.RAGE_HITPART == "Legs" then
		return char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("Right Leg") or char:FindFirstChild("Left Leg")
	end
	return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

function RageModule:IsPartVisible(targetPart, targetChar)
	if not targetPart or not targetPart.Parent then return false end
	if not self:IsAlive() then return false end
	
	local myChar = self.player.Character
	if not myChar then return false end
	local myHead = myChar:FindFirstChild("Head")
	if not myHead then return false end
	
	local origin = myHead.Position
	local targetPos = targetPart.Position
	local dir = targetPos - origin
	local dist = dir.Magnitude
	
	if dist < 0.1 then return true end
	if dist > self.MAX_DISTANCE then return false end
	
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {myChar}
	params.IgnoreWater = true
	
	local unit = dir.Unit
	local curOrigin = origin
	
	for i = 1, 5 do
		local res = self.Workspace:Raycast(curOrigin, targetPos - curOrigin, params)
		
		if not res then return true end
		
		local hit = res.Instance
		
		if hit and hit:IsDescendantOf(targetChar) then
			return true
		end
		
		if hit then
			local name = hit.Name:lower()
			local parent = hit.Parent
			local parentName = parent and parent.Name:lower() or ""
			
			local isWall = name:find("wall") or name:find("barrier") or parentName:find("wall") or name:find("brick")
			local isGlass = hit.Transparency > 0.5 or name:find("glass") or name:find("window")
			local isSoft = hit.CanCollide == false or hit.CanQuery == false or hit.Transparency > 0.8
			local isPenetrable = name:find("wood") or name:find("metal") or hit.Material == Enum.Material.Wood
			
			if isGlass or isSoft or isPenetrable then
				curOrigin = res.Position + unit * 0.1
				continue
			end
			
			if not isWall and hit.Transparency > 0.2 then
				curOrigin = res.Position + unit * 0.05
				continue
			end
		end
		
		return false
	end
	
	return false
end

function RageModule:PredictPosition(part, rootPart)
	if not self.PREDICTION_ENABLED or not rootPart then return part.Position end
	
	local velocity = rootPart.AssemblyLinearVelocity or rootPart.Velocity or Vector3.new()
	if velocity.Magnitude < 1 then return part.Position end
	
	local distance = (part.Position - self.Workspace.CurrentCamera.CFrame.Position).Magnitude
	local travelTime = distance / self.BULLET_SPEED
	local pingTime = self.ping / 1000
	local dynamicTime = math.clamp(pingTime + travelTime, 0.02, 0.15)
	
	local predictedPos = part.Position + (velocity * dynamicTime * self.PREDICTION_STRENGTH)
	
	return predictedPos
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

function RageModule:FindTarget()
	if not self:IsAlive() then return nil end
	
	local char = self.player.Character
	local myHead = char and char:FindFirstChild("Head")
	if not myHead then return nil end
	
	local now = tick()
	if now - self.lastPlayerListUpdate >= self.PLAYER_LIST_UPDATE_RATE then
		self.lastPlayerListUpdate = now
		self:UpdateActivePlayersList()
	end
	
	local bestTarget
	local bestDist = self.MAX_DISTANCE
	
	for _, data in ipairs(self.activePlayers) do
		if not data.humanoid or data.humanoid.Health <= 0 then continue end
		if not data.rootPart or not data.rootPart.Parent then continue end
		
		local dist = (data.rootPart.Position - myHead.Position).Magnitude
		if dist > bestDist then continue end
		
		local part
		
		if self.AIRSHOT_ACTIVE then
			part = data.character:FindFirstChild("Head")
			if not part or not self:IsPartVisible(part, data.character) then
				continue
			end
			
		elseif self.MIN_DAMAGE_ENABLED then
			part = nil
			for _, group in ipairs(self.MIN_DAMAGE_PRIORITY) do
				for _, partName in ipairs(group.parts) do
					local p = data.character:FindFirstChild(partName)
					if p then
						local dmg = self:CalculatePotentialDamage(partName, dist)
						if dmg >= self.MIN_DAMAGE_VALUE and self:IsPartVisible(p, data.character) then
							part = p
							break
						end
					end
				end
				if part then break end
			end
			if not part then
				continue
			end
			
		else
			local visible = false
			for _, partName in ipairs({
				"Head",
				"UpperTorso",
				"LowerTorso",
				"Torso",
				"HumanoidRootPart",
				"LeftUpperArm","RightUpperArm",
				"LeftUpperLeg","RightUpperLeg"
			}) do
				local p = data.character:FindFirstChild(partName)
				if p and self:IsPartVisible(p, data.character) then
					visible = true
					break
				end
			end
			
			if not visible then
				continue
			end
			
			part = self:GetTargetPart(data.character, dist)
			if not part then
				continue
			end
		end
		
		bestDist = dist
		bestTarget = {
			player = data.player,
			character = data.character,
			targetPart = part,
			rootPart = data.rootPart,
			distance = dist
		}
	end
	
	return bestTarget
end

function RageModule:EquipSSGOnce()
	if not self.AUTO_EQUIP_SSG then return end
	if self.autoEquippedOnce then return end
	
	local char = self.player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	
	local currentTool = char:FindFirstChildOfClass("Tool")
	if currentTool and currentTool.Name == "SSG-08" then
		self.autoEquippedOnce = true
		return
	end
	
	local backpack = self.player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	
	local tool = backpack:FindFirstChild("SSG-08")
	if tool and tool:IsA("Tool") then
		hum:EquipTool(tool)
		self.autoEquippedOnce = true
	end
end

function RageModule:Start()
	self.player.CharacterAdded:Connect(function()
		self.autoEquippedOnce = false
	end)
	
	self.RunService.Heartbeat:Connect(function()
		self:EquipSSGOnce()
		
		if not self.RAGE_ENABLED then return end
		if not self:IsAlive() then return end
		
		local inAir = self:IsInAir()
		self.AIRSHOT_ACTIVE = self.RAGE_NOSPREAD and inAir
		
		if self.RAGE_AUTOSHOOT and inAir and not self.RAGE_NOSPREAD then
			return
		end
		
		local gun = self:GetGun()
		if not gun then return end
		
		if not self.RAGE_AUTOSHOOT then
			return
		end
		
		local currentTime = tick()
		if currentTime - self.lastShot < gun.fireRate then return end
		
		if currentTime - self.lastPingUpdate >= self.PING_UPDATE_RATE then
			self.lastPingUpdate = currentTime
			self.ping = self.player:GetNetworkPing() * 1000
		end
		
		local target = self:FindTarget()
		if not target then 
			self.shotAttempts = 0
			return 
		end
		
		if self.shotAttempts >= self.maxShotAttempts then
			self.shotAttempts = 0
			task.wait(0.1)
			return
		end
		
		if self.RAGE_HITCHANCE_ENABLED and not self.AIRSHOT_ACTIVE then
			local roll = math.random(1, 100)
			if roll > self.RAGE_HITCHANCE then
				return
			end
		end
		
		local char = self.player.Character
		local head = char and char:FindFirstChild("Head")
		if not head then return end
		
		local targetPos = self.PREDICTION_ENABLED
			and self:PredictPosition(target.targetPart, target.rootPart)
			or target.targetPart.Position
		
		if gun.type == "AWP" then
			local origin = head.Position
			local dirVec = targetPos - origin
			if dirVec.Magnitude < 0.01 then return end
			
			local direction = dirVec.Unit
			local ok = pcall(function()
				gun.fireShot:FireServer(origin, direction, target.targetPart)
			end)
			
			if ok then
				self.lastShot = currentTime
				self.shotAttempts = self.shotAttempts + 1
			end
			
		elseif gun.type == "CastRay" then
			if not gun.hole or not gun.hole.Parent then return end
			
			local origin = gun.hole.Position
			local dirVec = targetPos - origin
			if dirVec.Magnitude < 0.01 then return end
			
			local direction = dirVec.Unit
			local ray = Ray.new(origin, direction * 2000)
			local ok = pcall(function()
				gun.castRay:FireServer(ray, targetPos, target.player, target.targetPart)
			end)
			
			if ok then
				self.lastShot = currentTime
				self.shotAttempts = self.shotAttempts + 1
			end
			
		elseif gun.type == "ShootRay" then
			if not gun.hole or not gun.hole.Parent then return end
			
			local origin = gun.hole.Position
			local dirVec = targetPos - origin
			if dirVec.Magnitude < 0.01 then return end
			
			local direction = dirVec.Unit
			local ray = Ray.new(origin, direction * 2000)
			local ok = pcall(function()
				gun.shootRay:FireServer(ray, target.targetPart, target.player)
			end)
			
			if ok then
				self.lastShot = currentTime
				self.shotAttempts = self.shotAttempts + 1
			end
			
		elseif gun.type == "Generic" then
			local origin = gun.hole and gun.hole.Position or head.Position
			local dirVec = targetPos - origin
			if dirVec.Magnitude < 0.01 then return end
			
			local direction = dirVec.Unit
			local ok = pcall(function()
				gun.shootEvent:FireServer(targetPos, target.targetPart, direction, target.player)
			end)
			
			if ok then
				self.lastShot = currentTime
				self.shotAttempts = self.shotAttempts + 1
			end
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

function RageModule:SetAutoEquipSSG(value)
	self.AUTO_EQUIP_SSG = value
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

function RageModule:GetSettings()
	return {
		RAGE_ENABLED = self.RAGE_ENABLED,
		RAGE_HITPART = self.RAGE_HITPART,
		RAGE_HITCHANCE = self.RAGE_HITCHANCE,
		RAGE_HITCHANCE_ENABLED = self.RAGE_HITCHANCE_ENABLED,
		RAGE_AUTOSHOOT = self.RAGE_AUTOSHOOT,
		RAGE_NOSPREAD = self.RAGE_NOSPREAD,
		AUTO_EQUIP_SSG = self.AUTO_EQUIP_SSG,
		MAX_DISTANCE = self.MAX_DISTANCE,
		PREDICTION_ENABLED = self.PREDICTION_ENABLED,
		PREDICTION_STRENGTH = self.PREDICTION_STRENGTH,
		MIN_DAMAGE_ENABLED = self.MIN_DAMAGE_ENABLED,
		MIN_DAMAGE_VALUE = self.MIN_DAMAGE_VALUE,
	}
end

function RageModule:ApplySettings(settings)
	if not settings then return end
	
	if settings.RAGE_ENABLED ~= nil then self:SetEnabled(settings.RAGE_ENABLED) end
	if settings.RAGE_HITPART ~= nil then self:SetHitpart(settings.RAGE_HITPART) end
	if settings.RAGE_HITCHANCE ~= nil then self:SetHitchance(settings.RAGE_HITCHANCE) end
	if settings.RAGE_HITCHANCE_ENABLED ~= nil then self:SetHitchanceEnabled(settings.RAGE_HITCHANCE_ENABLED) end
	if settings.RAGE_AUTOSHOOT ~= nil then self:SetAutoShoot(settings.RAGE_AUTOSHOOT) end
	if settings.RAGE_NOSPREAD ~= nil then self:SetNoSpread(settings.RAGE_NOSPREAD) end
	if settings.AUTO_EQUIP_SSG ~= nil then self:SetAutoEquipSSG(settings.AUTO_EQUIP_SSG) end
	if settings.MAX_DISTANCE ~= nil then self:SetMaxDistance(settings.MAX_DISTANCE) end
	if settings.PREDICTION_ENABLED ~= nil then self:SetPredictionEnabled(settings.PREDICTION_ENABLED) end
	if settings.PREDICTION_STRENGTH ~= nil then self:SetPredictionStrength(settings.PREDICTION_STRENGTH) end
	if settings.MIN_DAMAGE_ENABLED ~= nil then self:SetMinDamageEnabled(settings.MIN_DAMAGE_ENABLED) end
	if settings.MIN_DAMAGE_VALUE ~= nil then self:SetMinDamageValue(settings.MIN_DAMAGE_VALUE) end
end

return RageModule
