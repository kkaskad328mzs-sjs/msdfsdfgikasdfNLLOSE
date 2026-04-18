local UIChanger = {}
local ts = game:GetService("TweenService")
local uis = game:GetService("UserInputService")

UIChanger.settings = {
    accentColor = Color3.fromRGB(80,200,120),
    mainBg = Color3.fromRGB(17,17,17),
    secondaryBg = Color3.fromRGB(22,22,22),
    darkBg = Color3.fromRGB(20,20,20),
    darkerBg = Color3.fromRGB(15,15,15),
    strokeColor = Color3.fromRGB(35,35,35),
    borderColor = Color3.fromRGB(40,40,40),
    textColor = Color3.fromRGB(255,255,255),
    dimText = Color3.fromRGB(150,150,150),
    cornerRadius = 8,
    tabLayout = "horizontal",
    columnCount = 2,
    tabStyle = "text",
    backgroundImage = "",
    backgroundTransparency = 1,
    strokeThickness = 1,
    fontSize = 12,
    titleSize = 14,
    tabCornerRadius = 5,
    elementCornerRadius = 3,
    windowTransparency = 0,
    titleColor = Color3.fromRGB(80,200,120)
}

local settingsFrame = nil
local settingsOpen = false
local theme = {
    main=Color3.fromRGB(17,17,17),
    darker=Color3.fromRGB(15,15,15),
    dark=Color3.fromRGB(20,20,20),
    stroke=Color3.fromRGB(35,35,35),
    accent=Color3.fromRGB(80,200,120),
    text=Color3.fromRGB(255,255,255),
    dim=Color3.fromRGB(150,150,150),
    font=Enum.Font.Gotham
}

function UIChanger:createSettingsButton(parent)
    local btn = Instance.new("Frame")
    btn.Size = UDim2.new(0,80,0,22)
    btn.Position = UDim2.new(1,-90,0,42)
    btn.BackgroundColor3 = theme.main
    btn.BackgroundTransparency = 0.1
    btn.BorderSizePixel = 0
    btn.Active = true
    btn.Parent = parent
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = theme.stroke
    stroke.Thickness = 1
    stroke.Parent = btn
    
    local gl = Instance.new("Frame")
    gl.Size = UDim2.new(1,0,0,2)
    gl.BorderSizePixel = 0
    gl.Parent = btn
    
    local ug = Instance.new("UIGradient")
    ug.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(255,50,50)),
        ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,150,50)),
        ColorSequenceKeypoint.new(0.33,Color3.fromRGB(255,255,50)),
        ColorSequenceKeypoint.new(0.5,Color3.fromRGB(50,255,50)),
        ColorSequenceKeypoint.new(0.67,Color3.fromRGB(50,150,255)),
        ColorSequenceKeypoint.new(0.83,Color3.fromRGB(150,50,255)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(255,50,150))
    })
    ug.Parent = gl
    
    task.spawn(function()
        local offset = 0
        while gl and gl.Parent do
            offset = (offset + 0.003) % 2
            ug.Offset = Vector2.new(offset - 1, 0)
            task.wait()
        end
    end)
    
    local txt = Instance.new("TextLabel")
    txt.Text = "settings"
    txt.Size = UDim2.new(1,-10,1,-2)
    txt.Position = UDim2.new(0,5,0,2)
    txt.BackgroundTransparency = 1
    txt.Font = theme.font
    txt.TextSize = 11
    txt.TextColor3 = theme.text
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Parent = btn
    
    local clickBtn = Instance.new("TextButton")
    clickBtn.Size = UDim2.new(1,0,1,0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text = ""
    clickBtn.Parent = btn
    
    clickBtn.MouseButton1Click:Connect(function()
        self:toggleSettings(parent)
    end)
    
    local drag = false
    local dragStart = nil
    local startPos = nil
    
    btn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            dragStart = Vector2.new(i.Position.X, i.Position.Y)
            startPos = btn.AbsolutePosition
        end
    end)
    
    btn.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement and drag then
            local delta = Vector2.new(i.Position.X, i.Position.Y) - dragStart
            local newPos = startPos + delta
            btn.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
        end
    end)
    
    uis.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = false
        end
    end)
    
    return btn
