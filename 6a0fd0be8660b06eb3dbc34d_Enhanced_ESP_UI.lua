local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- ============================================
-- 增强版 ESP 系统 - 完整功能实现
-- ============================================
local PlayerESP = {
    -- 核心组件
    labels = {},
    rays = {},
    boxes = {},
    healthBars = {},
    headCircles = {},
    fovCircle = nil,
    localPlayer = nil,
    screenGui = nil,
    mainFrame = nil,
    collapsedFrame = nil,
    statusBar = nil,
    
    -- 基础 ESP 开关
    enabled = true,
    showRays = true,
    showBoxes = true,
    showHealthBars = true,
    showHeadCircles = true,
    showFovCircle = true,
    
    -- UI 状态
    isExpanded = true,
    isDragging = false,
    dragStartPos = nil,
    frameStartPos = nil,
    currentTab = "ESP",
    
    -- 坐头功能
    sitTarget = nil,
    isSitting = false,
    sitConnection = nil,
    originalCFrame = nil,
    sitHeightOffset = 3, -- 坐头高度偏移
    
    -- 颜色配置
    colors = {
        label = Color3.new(1, 0, 0),
        ray = Color3.fromRGB(0, 255, 0),
        box = Color3.fromRGB(120, 0, 180),
        healthBar = Color3.fromRGB(0, 255, 0),
        headCircle = Color3.fromRGB(255, 255, 0),
        fovCircle = Color3.fromRGB(255, 255, 255),
        teamBased = false
    },
    
    -- 玩家列表
    playerListFrame = nil,
    playerButtons = {},
    
    -- 自瞄系统
    aimbotEnabled = false,
    aimbotKey = "q",
    aimbotRange = 1000,
    aimbotFov = 360,
    aimbotStrength = 50,
    aimbotSmoothness = 20,
    aimbotPrediction = 0.5,
    wallCheck = true,
    teamCheck = true,
    aimbotTarget = nil,
    aimbotTargetPart = "Head",
    aimbotConnection = nil,
    aimbotKeyBeganConnection = nil,
    aimbotKeyEndedConnection = nil,
    
    -- 自瞄强制瞄地面
    aimbotGroundAimEnabled = false,   -- 瞄地面功能开关
    aimbotGroundAimTime = 0.1,      -- 瞄准目标时间（默认1秒）
    aimbotGroundDuration = 0.004,     -- 瞄地面持续时间（0.5秒）
    aimbotGroundAimTimer = 0,       -- 计时器
    aimbotIsGroundAiming = false,   -- 是否正在瞄地面
    
    -- 扳机系统
    triggerbotEnabled = false,
    triggerbotKey = "e",
    triggerbotAlwaysOn = true,
    triggerbotFiring = false,
    triggerbotHeadOnly = false,
    triggerbotDelay = 0,
    triggerbotConnection = nil,
    triggerbotBeganConn = nil,
    triggerbotEndedConn = nil,
    triggerKeyHeld = false,
    lastTriggerTime = 0,
    triggerbotPrediction = 0.1,  -- 命中预测强度（0-1）
    
    -- 飞行系统
    flyEnabled = false,
    flyKey = "f",
    flySpeed = 50,
    flySlowSpeed = 10,
    flyConnection = nil,
    flyBodyVelocity = nil,
    flyBodyGyro = nil,
    flyJoystickInputChangedConn = nil,
    flyJoystickInputEndedConn = nil,
    
    -- 手机端飞行虚拟摇杆
    flyJoystickActive = false,
    flyJoystickDir = Vector3.new(0, 0, 0),
    flyJoystickGui = nil,
    
    -- 强制第三人称
    forceThirdPerson = false,
    cameraModeChangedConn = nil,
    
    -- 性能优化
    raycastCache = {},
    cacheExpiry = 0.1,
    lastCleanup = 0,
    
    -- 输入连接
    inputChangedConnection = nil,
}

-- ============================================
-- 动画辅助函数
-- ============================================
function PlayerESP:tweenButton(button, targetColor, duration)
    duration = duration or 0.2
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(button, tweenInfo, {BackgroundColor3 = targetColor})
    tween:Play()
end

function PlayerESP:buttonClickEffect(button)
    -- 点击缩放效果 - 更现代的弹性动画
    local originalSize = button.Size
    local shrinkInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local expandInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    -- 先缩小
    local shrinkTween = TweenService:Create(button, shrinkInfo, {
        Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset - 6, originalSize.Y.Scale, originalSize.Y.Offset - 6)
    })
    shrinkTween:Play()
    
    -- 然后弹性放大恢复
    shrinkTween.Completed:Connect(function()
        local expandTween = TweenService:Create(button, expandInfo, {Size = originalSize})
        expandTween:Play()
    end)
end

function PlayerESP:tweenFrame(frame, targetSize, targetPosition, duration)
    duration = duration or 0.3
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local props = {}
    if targetSize then props.Size = targetSize end
    if targetPosition then props.Position = targetPosition end
    local tween = TweenService:Create(frame, tweenInfo, props)
    tween:Play()
    return tween
end

-- ============================================
-- 状态栏更新
-- ============================================
function PlayerESP:updateStatus(text, color)
    if self.statusBar and self.statusBar.Text then
        self.statusBar.Text = text
        self.statusBar.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    end
end

function PlayerESP:updateTargetStatus()
    local targetText = "无目标"
    local targetColor = Color3.fromRGB(150, 150, 150)
    
    if self.aimbotTarget then
        targetText = "锁定: " .. self.aimbotTarget.Name
        targetColor = Color3.fromRGB(160, 0, 70)
    end
    
    if self.targetStatusLabel then
        self.targetStatusLabel.Text = targetText
        self.targetStatusLabel.TextColor3 = targetColor
    end
end

-- ============================================
-- 颜色选择器
-- ============================================
function PlayerESP:createColorPicker(parent, defaultColor, colorName, callback)
    local colorFrame = Instance.new("Frame")
    colorFrame.Name = colorName .. "ColorFrame"
    colorFrame.Size = UDim2.new(1, 0, 0, 44)
    colorFrame.BackgroundTransparency = 1
    colorFrame.ZIndex = 3
    colorFrame.Parent = parent

    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(0.6, 0, 1, 0)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Text = colorName .. "颜色"
    colorLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
    colorLabel.TextSize = 14
    colorLabel.Font = Enum.Font.Gotham
    colorLabel.TextXAlignment = Enum.TextXAlignment.Left
    colorLabel.ZIndex = 4
    colorLabel.Parent = colorFrame

    local colorButton = Instance.new("TextButton")
    colorButton.Size = UDim2.new(0, 44, 0, 44)
    colorButton.Position = UDim2.new(1, -44, 0, 0)
    colorButton.BackgroundColor3 = defaultColor
    colorButton.BorderSizePixel = 0
    colorButton.Text = ""
    colorButton.ZIndex = 4
    colorButton.Parent = colorFrame
    
    local colorBtnCorner = Instance.new("UICorner")
    colorBtnCorner.CornerRadius = UDim.new(0, 10)
    colorBtnCorner.Parent = colorButton

    colorButton.MouseButton1Click:Connect(function()
        self:showColorPicker(defaultColor, function(newColor)
            colorButton.BackgroundColor3 = newColor
            callback(newColor)
        end)
    end)

    return colorFrame
end

function PlayerESP:showColorPicker(defaultColor, callback)
    local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild("ColorPickerGui")
    if existing then existing:Destroy() end

    local colorPickerGui = Instance.new("ScreenGui")
    colorPickerGui.Name = "ColorPickerGui"
    colorPickerGui.Parent = playerGui

    local colorFrame = Instance.new("Frame")
    colorFrame.Size = UDim2.new(0, 280, 0, 340)
    colorFrame.Position = UDim2.new(0.5, -140, 0.5, -170)
    colorFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    colorFrame.BorderSizePixel = 0
    colorFrame.ZIndex = 10
    colorFrame.Parent = colorPickerGui
    
    local colorFrameCorner = Instance.new("UICorner")
    colorFrameCorner.CornerRadius = UDim.new(0, 16)
    colorFrameCorner.Parent = colorFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 56)
    titleLabel.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
    titleLabel.Text = "选择颜色"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 18
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.ZIndex = 11
    titleLabel.Parent = colorFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 16)
    titleCorner.Parent = titleLabel

    local colorGrid = {
        Color3.new(1, 0, 0), Color3.new(1, 0.5, 0), Color3.new(1, 1, 0),
        Color3.new(0.5, 1, 0), Color3.new(0, 1, 0), Color3.new(0, 1, 0.5),
        Color3.new(0, 1, 1), Color3.new(0, 0.5, 1), Color3.new(0, 0, 1),
        Color3.new(0.5, 0, 1), Color3.new(1, 0, 1), Color3.new(1, 0, 0.5),
        Color3.new(1, 0.5, 0.5), Color3.new(1, 0.75, 0.5), Color3.new(1, 1, 0.5),
        Color3.new(0.75, 1, 0.5), Color3.new(0.5, 1, 0.5), Color3.new(0.5, 1, 0.75),
        Color3.new(0.5, 1, 1), Color3.new(0.5, 0.75, 1), Color3.new(0.5, 0.5, 1),
        Color3.new(0.75, 0.5, 1), Color3.new(1, 0.5, 1), Color3.new(1, 0.5, 0.75),
        Color3.new(1, 1, 1), Color3.fromRGB(128, 128, 128), Color3.new(0, 0, 0),
    }
    
    for i, color in ipairs(colorGrid) do
        local row = math.floor((i - 1) / 3)
        local col = (i - 1) % 3
        local colorBtn = Instance.new("TextButton")
        colorBtn.Size = UDim2.new(0, 70, 0, 44)
        colorBtn.Position = UDim2.new(0, 20 + col * 80, 0, 68 + row * 48)
        colorBtn.BackgroundColor3 = color
        colorBtn.BorderSizePixel = 0
        colorBtn.Text = ""
        colorBtn.ZIndex = 11
        colorBtn.Parent = colorFrame
        
        local colorBtnCorner = Instance.new("UICorner")
        colorBtnCorner.CornerRadius = UDim.new(0, 10)
        colorBtnCorner.Parent = colorBtn
        
        colorBtn.MouseButton1Click:Connect(function()
            callback(color)
            colorPickerGui:Destroy()
        end)
    end

    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 240, 0, 44)
    closeButton.Position = UDim2.new(0.5, -120, 1, -64)
    closeButton.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Text = "关闭"
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 16
    closeButton.ZIndex = 11
    closeButton.Parent = colorFrame
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 12)
    closeBtnCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        colorPickerGui:Destroy()
    end)
end

-- ============================================
-- 参数输入框组件 (替代滑块)
-- ============================================
function PlayerESP:createParamInput(parent, name, default, min, max, callback, isInteger)
    local paramFrame = Instance.new("Frame")
    paramFrame.Size = UDim2.new(1, 0, 0, 48)
    paramFrame.BackgroundTransparency = 1
    paramFrame.ZIndex = 3
    paramFrame.Parent = parent

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
    nameLabel.TextSize = 14
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 4
    nameLabel.Parent = paramFrame

    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(0, 100, 0, 40)
    inputBox.Position = UDim2.new(1, -100, 0, 4)
    inputBox.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
    inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    inputBox.PlaceholderText = tostring(default)
    inputBox.Text = tostring(default)
    inputBox.Font = Enum.Font.Gotham
    inputBox.TextSize = 14
    inputBox.TextXAlignment = Enum.TextXAlignment.Center
    inputBox.ZIndex = 4
    inputBox.Parent = paramFrame

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 10)
    inputCorner.Parent = inputBox

    inputBox.FocusLost:Connect(function()
        local val = tonumber(inputBox.Text)
        if val then
            val = math.clamp(val, min, max)
            if isInteger then
                val = math.floor(val)
                inputBox.Text = tostring(val)
            else
                inputBox.Text = string.format("%.2f", val)
            end
            callback(val)
        else
            inputBox.Text = tostring(default)
        end
    end)

    return paramFrame
end

-- ============================================
-- Tab 创建
-- ============================================
function PlayerESP:createTabButton(parent, name, tabId, position)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(0.25, 0, 0, 36)
    tabBtn.Position = position
    -- 现代风格：选中时紫色高亮，未选中时深色
    tabBtn.BackgroundColor3 = tabId == self.currentTab and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(32, 32, 44)
    tabBtn.Text = name
    tabBtn.TextColor3 = tabId == self.currentTab and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(148, 163, 184)
    tabBtn.TextSize = 14
    tabBtn.Font = Enum.Font.GothamBold
    tabBtn.BorderSizePixel = 0
    tabBtn.ZIndex = 3
    tabBtn.Parent = parent
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = tabBtn
    
    return tabBtn
end

function PlayerESP:switchTab(tabId)
    self.currentTab = tabId
    
    for _, btn in pairs(self.tabButtons) do
        local isSelected = btn.Name == tabId .. "Tab"
        btn.BackgroundColor3 = isSelected and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(32, 32, 44)
        btn.TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(148, 163, 184)
    end
    
    for id, frame in pairs(self.tabContents) do
        frame.Visible = (id == tabId)
    end
end

-- ============================================
-- 血量条 ESP
-- ============================================
function PlayerESP:createHealthBar(player)
    if not player or self.healthBars[player] then return end
    
    local healthBar = {
        bg = Drawing.new("Square"),
        fill = Drawing.new("Square"),
        outline = Drawing.new("Square"),
        player = player
    }
    
    healthBar.bg.Filled = true
    healthBar.bg.Color = Color3.fromRGB(40, 40, 40)
    healthBar.bg.Thickness = 1
    healthBar.bg.Visible = self.showHealthBars
    
    healthBar.fill.Filled = true
    healthBar.fill.Thickness = 1
    healthBar.fill.Visible = self.showHealthBars
    
    healthBar.outline.Filled = false
    healthBar.outline.Color = Color3.fromRGB(0, 0, 0)
    healthBar.outline.Thickness = 1
    healthBar.outline.Visible = self.showHealthBars
    
    self.healthBars[player] = healthBar
