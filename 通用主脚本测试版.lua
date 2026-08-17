--[[
    ╔══════════════════════════════════════════════════════════════════╗
    ║                        QUANTUM UI LIBRARY                        ║
    ║                   Version 2.4.0 - Background Update             ║
    ║                         Created by log_quick                     ║
    ║                                                                  ║
    ║  Changelog v2.4.0:                                              ║
    ║  • FIXED auto-load config - now 100% working                    ║
    ║  • Added custom background image support                        ║
    ║  • Background transparency syncs with UI transparency           ║
    ╚══════════════════════════════════════════════════════════════════╝
--]]

local QuantumUI = {}
QuantumUI.__index = QuantumUI
QuantumUI.Version = "2.4.0"
QuantumUI.Author = "log_quick"
QuantumUI.ThemeColor = Color3.fromRGB(0, 200, 255)
QuantumUI.Transparency = 0.3
QuantumUI.RainbowEnabled = true
QuantumUI.RainbowSpeed = 1
QuantumUI.RainbowColors = {
    Color3.fromRGB(255, 0, 0),
    Color3.fromRGB(255, 127, 0),
    Color3.fromRGB(255, 255, 0),
    Color3.fromRGB(0, 255, 0),
    Color3.fromRGB(0, 0, 255),
    Color3.fromRGB(75, 0, 130),
    Color3.fromRGB(143, 0, 255)
}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local Sounds = {
    Click = "rbxassetid://6895079853",
    Hover = "rbxassetid://6895079709",
    Toggle = "rbxassetid://6895079565",
    Open = "rbxassetid://6895079422",
    Close = "rbxassetid://6895079278",
    ConfigLoad = "rbxassetid://6026984224",
    ConfigSave = "rbxassetid://6895079134",
    Startup = "rbxassetid://5853855460",
    Error = "rbxassetid://6895078990",
    Notification = "rbxassetid://4590657391",
    SpecialLoad = "rbxassetid://5856815743"
}

-- ═══════════════════════════════════════════════════════════════════
--                          UTILITY
-- ═══════════════════════════════════════════════════════════════════

local Utility = {}

function Utility.Create(className, properties, children)
    local instance = Instance.new(className)
    for prop, value in pairs(properties or {}) do
        if prop ~= "Parent" then
            pcall(function() instance[prop] = value end)
        end
    end
    for _, child in pairs(children or {}) do
        child.Parent = instance
    end
    if properties and properties.Parent then
        instance.Parent = properties.Parent
    end
    return instance
end

function Utility.Tween(object, properties, duration, style, direction)
    if not object then return end
    local tween = TweenService:Create(object, TweenInfo.new(duration or 0.3, style or Enum.EasingStyle.Quart, direction or Enum.EasingDirection.Out), properties)
    tween:Play()
    return tween
end

function Utility.PlaySound(soundId, volume)
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = volume or 0.5
        sound.Parent = SoundService
        sound:Play()
        sound.Ended:Connect(function() sound:Destroy() end)
    end)
end

