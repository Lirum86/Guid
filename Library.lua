-- ModernUI Library
-- Eine moderne GUI Library für Roblox
-- Version 1.0

local ModernUI = {}
ModernUI.__index = ModernUI

-- Services
local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')
local TextService = game:GetService('TextService')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')
local Stats = game:GetService('Stats')

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')

-- Library Funktionen
function ModernUI.new(options)
    local self = setmetatable({}, ModernUI)
    
    -- Standard Optionen
    local defaults = {
        title = "ModernUI",
        size = UDim2.new(0, 650, 0, 430),
        logo = 'rbxassetid://137631839282026',
        draggable = true,
        theme = {
            primary = Color3.fromRGB(110, 117, 243),
            background = Color3.fromRGB(19, 18, 21),
            surface = Color3.fromRGB(26, 25, 28),
            text = Color3.fromRGB(200, 200, 200),
            textDark = Color3.fromRGB(0, 0, 0)
        }
    }
    
    -- Merge Optionen
    self.options = defaults
    if options then
        for k, v in pairs(options) do
            self.options[k] = v
        end
    end
    
    self.tabs = {}
    self.tabButtons = {}
    self.contentFrames = {}
    self.currentTab = 1
    self._themeRefs = {
        sliderFills = {},
        checkboxUpdaters = {},
        dropdownOptionButtons = {},
        multiDropdownOptionButtons = {},
        licenseLabels = {},
    }
    
    -- Element Registry für Config System
    self._elementRegistry = {}
    self._elementCounter = 0
    
    self:_createMainFrame()
    self:_setupDragging()
    self:_setupToggleKeyListener()
    self:_createWatermark()
    
    -- Config Manager Integration
    self.configManager = nil
    self:_setupConfigManagerIntegration()
    
    return self
end

function ModernUI:_createMainFrame()
    -- Hauptcontainer
    self.screenGui = Instance.new('ScreenGui')
    self.screenGui.Name = 'ModernGUI'
    self.screenGui.Parent = playerGui
    self.screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Hauptframe
    self.mainFrame = Instance.new('Frame')
    self.mainFrame.Name = 'MainFrame'
    self.mainFrame.Size = self.options.size
    self.mainFrame.Position = UDim2.new(0.5, -self.options.size.X.Offset/2, 0.5, -self.options.size.Y.Offset/2)
    self.mainFrame.BackgroundColor3 = self.options.theme.background
    self.mainFrame.BorderSizePixel = 0
    self.mainFrame.Parent = self.screenGui

    local mainCorner = Instance.new('UICorner')
    mainCorner.CornerRadius = UDim.new(0, 8)
    mainCorner.Parent = self.mainFrame

    -- Header
    self.header = Instance.new('Frame')
    self.header.Name = 'Header'
    self.header.Size = UDim2.new(1, 0, 0, 50)
    self.header.Position = UDim2.new(0, 0, 0, 0)
    self.header.BackgroundColor3 = self.options.theme.surface
    self.header.BorderSizePixel = 0
    self.header.Parent = self.mainFrame

    local headerCorner = Instance.new('UICorner')
    headerCorner.CornerRadius = UDim.new(0, 8)
    headerCorner.Parent = self.header

    local headerBottomMask = Instance.new('Frame')
    headerBottomMask.Size = UDim2.new(1, 0, 0, 8)
    headerBottomMask.Position = UDim2.new(0, 0, 1, -8)
    headerBottomMask.BackgroundColor3 = self.options.theme.surface
    headerBottomMask.BorderSizePixel = 0
    headerBottomMask.Parent = self.header

    -- Logo
    local logoIcon = Instance.new('ImageLabel')
    logoIcon.Name = 'LogoIcon'
    logoIcon.Size = UDim2.new(0, 60, 0, 60)
    logoIcon.Position = UDim2.new(0, 5, 0.5, -28)
    logoIcon.BackgroundTransparency = 1
    logoIcon.Image = self.options.logo
    logoIcon.ScaleType = Enum.ScaleType.Fit
    logoIcon.Parent = self.header

    -- Title
    local titleLabel = Instance.new('TextLabel')
    titleLabel.Name = 'TitleLabel'
    titleLabel.Size = UDim2.new(1, -150, 1, 0)
    titleLabel.Position = UDim2.new(0, 70, 0, 0)
    titleLabel.BackgroundTransparency = 1
    -- Remove header title text per request
    titleLabel.Text = ""
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 16
    titleLabel.Parent = self.header

    -- Close Button
    local closeButton = Instance.new('TextButton')
    closeButton.Name = 'CloseButton'
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -45, 0.5, -15)
    closeButton.BackgroundTransparency = 1
    closeButton.Text = '×'
    closeButton.TextColor3 = self.options.theme.text
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = self.header

    closeButton.MouseButton1Click:Connect(function()
        self:Destroy()
    end)

    -- Tab Container
    self.tabContainer = Instance.new('Frame')
    self.tabContainer.Name = 'TabContainer'
    self.tabContainer.Size = UDim2.new(0, 120, 1, -130)
    self.tabContainer.Position = UDim2.new(0, 0, 0, 50)
    self.tabContainer.BackgroundColor3 = self.options.theme.background
    self.tabContainer.BorderSizePixel = 0
    self.tabContainer.Parent = self.mainFrame

    -- Content Container
    self.contentContainer = Instance.new('Frame')
    self.contentContainer.Name = 'ContentContainer'
    self.contentContainer.Size = UDim2.new(1, -120, 1, -62)
    self.contentContainer.Position = UDim2.new(0, 120, 0, 50)
    self.contentContainer.BackgroundColor3 = self.options.theme.background
    self.contentContainer.BorderSizePixel = 0
    self.contentContainer.Parent = self.mainFrame

    -- Player Info (unten links)
    self:_createPlayerInfo()
end

function ModernUI:_createPlayerInfo()
    local playerInfoContainer = Instance.new('Frame')
    playerInfoContainer.Name = 'PlayerInfoContainer'
    playerInfoContainer.Size = UDim2.new(0, 130, 0, 60)
    playerInfoContainer.Position = UDim2.new(0, 5, 1, -68)
    playerInfoContainer.BackgroundTransparency = 1
    playerInfoContainer.Parent = self.mainFrame

    local playerAvatar = Instance.new('ImageLabel')
    playerAvatar.Name = 'PlayerAvatar'
    playerAvatar.Size = UDim2.new(0, 40, 0, 40)
    playerAvatar.Position = UDim2.new(0, 10, 0.5, -20)
    playerAvatar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    playerAvatar.BorderSizePixel = 0
    playerAvatar.Image = 'https://www.roblox.com/headshot-thumbnail/image?userId=' .. player.UserId .. '&width=150&height=150&format=png'
    playerAvatar.Parent = playerInfoContainer

    local avatarCorner = Instance.new('UICorner')
    avatarCorner.CornerRadius = UDim.new(0, 6)
    avatarCorner.Parent = playerAvatar

    local playerNameLabel = Instance.new('TextLabel')
    playerNameLabel.Name = 'PlayerNameLabel'
    playerNameLabel.Size = UDim2.new(0, 70, 0, 20)
    playerNameLabel.Position = UDim2.new(0, 55, 0.5, -15)
    playerNameLabel.BackgroundTransparency = 1
    playerNameLabel.Text = player.Name
    playerNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    playerNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    playerNameLabel.Font = Enum.Font.GothamBold
    playerNameLabel.TextSize = 12
    playerNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    playerNameLabel.Parent = playerInfoContainer

    local licenseLabel = Instance.new('TextLabel')
    licenseLabel.Name = 'LicenseLabel'
    licenseLabel.Size = UDim2.new(0, 70, 0, 16)
    licenseLabel.Position = UDim2.new(0, 55, 0.5, 0)
    licenseLabel.BackgroundTransparency = 1
    licenseLabel.Text = 'Lifetime'
    licenseLabel.TextColor3 = self.options.theme.primary
    licenseLabel.TextXAlignment = Enum.TextXAlignment.Left
    licenseLabel.Font = Enum.Font.Gotham
    licenseLabel.TextSize = 10
    licenseLabel.Parent = playerInfoContainer
    table.insert(self._themeRefs.licenseLabels, licenseLabel)
end

function ModernUI:_setupDragging()
    if not self.options.draggable then return end
    
    local dragging = false
    local dragInput, mousePos, framePos

    self.header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            mousePos = input.Position
            framePos = self.mainFrame.Position
        end
    end)

    self.header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    self.header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            self.mainFrame.Position = UDim2.new(
                framePos.X.Scale,
                framePos.X.Offset + delta.X,
                framePos.Y.Scale,
                framePos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Toggle key handling
function ModernUI:_setupToggleKeyListener()
    -- default toggle key is RightShift
    self._toggleKeyCode = Enum.KeyCode.RightShift
    if self._toggleConn then
        self._toggleConn:Disconnect()
        self._toggleConn = nil
    end
    self._toggleConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if self._isCapturingKeybind then return end
        if self._ignoreNextToggleKeyCode and input.KeyCode == self._ignoreNextToggleKeyCode then
            -- ignore this one key press (from binding capture) and clear flag
            self._ignoreNextToggleKeyCode = nil
            return
        end
        if self._ignoreToggleUntil and os.clock() < self._ignoreToggleUntil then
            return
        end
        if input.KeyCode == self._toggleKeyCode then
            self:Toggle()
        end
    end)
end