end

function UIChanger:toggleSettings(parent)
    if settingsOpen then
        ts:Create(settingsFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position = UDim2.new(0.5, -250, 0.3, -200)}):Play()
        task.wait(0.2)
        settingsFrame.Visible = false
        settingsOpen = false
    else
        if not settingsFrame then
            self:createSettingsPanel(parent)
        end
        settingsFrame.Position = UDim2.new(0.5, -250, 0.3, -200)
        settingsFrame.Visible = true
        ts:Create(settingsFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, -250, 0.5, -200)}):Play()
        settingsOpen = true
    end
end

return UIChanger


function UIChanger:createSettingsPanel(parent)
    settingsFrame = Instance.new("Frame")
    settingsFrame.Size = UDim2.new(0, 500, 0, 400)
    settingsFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
    settingsFrame.BackgroundColor3 = theme.main
    settingsFrame.BorderSizePixel = 0
    settingsFrame.Visible = false
    settingsFrame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = settingsFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = theme.stroke
    stroke.Thickness = 1
    stroke.Parent = settingsFrame
    
    local gl = Instance.new("Frame")
    gl.Size = UDim2.new(1,0,0,2)
    gl.BorderSizePixel = 0
    gl.Parent = settingsFrame
    
    local glCorner = Instance.new("UICorner")
    glCorner.CornerRadius = UDim.new(0, 8)
    glCorner.Parent = gl
    
    local ug = Instance.new("UIGradient")
    ug.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(255,50,50)),
        ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,150,50)),
        ColorSequenceKeypoint.new(0.33,Color3.fromRGB(255,255,50)),
        ColorSequenceKeypoint.new(0.5,Color3.fromRGB(50,255,50)),
        ColorSequenceKeypoint.new(0.67,Color3.fromRGB(50,150,255)),
        ColorSequenceKeypoint.new(0.83,Color3.fromRGB(150,50,255)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(255,50,150))
    })
    ug.Parent = gl
    
    task.spawn(function()
        local offset = 0
        while gl and gl.Parent do
            offset = (offset + 0.003) % 2
            ug.Offset = Vector2.new(offset - 1, 0)
            task.wait()
        end
    end)
    
    local title = Instance.new("TextLabel")
    title.Text = "UI SETTINGS"
    title.Size = UDim2.new(0, 200, 0, 24)
    title.Position = UDim2.new(0, 12, 0, 8)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = theme.accent
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = settingsFrame
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.TextColor3 = theme.dim
    closeBtn.Parent = settingsFrame
    
    closeBtn.MouseButton1Click:Connect(function()
        self:toggleSettings(parent)
    end)
    
    local tabContainer = Instance.new("Frame")
    tabContainer.Size = UDim2.new(1, -20, 0, 30)
    tabContainer.Position = UDim2.new(0, 10, 0, 38)
    tabContainer.BackgroundColor3 = theme.darker
    tabContainer.BorderSizePixel = 0
    tabContainer.Parent = settingsFrame
    
    local tcCorner = Instance.new("UICorner")
    tcCorner.CornerRadius = UDim.new(0, 5)
    tcCorner.Parent = tabContainer
    
    local tcStroke = Instance.new("UIStroke")
    tcStroke.Color = theme.stroke
    tcStroke.Thickness = 1
    tcStroke.Parent = tabContainer
    
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Padding = UDim.new(0, 5)
    tabLayout.Parent = tabContainer
    
    local tabPadding = Instance.new("UIPadding")
    tabPadding.PaddingLeft = UDim.new(0, 5)
    tabPadding.PaddingRight = UDim.new(0, 5)
    tabPadding.PaddingTop = UDim.new(0, 3)
    tabPadding.PaddingBottom = UDim.new(0, 3)
    tabPadding.Parent = tabContainer
    
    local pageContainer = Instance.new("Frame")
    pageContainer.Size = UDim2.new(1, -20, 1, -84)
    pageContainer.Position = UDim2.new(0, 10, 0, 76)
    pageContainer.BackgroundTransparency = 1
    pageContainer.Parent = settingsFrame
    
    self:createTab(tabContainer, pageContainer, "THEME", function(page)
        self:addColorOption(page, "Accent Color", self.settings.accentColor, function(c) self.settings.accentColor = c end)
        self:addColorOption(page, "Main Background", self.settings.mainBg, function(c) self.settings.mainBg = c end)
        self:addColorOption(page, "Secondary Background", self.settings.secondaryBg, function(c) self.settings.secondaryBg = c end)
        self:addColorOption(page, "Dark Background", self.settings.darkBg, function(c) self.settings.darkBg = c end)
        self:addColorOption(page, "Darker Background", self.settings.darkerBg, function(c) self.settings.darkerBg = c end)
        self:addColorOption(page, "Stroke Color", self.settings.strokeColor, function(c) self.settings.strokeColor = c end)
        self:addColorOption(page, "Border Color", self.settings.borderColor, function(c) self.settings.borderColor = c end)
        self:addColorOption(page, "Text Color", self.settings.textColor, function(c) self.settings.textColor = c end)
        self:addColorOption(page, "Dim Text", self.settings.dimText, function(c) self.settings.dimText = c end)
        self:addColorOption(page, "Title Color", self.settings.titleColor, function(c) self.settings.titleColor = c end)
    end)
    
    self:createTab(tabContainer, pageContainer, "LAYOUT", function(page)
        self:addDropdownOption(page, "Tab Layout", {"horizontal", "vertical"}, self.settings.tabLayout, function(v) self.settings.tabLayout = v end)
        self:addDropdownOption(page, "Column Count", {"1", "2", "3"}, tostring(self.settings.columnCount), function(v) self.settings.columnCount = tonumber(v) end)
        self:addDropdownOption(page, "Tab Style", {"text", "icons"}, self.settings.tabStyle, function(v) self.settings.tabStyle = v end)
    end)
    
    self:createTab(tabContainer, pageContainer, "STYLE", function(page)
        self:addSliderOption(page, "Corner Radius", 0, 20, self.settings.cornerRadius, function(v) self.settings.cornerRadius = v end)
        self:addSliderOption(page, "Tab Corner Radius", 0, 10, self.settings.tabCornerRadius, function(v) self.settings.tabCornerRadius = v end)
        self:addSliderOption(page, "Element Corner Radius", 0, 10, self.settings.elementCornerRadius, function(v) self.settings.elementCornerRadius = v end)
        self:addSliderOption(page, "Stroke Thickness", 0, 5, self.settings.strokeThickness, function(v) self.settings.strokeThickness = v end)
        self:addSliderOption(page, "Font Size", 8, 20, self.settings.fontSize, function(v) self.settings.fontSize = v end)
        self:addSliderOption(page, "Title Size", 10, 24, self.settings.titleSize, function(v) self.settings.titleSize = v end)
        self:addSliderOption(page, "Window Transparency", 0, 100, self.settings.windowTransparency * 100, function(v) self.settings.windowTransparency = v / 100 end)
    end)
    
    self:createTab(tabContainer, pageContainer, "BACKGROUND", function(page)
        self:addTextboxOption(page, "Image URL/AssetID", self.settings.backgroundImage, function(v) self.settings.backgroundImage = v end)
        self:addSliderOption(page, "Image Transparency", 0, 100, self.settings.backgroundTransparency * 100, function(v) self.settings.backgroundTransparency = v / 100 end)
    end)
    
    self:createTab(tabContainer, pageContainer, "ACTIONS", function(page)
        self:addButtonOption(page, "Apply Changes", function() self:applySettings() end)
        self:addButtonOption(page, "Reset to Default", function() self:resetSettings() end)
        self:addButtonOption(page, "Export Config", function() print("Config exported!") end)
        self:addButtonOption(page, "Import Config", function() print("Config imported!") end)
    end)
    
    local drag = false
    local dragStart = nil
    local startPos = nil
    
    settingsFrame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            local mousePos = Vector2.new(i.Position.X, i.Position.Y)
            local framePos = settingsFrame.AbsolutePosition
            if mousePos.Y < framePos.Y + 35 then
                drag = true
                dragStart = mousePos
                startPos = settingsFrame.AbsolutePosition
            end
        end
    end)
    
    uis.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement and drag then
            local delta = Vector2.new(i.Position.X, i.Position.Y) - dragStart
            local newPos = startPos + delta
            settingsFrame.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
        end
    end)
    
    uis.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = false
        end
    end)
