local UIChanger = {}
local ts = game:GetService("TweenService")
local uis = game:GetService("UserInputService")

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

UIChanger.settings = {
    accentColor = Color3.fromRGB(80,200,120),
    mainBg = Color3.fromRGB(17,17,17),
    secondaryBg = Color3.fromRGB(22,22,22),
    darkBg = Color3.fromRGB(20,20,20),
    strokeColor = Color3.fromRGB(35,35,35),
    textColor = Color3.fromRGB(255,255,255),
    dimText = Color3.fromRGB(150,150,150),
    cornerRadius = 8,
    strokeThickness = 1,
    fontSize = 12,
    titleSize = 14,
    tabLayout = "horizontal",
    columnCount = 2,
    backgroundImage = "",
    backgroundTransparency = 1
}

local function createGradientLine(parent)
    local gl = Instance.new("Frame")
    gl.Size = UDim2.new(1,0,0,2)
    gl.BorderSizePixel = 0
    gl.Parent = parent
    
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
    
    return gl
end

local function addColorOption(parent, text, def, cb)
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
    
    local preview = Instance.new("Frame")
    preview.Size = UDim2.new(0, 60, 0, 18)
    preview.Position = UDim2.new(1, -62, 0, 1)
    preview.BackgroundColor3 = def
    preview.BorderSizePixel = 0
    preview.Parent = f
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 3)
    corner.Parent = preview
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = theme.stroke
    stroke.Thickness = 1
    stroke.Parent = preview
end

local function addSliderOption(parent, text, min, max, def, cb)
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

local function addDropdownOption(parent, text, opts, def, cb)
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

local function addTextboxOption(parent, text, def, cb)
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

local function addButtonOption(parent, text, cb)
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

local function createTab(tabContainer, pageContainer, name, setupFunc)
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
    
    createGradientLine(btn)
    
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
        if settingsOpen then
            ts:Create(settingsFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position = UDim2.new(0.5, -250, 0.3, -200)}):Play()
            task.wait(0.2)
            settingsFrame.Visible = false
            settingsOpen = false
        else
            if not settingsFrame then
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
                
                local stroke2 = Instance.new("UIStroke")
                stroke2.Color = theme.stroke
                stroke2.Thickness = 1
                stroke2.Parent = settingsFrame
                
                createGradientLine(settingsFrame)
                
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
                    ts:Create(settingsFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position = UDim2.new(0.5, -250, 0.3, -200)}):Play()
                    task.wait(0.2)
                    settingsFrame.Visible = false
                    settingsOpen = false
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
                
                createTab(tabContainer, pageContainer, "THEME", function(page)
                    addColorOption(page, "Accent Color", UIChanger.settings.accentColor)
                    addColorOption(page, "Main Background", UIChanger.settings.mainBg)
                    addColorOption(page, "Secondary Background", UIChanger.settings.secondaryBg)
                    addColorOption(page, "Dark Background", UIChanger.settings.darkBg)
                    addColorOption(page, "Stroke Color", UIChanger.settings.strokeColor)
                    addColorOption(page, "Text Color", UIChanger.settings.textColor)
                    addColorOption(page, "Dim Text", UIChanger.settings.dimText)
                end)
                
                createTab(tabContainer, pageContainer, "LAYOUT", function(page)
                    addDropdownOption(page, "Tab Layout", {"horizontal", "vertical"}, UIChanger.settings.tabLayout)
                    addDropdownOption(page, "Column Count", {"1", "2", "3"}, tostring(UIChanger.settings.columnCount))
                end)
                
                createTab(tabContainer, pageContainer, "STYLE", function(page)
                    addSliderOption(page, "Corner Radius", 0, 20, UIChanger.settings.cornerRadius)
                    addSliderOption(page, "Stroke Thickness", 0, 5, UIChanger.settings.strokeThickness)
                    addSliderOption(page, "Font Size", 8, 20, UIChanger.settings.fontSize)
                    addSliderOption(page, "Title Size", 10, 24, UIChanger.settings.titleSize)
                end)
                
                createTab(tabContainer, pageContainer, "BACKGROUND", function(page)
                    addTextboxOption(page, "Image URL/AssetID", UIChanger.settings.backgroundImage)
                    addSliderOption(page, "Image Transparency", 0, 100, UIChanger.settings.backgroundTransparency * 100)
                end)
                
                createTab(tabContainer, pageContainer, "ACTIONS", function(page)
                    addButtonOption(page, "Apply Changes", function() print("Applied!") end)
                    addButtonOption(page, "Reset to Default", function() print("Reset!") end)
                    addButtonOption(page, "Export Config", function() print("Exported!") end)
                    addButtonOption(page, "Import Config", function() print("Imported!") end)
                end)
            end
            settingsFrame.Position = UDim2.new(0.5, -250, 0.3, -200)
            settingsFrame.Visible = true
            ts:Create(settingsFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, -250, 0.5, -200)}):Play()
            settingsOpen = true
        end
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

return UIChanger