end

function PlayerESP:removeHealthBar(player)
    if self.healthBars[player] then
        local bar = self.healthBars[player]
        bar.bg:Remove()
        bar.fill:Remove()
        bar.outline:Remove()
        self.healthBars[player] = nil
    end
end

function PlayerESP:updateHealthBars()
    if not self.localPlayer or not self.showHealthBars then 
        for _, bar in pairs(self.healthBars) do
            bar.bg.Visible = false
            bar.fill.Visible = false
            bar.outline.Visible = false
        end
        return 
    end
    
    local camera = workspace.CurrentCamera
    
    for player, bar in pairs(self.healthBars) do
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            local head = character:FindFirstChild("Head")
            
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
                    
                    local color
                    if healthPercent > 0.6 then
                        color = Color3.fromRGB(0, 255, 0)
                    elseif healthPercent > 0.3 then
                        color = Color3.fromRGB(255, 255, 0)
                    else
                        color = Color3.fromRGB(255, 0, 0)
                    end
                    bar.fill.Color = color
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
    end
end

function PlayerESP:toggleHealthBars()
    self.showHealthBars = not self.showHealthBars
    for _, bar in pairs(self.healthBars) do
        bar.bg.Visible = self.showHealthBars
        bar.fill.Visible = self.showHealthBars
        bar.outline.Visible = self.showHealthBars
    end
    if self.healthBarToggleBtn then
        self.healthBarToggleBtn.Text = "血量条: " .. (self.showHealthBars and "开启" or "关闭")
        self:tweenButton(self.healthBarToggleBtn, self.showHealthBars and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(239, 68, 68))
    end
end

-- ============================================
-- 头部圆圈 ESP
-- ============================================
function PlayerESP:createHeadCircle(player)
    if not player or self.headCircles[player] then return end
    
    local circle = Drawing.new("Circle")
    circle.Color = self.colors.headCircle
    circle.Thickness = 2
    circle.Filled = false
    circle.NumSides = 32
    circle.Visible = self.showHeadCircles
    
    self.headCircles[player] = { drawing = circle, player = player }
end

function PlayerESP:removeHeadCircle(player)
    if self.headCircles[player] then
        self.headCircles[player].drawing:Remove()
        self.headCircles[player] = nil
    end
end

function PlayerESP:updateHeadCircles()
    if not self.localPlayer or not self.showHeadCircles then 
        for _, circleData in pairs(self.headCircles) do
            circleData.drawing.Visible = false
        end
        return 
    end
    
    local camera = workspace.CurrentCamera
    local localCharacter = self.localPlayer.Character
    if not localCharacter then return end
    local localHead = localCharacter:FindFirstChild("Head")
    if not localHead then return end
    
    for player, circleData in pairs(self.headCircles) do
        local circle = circleData.drawing
        local character = player.Character
        
        if character then
            local head = character:FindFirstChild("Head")
            local humanoid = character:FindFirstChild("Humanoid")
            
            if head and humanoid and humanoid.Health > 0 then
                local headPos = head.Position
                local screenPos, onScreen = camera:WorldToViewportPoint(headPos)
                local distance = (headPos - localHead.Position).Magnitude
                
                if onScreen then
                    local baseRadius = 15
                    local radius = math.max(5, baseRadius * (50 / distance))
                    
                    circle.Position = Vector2.new(screenPos.X, screenPos.Y)
                    circle.Radius = radius
                    circle.Color = self.colors.headCircle
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
    end
end

function PlayerESP:toggleHeadCircles()
    self.showHeadCircles = not self.showHeadCircles
    for _, circleData in pairs(self.headCircles) do
        circleData.drawing.Visible = self.showHeadCircles
    end
    if self.headCircleToggleBtn then
        self.headCircleToggleBtn.Text = "头部圆圈: " .. (self.showHeadCircles and "开启" or "关闭")
        self:tweenButton(self.headCircleToggleBtn, self.showHeadCircles and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(239, 68, 68))
    end
end

-- ============================================
-- FOV 圆圈绘制
-- ============================================
function PlayerESP:createFovCircle()
    if self.fovCircle then return end
    
    local circle = Drawing.new("Circle")
    circle.Color = self.colors.fovCircle
    circle.Thickness = 1
    circle.Filled = false
    circle.NumSides = 64
    circle.Visible = false
    
    self.fovCircle = circle
end

function PlayerESP:updateFovCircle()
    if not self.fovCircle then return end
    
    if not self.showFovCircle or self.aimbotFov >= 360 then
        self.fovCircle.Visible = false
        return
    end
    
    local camera = workspace.CurrentCamera
    local viewportSize = camera.ViewportSize
    local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    local fovRadius = (viewportSize.Y / 2) * math.tan(math.rad(self.aimbotFov / 2))
    
    self.fovCircle.Position = center
    self.fovCircle.Radius = fovRadius
    self.fovCircle.Color = self.colors.fovCircle
    self.fovCircle.Visible = true
end

function PlayerESP:toggleFovCircle()
    self.showFovCircle = not self.showFovCircle
    if self.fovCircle then
        self.fovCircle.Visible = self.showFovCircle and self.aimbotFov < 360
    end
    if self.fovCircleToggleBtn then
        self.fovCircleToggleBtn.Text = "FOV圈: " .. (self.showFovCircle and "开启" or "关闭")
        self:tweenButton(self.fovCircleToggleBtn, self.showFovCircle and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(239, 68, 68))
    end
end

-- ============================================
-- 自瞄移动预测
-- ============================================
function PlayerESP:predictTargetPosition(player, targetPart)
    if not player or not player.Character then return nil end
    
    local character = player.Character
    local part = character:FindFirstChild(targetPart or "Head")
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    
    if not part or not humanoid or not rootPart then return part and part.Position or nil end
    
    local velocity = rootPart.Velocity
    local predictionStrength = self.aimbotPrediction or 0.5
    
    local currentPos = part.Position
    local distance = (currentPos - workspace.CurrentCamera.CFrame.Position).Magnitude
    local timeToHit = distance / 1000
    
    local predictedPos = currentPos + (velocity * timeToHit * predictionStrength)
    
    return predictedPos
end

function PlayerESP:aimAtPlayer(player)
    if not player or not player.Character then return end
    
    local camera = workspace.CurrentCamera
    local currentCFrame = camera.CFrame
    
    -- 更新瞄地面计时器（仅在功能开启时生效）
    if self.aimbotGroundAimEnabled then
        -- 首次调用时初始化计时器
        if self.aimbotGroundAimTimer == 0 then
            self.aimbotGroundAimTimer = tick()
        end
        if self.aimbotIsGroundAiming then
            -- 正在瞄地面，检查是否结束
            if (tick() - self.aimbotGroundAimTimer) >= self.aimbotGroundDuration then
                -- 瞄地面时间结束，恢复正常瞄准
                self.aimbotIsGroundAiming = false
                self.aimbotGroundAimTimer = tick()  -- 重新开始计时瞄准目标
            end
        else
            -- 正在瞄准目标，检查是否需要切换到瞄地面
            if (tick() - self.aimbotGroundAimTimer) >= self.aimbotGroundAimTime then
                -- 瞄准目标时间达到，切换到瞄地面
                self.aimbotIsGroundAiming = true
                self.aimbotGroundAimTimer = tick()
            end
        end
    end
    
    local targetPosition
    if self.aimbotGroundAimEnabled and self.aimbotIsGroundAiming then
        -- 瞄地面：获取自身脚下位置
        local localCharacter = self.localPlayer.Character
        if localCharacter then
            local localRoot = localCharacter:FindFirstChild("HumanoidRootPart")
            if localRoot then
                -- 计算自身脚下位置（Y坐标减去一定高度）
                targetPosition = localRoot.Position - Vector3.new(0, localRoot.Size.Y / 2 + 2, 0)
            else
                targetPosition = self:predictTargetPosition(player, self.aimbotTargetPart)
            end
        else
            targetPosition = self:predictTargetPosition(player, self.aimbotTargetPart)
        end
    else
        -- 正常瞄准目标
        targetPosition = self:predictTargetPosition(player, self.aimbotTargetPart)
    end
    
    if not targetPosition then return end
    
    local direction = (targetPosition - currentCFrame.Position).Unit
    
    local smoothFactor = math.clamp(self.aimbotSmoothness / 20, 0.01, 1)
    local currentLookVector = currentCFrame.LookVector
    local smoothDirection = currentLookVector:Lerp(direction, smoothFactor)
    
    if self.wallCheck and not self:isPlayerVisible(player) then
        return
    end
    
    if self.aimbotStrength >= 15 then
        camera.CFrame = CFrame.lookAt(currentCFrame.Position, currentCFrame.Position + direction)
    else
        camera.CFrame = CFrame.lookAt(currentCFrame.Position, currentCFrame.Position + smoothDirection)
    end
end

-- ============================================
-- 飞行功能 (支持手机端虚拟摇杆)
-- ============================================
function PlayerESP:toggleFly()
    self.flyEnabled = not self.flyEnabled
    
    if self.flyEnabled then
        self:startFly()
        if self.sitTarget then
            self:cancelLock()
        end
    else
        self:stopFly()
    end
    
    if self.flyToggleBtn then
        self.flyToggleBtn.Text = "飞行: " .. (self.flyEnabled and "开启" or "关闭")
        self:tweenButton(self.flyToggleBtn, self.flyEnabled and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(239, 68, 68))
    end
end

function PlayerESP:startFly()
    if self.flyConnection then return end
    
    local character = self.localPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end
    
    self.flyBodyVelocity = Instance.new("BodyVelocity")
    self.flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    self.flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    self.flyBodyVelocity.Parent = rootPart
    
    self.flyBodyGyro = Instance.new("BodyGyro")
    self.flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    self.flyBodyGyro.P = 10000
    self.flyBodyGyro.Parent = rootPart
    
    humanoid.PlatformStand = true
    
    -- 显示手机端虚拟摇杆
    self:showFlyJoystick()
    
    self.flyConnection = RunService.Heartbeat:Connect(function()
        if not self.flyEnabled or not self.localPlayer.Character then
            self:stopFly()
            return
        end
        
        local cam = workspace.CurrentCamera
        local moveDirection = Vector3.new(0, 0, 0)
        
        -- 键盘输入 (PC端)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDirection = moveDirection + cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDirection = moveDirection - cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDirection = moveDirection - cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDirection = moveDirection + cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDirection = moveDirection + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDirection = moveDirection - Vector3.new(0, 1, 0)
        end
        
        -- 虚拟摇杆输入 (手机端)
        if self.flyJoystickActive and self.flyJoystickDir.Magnitude > 0.1 then
            local joystickDir = self.flyJoystickDir
            local forward = cam.CFrame.LookVector * joystickDir.Y
            local right = cam.CFrame.RightVector * joystickDir.X
            moveDirection = moveDirection + forward + right
        end
        
        -- 上升/下降按钮
        if self.flyUpHeld then
            moveDirection = moveDirection + Vector3.new(0, 1, 0)
        end
        if self.flyDownHeld then
            moveDirection = moveDirection - Vector3.new(0, 1, 0)
        end
        
        local speed = self.flySpeed
        
        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit * speed
        end
        
        if self.flyBodyVelocity and self.flyBodyVelocity.Parent then
            self.flyBodyVelocity.Velocity = moveDirection
        end
        if self.flyBodyGyro and self.flyBodyGyro.Parent then
            self.flyBodyGyro.CFrame = cam.CFrame
        end
    end)
end

function PlayerESP:stopFly()
    self.flyEnabled = false
    
    if self.flyConnection then
        self.flyConnection:Disconnect()
        self.flyConnection = nil
    end
    
    if self.flyBodyVelocity then
        self.flyBodyVelocity:Destroy()
        self.flyBodyVelocity = nil
    end
    
    if self.flyBodyGyro then
        self.flyBodyGyro:Destroy()
        self.flyBodyGyro = nil
    end
    
    local character = self.localPlayer.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
        end
    end
    
    -- 隐藏虚拟摇杆
    self:hideFlyJoystick()
    
    if self.flyToggleBtn then
        self.flyToggleBtn.Text = "飞行: 关闭"
        self.flyToggleBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
    end
end

-- ============================================
-- 强制第三人称
-- ============================================
function PlayerESP:toggleThirdPerson()
    self.forceThirdPerson = not self.forceThirdPerson
    
    if self.forceThirdPerson then
        self:startForceThirdPerson()
    else
        self:stopForceThirdPerson()
    end
    
    if self.thirdPersonToggleBtn then
        self.thirdPersonToggleBtn.Text = "第三人称: " .. (self.forceThirdPerson and "开启" or "关闭")
        self:tweenButton(self.thirdPersonToggleBtn, self.forceThirdPerson and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(239, 68, 68))
    end
end

function PlayerESP:startForceThirdPerson()
    -- 立即切换到第三人称
    self.localPlayer.CameraMode = Enum.CameraMode.Classic
    self.localPlayer.CameraMaxZoomDistance = 12
    self.localPlayer.CameraMinZoomDistance = 0.5
    
    -- 监听相机模式变化，防止游戏强制切回第一人称
    self.cameraModeChangedConn = self.localPlayer:GetPropertyChangedSignal("CameraMode"):Connect(function()
        if self.forceThirdPerson and self.localPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then
            self.localPlayer.CameraMode = Enum.CameraMode.Classic
        end
    end)
end

function PlayerESP:stopForceThirdPerson()
    if self.cameraModeChangedConn then
        self.cameraModeChangedConn:Disconnect()
        self.cameraModeChangedConn = nil
    end
    -- 恢复默认相机设置
    self.localPlayer.CameraMode = Enum.CameraMode.Classic
    self.localPlayer.CameraMaxZoomDistance = 12
    self.localPlayer.CameraMinZoomDistance = 0.5
end