end


function UIChanger:createTab(tabContainer, pageContainer, name, setupFunc)
    local btn = Instance.new("TextButton")
    btn.Text = name
    btn.Size = UDim2.new(0, 85, 1, 0)
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextColor3 = theme.dim
    btn.Parent = tabContainer
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn
    
    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(1, -4, 0, 2)
    indicator.Position = UDim2.new(0, 2, 1, -2)
    indicator.BackgroundColor3 = theme.accent
    indicator.BorderSizePixel = 0
    indicator.Visible = false
    indicator.Parent = btn
    
    local indCorner = Instance.new("UICorner")
    indCorner.CornerRadius = UDim.new(1, 0)
    indCorner.Parent = indicator
    
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = theme.accent
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Parent = pageContainer
    
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 10)
    list.Parent = page
    
    btn.MouseButton1Click:Connect(function()
        for _, p in ipairs(pageContainer:GetChildren()) do p.Visible = false end
        for _, tb in ipairs(tabContainer:GetChildren()) do
            if tb:IsA("TextButton") then
                tb.TextColor3 = theme.dim
                tb.BackgroundTransparency = 1
                local ind = tb:FindFirstChild("Frame")
                if ind then ind.Visible = false end
            end
        end
        page.Visible = true
        btn.TextColor3 = theme.accent
        btn.BackgroundTransparency = 0.95
        btn.BackgroundColor3 = theme.accent
        indicator.Visible = true
    end)
    
    if #tabContainer:GetChildren() == 3 then
        page.Visible = true
        btn.TextColor3 = theme.accent
        btn.BackgroundTransparency = 0.95
        btn.BackgroundColor3 = theme.accent
        indicator.Visible = true
    end
    
    if setupFunc then setupFunc(page) end