-- Watermark (top-right, draggable when UI is open)
function ModernUI:_createWatermark()
    self._watermarkVisible = true
    self._watermarkFrame = Instance.new('Frame')
    self._watermarkFrame.Name = 'Watermark'
    self._watermarkFrame.BackgroundColor3 = self.options.theme.surface
    self._watermarkFrame.BorderSizePixel = 0
    self._watermarkFrame.Size = UDim2.new(0, 140, 0, 26)
    self._watermarkFrame.Position = UDim2.new(1, -190, 0, 8)
    self._watermarkFrame.AnchorPoint = Vector2.new(0, 0)
    self._watermarkFrame.Active = true
    self._watermarkFrame.Visible = true
    self._watermarkFrame.Parent = self.screenGui

    local wmCorner = Instance.new('UICorner')
    wmCorner.CornerRadius = UDim.new(0, 5)
    wmCorner.Parent = self._watermarkFrame

    local wmLabel = Instance.new('TextLabel')
    wmLabel.Name = 'Label'
    wmLabel.BackgroundTransparency = 1
    wmLabel.Size = UDim2.new(1, -12, 1, 0) -- 6px links + 6px rechts Padding
    wmLabel.Position = UDim2.new(0, 6, 0, 0)
    wmLabel.Font = Enum.Font.Gotham
    wmLabel.TextSize = 12
    wmLabel.TextXAlignment = Enum.TextXAlignment.Left
    wmLabel.TextColor3 = self.options.theme.text
    wmLabel.RichText = true
    wmLabel.Parent = self._watermarkFrame

    local function colorToHex(c)
        local r = math.clamp(math.floor(c.R * 255 + 0.5), 0, 255)
        local g = math.clamp(math.floor(c.G * 255 + 0.5), 0, 255)
        local b = math.clamp(math.floor(c.B * 255 + 0.5), 0, 255)
        return string.format("#%02X%02X%02X", r, g, b)
    end

    local function setWatermarkText(fps, pingMs)
        local lynix = string.format('<font color="%s">Lynix</font>', colorToHex(self.options.theme.primary))
        wmLabel.Text = string.format("%s | %d FPS | %d ms", lynix, fps, pingMs)
        local plainText = string.format("Lynix | %d FPS | %d ms", fps, pingMs)
        local bounds = TextService:GetTextSize(plainText, wmLabel.TextSize, wmLabel.Font, Vector2.new(10000, 26))
        self._watermarkFrame.Size = UDim2.new(0, bounds.X + 12, 0, 26)
    end

    -- Efficient update: one per frame for FPS, ping sampled when available
    if self._watermarkUpdateConn then self._watermarkUpdateConn:Disconnect() end
    self._watermarkUpdateConn = RunService.RenderStepped:Connect(function()
        -- RenderStepped yields in formatStats; avoid nested Wait by caching delta
        -- Instead compute FPS from passed step
    end)

    -- Re-implement with delta-based FPS
    local lastUpdate = os.clock()
    local accum = 0
    local frames = 0
    local pingMs = 0
    if self._watermarkUpdateConn then self._watermarkUpdateConn:Disconnect() end
    self._watermarkUpdateConn = RunService.RenderStepped:Connect(function(dt)
        frames = frames + 1
        accum = accum + dt
        if accum >= 0.25 then
            local fps = math.floor(frames / accum)
            -- Update ping occasionally
            local network = Stats and Stats.Network
            if network and network.ServerStatsItem and network.ServerStatsItem['Data Ping'] and network.ServerStatsItem['Data Ping'].GetValue then
                local ok, val = pcall(function()
                    return network.ServerStatsItem['Data Ping']:GetValue()
                end)
                if ok and typeof(val) == 'number' then
                    pingMs = math.floor(val)
                end
            end
            setWatermarkText(fps, pingMs)
            accum = 0
            frames = 0
        end
    end)

    -- Dragging only when main UI visible
    local dragging = false
    local dragInput, mousePos, framePos
    self._watermarkFrame.InputBegan:Connect(function(input)
        if not self.mainFrame.Visible then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            mousePos = input.Position
            framePos = self._watermarkFrame.Position
        end
    end)
    self._watermarkFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    self._watermarkFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            self._watermarkFrame.Position = UDim2.new(
                framePos.X.Scale,
                framePos.X.Offset + delta.X,
                framePos.Y.Scale,
                framePos.Y.Offset + delta.Y
            )
        end
    end)
end

function ModernUI:SetWatermarkVisible(visible)
    self._watermarkVisible = not not visible
    if self._watermarkFrame then
        self._watermarkFrame.Visible = self._watermarkVisible
    end
end

function ModernUI:SetToggleKey(key)
    -- Accept Enum.KeyCode or string name (e.g., "RightShift")
    local keyCode = nil
    if typeof(key) == "EnumItem" and tostring(key.EnumType) == "Enum.KeyCode" then
        keyCode = key
    elseif typeof(key) == "string" and Enum.KeyCode[key] then
        keyCode = Enum.KeyCode[key]
    end
    if keyCode then
        self._toggleKeyCode = keyCode
    end
end

function ModernUI:GetToggleKey()
    return self._toggleKeyCode
end

-- Tab Management
function ModernUI:CreateTab(name, icon)
    local tabIndex = #self.tabs + 1
    
    -- Tab Button
    local tabButton = Instance.new('TextButton')
    tabButton.Name = name .. 'Tab'
    tabButton.Size = UDim2.new(1, -15, 0, 35)
    tabButton.Position = UDim2.new(0, 10, 0, (tabIndex - 1) * 45 + 10)
    tabButton.BackgroundColor3 = self.options.theme.surface
    tabButton.BorderSizePixel = 0
    tabButton.Text = name
    tabButton.TextColor3 = self.options.theme.text
    tabButton.TextSize = 14
    tabButton.Font = Enum.Font.Gotham
    tabButton.Parent = self.tabContainer

    local tabCorner = Instance.new('UICorner')
    tabCorner.CornerRadius = UDim.new(0, 4)
    tabCorner.Parent = tabButton

    table.insert(self.tabButtons, tabButton)

    -- Content Frame
    local contentFrame = Instance.new('ScrollingFrame')
    contentFrame.Name = name .. 'Content'
    contentFrame.Size = UDim2.new(1, -20, 1, -20)
    contentFrame.Position = UDim2.new(0, 10, 0, 10)
    contentFrame.BackgroundTransparency = 1
    contentFrame.BorderSizePixel = 0
    contentFrame.ScrollBarThickness = 6
    contentFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentFrame.Visible = (tabIndex == 1)
    contentFrame.Parent = self.contentContainer

    local contentPadding = Instance.new('UIPadding')
    contentPadding.PaddingLeft = UDim.new(0, 0)
    contentPadding.Parent = contentFrame

    table.insert(self.contentFrames, contentFrame)

    -- Create two layout columns inside the content frame for auto-stacking windows
    self._columnsByContentFrame = self._columnsByContentFrame or {}
    local columnsContainer = Instance.new('Frame')
    columnsContainer.Name = 'ColumnsContainer'
    columnsContainer.BackgroundTransparency = 1
    columnsContainer.Size = UDim2.new(1, -16, 0, 0)
    columnsContainer.Position = UDim2.new(0, 6, 0, 12)
    columnsContainer.AutomaticSize = Enum.AutomaticSize.Y
    columnsContainer.Parent = contentFrame

    -- Use constraints and padding to avoid overlaps and keep gutters
    local columnsPadding = Instance.new('UIPadding')
    columnsPadding.PaddingRight = UDim.new(0, 0)
    columnsPadding.PaddingLeft = UDim.new(0, 0)
    columnsPadding.PaddingTop = UDim.new(0, 0)
    columnsPadding.PaddingBottom = UDim.new(0, 0)
    columnsPadding.Parent = columnsContainer

    local col1 = Instance.new('Frame')
    col1.Name = 'Column1'
    col1.BackgroundTransparency = 1
    col1.Size = UDim2.new(0.5, -10, 0, 0)
    col1.Position = UDim2.new(0, 0, 0, 0)
    col1.ClipsDescendants = true
    col1.AutomaticSize = Enum.AutomaticSize.Y
    col1.Parent = columnsContainer

    local col2 = Instance.new('Frame')
    col2.Name = 'Column2'
    col2.BackgroundTransparency = 1
    col2.Size = UDim2.new(0.5, -10, 0, 0)
    col2.Position = UDim2.new(1, 0, 0, 0)
    col2.AnchorPoint = Vector2.new(1, 0)
    col2.ClipsDescendants = true
    col2.AutomaticSize = Enum.AutomaticSize.Y
    col2.Parent = columnsContainer

    local list1 = Instance.new('UIListLayout')
    list1.Padding = UDim.new(0, 12)
    list1.FillDirection = Enum.FillDirection.Vertical
    list1.SortOrder = Enum.SortOrder.LayoutOrder
    list1.Parent = col1

    local list2 = Instance.new('UIListLayout')
    list2.Padding = UDim.new(0, 12)
    list2.FillDirection = Enum.FillDirection.Vertical
    list2.SortOrder = Enum.SortOrder.LayoutOrder
    list2.Parent = col2

    -- Prevent overlap: give windows full width inside column and respect padding via layout
    local function applyColumnChildProps(column)
        local function apply(child)
            if child:IsA('Frame') then
                child.Size = UDim2.new(1, 0, 0, child.AbsoluteSize.Y)
                child.AutomaticSize = Enum.AutomaticSize.Y
                child.ClipsDescendants = false
            end
        end
        for _, c in ipairs(column:GetChildren()) do apply(c) end
        column.ChildAdded:Connect(apply)
    end
    applyColumnChildProps(col1)
    applyColumnChildProps(col2)

    self._columnsByContentFrame[contentFrame] = { col1 = col1, col2 = col2 }

    -- Keep the scrollable area sized to tallest column
    local function updateCanvasSize()
        local h1 = list1.AbsoluteContentSize.Y
        local h2 = list2.AbsoluteContentSize.Y
        local tallest = math.max(h1, h2)
        contentFrame.CanvasSize = UDim2.new(0, 0, 0, tallest + 40)
    end
    list1:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateCanvasSize)
    list2:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateCanvasSize)
    columnsContainer:GetPropertyChangedSignal('AbsoluteSize'):Connect(updateCanvasSize)
    updateCanvasSize()

    -- Tab Click Event
    tabButton.MouseButton1Click:Connect(function()
        self:SwitchTab(tabIndex)
    end)

    -- Initialer Tab
    if tabIndex == 1 then
        self:SwitchTab(1)
    end

    -- Return Tab Object
    local tab = {
        frame = contentFrame,
        index = tabIndex,
        windows = {},
        library = self
    }
    
    function tab:CreateWindow(title, size, position)
        return self.library:_createWindow(self.frame, title, size, position)
    end
    
    table.insert(self.tabs, tab)

    -- No auto-injection here; keep library generic

    return tab
end

function ModernUI:SwitchTab(tabIndex)
    for i, button in ipairs(self.tabButtons) do
        local isActive = (i == tabIndex)
        local bgColor = isActive and self.options.theme.primary or self.options.theme.surface
        local textColor = isActive and self.options.theme.textDark or self.options.theme.text
        
        local tween = TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            BackgroundColor3 = bgColor,
            TextColor3 = textColor
        })
        tween:Play()
        
        self.contentFrames[i].Visible = isActive
    end
    
    self.currentTab = tabIndex
end

-- Apply theme to tab buttons without tween (for real-time theme updates)
function ModernUI:_applyTabThemeColors()
    for i, button in ipairs(self.tabButtons) do
        local isActive = (i == self.currentTab)
        button.BackgroundColor3 = isActive and self.options.theme.primary or self.options.theme.surface
        button.TextColor3 = isActive and self.options.theme.textDark or self.options.theme.text
    end
end