-- ============================================
-- 手机端飞行虚拟摇杆
-- ============================================
function PlayerESP:showFlyJoystick()
    self:hideFlyJoystick()
    
    local playerGui = self.localPlayer:WaitForChild("PlayerGui")
    
    self.flyJoystickGui = Instance.new("ScreenGui")
    self.flyJoystickGui.Name = "FlyJoystick"
    self.flyJoystickGui.ResetOnSpawn = false
    self.flyJoystickGui.Parent = playerGui
    
    -- 方向摇杆底座 (左侧)
    local joystickBg = Instance.new("Frame")
    joystickBg.Name = "JoystickBg"
    joystickBg.Size = UDim2.new(0, 120, 0, 120)
    joystickBg.Position = UDim2.new(0, 20, 1, -160)
    joystickBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    joystickBg.BackgroundTransparency = 0.7
    joystickBg.BorderSizePixel = 0
    joystickBg.Parent = self.flyJoystickGui
    
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = joystickBg
    
    -- 摇杆把手
    local joystickKnob = Instance.new("Frame")
    joystickKnob.Name = "JoystickKnob"
    joystickKnob.Size = UDim2.new(0, 50, 0, 50)
    joystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
    joystickKnob.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
    joystickKnob.BackgroundTransparency = 0.3
    joystickKnob.BorderSizePixel = 0
    joystickKnob.Parent = joystickBg
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = joystickKnob
    
    -- 上升按钮 (右侧上)
    local upBtn = Instance.new("TextButton")
    upBtn.Name = "UpBtn"
    upBtn.Size = UDim2.new(0, 60, 0, 60)
    upBtn.Position = UDim2.new(1, -80, 1, -180)
    upBtn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
    upBtn.BackgroundTransparency = 0.3
    upBtn.Text = "▲"
    upBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    upBtn.TextSize = 22
    upBtn.Font = Enum.Font.SourceSansBold
    upBtn.BorderSizePixel = 0
    upBtn.Parent = self.flyJoystickGui
    
    local upCorner = Instance.new("UICorner")
    upCorner.CornerRadius = UDim.new(1, 0)
    upCorner.Parent = upBtn
    
    -- 下降按钮 (右侧下)
    local downBtn = Instance.new("TextButton")
    downBtn.Name = "DownBtn"
    downBtn.Size = UDim2.new(0, 60, 0, 60)
    downBtn.Position = UDim2.new(1, -80, 1, -110)
    downBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
    downBtn.BackgroundTransparency = 0.3
    downBtn.Text = "▼"
    downBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    downBtn.TextSize = 22
    downBtn.Font = Enum.Font.SourceSansBold
    downBtn.BorderSizePixel = 0
    downBtn.Parent = self.flyJoystickGui
    
    local downCorner = Instance.new("UICorner")
    downCorner.CornerRadius = UDim.new(1, 0)
    downCorner.Parent = downBtn
    
    -- 摇杆触摸逻辑
    local joystickTouchId = nil
    local maxDist = 35
    
    local function updateKnobPosition(inputPos)
        local bgCenter = joystickBg.AbsolutePosition + joystickBg.AbsoluteSize / 2
        local delta = inputPos - bgCenter
        local dist = delta.Magnitude
        if dist > maxDist then
            delta = delta.Unit * maxDist
        end
        
        joystickKnob.Position = UDim2.new(0.5, delta.X - 25, 0.5, delta.Y - 25)
        
        -- 归一化方向 (-1 到 1)
        self.flyJoystickDir = Vector2.new(delta.X / maxDist, -delta.Y / maxDist)
    end
    
    local function resetKnob()
        joystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
        self.flyJoystickDir = Vector3.new(0, 0, 0)
        self.flyJoystickActive = false
        joystickTouchId = nil
    end
    
    -- 检查触摸是否在摇杆区域内
    local function isTouchInJoystick(pos)
        local bgPos = joystickBg.AbsolutePosition
        local bgSize = joystickBg.AbsoluteSize
        return pos.X >= bgPos.X and pos.X <= bgPos.X + bgSize.X
           and pos.Y >= bgPos.Y and pos.Y <= bgPos.Y + bgSize.Y
    end
    
    joystickBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            -- 使用 input 对象本身作为唯一标识
            joystickTouchId = input
            self.flyJoystickActive = true
            updateKnobPosition(Vector2.new(input.Position.X, input.Position.Y))
        end
    end)
    
    self.flyJoystickInputChangedConn = UserInputService.InputChanged:Connect(function(input)
        -- 检查是否是同一个触摸对象，且触摸位置在摇杆区域内
        if joystickTouchId and input == joystickTouchId then
            updateKnobPosition(Vector2.new(input.Position.X, input.Position.Y))
        end
    end)
    
    self.flyJoystickInputEndedConn = UserInputService.InputEnded:Connect(function(input)
        -- 检查是否是同一个触摸对象
        if joystickTouchId and input == joystickTouchId then
            resetKnob()
        end
    end)
    
    -- 上升/下降按钮逻辑
    self.flyUpHeld = false
    self.flyDownHeld = false
    
    upBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.flyUpHeld = true
        end
    end)
    upBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.flyUpHeld = false
        end
    end)
    
    downBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.flyDownHeld = true
        end
    end)
    downBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.flyDownHeld = false
        end
    end)
end

function PlayerESP:hideFlyJoystick()
    self.flyJoystickActive = false
    self.flyJoystickDir = Vector3.new(0, 0, 0)
    self.flyUpHeld = false
    self.flyDownHeld = false
    
    if self.flyJoystickInputChangedConn then
        self.flyJoystickInputChangedConn:Disconnect()
        self.flyJoystickInputChangedConn = nil
    end
    if self.flyJoystickInputEndedConn then
        self.flyJoystickInputEndedConn:Disconnect()
        self.flyJoystickInputEndedConn = nil
    end
    
    if self.flyJoystickGui then
        self.flyJoystickGui:Destroy()
        self.flyJoystickGui = nil
    end
end

-- ============================================
-- 扳机系统 (修复版 + 命中预测)
-- ============================================
function PlayerESP:updateTriggerbot()
    if not self.triggerbotEnabled then
        if self.triggerbotFiring then self:releaseFire() end
        return
    end
    
    local currentTime = tick()
    local shouldFire = false
    
    if self.triggerbotAlwaysOn or self.triggerKeyHeld then
        local target = self:getCrosshairTarget()
        if target then
            local isValidTarget = true
            
            if self.teamCheck and not self:isEnemy(target) then
                isValidTarget = false
            end
            
            if self.wallCheck and not self:isPlayerVisible(target) then
                isValidTarget = false
            end
            
            if self.triggerbotHeadOnly and isValidTarget then
                local character = target.Character
                if character then
                    local camera = workspace.CurrentCamera
                    local rayOrigin = camera.CFrame.Position
                    local rayDirection = camera.CFrame.LookVector * 1000
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                    if self.localPlayer.Character then
                        raycastParams.FilterDescendantsInstances = {self.localPlayer.Character}
                    end
                    
                    local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
                    if result then
                        local hitHead = result.Instance.Name == "Head" or 
                                       (result.Instance.Parent and result.Instance.Parent:FindFirstChild("Head") == result.Instance)
                        if not hitHead then
                            isValidTarget = false
                        end
                    end
                end
            end
            
            -- 命中预测：检查目标移动后是否仍在准星内
            if isValidTarget and self.triggerbotPrediction > 0 then
                isValidTarget = self:checkTriggerPrediction(target)
            end
            
            if isValidTarget then
                if currentTime - self.lastTriggerTime >= (self.triggerbotDelay / 1000) then
                    shouldFire = true
                    self.lastTriggerTime = currentTime
                end
            end
        end
    end
    
    if shouldFire and not self.triggerbotFiring then
        self:pressFire()
    elseif not shouldFire and self.triggerbotFiring then
        self:releaseFire()
    end
end

-- 命中预测检查：预测目标下一帧位置，判断是否仍在准星内
function PlayerESP:checkTriggerPrediction(target)
    local camera = workspace.CurrentCamera
    local character = target.Character
    if not character then return false end
    
    local targetPart = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not targetPart or not rootPart then return true end  -- 无法预测时默认通过
    
    local velocity = rootPart.Velocity
    if velocity.Magnitude < 0.1 then return true end  -- 静止目标无需预测
    
    -- 预测下一帧位置（假设 60fps，约 16ms）
    local predictionTime = 0.05 * self.triggerbotPrediction  -- 50ms * 预测强度
    local predictedPos = targetPart.Position + velocity * predictionTime
    
    -- 检查预测位置是否在准星内
    local screenPos, onScreen = camera:WorldToViewportPoint(predictedPos)
    if not onScreen then return false end
    
    local viewportSize = camera.ViewportSize
    local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    local screenPos2D = Vector2.new(screenPos.X, screenPos.Y)
    local distToCenter = (screenPos2D - center).Magnitude
    
    -- 使用较小的容差范围（准星中心 10 像素）
    return distToCenter <= 10
end

-- 修复：只使用鼠标事件，不使用触摸事件，避免劫持屏幕
function PlayerESP:pressFire()
    self.triggerbotFiring = true
    pcall(function()
        game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, true, game, 1)
    end)
end

-- 修复：确保释放事件正确发送
function PlayerESP:releaseFire()
    self.triggerbotFiring = false
    pcall(function()
        game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
end

-- ============================================
-- 射线检测缓存优化
-- ============================================
function PlayerESP:isPlayerVisible(player)
    if not self.wallCheck then return true end
    
    local cacheKey = player.UserId
    local cached = self.raycastCache[cacheKey]
    if cached and (tick() - cached.time) < self.cacheExpiry then
        return cached.visible
    end
    
    local localCharacter = self.localPlayer.Character
    if not localCharacter then return false end
    
    local targetCharacter = player.Character
    if not targetCharacter then return false end
    
    local localHead = localCharacter:FindFirstChild("Head")
    local targetHead = targetCharacter:FindFirstChild("Head")
    if not localHead or not targetHead then return false end
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {localCharacter, targetCharacter}
    raycastParams.IgnoreWater = true
    
    local direction = (targetHead.Position - localHead.Position)
    local raycastResult = Workspace:Raycast(localHead.Position, direction, raycastParams)
    
    local visible = false
    if not raycastResult then
        visible = true
    else
        local hitPart = raycastResult.Instance
        if hitPart and hitPart:IsDescendantOf(targetCharacter) then
            visible = true
        end
    end
    
    self.raycastCache[cacheKey] = {
        visible = visible,
        time = tick()
    }
    
    return visible
end

function PlayerESP:cleanRaycastCache()
    local currentTime = tick()
    for key, data in pairs(self.raycastCache) do
        if (currentTime - data.time) > self.cacheExpiry * 2 then
            self.raycastCache[key] = nil
        end
    end
end

-- ============================================
-- 原有功能保留
-- ============================================
function PlayerESP:isEnemy(player)
    if not self.teamCheck then return true end
    local localTeam = self.localPlayer.Team
    local targetTeam = player.Team
    if not localTeam or not targetTeam then return true end
    return localTeam ~= targetTeam
end

function PlayerESP:getNearestVisiblePlayer()
    local localCharacter = self.localPlayer.Character
    if not localCharacter then return nil end
    local localHead = localCharacter:FindFirstChild("Head")
    if not localHead then return nil end

    local nearestPlayer = nil
    local nearestDistance = self.aimbotRange
    local camera = workspace.CurrentCamera

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= self.localPlayer and player.Character then
            if not self:isEnemy(player) then continue end
            local character = player.Character
            local humanoid = character:FindFirstChild("Humanoid")
            local head = character:FindFirstChild(self.aimbotTargetPart)
            if humanoid and humanoid.Health > 0 and head then
                local distance = (head.Position - localHead.Position).Magnitude
                local isVisible = self:isPlayerVisible(player)
                if isVisible and distance <= nearestDistance then
                    if self.aimbotFov >= 360 then
                        nearestPlayer = player
                        nearestDistance = distance
                    else
                        local screenPoint, onScreen = camera:WorldToViewportPoint(head.Position)
                        if onScreen then
                            local viewportSize = camera.ViewportSize
                            local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
                            local screenPos = Vector2.new(screenPoint.X, screenPoint.Y)
                            local distanceToCenter = (screenPos - center).Magnitude
                            local fovRadius = (viewportSize.Y / 2) * math.tan(math.rad(self.aimbotFov / 2))
                            if distanceToCenter <= fovRadius then
                                nearestPlayer = player
                                nearestDistance = distance
                            end
                        end
                    end
                end
            end
        end
    end
    return nearestPlayer
end

function PlayerESP:getCrosshairTarget()
    local camera = workspace.CurrentCamera
    local rayOrigin = camera.CFrame.Position
    local rayDirection = camera.CFrame.LookVector * 1000
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    if self.localPlayer and self.localPlayer.Character then
        raycastParams.FilterDescendantsInstances = {self.localPlayer.Character}
    end
    raycastParams.IgnoreWater = true

    local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if result and result.Instance then
        local model = result.Instance:FindFirstAncestorWhichIsA("Model")
        if model then
            local hitPlayer = Players:GetPlayerFromCharacter(model)
            if hitPlayer and hitPlayer ~= self.localPlayer then
                return hitPlayer
            end
        end
    end
    return nil
end

function PlayerESP:startAimbotHeartbeat()
    if self.aimbotConnection then return end
    self.aimbotConnection = RunService.Heartbeat:Connect(function()
        if self.aimbotEnabled then
            local nearestPlayer = self:getNearestVisiblePlayer()
            if nearestPlayer then
                self.aimbotTarget = nearestPlayer
                self:aimAtPlayer(nearestPlayer)
            else
                self.aimbotTarget = nil
            end
            self:updateTargetStatus()
        end
    end)
end

function PlayerESP:stopAimbotHeartbeat()
    if self.aimbotConnection then
        self.aimbotConnection:Disconnect()
        self.aimbotConnection = nil
    end
    self.aimbotTarget = nil
    self:updateTargetStatus()
end

function PlayerESP:toggleAimbot()
    self.aimbotEnabled = not self.aimbotEnabled
    if self.aimbotEnabled then
        self:startAimbotHeartbeat()
        if self.aimbotToggleButton then
            self.aimbotToggleButton.Text = "自瞄: 开启"
            self:tweenButton(self.aimbotToggleButton, Color3.fromRGB(34, 197, 94))
        end
    else
        self:stopAimbotHeartbeat()
        if self.aimbotToggleButton then
            self.aimbotToggleButton.Text = "自瞄: 关闭"
            self:tweenButton(self.aimbotToggleButton, Color3.fromRGB(239, 68, 68))
        end
    end
end

function PlayerESP:setupAimbotKey()
    if self.aimbotKeyBeganConnection then self.aimbotKeyBeganConnection:Disconnect() end
    if self.aimbotKeyEndedConnection then self.aimbotKeyEndedConnection:Disconnect() end

    self.aimbotKeyBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode[self.aimbotKey:upper()] then
            if not self.aimbotEnabled then
                self.aimbotEnabled = true
                self:startAimbotHeartbeat()
                if self.aimbotToggleButton then
                    self.aimbotToggleButton.Text = "自瞄: 按键中"
                    self.aimbotToggleButton.BackgroundColor3 = Color3.fromRGB(245, 158, 11)
                end
            end
        end
    end)

    self.aimbotKeyEndedConnection = UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode[self.aimbotKey:upper()] then
            if self.aimbotEnabled then
                self.aimbotEnabled = false
                self:stopAimbotHeartbeat()
                if self.aimbotToggleButton then
                    self.aimbotToggleButton.Text = "自瞄: 关闭"
                    self.aimbotToggleButton.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
                end
            end
        end
    end)
