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
    titleSize = 14
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
                
                local gl2 = Instance.new("Frame")
                gl2.Size = UDim2.new(1,0,0,2)
                gl2.BorderSizePixel = 0
                gl2.Parent = settingsFrame
                
                local glCorner = Instance.new("UICorner")
                glCorner.CornerRadius = UDim.new(0, 8)
                glCorner.Parent = gl2
                
                local ug2 = Instance.new("UIGradient")
                ug2.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0,Color3.fromRGB(255,50,50)),
                    ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,150,50)),
                    ColorSequenceKeypoint.new(0.33,Color3.fromRGB(255,255,50)),
                    ColorSequenceKeypoint.new(0.5,Color3.fromRGB(50,255,50)),
                    ColorSequenceKeypoint.new(0.67,Color3.fromRGB(50,150,255)),
                    ColorSequenceKeypoint.new(0.83,Color3.fromRGB(150,50,255)),
                    ColorSequenceKeypoint.new(1,Color3.fromRGB(255,50,150))
                })
                ug2.Parent = gl2
                
                task.spawn(function()
                    local offset = 0
                    while gl2 and gl2.Parent do
                        offset = (offset + 0.003) % 2
                        ug2.Offset = Vector2.new(offset - 1, 0)
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
                    ts:Create(settingsFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position = UDim2.new(0.5, -250, 0.3, -200)}):Play()
                    task.wait(0.2)
                    settingsFrame.Visible = false
                    settingsOpen = false
                end)
                
                local infoText = Instance.new("TextLabel")
                infoText.Text = "UI Settings panel\nComing soon..."
                infoText.Size = UDim2.new(1, -40, 1, -80)
                infoText.Position = UDim2.new(0, 20, 0, 50)
                infoText.BackgroundTransparency = 1
                infoText.Font = Enum.Font.Gotham
                infoText.TextSize = 14
                infoText.TextColor3 = theme.dim
                infoText.TextWrapped = true
                infoText.Parent = settingsFrame
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