end

function UIChanger:addColorOption(parent, text, def, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 20)
    f.BackgroundTransparency = 1
    f.Parent = parent
    
    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(0.7, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = theme.dim
    lbl.Font = theme.font
    lbl.TextSize = 11
    lbl.Parent = f
    
    local preview = Instance.new("TextButton")
    preview.Size = UDim2.new(0, 60, 0, 18)
    preview.Position = UDim2.new(1, -62, 0, 1)
    preview.BackgroundColor3 = def
    preview.BorderSizePixel = 0
    preview.Text = ""
    preview.Parent = f
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 3)
    corner.Parent = preview
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = theme.stroke
    stroke.Thickness = 1
    stroke.Parent = preview
    
    local picker = nil
    local open = false
    
    preview.MouseButton1Click:Connect(function()
        open = not open
        if open then
            if not picker then
                picker = self:createColorPicker(preview, def, function(c)
                    preview.BackgroundColor3 = c
                    if cb then cb(c) end
                end)
            end
            local absPos = preview.AbsolutePosition
            picker.Position = UDim2.new(0, absPos.X - 70, 0, absPos.Y + 22)
            picker.Size = UDim2.new(0, 0, 0, 0)
            picker.Visible = true
            ts:Create(picker, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 140, 0, 160)}):Play()
        else
            ts:Create(picker, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)}):Play()
            task.wait(0.15)
            picker.Visible = false
        end
    end)
end

