-- ============================================
-- Roblox CS 防御功能 — ESP + Aimbot + UI
-- 队伍检测：基于 player:GetAttribute("Team") = "T" | "CT"
-- 不依赖 GC 扫描，服务器权威数据，可靠稳定
-- ============================================

print("[CS] ===== 开始加载 =====")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

print("[CS] 服务初始化完毕")

-- ============================================
-- 配置表
-- ============================================
local Config = {
	ESP_Enabled = true,
	ShowRays = false,
	ShowHealthBars = false,
	ShowHeadCircles = true,
	ShowFovCircle = true,

	RayColor = Color3.fromRGB(0, 255, 0),
	HealthBarColor_High = Color3.fromRGB(0, 255, 0),
	HealthBarColor_Mid = Color3.fromRGB(255, 255, 0),
	HealthBarColor_Low = Color3.fromRGB(255, 0, 0),
	HeadCircleColor = Color3.fromRGB(255, 255, 0),
	FovCircleColor = Color3.fromRGB(255, 255, 255),

	Aimbot_Enabled = true,
	Aimbot_Range = 500,
	Aimbot_FOV = 30,
	Aimbot_Smoothness = 20,
	Aimbot_Prediction = 0.5,
	Aimbot_TargetPart = "Head",

	-- 人类化瞄准 — donk 级别（S-Tier）
	Aimbot_Humanize = true,        -- 总开关：启用人类化行为
	Aimbot_ReactionMin = 100,      -- 最小反应延迟 (ms) — donk 级
	Aimbot_ReactionMax = 130,      -- 最大反应延迟 (ms) — donk 级
	Aimbot_OvershootChance = 0.03, -- 过冲概率 — donk 几乎不失误
	Aimbot_MicroJitter = 0.12,     -- 手部微颤幅度 — donk 手极稳
	Aimbot_PredictionError = 0.04, -- 预判误差 — 近乎读心
	Aimbot_PrefireAngle = 0.35,    -- 预开枪角度 (度) — donk 喷子起手

	-- 击杀追踪（最后一颗子弹轨道）— 蓝色发光半透明射线
	KillTracer_Enabled = true,     -- 击杀追踪开关
	KillTracer_Color = Color3.fromRGB(0, 170, 255), -- 主射线颜色（蓝色）
	KillTracer_Duration = 6,       -- 轨迹持续时间 (秒)
	KillTracer_Thickness = 2.5,    -- 初始线宽
	KillTracer_GlowColor = Color3.fromRGB(120, 220, 255), -- 辉光颜色（浅蓝色）
	KillSound_Enabled = true,      -- 击杀音效开关
	KillSound_ID = "rbxassetid://2513174484", -- 击杀音效 (Fortnite 爆头)
	KillHighlight_Enabled = true,  -- 击杀后高亮尸体开关
	KillHighlight_Color = Color3.fromRGB(0, 150, 255), -- 高亮颜色（蓝色发光雾状）
	KillHighlight_Duration = 6,    -- 高亮持续时间 (秒)
	KillHighlight_FadeOut = true,  -- 高亮结束前是否渐隐消散
	DebugLog = false,              -- 调试日志（诊断用，正常可关闭）

	WallCheck = true,
	TeamCheck = true,
	RaycastCacheExpiry = 0.1,
	CacheCleanupInterval = 5,
}

-- ============================================
-- 内部状态
-- ============================================
local ESP = {
	rays = {},
	healthBars = {},
	headCircles = {},
	fovCircle = nil,
	aimbotTarget = nil,
	aimbotConnection = nil,
	aimbot_GroundTimer = 0,
	aimbot_IsGroundAiming = false,
	-- 人类化瞄准状态机
	aimbotPhase = "idle",          -- "idle" | "reacting" | "flicking" | "ontarget"
	aimbotReactUntil = 0,          -- 反应阶段结束时间戳
	aimbotFlickStart = 0,          -- 甩枪开始时间戳
	aimbotWillOvershoot = false,   -- 本次 flick 是否过冲
	aimbotOvershootDir = nil,      -- 过冲方向
	aimbotJitterPhase = 0,         -- 微颤相位
	aimbotJitterSpeed = 0,         -- 微颤频率
	aimbotLastTarget = nil,        -- 上一帧目标位置（追踪用）
	aimbotPrefired = false,        -- 预开枪是否已触发
	aimbotFlickDirection = nil,    -- 甩枪初始方向（用于 spray transfer 修正）
	-- 击杀追踪状态
	killTracers = {},              -- 当前活跃的击杀轨迹 { { line, glow, from, to, spawnTime, isCrit }, ... }
	killHighlights = {},  -- 击杀后高亮尸体
	playerModels = {}, -- 按玩家缓存生前角色模板 { [player] = { model = Instance, parts = {[name]=CFrame}, pivot = CFrame, alive = bool } }
	raycastCache = {},
	lastCleanup = 0,
	localPlayer = nil,
}

-- ============================================
-- 队伍检测 — 基于 player:GetAttribute("Team")
-- 服务器权威数据，每帧动态读取，自动适配攻防互换
-- ============================================
function ESP:initTeamCheck()
	local lp = Players.LocalPlayer

	-- 等待 DataLoaded 确保服务器数据已同步
	if not lp:GetAttribute("DataLoaded") then
		print("[CS] 等待队伍数据同步...")
		for _ = 1, 100 do
			if lp:GetAttribute("DataLoaded") then break end
			task.wait(0.1)
		end
	end

	local myTeam = lp:GetAttribute("Team")
	if myTeam == "T" or myTeam == "CT" then
		print("[CS] 队伍检测初始化完成，当前阵营: " .. (myTeam == "T" and "民兵" or "操作员"))
		return
	end

	print("[CS] 队伍检测初始化完成，等待首局分配阵营")
end

function ESP:isEnemy(player)
	if not Config.TeamCheck then return true end
	if player == self.localPlayer then return false end

	-- 动态读取本地玩家当前队伍（适配 CS2 攻防互换）
	local lp = Players.LocalPlayer
	local myTeam = lp:GetAttribute("Team")

	-- 本地玩家尚未分配阵营（局间过渡期），默认全部视为敌人
	if myTeam ~= "T" and myTeam ~= "CT" then
		return true
	end

	local team = player:GetAttribute("Team")
	if team == "T" or team == "CT" then
		return team ~= myTeam
	end
	return true  -- 未知默认视为敌人
end

-- 根据击杀事件的 Victim 字段定位玩家
-- Victim 可能是纯 Name / DisplayName / 带格式或前后缀的复合字符串，需鲁棒匹配
function ESP:findPlayerByVictim(victim)
	if type(victim) ~= "string" or victim == "" then return nil end
	-- 去除富文本标签、空格、控制字符，得到干净的候选名
	local clean = victim:gsub("[<>/\\%c%s]", "")
	if clean == "" then return nil end
	for _, p in ipairs(Players:GetPlayers()) do
		local n = p.Name
		local d = p.DisplayName
		if clean == n or clean == d
			or clean:find(n, 1, true) or clean:find(d, 1, true)
			or n:find(clean, 1, true) or d:find(clean, 1, true) then
			return p
		end
	end
	return nil
end

-- ============================================
-- 墙体检测
-- ============================================
function ESP:isPlayerVisible(player)
	if not Config.WallCheck then return true end
	local cacheKey = player.UserId
	local cached = self.raycastCache[cacheKey]
	if cached and (tick() - cached.time) < Config.RaycastCacheExpiry then
		return cached.visible
	end
	local localChar = self.localPlayer and self.localPlayer.Character
	local targetChar = player.Character
	if not localChar or not targetChar then return false end
	local localHead = localChar:FindFirstChild("Head")
	local targetHead = targetChar:FindFirstChild("Head")
	if not localHead or not targetHead then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = {localChar, targetChar}
	params.IgnoreWater = true
	local direction = targetHead.Position - localHead.Position
	local result = Workspace:Raycast(localHead.Position, direction, params)
	local visible = false
	if not result then
		visible = true
	elseif result.Instance and result.Instance:IsDescendantOf(targetChar) then
		visible = true
	end
	self.raycastCache[cacheKey] = { visible = visible, time = tick() }
	return visible