function Utility.Ripple(parent, position, color)
    if not parent then return end
    local ripple = Utility.Create("Frame", {
        Parent = parent,
        BackgroundColor3 = color or Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        Position = UDim2.new(0, position.X - parent.AbsolutePosition.X, 0, position.Y - parent.AbsolutePosition.Y),
        Size = UDim2.new(0, 0, 0, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 100
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
    
    local maxSize = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 2
    Utility.Tween(ripple, {Size = UDim2.new(0, maxSize, 0, maxSize), BackgroundTransparency = 1}, 0.5)
    task.delay(0.5, function() if ripple then ripple:Destroy() end end)
end

function Utility.CreateGradient(colors, rotation)
    local gradient = Instance.new("UIGradient")
    if #colors >= 2 then
        local seq = {}
        for i, c in ipairs(colors) do
            table.insert(seq, ColorSequenceKeypoint.new((i-1)/(#colors-1), c))
        end
        gradient.Color = ColorSequence.new(seq)
    end
    gradient.Rotation = rotation or 0
    return gradient
end

function Utility.HSVToRGB(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    else r, g, b = v, p, q end
    return Color3.new(r, g, b)
end

function Utility.RGBToHSV(color)
    local r, g, b = color.R, color.G, color.B
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local h, s, v = 0, 0, max
    local d = max - min
    s = max == 0 and 0 or d / max
    if max ~= min then
        if max == r then h = (g - b) / d + (g < b and 6 or 0)
        elseif max == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h / 6
    end
    return h, s, v
end

function Utility.ScreenFlash(color, duration, intensity)
    pcall(function()
        local gui = Utility.Create("ScreenGui", {
            Parent = LocalPlayer:FindFirstChild("PlayerGui"),
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            DisplayOrder = 99999,
            IgnoreGuiInset = true
        })
        local flash = Utility.Create("Frame", {
            Parent = gui,
            BackgroundColor3 = color,
            BackgroundTransparency = 1 - (intensity or 0.4),
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0)
        })
        task.spawn(function()
            Utility.Tween(flash, {BackgroundTransparency = 0.3}, (duration or 0.5) * 0.2)
            task.wait((duration or 0.5) * 0.2)
            Utility.Tween(flash, {BackgroundTransparency = 1}, (duration or 0.5) * 0.8)
            task.wait((duration or 0.5) * 0.8)
            gui:Destroy()
        end)
    end)
end

-- ═══════════════════════════════════════════════════════════════════
--                          CONFIG SYSTEM (COMPLETELY REWRITTEN)
-- ═══════════════════════════════════════════════════════════════════

local ConfigSystem = {}

function ConfigSystem.Init()
    pcall(function()
        if not isfolder("QuantumUI") then makefolder("QuantumUI") end
        if not isfolder("QuantumUI/Configs") then makefolder("QuantumUI/Configs") end
    end)
end

function ConfigSystem.Save(name, data)
    ConfigSystem.Init()
    local success = pcall(function()
        writefile("QuantumUI/Configs/" .. name .. ".json", HttpService:JSONEncode(data))
    end)
    return success
end

function ConfigSystem.Load(name)
    local success, data = pcall(function()
        if isfile("QuantumUI/Configs/" .. name .. ".json") then
            return HttpService:JSONDecode(readfile("QuantumUI/Configs/" .. name .. ".json"))
        end
        return nil
    end)
    return success and data or nil
end

function ConfigSystem.Delete(name)
    pcall(function()
        if isfile("QuantumUI/Configs/" .. name .. ".json") then
            delfile("QuantumUI/Configs/" .. name .. ".json")
        end
    end)
end

function ConfigSystem.List()
    local list = {}
    pcall(function()
        if isfolder("QuantumUI/Configs") then
            for _, file in ipairs(listfiles("QuantumUI/Configs")) do
                local name = file:match("([^/\\]+)%.json$")
                if name then table.insert(list, name) end
            end
        end
    end)
    return list
end

function ConfigSystem.SaveAutoLoad(configName)
    ConfigSystem.Init()
    pcall(function()
        writefile("QuantumUI/autoload.txt", configName or "")
    end)
end

function ConfigSystem.GetAutoLoad()
    local success, name = pcall(function()
        if isfile("QuantumUI/autoload.txt") then
            return readfile("QuantumUI/autoload.txt")
        end
        return nil
    end)
    if success and name and name ~= "" then
        return name
    end
    return nil
end

function ConfigSystem.ClearAutoLoad()
    pcall(function()
        if isfile("QuantumUI/autoload.txt") then
            delfile("QuantumUI/autoload.txt")
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════
--                          RAINBOW HANDLER
-- ═══════════════════════════════════════════════════════════════════

local RainbowHandler = {Objects = {}, Connection = nil}

function RainbowHandler.Add(object)
    table.insert(RainbowHandler.Objects, object)
end

function RainbowHandler.Start()
    if RainbowHandler.Connection then return end
    local hue = 0
    RainbowHandler.Connection = RunService.RenderStepped:Connect(function(dt)
        if not QuantumUI.RainbowEnabled then return end
        hue = (hue + dt * QuantumUI.RainbowSpeed * 0.1) % 1
        for i = #RainbowHandler.Objects, 1, -1 do
            local obj = RainbowHandler.Objects[i]
            if obj and obj.Parent then
                local gradient = obj:FindFirstChildOfClass("UIGradient")
                if gradient then
                    local colors = {}
                    for j = 1, 7 do
                        colors[j] = ColorSequenceKeypoint.new((j-1)/6, Utility.HSVToRGB((hue + (j-1)/7) % 1, 1, 1))
                    end
                    gradient.Color = ColorSequence.new(colors)
                end
            else
                table.remove(RainbowHandler.Objects, i)
            end
        end
    end)
end

function RainbowHandler.Stop()
    if RainbowHandler.Connection then
        RainbowHandler.Connection:Disconnect()
        RainbowHandler.Connection = nil
    end
end

-- ═══════════════════════════════════════════════════════════════════
--                          MAIN LIBRARY
-- ═══════════════════════════════════════════════════════════════════

function QuantumUI.new(options)
    options = options or {}
    
    local self = setmetatable({}, QuantumUI)
    self.Title = options.Title or "Quantum UI"
    self.Subtitle = options.Subtitle or "by log_quick"
    self.ThemeColor = options.ThemeColor or Color3.fromRGB(0, 200, 255)
    self.Transparency = options.Transparency or 0.3
    self.Size = options.Size or (IsMobile and UDim2.new(0.95, 0, 0.85, 0) or UDim2.new(0, 600, 0, 450))
    self.BackgroundImage = options.BackgroundImage or nil  -- NEW: Custom background
    self.BackgroundTransparency = options.BackgroundTransparency or 0.5  -- NEW
    self.Tabs = {}
    self.Flags = {}
    self.Elements = {}
    self.ConfigData = {}
    self.Keybind = options.Keybind or Enum.KeyCode.RightControl
    self.Visible = true
    self.Minimized = false
    self.Maximized = false
    self.CanDrag = true
    self.SavedPosition = nil
    self.SavedSize = nil
    self.BackgroundLabel = nil  -- NEW: Reference to background
    
    QuantumUI.ThemeColor = self.ThemeColor
    QuantumUI.Transparency = self.Transparency
    
    -- Initialize config system
    ConfigSystem.Init()
    
    self:Initialize()
    
    return self
end

function QuantumUI:Initialize()
    self.ScreenGui = Utility.Create("ScreenGui", {
        Name = "QuantumUI_" .. HttpService:GenerateGUID(false),
        Parent = CoreGui,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
        DisplayOrder = 999
    })
    
    self:CreateLoadingScreen()
end

function QuantumUI:CreateLoadingScreen()
    local loadingFrame = Utility.Create("Frame", {
        Name = "LoadingScreen",
        Parent = self.ScreenGui,
        BackgroundColor3 = Color3.fromRGB(10, 10, 20),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 1000
    })
    
    for i = 1, 20 do
        Utility.Create("Frame", {
            Parent = loadingFrame,
            BackgroundColor3 = self.ThemeColor,
            BackgroundTransparency = 0.92,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, i/20 - 0.025, 0)
        })
    end
    for i = 1, 30 do
        Utility.Create("Frame", {
            Parent = loadingFrame,
            BackgroundColor3 = self.ThemeColor,
            BackgroundTransparency = 0.92,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 1, 1, 0),
            Position = UDim2.new(i/30 - 0.017, 0, 0, 0)
        })
    end
    
    local logoContainer = Utility.Create("Frame", {
        Parent = loadingFrame,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 180, 0, 180),
        Position = UDim2.new(0.5, 0, 0.35, 0),
        AnchorPoint = Vector2.new(0.5, 0.5)
    })
    
    local ring = Utility.Create("ImageLabel", {
        Parent = logoContainer,
        BackgroundTransparency = 1,
        Size = UDim2.new(1.2, 0, 1.2, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Image = "rbxassetid://6034281467",
        ImageColor3 = self.ThemeColor,
        ImageTransparency = 0.5
    })
    
    Utility.Create("TextLabel", {
        Parent = logoContainer,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.5, 0, 0.5, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Font = Enum.Font.GothamBold,
        Text = "Q",
        TextColor3 = self.ThemeColor,
        TextScaled = true
    })
    
    local title = Utility.Create("TextLabel", {
        Parent = loadingFrame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 50),
        Position = UDim2.new(0, 0, 0.55, 0),
        Font = Enum.Font.GothamBold,
        Text = "QUANTUM UI",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 32,
        TextTransparency = 1
    })
    
    local subtitle = Utility.Create("TextLabel", {
        Parent = loadingFrame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 25),
        Position = UDim2.new(0, 0, 0.55, 45),
        Font = Enum.Font.Gotham,
        Text = "INITIALIZING...",
        TextColor3 = self.ThemeColor,
        TextSize = 14,
        TextTransparency = 1
    })
    
    local loadingBarBg = Utility.Create("Frame", {
        Parent = loadingFrame,
        BackgroundColor3 = Color3.fromRGB(30, 30, 40),
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Size = UDim2.new(0.35, 0, 0, 6),
        Position = UDim2.new(0.325, 0, 0.7, 0)
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
    
    local loadingBar = Utility.Create("Frame", {
        Parent = loadingBarBg,
        BackgroundColor3 = self.ThemeColor,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0)
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
    
    local rotation = 0
    local rotateConn = RunService.RenderStepped:Connect(function(dt)
        rotation = rotation + dt * 50
        ring.Rotation = rotation
    end)
    
    Utility.PlaySound(Sounds.Startup, 0.6)
    
    task.spawn(function()
        task.wait(0.3)
        Utility.Tween(title, {TextTransparency = 0}, 0.4)
        Utility.Tween(subtitle, {TextTransparency = 0}, 0.4)
        
        local steps = {
            {0.2, "Loading components..."},
            {0.4, "Initializing theme..."},
            {0.6, "Setting up config..."},
            {0.8, "Preparing UI..."},
            {1.0, "Ready!"}
        }
        
        for _, step in ipairs(steps) do
            Utility.Tween(loadingBar, {Size = UDim2.new(step[1], 0, 1, 0)}, 0.25)
            subtitle.Text = step[2]
            Utility.PlaySound(Sounds.Click, 0.15)
            task.wait(0.25)
        end
        
        task.wait(0.3)
        Utility.Tween(loadingFrame, {BackgroundTransparency = 1}, 0.4)
        for _, child in ipairs(loadingFrame:GetDescendants()) do
            if child:IsA("TextLabel") then
                Utility.Tween(child, {TextTransparency = 1}, 0.4)
            elseif child:IsA("ImageLabel") then
                Utility.Tween(child, {ImageTransparency = 1}, 0.4)
            elseif child:IsA("Frame") then
                Utility.Tween(child, {BackgroundTransparency = 1}, 0.4)
            end
        end
        
        task.wait(0.4)
        rotateConn:Disconnect()
        loadingFrame:Destroy()
        
        self:CreateMainWindow()
    end)
end

function QuantumUI:CreateMainWindow()
    self.MainFrame = Utility.Create("Frame", {
        Name = "MainFrame",
        Parent = self.ScreenGui,
        BackgroundColor3 = Color3.fromRGB(15, 15, 25),
        BackgroundTransparency = self.Transparency,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ClipsDescendants = true
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 12)})})
    
    -- NEW: Custom Background Image
    if self.BackgroundImage then
        self.BackgroundLabel = Utility.Create("ImageLabel", {
            Name = "BackgroundImage",
            Parent = self.MainFrame,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            Image = self.BackgroundImage,
            ImageTransparency = self.BackgroundTransparency,
            ScaleType = Enum.ScaleType.Crop,
            ZIndex = 0
        })
    end
    
    -- Rainbow Border
    local borderStroke = Utility.Create("UIStroke", {
        Parent = self.MainFrame,
        Color = self.ThemeColor,
        Thickness = 2,
        Transparency = 0.3
    })
    local borderGradient = Utility.CreateGradient(QuantumUI.RainbowColors, 0)
    borderGradient.Parent = borderStroke
    RainbowHandler.Add(borderStroke)
    RainbowHandler.Start()
    
    -- Scanlines
    Utility.Create("ImageLabel", {
        Parent = self.MainFrame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Image = "rbxassetid://594768915",
        ImageTransparency = 0.96,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.new(0, 100, 0, 100),
        ZIndex = 2
    })
    
    -- Top Bar
    local topBar = Utility.Create("Frame", {
        Name = "TopBar",
        Parent = self.MainFrame,
        BackgroundColor3 = Color3.fromRGB(20, 20, 35),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 50),
        ZIndex = 10
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 12)})})
    
    Utility.Create("Frame", {
        Parent = topBar,
        BackgroundColor3 = Color3.fromRGB(20, 20, 35),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 1, -20),
        ZIndex = 9
    })
    
    Utility.Create("TextLabel", {
        Parent = topBar,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 40, 0, 40),
        Position = UDim2.new(0, 10, 0, 5),
        Font = Enum.Font.GothamBold,
        Text = "Q",
        TextColor3 = self.ThemeColor,
        TextSize = 28,
        ZIndex = 11
    })
    
    Utility.Create("TextLabel", {
        Parent = topBar,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 200, 0, 25),
        Position = UDim2.new(0, 55, 0, 5),
        Font = Enum.Font.GothamBold,
        Text = self.Title,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 11
    })
    
    Utility.Create("TextLabel", {
        Parent = topBar,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 200, 0, 15),
        Position = UDim2.new(0, 55, 0, 30),
        Font = Enum.Font.Gotham,
        Text = self.Subtitle,
        TextColor3 = Color3.fromRGB(150, 150, 150),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 11
    })
    
    local controls = Utility.Create("Frame", {
        Parent = topBar,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 90, 0, 30),
        Position = UDim2.new(1, -100, 0, 10),
        ZIndex = 11
    })
    
    local minimizeBtn = self:CreateControlButton(controls, "—", Color3.fromRGB(255, 190, 0), 0)
    local maximizeBtn = self:CreateControlButton(controls, "□", Color3.fromRGB(0, 200, 100), 30)
    local closeBtn = self:CreateControlButton(controls, "×", Color3.fromRGB(255, 80, 80), 60)
    
    local tabWidth = IsMobile and 50 or 150
    local tabContainer = Utility.Create("Frame", {
        Name = "TabContainer",
        Parent = self.MainFrame,
        BackgroundColor3 = Color3.fromRGB(18, 18, 30),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Size = UDim2.new(0, tabWidth, 1, -50),
        Position = UDim2.new(0, 0, 0, 50),
        ZIndex = 5
    })
    
    local tabList = Utility.Create("ScrollingFrame", {
        Name = "TabList",
        Parent = tabContainer,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, -10),
        Position = UDim2.new(0, 0, 0, 5),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = self.ThemeColor,
        ZIndex = 6
    }, {
        Utility.Create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)}),
        Utility.Create("UIPadding", {PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), PaddingTop = UDim.new(0, 5)})
    })
    
    local contentContainer = Utility.Create("Frame", {
        Name = "ContentContainer",
        Parent = self.MainFrame,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -tabWidth, 1, -50),
        Position = UDim2.new(0, tabWidth, 0, 50),
        ZIndex = 5
    })
    
    self.TopBar = topBar
    self.TabContainer = tabContainer
    self.TabList = tabList
    self.ContentContainer = contentContainer
    
    self:SetupDragging()
    self:SetupBorderDragging()
    self:SetupControlButtons(minimizeBtn, maximizeBtn, closeBtn)
    self:SetupKeybind()
    self:CreateFloatingButton()
    
    Utility.PlaySound(Sounds.Open, 0.5)
    Utility.Tween(self.MainFrame, {Size = self.Size}, 0.5, Enum.EasingStyle.Back)
    
    -- Create settings tab and handle auto-load
    task.spawn(function()
        task.wait(0.6)
        self:CreateSettingsTab()
        
        -- AUTO LOAD CONFIG (FIXED!)
        task.wait(0.5)
        self:TryAutoLoadConfig()
    end)
end

-- NEW: Set custom background
function QuantumUI:SetBackground(imageId, transparency)
    self.BackgroundImage = imageId
    self.BackgroundTransparency = transparency or self.Transparency
    
    if self.BackgroundLabel then
        self.BackgroundLabel.Image = imageId
        self.BackgroundLabel.ImageTransparency = self.BackgroundTransparency
    elseif self.MainFrame then
        self.BackgroundLabel = Utility.Create("ImageLabel", {
            Name = "BackgroundImage",
            Parent = self.MainFrame,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            Image = imageId,
            ImageTransparency = self.BackgroundTransparency,
            ScaleType = Enum.ScaleType.Crop,
            ZIndex = 0
        })
    end
end

-- NEW: Update background transparency
function QuantumUI:SetBackgroundTransparency(transparency)
    self.BackgroundTransparency = transparency
    if self.BackgroundLabel then
        Utility.Tween(self.BackgroundLabel, {ImageTransparency = transparency}, 0.3)
    end
end

-- NEW: Remove background
function QuantumUI:RemoveBackground()
    self.BackgroundImage = nil
    if self.BackgroundLabel then
        self.BackgroundLabel:Destroy()
        self.BackgroundLabel = nil
    end
end