function UIChanger:createColorPicker(parent, def, cb)
    local picker = Instance.new("Frame")
    picker.Size = UDim2.new(0, 140, 0, 160)
    picker.BackgroundColor3 = theme.darker
    picker.BorderSizePixel = 0
    picker.Visible = false
    picker.ClipsDescendants = true
    picker.ZIndex = 200
    picker.Parent = parent.Parent.Parent.Parent.Parent
    
    local pkCorner = Instance.new("UICorner")
    pkCorner.CornerRadius = UDim.new(0, 5)
    pkCorner.Parent = picker
    
    local pkStroke = Instance.new("UIStroke")
    pkStroke.Color = theme.stroke
    pkStroke.Thickness = 1
    pkStroke.Parent = picker
    
    local wheel = Instance.new("ImageLabel")
    wheel.Size = UDim2.new(0, 120, 0, 120)
    wheel.Position = UDim2.new(0, 10, 0, 10)
    wheel.BackgroundTransparency = 1
    wheel.Image = "rbxassetid://698052001"
    wheel.ZIndex = 201
    wheel.Parent = picker
    
    local alphaSlider = Instance.new("Frame")
    alphaSlider.Size = UDim2.new(0, 120, 0, 12)
    alphaSlider.Position = UDim2.new(0, 10, 0, 138)
    alphaSlider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    alphaSlider.BorderSizePixel = 0
    alphaSlider.ZIndex = 201
    alphaSlider.Parent = picker
    
    local asCorner = Instance.new("UICorner")
    asCorner.CornerRadius = UDim.new(0, 3)
    asCorner.Parent = alphaSlider
    
    local asGrad = Instance.new("UIGradient")
    asGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1)
    })
    asGrad.Parent = alphaSlider
    
    local alphaFill = Instance.new("Frame")
    alphaFill.Size = UDim2.new(1, 0, 1, 0)
    alphaFill.BackgroundColor3 = def
    alphaFill.BorderSizePixel = 0
    alphaFill.ZIndex = 200
    alphaFill.Parent = alphaSlider
    
    local afCorner = Instance.new("UICorner")
    afCorner.CornerRadius = UDim.new(0, 3)
    afCorner.Parent = alphaFill
    
    local curColor = def
    local curAlpha = 1
    
    wheel.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            local function update()
                local mp = uis:GetMouseLocation()
                local center = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
                local delta = mp - center
                local angle = math.atan2(delta.Y, delta.X)
                local dist = math.min((delta.Magnitude / (wheel.AbsoluteSize.X / 2)), 1)
                local hue = (angle + math.pi) / (2 * math.pi)
                curColor = Color3.fromHSV(hue, dist, 1)
                alphaFill.BackgroundColor3 = curColor
                if cb then cb(curColor) end
            end
            update()
            local conn
            conn = uis.InputChanged:Connect(function(i2)
                if i2.UserInputType == Enum.UserInputType.MouseMovement then
                    update()
                end
            end)
            local endConn
            endConn = uis.InputEnded:Connect(function(i2)
                if i2.UserInputType == Enum.UserInputType.MouseButton1 then
                    conn:Disconnect()
                    endConn:Disconnect()
                end
            end)
        end
    end)
    
    alphaSlider.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            local function update()
                local mp = uis:GetMouseLocation()
                local rel = math.clamp((mp.X - alphaSlider.AbsolutePosition.X) / alphaSlider.AbsoluteSize.X, 0, 1)
                curAlpha = 1 - rel
            end
            update()
            local conn
            conn = uis.InputChanged:Connect(function(i2)
                if i2.UserInputType == Enum.UserInputType.MouseMovement then
                    update()
                end
            end)
            local endConn
            endConn = uis.InputEnded:Connect(function(i2)
                if i2.UserInputType == Enum.UserInputType.MouseButton1 then
                    conn:Disconnect()
                    endConn:Disconnect()
                end
            end)
        end
    end)
    
    return picker
end