end

function PlayerESP:setupTriggerbotKey()
    if self.triggerbotBeganConn then self.triggerbotBeganConn:Disconnect() end
    if self.triggerbotEndedConn then self.triggerbotEndedConn:Disconnect() end

    self.triggerbotBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode[self.triggerbotKey:upper()] then
            self.triggerKeyHeld = true
        end
    end)
    self.triggerbotEndedConn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode[self.triggerbotKey:upper()] then
            self.triggerKeyHeld = false
        end
    end)
end

function PlayerESP:toggleTriggerbot()
    self.triggerbotEnabled = not self.triggerbotEnabled
    if self.triggerbotEnabled then
        if not self.triggerbotConnection then
            self.triggerbotConnection = RunService.Heartbeat:Connect(function()
                self:updateTriggerbot()
            end)
        end
        if self.triggerbotToggleButton then
            self.triggerbotToggleButton.Text = "扳机: 开启"
            self:tweenButton(self.triggerbotToggleButton, Color3.fromRGB(34, 197, 94))
        end
        self:setupTriggerbotKey()
    else
        if self.triggerbotConnection then
            self.triggerbotConnection:Disconnect()
            self.triggerbotConnection = nil
        end
        self:releaseFire()
        if self.triggerbotToggleButton then
            self.triggerbotToggleButton.Text = "扳机: 关闭"
            self:tweenButton(self.triggerbotToggleButton, Color3.fromRGB(239, 68, 68))
        end
    end
end

function PlayerESP:lockToPlayer()
    if self.flyEnabled then
        self:updateStatus("飞行中无法锁定", Color3.fromRGB(255, 165, 0))
        return
    end
    
    local targetName = self.playerNameBox.Text:gsub("%s+", "")
    if targetName == "" then
        self.sitStatusLabel.Text = "状态: 请输入玩家名"
        self.sitStatusLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
        return
    end
    local targetPlayer = nil
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower():find(targetName:lower()) or player.DisplayName:lower():find(targetName:lower()) then
            targetPlayer = player
            break
        end
    end
    if not targetPlayer then
        self.sitStatusLabel.Text = "状态: 玩家不存在"
        self.sitStatusLabel.TextColor3 = Color3.fromRGB(160, 0, 70)
        return
    end
    if targetPlayer == self.localPlayer then
        self.sitStatusLabel.Text = "状态: 不能锁定自己"
        self.sitStatusLabel.TextColor3 = Color3.fromRGB(160, 0, 70)
        return
    end
    self:cancelLock()
    self.sitTarget = targetPlayer
    self.isSitting = true
    local character = self.localPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        self.originalCFrame = character.HumanoidRootPart.CFrame
    end
    self.sitConnection = RunService.Heartbeat:Connect(function()
        self:updateSitting()
    end)
    self.sitStatusLabel.Text = "状态: 锁定到 " .. targetPlayer.Name
    self.sitStatusLabel.TextColor3 = Color3.fromRGB(0, 160, 130)
    self:tweenButton(self.lockButton, Color3.fromRGB(0, 160, 130))
    self:updatePlayerList()
end

function PlayerESP:cancelLock()
    if self.sitConnection then
        self.sitConnection:Disconnect()
        self.sitConnection = nil
    end
    self.isSitting = false
    self.sitTarget = nil
    if self.originalCFrame then
        local character = self.localPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            character.HumanoidRootPart.CFrame = self.originalCFrame
        end
        self.originalCFrame = nil
    end
    self.sitStatusLabel.Text = "状态: 未锁定"
    self.sitStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    self:tweenButton(self.lockButton, Color3.fromRGB(100, 0, 180))
    self:updatePlayerList()
end

function PlayerESP:updateSitting()
    if not self.isSitting or not self.sitTarget then return end
    local localCharacter = self.localPlayer.Character
    local targetCharacter = self.sitTarget.Character
    if not localCharacter or not targetCharacter then return end
    local localRoot = localCharacter:FindFirstChild("HumanoidRootPart")
    local targetHead = targetCharacter:FindFirstChild("Head")
    if not localRoot or not targetHead then return end
    local headPosition = targetHead.Position
    local sitPosition = headPosition + Vector3.new(0, self.sitHeightOffset, 0)
    localRoot.CFrame = CFrame.new(sitPosition, targetHead.Position)
end

function PlayerESP:getPlayerColor(player, elementType)
    if self.colors.teamBased then
        if player.Team then return player.Team.TeamColor.Color
        else return self.colors.label end
    else
        if elementType == "label" then return self.colors.label
        elseif elementType == "ray" then return self.colors.ray
        elseif elementType == "box" then return self.colors.box
        else return self.colors.label end
    end
end

function PlayerESP:createLabel(player)
    if not player or self.labels[player] then return end
    local drawing = Drawing.new("Text")
    drawing.Text = player.Name
    drawing.Color = self:getPlayerColor(player, "label")
    drawing.Size = 14
    drawing.Center = true
    drawing.Outline = true
    drawing.OutlineColor = Color3.new(0, 0, 0)
    drawing.Visible = self.enabled
    self.labels[player] = { player = player, drawing = drawing }
end

function PlayerESP:createRay(player)
    if not player or self.rays[player] then return end
    local ray = Drawing.new("Line")
    ray.Color = self:getPlayerColor(player, "ray")
    ray.Thickness = 1
    ray.Visible = self.showRays
    self.rays[player] = { player = player, drawing = ray }
end

function PlayerESP:createBox(player)
    if not player or self.boxes[player] then return end
    local box = {
        top = Drawing.new("Line"),
        bottom = Drawing.new("Line"),
        left = Drawing.new("Line"),
        right = Drawing.new("Line")
    }
    local color = self:getPlayerColor(player, "box")
    for _, line in pairs(box) do
        line.Color = color
        line.Thickness = 1
        line.Visible = self.showBoxes
    end
    self.boxes[player] = { player = player, drawing = box }
end

function PlayerESP:removeLabel(player)
    if self.labels[player] and self.labels[player].drawing then
        self.labels[player].drawing:Remove()
        self.labels[player] = nil
    end
end

function PlayerESP:removeRay(player)
    if self.rays[player] and self.rays[player].drawing then
        self.rays[player].drawing:Remove()
        self.rays[player] = nil
    end
end

function PlayerESP:removeBox(player)
    if self.boxes[player] and self.boxes[player].drawing then
        for _, line in pairs(self.boxes[player].drawing) do
            line:Remove()
        end
        self.boxes[player] = nil
    end
end

function PlayerESP:updateCrosshairRays()
    if not self.localPlayer or not self.showRays then return end
    local camera = workspace.CurrentCamera
    local viewportSize = camera.ViewportSize
    -- 射线起点改为屏幕底部中央，适配所有分辨率
    local centerScreen = Vector2.new(viewportSize.X / 2, viewportSize.Y)

    for player, rayData in pairs(self.rays) do
        local ray = rayData.drawing
        local character = player.Character
        if character then
            local head = character:FindFirstChild("Head")
            if head then
                local headPos = head.Position + Vector3.new(0, 1, 0)
                local screenPos, onScreen = camera:WorldToViewportPoint(headPos)

                if onScreen then
                    ray.From = centerScreen
                    ray.To = Vector2.new(screenPos.X, screenPos.Y)
                else
                    local direction = Vector2.new(screenPos.X - centerScreen.X, screenPos.Y - centerScreen.Y)
                    if direction.Magnitude > 0 then
                        local edgePoint = centerScreen
                        local maxX = viewportSize.X
                        local maxY = viewportSize.Y
                        local tMin = math.huge
                        if direction.X > 0 then
                            local t = (maxX - centerScreen.X) / direction.X
                            if t > 0 and t < tMin then tMin = t; edgePoint = centerScreen + direction * t end
                        elseif direction.X < 0 then
                            local t = -centerScreen.X / direction.X
                            if t > 0 and t < tMin then tMin = t; edgePoint = centerScreen + direction * t end
                        end
                        if direction.Y > 0 then
                            local t = (maxY - centerScreen.Y) / direction.Y
                            if t > 0 and t < tMin then tMin = t; edgePoint = centerScreen + direction * t end
                        elseif direction.Y < 0 then
                            local t = -centerScreen.Y / direction.Y
                            if t > 0 and t < tMin then tMin = t; edgePoint = centerScreen + direction * t end
                        end
                        ray.From = centerScreen
                        ray.To = edgePoint
                    else
                        ray.From = centerScreen
                        ray.To = centerScreen
                    end
                end
                ray.Visible = true
            else
                ray.Visible = false
            end
        else
            ray.Visible = false
        end
    end
end

function PlayerESP:updateBoxes()
    if not self.localPlayer or not self.showBoxes then return end
    for player, boxData in pairs(self.boxes) do
        local box = boxData.drawing
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local rootPart = character.HumanoidRootPart
            local head = character:FindFirstChild("Head")
            if rootPart and head then
                local height = 5
                local width = 2
                local topPos = head.Position + Vector3.new(0, 1, 0)
                local bottomPos = rootPart.Position - Vector3.new(0, height/2, 0)
                local screenTop, topOnScreen = workspace.CurrentCamera:WorldToViewportPoint(topPos)
                local screenBottom, bottomOnScreen = workspace.CurrentCamera:WorldToViewportPoint(bottomPos)
                if topOnScreen or bottomOnScreen then
                    local centerX = screenTop.X
                    local topY = screenTop.Y
                    local bottomY = screenBottom.Y
                    local halfWidth = width * 10
                    box.top.From = Vector2.new(centerX - halfWidth, topY)
                    box.top.To = Vector2.new(centerX + halfWidth, topY)
                    box.bottom.From = Vector2.new(centerX - halfWidth, bottomY)
                    box.bottom.To = Vector2.new(centerX + halfWidth, bottomY)
                    box.left.From = Vector2.new(centerX - halfWidth, topY)
                    box.left.To = Vector2.new(centerX - halfWidth, bottomY)
                    box.right.From = Vector2.new(centerX + halfWidth, topY)
                    box.right.To = Vector2.new(centerX + halfWidth, bottomY)
                    for _, line in pairs(box) do line.Visible = true end
                else
                    for _, line in pairs(box) do line.Visible = false end
                end
            else
                for _, line in pairs(box) do line.Visible = false end
            end
        else
            for _, line in pairs(box) do line.Visible = false end
        end
    end
end

function PlayerESP:updateLabels(dt)
    if not self.localPlayer or not self.enabled then return end
    local localCharacter = self.localPlayer.Character
    if not localCharacter then return end
    local localHead = localCharacter:FindFirstChild("Head")
    if not localHead then return end
    for player, labelData in pairs(self.labels) do
        local drawing = labelData.drawing
        local character = player.Character
        if character then
            local head = character:FindFirstChild("Head")
            if head then
                local headPos = head.Position + Vector3.new(0, 2, 0)
                local distance = (headPos - localHead.Position).Magnitude
                drawing.Text = string.format("%s [%.1f]", player.Name, distance)
                local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(headPos)
                if onScreen then
                    drawing.Position = Vector2.new(screenPos.X, screenPos.Y)
                    drawing.Visible = true
                else
                    drawing.Visible = false
                end
            else
                drawing.Visible = false
            end
        else
            drawing.Visible = false
        end
    end
end

function PlayerESP:toggleESP()
    self.enabled = not self.enabled
    for _, labelData in pairs(self.labels) do
        if labelData.drawing then labelData.drawing.Visible = self.enabled end
    end
    if self.toggleButton then
        self.toggleButton.Text = self.enabled and "标签: 开启" or "标签: 关闭"
        self:tweenButton(self.toggleButton, self.enabled and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(239, 68, 68))
    end
end

function PlayerESP:toggleRays()
    self.showRays = not self.showRays
    for _, rayData in pairs(self.rays) do
        if rayData.drawing then rayData.drawing.Visible = self.showRays end
    end
    if self.rayToggleButton then
        self.rayToggleButton.Text = self.showRays and "射线: 开启" or "射线: 关闭"
        self:tweenButton(self.rayToggleButton, self.showRays and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(239, 68, 68))
    end
end