-- FIXED: Auto load config function
function QuantumUI:TryAutoLoadConfig()
    local autoLoadName = ConfigSystem.GetAutoLoad()
    
    if autoLoadName and autoLoadName ~= "" then
        print("[QuantumUI] Auto loading config:", autoLoadName)
        
        local configData = ConfigSystem.Load(autoLoadName)
        
        if configData then
            -- Wait a bit for all elements to be ready
            task.wait(0.3)
            
            -- Apply the config
            self:ApplyConfig(configData)
            
            -- Visual feedback
            Utility.PlaySound(Sounds.SpecialLoad, 0.7)
            Utility.ScreenFlash(self.ThemeColor, 0.5, 0.4)
            
            self:Notify({
                Title = "✅ Auto Loaded!",
                Content = "Config '" .. autoLoadName .. "' loaded automatically.",
                Duration = 4,
                Type = "Success"
            })
            
            print("[QuantumUI] Auto load complete!")
        else
            print("[QuantumUI] Auto load config not found:", autoLoadName)
        end
    else
        print("[QuantumUI] No auto load config set")
    end
end

-- Apply config to all flagged elements
function QuantumUI:ApplyConfig(configData)
    if not configData then return end
    
    for flag, value in pairs(configData) do
        local element = self.Flags[flag]
        if element and element.Set then
            pcall(function()
                if type(value) == "table" then
                    if value._type == "Color3" then
                        element:Set(Color3.new(value.R, value.G, value.B))
                    elseif value._type == "KeyCode" then
                        element:Set(Enum.KeyCode[value.Name] or Enum.KeyCode.Unknown)
                    elseif value._type == "table" then
                        element:Set(value._data)
                    else
                        element:Set(value)
                    end
                else
                    element:Set(value)
                end
            end)
        end
    end
end

function QuantumUI:CreateControlButton(parent, text, color, xOffset)
    local btn = Utility.Create("TextButton", {
        Parent = parent,
        BackgroundColor3 = color,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 25, 0, 25),
        Position = UDim2.new(0, xOffset, 0, 0),
        Font = Enum.Font.GothamBold,
        Text = text,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = text == "×" and 20 or 14,
        ZIndex = 12
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 6)})})
    
    btn.MouseEnter:Connect(function()
        Utility.PlaySound(Sounds.Hover, 0.1)
        Utility.Tween(btn, {BackgroundTransparency = 0.2}, 0.2)
    end)
    btn.MouseLeave:Connect(function()
        Utility.Tween(btn, {BackgroundTransparency = 0.5}, 0.2)
    end)
    
    return btn
end

function QuantumUI:SetupBorderDragging()
    local edges = {
        {size = UDim2.new(0, 12, 1, 0), pos = UDim2.new(0, 0, 0, 0)},
        {size = UDim2.new(0, 12, 1, 0), pos = UDim2.new(1, -12, 0, 0)},
        {size = UDim2.new(1, 0, 0, 12), pos = UDim2.new(0, 0, 1, -12)},
    }
    
    for _, edge in ipairs(edges) do
        local edgeFrame = Utility.Create("Frame", {
            Parent = self.MainFrame,
            BackgroundTransparency = 1,
            Size = edge.size,
            Position = edge.pos,
            ZIndex = 50
        })
        
        local dragging, dragStart, startPos = false, nil, nil
        
        edgeFrame.InputBegan:Connect(function(input)
            if self.Maximized or not self.CanDrag then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = self.MainFrame.Position
            end
        end)
        
        edgeFrame.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                self.MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end
end

function QuantumUI:SetupDragging()
    local dragging, dragStart, startPos = false, nil, nil
    
    self.TopBar.InputBegan:Connect(function(input)
        if self.Maximized or not self.CanDrag then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = self.MainFrame.Position
        end
    end)
    
    self.TopBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            self.MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

function QuantumUI:SetupControlButtons(minimize, maximize, close)
    minimize.MouseButton1Click:Connect(function()
        Utility.PlaySound(Sounds.Click, 0.3)
        if self.MainFrame.Size.Y.Offset > 60 or self.MainFrame.Size.Y.Scale > 0.1 then
            self._savedSize = self.MainFrame.Size
            Utility.Tween(self.MainFrame, {Size = UDim2.new(self.MainFrame.Size.X.Scale, self.MainFrame.Size.X.Offset, 0, 50)}, 0.3)
        else
            Utility.Tween(self.MainFrame, {Size = self._savedSize or self.Size}, 0.3)
        end
    end)
    
    maximize.MouseButton1Click:Connect(function()
        Utility.PlaySound(Sounds.Click, 0.3)
        if self.Maximized then
            self.Maximized = false
            self.CanDrag = true
            Utility.Tween(self.MainFrame, {Size = self.SavedSize or self.Size, Position = self.SavedPosition or UDim2.new(0.5, 0, 0.5, 0)}, 0.3)
            maximize.Text = "□"
        else
            self.Maximized = true
            self.CanDrag = false
            self.SavedSize = self.MainFrame.Size
            self.SavedPosition = self.MainFrame.Position
            Utility.Tween(self.MainFrame, {Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.3)
            maximize.Text = "❐"
        end
    end)
    
    close.MouseButton1Click:Connect(function()
        Utility.PlaySound(Sounds.Close, 0.3)
        self:MinimizeToButton()
    end)
end

function QuantumUI:CreateFloatingButton()
    self.FloatingButton = Utility.Create("TextButton", {
        Parent = self.ScreenGui,
        BackgroundColor3 = self.ThemeColor,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Font = Enum.Font.GothamBold,
        Text = "Q",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 24,
        TextTransparency = 1,
        Visible = false,
        ZIndex = 1000
    }, {
        Utility.Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
        Utility.Create("UIStroke", {Color = Color3.fromRGB(255, 255, 255), Thickness = 2, Transparency = 0.5})
    })
    
    self.FloatingButton.MouseButton1Click:Connect(function()
        Utility.PlaySound(Sounds.Open, 0.5)
        self:RestoreFromMinimize()
    end)
    
    local dragging, dragStart, startPos = false, nil, nil
    self.FloatingButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = self.FloatingButton.Position
        end
    end)
    self.FloatingButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            self.FloatingButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

function QuantumUI:MinimizeToButton()
    if self.Minimized then return end
    self.Minimized = true
    
    local pos = self.MainFrame.AbsolutePosition
    local size = self.MainFrame.AbsoluteSize
    
    Utility.Tween(self.MainFrame, {Size = UDim2.new(0, 0, 0, 0)}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    task.wait(0.3)
    self.MainFrame.Visible = false
    
    self.FloatingButton.Position = UDim2.new(0, pos.X + size.X/2, 0, pos.Y + size.Y/2)
    self.FloatingButton.Size = UDim2.new(0, 0, 0, 0)
    self.FloatingButton.TextTransparency = 1
    self.FloatingButton.Visible = true
    Utility.Tween(self.FloatingButton, {Size = UDim2.new(0, 50, 0, 50), TextTransparency = 0}, 0.3, Enum.EasingStyle.Back)
end

function QuantumUI:RestoreFromMinimize()
    if not self.Minimized then return end
    self.Minimized = false
    
    Utility.Tween(self.FloatingButton, {Size = UDim2.new(0, 0, 0, 0), TextTransparency = 1}, 0.2)
    task.wait(0.2)
    self.FloatingButton.Visible = false
    
    self.MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.MainFrame.Size = UDim2.new(0, 0, 0, 0)
    self.MainFrame.Visible = true
    Utility.Tween(self.MainFrame, {Size = self.Size}, 0.4, Enum.EasingStyle.Back)
end

function QuantumUI:SetupKeybind()
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == self.Keybind then
            if self.Minimized then self:RestoreFromMinimize() else self:MinimizeToButton() end
        end
    end)
end

function QuantumUI:Destroy()
    RainbowHandler.Stop()
    if self.ScreenGui then self.ScreenGui:Destroy() end
end

function QuantumUI:UpdateContentSize(parent)
    if parent and parent:IsA("ScrollingFrame") then
        local layout = parent:FindFirstChildOfClass("UIListLayout")
        if layout then
            task.defer(function()
                parent.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
            end)
        end
    end
end

-- NEW: Set UI transparency (also updates background)
function QuantumUI:SetTransparency(transparency)
    self.Transparency = transparency
    QuantumUI.Transparency = transparency
    
    if self.MainFrame then
        Utility.Tween(self.MainFrame, {BackgroundTransparency = transparency}, 0.3)
    end
    
    -- Sync background transparency
    if self.BackgroundLabel then
        local bgTransparency = math.max(0, transparency - 0.2)  -- Background slightly more visible
        Utility.Tween(self.BackgroundLabel, {ImageTransparency = bgTransparency}, 0.3)
    end
end

-- ═══════════════════════════════════════════════════════════════════
--                          TAB SYSTEM
-- ═══════════════════════════════════════════════════════════════════

function QuantumUI:AddTab(options)
    options = options or {}
    local tabName = options.Name or "Tab"
    local tabIcon = options.Icon or "rbxassetid://6031280882"
    
    local tab = {Name = tabName, Elements = {}}
    
    local tabButton = Utility.Create("TextButton", {
        Parent = self.TabList,
        BackgroundColor3 = Color3.fromRGB(30, 30, 45),
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, IsMobile and 45 or 40),
        Font = Enum.Font.GothamSemibold,
        Text = IsMobile and "" or ("      " .. tabName),
        TextColor3 = Color3.fromRGB(200, 200, 200),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 8)})})
    
    local icon = Utility.Create("ImageLabel", {
        Parent = tabButton,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0, IsMobile and 12 or 10, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        Image = tabIcon,
        ImageColor3 = Color3.fromRGB(200, 200, 200),
        ZIndex = 8
    })
    
    local indicator = Utility.Create("Frame", {
        Parent = tabButton,
        BackgroundColor3 = self.ThemeColor,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 0.6, 0),
        Position = UDim2.new(0, 0, 0.2, 0),
        Visible = false,
        ZIndex = 8
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 2)})})
    
    local tabPage = Utility.Create("ScrollingFrame", {
        Parent = self.ContentContainer,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -20, 1, -20),
        Position = UDim2.new(0, 10, 0, 10),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = self.ThemeColor,
        Visible = false,
        ZIndex = 6
    }, {
        Utility.Create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10)}),
        Utility.Create("UIPadding", {PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5)})
    })
    
    tab.Button = tabButton
    tab.Page = tabPage
    tab.Indicator = indicator
    tab.Icon = icon
    
    tabButton.MouseButton1Click:Connect(function()
        Utility.PlaySound(Sounds.Click, 0.3)
        self:SelectTab(tab)
    end)
    
    tabButton.MouseEnter:Connect(function()
        Utility.PlaySound(Sounds.Hover, 0.1)
        Utility.Tween(tabButton, {BackgroundTransparency = 0.3}, 0.2)
    end)
    tabButton.MouseLeave:Connect(function()
        if self.SelectedTab ~= tab then
            Utility.Tween(tabButton, {BackgroundTransparency = 0.5}, 0.2)
        end
    end)
    
    table.insert(self.Tabs, tab)
    
    local layout = self.TabList:FindFirstChildOfClass("UIListLayout")
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        self.TabList.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)
    
    if #self.Tabs == 1 then self:SelectTab(tab) end
    
    local window = self
    function tab:AddSection(opts) return window:CreateSection(tabPage, opts) end
    function tab:AddButton(opts) return window:CreateButton(tabPage, opts) end
    function tab:AddToggle(opts) return window:CreateToggle(tabPage, opts) end
    function tab:AddSlider(opts) return window:CreateSlider(tabPage, opts) end
    function tab:AddDropdown(opts) return window:CreateDropdown(tabPage, opts) end
    function tab:AddTextbox(opts) return window:CreateTextbox(tabPage, opts) end
    function tab:AddColorPicker(opts) return window:CreateColorPicker(tabPage, opts) end
    function tab:AddKeybind(opts) return window:CreateKeybind(tabPage, opts) end
    function tab:AddLabel(opts) return window:CreateLabel(tabPage, opts) end
    function tab:AddParagraph(opts) return window:CreateParagraph(tabPage, opts) end
    
    return tab