end

function ESP:cleanRaycastCache()
	local now = tick()
	for key, data in pairs(self.raycastCache) do
		if (now - data.time) > Config.RaycastCacheExpiry * 2 then
			self.raycastCache[key] = nil
		end
	end
end

-- ============================================
-- 自瞄 - 移动预测（人类化：加入预判误差）
-- ============================================
function ESP:predictTargetPosition(player)
	if not player or not player.Character then return nil end
	local char = player.Character
	local part = char:FindFirstChild(Config.Aimbot_TargetPart)
	local humanoid = char:FindFirstChild("Humanoid")
	local rootPart = char:FindFirstChild("HumanoidRootPart")
	if not part or not humanoid or not rootPart then
		if part then return part.Position end
		return nil
	end
	local velocity = rootPart.Velocity
	local currentPos = part.Position
	local distance = (currentPos - Workspace.CurrentCamera.CFrame.Position).Magnitude
	local timeToHit = distance / 1000
	local predicted = currentPos + (velocity * timeToHit * Config.Aimbot_Prediction)

	-- 人类化：预判不完美，加入随机误差
	if Config.Aimbot_Humanize and Config.Aimbot_PredictionError > 0 then
		local errorMag = velocity.Magnitude * timeToHit * Config.Aimbot_PredictionError
		predicted = predicted + Vector3.new(
			(math.random() - 0.5) * errorMag * 2,
			(math.random() - 0.5) * errorMag,
			(math.random() - 0.5) * errorMag * 2
		)
	end

	return predicted
end