-- Window Creation
function ModernUI:_createWindow(parent, title, size, position)
    -- size and position can be hinted; auto-layout will place and size
    size = size or UDim2.new(0, 0, 0, 0)
    position = position or UDim2.new(0, 0, 0, 0)
    
    local window = Instance.new('Frame')
    window.Name = title .. 'Window'
    window.BackgroundColor3 = Color3.fromRGB(21, 21, 23)
    window.BorderSizePixel = 0
    window.AutomaticSize = Enum.AutomaticSize.Y
    window.Size = UDim2.new(1, 0, 0, 0)
    window.Parent = parent

    local windowCorner = Instance.new('UICorner')
    windowCorner.CornerRadius = UDim.new(0, 6)
    windowCorner.Parent = window

    -- Header
    local windowHeader = Instance.new('Frame')
    windowHeader.Name = 'Header'
    windowHeader.Size = UDim2.new(1, 0, 0, 30)
    windowHeader.BackgroundColor3 = self.options.theme.surface
    windowHeader.BorderSizePixel = 0
    windowHeader.Parent = window

    local headerCorner = Instance.new('UICorner')
    headerCorner.CornerRadius = UDim.new(0, 6)
    headerCorner.Parent = windowHeader

    local headerMask = Instance.new('Frame')
    headerMask.Size = UDim2.new(1, 0, 0, 6)
    headerMask.Position = UDim2.new(0, 0, 1, -6)
    headerMask.BackgroundColor3 = self.options.theme.surface
    headerMask.BorderSizePixel = 0
    headerMask.Parent = windowHeader

    -- Title
    local windowTitle = Instance.new('TextLabel')
    windowTitle.Name = 'Title'
    windowTitle.Size = UDim2.new(1, -20, 1, 0)
    windowTitle.Position = UDim2.new(0, 10, 0, 0)
    windowTitle.BackgroundTransparency = 1
    windowTitle.Text = title
    windowTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    windowTitle.TextXAlignment = Enum.TextXAlignment.Left
    windowTitle.TextYAlignment = Enum.TextYAlignment.Center
    windowTitle.Font = Enum.Font.GothamBold
    windowTitle.TextSize = 14
    windowTitle.Parent = windowHeader

    -- Separator
    local separator = Instance.new('Frame')
    separator.Name = 'Separator'
    separator.Size = UDim2.new(1, 0, 0, 1)
    separator.Position = UDim2.new(0, 0, 0, 30)
    separator.BackgroundColor3 = Color3.fromRGB(30, 30, 32)
    separator.BorderSizePixel = 0
    separator.Parent = window

    -- Content Area
    local contentArea = Instance.new('Frame')
    contentArea.Name = 'ContentArea'
    contentArea.AutomaticSize = Enum.AutomaticSize.Y
    contentArea.Size = UDim2.new(1, -20, 0, 0)
    contentArea.Position = UDim2.new(0, 10, 0, 35)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = window

    -- Auto-stack elements inside window with spacing
    local contentList = Instance.new('UIListLayout')
    contentList.Padding = UDim.new(0, 10)
    contentList.FillDirection = Enum.FillDirection.Vertical
    contentList.SortOrder = Enum.SortOrder.LayoutOrder
    contentList.Parent = contentArea
    
    -- ensure bottom spacing at end of window
    local contentPadding = Instance.new('UIPadding')
    contentPadding.PaddingBottom = UDim.new(0, 10)
    contentPadding.Parent = contentArea

    -- Return Window Object mit UI Elementen
    local windowObj = {
        frame = window,
        content = contentArea,
        library = self,
        _nextY = 0,
        _column = 1, -- default column index (1 or 2)
        _autoSize = true
    }
    
    -- UI Element Creation Methods
    function windowObj:CreateCheckbox(text, default, callback)
        return self.library:_createCheckbox(self, text, default, callback)
    end
    
    function windowObj:CreateSlider(text, min, max, default, callback)
        return self.library:_createSlider(self, text, min, max, default, callback)
    end
    
    function windowObj:CreateDropdown(text, options, default, callback)
        return self.library:_createDropdown(self, text, options, default, callback)
    end
    
    function windowObj:CreateMultiDropdown(text, options, defaults, callback)
        return self.library:_createMultiDropdown(self, text, options, defaults, callback)
    end
    
    function windowObj:CreateColorPicker(text, default, callback)
        return self.library:_createColorPicker(self, text, default, callback)
    end
    
    function windowObj:CreateButton(text, callback)
        return self.library:_createButton(self, text, callback)
    end
    
    function windowObj:CreateTextBox(text, placeholder, callback)
        return self.library:_createTextBox(self, text, placeholder, callback)
    end
    
    function windowObj:CreateKeybind(text, default, callback)
        return self.library:_createKeybind(self, text, default, callback)
    end

    -- Place window into a column if parent is a tab content frame
    local columns = self._columnsByContentFrame[parent]
    if columns then
        local targetCol = (columns.col1.AbsoluteSize.Y <= columns.col2.AbsoluteSize.Y) and columns.col1 or columns.col2
        window.Parent = targetCol
    end

    return windowObj
end