end

function QuantumUI:SelectTab(tab)
    for _, t in ipairs(self.Tabs) do
        t.Page.Visible = false
        t.Indicator.Visible = false
        Utility.Tween(t.Button, {BackgroundTransparency = 0.5}, 0.2)
        Utility.Tween(t.Icon, {ImageColor3 = Color3.fromRGB(200, 200, 200)}, 0.2)
    end
    tab.Page.Visible = true
    tab.Indicator.Visible = true
    self.SelectedTab = tab
    Utility.Tween(tab.Button, {BackgroundTransparency = 0.2}, 0.2)
    Utility.Tween(tab.Icon, {ImageColor3 = self.ThemeColor}, 0.2)
end

-- ═══════════════════════════════════════════════════════════════════
--                          UI ELEMENTS
-- ═══════════════════════════════════════════════════════════════════

function QuantumUI:CreateSection(parent, options)
    local frame = Utility.Create("Frame", {
        Parent = parent,
        BackgroundColor3 = Color3.fromRGB(25, 25, 40),
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 35),
        ZIndex = 7
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 8)})})
    
    Utility.Create("TextLabel", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        Font = Enum.Font.GothamBold,
        Text = options.Name or "Section",
        TextColor3 = self.ThemeColor,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 8
    })
    
    self:UpdateContentSize(parent)
    return frame
end

function QuantumUI:CreateButton(parent, options)
    options = options or {}
    
    local frame = Utility.Create("Frame", {
        Parent = parent,
        BackgroundColor3 = Color3.fromRGB(30, 30, 45),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 45),
        ZIndex = 7
    }, {
        Utility.Create("UICorner", {CornerRadius = UDim.new(0, 8)}),
        Utility.Create("UIStroke", {Color = self.ThemeColor, Thickness = 1, Transparency = 0.7})
    })
    
    local btn = Utility.Create("TextButton", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Font = Enum.Font.GothamSemibold,
        Text = options.Name or "Button",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        ZIndex = 8
    })
    
    btn.MouseButton1Click:Connect(function()
        Utility.PlaySound(Sounds.Click, 0.3)
        Utility.Ripple(frame, Vector2.new(Mouse.X, Mouse.Y), self.ThemeColor)
        if options.Callback then options.Callback() end
    end)
    
    btn.MouseEnter:Connect(function()
        Utility.PlaySound(Sounds.Hover, 0.1)
        Utility.Tween(frame:FindFirstChildOfClass("UIStroke"), {Transparency = 0.3}, 0.2)
    end)
    btn.MouseLeave:Connect(function()
        Utility.Tween(frame:FindFirstChildOfClass("UIStroke"), {Transparency = 0.7}, 0.2)
    end)
    
    self:UpdateContentSize(parent)
    return {Frame = frame, SetText = function(_, t) btn.Text = t end}
end