-- ============================================
-- 自瞄 - 人类化瞄准 · donk 级别
-- 四阶段：reacting → flicking → prefiring → ontarget
-- 甩枪极快干净，预开枪 + 喷子转移，追踪零抖动
-- ============================================
function ESP:aimAtPlayer(player)
	if not player or not player.Character then return end
	local camera = Workspace.CurrentCamera
	local currentCFrame = camera.CFrame
	local now = tick()

	-- 检查目标是否存活（用于 spray transfer 检测）
	local char = player.Character
	local humanoid = char and char:FindFirstChild("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		-- 目标死亡 → 触发 spray transfer：立即找下一个可见目标
		self.aimbotTarget = nil
		self.aimbotPhase = "idle"
		self.aimbotPrefired = false
		return
	end

	local targetPosition = self:predictTargetPosition(player)
	if not targetPosition then return end
	if Config.WallCheck and not self:isPlayerVisible(player) then return end

	local cameraPos = currentCFrame.Position
	local currentDir = currentCFrame.LookVector
	local targetDir = (targetPosition - cameraPos).Unit
	local angleToTarget = math.acos(math.clamp(currentDir:Dot(targetDir), -1, 1))

	-- === Phase 1: 反应延迟（donk 100-130ms，低方差） ===
	if self.aimbotPhase == "reacting" then
		if now < self.aimbotReactUntil then return end
		self.aimbotPhase = "flicking"
		self.aimbotFlickStart = now
		self.aimbotWillOvershoot = math.random() < Config.Aimbot_OvershootChance
		self.aimbotJitterPhase = math.random() * math.pi * 2
		self.aimbotJitterSpeed = 8 + math.random() * 3  -- 10Hz 附近，精英级震颤
		self.aimbotLastTarget = targetPosition
		self.aimbotPrefired = false
		-- 记录甩枪初始方向（用于检测 spray transfer 方向一致性）
		self.aimbotFlickDirection = targetDir
		if self.aimbotWillOvershoot then
			local right = currentDir:Cross(Vector3.new(0, 1, 0)).Unit
			if right.Magnitude < 0.01 then right = Vector3.new(1, 0, 0) end
			self.aimbotOvershootDir = (math.random() < 0.5) and right or -right
		end
	end

	-- === Phase 2: 甩枪（donk 风格：极快，50-120ms，缓入曲线） ===
	if self.aimbotPhase == "flicking" then
		-- donk flick 时长：50-120ms
		local elapsed = now - self.aimbotFlickStart
		local flickDuration = 0.05 + (Config.Aimbot_Smoothness / 20) * 0.07
		local t = math.clamp(elapsed / flickDuration, 0, 1)

		-- easeInQuad 缓入，但 donk 加速更快：t² → 前半段就达到 60% 速度
		local easedT = t * t
		-- donk 峰值速度：极高
		local peakSpeed = 0.38 + (1 - Config.Aimbot_Smoothness / 20) * 0.22
		local flickSpeed = easedT * peakSpeed * 1.8

		-- 过冲处理：仅 3% 概率，极微幅度，1 帧修正
		if self.aimbotWillOvershoot and self.aimbotOvershootDir and t > 0.65 then
			local bias = self.aimbotOvershootDir * 0.008
			local overshootTarget = (targetDir + bias).Unit
			local newDir = currentDir:Lerp(overshootTarget, flickSpeed)
			camera.CFrame = CFrame.lookAt(cameraPos, cameraPos + newDir)
			if t > 0.8 then
				self.aimbotPhase = "ontarget"
				self.aimbotWillOvershoot = false
			end
			return
		end

		local newDir = currentDir:Lerp(targetDir, flickSpeed)
		camera.CFrame = CFrame.lookAt(cameraPos, cameraPos + newDir)

		-- donk 风格：距离目标 0.35° 就进入预开枪，不必等完全锁定
		if angleToTarget < math.rad(Config.Aimbot_PrefireAngle) then
			self.aimbotPhase = "prefiring"
			self.aimbotPrefired = true
			self.aimbotLastTarget = targetPosition
		end
		if t >= 1.0 then
			self.aimbotPhase = "ontarget"
		end
		self.aimbotLastTarget = targetPosition
		return
	end

	-- === Phase 3: 预开枪（donk 招牌：准星差 0.35° 就开始喷，喷子修正到完全锁定） ===
	if self.aimbotPhase == "prefiring" then
		-- 预开枪期间的修正：仍然向目标靠拢，但速度稍慢（模拟喷子修正）
		local prefireSpeed = 0.15 + (1 - Config.Aimbot_Smoothness / 20) * 0.15

		-- 极微颤（喷子中的自然波动）
		local jitter = 0
		if Config.Aimbot_MicroJitter > 0 then
			self.aimbotJitterPhase = self.aimbotJitterPhase + 0.06 * self.aimbotJitterSpeed
			jitter = math.sin(self.aimbotJitterPhase) * Config.Aimbot_MicroJitter * 0.001
				+ (math.random() - 0.5) * Config.Aimbot_MicroJitter * 0.0005
		end

		local right = currentDir:Cross(Vector3.new(0, 1, 0)).Unit
		if right.Magnitude < 0.01 then right = Vector3.new(1, 0, 0) end
		local up = right:Cross(currentDir).Unit
		local jitteredDir = (targetDir + right * jitter + up * jitter * 0.5).Unit

		local newDir = currentDir:Lerp(jitteredDir, prefireSpeed)
		camera.CFrame = CFrame.lookAt(cameraPos, cameraPos + newDir)

		-- 完全锁定后 → ontarget
		if angleToTarget < math.rad(0.15) then
			self.aimbotPhase = "ontarget"
		end
		self.aimbotLastTarget = targetPosition
		return
	end

	-- === Phase 4: 锁定追踪（donk 级：近乎零抖动，追踪极快） ===
	if self.aimbotPhase == "ontarget" then
		local targetDelta = Vector3.zero
		if self.aimbotLastTarget then
			targetDelta = targetPosition - self.aimbotLastTarget
		end
		self.aimbotLastTarget = targetPosition

		-- donk 追踪速度：快且紧
		local trackSpeed = 0.35 + (1 - Config.Aimbot_Smoothness / 20) * 0.30  -- 0.35-0.65

		-- 微颤：donk 级别几乎不可见
		local jitter = 0
		if Config.Aimbot_MicroJitter > 0 then
			self.aimbotJitterPhase = self.aimbotJitterPhase + 0.06 * self.aimbotJitterSpeed
			jitter = math.sin(self.aimbotJitterPhase) * Config.Aimbot_MicroJitter * 0.0008
				+ (math.random() - 0.5) * Config.Aimbot_MicroJitter * 0.0004
		end

		local right = currentDir:Cross(Vector3.new(0, 1, 0)).Unit
		if right.Magnitude < 0.01 then right = Vector3.new(1, 0, 0) end
		local up = right:Cross(currentDir).Unit
		local jitteredDir = (targetDir + right * jitter + up * jitter * 0.5).Unit

		-- 目标移动时加速追踪（donk 的读盘能力）
		local effectiveSpeed = trackSpeed
		if targetDelta.Magnitude > 0.3 then
			effectiveSpeed = trackSpeed * 1.6  -- 加速追踪
		end

		local newDir = currentDir:Lerp(jitteredDir, effectiveSpeed)
		camera.CFrame = CFrame.lookAt(cameraPos, cameraPos + newDir)
		return
	end
end

-- ============================================
-- 自瞄 - 经典瞄准（非人类化，保留原逻辑）
-- ============================================
function ESP:aimAtPlayerClassic(player)
	if not player or not player.Character then return end
	local camera = Workspace.CurrentCamera
	local currentCFrame = camera.CFrame
	local targetPosition = self:predictTargetPosition(player)
	if not targetPosition then return end
	if Config.WallCheck and not self:isPlayerVisible(player) then return end
	local direction = (targetPosition - currentCFrame.Position).Unit
	local smoothFactor = math.clamp(Config.Aimbot_Smoothness / 20, 0.01, 1)
	if Config.Aimbot_Smoothness >= 15 then
		camera.CFrame = CFrame.lookAt(currentCFrame.Position, currentCFrame.Position + direction)
	else
		local smoothDir = currentCFrame.LookVector:Lerp(direction, smoothFactor)
		camera.CFrame = CFrame.lookAt(currentCFrame.Position, currentCFrame.Position + smoothDir)
	end
end

-- ============================================
-- 自瞄 - 获取最近可见目标
-- ============================================
function ESP:getNearestVisiblePlayer()
	local localChar = self.localPlayer and self.localPlayer.Character
	if not localChar then return nil end
	local localHead = localChar:FindFirstChild("Head")
	if not localHead then return nil end
	local nearestPlayer = nil
	local nearestDistance = Config.Aimbot_Range
	local camera = Workspace.CurrentCamera
	for _, player in ipairs(Players:GetPlayers()) do
		if player == self.localPlayer then
			-- skip self
		elseif player.Character then
			if self:isEnemy(player) then
				local char = player.Character
				local humanoid = char:FindFirstChild("Humanoid")
				local head = char:FindFirstChild(Config.Aimbot_TargetPart)
				if humanoid and humanoid.Health > 0 and head then
					local distance = (head.Position - localHead.Position).Magnitude
					if distance <= nearestDistance then
						if self:isPlayerVisible(player) then
							if Config.Aimbot_FOV >= 360 then
								nearestPlayer = player
								nearestDistance = distance
							else
								local screenPoint, onScreen = camera:WorldToViewportPoint(head.Position)
								if onScreen then
									local viewportSize = camera.ViewportSize
									local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
									local screenPos = Vector2.new(screenPoint.X, screenPoint.Y)
									local distToCenter = (screenPos - center).Magnitude
									local fovRadius = (viewportSize.Y / 2) * math.tan(math.rad(Config.Aimbot_FOV / 2))
									if distToCenter <= fovRadius then
										nearestPlayer = player
										nearestDistance = distance
									end
								end
							end
						end
					end
				end
			end
		end
	end
	return nearestPlayer
end

-- ============================================
-- 自瞄心跳（人类化状态机 + spray transfer）
-- ============================================
function ESP:startAimbot()
	if self.aimbotConnection then return end
	self.aimbotConnection = RunService.Heartbeat:Connect(function()
		if Config.Aimbot_Enabled then
			local nearest = self:getNearestVisiblePlayer()

			if nearest then
				-- 目标切换检测：新目标 → 重置状态机
				if self.aimbotTarget ~= nearest then
					local prevTarget = self.aimbotTarget

					-- spray transfer 检测：上一个目标刚死亡且新目标在相近方向
					local isSprayTransfer = false
					if prevTarget and self.aimbotPhase == "idle" and self.aimbotPrefired then
						-- 上一帧触发了目标死亡，这一帧自动切到新目标
						isSprayTransfer = true
					end

					self.aimbotTarget = nearest
					if Config.Aimbot_Humanize then
						if isSprayTransfer then
							-- donk 招牌 spray transfer：目标死亡 → 立即 flick 到下一个
							-- 跳过反应延迟，直接进入 flicking 阶段
							self.aimbotPhase = "flicking"
							self.aimbotFlickStart = tick()
							self.aimbotWillOvershoot = math.random() < (Config.Aimbot_OvershootChance * 0.5)
							self.aimbotJitterPhase = math.random() * math.pi * 2
							self.aimbotJitterSpeed = 8 + math.random() * 3
							self.aimbotPrefired = false
							self.aimbotFlickDirection = nil
							if self.aimbotWillOvershoot then
								local camera = Workspace.CurrentCamera
								local right = camera.CFrame.LookVector:Cross(Vector3.new(0, 1, 0)).Unit
								if right.Magnitude < 0.01 then right = Vector3.new(1, 0, 0) end
								self.aimbotOvershootDir = (math.random() < 0.5) and right or -right
							end
						else
							-- 正常目标切换：进入反应延迟
							self.aimbotPhase = "reacting"
							local reactionMs = Config.Aimbot_ReactionMin
								+ math.random() * (Config.Aimbot_ReactionMax - Config.Aimbot_ReactionMin)
							self.aimbotReactUntil = tick() + reactionMs / 1000
						end
					else
						self.aimbotPhase = "idle"
					end
				end

				-- 执行瞄准
				if Config.Aimbot_Humanize then
					self:aimAtPlayer(nearest)
				else
					self:aimAtPlayerClassic(nearest)
				end
			else
				-- 无目标 → 重置
				self.aimbotTarget = nil
				self.aimbotPhase = "idle"
				self.aimbotPrefired = false
			end
		end
	end)
end

function ESP:stopAimbot()
	if self.aimbotConnection then
		self.aimbotConnection:Disconnect()
		self.aimbotConnection = nil
	end
	self.aimbotTarget = nil
	self.aimbotPhase = "idle"
end

-- ============================================
-- ============  UI 面板 ============
-- ============================================
print("[CS] 开始创建 UI...")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = nil

-- 等待 PlayerGui
local ok, pg = pcall(function()
	return LocalPlayer:WaitForChild("PlayerGui")
end)
if ok and pg then
	PlayerGui = pg
	print("[CS] PlayerGui 已获取")
else
	print("[CS] 错误: 无法获取 PlayerGui: " .. tostring(pg))
	return
end

local TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PANEL_W, PANEL_H = 210, 500
local BALL_SIZE = 40
local TOGGLE_W, TOGGLE_H = 36, 20

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CSDefenseUI"
ScreenGui.Parent = PlayerGui
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
print("[CS] ScreenGui 已创建")

-- 主面板
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
MainFrame.Position = UDim2.new(0.5, -PANEL_W / 2, 0.5, -PANEL_H / 2)
MainFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
MainFrame.BackgroundTransparency = 0.08
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = MainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(60, 60, 80)
stroke.Thickness = 1
stroke.Transparency = 0.5
stroke.Parent = MainFrame

-- 标题栏
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.Position = UDim2.new(0, 0, 0, 0)
TitleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
TitleBar.BackgroundTransparency = 0.3
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local tc = Instance.new("UICorner")
tc.CornerRadius = UDim.new(0, 10)
tc.Parent = TitleBar

local tb = Instance.new("Frame")
tb.Size = UDim2.new(1, 0, 0, 10)
tb.Position = UDim2.new(0, 0, 0, 20)
tb.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
tb.BackgroundTransparency = 0.3
tb.BorderSizePixel = 0
tb.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -12, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Roblox CS 防御"
Title.TextColor3 = Color3.fromRGB(220, 220, 240)
Title.TextSize = 13
Title.Font = Enum.Font.GothamSemibold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

-- 折叠按钮
local CollapseBtn = Instance.new("TextButton")
CollapseBtn.Size = UDim2.new(0, 22, 0, 22)
CollapseBtn.Position = UDim2.new(1, -26, 0, 4)
CollapseBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
CollapseBtn.Text = "_"
CollapseBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
CollapseBtn.TextSize = 14
CollapseBtn.Font = Enum.Font.GothamBold
CollapseBtn.BorderSizePixel = 0
CollapseBtn.AutoButtonColor = false
CollapseBtn.Parent = TitleBar

local ccb = Instance.new("UICorner")
ccb.CornerRadius = UDim.new(0, 5)
ccb.Parent = CollapseBtn

-- 滚动区域
local ScrollingFrame = Instance.new("ScrollingFrame")
ScrollingFrame.Size = UDim2.new(1, -16, 1, -40)
ScrollingFrame.Position = UDim2.new(0, 8, 0, 36)
ScrollingFrame.BackgroundTransparency = 1
ScrollingFrame.BorderSizePixel = 0
ScrollingFrame.ScrollBarThickness = 4
ScrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 500)
ScrollingFrame.Parent = MainFrame

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, 0, 0, 500)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = ScrollingFrame