function UIChanger:addDropdownOption(parent, text, opts, def, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 20)
    f.BackgroundTransparency = 1
    f.Parent = parent
    
    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = theme.dim
    lbl.Font = theme.font
    lbl.TextSize = 11
    lbl.Parent = f
    
    local box = Instance.new("TextButton")
    box.Size = UDim2.new(0.45, 0, 1, 0)
    box.Position = UDim2.new(0.55, 0, 0, 0)
    box.BackgroundColor3 = theme.dark
    box.BorderSizePixel = 0
    box.Text = def
    box.TextColor3 = theme.text
    box.Font = theme.font
    box.TextSize = 10
    box.Parent = f
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 3)
    corner.Parent = box
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = theme.stroke
    stroke.Thickness = 1
    stroke.Parent = box
end

function UIChanger:addSliderOption(parent, text, min, max, def, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 30)
    f.BackgroundTransparency = 1
    f.Parent = parent
    
    local lbl = Instance.new("TextLabel")
    lbl.Text = text .. ": " .. def
    lbl.Size = UDim2.new(1, 0, 0, 12)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = theme.dim
    lbl.Font = theme.font
    lbl.TextSize = 11
    lbl.Parent = f
    
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 0, 10)
    bg.Position = UDim2.new(0, 0, 0, 16)
    bg.BackgroundColor3 = theme.dark
    bg.BorderSizePixel = 0
    bg.Parent = f
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 3)
    corner.Parent = bg
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = theme.stroke
    stroke.Thickness = 1
    stroke.Parent = bg
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((def - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = theme.accent
    fill.BorderSizePixel = 0
    fill.Parent = bg
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 3)
    fillCorner.Parent = fill
end

function UIChanger:addTextboxOption(parent, text, def, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 30)
    f.BackgroundTransparency = 1
    f.Parent = parent
    
    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(1, 0, 0, 12)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = theme.dim
    lbl.Font = theme.font
    lbl.TextSize = 11
    lbl.Parent = f
    
    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(1, 0, 0, 16)
    tb.Position = UDim2.new(0, 0, 0, 14)
    tb.BackgroundColor3 = theme.dark
    tb.BorderSizePixel = 0
    tb.Text = def or ""
    tb.PlaceholderText = "Enter..."
    tb.TextColor3 = theme.text
    tb.Font = theme.font
    tb.TextSize = 10
    tb.ClearTextOnFocus = false
    tb.Parent = f
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 3)
    corner.Parent = tb
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = theme.stroke
    stroke.Thickness = 1
    stroke.Parent = tb
end

function UIChanger:addButtonOption(parent, text, cb)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 25)
    btn.BackgroundColor3 = theme.dark
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = theme.text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = theme.stroke
    stroke.Thickness = 1
    stroke.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        if cb then cb() end
    end)
end

function UIChanger:applySettings()
    print("Applying settings...")
    print("Accent Color:", self.settings.accentColor)
    print("Corner Radius:", self.settings.cornerRadius)
end

function UIChanger:resetSettings()
    self.settings = {
        accentColor = Color3.fromRGB(80,200,120),
        mainBg = Color3.fromRGB(17,17,17),
        secondaryBg = Color3.fromRGB(22,22,22),
        darkBg = Color3.fromRGB(20,20,20),
        darkerBg = Color3.fromRGB(15,15,15),
        strokeColor = Color3.fromRGB(35,35,35),
        borderColor = Color3.fromRGB(40,40,40),
        textColor = Color3.fromRGB(255,255,255),
        dimText = Color3.fromRGB(150,150,150),
        cornerRadius = 8,
        tabLayout = "horizontal",
        columnCount = 2,
        tabStyle = "text",
        backgroundImage = "",
        backgroundTransparency = 1,
        strokeThickness = 1,
        fontSize = 12,
        titleSize = 14,
        tabCornerRadius = 5,
        elementCornerRadius = 3,
        windowTransparency = 0,
        titleColor = Color3.fromRGB(80,200,120)
    }
    print("Settings reset to default")
end