-- UI Elements
function ModernUI:_createCheckbox(window, text, default, callback)
    default = default or false
    callback = callback or function() end
    
    local container = Instance.new('Frame')
    container.Name = 'CheckboxContainer'
    container.Size = UDim2.new(1, 0, 0, 25)
    container.Position = UDim2.new(0, 0, 0, window._nextY)
    container.BackgroundTransparency = 1
    container.Parent = window.content
    
    window._nextY = window._nextY + 30

    local checkbox = Instance.new('ImageButton')
    checkbox.Name = 'Checkbox'
    checkbox.Size = UDim2.new(0, 18, 0, 18)
    checkbox.Position = UDim2.new(0, 0, 0.5, -9)
    checkbox.BackgroundColor3 = self.options.theme.surface
    checkbox.BorderSizePixel = 0
    checkbox.Image = ''
    checkbox.Parent = container

    local checkIcon = Instance.new('ImageLabel')
    checkIcon.Name = 'CheckIcon'
    checkIcon.Size = UDim2.new(0, 12, 0, 12)
    checkIcon.Position = UDim2.new(0.5, -6, 0.5, -5)
    checkIcon.BackgroundTransparency = 1
    checkIcon.Image = ''
    checkIcon.ImageColor3 = Color3.fromRGB(0, 0, 0)
    checkIcon.Parent = checkbox

    local checkboxCorner = Instance.new('UICorner')
    checkboxCorner.CornerRadius = UDim.new(0, 3)
    checkboxCorner.Parent = checkbox

    local label = Instance.new('TextLabel')
    label.Name = 'Label'
    label.Size = UDim2.new(1, -25, 1, 0)
    label.Position = UDim2.new(0, 25, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = self.options.theme.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.Parent = container

    local enabled = default

    local function updateCheckbox()
        if enabled then
            checkbox.BackgroundColor3 = self.options.theme.primary
            checkIcon.Image = 'rbxassetid://98902844787044'
        else
            checkbox.BackgroundColor3 = self.options.theme.surface
            checkIcon.Image = ''
        end
    end

    checkbox.MouseButton1Click:Connect(function()
        enabled = not enabled
        updateCheckbox()
        callback(enabled)
    end)

    updateCheckbox()

    -- Register theme updater to refresh colors in real time when theme changes
    table.insert(self._themeRefs.checkboxUpdaters, function()
        updateCheckbox()
    end)

    local api = {
        SetValue = function(value)
            enabled = value
            updateCheckbox()
        end,
        GetValue = function()
            return enabled
        end
    }
    
    -- Element für Config System registrieren
    if window and window.library then
        local tabName = nil
        local windowName = nil
        
        -- Tab und Window Namen aus dem Parent-Frame ermitteln
        for _, tab in ipairs(window.library.tabs) do
            if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                tabName = tab.frame.Name:gsub("Content", "")
                break
            end
        end
        
        if window.frame and window.frame.Name then
            windowName = window.frame.Name:gsub("Window", "")
        end
        
        window.library:_registerElement("checkbox", tabName, windowName, text, api)
    end
    
    return api
end

function ModernUI:_createMultiDropdown(window, text, options, defaults, callback)
    options = options or {}
    defaults = defaults or {}
    callback = callback or function() end

    local container = Instance.new('Frame')
    container.Name = 'MultiDropdownContainer'
    container.Size = UDim2.new(1, 0, 0, 50)
    container.Position = UDim2.new(0, 0, 0, window._nextY)
    container.BackgroundTransparency = 1
    container.Parent = window.content
    window._nextY = window._nextY + 55

    local label = Instance.new('TextLabel')
    label.Name = 'Label'
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text or 'Select'
    label.TextColor3 = self.options.theme.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.Parent = container

    local button = Instance.new('TextButton')
    button.Name = 'MultiDropdownButton'
    button.Size = UDim2.new(1, 0, 0, 25)
    button.Position = UDim2.new(0, 0, 0, 22)
    button.BackgroundColor3 = self.options.theme.surface
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.TextTruncate = Enum.TextTruncate.AtEnd
    button.Text = ''
    button.TextColor3 = self.options.theme.text
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.TextYAlignment = Enum.TextYAlignment.Center
    button.Font = Enum.Font.Gotham
    button.TextSize = 11
    button.ClipsDescendants = false
    button.Parent = container

    local btnCorner = Instance.new('UICorner')
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = button

    local btnPadding = Instance.new('UIPadding')
    btnPadding.PaddingLeft = UDim.new(0, 10)
    btnPadding.PaddingRight = UDim.new(0, 12)
    btnPadding.Parent = button

    local arrow = Instance.new('ImageLabel')
    arrow.Name = 'Arrow'
    arrow.Size = UDim2.new(0, 20, 0, 20)
    arrow.AnchorPoint = Vector2.new(1, 0.5)
    arrow.Position = UDim2.new(1, 10, 0.5, 0)
    arrow.BackgroundTransparency = 1
    arrow.Image = 'rbxassetid://116164752384094'
    arrow.ImageColor3 = self.options.theme.text
    arrow.ZIndex = 60
    arrow.Parent = button

    local menu = Instance.new('ScrollingFrame')
    menu.Name = 'MultiDropdownMenu'
    menu.Size = UDim2.new(0, 0, 0, 150)
    menu.BackgroundColor3 = self.options.theme.surface
    menu.BorderSizePixel = 0
    menu.Visible = false
    menu.ZIndex = 50
    menu.ScrollBarThickness = 0
    menu.ScrollingDirection = Enum.ScrollingDirection.Y
    menu.ElasticBehavior = Enum.ElasticBehavior.Never
    menu.CanvasSize = UDim2.new(0, 0, 0, 0)
    menu.Parent = window.frame

    local maxMenuHeight = 150
    local menuCorner = Instance.new('UICorner')
    menuCorner.CornerRadius = UDim.new(0, 4)
    menuCorner.Parent = menu
    local isOpen = false
    -- Track open state early so option handlers close correctly
    local isOpen = false

    local scrollTrack = Instance.new('Frame')
    scrollTrack.Name = 'CustomScrollTrack'
    scrollTrack.Size = UDim2.new(0, 4, 0, maxMenuHeight)
    scrollTrack.Position = UDim2.new(0, 0, 0, 0)
    scrollTrack.BackgroundTransparency = 1
    scrollTrack.BorderSizePixel = 0
    scrollTrack.ZIndex = 200
    scrollTrack.Visible = false
    scrollTrack.Parent = window.frame

    local scrollThumb = Instance.new('Frame')
    scrollThumb.Name = 'Thumb'
    scrollThumb.Size = UDim2.new(1, 0, 0, 24)
    scrollThumb.Position = UDim2.new(0, 0, 0, 0)
    scrollThumb.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
    scrollThumb.BorderSizePixel = 0
    scrollThumb.ZIndex = 52
    scrollThumb.Parent = scrollTrack

    local thumbCorner = Instance.new('UICorner')
    thumbCorner.CornerRadius = UDim.new(0, 3)
    thumbCorner.Parent = scrollThumb

    local selectedMap = {}
    for _, d in ipairs(defaults) do selectedMap[tostring(d)] = true end

    local function computeButtonText()
        local names = {}
        for _, name in ipairs(options) do
            if selectedMap[tostring(name)] then table.insert(names, tostring(name)) end
        end
        if #names == 0 then return 'None' end
        local text = table.concat(names, ', ')
        if #text > 22 then return tostring(#names) .. ' selected' end
        return text
    end
    button.Text = computeButtonText()

    local function syncMenuPlacement()
        local parentAbs = window.frame.AbsolutePosition
        local btnAbs = button.AbsolutePosition
        local xOffset = btnAbs.X - parentAbs.X
        local yOffset = (btnAbs.Y - parentAbs.Y) + button.AbsoluteSize.Y + 2
        menu.Position = UDim2.new(0, xOffset, 0, yOffset)
        menu.Size = UDim2.new(0, button.AbsoluteSize.X, 0, maxMenuHeight)
        scrollTrack.Position = UDim2.new(0, xOffset + menu.AbsoluteSize.X - 6, 0, yOffset)
        scrollTrack.Size = UDim2.new(0, 4, 0, maxMenuHeight)
        arrow.Position = UDim2.new(1, 10, 0.5, 0)
    end
    syncMenuPlacement()
    button:GetPropertyChangedSignal('AbsoluteSize'):Connect(syncMenuPlacement)
    button:GetPropertyChangedSignal('AbsolutePosition'):Connect(syncMenuPlacement)
    window.frame:GetPropertyChangedSignal('AbsolutePosition'):Connect(syncMenuPlacement)

    local function updateMenuCanvas()
        local optionHeight = 30
        menu.CanvasSize = UDim2.new(0, 0, 0, (#options * (optionHeight + 2)) + 12)
    end

    local function updateCustomScrollbar()
        local visibleHeight = menu.AbsoluteSize.Y
        local contentHeight = menu.CanvasSize.Y.Offset
        if contentHeight <= visibleHeight then
            scrollTrack.Visible = false
            return
        end
        scrollTrack.Visible = menu.Visible
        local trackHeight = visibleHeight
        local minThumb = 20
        local thumbHeight = math.clamp(math.floor((visibleHeight / contentHeight) * trackHeight), minThumb, trackHeight)
        scrollThumb.Size = UDim2.new(1, 0, 0, thumbHeight)
        local maxScroll = contentHeight - visibleHeight
        local ratio = (maxScroll > 0) and (menu.CanvasPosition.Y / maxScroll) or 0
        local thumbY = math.floor(ratio * (trackHeight - thumbHeight))
        scrollThumb.Position = UDim2.new(0, 0, 0, thumbY)
    end

    local draggingThumb = false
    local dragStartY = 0
    local thumbStartY = 0
    scrollThumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingThumb = true
            dragStartY = input.Position.Y
            thumbStartY = scrollThumb.AbsolutePosition.Y
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingThumb and input.UserInputType == Enum.UserInputType.MouseMovement then
            local visibleHeight = menu.AbsoluteSize.Y
            local contentHeight = menu.CanvasSize.Y.Offset
            local trackHeight = visibleHeight
            local thumbHeight = scrollThumb.AbsoluteSize.Y
            local maxThumbY = trackHeight - thumbHeight
            local deltaY = input.Position.Y - dragStartY
            local newThumbY = math.clamp((thumbStartY - scrollTrack.AbsolutePosition.Y) + deltaY, 0, maxThumbY)
            scrollThumb.Position = UDim2.new(0, 0, 0, newThumbY)
            local maxScroll = math.max(0, contentHeight - visibleHeight)
            local newRatio = (maxThumbY > 0) and (newThumbY / maxThumbY) or 0
            menu.CanvasPosition = Vector2.new(0, newRatio * maxScroll)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingThumb = false
        end
    end)

    local optionButtons = {}
    local optionHeight = 30
    for i, option in ipairs(options) do
        local optionFrame = Instance.new('Frame')
        optionFrame.Name = tostring(option) .. 'Option'
        optionFrame.Size = UDim2.new(1, -10, 0, optionHeight)
        optionFrame.Position = UDim2.new(0, 5, 0, (i - 1) * (optionHeight + 2) + 6)
        optionFrame.BackgroundTransparency = 1
        optionFrame.Parent = menu

        local optionButton = Instance.new('TextButton')
        optionButton.Name = 'Button'
        optionButton.Size = UDim2.new(1, 0, 1, 0)
        optionButton.BackgroundColor3 = self.options.theme.primary
        optionButton.BackgroundTransparency = selectedMap[tostring(option)] and 0 or 1
        optionButton.BorderSizePixel = 0
        optionButton.AutoButtonColor = false
        optionButton.Text = tostring(option)
        optionButton.TextColor3 = selectedMap[tostring(option)] and self.options.theme.textDark or self.options.theme.text
        optionButton.TextXAlignment = Enum.TextXAlignment.Left
        optionButton.Font = Enum.Font.Gotham
        optionButton.TextSize = 11
        optionButton.Parent = optionFrame
        optionButtons[tostring(option)] = optionButton
        table.insert(self._themeRefs.multiDropdownOptionButtons, optionButton)

        local optionCorner = Instance.new('UICorner')
        optionCorner.CornerRadius = UDim.new(0, 3)
        optionCorner.Parent = optionButton

        local optionPadding = Instance.new('UIPadding')
        optionPadding.PaddingLeft = UDim.new(0, 8)
        optionPadding.Parent = optionButton

        optionButton.MouseButton1Click:Connect(function()
            local key = tostring(option)
            selectedMap[key] = not selectedMap[key]
            local isOn = selectedMap[key]
            optionButton.BackgroundTransparency = isOn and 0 or 1
            if isOn then optionButton.BackgroundColor3 = self.options.theme.primary end
            optionButton.TextColor3 = isOn and self.options.theme.textDark or self.options.theme.text
            button.Text = computeButtonText()
            callback(selectedMap)
        end)
    end
    updateMenuCanvas()
    updateCustomScrollbar()

    local function toggleMenu()
        isOpen = not isOpen
        syncMenuPlacement()
        menu.Visible = isOpen
        scrollTrack.Visible = isOpen and (menu.CanvasSize.Y.Offset > menu.AbsoluteSize.Y)
        updateCustomScrollbar()
        local rotation = isOpen and 180 or 0
        TweenService:Create(arrow, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Rotation = rotation}):Play()
    end
    button.MouseButton1Click:Connect(function()
        -- Force open on first click if closed
        if not menu.Visible then
            isOpen = false
        end
        toggleMenu()
    end)
    arrow.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if not menu.Visible then isOpen = false end
            toggleMenu()
        end
    end)

    local api = {}
    function api.GetValue()
        return selectedMap
    end
    function api.SetValue(map)
        if type(map) ~= 'table' then return end
        selectedMap = {}
        for k,v in pairs(map) do if v then selectedMap[tostring(k)] = true end end
        for _, opt in ipairs(options) do
            local btn = optionButtons[tostring(opt)]
            if btn then
                local isOn = selectedMap[tostring(opt)]
                btn.BackgroundTransparency = isOn and 0 or 1
                btn.TextColor3 = isOn and self.options.theme.textDark or self.options.theme.text
            end
        end
        button.Text = computeButtonText()
        callback(selectedMap)
    end
    function api.SetOptions(newOptions)
        for _, btn in pairs(optionButtons) do
            if btn and btn.Parent then
                btn.Parent:Destroy()
            end
        end
        optionButtons = {}
        options = newOptions or {}
        updateMenuCanvas()
        for i, option in ipairs(options) do
            local optionFrame = Instance.new('Frame')
            optionFrame.Name = tostring(option) .. 'Option'
            optionFrame.Size = UDim2.new(1, -10, 0, optionHeight)
            optionFrame.Position = UDim2.new(0, 5, 0, (i - 1) * (optionHeight + 2) + 6)
            optionFrame.BackgroundTransparency = 1
            optionFrame.Parent = menu

            local optionButton = Instance.new('TextButton')
            optionButton.Name = 'Button'
            optionButton.Size = UDim2.new(1, 0, 1, 0)
            optionButton.BackgroundColor3 = self.options.theme.primary
            optionButton.BackgroundTransparency = selectedMap[tostring(option)] and 0 or 1
            optionButton.BorderSizePixel = 0
            optionButton.AutoButtonColor = false
            optionButton.Text = tostring(option)
            optionButton.TextColor3 = selectedMap[tostring(option)] and self.options.theme.textDark or self.options.theme.text
            optionButton.TextXAlignment = Enum.TextXAlignment.Left
            optionButton.Font = Enum.Font.Gotham
            optionButton.TextSize = 11
            optionButton.Parent = optionFrame
            optionButtons[tostring(option)] = optionButton
            table.insert(self._themeRefs.multiDropdownOptionButtons, optionButton)

            local optionCorner = Instance.new('UICorner')
            optionCorner.CornerRadius = UDim.new(0, 3)
            optionCorner.Parent = optionButton

            local optionPadding = Instance.new('UIPadding')
            optionPadding.PaddingLeft = UDim.new(0, 8)
            optionPadding.Parent = optionButton

            optionButton.MouseButton1Click:Connect(function()
                local key = tostring(option)
                selectedMap[key] = not selectedMap[key]
                local isOn = selectedMap[key]
                optionButton.BackgroundTransparency = isOn and 0 or 1
                optionButton.TextColor3 = isOn and self.options.theme.textDark or self.options.theme.text
                button.Text = computeButtonText()
                callback(selectedMap)
            end)
        end
        updateCustomScrollbar()
        button.Text = computeButtonText()
    end

    -- Element für Config System registrieren
    if window and window.library then
        local tabName = nil
        local windowName = nil
        
        for _, tab in ipairs(window.library.tabs) do
            if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                tabName = tab.frame.Name:gsub("Content", "")
                break
            end
        end
        
        if window.frame and window.frame.Name then
            windowName = window.frame.Name:gsub("Window", "")
        end
        
        window.library:_registerElement("multidropdown", tabName, windowName, text, api)
    end

    return api