-- 折叠球
local BallBtn = Instance.new("TextButton")
BallBtn.Size = UDim2.new(0, BALL_SIZE, 0, BALL_SIZE)
BallBtn.Position = UDim2.new(0.5, -BALL_SIZE / 2, 0.5, -BALL_SIZE / 2)
BallBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
BallBtn.BackgroundTransparency = 0.08
BallBtn.BorderSizePixel = 0
BallBtn.Text = "C"
BallBtn.TextSize = 18
BallBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
BallBtn.Font = Enum.Font.GothamBold
BallBtn.AutoButtonColor = false
BallBtn.Active = true
BallBtn.Draggable = true
BallBtn.Visible = false
BallBtn.ZIndex = 10
BallBtn.Parent = ScreenGui

local bcorner = Instance.new("UICorner")
bcorner.CornerRadius = UDim.new(1, 0)
bcorner.Parent = BallBtn

local bstroke = Instance.new("UIStroke")
bstroke.Color = Color3.fromRGB(60, 60, 80)
bstroke.Thickness = 1
bstroke.Transparency = 0.5
bstroke.Parent = BallBtn

print("[CS] 主面板和球已创建")

-- ============================================
-- UI 组件工厂
-- ============================================
local function MakeSectionLabel(y, text)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 18)
	lbl.Position = UDim2.new(0, 0, 0, y)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(140, 140, 160)
	lbl.TextSize = 11
	lbl.Font = Enum.Font.GothamBold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = ContentFrame
	return lbl
end

local function MakeToggle(y, label, defaultValue, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 28)
	row.Position = UDim2.new(0, 0, 0, y)
	row.BackgroundTransparency = 1
	row.Parent = ContentFrame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0, 90, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = label
	nameLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	nameLabel.TextSize = 12
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, TOGGLE_W, 0, TOGGLE_H)
	btn.Position = UDim2.new(1, -TOGGLE_W, 0, 4)
	btn.Text = ""
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Parent = row

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(1, 0)
	btnCorner.Parent = btn

	local state = defaultValue
	local function updateVisual()
		btn.BackgroundColor3 = state and Color3.fromRGB(0, 180, 100) or Color3.fromRGB(80, 80, 95)
	end
	updateVisual()

	btn.MouseButton1Click:Connect(function()
		state = not state
		updateVisual()
		callback(state)
	end)

	return { set = function(v) state = v; updateVisual() end, get = function() return state end }
end

local function MakeSlider(y, label, minVal, maxVal, defaultVal, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 36)
	row.Position = UDim2.new(0, 0, 0, y)
	row.BackgroundTransparency = 1
	row.Parent = ContentFrame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0, 80, 0, 16)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = label
	nameLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	nameLabel.TextSize = 12
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(0, 36, 0, 16)
	valLabel.Position = UDim2.new(1, -36, 0, 0)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = tostring(defaultVal)
	valLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	valLabel.TextSize = 11
	valLabel.Font = Enum.Font.GothamMedium
	valLabel.TextXAlignment = Enum.TextXAlignment.Right
	valLabel.Parent = row

	local track = Instance.new("TextButton")
	track.Size = UDim2.new(1, 0, 0, 6)
	track.Position = UDim2.new(0, 0, 0, 22)
	track.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	track.BorderSizePixel = 0
	track.AutoButtonColor = false
	track.Text = ""
	track.Parent = row

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local knob = Instance.new("TextButton")
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.Position = UDim2.new((defaultVal - minVal) / (maxVal - minVal), -7, 0, -4)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.AutoButtonColor = false
	knob.Text = ""
	knob.Parent = track

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local dragging = false
	local currentValue = defaultVal

	local function updateFromPos(x)
		local relX = math.clamp(x - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
		local frac = relX / track.AbsoluteSize.X
		local val = minVal + frac * (maxVal - minVal)
		val = math.floor(val + 0.5)
		val = math.clamp(val, minVal, maxVal)
		if val ~= currentValue then
			currentValue = val
			fill.Size = UDim2.new(frac, 0, 1, 0)
			knob.Position = UDim2.new(frac, -7, 0, -4)
			valLabel.Text = tostring(val)
			callback(val)
		end
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromPos(Vector2.new(input.Position.X, 0).X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	return {
		set = function(v)
			currentValue = v
			local frac = (v - minVal) / (maxVal - minVal)
			fill.Size = UDim2.new(frac, 0, 1, 0)
			knob.Position = UDim2.new(frac, -7, 0, -4)
			valLabel.Text = tostring(v)
		end
	}
end

local function MakeDropdown(y, label, options, defaultVal, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 28)
	row.Position = UDim2.new(0, 0, 0, y)
	row.BackgroundTransparency = 1
	row.Parent = ContentFrame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0, 80, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = label
	nameLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	nameLabel.TextSize = 12
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 100, 0, 22)
	btn.Position = UDim2.new(1, -100, 0, 3)
	btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
	btn.Text = defaultVal
	btn.TextColor3 = Color3.fromRGB(200, 200, 220)
	btn.TextSize = 11
	btn.Font = Enum.Font.GothamMedium
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Parent = row

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 5)
	btnCorner.Parent = btn

	local currentIndex = 1
	for i, opt in ipairs(options) do
		if opt == defaultVal then currentIndex = i end
	end

	btn.MouseButton1Click:Connect(function()
		currentIndex = currentIndex % #options + 1
		btn.Text = options[currentIndex]
		callback(options[currentIndex])
	end)

	return {
		set = function(v)
			for i, opt in ipairs(options) do
				if opt == v then
					currentIndex = i
					btn.Text = v
					break
				end
			end
		end
	}
end

-- ============================================
-- 构建 UI 控件
-- ============================================
local curY = 4

MakeSectionLabel(curY, "── ESP 开关 ──")
curY = curY + 20

local uiESPTotal = MakeToggle(curY, "总开关", Config.ESP_Enabled, function(v)
	Config.ESP_Enabled = v
	uiESPRays.set(v)
	uiESPHealth.set(v)
	uiESPHead.set(v)
	uiESPFov.set(v)
end)
curY = curY + 30

local uiESPRays = MakeToggle(curY, "射线", Config.ShowRays, function(v) Config.ShowRays = v end)
curY = curY + 30

local uiESPHealth = MakeToggle(curY, "血量条", Config.ShowHealthBars, function(v) Config.ShowHealthBars = v end)
curY = curY + 30

local uiESPHead = MakeToggle(curY, "头部圆圈", Config.ShowHeadCircles, function(v) Config.ShowHeadCircles = v end)
curY = curY + 30

local uiESPFov = MakeToggle(curY, "FOV 圈", Config.ShowFovCircle, function(v) Config.ShowFovCircle = v end)
curY = curY + 34

MakeSectionLabel(curY, "── 自瞄 ──")
curY = curY + 20

