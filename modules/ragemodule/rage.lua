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
	
	self.fireShot = nil
	self.fireShotTime = 0
	self.rbLast = 0
	self.playerData = {}
	self.playerDataTime = 0
	self.myChar = nil
	self.myHRP = nil
	self.myHead = nil
	
	self.RayP = RaycastParams.new()
	self.RayP.FilterType = Enum.RaycastFilterType.Exclude
	self.RayP.IgnoreWater = true
	
	self.PLAYER_CACHE_INTERVAL = 0.4
	self.frame = 0
	
	return self
end

function RageModule:CacheChar()
	self.myChar = self.player.Character
	if self.myChar then
		self.myHRP = self.myChar:FindFirstChild("HumanoidRootPart")
		self.myHead = self.myChar:FindFirstChild("Head")
	else
		self.myHRP = nil
		self.myHead = nil
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
			self.RayP.FilterDescendantsInstances = {self.myChar}
			local best = nil
			
			for i = 1, 4 do
				local d = self.playerData[i]
				if d and (not self.rbTeamCheck or not d.team) and d.dist < self.rbMaxDist then
					if self.rbNoAir then
						local enemyPos = d.r.Position
						local groundRay = self.Workspace:Raycast(enemyPos, Vector3.new(0, -4, 0), self.RayP)
						local isInAir = groundRay == nil
						
						local enemyVelY = d.r.AssemblyLinearVelocity.Y
						if isInAir or math.abs(enemyVelY) > 8 then
							continue
						end
					end
					
					local tgt = self.rbHitbox == "Head" and d.head or d.torso or d.r
					if tgt then
						local dir = tgt.Position - head.Position
						local res = self.Workspace:Raycast(head.Position, dir, self.RayP)
						
						if self.rbWallCheck then
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
				local fs = self:GetFireShot()
				if fs then
					local tgt = self.rbHitbox == "Head" and best.head or best.torso or best.r
					local vel = best.r.AssemblyLinearVelocity
					local pos = tgt.Position
					if vel.Magnitude > 1 then
						pos = pos + Vector3.new(vel.X, 0, vel.Z) * self.player:GetNetworkPing() * self.rbPredMulti
					end
					pcall(fs.FireServer, fs, head.Position, (pos - head.Position).Unit, tgt)
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

return RageModule