end

function ModernUI:_createSlider(window, text, min, max, default, callback)
    min = min or 0
    max = max or 100
    default = default or min
    callback = callback or function() end

    local container = Instance.new('Frame')
    container.Name = 'SliderContainer'
    container.Size = UDim2.new(1, 0, 0, 50)
    container.Position = UDim2.new(0, 0, 0, window._nextY)
    container.BackgroundTransparency = 1
    container.Parent = window.content
    
    window._nextY = window._nextY + 55

    local label = Instance.new('TextLabel')
    label.Name = 'Label'
    label.Size = UDim2.new(0.6, 0, 0, 20)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = self.options.theme.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.Parent = container

    local valueLabel = Instance.new('TextLabel')
    valueLabel.Name = 'ValueLabel'
    valueLabel.Size = UDim2.new(0.4, 0, 0, 20)
    valueLabel.Position = UDim2.new(0.6, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(math.floor(default))
    valueLabel.TextColor3 = self.options.theme.text
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Font = Enum.Font.Gotham
    valueLabel.TextSize = 12
    valueLabel.Parent = container

    local track = Instance.new('Frame')
    track.Name = 'Track'
    track.Size = UDim2.new(1, 0, 0, 12)
    track.Position = UDim2.new(0, 0, 0, 28)
    track.BackgroundColor3 = self.options.theme.surface
    track.BorderSizePixel = 0
    track.Parent = container

    local trackCorner = Instance.new('UICorner')
    trackCorner.CornerRadius = UDim.new(0, 2)
    trackCorner.Parent = track

    local fill = Instance.new('Frame')
    fill.Name = 'Fill'
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = self.options.theme.primary
    fill.BorderSizePixel = 0
    fill.Parent = track

    table.insert(self._themeRefs.sliderFills, fill)

    local fillCorner = Instance.new('UICorner')
    fillCorner.CornerRadius = UDim.new(0, 2)
    fillCorner.Parent = fill

    local value = default
    local dragging = false

    local function updateSlider()
        local percentage = (value - min) / (max - min)
        local tween = TweenService:Create(fill, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
            Size = UDim2.new(percentage, 0, 1, 0)
        })
        tween:Play()
        valueLabel.Text = tostring(math.floor(value))
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            local relativeX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            value = min + (relativeX * (max - min))
            updateSlider()
            callback(value)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local relativeX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            value = min + (relativeX * (max - min))
            updateSlider()
            callback(value)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    updateSlider()

    local api = {
        SetValue = function(newValue)
            value = math.clamp(newValue, min, max)
            updateSlider()
        end,
        GetValue = function()
            return value
        end
    }
    
    -- Element für Config System registrieren
    if window and window.library then
        local tabName = nil
        local windowName = nil
        
        for _, tab in ipairs(window.library.tabs) do
            if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                tabName = tab.frame.Name:gsub("Content", "")
                break
            end
        end
        
        if window.frame and window.frame.Name then
            windowName = window.frame.Name:gsub("Window", "")
        end
        
        window.library:_registerElement("slider", tabName, windowName, text, api)
    end
    
    return api
end

function ModernUI:_createButton(window, text, callback)
    callback = callback or function() end

    local button = Instance.new('TextButton')
    button.Name = 'Button'
    button.Size = UDim2.new(1, 0, 0, 34)
    button.Position = UDim2.new(0, 0, 0, window._nextY)
    button.BackgroundColor3 = self.options.theme.surface
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = text
    button.Font = Enum.Font.Gotham
    button.TextSize = 12
    button.TextColor3 = self.options.theme.text
    button.Parent = window.content
    
    -- 34px height + 8px spacing (matches Lynix)
    window._nextY = window._nextY + 42

    local buttonCorner = Instance.new('UICorner')
    buttonCorner.CornerRadius = UDim.new(0, 5)
    buttonCorner.Parent = button

    -- Match Lynix GUI exactly: immediate flash on press (mouse/touch), smooth fade back on release; callback on click
    local baseButtonBg = button.BackgroundColor3
    local baseButtonText = button.TextColor3
    local bgTween = nil
    local textTween = nil

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if bgTween then bgTween:Cancel() end
            if textTween then textTween:Cancel() end
            button.BackgroundColor3 = self.options.theme.primary
            button.TextColor3 = self.options.theme.textDark
        end
    end)

    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if bgTween then bgTween:Cancel() end
            if textTween then textTween:Cancel() end
            bgTween = TweenService:Create(button, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = baseButtonBg
            })
            textTween = TweenService:Create(button, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                TextColor3 = baseButtonText
            })
            bgTween:Play()
            textTween:Play()
        end
    end)

    button.MouseButton1Click:Connect(function()
        callback()
    end)

    local api = {
        SetText = function(newText)
            button.Text = newText
        end,
        GetValue = function()
            return button.Text
        end,
        SetValue = function(newText)
            button.Text = newText
        end
    }
    
    -- Element für Config System registrieren
    if window and window.library then
        local tabName = nil
        local windowName = nil
        
        for _, tab in ipairs(window.library.tabs) do
            if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                tabName = tab.frame.Name:gsub("Content", "")
                break
            end
        end
        
        if window.frame and window.frame.Name then
            windowName = window.frame.Name:gsub("Window", "")
        end
        
        window.library:_registerElement("button", tabName, windowName, text, api)
    end
    
    return api
end