local uiAimbot = MakeToggle(curY, "自瞄开关", Config.Aimbot_Enabled, function(v)
	Config.Aimbot_Enabled = v
	if v then ESP:startAimbot() else ESP:stopAimbot() end
end)
curY = curY + 30

local uiAimbotHumanize = MakeToggle(curY, "人类化", Config.Aimbot_Humanize, function(v)
	Config.Aimbot_Humanize = v
	-- 切换时重置状态机
	if Config.Aimbot_Enabled then
		ESP.aimbotPhase = "idle"
		ESP.aimbotTarget = nil
	end
end)
curY = curY + 30

local uiAimbotSmooth = MakeSlider(curY, "平滑度", 1, 20, Config.Aimbot_Smoothness, function(v) Config.Aimbot_Smoothness = v end)
curY = curY + 40

local uiAimbotFOV = MakeSlider(curY, "FOV", 30, 360, Config.Aimbot_FOV, function(v) Config.Aimbot_FOV = v end)
curY = curY + 40

local uiAimbotPart = MakeDropdown(curY, "瞄准部位", {"Head", "HumanoidRootPart", "Torso"}, Config.Aimbot_TargetPart, function(v) Config.Aimbot_TargetPart = v end)
curY = curY + 34

MakeSectionLabel(curY, "── 检测 ──")
curY = curY + 20

local uiWallCheck = MakeToggle(curY, "墙体检测", Config.WallCheck, function(v) Config.WallCheck = v end)
curY = curY + 30

local uiTeamCheck = MakeToggle(curY, "队伍检测", Config.TeamCheck, function(v) Config.TeamCheck = v end)
curY = curY + 30

MakeSectionLabel(curY, "── 击杀追踪 ──")
curY = curY + 20

local uiKillTracer = MakeToggle(curY, "子弹轨道", Config.KillTracer_Enabled, function(v) Config.KillTracer_Enabled = v end)
curY = curY + 24
local uiKillSound = MakeToggle(curY, "击杀音效", Config.KillSound_Enabled, function(v) Config.KillSound_Enabled = v end)
curY = curY + 30

local uiKillHighlight = MakeToggle(curY, "尸体高亮", Config.KillHighlight_Enabled, function(v) Config.KillHighlight_Enabled = v end)
curY = curY + 30

ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, curY + 20)

print("[CS] UI 控件已创建")

-- ============================================
-- 折叠/展开
-- ============================================
local isCollapsed = false
local tweening = false

local function GetRelativePos(absolutePos)
	local base = ScreenGui.AbsolutePosition
	return UDim2.new(0, absolutePos.X - base.X, 0, absolutePos.Y - base.Y)
end

local function CollapsePanel()
	if isCollapsed or tweening then return end
	tweening = true
	isCollapsed = true
	BallBtn.Position = GetRelativePos(MainFrame.AbsolutePosition)
	BallBtn.Size = UDim2.new(0, 0, 0, 0)
	BallBtn.Visible = true
	local shrink = TweenService:Create(MainFrame, TWEEN_INFO, { Size = UDim2.new(0, 0, 0, 0) })
	local grow = TweenService:Create(BallBtn, TWEEN_INFO, { Size = UDim2.new(0, BALL_SIZE, 0, BALL_SIZE) })
	shrink:Play()
	grow:Play()
	shrink.Completed:Wait()
	MainFrame.Visible = false
	MainFrame.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
	tweening = false
end

local function ExpandPanel()
	if not isCollapsed or tweening then return end
	tweening = true
	isCollapsed = false
	MainFrame.Position = GetRelativePos(BallBtn.AbsolutePosition)
	MainFrame.Size = UDim2.new(0, 0, 0, 0)
	MainFrame.Visible = true
	local shrink = TweenService:Create(BallBtn, TWEEN_INFO, { Size = UDim2.new(0, 0, 0, 0) })
	local grow = TweenService:Create(MainFrame, TWEEN_INFO, { Size = UDim2.new(0, PANEL_W, 0, PANEL_H) })
	shrink:Play()
	grow:Play()
	shrink.Completed:Wait()
	BallBtn.Visible = false
	BallBtn.Size = UDim2.new(0, BALL_SIZE, 0, BALL_SIZE)
	tweening = false
end

CollapseBtn.MouseButton1Click:Connect(CollapsePanel)
BallBtn.MouseButton1Click:Connect(ExpandPanel)

MainFrame:GetPropertyChangedSignal("Position"):Connect(function()
	if not isCollapsed then BallBtn.Position = GetRelativePos(MainFrame.AbsolutePosition) end
end)
BallBtn:GetPropertyChangedSignal("Position"):Connect(function()
	if isCollapsed then MainFrame.Position = GetRelativePos(BallBtn.AbsolutePosition) end
end)

print("[CS] 折叠/展开逻辑已绑定")

-- ============================================
-- 透视 - 射线
-- ============================================
function ESP:createRay(player)
	if not player then return end
	if self.rays[player] then return end
	local ray = Drawing.new("Line")
	ray.Color = Config.RayColor
	ray.Thickness = 1
	ray.Visible = Config.ShowRays
	self.rays[player] = { player = player, drawing = ray }
end

function ESP:removeRay(player)
	if self.rays[player] and self.rays[player].drawing then
		self.rays[player].drawing:Remove()
		self.rays[player] = nil
	end
end

function ESP:updateRays()
	if not self.localPlayer or not Config.ShowRays then
		for _, data in pairs(self.rays) do
			if data.drawing then data.drawing.Visible = false end
		end
		return
	end
	local camera = Workspace.CurrentCamera
	local viewportSize = camera.ViewportSize
	local centerScreen = Vector2.new(viewportSize.X / 2, viewportSize.Y)
	for player, data in pairs(self.rays) do
		local ray = data.drawing
		if self:isEnemy(player) then
			local char = player.Character
			if char then
				local head = char:FindFirstChild("Head")
				if head then
					local headPos = head.Position + Vector3.new(0, 1, 0)
					local screenPos, onScreen = camera:WorldToViewportPoint(headPos)
					if onScreen then
						ray.From = centerScreen
						ray.To = Vector2.new(screenPos.X, screenPos.Y)
						ray.Visible = true
					else
						ray.Visible = false
					end
				else
					ray.Visible = false
				end
			else
				ray.Visible = false
			end
		else
			ray.Visible = false
		end
	end
end

-- ============================================
-- 透视 - 血量条
-- ============================================
function ESP:createHealthBar(player)
	if not player then return end
	if self.healthBars[player] then return end
	self.healthBars[player] = {
		bg = Drawing.new("Square"),
		fill = Drawing.new("Square"),
		outline = Drawing.new("Square"),
		player = player,
	}
	local bar = self.healthBars[player]
	bar.bg.Filled = true
	bar.bg.Color = Color3.fromRGB(40, 40, 40)
	bar.bg.Thickness = 1
	bar.bg.Visible = Config.ShowHealthBars
	bar.fill.Filled = true
	bar.fill.Thickness = 1
	bar.fill.Visible = Config.ShowHealthBars
	bar.outline.Filled = false
	bar.outline.Color = Color3.fromRGB(0, 0, 0)
	bar.outline.Thickness = 1
	bar.outline.Visible = Config.ShowHealthBars
end

function ESP:removeHealthBar(player)
	if self.healthBars[player] then
		local bar = self.healthBars[player]
		bar.bg:Remove()
		bar.fill:Remove()
		bar.outline:Remove()
		self.healthBars[player] = nil
	end
end