function QuantumUI:CreateToggle(parent, options)
    options = options or {}
    local flag = options.Flag
    local toggled = options.Default or false
    
    local frame = Utility.Create("Frame", {
        Parent = parent,
        BackgroundColor3 = Color3.fromRGB(30, 30, 45),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 45),
        ZIndex = 7
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 8)})})
    
    Utility.Create("TextLabel", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -70, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        Font = Enum.Font.GothamSemibold,
        Text = options.Name or "Toggle",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 8
    })
    
    local toggleBg = Utility.Create("Frame", {
        Parent = frame,
        BackgroundColor3 = Color3.fromRGB(50, 50, 65),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 50, 0, 26),
        Position = UDim2.new(1, -60, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 8
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
    
    local toggleIndicator = Utility.Create("Frame", {
        Parent = toggleBg,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0, 3, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 9
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
    
    local function update(state, skip)
        toggled = state
        if toggled then
            Utility.Tween(toggleBg, {BackgroundColor3 = self.ThemeColor}, 0.2)
            Utility.Tween(toggleIndicator, {Position = UDim2.new(1, -23, 0.5, 0)}, 0.2)
        else
            Utility.Tween(toggleBg, {BackgroundColor3 = Color3.fromRGB(50, 50, 65)}, 0.2)
            Utility.Tween(toggleIndicator, {Position = UDim2.new(0, 3, 0.5, 0)}, 0.2)
        end
        if flag then self.ConfigData[flag] = toggled end
        if not skip and options.Callback then options.Callback(toggled) end
    end
    
    local btn = Utility.Create("TextButton", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Text = "",
        ZIndex = 10
    })
    
    btn.MouseButton1Click:Connect(function()
        Utility.PlaySound(Sounds.Toggle, 0.3)
        update(not toggled)
    end)
    
    update(toggled, true)
    self:UpdateContentSize(parent)
    
    local obj = {
        Frame = frame,
        Value = toggled,
        Set = function(_, s) update(s) end,
        Get = function() return toggled end
    }
    
    if flag then self.Flags[flag] = obj; self.Elements[flag] = obj end
    return obj
end

function QuantumUI:CreateSlider(parent, options)
    options = options or {}
    local flag = options.Flag
    local min, max = options.Min or 0, options.Max or 100
    local value = options.Default or min
    local increment = options.Increment or 1
    local suffix = options.Suffix or ""
    
    local frame = Utility.Create("Frame", {
        Parent = parent,
        BackgroundColor3 = Color3.fromRGB(30, 30, 45),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 55),
        ZIndex = 7
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 8)})})
    
    Utility.Create("TextLabel", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.6, 0, 0, 25),
        Position = UDim2.new(0, 15, 0, 5),
        Font = Enum.Font.GothamSemibold,
        Text = options.Name or "Slider",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 8
    })
    
    local valueLabel = Utility.Create("TextLabel", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.3, 0, 0, 25),
        Position = UDim2.new(0.7, -15, 0, 5),
        Font = Enum.Font.GothamSemibold,
        Text = tostring(value) .. suffix,
        TextColor3 = self.ThemeColor,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 8
    })
    
    local sliderBg = Utility.Create("Frame", {
        Parent = frame,
        BackgroundColor3 = Color3.fromRGB(50, 50, 65),
        BorderSizePixel = 0,
        Size = UDim2.new(1, -30, 0, 8),
        Position = UDim2.new(0, 15, 0, 35),
        ZIndex = 8
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
    
    local sliderFill = Utility.Create("Frame", {
        Parent = sliderBg,
        BackgroundColor3 = self.ThemeColor,
        BorderSizePixel = 0,
        Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
        ZIndex = 9
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
    
    local sliderKnob = Utility.Create("Frame", {
        Parent = sliderBg,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new((value - min) / (max - min), -8, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 10
    }, {
        Utility.Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
        Utility.Create("UIStroke", {Color = self.ThemeColor, Thickness = 2})
    })
    
    local function update(newVal, skip)
        value = math.clamp(newVal, min, max)
        value = math.floor(value / increment + 0.5) * increment
        local pct = (value - min) / (max - min)
        Utility.Tween(sliderFill, {Size = UDim2.new(pct, 0, 1, 0)}, 0.1)
        Utility.Tween(sliderKnob, {Position = UDim2.new(pct, -8, 0.5, 0)}, 0.1)
        valueLabel.Text = tostring(value) .. suffix
        if flag then self.ConfigData[flag] = value end
        if not skip and options.Callback then options.Callback(value) end
    end
    
    local dragging = false
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            local pct = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            update(min + (max - min) * pct)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local pct = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            update(min + (max - min) * pct)
        end
    end)
    
    update(value, true)
    self:UpdateContentSize(parent)
    
    local obj = {
        Frame = frame,
        Value = value,
        Set = function(_, v) update(v) end,
        Get = function() return value end
    }
    
    if flag then self.Flags[flag] = obj; self.Elements[flag] = obj end
    return obj
end

function QuantumUI:CreateDropdown(parent, options)
    options = options or {}
    local flag = options.Flag
    local items = options.Items or {}
    local multi = options.Multi or false
    local selected = multi and {} or (options.Default or items[1])
    local isOpen = false
    
    if multi and options.Default then
        for _, item in ipairs(type(options.Default) == "table" and options.Default or {options.Default}) do
            selected[item] = true
        end
    end
    
    local frame = Utility.Create("Frame", {
        Parent = parent,
        BackgroundColor3 = Color3.fromRGB(30, 30, 45),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 45),
        ClipsDescendants = true,
        ZIndex = 20
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 8)})})
    
    Utility.Create("TextLabel", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.5, 0, 0, 45),
        Position = UDim2.new(0, 15, 0, 0),
        Font = Enum.Font.GothamSemibold,
        Text = options.Name or "Dropdown",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 21
    })
    
    local selectedLabel = Utility.Create("TextLabel", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.4, -30, 0, 45),
        Position = UDim2.new(0.5, 0, 0, 0),
        Font = Enum.Font.Gotham,
        Text = "",
        TextColor3 = self.ThemeColor,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 21
    })
    
    local arrow = Utility.Create("TextLabel", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 20, 0, 45),
        Position = UDim2.new(1, -25, 0, 0),
        Font = Enum.Font.GothamBold,
        Text = "▼",
        TextColor3 = self.ThemeColor,
        TextSize = 12,
        ZIndex = 21
    })
    
    local itemContainer = Utility.Create("Frame", {
        Parent = frame,
        BackgroundColor3 = Color3.fromRGB(25, 25, 40),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -20, 0, 0),
        Position = UDim2.new(0, 10, 0, 50),
        ClipsDescendants = true,
        ZIndex = 21
    }, {
        Utility.Create("UICorner", {CornerRadius = UDim.new(0, 6)}),
        Utility.Create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2)}),
        Utility.Create("UIPadding", {PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5)})
    })
    
    local function updateLabel()
        if multi then
            local list = {}
            for item, v in pairs(selected) do if v then table.insert(list, item) end end
            selectedLabel.Text = #list > 0 and table.concat(list, ", ") or "Select..."
        else
            selectedLabel.Text = selected or "Select..."
        end
    end
    
    local function createItem(itemName)
        local itemBtn = Utility.Create("TextButton", {
            Name = itemName,
            Parent = itemContainer,
            BackgroundColor3 = Color3.fromRGB(40, 40, 55),
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 30),
            Font = Enum.Font.Gotham,
            Text = multi and ("  " .. itemName) or itemName,
            TextColor3 = Color3.fromRGB(200, 200, 200),
            TextSize = 12,
            TextXAlignment = multi and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
            ZIndex = 22
        }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 4)})})
        
        local check
        if multi then
            check = Utility.Create("TextLabel", {
                Parent = itemBtn,
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 20, 1, 0),
                Position = UDim2.new(1, -25, 0, 0),
                Font = Enum.Font.GothamBold,
                Text = selected[itemName] and "✓" or "",
                TextColor3 = self.ThemeColor,
                TextSize = 14,
                ZIndex = 23
            })
        end
        
        itemBtn.MouseButton1Click:Connect(function()
            Utility.PlaySound(Sounds.Click, 0.2)
            if multi then
                selected[itemName] = not selected[itemName]
                check.Text = selected[itemName] and "✓" or ""
                updateLabel()
                if options.Callback then options.Callback(selected) end
                if flag then self.ConfigData[flag] = {_data = selected, _type = "table"} end
            else
                selected = itemName
                updateLabel()
                isOpen = false
                Utility.Tween(frame, {Size = UDim2.new(1, 0, 0, 45)}, 0.3)
                Utility.Tween(arrow, {Rotation = 0}, 0.3)
                if options.Callback then options.Callback(selected) end
                if flag then self.ConfigData[flag] = selected end
            end
        end)
        
        itemBtn.MouseEnter:Connect(function() Utility.Tween(itemBtn, {BackgroundTransparency = 0.3}, 0.2) end)
        itemBtn.MouseLeave:Connect(function() Utility.Tween(itemBtn, {BackgroundTransparency = 0.5}, 0.2) end)
    end
    
    for _, item in ipairs(items) do createItem(item) end
    
    local toggle = Utility.Create("TextButton", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 45),
        Text = "",
        ZIndex = 25
    })
    
    toggle.MouseButton1Click:Connect(function()
        Utility.PlaySound(Sounds.Click, 0.3)
        isOpen = not isOpen
        if isOpen then
            local h = math.min(#items * 32 + 15, 200)
            Utility.Tween(frame, {Size = UDim2.new(1, 0, 0, 50 + h)}, 0.3)
            Utility.Tween(itemContainer, {Size = UDim2.new(1, -20, 0, h)}, 0.3)
            Utility.Tween(arrow, {Rotation = 180}, 0.3)
        else
            Utility.Tween(frame, {Size = UDim2.new(1, 0, 0, 45)}, 0.3)
            Utility.Tween(itemContainer, {Size = UDim2.new(1, -20, 0, 0)}, 0.3)
            Utility.Tween(arrow, {Rotation = 0}, 0.3)
        end
        self:UpdateContentSize(parent)
    end)
    
    updateLabel()
    self:UpdateContentSize(parent)
    
    local obj = {
        Frame = frame,
        Value = selected,
        Set = function(_, v)
            if multi then
                selected = {}
                for _, i in ipairs(type(v) == "table" and v or {v}) do selected[i] = true end
            else
                selected = v
            end
            updateLabel()
            if options.Callback then options.Callback(selected) end
        end,
        Get = function() return selected end,
        Refresh = function(_, newItems)
            items = newItems
            for _, c in ipairs(itemContainer:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
            for _, item in ipairs(items) do createItem(item) end
        end
    }
    
    if flag then self.Flags[flag] = obj; self.Elements[flag] = obj end
    return obj
end

function QuantumUI:CreateTextbox(parent, options)
    options = options or {}
    local flag = options.Flag
    
    local frame = Utility.Create("Frame", {
        Parent = parent,
        BackgroundColor3 = Color3.fromRGB(30, 30, 45),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 45),
        ZIndex = 7
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 8)})})
    
    Utility.Create("TextLabel", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.4, 0, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        Font = Enum.Font.GothamSemibold,
        Text = options.Name or "Textbox",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 8
    })
    
    local container = Utility.Create("Frame", {
        Parent = frame,
        BackgroundColor3 = Color3.fromRGB(40, 40, 55),
        BorderSizePixel = 0,
        Size = UDim2.new(0.55, -20, 0, 30),
        Position = UDim2.new(0.45, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 8
    }, {
        Utility.Create("UICorner", {CornerRadius = UDim.new(0, 6)}),
        Utility.Create("UIStroke", {Color = self.ThemeColor, Thickness = 1, Transparency = 0.7})
    })
    
    local textbox = Utility.Create("TextBox", {
        Parent = container,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        Font = Enum.Font.Gotham,
        Text = options.Default or "",
        PlaceholderText = options.Placeholder or "Enter text...",
        PlaceholderColor3 = Color3.fromRGB(150, 150, 150),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = options.ClearOnFocus or false,
        ZIndex = 9
    })
    
    textbox.Focused:Connect(function()
        Utility.PlaySound(Sounds.Click, 0.2)
        Utility.Tween(container:FindFirstChildOfClass("UIStroke"), {Transparency = 0.3}, 0.2)
    end)
    
    textbox.FocusLost:Connect(function(enter)
        Utility.Tween(container:FindFirstChildOfClass("UIStroke"), {Transparency = 0.7}, 0.2)
        if flag then self.ConfigData[flag] = textbox.Text end
        if options.Callback then options.Callback(textbox.Text, enter) end
    end)
    
    self:UpdateContentSize(parent)
    
    local obj = {
        Frame = frame,
        Value = textbox.Text,
        Set = function(_, t) textbox.Text = t; if flag then self.ConfigData[flag] = t end end,
        Get = function() return textbox.Text end
    }
    
    if flag then self.Flags[flag] = obj; self.Elements[flag] = obj end
    return obj
end

function QuantumUI:CreateColorPicker(parent, options)
    options = options or {}
    local flag = options.Flag
    local currentColor = options.Default or Color3.fromRGB(255, 255, 255)
    local isOpen = false
    local h, s, v = Utility.RGBToHSV(currentColor)
    local presets = options.Presets or {
        Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 127, 0), Color3.fromRGB(255, 255, 0),
        Color3.fromRGB(0, 255, 0), Color3.fromRGB(0, 255, 255), Color3.fromRGB(0, 0, 255),
        Color3.fromRGB(127, 0, 255), Color3.fromRGB(255, 0, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0)
    }
    
    local frame = Utility.Create("Frame", {
        Parent = parent,
        BackgroundColor3 = Color3.fromRGB(30, 30, 45),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 45),
        ClipsDescendants = true,
        ZIndex = 15
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 8)})})
    
    Utility.Create("TextLabel", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.6, 0, 0, 45),
        Position = UDim2.new(0, 15, 0, 0),
        Font = Enum.Font.GothamSemibold,
        Text = options.Name or "Color Picker",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 16
    })
    
    local preview = Utility.Create("Frame", {
        Parent = frame,
        BackgroundColor3 = currentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 35, 0, 25),
        Position = UDim2.new(1, -50, 0, 10),
        ZIndex = 16
    }, {
        Utility.Create("UICorner", {CornerRadius = UDim.new(0, 6)}),
        Utility.Create("UIStroke", {Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Transparency = 0.5})
    })
    
    local pickerContainer = Utility.Create("Frame", {
        Parent = frame,
        BackgroundColor3 = Color3.fromRGB(25, 25, 40),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -20, 0, 0),
        Position = UDim2.new(0, 10, 0, 50),
        ClipsDescendants = true,
        ZIndex = 16
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 8)})})
    
    local wheelSize = IsMobile and 140 or 170
    
    local wheelContainer = Utility.Create("Frame", {
        Parent = pickerContainer,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, wheelSize, 0, wheelSize),
        Position = UDim2.new(0, 15, 0, 15),
        ZIndex = 17
    })
    
    local colorWheel = Utility.Create("ImageLabel", {
        Parent = wheelContainer,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Image = "rbxassetid://6020299385",
        ZIndex = 18
    })
    
    local valueOverlay = Utility.Create("ImageLabel", {
        Parent = wheelContainer,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Image = "rbxassetid://6020299385",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = v,
        ZIndex = 19
    })
    
    local wheelCursor = Utility.Create("Frame", {
        Parent = wheelContainer,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 14, 0, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 20
    }, {
        Utility.Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
        Utility.Create("UIStroke", {Color = Color3.fromRGB(0, 0, 0), Thickness = 2})
    })
    
    local valueSlider = Utility.Create("Frame", {
        Parent = pickerContainer,
        BackgroundColor3 = Color3.fromRGB(50, 50, 65),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 18, 0, wheelSize),
        Position = UDim2.new(0, wheelSize + 25, 0, 15),
        ZIndex = 17
    }, {
        Utility.Create("UICorner", {CornerRadius = UDim.new(0, 6)}),
        Utility.Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
            }),
            Rotation = 90
        })
    })
    
    local valueKnob = Utility.Create("Frame", {
        Parent = valueSlider,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 4, 0, 8),
        Position = UDim2.new(0, -2, 1 - v, -4),
        ZIndex = 18
    }, {
        Utility.Create("UICorner", {CornerRadius = UDim.new(0, 3)}),
        Utility.Create("UIStroke", {Color = Color3.fromRGB(0, 0, 0), Thickness = 1})
    })
    
    local hexContainer = Utility.Create("Frame", {
        Parent = pickerContainer,
        BackgroundColor3 = Color3.fromRGB(40, 40, 55),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 90, 0, 28),
        Position = UDim2.new(0, 15, 0, wheelSize + 25),
        ZIndex = 17
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 6)})})
    
    Utility.Create("TextLabel", {
        Parent = hexContainer,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 20, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = "#",
        TextColor3 = self.ThemeColor,
        TextSize = 14,
        ZIndex = 18
    })
    
    local hexInput = Utility.Create("TextBox", {
        Parent = hexContainer,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -25, 1, 0),
        Position = UDim2.new(0, 20, 0, 0),
        Font = Enum.Font.Code,
        Text = string.format("%02X%02X%02X", currentColor.R * 255, currentColor.G * 255, currentColor.B * 255),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 11,
        ZIndex = 18
    })
    
    local presetContainer = Utility.Create("Frame", {
        Parent = pickerContainer,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -30, 0, 30),
        Position = UDim2.new(0, 15, 0, wheelSize + 60),
        ZIndex = 17
    }, {Utility.Create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5)})})
    
    local function updateColor(newColor, skip)
        currentColor = newColor
        h, s, v = Utility.RGBToHSV(newColor)
        preview.BackgroundColor3 = newColor
        valueOverlay.ImageTransparency = v
        local angle = h * math.pi * 2
        local radius = s * (wheelSize / 2 - 8)
        wheelCursor.Position = UDim2.new(0.5, math.cos(angle) * radius, 0.5, -math.sin(angle) * radius)
        valueKnob.Position = UDim2.new(0, -2, 1 - v, -4)
        hexInput.Text = string.format("%02X%02X%02X", newColor.R * 255, newColor.G * 255, newColor.B * 255)
        if flag then self.ConfigData[flag] = {R = newColor.R, G = newColor.G, B = newColor.B, _type = "Color3"} end
        if not skip and options.Callback then options.Callback(newColor) end
    end
    
    for _, preset in ipairs(presets) do
        local presetBtn = Utility.Create("TextButton", {
            Parent = presetContainer,
            BackgroundColor3 = preset,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 22, 0, 22),
            Text = "",
            ZIndex = 18
        }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 4)})})
        
        presetBtn.MouseButton1Click:Connect(function()
            Utility.PlaySound(Sounds.Click, 0.2)
            updateColor(preset)
        end)
    end
    
    local wheelDragging, valueDragging = false, false
    
    colorWheel.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            wheelDragging = true
        end
    end)
    colorWheel.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            wheelDragging = false
        end
    end)
    
    valueSlider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            valueDragging = true
            local pct = math.clamp((input.Position.Y - valueSlider.AbsolutePosition.Y) / valueSlider.AbsoluteSize.Y, 0, 1)
            v = 1 - pct
            updateColor(Utility.HSVToRGB(h, s, v))
        end
    end)
    valueSlider.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            valueDragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if wheelDragging then
                local centerX = wheelContainer.AbsolutePosition.X + wheelSize / 2
                local centerY = wheelContainer.AbsolutePosition.Y + wheelSize / 2
                local dx = input.Position.X - centerX
                local dy = input.Position.Y - centerY
                local dist = math.sqrt(dx * dx + dy * dy)
                local maxR = wheelSize / 2 - 5
                if dist <= maxR then
                    local angle = math.atan2(-dy, dx)
                    if angle < 0 then angle = angle + math.pi * 2 end
                    h = angle / (math.pi * 2)
                    s = math.min(dist / maxR, 1)
                    updateColor(Utility.HSVToRGB(h, s, v))
                end
            end
            if valueDragging then
                local pct = math.clamp((input.Position.Y - valueSlider.AbsolutePosition.Y) / valueSlider.AbsoluteSize.Y, 0, 1)
                v = 1 - pct
                updateColor(Utility.HSVToRGB(h, s, v))
            end
        end
    end)
    
    hexInput.FocusLost:Connect(function()
        local hex = hexInput.Text:gsub("#", "")
        local success, r, g, b = pcall(function()
            return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
        end)
        if success and r and g and b then updateColor(Color3.fromRGB(r, g, b)) end
    end)
    
    local toggle = Utility.Create("TextButton", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 45),
        Text = "",
        ZIndex = 20
    })
    
    toggle.MouseButton1Click:Connect(function()
        Utility.PlaySound(Sounds.Click, 0.3)
        isOpen = not isOpen
        if isOpen then
            local height = wheelSize + 105
            Utility.Tween(frame, {Size = UDim2.new(1, 0, 0, 50 + height)}, 0.3)
            Utility.Tween(pickerContainer, {Size = UDim2.new(1, -20, 0, height)}, 0.3)
        else
            Utility.Tween(frame, {Size = UDim2.new(1, 0, 0, 45)}, 0.3)
            Utility.Tween(pickerContainer, {Size = UDim2.new(1, -20, 0, 0)}, 0.3)
        end
        self:UpdateContentSize(parent)
    end)
    
    updateColor(currentColor, true)
    self:UpdateContentSize(parent)
    
    local obj = {
        Frame = frame,
        Value = currentColor,
        Set = function(_, c)
            if type(c) == "table" then c = Color3.new(c.R, c.G, c.B) end
            updateColor(c)
        end,
        Get = function() return currentColor end
    }
    
    if flag then self.Flags[flag] = obj; self.Elements[flag] = obj end
    return obj