function PlayerESP:toggleBoxes()
    self.showBoxes = not self.showBoxes
    for _, boxData in pairs(self.boxes) do
        if boxData.drawing then
            for _, line in pairs(boxData.drawing) do
                line.Visible = self.showBoxes
            end
        end
    end
    if self.boxToggleButton then
        self.boxToggleButton.Text = self.showBoxes and "方框: 开启" or "方框: 关闭"
        self:tweenButton(self.boxToggleButton, self.showBoxes and Color3.fromRGB(139, 92, 246) or Color3.fromRGB(239, 68, 68))
    end
end

function PlayerESP:toggleWallCheck()
    self.wallCheck = not self.wallCheck
    if self.wallCheckButton then
        self.wallCheckButton.Text = "墙体检测: " .. (self.wallCheck and "开启" or "关闭")
        self:tweenButton(self.wallCheckButton, self.wallCheck and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(239, 68, 68))
    end
end

function PlayerESP:toggleTeamCheck()
    self.teamCheck = not self.teamCheck
    if self.teamCheckButton then
        self.teamCheckButton.Text = "队伍区分: " .. (self.teamCheck and "开启" or "关闭")
        self:tweenButton(self.teamCheckButton, self.teamCheck and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(239, 68, 68))
    end
end

function PlayerESP:toggleUI()
    self.isExpanded = not self.isExpanded
    if self.isExpanded then
        -- 展开：先显示主框架，从折叠位置开始动画展开
        self.mainFrame.Visible = true
        self.collapsedFrame.Visible = false
        
        -- 从小变大动画
        local startSize = UDim2.new(0, 150, 0, 150)
        local targetSize = UDim2.new(0, 360, 0, 520)
        self.mainFrame.Size = startSize
        self:tweenFrame(self.mainFrame, targetSize, nil, 0.3)
    else
        -- 折叠：先缩小动画，再隐藏
        local targetSize = UDim2.new(0, 80, 0, 80)
        local tween = self:tweenFrame(self.mainFrame, targetSize, nil, 0.2)
        
        tween.Completed:Connect(function()
            self.mainFrame.Visible = false
            self.collapsedFrame.Visible = true
            -- 折叠按钮弹出动画
            self.collapsedFrame.Size = UDim2.new(0, 40, 0, 40)
            self:tweenFrame(self.collapsedFrame, UDim2.new(0, 64, 0, 64), nil, 0.2)
        end)
    end
end

-- ============================================
-- 玩家列表
-- ============================================
function PlayerESP:createPlayerList(parent)
    local playerListFrame = Instance.new("Frame")
    playerListFrame.Name = "PlayerListFrame"
    playerListFrame.Size = UDim2.new(0.9, 0, 0, 80)
    playerListFrame.Position = UDim2.new(0, 0, 0, 0)
    playerListFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    playerListFrame.BorderSizePixel = 1
    playerListFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    playerListFrame.Parent = parent

    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = playerListFrame

    local uiListLayout = Instance.new("UIListLayout")
    uiListLayout.Padding = UDim.new(0, 2)
    uiListLayout.FillDirection = Enum.FillDirection.Vertical
    uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    uiListLayout.SortOrder = Enum.SortOrder.Name
    uiListLayout.Parent = scrollFrame

    self.playerListFrame = scrollFrame
    self:updatePlayerList()
    return playerListFrame
end

function PlayerESP:updatePlayerList()
    if not self.playerListFrame then return end
    for _, button in pairs(self.playerButtons) do
        if button then button:Destroy() end
    end
    self.playerButtons = {}
    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= self.localPlayer then
            table.insert(players, player)
        end
    end
    table.sort(players, function(a, b) return a.Name:lower() < b.Name:lower() end)
    local buttonHeight = 20
    local totalHeight = #players * (buttonHeight + 2)
    self.playerListFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    for i, player in ipairs(players) do
        local playerButton = Instance.new("TextButton")
        playerButton.Size = UDim2.new(0.95, 0, 0, buttonHeight)
        playerButton.Position = UDim2.new(0.025, 0, 0, (i-1) * (buttonHeight + 2))
        playerButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        playerButton.BorderSizePixel = 0
        playerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        playerButton.Text = player.Name
        playerButton.Font = Enum.Font.SourceSans
        playerButton.TextSize = 12
        playerButton.Parent = self.playerListFrame

        playerButton.MouseEnter:Connect(function()
            if not self.sitTarget or self.sitTarget ~= player then
                playerButton.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
            end
        end)
        playerButton.MouseLeave:Connect(function()
            if not self.sitTarget or self.sitTarget ~= player then
                playerButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
            end
        end)
        playerButton.MouseButton1Click:Connect(function()
            self.playerNameBox.Text = player.Name
            for _, btn in pairs(self.playerButtons) do
                if btn then btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70) end
            end
            playerButton.BackgroundColor3 = Color3.fromRGB(100, 0, 180)
        end)
        table.insert(self.playerButtons, playerButton)
    end
end

-- ============================================
-- 颜色更新
-- ============================================
function PlayerESP:updateAllLabelsColor()
    for player, labelData in pairs(self.labels) do
        if labelData.drawing then labelData.drawing.Color = self:getPlayerColor(player, "label") end
    end
end

function PlayerESP:updateAllRaysColor()
    for player, rayData in pairs(self.rays) do
        if rayData.drawing then rayData.drawing.Color = self:getPlayerColor(player, "ray") end
    end
end

function PlayerESP:updateAllBoxesColor()
    for player, boxData in pairs(self.boxes) do
        if boxData.drawing then
            local color = self:getPlayerColor(player, "box")
            for _, line in pairs(boxData.drawing) do line.Color = color end
        end
    end
end

function PlayerESP:updateAllColors()
    self:updateAllLabelsColor()
    self:updateAllRaysColor()
    self:updateAllBoxesColor()
end