function ESP:updateHealthBars()
	if not self.localPlayer or not Config.ShowHealthBars then
		for _, bar in pairs(self.healthBars) do
			bar.bg.Visible = false
			bar.fill.Visible = false
			bar.outline.Visible = false
		end
		return
	end
	local camera = Workspace.CurrentCamera
	for player, bar in pairs(self.healthBars) do
		if self:isEnemy(player) then
			local char = player.Character
			if char then
				local humanoid = char:FindFirstChild("Humanoid")
				local head = char:FindFirstChild("Head")
				if humanoid and head and humanoid.Health > 0 then
					local healthPercent = humanoid.Health / humanoid.MaxHealth
					local headPos = head.Position + Vector3.new(0, 1.5, 0)
					local screenPos, onScreen = camera:WorldToViewportPoint(headPos)
					if onScreen then
						local barWidth = 40
						local barHeight = 4
						local x = screenPos.X - barWidth / 2
						local y = screenPos.Y - 25
						bar.bg.Position = Vector2.new(x, y)
						bar.bg.Size = Vector2.new(barWidth, barHeight)
						bar.bg.Visible = true
						bar.fill.Position = Vector2.new(x, y)
						bar.fill.Size = Vector2.new(barWidth * healthPercent, barHeight)
						if healthPercent > 0.6 then
							bar.fill.Color = Config.HealthBarColor_High
						elseif healthPercent > 0.3 then
							bar.fill.Color = Config.HealthBarColor_Mid
						else
							bar.fill.Color = Config.HealthBarColor_Low
						end
						bar.fill.Visible = true
						bar.outline.Position = Vector2.new(x, y)
						bar.outline.Size = Vector2.new(barWidth, barHeight)
						bar.outline.Visible = true
					else
						bar.bg.Visible = false
						bar.fill.Visible = false
						bar.outline.Visible = false
					end
				else
					bar.bg.Visible = false
					bar.fill.Visible = false
					bar.outline.Visible = false
				end
			else
				bar.bg.Visible = false
				bar.fill.Visible = false
				bar.outline.Visible = false
			end
		else
			bar.bg.Visible = false
			bar.fill.Visible = false
			bar.outline.Visible = false
		end
	end
end

-- ============================================
-- 透视 - 头部圆圈
-- ============================================
function ESP:createHeadCircle(player)
	if not player then return end
	if self.headCircles[player] then return end
	local circle = Drawing.new("Circle")
	circle.Color = Config.HeadCircleColor
	circle.Thickness = 2
	circle.Filled = false
	circle.NumSides = 32
	circle.Visible = Config.ShowHeadCircles
	self.headCircles[player] = { drawing = circle, player = player }
end

function ESP:removeHeadCircle(player)
	if self.headCircles[player] then
		self.headCircles[player].drawing:Remove()
		self.headCircles[player] = nil
	end
end

function ESP:updateHeadCircles()
	if not self.localPlayer or not Config.ShowHeadCircles then
		for _, data in pairs(self.headCircles) do
			data.drawing.Visible = false
		end
		return
	end
	local camera = Workspace.CurrentCamera
	local localChar = self.localPlayer.Character
	if not localChar then return end
	local localHead = localChar:FindFirstChild("Head")
	if not localHead then return end
	for player, data in pairs(self.headCircles) do
		local circle = data.drawing
		if self:isEnemy(player) then
			local char = player.Character
			if char then
				local head = char:FindFirstChild("Head")
				local humanoid = char:FindFirstChild("Humanoid")
				if head and humanoid and humanoid.Health > 0 then
					local headPos = head.Position
					local screenPos, onScreen = camera:WorldToViewportPoint(headPos)
					local distance = (headPos - localHead.Position).Magnitude
					if onScreen then
						local baseRadius = 15
						local radius = math.max(5, baseRadius * (50 / distance))
						circle.Position = Vector2.new(screenPos.X, screenPos.Y)
						circle.Radius = radius
						circle.Color = Config.HeadCircleColor
						circle.Visible = true
					else
						circle.Visible = false
					end
				else
					circle.Visible = false
				end
			else
				circle.Visible = false
			end
		else
			circle.Visible = false
		end
	end
end

-- ============================================
-- 透视 - FOV 圈
-- ============================================
function ESP:createFovCircle()
	if self.fovCircle then return end
	self.fovCircle = Drawing.new("Circle")
	self.fovCircle.Color = Config.FovCircleColor
	self.fovCircle.Thickness = 1
	self.fovCircle.Filled = false
	self.fovCircle.NumSides = 64
	self.fovCircle.Visible = false
end

function ESP:updateFovCircle()
	if not self.fovCircle then return end
	if not Config.ShowFovCircle or Config.Aimbot_FOV >= 360 then
		self.fovCircle.Visible = false
		return
	end
	local camera = Workspace.CurrentCamera
	local viewportSize = camera.ViewportSize
	local fovRadius = (viewportSize.Y / 2) * math.tan(math.rad(Config.Aimbot_FOV / 2))
	self.fovCircle.Position = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
	self.fovCircle.Radius = fovRadius
	self.fovCircle.Color = Config.FovCircleColor
	self.fovCircle.Visible = true
end

-- ============================================
-- 击杀追踪 — 最后一颗子弹轨道
-- 依赖 RE_KF 事件的淘汰广播，精确知道谁杀了谁
-- RE_KF 参数: { Victim, Killer, RealNames, Crit, Weapon }
-- ============================================
-- 获取受害者死亡位置：优先用快照"生前"位置，其次实时角色，最后缓存模板
function ESP:getDeathPosition(victimPlayer)
	if not victimPlayer then return nil end
	local victimChar = victimPlayer.Character
	local template = self.playerModels[victimPlayer]
	local parts = template and template.parts or nil
	-- 优先用快照记录的"生前"位置（角色可能已倒地/部件透明/被传送）
	if parts then
		for _, name in ipairs({"Head", "HumanoidRootPart", "Torso"}) do
			if parts[name] then
				return parts[name].Position
			end
		end
	end
	if victimChar then
		local part = (victimChar:FindFirstChild("Head")
			or victimChar:FindFirstChild("HumanoidRootPart")
			or victimChar:FindFirstChild("Torso")
			or victimChar:FindFirstChildWhichIsA("BasePart"))
		if part and typeof(part) == "Instance" and part.Parent then
			return part.Position
		end
	end
	if template and template.pivot then
		return template.pivot.Position
	end
	return nil
end

-- 创建"蓝色半透明发光雾状"高亮（替代旧的克隆模型+Highlight 方案）
function ESP:createFogHighlight(pos)
	local model = Instance.new("Model")
	model.Name = "KillFog"

	local color = Config.KillHighlight_Color

	-- 多层蓝色发光雾团：Neon 半透明球体堆叠成雾状
	local blobs = {
		{ size = Vector3.new(6, 4, 6),    off = Vector3.new(0, 1, 0) },
		{ size = Vector3.new(4.5, 3, 4.5), off = Vector3.new(1.6, 0.6, -0.6) },
		{ size = Vector3.new(3.8, 2.6, 3.8), off = Vector3.new(-1.4, 2, 0.9) },
		{ size = Vector3.new(5, 3.2, 5),  off = Vector3.new(0.9, -0.4, 1.6) },
		{ size = Vector3.new(3.2, 2.2, 3.2), off = Vector3.new(-1, 3, -1.2) },
	}
	for _, b in ipairs(blobs) do
		local part = Instance.new("Part")
		part.Name = "FogBlob"
		part.Shape = Enum.PartType.Ball
		part.Size = b.size
		part.Material = Enum.Material.Neon
		part.Color = color
		part.Transparency = 0.62
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.CFrame = CFrame.new(pos + b.off)
		part.Parent = model
	end

	-- 雾粒子：蓝色半透明，缓慢上升消散
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "FogEmitter"
	emitterPart.Size = Vector3.new(1, 1, 1)
	emitterPart.Transparency = 1
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CastShadow = false
	emitterPart.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
	emitterPart.Parent = model

	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3),
		NumberSequenceKeypoint.new(1, 7),
	})
	pe.Lifetime = NumberRange.new(2.5, 4)
	pe.Speed = NumberRange.new(0.4, 1.2)
	pe.Rate = 25
	pe.Rotation = NumberRange.new(0, 360)
	pe.LightEmission = 0.8
	pe.Parent = emitterPart

	-- 柔和蓝光点光源
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 2
	light.Range = 16
	light.Parent = emitterPart

	model.Parent = Workspace
	return model
end