end

function QuantumUI:CreateKeybind(parent, options)
    options = options or {}
    local flag = options.Flag
    local currentKey = options.Default or Enum.KeyCode.Unknown
    local listening = false
    
    local frame = Utility.Create("Frame", {
        Parent = parent,
        BackgroundColor3 = Color3.fromRGB(30, 30, 45),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 45),
        ZIndex = 7
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 8)})})
    
    Utility.Create("TextLabel", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.6, 0, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        Font = Enum.Font.GothamSemibold,
        Text = options.Name or "Keybind",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 8
    })
    
    local keyBtn = Utility.Create("TextButton", {
        Parent = frame,
        BackgroundColor3 = Color3.fromRGB(40, 40, 55),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 80, 0, 28),
        Position = UDim2.new(1, -95, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        Font = Enum.Font.GothamSemibold,
        Text = currentKey == Enum.KeyCode.Unknown and "None" or currentKey.Name,
        TextColor3 = self.ThemeColor,
        TextSize = 12,
        ZIndex = 8
    }, {
        Utility.Create("UICorner", {CornerRadius = UDim.new(0, 6)}),
        Utility.Create("UIStroke", {Color = self.ThemeColor, Thickness = 1, Transparency = 0.5})
    })
    
    keyBtn.MouseButton1Click:Connect(function()
        Utility.PlaySound(Sounds.Click, 0.3)
        listening = true
        keyBtn.Text = "..."
        Utility.Tween(keyBtn, {BackgroundColor3 = self.ThemeColor}, 0.2)
    end)
    
    UserInputService.InputBegan:Connect(function(input, processed)
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                listening = false
                Utility.Tween(keyBtn, {BackgroundColor3 = Color3.fromRGB(40, 40, 55)}, 0.2)
                if input.KeyCode == Enum.KeyCode.Escape then
                    currentKey = Enum.KeyCode.Unknown
                    keyBtn.Text = "None"
                else
                    currentKey = input.KeyCode
                    keyBtn.Text = input.KeyCode.Name
                end
                if flag then self.ConfigData[flag] = {Name = currentKey.Name, _type = "KeyCode"} end
                if options.ChangedCallback then options.ChangedCallback(currentKey) end
            end
        elseif not processed and input.KeyCode == currentKey then
            if options.Callback then options.Callback(currentKey) end
        end
    end)
    
    self:UpdateContentSize(parent)
    
    local obj = {
        Frame = frame,
        Value = currentKey,
        Set = function(_, k)
            if type(k) == "string" then k = Enum.KeyCode[k] or Enum.KeyCode.Unknown end
            currentKey = k
            keyBtn.Text = k == Enum.KeyCode.Unknown and "None" or k.Name
            if flag then self.ConfigData[flag] = {Name = k.Name, _type = "KeyCode"} end
        end,
        Get = function() return currentKey end
    }
    
    if flag then self.Flags[flag] = obj; self.Elements[flag] = obj end
    return obj
end

function QuantumUI:CreateLabel(parent, options)
    local frame = Utility.Create("Frame", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 25),
        ZIndex = 7
    })
    
    local label = Utility.Create("TextLabel", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        Font = Enum.Font.Gotham,
        Text = options.Text or "Label",
        TextColor3 = Color3.fromRGB(200, 200, 200),
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        ZIndex = 8
    })
    
    self:UpdateContentSize(parent)
    return {Frame = frame, SetText = function(_, t) label.Text = t end}
end

function QuantumUI:CreateParagraph(parent, options)
    options = options or {}
    
    local frame = Utility.Create("Frame", {
        Parent = parent,
        BackgroundColor3 = Color3.fromRGB(30, 30, 45),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 70),
        ZIndex = 7
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 8)})})
    
    local titleLabel = Utility.Create("TextLabel", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -30, 0, 25),
        Position = UDim2.new(0, 15, 0, 5),
        Font = Enum.Font.GothamBold,
        Text = options.Title or "Paragraph",
        TextColor3 = self.ThemeColor,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 8
    })
    
    local contentLabel = Utility.Create("TextLabel", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -30, 0, 35),
        Position = UDim2.new(0, 15, 0, 30),
        Font = Enum.Font.Gotham,
        Text = options.Content or "",
        TextColor3 = Color3.fromRGB(180, 180, 180),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        ZIndex = 8
    })
    
    local textSize = TextService:GetTextSize(options.Content or "", 12, Enum.Font.Gotham, Vector2.new(500, math.huge))
    frame.Size = UDim2.new(1, 0, 0, math.max(70, textSize.Y + 45))
    contentLabel.Size = UDim2.new(1, -30, 0, textSize.Y + 10)
    
    self:UpdateContentSize(parent)
    
    return {
        Frame = frame,
        SetTitle = function(_, t) titleLabel.Text = t end,
        SetContent = function(_, c)
            contentLabel.Text = c
            local ts = TextService:GetTextSize(c, 12, Enum.Font.Gotham, Vector2.new(500, math.huge))
            frame.Size = UDim2.new(1, 0, 0, math.max(70, ts.Y + 45))
            contentLabel.Size = UDim2.new(1, -30, 0, ts.Y + 10)
            self:UpdateContentSize(parent)
        end
    }
end

-- ═══════════════════════════════════════════════════════════════════
--                          SETTINGS TAB (FIXED AUTO LOAD)
-- ═══════════════════════════════════════════════════════════════════

