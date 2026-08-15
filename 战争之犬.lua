-- ============================================
-- ESP + Aimbot + UI — 异步加载版
-- UI 立即创建，GC 扫描在后台进行，不阻塞渲染
-- ============================================

print("[ESP] ===== 开始加载 =====")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

print("[ESP] 服务初始化完毕")

-- ============================================
-- 配置表
-- ============================================
local Config = {
	ESP_Enabled = true,
	ShowRays = true,
	ShowHealthBars = true,
	ShowHeadCircles = true,
	ShowFovCircle = true,

	RayColor = Color3.fromRGB(0, 255, 0),
	HealthBarColor_High = Color3.fromRGB(0, 255, 0),
	HealthBarColor_Mid = Color3.fromRGB(255, 255, 0),
	HealthBarColor_Low = Color3.fromRGB(255, 0, 0),
	HeadCircleColor = Color3.fromRGB(255, 255, 0),
	FovCircleColor = Color3.fromRGB(255, 255, 255),

	Aimbot_Enabled = false,
	Aimbot_Range = 500,
	Aimbot_FOV = 360,
	Aimbot_Smoothness = 5,
	Aimbot_Prediction = 0.5,
	Aimbot_TargetPart = "Head",

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
	raycastCache = {},
	lastCleanup = 0,
	localPlayer = nil,
}

-- ============================================
-- 后台 GC 扫描 — 不阻塞 UI
-- ============================================
local SameTeam = nil  -- 初始为 nil，扫描完成后赋值

local function startGCScan()
	print("[ESP] 后台 GC 扫描已启动...")
	local ok, err = pcall(function()
		local gc = getgc()
		if not gc then
			print("[ESP] GC 扫描: getgc() 返回 nil")
			return
		end
		local total = #gc
		print("[ESP] GC 扫描: 共 " .. total .. " 个对象")
		local count = 0
		for _, obj in ipairs(gc) do
			if type(obj) == "function" then
				local ok2, constants = pcall(function() return getconstants(obj) end)
				if ok2 and constants then
					local found = false
					for _, c in ipairs(constants) do
						if c == "playerTeams" then
							found = true
							break
						end
					end
					if found then
						local ok3, upvals = pcall(function() return getupvalues(obj) end)
						if ok3 and upvals and upvals[1] and type(upvals[1]) == "table" then
							SameTeam = upvals[1].SameTeam
							if SameTeam then
								print("[ESP] GC 扫描: 队伍函数已找到!")
								return
							end
						end
					end
				end
			end
			count = count + 1
			if count % 30000 == 0 then
				task.wait()  -- 让出执行权，不阻塞渲染
				print("[ESP] GC 扫描: " .. count .. "/" .. total)
			end
		end
		print("[ESP] GC 扫描: 完成，未找到队伍函数")
	end)
	if not ok then
		print("[ESP] GC 扫描失败: " .. tostring(err))
	end
end

-- 启动后台扫描
task.spawn(startGCScan)

-- ============================================
-- 队伍检测
-- ============================================
function ESP:isEnemy(player)
	if not Config.TeamCheck then return true end
	if not SameTeam then return true end
	if player == self.localPlayer then return false end
	local ok, result = pcall(function() return SameTeam(self.localPlayer, player) end)
	if ok then return not result end
	return true
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
-- 自瞄 - 移动预测
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
	return currentPos + (velocity * timeToHit * Config.Aimbot_Prediction)
end

-- ============================================
-- 自瞄 - 瞄准玩家
-- ============================================
function ESP:aimAtPlayer(player)
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
-- 自瞄心跳
-- ============================================
function ESP:startAimbot()
	if self.aimbotConnection then return end
	self.aimbotConnection = RunService.Heartbeat:Connect(function()
		if Config.Aimbot_Enabled then
			local nearest = self:getNearestVisiblePlayer()
			if nearest then
				self.aimbotTarget = nearest
				self:aimAtPlayer(nearest)
			else
				self.aimbotTarget = nil
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
end

-- ============================================
-- ============  UI 面板 ============
-- ============================================
print("[ESP] 开始创建 UI...")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = nil

-- 等待 PlayerGui
local ok, pg = pcall(function()
	return LocalPlayer:WaitForChild("PlayerGui")
end)
if ok and pg then
	PlayerGui = pg
	print("[ESP] PlayerGui 已获取")
else
	print("[ESP] 错误: 无法获取 PlayerGui: " .. tostring(pg))
	return
end

local TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PANEL_W, PANEL_H = 210, 400
local BALL_SIZE = 40
local TOGGLE_W, TOGGLE_H = 36, 20

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ESPUI"
ScreenGui.Parent = PlayerGui
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
print("[ESP] ScreenGui 已创建")

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
Title.Text = "ESP · Aimbot"
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
BallBtn.Text = "E"
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

print("[ESP] 主面板和球已创建")

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

ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, curY + 20)

print("[ESP] UI 控件已创建")

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

print("[ESP] 折叠/展开逻辑已绑定")

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
-- 初始化 ESP 渲染
-- ============================================
print("[ESP] 初始化渲染...")

function ESP:init()
	self.localPlayer = Players.LocalPlayer
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
		local now = tick()
		if now - self.lastCleanup > Config.CacheCleanupInterval then
			self:cleanRaycastCache()
			self.lastCleanup = now
		end
	end)

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

print("[ESP] UI 面板已加载")
print("[ESP] 点击 _ 折叠面板，点击 球 展开")
print("[ESP] GC 扫描正在后台进行...")
print("[ESP] ===== 加载完成 =====")