-- Simple implementations für andere UI Elemente
function ModernUI:_createDropdown(window, text, options, default, callback)
    options = options or {}
    callback = callback or function() end

    local container = Instance.new('Frame')
    container.Name = 'DropdownContainer'
    container.Size = UDim2.new(1, 0, 0, 50)
    container.Position = UDim2.new(0, 0, 0, window._nextY)
    container.BackgroundTransparency = 1
    container.Parent = window.content
    window._nextY = window._nextY + 55
    
    local label = Instance.new('TextLabel')
    label.Name = 'Label'
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = text or 'Select'
    label.TextColor3 = self.options.theme.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.Parent = container

    local button = Instance.new('TextButton')
    button.Name = 'DropdownButton'
    button.Size = UDim2.new(1, 0, 0, 25)
    button.Position = UDim2.new(0, 0, 0, 22)
    button.BackgroundColor3 = self.options.theme.surface
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.TextTruncate = Enum.TextTruncate.AtEnd
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.TextYAlignment = Enum.TextYAlignment.Center
    button.Font = Enum.Font.Gotham
    button.TextSize = 11
    button.TextColor3 = self.options.theme.text
    button.ClipsDescendants = false
    button.Parent = container
    
    local btnCorner = Instance.new('UICorner')
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = button

    local btnPadding = Instance.new('UIPadding')
    btnPadding.PaddingLeft = UDim.new(0, 10)
    btnPadding.PaddingRight = UDim.new(0, 12)
    btnPadding.Parent = button

    local arrow = Instance.new('ImageLabel')
    arrow.Name = 'Arrow'
    arrow.Size = UDim2.new(0, 16, 0, 16)
    arrow.AnchorPoint = Vector2.new(1, 0.5)
    arrow.Position = UDim2.new(1, 10, 0.5, 0)
    arrow.BackgroundTransparency = 1
    arrow.Image = 'rbxassetid://128488479848041'
    arrow.ImageColor3 = self.options.theme.text
    arrow.ZIndex = 60
    arrow.Parent = button

    -- Overlay menu on the window for proper placement
    local menu = Instance.new('ScrollingFrame')
    menu.Name = 'DropdownMenu'
    menu.Size = UDim2.new(0, 0, 0, 150)
    menu.BackgroundColor3 = self.options.theme.surface
    menu.BorderSizePixel = 0
    menu.Visible = false
    menu.ZIndex = 50
    menu.ScrollBarThickness = 0
    menu.ScrollingDirection = Enum.ScrollingDirection.Y
    menu.ElasticBehavior = Enum.ElasticBehavior.Never
    menu.CanvasSize = UDim2.new(0, 0, 0, 0)
    menu.Parent = window.frame

    local maxMenuHeight = 150
    local menuCorner = Instance.new('UICorner')
    menuCorner.CornerRadius = UDim.new(0, 4)
    menuCorner.Parent = menu

    -- Custom slim scrollbar (visible only on overflow)
    local scrollTrack = Instance.new('Frame')
    scrollTrack.Name = 'CustomScrollTrack'
    scrollTrack.Size = UDim2.new(0, 4, 0, maxMenuHeight)
    scrollTrack.Position = UDim2.new(0, 0, 0, 0)
    scrollTrack.BackgroundTransparency = 1
    scrollTrack.BorderSizePixel = 0
    scrollTrack.ZIndex = 200
    scrollTrack.Visible = false
    scrollTrack.Parent = window.frame

    local scrollThumb = Instance.new('Frame')
    scrollThumb.Name = 'Thumb'
    scrollThumb.Size = UDim2.new(1, 0, 0, 24)
    scrollThumb.Position = UDim2.new(0, 0, 0, 0)
    scrollThumb.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
    scrollThumb.BorderSizePixel = 0
    scrollThumb.ZIndex = 52
    scrollThumb.Parent = scrollTrack

    local thumbCorner = Instance.new('UICorner')
    thumbCorner.CornerRadius = UDim.new(0, 3)
    thumbCorner.Parent = scrollThumb

    local selected = default or options[1] or 'Select...'
    button.Text = tostring(selected)

    local optionButtons = {}
    local optionHeight = 30

    local function syncMenuPlacement()
        local parentAbs = window.frame.AbsolutePosition
        local btnAbs = button.AbsolutePosition
        local xOffset = btnAbs.X - parentAbs.X
        local yOffset = (btnAbs.Y - parentAbs.Y) + button.AbsoluteSize.Y + 2
        menu.Position = UDim2.new(0, xOffset, 0, yOffset)
        menu.Size = UDim2.new(0, button.AbsoluteSize.X, 0, maxMenuHeight)
        scrollTrack.Position = UDim2.new(0, xOffset + menu.AbsoluteSize.X - 6, 0, yOffset)
        scrollTrack.Size = UDim2.new(0, 4, 0, maxMenuHeight)
        arrow.Position = UDim2.new(1, 10, 0.5, 0)
    end
    syncMenuPlacement()
    button:GetPropertyChangedSignal('AbsoluteSize'):Connect(syncMenuPlacement)
    button:GetPropertyChangedSignal('AbsolutePosition'):Connect(syncMenuPlacement)
    window.frame:GetPropertyChangedSignal('AbsolutePosition'):Connect(syncMenuPlacement)

    local function updateMenuCanvas()
        menu.CanvasSize = UDim2.new(0, 0, 0, (#options * (optionHeight + 2)) + 12)
    end

    -- build options
    for i, option in ipairs(options) do
        local optionFrame = Instance.new('Frame')
        optionFrame.Name = tostring(option) .. 'Option'
        optionFrame.Size = UDim2.new(1, -10, 0, optionHeight)
        optionFrame.Position = UDim2.new(0, 5, 0, (i - 1) * (optionHeight + 2) + 6)
        optionFrame.BackgroundTransparency = 1
        optionFrame.Parent = menu

    local optionButton = Instance.new('TextButton')
        optionButton.Name = 'Button'
        optionButton.Size = UDim2.new(1, 0, 1, 0)
        optionButton.BackgroundColor3 = self.options.theme.primary
        optionButton.BackgroundTransparency = (option == selected) and 0 or 1
        optionButton.BorderSizePixel = 0
        optionButton.AutoButtonColor = false
        optionButton.Text = tostring(option)
        optionButton.TextColor3 = (option == selected) and self.options.theme.textDark or self.options.theme.text
        optionButton.TextXAlignment = Enum.TextXAlignment.Left
        optionButton.Font = Enum.Font.Gotham
        optionButton.TextSize = 11
        optionButton.Parent = optionFrame
        optionButtons[option] = optionButton
        table.insert(self._themeRefs.dropdownOptionButtons, optionButton)

        local optionCorner = Instance.new('UICorner')
        optionCorner.CornerRadius = UDim.new(0, 3)
        optionCorner.Parent = optionButton

        local optionPadding = Instance.new('UIPadding')
        optionPadding.PaddingLeft = UDim.new(0, 8)
        optionPadding.Parent = optionButton

        optionButton.MouseButton1Click:Connect(function()
            selected = option
            button.Text = tostring(selected)
            for _, opt in ipairs(options) do
                local btn = optionButtons[opt]
                if btn then
                    local isSel = (opt == selected)
                    btn.BackgroundTransparency = isSel and 0 or 1
                    if isSel then btn.BackgroundColor3 = self.options.theme.primary end
                    btn.TextColor3 = isSel and self.options.theme.textDark or self.options.theme.text
                end
            end
            -- Ensure internal open-state is reset so next click opens immediately
            isOpen = false
            -- Defer close by one heartbeat so click release doesn't toggle back
            menu.Visible = false
            scrollTrack.Visible = false
            TweenService:Create(arrow, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Rotation = 0}):Play()
            callback(selected)
        end)
    end
    updateMenuCanvas()
    
    -- Scrollbar syncing
    local function updateCustomScrollbar()
        local visibleHeight = menu.AbsoluteSize.Y
        local contentHeight = menu.CanvasSize.Y.Offset
        if contentHeight <= visibleHeight then
            scrollTrack.Visible = false
            return
        end
        scrollTrack.Visible = menu.Visible
        local trackHeight = visibleHeight
        local minThumb = 20
        local thumbHeight = math.clamp(math.floor((visibleHeight / contentHeight) * trackHeight), minThumb, trackHeight)
        scrollThumb.Size = UDim2.new(1, 0, 0, thumbHeight)
        local maxScroll = contentHeight - visibleHeight
        local ratio = (maxScroll > 0) and (menu.CanvasPosition.Y / maxScroll) or 0
        local thumbY = math.floor(ratio * (trackHeight - thumbHeight))
        scrollThumb.Position = UDim2.new(0, 0, 0, thumbY)
    end
    
    menu:GetPropertyChangedSignal('CanvasPosition'):Connect(updateCustomScrollbar)
    menu:GetPropertyChangedSignal('AbsoluteSize'):Connect(updateCustomScrollbar)
    menu.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            updateCustomScrollbar()
        end
    end)

    -- Dragging the thumb
    local draggingThumb = false
    local dragStartY = 0
    local thumbStartY = 0
    scrollThumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingThumb = true
            dragStartY = input.Position.Y
            thumbStartY = scrollThumb.AbsolutePosition.Y
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingThumb and input.UserInputType == Enum.UserInputType.MouseMovement then
            local visibleHeight = menu.AbsoluteSize.Y
            local contentHeight = menu.CanvasSize.Y.Offset
            local trackHeight = visibleHeight
            local thumbHeight = scrollThumb.AbsoluteSize.Y
            local maxThumbY = trackHeight - thumbHeight
            local deltaY = input.Position.Y - dragStartY
            local newThumbY = math.clamp((thumbStartY - scrollTrack.AbsolutePosition.Y) + deltaY, 0, maxThumbY)
            scrollThumb.Position = UDim2.new(0, 0, 0, newThumbY)
            local maxScroll = math.max(0, contentHeight - visibleHeight)
            local newRatio = (maxThumbY > 0) and (newThumbY / maxThumbY) or 0
            menu.CanvasPosition = Vector2.new(0, newRatio * maxScroll)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingThumb = false
        end
    end)

    local function toggleMenu()
        isOpen = not isOpen
        syncMenuPlacement()
        menu.Visible = isOpen
        scrollTrack.Visible = isOpen and (menu.CanvasSize.Y.Offset > menu.AbsoluteSize.Y)
        updateCustomScrollbar()
        local rotation = isOpen and 180 or 0
        TweenService:Create(arrow, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Rotation = rotation}):Play()
    end

    button.MouseButton1Click:Connect(toggleMenu)
    arrow.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            toggleMenu()
        end
    end)

    local api = {}
    function api.SetValue(value)
        if value == nil then return end
        for _, opt in ipairs(options) do
            if tostring(opt) == tostring(value) then
                selected = opt
                button.Text = tostring(selected)
                for __, o in ipairs(options) do
                    local btn = optionButtons[o]
                    if btn then
                        local isSel = (o == selected)
                        btn.BackgroundTransparency = isSel and 0 or 1
                        btn.TextColor3 = isSel and self.options.theme.textDark or self.options.theme.text
                    end
                end
                callback(selected)
                break
            end
        end
    end

    function api.GetValue()
        return selected
    end

    function api.SetOptions(newOptions)
        for _, btn in pairs(optionButtons) do
            if btn and btn.Parent then
                btn.Parent:Destroy()
            end
        end
        optionButtons = {}
        options = newOptions or {}
        if #options > 0 then
            selected = options[1]
            button.Text = tostring(selected)
        end
        for i, option in ipairs(options) do
            local optionFrame = Instance.new('Frame')
            optionFrame.Name = tostring(option) .. 'Option'
            optionFrame.Size = UDim2.new(1, -10, 0, optionHeight)
            optionFrame.Position = UDim2.new(0, 5, 0, (i - 1) * (optionHeight + 2) + 6)
            optionFrame.BackgroundTransparency = 1
            optionFrame.Parent = menu

    local optionButton = Instance.new('TextButton')
            optionButton.Name = 'Button'
            optionButton.Size = UDim2.new(1, 0, 1, 0)
            optionButton.BackgroundColor3 = self.options.theme.primary
            optionButton.BackgroundTransparency = (option == selected) and 0 or 1
            optionButton.BorderSizePixel = 0
            optionButton.AutoButtonColor = false
            optionButton.Text = tostring(option)
            optionButton.TextColor3 = (option == selected) and self.options.theme.textDark or self.options.theme.text
            optionButton.TextXAlignment = Enum.TextXAlignment.Left
            optionButton.Font = Enum.Font.Gotham
            optionButton.TextSize = 11
            optionButton.Parent = optionFrame
            optionButtons[option] = optionButton
            table.insert(self._themeRefs.dropdownOptionButtons, optionButton)

            local optionCorner = Instance.new('UICorner')
            optionCorner.CornerRadius = UDim.new(0, 3)
            optionCorner.Parent = optionButton

            local optionPadding = Instance.new('UIPadding')
            optionPadding.PaddingLeft = UDim.new(0, 8)
            optionPadding.Parent = optionButton

            optionButton.MouseButton1Click:Connect(function()
                selected = option
                button.Text = tostring(selected)
                for _, opt in ipairs(options) do
                    local btn2 = optionButtons[opt]
                    if btn2 then
                        local isSel = (opt == selected)
                        btn2.BackgroundTransparency = isSel and 0 or 1
                        btn2.TextColor3 = isSel and self.options.theme.textDark or self.options.theme.text
                    end
                end
                -- Ensure internal open-state is reset so next click opens immediately
                isOpen = false
                menu.Visible = false
                scrollTrack.Visible = false
                TweenService:Create(arrow, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Rotation = 0}):Play()
                callback(selected)
            end)
        end
        updateMenuCanvas()
    end

    -- Element für Config System registrieren
    if window and window.library then
        local tabName = nil
        local windowName = nil
        
        for _, tab in ipairs(window.library.tabs) do
            if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                tabName = tab.frame.Name:gsub("Content", "")
                break
            end
        end
        
        if window.frame and window.frame.Name then
            windowName = window.frame.Name:gsub("Window", "")
        end
        
        window.library:_registerElement("dropdown", tabName, windowName, text, api)
    end
    
    return api
end