-- ============================================
-- 现代化 UI 创建
-- ============================================
function PlayerESP:createUI()
    if self.screenGui then self.screenGui:Destroy() end
    if self.inputChangedConnection then self.inputChangedConnection:Disconnect() end

    self.screenGui = Instance.new("ScreenGui")
    self.screenGui.Name = "EnhancedESPGui"
    self.screenGui.ResetOnSpawn = false
    self.screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

    -- 主框架 (现代风格)
    self.mainFrame = Instance.new("Frame")
    self.mainFrame.Size = UDim2.new(0, 360, 0, 360)
    self.mainFrame.Position = UDim2.new(0, 20, 0, 20)
    self.mainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    self.mainFrame.BorderSizePixel = 0
    self.mainFrame.ClipsDescendants = true
    self.mainFrame.Parent = self.screenGui
    
    -- 圆角
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 16)
    mainCorner.Parent = self.mainFrame
    
    -- 阴影效果容器
    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1, 12, 1, 12)
    shadow.Position = UDim2.new(0, -6, 0, -6)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.85
    shadow.ZIndex = 0
    shadow.Parent = self.mainFrame
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 18)
    shadowCorner.Parent = shadow

    -- 标题栏
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 56)
    titleBar.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
    titleBar.BorderSizePixel = 0
    titleBar.ZIndex = 2
    titleBar.Parent = self.mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 16)
    titleCorner.Parent = titleBar
    
    -- 图标
    local iconFrame = Instance.new("Frame")
    iconFrame.Size = UDim2.new(0, 32, 0, 32)
    iconFrame.Position = UDim2.new(0, 16, 0.5, -16)
    iconFrame.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
    iconFrame.ZIndex = 3
    iconFrame.Parent = titleBar
    
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 10)
    iconCorner.Parent = iconFrame
    
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = "⚡"
    iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    iconLabel.TextSize = 18
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.ZIndex = 4
    iconLabel.Parent = iconFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.5, 0, 1, 0)
    titleLabel.Position = UDim2.new(0, 58, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "ESP 控制面板"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 18
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 3
    titleLabel.Parent = titleBar

    local collapseButton = Instance.new("TextButton")
    collapseButton.Size = UDim2.new(0, 36, 0, 36)
    collapseButton.Position = UDim2.new(1, -52, 0.5, -18)
    collapseButton.BackgroundColor3 = Color3.fromRGB(64, 64, 82)
    collapseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    collapseButton.Text = "−"
    collapseButton.Font = Enum.Font.GothamBold
    collapseButton.TextSize = 24
    collapseButton.ZIndex = 3
    collapseButton.Parent = titleBar
    
    local collapseCorner = Instance.new("UICorner")
    collapseCorner.CornerRadius = UDim.new(0, 12)
    collapseCorner.Parent = collapseButton

    -- Tab 栏
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -32, 0, 44)
    tabBar.Position = UDim2.new(0, 16, 0, 68)
    tabBar.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
    tabBar.BorderSizePixel = 0
    tabBar.ZIndex = 2
    tabBar.Parent = self.mainFrame
    
    local tabBarCorner = Instance.new("UICorner")
    tabBarCorner.CornerRadius = UDim.new(0, 12)
    tabBarCorner.Parent = tabBar

    self.tabButtons = {}
    self.tabContents = {}
    
    local tabs = {{"ESP", "ESP"}, {"战斗", "Combat"}, {"辅助", "Misc"}, {"设置", "Settings"}}
    for i, tabInfo in ipairs(tabs) do
        local btn = self:createTabButton(tabBar, tabInfo[1], tabInfo[2], UDim2.new((i-1) * 0.25, 0, 0, 4))
        btn.Name = tabInfo[2] .. "Tab"
        btn.Parent = tabBar
        self.tabButtons[tabInfo[2]] = btn
        
        btn.MouseButton1Click:Connect(function()
            self:switchTab(tabInfo[2])
        end)
    end

    -- 内容区域
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -32, 1, -140)
    contentFrame.Position = UDim2.new(0, 16, 0, 120)
    contentFrame.BackgroundTransparency = 1
    contentFrame.ZIndex = 2
    contentFrame.Parent = self.mainFrame

    -- 状态栏
    local statusBarFrame = Instance.new("Frame")
    statusBarFrame.Size = UDim2.new(1, -32, 0, 52)
    statusBarFrame.Position = UDim2.new(0, 16, 1, -68)
    statusBarFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
    statusBarFrame.BorderSizePixel = 0
    statusBarFrame.ZIndex = 2
    statusBarFrame.Parent = self.mainFrame
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 12)
    statusCorner.Parent = statusBarFrame

    self.targetStatusLabel = Instance.new("TextLabel")
    self.targetStatusLabel.Size = UDim2.new(1, -24, 0, 20)
    self.targetStatusLabel.Position = UDim2.new(0, 12, 0, 6)
    self.targetStatusLabel.BackgroundTransparency = 1
    self.targetStatusLabel.Text = "无目标"
    self.targetStatusLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
    self.targetStatusLabel.TextSize = 13
    self.targetStatusLabel.Font = Enum.Font.Gotham
    self.targetStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.targetStatusLabel.ZIndex = 3
    self.targetStatusLabel.Parent = statusBarFrame

    self.statusBar = Instance.new("TextLabel")
    self.statusBar.Size = UDim2.new(1, -24, 0, 18)
    self.statusBar.Position = UDim2.new(0, 12, 0, 28)
    self.statusBar.BackgroundTransparency = 1
    self.statusBar.Text = "就绪"
    self.statusBar.TextColor3 = Color3.fromRGB(74, 222, 128)
    self.statusBar.TextSize = 12
    self.statusBar.Font = Enum.Font.Gotham
    self.statusBar.TextXAlignment = Enum.TextXAlignment.Left
    self.statusBar.ZIndex = 3
    self.statusBar.Parent = statusBarFrame

    -- ========== ESP Tab ==========
    local espTab = Instance.new("ScrollingFrame")
    espTab.Name = "ESPTab"
    espTab.Size = UDim2.new(1, 0, 1, 0)
    espTab.BackgroundTransparency = 1
    espTab.BorderSizePixel = 0
    espTab.ScrollBarThickness = 4
    espTab.ScrollBarImageColor3 = Color3.fromRGB(75, 85, 99)
    espTab.AutomaticCanvasSize = Enum.AutomaticSize.Y
    espTab.CanvasSize = UDim2.new(0, 0, 0, 0)
    espTab.Visible = true
    espTab.ZIndex = 2
    espTab.Parent = contentFrame
    self.tabContents["ESP"] = espTab

    local espLayout = Instance.new("UIListLayout")
    espLayout.Padding = UDim.new(0, 12)
    espLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    espLayout.SortOrder = Enum.SortOrder.LayoutOrder
    espLayout.Parent = espTab

    local espPadding = Instance.new("UIPadding")
    espPadding.PaddingTop = UDim.new(0, 4)
    espPadding.PaddingBottom = UDim.new(0, 4)
    espPadding.Parent = espTab

    -- ESP 开关
    self.toggleButton = Instance.new("TextButton")
    self.toggleButton.Size = UDim2.new(1, 0, 0, 48)
    self.toggleButton.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
    self.toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.toggleButton.Text = "标签: 开启"
    self.toggleButton.Font = Enum.Font.GothamBold
    self.toggleButton.TextSize = 15
    self.toggleButton.LayoutOrder = 1
    self.toggleButton.ZIndex = 3
    self.toggleButton.Parent = espTab
    local toggleBtnCorner = Instance.new("UICorner")
    toggleBtnCorner.CornerRadius = UDim.new(0, 12)
    toggleBtnCorner.Parent = self.toggleButton

    self.rayToggleButton = Instance.new("TextButton")
    self.rayToggleButton.Size = UDim2.new(1, 0, 0, 48)
    self.rayToggleButton.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
    self.rayToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.rayToggleButton.Text = "射线: 开启"
    self.rayToggleButton.Font = Enum.Font.GothamBold
    self.rayToggleButton.TextSize = 15
    self.rayToggleButton.LayoutOrder = 2
    self.rayToggleButton.ZIndex = 3
    self.rayToggleButton.Parent = espTab
    local rayBtnCorner = Instance.new("UICorner")
    rayBtnCorner.CornerRadius = UDim.new(0, 12)
    rayBtnCorner.Parent = self.rayToggleButton

    self.boxToggleButton = Instance.new("TextButton")
    self.boxToggleButton.Size = UDim2.new(1, 0, 0, 48)
    self.boxToggleButton.BackgroundColor3 = Color3.fromRGB(139, 92, 246)
    self.boxToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.boxToggleButton.Text = "方框: 开启"
    self.boxToggleButton.Font = Enum.Font.GothamBold
    self.boxToggleButton.TextSize = 15
    self.boxToggleButton.LayoutOrder = 3
    self.boxToggleButton.ZIndex = 3
    self.boxToggleButton.Parent = espTab
    local boxBtnCorner = Instance.new("UICorner")
    boxBtnCorner.CornerRadius = UDim.new(0, 12)
    boxBtnCorner.Parent = self.boxToggleButton

    self.healthBarToggleBtn = Instance.new("TextButton")
    self.healthBarToggleBtn.Size = UDim2.new(1, 0, 0, 48)
    self.healthBarToggleBtn.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
    self.healthBarToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.healthBarToggleBtn.Text = "血量条: 开启"
    self.healthBarToggleBtn.Font = Enum.Font.GothamBold
    self.healthBarToggleBtn.TextSize = 15
    self.healthBarToggleBtn.LayoutOrder = 4
    self.healthBarToggleBtn.ZIndex = 3
    self.healthBarToggleBtn.Parent = espTab
    local healthBtnCorner = Instance.new("UICorner")
    healthBtnCorner.CornerRadius = UDim.new(0, 12)
    healthBtnCorner.Parent = self.healthBarToggleBtn

    self.headCircleToggleBtn = Instance.new("TextButton")
    self.headCircleToggleBtn.Size = UDim2.new(1, 0, 0, 48)
    self.headCircleToggleBtn.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
    self.headCircleToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.headCircleToggleBtn.Text = "头部圆圈: 开启"
    self.headCircleToggleBtn.Font = Enum.Font.GothamBold
    self.headCircleToggleBtn.TextSize = 15
    self.headCircleToggleBtn.LayoutOrder = 5
    self.headCircleToggleBtn.ZIndex = 3
    self.headCircleToggleBtn.Parent = espTab
    local headCircleBtnCorner = Instance.new("UICorner")
    headCircleBtnCorner.CornerRadius = UDim.new(0, 12)
    headCircleBtnCorner.Parent = self.headCircleToggleBtn

    -- 颜色设置
    local colorSection = Instance.new("TextLabel")
    colorSection.Size = UDim2.new(1, 0, 0, 24)
    colorSection.BackgroundTransparency = 1
    colorSection.Text = "颜色设置"
    colorSection.TextColor3 = Color3.fromRGB(226, 232, 240)
    colorSection.TextSize = 16
    colorSection.Font = Enum.Font.GothamBold
    colorSection.TextXAlignment = Enum.TextXAlignment.Left
    colorSection.LayoutOrder = 6
    colorSection.ZIndex = 3
    colorSection.Parent = espTab

    local labelColorFrame = self:createColorPicker(espTab, self.colors.label, "标签", function(color)
        self.colors.label = color
        self:updateAllLabelsColor()
    end)
    labelColorFrame.LayoutOrder = 7

    local rayColorFrame = self:createColorPicker(espTab, self.colors.ray, "射线", function(color)
        self.colors.ray = color
        self:updateAllRaysColor()
    end)
    rayColorFrame.LayoutOrder = 8

    local boxColorFrame = self:createColorPicker(espTab, self.colors.box, "方框", function(color)
        self.colors.box = color
        self:updateAllBoxesColor()
    end)
    boxColorFrame.LayoutOrder = 9

    local headCircleColorFrame = self:createColorPicker(espTab, self.colors.headCircle, "头部圆圈", function(color)
        self.colors.headCircle = color
    end)
    headCircleColorFrame.LayoutOrder = 10

    local teamToggle = Instance.new("TextButton")
    teamToggle.Size = UDim2.new(1, 0, 0, 40)
    teamToggle.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
    teamToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    teamToggle.Text = "队伍颜色: 关闭"
    teamToggle.Font = Enum.Font.Gotham
    teamToggle.TextSize = 14
    teamToggle.LayoutOrder = 11
    teamToggle.ZIndex = 3
    teamToggle.Parent = espTab
    local teamBtnCorner = Instance.new("UICorner")
    teamBtnCorner.CornerRadius = UDim.new(0, 10)
    teamBtnCorner.Parent = teamToggle

    -- ========== Combat Tab ==========
    local combatTab = Instance.new("ScrollingFrame")
    combatTab.Name = "CombatTab"
    combatTab.Size = UDim2.new(1, 0, 1, 0)
    combatTab.BackgroundTransparency = 1
    combatTab.BorderSizePixel = 0
    combatTab.ScrollBarThickness = 4
    combatTab.ScrollBarImageColor3 = Color3.fromRGB(75, 85, 99)
    combatTab.AutomaticCanvasSize = Enum.AutomaticSize.Y
    combatTab.CanvasSize = UDim2.new(0, 0, 0, 0)
    combatTab.Visible = false
    combatTab.ZIndex = 2
    combatTab.Parent = contentFrame
    self.tabContents["Combat"] = combatTab

    local combatLayout = Instance.new("UIListLayout")
    combatLayout.Padding = UDim.new(0, 12)
    combatLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    combatLayout.SortOrder = Enum.SortOrder.LayoutOrder
    combatLayout.Parent = combatTab

    local combatPadding = Instance.new("UIPadding")
    combatPadding.PaddingTop = UDim.new(0, 4)
    combatPadding.PaddingBottom = UDim.new(0, 4)
    combatPadding.Parent = combatTab

    self.aimbotToggleButton = Instance.new("TextButton")
    self.aimbotToggleButton.Size = UDim2.new(1, 0, 0, 48)
    self.aimbotToggleButton.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
    self.aimbotToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.aimbotToggleButton.Text = "自瞄: 关闭"
    self.aimbotToggleButton.Font = Enum.Font.GothamBold
    self.aimbotToggleButton.TextSize = 15
    self.aimbotToggleButton.LayoutOrder = 1
    self.aimbotToggleButton.ZIndex = 3
    self.aimbotToggleButton.Parent = combatTab
    local aimbotBtnCorner = Instance.new("UICorner")
    aimbotBtnCorner.CornerRadius = UDim.new(0, 12)
    aimbotBtnCorner.Parent = self.aimbotToggleButton

    self.triggerbotToggleButton = Instance.new("TextButton")
    self.triggerbotToggleButton.Size = UDim2.new(1, 0, 0, 48)
    self.triggerbotToggleButton.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
    self.triggerbotToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.triggerbotToggleButton.Text = "扳机: 关闭"
    self.triggerbotToggleButton.Font = Enum.Font.GothamBold
    self.triggerbotToggleButton.TextSize = 15
    self.triggerbotToggleButton.LayoutOrder = 2
    self.triggerbotToggleButton.ZIndex = 3
    self.triggerbotToggleButton.Parent = combatTab
    local triggerBtnCorner = Instance.new("UICorner")
    triggerBtnCorner.CornerRadius = UDim.new(0, 12)
    triggerBtnCorner.Parent = self.triggerbotToggleButton

    self.wallCheckButton = Instance.new("TextButton")
    self.wallCheckButton.Size = UDim2.new(1, 0, 0, 40)
    self.wallCheckButton.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
    self.wallCheckButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.wallCheckButton.Text = "墙体检测: 开启"
    self.wallCheckButton.Font = Enum.Font.Gotham
    self.wallCheckButton.TextSize = 14
    self.wallCheckButton.LayoutOrder = 3
    self.wallCheckButton.ZIndex = 3
    self.wallCheckButton.Parent = combatTab
    local wallBtnCorner = Instance.new("UICorner")
    wallBtnCorner.CornerRadius = UDim.new(0, 10)
    wallBtnCorner.Parent = self.wallCheckButton

    self.teamCheckButton = Instance.new("TextButton")
    self.teamCheckButton.Size = UDim2.new(1, 0, 0, 40)
    self.teamCheckButton.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
    self.teamCheckButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.teamCheckButton.Text = "队伍区分: 开启"
    self.teamCheckButton.Font = Enum.Font.Gotham
    self.teamCheckButton.TextSize = 14
    self.teamCheckButton.LayoutOrder = 4
    self.teamCheckButton.ZIndex = 3
    self.teamCheckButton.Parent = combatTab
    local teamBtnCorner = Instance.new("UICorner")
    teamBtnCorner.CornerRadius = UDim.new(0, 10)
    teamBtnCorner.Parent = self.teamCheckButton

    self.fovCircleToggleBtn = Instance.new("TextButton")
    self.fovCircleToggleBtn.Size = UDim2.new(1, 0, 0, 40)
    self.fovCircleToggleBtn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
    self.fovCircleToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.fovCircleToggleBtn.Text = "FOV圈: 开启"
    self.fovCircleToggleBtn.Font = Enum.Font.Gotham
    self.fovCircleToggleBtn.TextSize = 14
    self.fovCircleToggleBtn.LayoutOrder = 5
    self.fovCircleToggleBtn.ZIndex = 3
    self.fovCircleToggleBtn.Parent = combatTab
    local fovBtnCorner = Instance.new("UICorner")
    fovBtnCorner.CornerRadius = UDim.new(0, 10)
    fovBtnCorner.Parent = self.fovCircleToggleBtn

    -- 扳机设置
    local triggerSettingsLabel = Instance.new("TextLabel")
    triggerSettingsLabel.Size = UDim2.new(1, 0, 0, 24)
    triggerSettingsLabel.BackgroundTransparency = 1
    triggerSettingsLabel.Text = "扳机设置"
    triggerSettingsLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
    triggerSettingsLabel.TextSize = 16
    triggerSettingsLabel.Font = Enum.Font.GothamBold
    triggerSettingsLabel.TextXAlignment = Enum.TextXAlignment.Left
    triggerSettingsLabel.LayoutOrder = 6
    triggerSettingsLabel.ZIndex = 3
    triggerSettingsLabel.Parent = combatTab

    self.triggerHeadOnlyBtn = Instance.new("TextButton")
    self.triggerHeadOnlyBtn.Size = UDim2.new(1, 0, 0, 40)
    self.triggerHeadOnlyBtn.BackgroundColor3 = self.triggerbotHeadOnly and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(51, 65, 85)
    self.triggerHeadOnlyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.triggerHeadOnlyBtn.Text = "仅头部触发: " .. (self.triggerbotHeadOnly and "开启" or "关闭")
    self.triggerHeadOnlyBtn.Font = Enum.Font.Gotham
    self.triggerHeadOnlyBtn.TextSize = 14
    self.triggerHeadOnlyBtn.LayoutOrder = 7
    self.triggerHeadOnlyBtn.ZIndex = 3
    self.triggerHeadOnlyBtn.Parent = combatTab
    local headOnlyBtnCorner = Instance.new("UICorner")
    headOnlyBtnCorner.CornerRadius = UDim.new(0, 10)
    headOnlyBtnCorner.Parent = self.triggerHeadOnlyBtn

    -- 触发延迟 (文本输入)
    local triggerDelayInput = self:createParamInput(combatTab, "触发延迟(ms)", self.triggerbotDelay, 0, 500, function(value)
        self.triggerbotDelay = value
    end, true)
    triggerDelayInput.LayoutOrder = 8

    -- 扳机命中预测参数
    local triggerPredictionInput = self:createParamInput(combatTab, "扳机预测强度", self.triggerbotPrediction, 0, 1, function(value)
        self.triggerbotPrediction = value
    end, false)
    triggerPredictionInput.LayoutOrder = 9

    -- 自瞄参数
    local aimbotSettingsLabel = Instance.new("TextLabel")
    aimbotSettingsLabel.Size = UDim2.new(1, 0, 0, 24)
    aimbotSettingsLabel.BackgroundTransparency = 1
    aimbotSettingsLabel.Text = "自瞄参数"
    aimbotSettingsLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
    aimbotSettingsLabel.TextSize = 16
    aimbotSettingsLabel.Font = Enum.Font.GothamBold
    aimbotSettingsLabel.TextXAlignment = Enum.TextXAlignment.Left
    aimbotSettingsLabel.LayoutOrder = 10
    aimbotSettingsLabel.ZIndex = 3
    aimbotSettingsLabel.Parent = combatTab

    -- 平滑度 (文本输入)
    local smoothnessInput = self:createParamInput(combatTab, "平滑度", self.aimbotSmoothness, 1, 20, function(value)
        self.aimbotSmoothness = value
    end, false)
    smoothnessInput.LayoutOrder = 11

    -- 预测强度 (文本输入)
    local predictionInput = self:createParamInput(combatTab, "移动预测", self.aimbotPrediction, 0, 2, function(value)
        self.aimbotPrediction = value
    end, false)
    predictionInput.LayoutOrder = 12

    -- 范围 (文本输入)
    local rangeInput = self:createParamInput(combatTab, "自瞄范围", self.aimbotRange, 50, 500, function(value)
        self.aimbotRange = value
    end, true)
    rangeInput.LayoutOrder = 13

    -- FOV (文本输入)
    local fovInput = self:createParamInput(combatTab, "自瞄FOV", self.aimbotFov, 30, 360, function(value)
        self.aimbotFov = value
    end, true)
    fovInput.LayoutOrder = 14

    -- 瞄地面功能开关按钮
    self.groundAimToggleBtn = Instance.new("TextButton")
    self.groundAimToggleBtn.Size = UDim2.new(1, 0, 0, 48)
    self.groundAimToggleBtn.BackgroundColor3 = self.aimbotGroundAimEnabled and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(239, 68, 68)
    self.groundAimToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.groundAimToggleBtn.Text = "瞄地面: " .. (self.aimbotGroundAimEnabled and "开启" or "关闭")
    self.groundAimToggleBtn.Font = Enum.Font.GothamBold
    self.groundAimToggleBtn.TextSize = 15
    self.groundAimToggleBtn.LayoutOrder = 15
    self.groundAimToggleBtn.ZIndex = 3
    self.groundAimToggleBtn.Parent = combatTab
    local groundBtnCorner = Instance.new("UICorner")
    groundBtnCorner.CornerRadius = UDim.new(0, 12)
    groundBtnCorner.Parent = self.groundAimToggleBtn

    -- 瞄地面时间参数 (文本输入)
    local groundAimTimeInput = self:createParamInput(combatTab, "瞄目标时间(秒)", self.aimbotGroundAimTime, 0.1, 5, function(value)
        self.aimbotGroundAimTime = value
    end, false)
    groundAimTimeInput.LayoutOrder = 16

    -- ========== Misc Tab ==========
    local miscTab = Instance.new("ScrollingFrame")
    miscTab.Name = "MiscTab"
    miscTab.Size = UDim2.new(1, 0, 1, 0)
    miscTab.BackgroundTransparency = 1
    miscTab.BorderSizePixel = 0
    miscTab.ScrollBarThickness = 4
    miscTab.ScrollBarImageColor3 = Color3.fromRGB(75, 85, 99)
    miscTab.AutomaticCanvasSize = Enum.AutomaticSize.Y
    miscTab.CanvasSize = UDim2.new(0, 0, 0, 0)
    miscTab.Visible = false
    miscTab.ZIndex = 2
    miscTab.Parent = contentFrame
    self.tabContents["Misc"] = miscTab

    local miscLayout = Instance.new("UIListLayout")
    miscLayout.Padding = UDim.new(0, 12)
    miscLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    miscLayout.SortOrder = Enum.SortOrder.LayoutOrder
    miscLayout.Parent = miscTab

    local miscPadding = Instance.new("UIPadding")
    miscPadding.PaddingTop = UDim.new(0, 4)
    miscPadding.PaddingBottom = UDim.new(0, 4)
    miscPadding.Parent = miscTab

    self.flyToggleBtn = Instance.new("TextButton")
    self.flyToggleBtn.Size = UDim2.new(1, 0, 0, 48)
    self.flyToggleBtn.BackgroundColor3 = self.flyEnabled and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(239, 68, 68)
    self.flyToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.flyToggleBtn.Text = "飞行: " .. (self.flyEnabled and "开启" or "关闭")
    self.flyToggleBtn.Font = Enum.Font.GothamBold
    self.flyToggleBtn.TextSize = 15
    self.flyToggleBtn.LayoutOrder = 2
    self.flyToggleBtn.ZIndex = 3
    self.flyToggleBtn.Parent = miscTab
    local flyBtnCorner = Instance.new("UICorner")
    flyBtnCorner.CornerRadius = UDim.new(0, 12)
    flyBtnCorner.Parent = self.flyToggleBtn

    -- 飞行速度 (文本输入)
    local flySpeedInput = self:createParamInput(miscTab, "飞行速度", self.flySpeed, 10, 200, function(value)
        self.flySpeed = value
    end, true)
    flySpeedInput.LayoutOrder = 3

    -- 强制第三人称按钮
    self.thirdPersonToggleBtn = Instance.new("TextButton")
    self.thirdPersonToggleBtn.Size = UDim2.new(1, 0, 0, 48)
    self.thirdPersonToggleBtn.BackgroundColor3 = self.forceThirdPerson and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(239, 68, 68)
    self.thirdPersonToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.thirdPersonToggleBtn.Text = "第三人称: " .. (self.forceThirdPerson and "开启" or "关闭")
    self.thirdPersonToggleBtn.Font = Enum.Font.GothamBold
    self.thirdPersonToggleBtn.TextSize = 15
    self.thirdPersonToggleBtn.LayoutOrder = 4
    self.thirdPersonToggleBtn.ZIndex = 3
    self.thirdPersonToggleBtn.Parent = miscTab
    local thirdBtnCorner = Instance.new("UICorner")
    thirdBtnCorner.CornerRadius = UDim.new(0, 12)
    thirdBtnCorner.Parent = self.thirdPersonToggleBtn

    -- 坐头功能
    local sitSection = Instance.new("TextLabel")
    sitSection.Size = UDim2.new(1, 0, 0, 24)
    sitSection.BackgroundTransparency = 1
    sitSection.Text = "坐头功能"
    sitSection.TextColor3 = Color3.fromRGB(226, 232, 240)
    sitSection.TextSize = 16
    sitSection.Font = Enum.Font.GothamBold
    sitSection.TextXAlignment = Enum.TextXAlignment.Left
    sitSection.LayoutOrder = 5
    sitSection.ZIndex = 3
    sitSection.Parent = miscTab

    self.playerNameBox = Instance.new("TextBox")
    self.playerNameBox.Size = UDim2.new(1, 0, 0, 44)
    self.playerNameBox.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
    self.playerNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.playerNameBox.PlaceholderText = "输入玩家名"
    self.playerNameBox.Text = ""
    self.playerNameBox.Font = Enum.Font.Gotham
    self.playerNameBox.TextSize = 14
    self.playerNameBox.LayoutOrder = 6
    self.playerNameBox.ZIndex = 3
    self.playerNameBox.Parent = miscTab
    local nameCorner = Instance.new("UICorner")
    nameCorner.CornerRadius = UDim.new(0, 10)
    nameCorner.Parent = self.playerNameBox

    local playerListContainer = Instance.new("Frame")
    playerListContainer.Size = UDim2.new(1, 0, 0, 100)
    playerListContainer.BackgroundTransparency = 1
    playerListContainer.LayoutOrder = 7
    playerListContainer.ZIndex = 3
    playerListContainer.Parent = miscTab

    local playerListTitle = Instance.new("TextLabel")
    playerListTitle.Size = UDim2.new(1, 0, 0, 20)
    playerListTitle.BackgroundTransparency = 1
    playerListTitle.Text = "快速选择玩家:"
    playerListTitle.TextColor3 = Color3.fromRGB(148, 163, 184)
    playerListTitle.TextSize = 13
    playerListTitle.Font = Enum.Font.Gotham
    playerListTitle.TextXAlignment = Enum.TextXAlignment.Left
    playerListTitle.ZIndex = 4
    playerListTitle.Parent = playerListContainer

    self:createPlayerList(playerListContainer)
    local playerListFrame = playerListContainer:FindFirstChild("PlayerListFrame")
    if playerListFrame then playerListFrame.Position = UDim2.new(0, 0, 0, 24) end

    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(1, 0, 0, 44)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.LayoutOrder = 8
    buttonFrame.ZIndex = 3
    buttonFrame.Parent = miscTab

    self.lockButton = Instance.new("TextButton")
    self.lockButton.Size = UDim2.new(0.48, 0, 1, 0)
    self.lockButton.BackgroundColor3 = Color3.fromRGB(139, 92, 246)
    self.lockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.lockButton.Text = "锁定"
    self.lockButton.Font = Enum.Font.GothamBold
    self.lockButton.TextSize = 14
    self.lockButton.ZIndex = 4
    self.lockButton.Parent = buttonFrame
    local lockBtnCorner = Instance.new("UICorner")
    lockBtnCorner.CornerRadius = UDim.new(0, 10)
    lockBtnCorner.Parent = self.lockButton

    self.cancelButton = Instance.new("TextButton")
    self.cancelButton.Size = UDim2.new(0.48, 0, 1, 0)
    self.cancelButton.Position = UDim2.new(0.52, 0, 0, 0)
    self.cancelButton.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
    self.cancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.cancelButton.Text = "取消"
    self.cancelButton.Font = Enum.Font.GothamBold
    self.cancelButton.TextSize = 14
    self.cancelButton.ZIndex = 4
    self.cancelButton.Parent = buttonFrame
    local cancelBtnCorner = Instance.new("UICorner")
    cancelBtnCorner.CornerRadius = UDim.new(0, 10)
    cancelBtnCorner.Parent = self.cancelButton

    self.sitStatusLabel = Instance.new("TextLabel")
    self.sitStatusLabel.Size = UDim2.new(1, 0, 0, 24)
    self.sitStatusLabel.BackgroundTransparency = 1
    self.sitStatusLabel.Text = "状态: 未锁定"
    self.sitStatusLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
    self.sitStatusLabel.TextSize = 14
    self.sitStatusLabel.Font = Enum.Font.Gotham
    self.sitStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.sitStatusLabel.LayoutOrder = 9
    self.sitStatusLabel.ZIndex = 3
    self.sitStatusLabel.Parent = miscTab

    -- 坐头高度参数
    local sitHeightInput = self:createParamInput(miscTab, "坐头高度", self.sitHeightOffset, 0, 10, function(value)
        self.sitHeightOffset = value
    end, false)
    sitHeightInput.LayoutOrder = 10

    -- ========== Settings Tab ==========
    local settingsTab = Instance.new("ScrollingFrame")
    settingsTab.Name = "SettingsTab"
    settingsTab.Size = UDim2.new(1, 0, 1, 0)
    settingsTab.BackgroundTransparency = 1
    settingsTab.BorderSizePixel = 0
    settingsTab.ScrollBarThickness = 4
    settingsTab.ScrollBarImageColor3 = Color3.fromRGB(75, 85, 99)
    settingsTab.AutomaticCanvasSize = Enum.AutomaticSize.Y
    settingsTab.CanvasSize = UDim2.new(0, 0, 0, 0)
    settingsTab.Visible = false
    settingsTab.ZIndex = 2
    settingsTab.Parent = contentFrame
    self.tabContents["Settings"] = settingsTab

    local settingsLayout = Instance.new("UIListLayout")
    settingsLayout.Padding = UDim.new(0, 12)
    settingsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    settingsLayout.Parent = settingsTab

    local settingsPadding = Instance.new("UIPadding")
    settingsPadding.PaddingTop = UDim.new(0, 4)
    settingsPadding.PaddingBottom = UDim.new(0, 4)
    settingsPadding.Parent = settingsTab

    -- 按键绑定
    local keybindSection = Instance.new("TextLabel")
    keybindSection.Size = UDim2.new(1, 0, 0, 24)
    keybindSection.BackgroundTransparency = 1
    keybindSection.Text = "按键绑定"
    keybindSection.TextColor3 = Color3.fromRGB(226, 232, 240)
    keybindSection.TextSize = 16
    keybindSection.Font = Enum.Font.GothamBold
    keybindSection.TextXAlignment = Enum.TextXAlignment.Left
    keybindSection.LayoutOrder = 1
    keybindSection.ZIndex = 3
    keybindSection.Parent = settingsTab

    -- 自瞄按键
    local aimbotKeyFrame = Instance.new("Frame")
    aimbotKeyFrame.Size = UDim2.new(1, 0, 0, 44)
    aimbotKeyFrame.BackgroundTransparency = 1
    aimbotKeyFrame.LayoutOrder = 2
    aimbotKeyFrame.ZIndex = 3
    aimbotKeyFrame.Parent = settingsTab
    local aimbotKeyLabel = Instance.new("TextLabel")
    aimbotKeyLabel.Size = UDim2.new(0.5, 0, 1, 0)
    aimbotKeyLabel.BackgroundTransparency = 1
    aimbotKeyLabel.Text = "自瞄按键:"
    aimbotKeyLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
    aimbotKeyLabel.TextSize = 14
    aimbotKeyLabel.Font = Enum.Font.Gotham
    aimbotKeyLabel.TextXAlignment = Enum.TextXAlignment.Left
    aimbotKeyLabel.ZIndex = 4
    aimbotKeyLabel.Parent = aimbotKeyFrame
    self.aimbotKeyBox = Instance.new("TextBox")
    self.aimbotKeyBox.Size = UDim2.new(0, 100, 0, 40)
    self.aimbotKeyBox.Position = UDim2.new(1, -100, 0, 2)
    self.aimbotKeyBox.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
    self.aimbotKeyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.aimbotKeyBox.Text = self.aimbotKey
    self.aimbotKeyBox.Font = Enum.Font.Gotham
    self.aimbotKeyBox.TextSize = 14
    self.aimbotKeyBox.TextXAlignment = Enum.TextXAlignment.Center
    self.aimbotKeyBox.ZIndex = 4
    self.aimbotKeyBox.Parent = aimbotKeyFrame
    local aimbotKeyCorner = Instance.new("UICorner")
    aimbotKeyCorner.CornerRadius = UDim.new(0, 10)
    aimbotKeyCorner.Parent = self.aimbotKeyBox

    -- 扳机按键
    local triggerKeyFrame = Instance.new("Frame")
    triggerKeyFrame.Size = UDim2.new(1, 0, 0, 44)
    triggerKeyFrame.BackgroundTransparency = 1
    triggerKeyFrame.LayoutOrder = 3
    triggerKeyFrame.ZIndex = 3
    triggerKeyFrame.Parent = settingsTab
    local triggerKeyLabel = Instance.new("TextLabel")
    triggerKeyLabel.Size = UDim2.new(0.5, 0, 1, 0)
    triggerKeyLabel.BackgroundTransparency = 1
    triggerKeyLabel.Text = "扳机按键:"
    triggerKeyLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
    triggerKeyLabel.TextSize = 14
    triggerKeyLabel.Font = Enum.Font.Gotham
    triggerKeyLabel.TextXAlignment = Enum.TextXAlignment.Left
    triggerKeyLabel.ZIndex = 4
    triggerKeyLabel.Parent = triggerKeyFrame
    self.triggerbotKeyBox = Instance.new("TextBox")
    self.triggerbotKeyBox.Size = UDim2.new(0, 100, 0, 40)
    self.triggerbotKeyBox.Position = UDim2.new(1, -100, 0, 2)
    self.triggerbotKeyBox.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
    self.triggerbotKeyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.triggerbotKeyBox.Text = self.triggerbotKey
    self.triggerbotKeyBox.Font = Enum.Font.Gotham
    self.triggerbotKeyBox.TextSize = 14
    self.triggerbotKeyBox.TextXAlignment = Enum.TextXAlignment.Center
    self.triggerbotKeyBox.ZIndex = 4
    self.triggerbotKeyBox.Parent = triggerKeyFrame
    local triggerKeyCorner = Instance.new("UICorner")
    triggerKeyCorner.CornerRadius = UDim.new(0, 10)
    triggerKeyCorner.Parent = self.triggerbotKeyBox

    -- 飞行按键
    local flyKeyFrame = Instance.new("Frame")
    flyKeyFrame.Size = UDim2.new(1, 0, 0, 44)
    flyKeyFrame.BackgroundTransparency = 1
    flyKeyFrame.LayoutOrder = 4
    flyKeyFrame.ZIndex = 3
    flyKeyFrame.Parent = settingsTab
    local flyKeyLabel = Instance.new("TextLabel")
    flyKeyLabel.Size = UDim2.new(0.5, 0, 1, 0)
    flyKeyLabel.BackgroundTransparency = 1
    flyKeyLabel.Text = "飞行按键:"
    flyKeyLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
    flyKeyLabel.TextSize = 14
    flyKeyLabel.Font = Enum.Font.Gotham
    flyKeyLabel.TextXAlignment = Enum.TextXAlignment.Left
    flyKeyLabel.ZIndex = 4
    flyKeyLabel.Parent = flyKeyFrame
    self.flyKeyBox = Instance.new("TextBox")
    self.flyKeyBox.Size = UDim2.new(0, 100, 0, 40)
    self.flyKeyBox.Position = UDim2.new(1, -100, 0, 2)
    self.flyKeyBox.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
    self.flyKeyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.flyKeyBox.Text = self.flyKey
    self.flyKeyBox.Font = Enum.Font.Gotham
    self.flyKeyBox.TextSize = 14
    self.flyKeyBox.TextXAlignment = Enum.TextXAlignment.Center
    self.flyKeyBox.ZIndex = 4
    self.flyKeyBox.Parent = flyKeyFrame
    local flyKeyCorner = Instance.new("UICorner")
    flyKeyCorner.CornerRadius = UDim.new(0, 10)
    flyKeyCorner.Parent = self.flyKeyBox

    -- 说明
    local infoSection = Instance.new("TextLabel")
    infoSection.Size = UDim2.new(1, 0, 0, 24)
    infoSection.BackgroundTransparency = 1
    infoSection.Text = "说明"
    infoSection.TextColor3 = Color3.fromRGB(226, 232, 240)
    infoSection.TextSize = 16
    infoSection.Font = Enum.Font.GothamBold
    infoSection.TextXAlignment = Enum.TextXAlignment.Left
    infoSection.LayoutOrder = 5
    infoSection.ZIndex = 3
    infoSection.Parent = settingsTab

    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(1, 0, 0, 120)
    infoText.BackgroundTransparency = 1
    infoText.Text = "PC: WASD飞行 空格上升 Shift下降\n手机: 飞行时自动显示虚拟摇杆\n左侧摇杆控制方向 右侧按钮升降\n飞行时自动取消坐头锁定"
    infoText.TextColor3 = Color3.fromRGB(148, 163, 184)
    infoText.TextSize = 13
    infoText.Font = Enum.Font.Gotham
    infoText.TextXAlignment = Enum.TextXAlignment.Left
    infoText.TextYAlignment = Enum.TextYAlignment.Top
    infoText.LayoutOrder = 6
    infoText.ZIndex = 3
    infoText.Parent = settingsTab

    -- 折叠按钮
    self.collapsedFrame = Instance.new("TextButton")
    self.collapsedFrame.Size = UDim2.new(0, 64, 0, 64)
    self.collapsedFrame.Position = UDim2.new(0, 20, 0, 20)
    self.collapsedFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    self.collapsedFrame.BorderSizePixel = 0
    self.collapsedFrame.Text = "⚡"
    self.collapsedFrame.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.collapsedFrame.TextSize = 32
    self.collapsedFrame.Font = Enum.Font.GothamBold
    self.collapsedFrame.Visible = false
    self.collapsedFrame.ZIndex = 10
    self.collapsedFrame.Parent = self.screenGui
    local collapsedCorner = Instance.new("UICorner")
    collapsedCorner.CornerRadius = UDim.new(0, 16)
    collapsedCorner.Parent = self.collapsedFrame
    
    -- 折叠按钮阴影
    local collapsedShadow = Instance.new("Frame")
    collapsedShadow.Size = UDim2.new(1, 8, 1, 8)
    collapsedShadow.Position = UDim2.new(0, -4, 0, -4)
    collapsedShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    collapsedShadow.BackgroundTransparency = 0.85
    collapsedShadow.ZIndex = 9
    collapsedShadow.Parent = self.collapsedFrame
    local collapsedShadowCorner = Instance.new("UICorner")
    collapsedShadowCorner.CornerRadius = UDim.new(0, 18)
    collapsedShadowCorner.Parent = collapsedShadow

    -- 事件绑定 (带点击特效)
    self.toggleButton.MouseButton1Click:Connect(function() self:buttonClickEffect(self.toggleButton) self:toggleESP() end)
    self.rayToggleButton.MouseButton1Click:Connect(function() self:buttonClickEffect(self.rayToggleButton) self:toggleRays() end)
    self.boxToggleButton.MouseButton1Click:Connect(function() self:buttonClickEffect(self.boxToggleButton) self:toggleBoxes() end)
    self.aimbotToggleButton.MouseButton1Click:Connect(function() self:buttonClickEffect(self.aimbotToggleButton) self:toggleAimbot() end)
    self.groundAimToggleBtn.MouseButton1Click:Connect(function()
        self:buttonClickEffect(self.groundAimToggleBtn)
        self.aimbotGroundAimEnabled = not self.aimbotGroundAimEnabled
        self.aimbotIsGroundAiming = false
        self.aimbotGroundAimTimer = 0
        self.groundAimToggleBtn.Text = "瞄地面: " .. (self.aimbotGroundAimEnabled and "开启" or "关闭")
        self:tweenButton(self.groundAimToggleBtn, self.aimbotGroundAimEnabled and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(239, 68, 68))
    end)
    self.triggerbotToggleButton.MouseButton1Click:Connect(function() self:buttonClickEffect(self.triggerbotToggleButton) self:toggleTriggerbot() end)
    self.wallCheckButton.MouseButton1Click:Connect(function() self:buttonClickEffect(self.wallCheckButton) self:toggleWallCheck() end)
    self.teamCheckButton.MouseButton1Click:Connect(function() self:buttonClickEffect(self.teamCheckButton) self:toggleTeamCheck() end)
    self.lockButton.MouseButton1Click:Connect(function() self:buttonClickEffect(self.lockButton) self:lockToPlayer() end)
    self.cancelButton.MouseButton1Click:Connect(function()
        self:buttonClickEffect(self.cancelButton)
        self:cancelLock()
    end)
    collapseButton.MouseButton1Click:Connect(function() self:buttonClickEffect(collapseButton) self:toggleUI() end)
    self.collapsedFrame.MouseButton1Click:Connect(function() self:buttonClickEffect(self.collapsedFrame) self:toggleUI() end)
    
    self.healthBarToggleBtn.MouseButton1Click:Connect(function() self:buttonClickEffect(self.healthBarToggleBtn) self:toggleHealthBars() end)
    self.headCircleToggleBtn.MouseButton1Click:Connect(function() self:buttonClickEffect(self.headCircleToggleBtn) self:toggleHeadCircles() end)
    self.fovCircleToggleBtn.MouseButton1Click:Connect(function() self:buttonClickEffect(self.fovCircleToggleBtn) self:toggleFovCircle() end)
    self.flyToggleBtn.MouseButton1Click:Connect(function() self:buttonClickEffect(self.flyToggleBtn) self:toggleFly() end)
    self.thirdPersonToggleBtn.MouseButton1Click:Connect(function() self:buttonClickEffect(self.thirdPersonToggleBtn) self:toggleThirdPerson() end)
    
    self.triggerHeadOnlyBtn.MouseButton1Click:Connect(function()
        self:buttonClickEffect(self.triggerHeadOnlyBtn)
        self.triggerbotHeadOnly = not self.triggerbotHeadOnly
        self.triggerHeadOnlyBtn.Text = "仅头部触发: " .. (self.triggerbotHeadOnly and "开启" or "关闭")
        self:tweenButton(self.triggerHeadOnlyBtn, self.triggerbotHeadOnly and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(51, 65, 85))
    end)
    
    teamToggle.MouseButton1Click:Connect(function()
        self:buttonClickEffect(teamToggle)
        self.colors.teamBased = not self.colors.teamBased
        teamToggle.Text = "队伍颜色: " .. (self.colors.teamBased and "开启" or "关闭")
        self:tweenButton(teamToggle, self.colors.teamBased and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(51, 65, 85))
        self:updateAllColors()
    end)

    -- 输入框事件
    self.aimbotKeyBox.FocusLost:Connect(function()
        local newKey = self.aimbotKeyBox.Text:lower()
        if newKey ~= "" and #newKey == 1 then
            self.aimbotKey = newKey
            self:setupAimbotKey()
        else
            self.aimbotKeyBox.Text = self.aimbotKey
        end
    end)
    
    self.triggerbotKeyBox.FocusLost:Connect(function()
        local newKey = self.triggerbotKeyBox.Text:lower()
        if newKey ~= "" and #newKey == 1 then
            self.triggerbotKey = newKey
            self:setupTriggerbotKey()
        else
            self.triggerbotKeyBox.Text = self.triggerbotKey
        end
    end)
    
    self.flyKeyBox.FocusLost:Connect(function()
        local newKey = self.flyKeyBox.Text:lower()
        if newKey ~= "" and #newKey == 1 then
            self.flyKey = newKey
        else
            self.flyKeyBox.Text = self.flyKey
        end
    end)

    -- 拖动功能
    local function startDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self.isDragging = true
            self.dragStartPos = Vector2.new(input.Position.X, input.Position.Y)
            self.frameStartPos = UDim2.new(0, self.mainFrame.Position.X.Offset, 0, self.mainFrame.Position.Y.Offset)
        end
    end
    local function endDrag(input)
        if self.isDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            self.isDragging = false
        end
    end
    local function updateDrag(input)
        if self.isDragging and self.isExpanded then
            local delta = Vector2.new(input.Position.X, input.Position.Y) - self.dragStartPos
            self.mainFrame.Position = UDim2.new(
                0, self.frameStartPos.X.Offset + delta.X,
                0, self.frameStartPos.Y.Offset + delta.Y
            )
        end
    end
    titleBar.InputBegan:Connect(startDrag)
    UserInputService.InputEnded:Connect(endDrag)
    self.inputChangedConnection = UserInputService.InputChanged:Connect(updateDrag)

    -- 飞行快捷键
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode[self.flyKey:upper()] then
            self:toggleFly()
        end
    end)

    self:setupAimbotKey()
    self:setupTriggerbotKey()