function ESP:initKillTracer()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local reKF = ReplicatedStorage:FindFirstChild("RE_KF")
	if not reKF then
		print("[CS] 击杀追踪: RE_KF 未找到，功能不可用")
		return
	end

	reKF.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then return end

		local killer = data.Killer
		local victim = data.Victim
		local crit = data.Crit
		local weapon = data.Weapon

		-- 检查击杀者是否是我（Killer 可能是 "XBOXMCPEFTK" 或 "XBOXMCPEFTK + 队友"）
		local lpName = Players.LocalPlayer.Name
		if not killer or not killer:find(lpName, 1, true) then
			if Config.DebugLog then
				print(string.format("[CS] 击杀手非我方, 忽略. killer=%s lp=%s", tostring(killer), lpName))
			end
			return
		end
		if not victim then return end

		-- 找到受害者玩家（可能已离开服务器，用遍历代替 FindFirstChild）
		-- Victim 可能是 Name / DisplayName / 复合字符串（如 "X + CRAZ_4M"），做宽松匹配
		local victimPlayer = self:findPlayerByVictim(victim)
		if Config.DebugLog then
			print(string.format("[CS] 击杀事件: victim=%s (%s), 找到受害者=%s, 高亮开关=%s",
				tostring(victim), type(victim), victimPlayer and "是" or "否",
				Config.KillHighlight_Enabled and "开" or "关"))
		end
		if not victimPlayer then
			local clean = type(victim) == "string" and victim:gsub("[<>/\\%c%s]", "") or ""
			local names = {}
			for _, p in ipairs(Players:GetPlayers()) do
				table.insert(names, string.format("%s(%s)", p.Name, p.DisplayName))
			end
			print("[CS] 匹配失败诊断: 清洗后=[" .. clean .. "] 玩家列表: " .. table.concat(names, ", "))
		end

		-- 击杀音效
		if Config.KillSound_Enabled then
			local sound = Instance.new("Sound")
			sound.SoundId = Config.KillSound_ID
			sound.Volume = 3
			sound.Parent = game:GetService("SoundService")
			sound:Play()
			sound.Ended:Connect(function()
				sound:Destroy()
			end)
		end

		-- 击杀后高亮：蓝色半透明发光雾状（替代旧的克隆模型+Highlight 方案）
		if Config.KillHighlight_Enabled and victimPlayer then
			local fogPos = self:getDeathPosition(victimPlayer)
			if fogPos then
				local fog = self:createFogHighlight(fogPos)
				table.insert(self.killHighlights, {
					fog = fog,
					player = victimPlayer,
					spawnTime = tick(),
					expireTime = tick() + Config.KillHighlight_Duration,
				})
				if Config.DebugLog then
					print(string.format("[CS] 尸体高亮: %s 雾状高亮已生成 @%s",
						victim, tostring(fogPos)))
				end
			else
				if Config.DebugLog then
					print("[CS] 尸体高亮: 无法获取死亡位置, 跳过")
				end
			end
		end

		-- 击杀追踪（最后一颗子弹轨道）
		if not Config.KillTracer_Enabled then return end

		local now = tick()

		-- 获取我的头部位置
		local myHead = nil
		local lpChar = Players.LocalPlayer.Character
		if lpChar then
			myHead = lpChar:FindFirstChild("Head")
		end
		local fromPos = myHead and myHead.Position
			or (Workspace.CurrentCamera.CFrame.Position + Workspace.CurrentCamera.CFrame.LookVector * 0.5)

		-- 获取受害者死亡位置（复用 getDeathPosition，优先快照"生前"位置）
		local toPos = self:getDeathPosition(victimPlayer)
		if not toPos then
			-- 角色已清理：从镜头方向做射线检测，打到墙/地面就停，否则默认 200 单位
			local cam = Workspace.CurrentCamera
			local rayOrigin = cam.CFrame.Position
			local rayDirection = cam.CFrame.LookVector * 500
			local rayParams = RaycastParams.new()
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			rayParams.FilterDescendantsInstances = (Players.LocalPlayer.Character and {Players.LocalPlayer.Character}) or {}
			rayParams.IgnoreWater = true
			local rayResult = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
			if rayResult then
				toPos = rayResult.Position
			else
				toPos = rayOrigin + cam.CFrame.LookVector * 200
			end
		end

		-- 蓝色发光半透明射线（爆头略粗，颜色略亮）
		local mainColor = crit and Config.KillTracer_GlowColor or Config.KillTracer_Color
		local glowColor = crit and Color3.fromRGB(180, 240, 255) or Config.KillTracer_GlowColor
		local thickness = crit and Config.KillTracer_Thickness * 1.2 or Config.KillTracer_Thickness
		local baseTrans = 0.25   -- 主射线基础透明度（半透明）
		local glowTrans = 0.55   -- 辉光层基础透明度

		-- 3D 子弹轨迹：两个隐形 Part 各挂一个 Attachment，Beam 挂 Workspace
		local part0 = Instance.new("Part")
		part0.Name = "KillTracer"
		part0.Size = Vector3.new(0.1, 0.1, 0.1)
		part0.Anchored = true
		part0.CanCollide = false
		part0.CanQuery = false
		part0.CastShadow = false
		part0.Transparency = 1
		part0.CFrame = CFrame.new(fromPos)
		part0.Parent = Workspace

		local part1 = Instance.new("Part")
		part1.Name = "KillTracer"
		part1.Size = Vector3.new(0.1, 0.1, 0.1)
		part1.Anchored = true
		part1.CanCollide = false
		part1.CanQuery = false
		part1.CastShadow = false
		part1.Transparency = 1
		part1.CFrame = CFrame.new(toPos)
		part1.Parent = Workspace

		local attach0 = Instance.new("Attachment")
		attach0.Parent = part0

		local attach1 = Instance.new("Attachment")
		attach1.Parent = part1

		-- 主射线：蓝色半透明强发光
		local beam = Instance.new("Beam")
		beam.Attachment0 = attach0
		beam.Attachment1 = attach1
		beam.Color = ColorSequence.new(mainColor)
		beam.Width0 = thickness * 0.2
		beam.Width1 = thickness * 0.2
		beam.Transparency = NumberSequence.new(baseTrans)
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Parent = Workspace

		-- 辉光层：更宽更透的浅蓝色光晕
		local glowBeam = Instance.new("Beam")
		glowBeam.Attachment0 = attach0
		glowBeam.Attachment1 = attach1
		glowBeam.Color = ColorSequence.new(glowColor)
		glowBeam.Width0 = thickness * 0.5
		glowBeam.Width1 = thickness * 0.5
		glowBeam.Transparency = NumberSequence.new(glowTrans)
		glowBeam.FaceCamera = true
		glowBeam.LightEmission = 1
		glowBeam.LightInfluence = 0
		glowBeam.Parent = Workspace

		table.insert(self.killTracers, {
			part0 = part0,
			part1 = part1,
			beam = beam,
			glowBeam = glowBeam,
			attach0 = attach0,
			attach1 = attach1,
			from = fromPos,
			to = toPos,
			spawnTime = now,
			isCrit = crit,
			baseTrans = baseTrans,
			glowTrans = glowTrans,
		})

		print(string.format("[CS] 击杀追踪: %s %s %s (武器: %s)",
			killer, crit and "爆头" or "击杀", victim, weapon or "未知"))
	end)

	print("[CS] 击杀追踪: RE_KF 监听已绑定")
end

-- 清理到期的击杀雾状高亮（到期后渐隐并自动移除）
function ESP:updateKillHighlights()
	local now = tick()
	local total = Config.KillHighlight_Duration
	local toRemove = {}
	for i, entry in ipairs(self.killHighlights) do
		local age = now - entry.spawnTime
		local expired = age >= total
		local gone = not entry.fog or not entry.fog.Parent
		if expired or gone then
			if entry.fog then
				entry.fog:Destroy()
			end
			table.insert(toRemove, i)
		elseif Config.KillHighlight_FadeOut and entry.fog then
			-- 渐隐：最后 1 秒内透明度渐增，雾状缓缓消散
			local remain = total - age
			if remain < 1 then
				local fade = 1 - remain -- 0 → 1
				for _, part in ipairs(entry.fog:GetDescendants()) do
					if part:IsA("BasePart") and part.Name == "FogBlob" then
						part.Transparency = 0.62 + fade * 0.38
					end
				end
			end
		end
	end
	for i = #toRemove, 1, -1 do
		table.remove(self.killHighlights, toRemove[i])
	end