function ModernUI:_createColorPicker(window, text, default, callback)
    default = default or Color3.fromRGB(113, 118, 242)
    callback = callback or function() end

    local container = Instance.new('Frame')
    container.Name = 'ColorPickerContainer'
    container.Size = UDim2.new(1, 0, 0, 36)
    container.Position = UDim2.new(0, 0, 0, window._nextY)
    container.BackgroundTransparency = 1
    container.Parent = window.content
    window._nextY = window._nextY + 42

    local label = Instance.new('TextLabel')
    label.Name = 'Label'
    label.Size = UDim2.new(1, -25, 1, 0)
    label.Position = UDim2.new(0, 25, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = self.options.theme.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.Parent = container

    local colorPreview = Instance.new('TextButton')
    colorPreview.Name = 'ColorPreview'
    colorPreview.Size = UDim2.new(0, 18, 0, 18)
    colorPreview.Position = UDim2.new(0, 0, 0.5, -9)
    colorPreview.BackgroundColor3 = default
    colorPreview.BorderSizePixel = 0
    colorPreview.AutoButtonColor = false
    colorPreview.Text = ''
    colorPreview.Parent = container

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 3)
    corner.Parent = colorPreview

    -- Popup next to preview (overlay on window)
    local popup = Instance.new('Frame')
    popup.Name = 'ColorPickerPopup'
    popup.Size = UDim2.new(0, 196, 0, 238)
    popup.BackgroundColor3 = self.options.theme.surface
    popup.BorderSizePixel = 0
    popup.Visible = false
    popup.ZIndex = 120
    popup.Parent = window.frame

    local popupCorner = Instance.new('UICorner')
    popupCorner.CornerRadius = UDim.new(0, 8)
    popupCorner.Parent = popup

    local function syncPopupPlacement()
        local parentAbs = window.frame.AbsolutePosition
        local boxAbs = colorPreview.AbsolutePosition
        local xOffset = (boxAbs.X - parentAbs.X) + colorPreview.AbsoluteSize.X + 8
        local yOffset = (boxAbs.Y - parentAbs.Y) - 4
        popup.Position = UDim2.new(0, xOffset, 0, yOffset)
    end
    syncPopupPlacement()
    colorPreview:GetPropertyChangedSignal('AbsolutePosition'):Connect(syncPopupPlacement)
    window.frame:GetPropertyChangedSignal('AbsolutePosition'):Connect(syncPopupPlacement)

    -- SV square
    local svFrame = Instance.new('Frame')
    svFrame.Name = 'SV'
    svFrame.Size = UDim2.new(0, 168, 0, 168)
    svFrame.Position = UDim2.new(0, 14, 0, 16)
    svFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    svFrame.BorderSizePixel = 0
    svFrame.ZIndex = 121
    svFrame.ClipsDescendants = true
    svFrame.Parent = popup

    local svCorner = Instance.new('UICorner')
    svCorner.CornerRadius = UDim.new(0, 6)
    svCorner.Parent = svFrame

    local svSaturationOverlay = Instance.new('Frame')
    svSaturationOverlay.Size = UDim2.new(1, 0, 1, 0)
    svSaturationOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    svSaturationOverlay.BorderSizePixel = 0
    svSaturationOverlay.ZIndex = 122
    svSaturationOverlay.Parent = svFrame
    local svSatGradient = Instance.new('UIGradient')
    svSatGradient.Rotation = 0
    svSatGradient.Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(255,255,255))
    svSatGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 0.0),
        NumberSequenceKeypoint.new(1.0, 1.0),
    })
    svSatGradient.Parent = svSaturationOverlay
    local svSatCorner = Instance.new('UICorner')
    svSatCorner.CornerRadius = UDim.new(0, 6)
    svSatCorner.Parent = svSaturationOverlay

    local svValueOverlay = Instance.new('Frame')
    svValueOverlay.Size = UDim2.new(1, 0, 1, 0)
    svValueOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    svValueOverlay.BorderSizePixel = 0
    svValueOverlay.ZIndex = 123
    svValueOverlay.Parent = svFrame
    local svValGradient = Instance.new('UIGradient')
    svValGradient.Rotation = 90
    svValGradient.Color = ColorSequence.new(Color3.fromRGB(0,0,0), Color3.fromRGB(0,0,0))
    svValGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 1.0),
        NumberSequenceKeypoint.new(1.0, 0.0),
    })
    svValGradient.Parent = svValueOverlay
    local svValCorner = Instance.new('UICorner')
    svValCorner.CornerRadius = UDim.new(0, 6)
    svValCorner.Parent = svValueOverlay

    local svKnob = Instance.new('Frame')
    svKnob.Size = UDim2.new(0, 10, 0, 10)
    svKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    svKnob.Position = UDim2.new(0, 0, 0, 0)
    svKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    svKnob.BorderSizePixel = 0
    svKnob.ZIndex = 124
    svKnob.Parent = svFrame
    local svKnobCorner = Instance.new('UICorner')
    svKnobCorner.CornerRadius = UDim.new(1, 0)
    svKnobCorner.Parent = svKnob

    -- Hue bar
    local hueBar = Instance.new('Frame')
    hueBar.Name = 'HueBar'
    hueBar.Size = UDim2.new(0, 168, 0, 12)
    hueBar.Position = UDim2.new(0, 14, 0, 196)
    hueBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    hueBar.BorderSizePixel = 0
    hueBar.ZIndex = 121
    hueBar.Parent = popup

    local hueCorner = Instance.new('UICorner')
    hueCorner.CornerRadius = UDim.new(0, 6)
    hueCorner.Parent = hueBar

    local hueGradient = Instance.new('UIGradient')
    hueGradient.Rotation = 0
    hueGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 165, 0)),
        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 0)),
        ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(0.83, Color3.fromRGB(0, 0, 255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 255))
    })
    hueGradient.Parent = hueBar

    local hueMarker = Instance.new('Frame')
    hueMarker.Size = UDim2.new(0, 8, 0, 16)
    hueMarker.AnchorPoint = Vector2.new(0.5, 0.5)
    hueMarker.Position = UDim2.new(0, 0, 0.5, 0)
    hueMarker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    hueMarker.BorderSizePixel = 0
    hueMarker.ZIndex = 122
    hueMarker.Parent = hueBar
    local hueMarkerCorner = Instance.new('UICorner')
    hueMarkerCorner.CornerRadius = UDim.new(0, 2)
    hueMarkerCorner.Parent = hueMarker
    hueMarker.ClipsDescendants = true

    -- Alpha bar
    local alphaBar = Instance.new('Frame')
    alphaBar.Name = 'AlphaBar'
    alphaBar.Size = UDim2.new(0, 168, 0, 12)
    alphaBar.Position = UDim2.new(0, 14, 0, 216)
    alphaBar.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    alphaBar.BorderSizePixel = 0
    alphaBar.ZIndex = 121
    alphaBar.Parent = popup

    local alphaCorner = Instance.new('UICorner')
    alphaCorner.CornerRadius = UDim.new(0, 6)
    alphaCorner.Parent = alphaBar

    local alphaGradient = Instance.new('UIGradient')
    alphaGradient.Rotation = 0
    alphaGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 255, 255)),
    })
    alphaGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 0.0),
        NumberSequenceKeypoint.new(1.00, 1.0),
    })
    alphaGradient.Parent = alphaBar

    local alphaMarker = Instance.new('Frame')
    alphaMarker.Size = UDim2.new(0, 8, 0, 16)
    alphaMarker.AnchorPoint = Vector2.new(0.5, 0.5)
    alphaMarker.Position = UDim2.new(0, 0, 0.5, 0)
    alphaMarker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    alphaMarker.BorderSizePixel = 0
    alphaMarker.ZIndex = 122
    alphaMarker.Parent = alphaBar
    local alphaMarkerCorner = Instance.new('UICorner')
    alphaMarkerCorner.CornerRadius = UDim.new(0, 2)
    alphaMarkerCorner.Parent = alphaMarker

    -- Color state (HSV + A)
    local hue, saturation, value, alpha = Color3.toHSV(default)
    if hue ~= hue then hue = 0 end -- guard against NaN
    alpha = 1

    local function hsvToColor3(h, s, v)
        return Color3.fromHSV(h, s, v)
    end

    local function updatePreviewAndSV()
        svFrame.BackgroundColor3 = hsvToColor3(hue, 1, 1)
        colorPreview.BackgroundColor3 = hsvToColor3(hue, saturation, value)
        hueMarker.Position = UDim2.new(hue, 0, 0.5, 0)
        local c = colorPreview.BackgroundColor3
        alphaGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, c),
            ColorSequenceKeypoint.new(1.00, c),
        })
        alphaMarker.Position = UDim2.new(alpha, 0, 0.5, 0)
        svKnob.Position = UDim2.new(saturation, 0, 1 - value, 0)
    end
    updatePreviewAndSV()

    -- Toggle popup
    colorPreview.MouseButton1Click:Connect(function()
        popup.Visible = not popup.Visible
        syncPopupPlacement()
    end)

    -- Drag hue
    local draggingHue = false
    hueBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingHue = true
            local x = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
            hue = x
            updatePreviewAndSV()
            callback(colorPreview.BackgroundColor3, alpha)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingHue and input.UserInputType == Enum.UserInputType.MouseMovement then
            local x = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
            hue = x
            updatePreviewAndSV()
            callback(colorPreview.BackgroundColor3, alpha)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingHue = false
        end
    end)

    -- Drag alpha
    local draggingAlpha = false
    alphaBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingAlpha = true
            local x = math.clamp((input.Position.X - alphaBar.AbsolutePosition.X) / alphaBar.AbsoluteSize.X, 0, 1)
            alpha = x
            updatePreviewAndSV()
            callback(colorPreview.BackgroundColor3, alpha)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingAlpha and input.UserInputType == Enum.UserInputType.MouseMovement then
            local x = math.clamp((input.Position.X - alphaBar.AbsolutePosition.X) / alphaBar.AbsoluteSize.X, 0, 1)
            alpha = x
            updatePreviewAndSV()
            callback(colorPreview.BackgroundColor3, alpha)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingAlpha = false
        end
    end)

    -- Drag SV
    local draggingSV = false
    svFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingSV = true
            local relX = math.clamp((input.Position.X - svFrame.AbsolutePosition.X) / svFrame.AbsoluteSize.X, 0, 1)
            local relY = math.clamp((input.Position.Y - svFrame.AbsolutePosition.Y) / svFrame.AbsoluteSize.Y, 0, 1)
            saturation = relX
            value = 1 - relY
            updatePreviewAndSV()
            callback(colorPreview.BackgroundColor3, alpha)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingSV and input.UserInputType == Enum.UserInputType.MouseMovement then
            local relX = math.clamp((input.Position.X - svFrame.AbsolutePosition.X) / svFrame.AbsoluteSize.X, 0, 1)
            local relY = math.clamp((input.Position.Y - svFrame.AbsolutePosition.Y) / svFrame.AbsoluteSize.Y, 0, 1)
            saturation = relX
            value = 1 - relY
            updatePreviewAndSV()
            callback(colorPreview.BackgroundColor3, alpha)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingSV = false
        end
    end)

    local api = {}
    function api.SetValue(color, newAlpha)
        if typeof(color) == 'Color3' then
            local h, s, v = Color3.toHSV(color)
            hue, saturation, value = h, s, v
        end
        if typeof(newAlpha) == 'number' then
            alpha = math.clamp(newAlpha, 0, 1)
        end
        updatePreviewAndSV()
        callback(colorPreview.BackgroundColor3, alpha)
    end
    function api.GetValue()
        return colorPreview.BackgroundColor3
    end
    function api.GetRGBA()
        local c = colorPreview.BackgroundColor3
        return c, alpha
    end

    -- Element für Config System registrieren
    if window and window.library then
        local tabName = nil
        local windowName = nil
        
        for _, tab in ipairs(window.library.tabs) do
            if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                tabName = tab.frame.Name:gsub("Content", "")
                break
            end
        end
        
        if window.frame and window.frame.Name then
            windowName = window.frame.Name:gsub("Window", "")
        end
        
        window.library:_registerElement("colorpicker", tabName, windowName, text, api)
    end

    return api
end