function QuantumUI:CreateSettingsTab()
    local settingsTab = self:AddTab({Name = "Settings", Icon = "rbxassetid://6031280882"})
    
    -- ═══════════════════════════════════════
    -- CONFIG SECTION
    -- ═══════════════════════════════════════
    settingsTab:AddSection({Name = "📁 Config System"})
    
    local configName = ""
    settingsTab:AddTextbox({
        Name = "Config Name",
        Placeholder = "Enter config name...",
        Callback = function(text) configName = text end
    })
    
    settingsTab:AddButton({
        Name = "💾 Save Config",
        Callback = function()
            if configName == "" then
                self:Notify({Title = "Error", Content = "Please enter a config name!", Duration = 3, Type = "Error"})
                return
            end
            
            local saveData = {}
            for flag, element in pairs(self.Flags) do
                if element.Get then
                    local value = element:Get()
                    if typeof(value) == "Color3" then
                        saveData[flag] = {R = value.R, G = value.G, B = value.B, _type = "Color3"}
                    elseif typeof(value) == "EnumItem" then
                        saveData[flag] = {Name = value.Name, _type = "KeyCode"}
                    elseif type(value) == "table" then
                        saveData[flag] = {_data = value, _type = "table"}
                    else
                        saveData[flag] = value
                    end
                end
            end
            
            if ConfigSystem.Save(configName, saveData) then
                Utility.PlaySound(Sounds.ConfigSave, 0.5)
                Utility.ScreenFlash(Color3.fromRGB(0, 255, 100), 0.4, 0.3)
                self:RefreshConfigDropdowns()
                self:Notify({Title = "Saved!", Content = "Config '" .. configName .. "' saved!", Duration = 3, Type = "Success"})
            else
                self:Notify({Title = "Error", Content = "Failed to save config!", Duration = 3, Type = "Error"})
            end
        end
    })
    
    local configDropdown = settingsTab:AddDropdown({
        Name = "Select Config",
        Items = ConfigSystem.List(),
        Callback = function(selected) self.SelectedConfig = selected end
    })
    self.ConfigDropdown = configDropdown
    
    settingsTab:AddButton({
        Name = "📂 Load Config",
        Callback = function()
            if not self.SelectedConfig then
                self:Notify({Title = "Error", Content = "Please select a config!", Duration = 3, Type = "Error"})
                return
            end
            
            local data = ConfigSystem.Load(self.SelectedConfig)
            if data then
                self:ApplyConfig(data)
                Utility.PlaySound(Sounds.SpecialLoad, 0.7)
                Utility.ScreenFlash(self.ThemeColor, 0.5, 0.5)
                self:Notify({Title = "Loaded!", Content = "Config '" .. self.SelectedConfig .. "' loaded!", Duration = 3, Type = "Success"})
            else
                self:Notify({Title = "Error", Content = "Failed to load config!", Duration = 3, Type = "Error"})
            end
        end
    })
    
    settingsTab:AddButton({
        Name = "🗑️ Delete Config",
        Callback = function()
            if not self.SelectedConfig then
                self:Notify({Title = "Error", Content = "Please select a config!", Duration = 3, Type = "Error"})
                return
            end
            
            ConfigSystem.Delete(self.SelectedConfig)
            Utility.PlaySound(Sounds.Close, 0.4)
            self:RefreshConfigDropdowns()
            self.SelectedConfig = nil
            self:Notify({Title = "Deleted", Content = "Config deleted!", Duration = 3, Type = "Info"})
        end
    })
    
    -- ═══════════════════════════════════════
    -- AUTO LOAD SECTION (FIXED!)
    -- ═══════════════════════════════════════
    settingsTab:AddSection({Name = "🔄 Auto Load Config"})
    
    -- Show current auto load
    local currentAutoLoad = ConfigSystem.GetAutoLoad()
    if currentAutoLoad then
        settingsTab:AddLabel({Text = "📌 Current: " .. currentAutoLoad})
    else
        settingsTab:AddLabel({Text = "📌 No auto load config set"})
    end
    
    local autoLoadDropdown = settingsTab:AddDropdown({
        Name = "Set Auto Load",
        Items = ConfigSystem.List(),
        Callback = function(selected)
            ConfigSystem.SaveAutoLoad(selected)
            Utility.PlaySound(Sounds.ConfigSave, 0.4)
            self:Notify({
                Title = "✅ Auto Load Set!",
                Content = "'" .. selected .. "' will load on next startup.",
                Duration = 4,
                Type = "Success"
            })
        end
    })
    self.AutoLoadDropdown = autoLoadDropdown
    
    settingsTab:AddButton({
        Name = "❌ Clear Auto Load",
        Callback = function()
            ConfigSystem.ClearAutoLoad()
            Utility.PlaySound(Sounds.Close, 0.4)
            self:Notify({Title = "Cleared", Content = "Auto load disabled.", Duration = 3, Type = "Info"})
        end
    })
    
    -- ═══════════════════════════════════════
    -- UI SETTINGS SECTION
    -- ═══════════════════════════════════════
    settingsTab:AddSection({Name = "🎨 UI Settings"})
    
    settingsTab:AddColorPicker({
        Name = "Theme Color",
        Default = self.ThemeColor,
        Callback = function(color)
            self.ThemeColor = color
            QuantumUI.ThemeColor = color
        end
    })
    
    settingsTab:AddSlider({
        Name = "UI Transparency",
        Min = 0,
        Max = 90,
        Default = self.Transparency * 100,
        Suffix = "%",
        Callback = function(value)
            self:SetTransparency(value / 100)
        end
    })
    
    -- NEW: Background Settings
    settingsTab:AddSection({Name = "🖼️ Background"})
    
    local bgImageId = ""
    settingsTab:AddTextbox({
        Name = "Background Image ID",
        Placeholder = "rbxassetid://...",
        Callback = function(text) bgImageId = text end
    })
    
    settingsTab:AddButton({
        Name = "🖼️ Set Background",
        Callback = function()
            if bgImageId ~= "" then
                self:SetBackground(bgImageId)
                self:Notify({Title = "Background Set", Content = "Background image applied!", Duration = 3, Type = "Success"})
            end
        end
    })
    
    settingsTab:AddButton({
        Name = "❌ Remove Background",
        Callback = function()
            self:RemoveBackground()
            self:Notify({Title = "Background Removed", Content = "Background image removed.", Duration = 3, Type = "Info"})
        end
    })
    
    settingsTab:AddSlider({
        Name = "Background Transparency",
        Min = 0,
        Max = 100,
        Default = 50,
        Suffix = "%",
        Callback = function(value)
            self:SetBackgroundTransparency(value / 100)
        end
    })
    
    -- Rainbow Settings
    settingsTab:AddSection({Name = "🌈 Rainbow Border"})
    
    settingsTab:AddToggle({
        Name = "Rainbow Border",
        Default = QuantumUI.RainbowEnabled,
        Callback = function(state) QuantumUI.RainbowEnabled = state end
    })
    
    settingsTab:AddSlider({
        Name = "Rainbow Speed",
        Min = 0.1,
        Max = 5,
        Default = QuantumUI.RainbowSpeed,
        Increment = 0.1,
        Callback = function(value) QuantumUI.RainbowSpeed = value end
    })
    
    -- ═══════════════════════════════════════
    -- ACTIONS SECTION
    -- ═══════════════════════════════════════
    settingsTab:AddSection({Name = "🎮 Actions"})
    
    settingsTab:AddButton({
        Name = "🔄 Rejoin Server",
        Callback = function()
            Utility.PlaySound(Sounds.Click, 0.3)
            self:Notify({Title = "Rejoining...", Content = "Teleporting back...", Duration = 2, Type = "Info"})
            task.wait(0.5)
            game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
        end
    })
    
    settingsTab:AddButton({
        Name = "❌ Disable All Features",
        Callback = function()
            Utility.PlaySound(Sounds.Close, 0.4)
            local count = 0
            for _, element in pairs(self.Flags) do
                if element.Get and type(element:Get()) == "boolean" and element:Get() == true then
                    element:Set(false)
                    count = count + 1
                end
            end
            Utility.ScreenFlash(Color3.fromRGB(255, 0, 0), 0.3, 0.3)
            self:Notify({Title = "Disabled", Content = count .. " features disabled.", Duration = 3, Type = "Warning"})
        end
    })
    
    settingsTab:AddButton({
        Name = "💀 Destroy UI",
        Callback = function()
            Utility.PlaySound(Sounds.Close, 0.5)
            self:Notify({Title = "Goodbye!", Content = "Destroying UI...", Duration = 1, Type = "Info"})
            task.wait(1)
            self:Destroy()
        end
    })
    
    settingsTab:AddKeybind({
        Name = "Toggle UI Key",
        Default = self.Keybind,
        ChangedCallback = function(key) self.Keybind = key end
    })
    
    -- ═══════════════════════════════════════
    -- CREDITS SECTION
    -- ═══════════════════════════════════════
    settingsTab:AddSection({Name = "ℹ️ Credits"})
    
    settingsTab:AddParagraph({
        Title = "Quantum UI v" .. QuantumUI.Version,
        Content = "Sci-fi UI library with:\n• Rainbow borders\n• Config system with Auto Load\n• Custom background support\n• Mobile support"
    })
    
    settingsTab:AddLabel({Text = "Created by: log_quick"})
    settingsTab:AddLabel({Text = "GitHub: github.com/logquickly"})
end

function QuantumUI:RefreshConfigDropdowns()
    local configs = ConfigSystem.List()
    if self.ConfigDropdown then self.ConfigDropdown:Refresh(configs) end
    if self.AutoLoadDropdown then self.AutoLoadDropdown:Refresh(configs) end
end

-- ═══════════════════════════════════════════════════════════════════
--                          NOTIFICATION SYSTEM
-- ═══════════════════════════════════════════════════════════════════

