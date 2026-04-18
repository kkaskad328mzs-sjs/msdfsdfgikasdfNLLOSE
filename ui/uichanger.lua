local UIChanger = {}
local ts = game:GetService("TweenService")
local uis = game:GetService("UserInputService")

UIChanger.settings = {
    accentColor = Color3.fromRGB(80,200,120),
    mainBg = Color3.fromRGB(17,17,17),
    secondaryBg = Color3.fromRGB(22,22,22),
    strokeColor = Color3.fromRGB(35,35,35),
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
    titleSize = 14
}

local settingsFrame = nil
local settingsOpen = false

function UIChanger:createSettingsButton(parent)
    local btn = Instance.new("Frame")
    btn.Size = UDim2.new(0,40,0,40)
    btn.Position = UDim2.new(1,-50,1,-50)
    btn.BackgroundColor3 = self.settings.mainBg
    btn.BackgroundTransparency = 0.1
    btn.BorderSizePixel = 0
    btn.Active = true
    btn.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1,0)
    corner.Parent = btn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = self.settings.strokeColor
    stroke.Thickness = 1
    stroke.Parent = btn
    
    local icon = Instance.new("TextLabel")
    icon.Text = "⚙"
    icon.Size = UDim2.new(1,0,1,0)
    icon.BackgroundTransparency = 1
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 20
    icon.TextColor3 = self.settings.accentColor
    icon.Parent = btn
    
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
        ts:Create(settingsFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position = UDim2.new(0.5, -200, 0.3, -250)}):Play()
        task.wait(0.2)
        settingsFrame.Visible = false
        settingsOpen = false
    else
        if not settingsFrame then
            self:createSettingsPanel(parent)
        end
        settingsFrame.Position = UDim2.new(0.5, -200, 0.3, -250)
        settingsFrame.Visible = true
        ts:Create(settingsFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, -200, 0.5, -250)}):Play()
        settingsOpen = true
    end
end

function UIChanger:createSettingsPanel(parent)
    settingsFrame = Instance.new("Frame")
    settingsFrame.Size = UDim2.new(0, 400, 0, 500)
    settingsFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
    settingsFrame.BackgroundColor3 = self.settings.mainBg
    settingsFrame.BorderSizePixel = 0
    settingsFrame.Visible = false
    settingsFrame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = settingsFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = self.settings.accentColor
    stroke.Thickness = 2
    stroke.Parent = settingsFrame
    
    local title = Instance.new("TextLabel")
    title.Text = "UI SETTINGS"
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = self.settings.accentColor
    title.Parent = settingsFrame
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.TextColor3 = self.settings.dimText
    closeBtn.Parent = settingsFrame
    
    closeBtn.MouseButton1Click:Connect(function()
        self:toggleSettings(parent)
    end)
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -50)
    scroll.Position = UDim2.new(0, 10, 0, 40)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = self.settings.accentColor
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = settingsFrame
    
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 10)
    list.Parent = scroll
    
    self:addSection(scroll, "THEME")
    self:addColorPicker(scroll, "Accent Color", self.settings.accentColor, function(c) self.settings.accentColor = c end)
    self:addColorPicker(scroll, "Main Background", self.settings.mainBg, function(c) self.settings.mainBg = c end)
    self:addColorPicker(scroll, "Secondary Background", self.settings.secondaryBg, function(c) self.settings.secondaryBg = c end)
    self:addColorPicker(scroll, "Stroke Color", self.settings.strokeColor, function(c) self.settings.strokeColor = c end)
    self:addColorPicker(scroll, "Text Color", self.settings.textColor, function(c) self.settings.textColor = c end)
    
    self:addSection(scroll, "LAYOUT")
    self:addDropdown(scroll, "Tab Layout", {"horizontal", "vertical"}, self.settings.tabLayout, function(v) self.settings.tabLayout = v end)
    self:addDropdown(scroll, "Column Count", {"1", "2", "3"}, tostring(self.settings.columnCount), function(v) self.settings.columnCount = tonumber(v) end)
    self:addDropdown(scroll, "Tab Style", {"text", "icons"}, self.settings.tabStyle, function(v) self.settings.tabStyle = v end)
    
    self:addSection(scroll, "APPEARANCE")
    self:addSlider(scroll, "Corner Radius", 0, 20, self.settings.cornerRadius, function(v) self.settings.cornerRadius = v end)
    self:addSlider(scroll, "Stroke Thickness", 0, 5, self.settings.strokeThickness, function(v) self.settings.strokeThickness = v end)
    self:addSlider(scroll, "Font Size", 8, 16, self.settings.fontSize, function(v) self.settings.fontSize = v end)
    
    self:addSection(scroll, "BACKGROUND")
    self:addTextbox(scroll, "Image URL/AssetID", self.settings.backgroundImage, function(v) self.settings.backgroundImage = v end)
    self:addSlider(scroll, "Image Transparency", 0, 100, self.settings.backgroundTransparency * 100, function(v) self.settings.backgroundTransparency = v / 100 end)
    
    self:addSection(scroll, "ACTIONS")
    self:addButton(scroll, "Apply Changes", function() self:applySettings() end)
    self:addButton(scroll, "Reset to Default", function() self:resetSettings() end)
    
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