end

-- 逐帧快照所有敌人姿态，用于击杀后还原"击杀前"身体姿态
function ESP:updateCharacterSnapshots()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= self.localPlayer then
			local char = player.Character
			if char then
				-- 判断是否"明确死亡"：只有存在 Humanoid 且血量<=0 才算死亡姿态
			-- 若游戏无标准 Humanoid（自定义血量），则无法判断，一律按存活处理并填充快照
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			local confirmedDead = humanoid and humanoid.Health <= 0

			-- 按玩家缓存模板：角色重建时更新模板模型
			local entry = self.playerModels[player]
			if not entry or entry.source ~= char then
				-- 备份旧模板姿态（重生瞬间可能短暂无角色）
				local oldParts, oldPivot = {}, nil
				if entry then
					oldParts, oldPivot = entry.parts, entry.pivot
					-- 销毁旧的隐藏模板，避免泄漏
					if entry.model then
						pcall(function() entry.model:Destroy() end)
					end
				end
				local model = char:Clone()
				model.Name = "PlayerModelTemplate"
				-- 挂到 nil（隐藏，不放入 Workspace），避免在场景中出现可见的定格模型
				-- 仅当角色被销毁时用于重建克隆
				model.Parent = nil
				-- 冻结模板
				for _, part in ipairs(model:GetDescendants()) do
					if part:IsA("JointInstance") then part:Destroy() end
				end
				for _, part in ipairs(model:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = true
						part.CanCollide = false
						part.CanQuery = false
						part.CanTouch = false
					end
				end
				for _, scr in ipairs(model:GetDescendants()) do
					if scr:IsA("LuaSourceContainer") then scr:Destroy() end
				end
				-- 若角色已在淘汰存放区（极低高度），则用旧模板的生前位置，避免记录地面位置
				local hroot0 = char:FindFirstChild("HumanoidRootPart")
				local initPivot = oldPivot
				if not initPivot and hroot0 and hroot0.Position.Y >= -50 then
					initPivot = char:GetPivot()
				end
				entry = { model = model, parts = oldParts or {}, pivot = initPivot or CFrame.new(0, 0, 0), source = char, alive = not confirmedDead, teleported = false }
				self.playerModels[player] = entry
			end

			-- 更新姿态快照：未明确死亡时填充（存在 Humanoid 且血量>0，或没有 Humanoid）
			if not confirmedDead then
				-- 淘汰存放区高度检测：游戏淘汰玩家时会把角色传送到"地面存放实体"，
				-- 该实体固定位于极低高度（地面 y≈-451，正常战斗 y>0）。
				-- 一旦角色 y 低于阈值，判定已传送到存放区，停止更新快照，保留"生前"位置。
				local hroot = char:FindFirstChild("HumanoidRootPart")
				local atStorage = hroot and hroot.Position.Y < -50 or false

				if not atStorage then
					local parts = entry.parts
					for _, part in ipairs(char:GetDescendants()) do
						if part:IsA("BasePart") then
							parts[part.Name] = part.CFrame
						end
					end
					entry.pivot = char:GetPivot()
					entry.alive = true
					entry.teleported = false
				else
					entry.teleported = true
				end
			end
			end
		end
	end
	-- 清理已退出玩家的模板
	for player in pairs(self.playerModels) do
		if not player or not player.Parent then
			if self.playerModels[player].model then
				self.playerModels[player].model:Destroy()
			end
			self.playerModels[player] = nil
		end
	end
end

-- 更新所有活跃轨迹（3D Beam 淡出动画）
function ESP:updateKillTracers()
	local now = tick()
	local toRemove = {}

	for i, tracer in ipairs(self.killTracers) do
		local elapsed = now - tracer.spawnTime
		local duration = Config.KillTracer_Duration

		if elapsed >= duration then
			-- 轨迹过期 → 销毁两个 Part + Beam
			tracer.part0:Destroy()
			tracer.part1:Destroy()
			tracer.beam:Destroy()
			tracer.glowBeam:Destroy()
			toRemove[#toRemove + 1] = i
		else
			local progress = elapsed / duration
			-- 爆头轨迹：全满亮 0.35 后开始淡出；普通：0.3
			local holdRatio = tracer.isCrit and 0.35 or 0.3
			local alpha
			if progress < holdRatio then
				alpha = 1
			else
				alpha = 1 - ((progress - holdRatio) / (1 - holdRatio))
				alpha = alpha * alpha
			end

			local glowAlpha = alpha * 0.5
			local baseWidth = tracer.isCrit and Config.KillTracer_Thickness * 1.2 or Config.KillTracer_Thickness
			-- 保留初始半透明基础（baseTrans/glowTrans），随 alpha 收缩到完全消失
			local bt = tracer.baseTrans or 0.25
			local gt = tracer.glowTrans or 0.55

			-- 主 Beam：透明度在基础半透明之上随 alpha 淡出，宽度同步收缩
			tracer.beam.Transparency = NumberSequence.new(bt + (1 - bt) * (1 - alpha))
			tracer.beam.Width0 = baseWidth * 0.2 * alpha
			tracer.beam.Width1 = baseWidth * 0.2 * alpha

			-- 辉光 Beam
			tracer.glowBeam.Transparency = NumberSequence.new(gt + (1 - gt) * (1 - glowAlpha))
			tracer.glowBeam.Width0 = baseWidth * 0.5 * alpha
			tracer.glowBeam.Width1 = baseWidth * 0.5 * alpha
		end
	end

	for j = #toRemove, 1, -1 do
		table.remove(self.killTracers, toRemove[j])
	end
end

-- ============================================
-- 初始化 ESP 渲染
-- ============================================
print("[CS] 初始化渲染...")

function ESP:init()
	self.localPlayer = Players.LocalPlayer

	-- 初始化队伍检测（基于 Attribute["Team"]）
	self:initTeamCheck()

	-- 初始化击杀追踪（基于 RE_KF 事件）
	self:initKillTracer()

	self:createFovCircle()

	-- 为当前在线玩家创建渲染
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= self.localPlayer then
			self:createRay(player)
			self:createHealthBar(player)
			self:createHeadCircle(player)
		end
	end

	-- 监听新玩家加入
	Players.PlayerAdded:Connect(function(player)
		if player ~= self.localPlayer then
			self:createRay(player)
			self:createHealthBar(player)
			self:createHeadCircle(player)
		end
	end)

	-- 监听玩家离开
	Players.PlayerRemoving:Connect(function(player)
		self:removeRay(player)
		self:removeHealthBar(player)
		self:removeHeadCircle(player)
		if self.aimbotTarget == player then self.aimbotTarget = nil end
		self.raycastCache[player.UserId] = nil
	end)

	-- 渲染心跳
	RunService.Heartbeat:Connect(function()
		self:updateRays()
		self:updateHealthBars()
		self:updateHeadCircles()
		self:updateFovCircle()
		self:updateKillTracers()
		self:updateKillHighlights()
		self:updateCharacterSnapshots()
		local now = tick()
		if now - self.lastCleanup > Config.CacheCleanupInterval then
			self:cleanRaycastCache()
			self.lastCleanup = now
		end
	end)

	-- 默认开启自瞄（Config.Aimbot_Enabled = true）
	self:startAimbot()

	-- 本地玩家离开时清理
	Players.PlayerRemoving:Connect(function(player)
		if player == self.localPlayer then
			self:stopAimbot()
			for _, data in pairs(self.rays) do
				if data.drawing then data.drawing:Remove() end
			end
			for _, bar in pairs(self.healthBars) do
				bar.bg:Remove()
				bar.fill:Remove()
				bar.outline:Remove()
			end
			for _, data in pairs(self.headCircles) do
				data.drawing:Remove()
			end
			if self.fovCircle then self.fovCircle:Remove() end
		end
	end)
end

-- ============================================
-- 启动
-- ============================================
ESP:init()

getgenv().ESP_Config = Config
getgenv().ESP = ESP

print("[CS] UI 面板已加载")
print("[CS] 点击 _ 折叠面板，点击 球 展开")
print("[CS] ===== 加载完成 =====")