function QuantumUI:Notify(options)
    options = options or {}
    local title = options.Title or "Notification"
    local content = options.Content or ""
    local duration = options.Duration or 3
    local nType = options.Type or "Info"
    
    local colors = {
        Info = Color3.fromRGB(0, 170, 255),
        Success = Color3.fromRGB(0, 255, 100),
        Warning = Color3.fromRGB(255, 200, 0),
        Error = Color3.fromRGB(255, 80, 80)
    }
    local color = colors[nType] or self.ThemeColor
    
    if not self.NotifContainer then
        self.NotifContainer = Utility.Create("Frame", {
            Parent = self.ScreenGui,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 300, 1, 0),
            Position = UDim2.new(1, -320, 0, 0),
            ZIndex = 100
        }, {
            Utility.Create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 10)}),
            Utility.Create("UIPadding", {PaddingBottom = UDim.new(0, 20)})
        })
    end
    
    local notif = Utility.Create("Frame", {
        Parent = self.NotifContainer,
        BackgroundColor3 = Color3.fromRGB(20, 20, 35),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        ZIndex = 101
    }, {
        Utility.Create("UICorner", {CornerRadius = UDim.new(0, 10)}),
        Utility.Create("UIStroke", {Color = color, Thickness = 2, Transparency = 0.3})
    })
    
    Utility.Create("Frame", {
        Parent = notif,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 4, 1, -10),
        Position = UDim2.new(0, 5, 0, 5),
        ZIndex = 102
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 2)})})
    
    Utility.Create("TextLabel", {
        Parent = notif,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -25, 0, 25),
        Position = UDim2.new(0, 15, 0, 5),
        Font = Enum.Font.GothamBold,
        Text = title,
        TextColor3 = color,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 102
    })
    
    Utility.Create("TextLabel", {
        Parent = notif,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -25, 0, 40),
        Position = UDim2.new(0, 15, 0, 30),
        Font = Enum.Font.Gotham,
        Text = content,
        TextColor3 = Color3.fromRGB(200, 200, 200),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        ZIndex = 102
    })
    
    local progress = Utility.Create("Frame", {
        Parent = notif,
        BackgroundColor3 = color,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 3),
        Position = UDim2.new(0, 0, 1, -3),
        ZIndex = 102
    }, {Utility.Create("UICorner", {CornerRadius = UDim.new(0, 2)})})
    
    local textSize = TextService:GetTextSize(content, 12, Enum.Font.Gotham, Vector2.new(270, math.huge))
    local height = math.max(70, textSize.Y + 45)
    
    Utility.PlaySound(Sounds.Notification, 0.4)
    Utility.Tween(notif, {Size = UDim2.new(1, 0, 0, height)}, 0.3, Enum.EasingStyle.Back)
    Utility.Tween(progress, {Size = UDim2.new(0, 0, 0, 3)}, duration, Enum.EasingStyle.Linear)
    
    task.delay(duration, function()
        Utility.Tween(notif, {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1}, 0.3)
        task.wait(0.3)
        if notif then notif:Destroy() end
    end)
end

-- ============================================
-- 以下内容来自 Enhanced_ESP_UI.lua (仅功能，不含UI)
-- ============================================

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
    aimbotRange = 100,
    aimbotFov = 360,
    aimbotStrength = 10,
    aimbotSmoothness = 5,
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
    aimbotGroundAimTime = 1.0,      -- 瞄准目标时间（默认1秒）
    aimbotGroundDuration = 0.5,     -- 瞄地面持续时间（0.5秒）
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
    
    -- 移动端自瞄快捷键
    mobileAimbotGui = nil,
    mobileAimbotBtn = nil,
    
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
    duration = duration or 0.15
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(button, tweenInfo, {BackgroundColor3 = targetColor})
    tween:Play()
end

function PlayerESP:updateButtonState(button, isOn, text, borderOnly)
    -- 更新按钮文字
    button.Text = text
    -- 更新文字颜色
    button.TextColor3 = isOn and Color3.fromRGB(228, 228, 231) or Color3.fromRGB(113, 113, 122)
    -- 更新边框颜色
    button.BorderColor3 = isOn and Color3.fromRGB(75, 63, 227) or Color3.fromRGB(60, 60, 65)
    -- 如果不只是边框变化，也更新背景
    if not borderOnly then
        button.BackgroundColor3 = isOn and Color3.fromRGB(39, 39, 42) or Color3.fromRGB(39, 39, 42)
    end
end

function PlayerESP:buttonClickEffect(button)
    -- 点击缩放效果
    local originalSize = button.Size
    local tweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    -- 缩小
    local shrinkTween = TweenService:Create(button, tweenInfo, {
        Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset - 4, originalSize.Y.Scale, originalSize.Y.Offset - 4)
    })
    shrinkTween:Play()
    
    -- 延迟后恢复
    task.delay(0.08, function()
        local expandTween = TweenService:Create(button, tweenInfo, {Size = originalSize})
        expandTween:Play()
    end)
end

function PlayerESP:tweenFrame(frame, targetSize, targetPosition, duration)
    duration = duration or 0.25
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local props = {}
    if targetSize then props.Size = targetSize end
    if targetPosition then props.Position = targetPosition end
    local tween = TweenService:Create(frame, tweenInfo, props)
    tween:Play()
    return tween
end

-- HSV 转 Color3，用于彩虹色效果
function PlayerESP:hsvToColor3(h, s, v)
    h = h % 1
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    local r, g, b
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    else r, g, b = v, p, q end
    return Color3.new(r, g, b)
end

-- ============================================
-- 状态栏更新
-- ============================================
function PlayerESP:updateStatus(text, color)
    if self.statusBar and self.statusBar.Text then
        self.statusBar.Text = text
        self.statusBar.TextColor3 = color or Color3.fromRGB(228, 228, 231)
    end
end

function PlayerESP:updateTargetStatus()
    local targetText = "无目标"
    local targetColor = Color3.fromRGB(113, 113, 122)
    
    if self.aimbotTarget then
        targetText = "锁定: " .. self.aimbotTarget.Name
        targetColor = Color3.fromRGB(75, 63, 227)
    end
    
    if self.targetStatusLabel then
        self.targetStatusLabel.Text = targetText
        self.targetStatusLabel.TextColor3 = targetColor
    end
end

-- ============================================
-- 颜色选择器
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
        -- 队伍区分：开启时跳过队友
        if not self:isEnemy(player) then
            bar.bg.Visible = false
            bar.fill.Visible = false
            bar.outline.Visible = false
            continue
        end
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
        -- [UI reference removed]
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
        -- 队伍区分：开启时跳过队友
        if not self:isEnemy(player) then
            circleData.drawing.Visible = false
            continue
        end
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
        -- [UI reference removed]
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
    
    -- 随机颜色变化：基于时间循环色相
    self.fovHue = (self.fovHue or 0) + 0.005
    if self.fovHue > 1 then self.fovHue = self.fovHue - 1 end
    self.fovCircle.Color = self:hsvToColor3(self.fovHue, 1, 1)
    
    local camera = workspace.CurrentCamera
    local viewportSize = camera.ViewportSize
    local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    local fovRadius = (viewportSize.Y / 2) * math.tan(math.rad(self.aimbotFov / 2))
    
    self.fovCircle.Position = center
    self.fovCircle.Radius = fovRadius
    self.fovCircle.Visible = true
end

function PlayerESP:toggleFovCircle()
    self.showFovCircle = not self.showFovCircle
    if self.fovCircle then
        self.fovCircle.Visible = self.showFovCircle and self.aimbotFov < 360
    end
        -- [UI reference removed]
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
        -- [UI reference removed]
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
        -- [UI reference removed]
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
    joystickKnob.BackgroundColor3 = Color3.fromRGB(100, 0, 180)
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
    upBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 130)
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
    downBtn.BackgroundColor3 = Color3.fromRGB(160, 0, 70)
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
-- 移动端自瞄快捷键按钮
-- ============================================
function PlayerESP:updateMobileAimbotButton()
    if not self.mobileAimbotBtn then return end
    
    if self.aimbotEnabled then
        self.mobileAimbotBtnText.TextColor3 = Color3.fromRGB(255, 255, 255)
        self.mobileAimbotBtn.BackgroundColor3 = Color3.fromRGB(75, 63, 227)
        self.mobileAimbotBtn.BackgroundTransparency = 0.2
        self.mobileAimbotBtn.BorderColor3 = Color3.fromRGB(139, 92, 246)
        self.mobileAimbotIndicator.BorderColor3 = Color3.fromRGB(75, 63, 227)
    else
        self.mobileAimbotBtnText.TextColor3 = Color3.fromRGB(161, 161, 170)
        self.mobileAimbotBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
        self.mobileAimbotBtn.BackgroundTransparency = 0.35
        self.mobileAimbotBtn.BorderColor3 = Color3.fromRGB(60, 60, 65)
        self.mobileAimbotIndicator.BorderColor3 = Color3.fromRGB(60, 60, 65)
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
            -- [UI reference removed]
        end
    else
        self:stopAimbotHeartbeat()
            -- [UI reference removed]
        end
    end
    self:updateMobileAimbotButton()
end

function PlayerESP:toggleTriggerbot()
    self.triggerbotEnabled = not self.triggerbotEnabled
    if self.triggerbotEnabled then
        if not self.triggerbotConnection then
            self.triggerbotConnection = RunService.Heartbeat:Connect(function()
                self:updateTriggerbot()
            end)
        end
            -- [UI reference removed]
        end
    else
        if self.triggerbotConnection then
            self.triggerbotConnection:Disconnect()
            self.triggerbotConnection = nil
        end
        self:releaseFire()
            -- [UI reference removed]
        end
    end
end

function PlayerESP:lockToPlayer(targetPlayer)
    -- targetPlayer: Player object to lock onto
    if not targetPlayer then return end
    if self.flyEnabled then return end
    if targetPlayer == self.localPlayer then return end
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
    -- 状态: 未锁定

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
        -- 队伍区分：开启时跳过队友
        if not self:isEnemy(player) then
            rayData.drawing.Visible = false
            continue
        end
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
    end
end

function PlayerESP:updateBoxes()
    if not self.localPlayer or not self.showBoxes then return end
    for player, boxData in pairs(self.boxes) do
        -- 队伍区分：开启时跳过队友
        if not self:isEnemy(player) then
            for _, line in pairs(boxData.drawing) do
                line.Visible = false
            end
            continue
        end
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
        -- 队伍区分：开启时跳过队友
        if not self:isEnemy(player) then
            labelData.drawing.Visible = false
            continue
        end
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
        -- [UI reference removed]
    end
end

function PlayerESP:toggleRays()
    self.showRays = not self.showRays
    for _, rayData in pairs(self.rays) do
        if rayData.drawing then rayData.drawing.Visible = self.showRays end
    end
        -- [UI reference removed]
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
        -- [UI reference removed]
    end
end

function PlayerESP:toggleWallCheck()
    self.wallCheck = not self.wallCheck
        -- [UI reference removed]
    end
end

function PlayerESP:toggleTeamCheck()
    self.teamCheck = not self.teamCheck
        -- [UI reference removed]
    end
end

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

function PlayerESP:init()
    self.localPlayer = Players.LocalPlayer
    
    self:createFovCircle()
    
    Players.PlayerAdded:Connect(function(player)
        if player ~= self.localPlayer then
            self:createLabel(player)
            self:createRay(player)
            self:createBox(player)
            self:createHealthBar(player)
            self:createHeadCircle(player)
        end
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
    
    if self.mobileAimbotGui then
        if self.mobileAimbotTouchStartedConn then self.mobileAimbotTouchStartedConn:Disconnect() end
        if self.mobileAimbotTouchMovedConn then self.mobileAimbotTouchMovedConn:Disconnect() end
        if self.mobileAimbotTouchEndedConn then self.mobileAimbotTouchEndedConn:Disconnect() end
        self.mobileAimbotGui:Destroy()
    end
    
    if self.screenGui then self.screenGui:Destroy() end
end

-- 启动
PlayerESP:init()

getgenv().PlayerESP = PlayerESP


return QuantumUI