function UIChanger:addSection(parent, text)
    local section = Instance.new("TextLabel")
    section.Text = text
    section.Size = UDim2.new(1, 0, 0, 20)
    section.BackgroundTransparency = 1
    section.Font = Enum.Font.GothamBold
    section.TextSize = 11
    section.TextColor3 = self.settings.accentColor
    section.TextXAlignment = Enum.TextXAlignment.Left
    section.Parent = parent
end

function UIChanger:addColorPicker(parent, text, def, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 20)
    f.BackgroundTransparency = 1
    f.Parent = parent
    
    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(0.7, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = self.settings.dimText
    lbl.Font = Enum.Font.Gotham
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
    
    preview.MouseButton1Click:Connect(function()
        if cb then cb(def) end
    end)
end

function UIChanger:addDropdown(parent, text, opts, def, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 20)
    f.BackgroundTransparency = 1
    f.Parent = parent
    
    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = self.settings.dimText
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.Parent = f
    
    local box = Instance.new("TextButton")
    box.Size = UDim2.new(0.45, 0, 1, 0)
    box.Position = UDim2.new(0.55, 0, 0, 0)
    box.BackgroundColor3 = self.settings.secondaryBg
    box.BorderSizePixel = 0
    box.Text = def
    box.TextColor3 = self.settings.textColor
    box.Font = Enum.Font.Gotham
    box.TextSize = 10
    box.Parent = f
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 3)
    corner.Parent = box
end

function UIChanger:addSlider(parent, text, min, max, def, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 30)
    f.BackgroundTransparency = 1
    f.Parent = parent
    
    local lbl = Instance.new("TextLabel")
    lbl.Text = text .. ": " .. def
    lbl.Size = UDim2.new(1, 0, 0, 12)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = self.settings.dimText
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.Parent = f
    
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 0, 10)
    bg.Position = UDim2.new(0, 0, 0, 16)
    bg.BackgroundColor3 = self.settings.secondaryBg
    bg.BorderSizePixel = 0
    bg.Parent = f
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 3)
    corner.Parent = bg
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((def - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = self.settings.accentColor
    fill.BorderSizePixel = 0
    fill.Parent = bg
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 3)
    fillCorner.Parent = fill
end

function UIChanger:addTextbox(parent, text, def, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 30)
    f.BackgroundTransparency = 1
    f.Parent = parent
    
    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(1, 0, 0, 12)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = self.settings.dimText
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.Parent = f
    
    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(1, 0, 0, 16)
    tb.Position = UDim2.new(0, 0, 0, 14)
    tb.BackgroundColor3 = self.settings.secondaryBg
    tb.BorderSizePixel = 0
    tb.Text = def or ""
    tb.PlaceholderText = "Enter..."
    tb.TextColor3 = self.settings.textColor
    tb.Font = Enum.Font.Gotham
    tb.TextSize = 10
    tb.ClearTextOnFocus = false
    tb.Parent = f
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 3)
    corner.Parent = tb
end

function UIChanger:addButton(parent, text, cb)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 25)
    btn.BackgroundColor3 = self.settings.accentColor
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        if cb then cb() end
    end)
end

function UIChanger:applySettings()
    print("Applying settings...")
end

function UIChanger:resetSettings()
    self.settings = {
        accentColor = Color3.fromRGB(80,200,120),
        mainBg = Color3.fromRGB(17,17,17),
        secondaryBg = Color3.fromRGB(22,22,22),
        strokeColor = Color3.fromRGB(35,35,35),
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
        titleSize = 14
    }
    print("Settings reset to default")
end

return UIChanger