function ModernUI:_createTextBox(window, text, placeholder, callback)
    placeholder = placeholder or "Enter text..."
    callback = callback or function() end

    local container = Instance.new('Frame')
    container.Size = UDim2.new(1, 0, 0, 40)
    container.Position = UDim2.new(0, 0, 0, window._nextY)
    container.BackgroundTransparency = 1
    container.Parent = window.content
    window._nextY = window._nextY + 45

    local background = Instance.new('Frame')
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = self.options.theme.surface
    background.BorderSizePixel = 0
    background.Parent = container

    local bgCorner = Instance.new('UICorner')
    bgCorner.CornerRadius = UDim.new(0, 5)
    bgCorner.Parent = background

    -- Underline for focus feedback (matches Lynix style)
    local underline = Instance.new('Frame')
    underline.Name = 'Underline'
    underline.Size = UDim2.new(1, -12, 0, 2)
    underline.Position = UDim2.new(0, 6, 1, -5)
    underline.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    underline.BorderSizePixel = 0
    underline.Parent = background

    local textBox = Instance.new('TextBox')
    textBox.Name = 'TextBox'
    textBox.Size = UDim2.new(1, -52, 1, -10) -- leave space for right-side icon
    textBox.Position = UDim2.new(0, 10, 0, 5)
    textBox.BackgroundTransparency = 1
    textBox.ClearTextOnFocus = false
    textBox.Text = ''
    textBox.TextColor3 = self.options.theme.text
    textBox.PlaceholderText = placeholder
    textBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 125)
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.TextYAlignment = Enum.TextYAlignment.Center
    textBox.TextSize = 12
    textBox.Font = Enum.Font.Gotham
    textBox.Parent = background

    -- Right-side icon (pencil) like Lynix
    local pencilIcon = Instance.new('ImageLabel')
    pencilIcon.Name = 'Pencil'
    pencilIcon.Size = UDim2.new(0, 20, 0, 20)
    pencilIcon.AnchorPoint = Vector2.new(1, 0.5)
    pencilIcon.Position = UDim2.new(1, -10, 0.5, 0)
    pencilIcon.BackgroundTransparency = 1
    pencilIcon.Image = 'rbxassetid://96464342105694'
    pencilIcon.ImageColor3 = self.options.theme.text
    pencilIcon.Parent = background

    local function setUnderlineActive(active)
        local target = active and self.options.theme.primary or Color3.fromRGB(50, 50, 55)
        TweenService:Create(underline, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = target}):Play()
    end

    textBox.Focused:Connect(function()
        setUnderlineActive(true)
    end)

    textBox.FocusLost:Connect(function()
        setUnderlineActive(false)
        callback(textBox.Text)
    end)

    local api = {
        SetValue = function(value)
            textBox.Text = value
        end,
        GetValue = function()
            return textBox.Text
        end
    }
    
    -- Element für Config System registrieren
    if window and window.library then
        local tabName = nil
        local windowName = nil
        
        for _, tab in ipairs(window.library.tabs) do
            if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                tabName = tab.frame.Name:gsub("Content", "")
                break
            end
        end
        
        if window.frame and window.frame.Name then
            windowName = window.frame.Name:gsub("Window", "")
        end
        
        window.library:_registerElement("textbox", tabName, windowName, text or "TextInput", api)
    end
    
    return api
end

function ModernUI:_createKeybind(window, text, default, callback)
    default = default or "None"
    callback = callback or function() end

    local container = Instance.new('Frame')
    container.Name = 'KeybindContainer'
    container.Size = UDim2.new(1, 0, 0, 50)
    container.Position = UDim2.new(0, 0, 0, window._nextY)
    container.BackgroundTransparency = 1
    container.Parent = window.content
    window._nextY = window._nextY + 55

    local label = Instance.new('TextLabel')
    label.Name = 'Label'
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text or 'Keybind'
    label.TextColor3 = self.options.theme.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.Parent = container

    local button = Instance.new('TextButton')
    button.Name = 'KeybindButton'
    button.Size = UDim2.new(1, 0, 0, 25)
    button.Position = UDim2.new(0, 0, 0, 22)
    button.BackgroundColor3 = self.options.theme.surface
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = 'Bind: ' .. default
    button.Font = Enum.Font.Gotham
    button.TextSize = 12
    button.TextColor3 = self.options.theme.text
    button.Parent = container

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = button

    local isBinding = false
    local currentKey = default

    local function setBindVisual(active)
        local bg = active and self.options.theme.primary or self.options.theme.surface
        local txt = active and self.options.theme.textDark or self.options.theme.text
        TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = bg}):Play()
        TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {TextColor3 = txt}):Play()
    end

    button.MouseButton1Click:Connect(function()
        if isBinding then return end
        isBinding = true
        self._isCapturingKeybind = true
        button.Text = 'Press any key...'
        setBindVisual(true)
        
        local connection
        connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                connection:Disconnect()
                isBinding = false
                
                if input.KeyCode == Enum.KeyCode.Escape then
                    currentKey = "None"
                    button.Text = 'Bind: None'
                else
                    currentKey = input.KeyCode.Name
                    button.Text = 'Bind: ' .. currentKey
                end
                
                setBindVisual(false)
                -- Prevent immediate UI toggle on this very key press
                self._ignoreNextToggleKeyCode = input.KeyCode
                self._ignoreToggleUntil = os.clock() + 0.2
                -- Defer releasing the capture flag to next frame to avoid race with other listeners
                task.defer(function()
                    self._isCapturingKeybind = false
                end)
                callback(currentKey)
            end
        end)
    end)

    local api = {
        SetValue = function(key)
            currentKey = key
            button.Text = 'Bind: ' .. key
        end,
        GetValue = function()
            return currentKey
        end
    }
    
    -- Element für Config System registrieren
    if window and window.library then
        local tabName = nil
        local windowName = nil
        
        for _, tab in ipairs(window.library.tabs) do
            if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                tabName = tab.frame.Name:gsub("Content", "")
                break
            end
        end
        
        if window.frame and window.frame.Name then
            windowName = window.frame.Name:gsub("Window", "")
        end
        
        window.library:_registerElement("keybind", tabName, windowName, text, api)
    end
    
    return api
end

-- Destroy GUI
function ModernUI:Destroy()
    if self.screenGui then
        self.screenGui:Destroy()
    end
    if self._toggleConn then
        self._toggleConn:Disconnect()
        self._toggleConn = nil
    end
    if self._watermarkUpdateConn then
        self._watermarkUpdateConn:Disconnect()
        self._watermarkUpdateConn = nil
    end
end

-- Toggle GUI
function ModernUI:Toggle()
    if self.mainFrame then
        self.mainFrame.Visible = not self.mainFrame.Visible
    end
end

-- Set Theme
function ModernUI:SetTheme(theme)
    for k, v in pairs(theme) do
        self.options.theme[k] = v
    end
    -- Update primary-dependent elements live
    local primary = self.options.theme.primary
    if self._themeRefs then
        if self._themeRefs.sliderFills then
            for _, fill in ipairs(self._themeRefs.sliderFills) do
                if fill and fill.Parent then fill.BackgroundColor3 = primary end
            end
        end
        if self._themeRefs.dropdownOptionButtons then
            for _, btn in ipairs(self._themeRefs.dropdownOptionButtons) do
                if btn and btn.Parent and btn.BackgroundTransparency == 0 then
                    btn.BackgroundColor3 = primary
                end
            end
        end
        if self._themeRefs.multiDropdownOptionButtons then
            for _, btn in ipairs(self._themeRefs.multiDropdownOptionButtons) do
                if btn and btn.Parent and btn.BackgroundTransparency == 0 then
                    btn.BackgroundColor3 = primary
                end
            end
        end
        if self._themeRefs.licenseLabels then
            for _, lbl in ipairs(self._themeRefs.licenseLabels) do
                if lbl and lbl.Parent then lbl.TextColor3 = primary end
            end
        end
        if self._themeRefs.checkboxUpdaters then
            for _, fn in ipairs(self._themeRefs.checkboxUpdaters) do
                if type(fn) == 'function' then fn() end
            end
        end
    end
    -- Update tabs immediately
    self:_applyTabThemeColors()
end

-- Config Manager Integration Setup
function ModernUI:_setupConfigManagerIntegration()
    -- Automatisches Laden des Config Systems
    task.spawn(function()
        print("[Library] Starting ConfigManager integration...")
        task.wait(0.5) -- Reduced from 2 seconds
        
        local success = pcall(function()
            -- Versuche Config System zu laden
            local ConfigManager = nil
            
            print("[Library] Attempting to load local ConfigSystem...")
            -- Lokales ConfigSystem bevorzugen
            local ok, module = pcall(function()
                return require(script.Parent:WaitForChild("ConfigSystem"))
            end)
            
            if ok and module then
                print("[Library] Local ConfigSystem loaded successfully")
                ConfigManager = module
            else
                print("[Library] Local ConfigSystem failed, trying GitHub fallback...")
                -- Fallback zu GitHub
                local success, result = pcall(function()
                    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Lirum86/Guid/refs/heads/main/Config.lua"))()
                end)
                
                if success and result then
                    print("[Library] GitHub ConfigSystem loaded successfully")
                    ConfigManager = result
                else
                    print("[Library] GitHub ConfigSystem failed")
                end
            end
            
            if ConfigManager then
                print("[Library] Creating ConfigManager instance...")
                self.configManager = ConfigManager.new(self)
                self:_addConfigManagement(self.configManager)
                print("[Library] ConfigManager integration complete")
            else
                print("[Library] No ConfigManager available")
            end
        end)
        
        if not success then
            warn("[Library] ConfigManager integration failed")
        end
    end)
end

-- Config Management zur bestehenden Settings Tab Integration
function ModernUI:_addConfigManagement(configManager)
    -- Stelle ConfigManager für SettingsTab zur Verfügung
    self._configManagerForSettings = configManager
    print("[Library] ConfigManager stored for SettingsTab integration")
    
    -- Debug: ConfigManager verfügbare Methoden anzeigen
    if configManager then
        local methods = {}
        for k, v in pairs(configManager) do
            if type(v) == "function" then
                table.insert(methods, k)
            end
        end
        print("[Library] ConfigManager methods available: " .. table.concat(methods, ", "))
    end
end

-- Element Registry Functions für Config System
function ModernUI:_registerElement(elementType, tabName, windowName, elementName, elementAPI)
    self._elementCounter = self._elementCounter + 1
    local elementId = "element_" .. self._elementCounter
    
    self._elementRegistry[elementId] = {
        id = elementId,
        type = elementType,
        tabName = tabName or "Unknown",
        windowName = windowName or "Unknown", 
        elementName = elementName or "Unknown",
        api = elementAPI,
        path = tabName .. "." .. windowName .. "." .. elementName
    }
    
    print("[Library] Registered element: " .. elementType .. " - " .. (tabName or "Unknown") .. "." .. (windowName or "Unknown") .. "." .. (elementName or "Unknown"))
    
    return elementId
end

function ModernUI:_getAllRegisteredElements()
    return self._elementRegistry
end

function ModernUI:_getElementByPath(tabName, windowName, elementName)
    local path = tabName .. "." .. windowName .. "." .. elementName
    for _, element in pairs(self._elementRegistry) do
        if element.path == path then
            return element
        end
    end
    return nil
end

return ModernUI