end

-- ============================================
-- 初始化
-- ============================================
function PlayerESP:init()
    self.localPlayer = Players.LocalPlayer
    
    self:createFovCircle()
    self:createUI()
    
    Players.PlayerAdded:Connect(function(player)
        if player ~= self.localPlayer then
            self:createLabel(player)
            self:createRay(player)
            self:createBox(player)
            self:createHealthBar(player)
            self:createHeadCircle(player)
        end
        self:updatePlayerList()
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self:removeLabel(player)
        self:removeRay(player)
        self:removeBox(player)
        self:removeHealthBar(player)
        self:removeHeadCircle(player)
        if player == self.sitTarget then self:cancelLock() end
        if player == self.aimbotTarget then 
            self.aimbotTarget = nil
            self:updateTargetStatus()
        end
        self.raycastCache[player.UserId] = nil
        self:updatePlayerList()
    end)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= self.localPlayer then
            self:createLabel(player)
            self:createRay(player)
            self:createBox(player)
            self:createHealthBar(player)
            self:createHeadCircle(player)
        end
    end
    
    RunService.Heartbeat:Connect(function(dt)
        self:updateLabels(dt)
        self:updateCrosshairRays()
        self:updateBoxes()
        self:updateHealthBars()
        self:updateHeadCircles()
        self:updateFovCircle()
        
        local currentTime = tick()
        if currentTime - self.lastCleanup > 5 then
            self:cleanRaycastCache()
            self.lastCleanup = currentTime
        end
    end)
    
    game:GetService("Players").PlayerRemoving:Connect(function(player)
        if player == self.localPlayer then
            self:cleanup()
        end
    end)
end

-- ============================================
-- 清理资源
-- ============================================
function PlayerESP:cleanup()
    self:cancelLock()
    self:stopFly()
    self:stopAimbotHeartbeat()
    self:stopForceThirdPerson()
    
    if self.aimbotConnection then self.aimbotConnection:Disconnect() end
    if self.triggerbotConnection then self.triggerbotConnection:Disconnect() end
    if self.inputChangedConnection then self.inputChangedConnection:Disconnect() end
    if self.aimbotKeyBeganConnection then self.aimbotKeyBeganConnection:Disconnect() end
    if self.aimbotKeyEndedConnection then self.aimbotKeyEndedConnection:Disconnect() end
    if self.triggerbotBeganConn then self.triggerbotBeganConn:Disconnect() end
    if self.triggerbotEndedConn then self.triggerbotEndedConn:Disconnect() end
    
    self:releaseFire()
    
    for _, labelData in pairs(self.labels) do if labelData.drawing then labelData.drawing:Remove() end end
    for _, rayData in pairs(self.rays) do if rayData.drawing then rayData.drawing:Remove() end end
    for _, boxData in pairs(self.boxes) do
        if boxData.drawing then for _, line in pairs(boxData.drawing) do line:Remove() end end
    end
    for _, bar in pairs(self.healthBars) do
        bar.bg:Remove()
        bar.fill:Remove()
        bar.outline:Remove()
    end
    for _, circleData in pairs(self.headCircles) do
        circleData.drawing:Remove()
    end
    if self.fovCircle then self.fovCircle:Remove() end
    
    self:hideFlyJoystick()
    
    if self.screenGui then self.screenGui:Destroy() end
end

-- 启动
PlayerESP:init()

getgenv().PlayerESP = PlayerESP
