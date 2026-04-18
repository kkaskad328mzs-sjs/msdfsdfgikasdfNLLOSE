local lib = {}
lib.runtime = {gui=nil,main=nil,drag=false,dragStart=nil,startPos=nil,conns={},sliderDrag=nil}
lib.theme = {
    main=Color3.fromRGB(17,17,17),group=Color3.fromRGB(22,22,22),stroke=Color3.fromRGB(35,35,35),
    accent=Color3.fromRGB(80,200,120),text=Color3.fromRGB(255,255,255),dim=Color3.fromRGB(150,150,150),
    font=Enum.Font.Gotham,dark=Color3.fromRGB(20,20,20),darker=Color3.fromRGB(15,15,15),border=Color3.fromRGB(40,40,40),
    accentDark=Color3.fromRGB(50,160,90),tabActive=Color3.fromRGB(25,25,25)
}
local t=lib.theme
local r=lib.runtime
local uis=game:GetService("UserInputService")

function lib:create(title)
    local coreGui=game:GetService("CoreGui")
    local oldGui=coreGui:FindFirstChild("Arc")
    if oldGui then oldGui:Destroy() end
    if r.gui then r.gui:Destroy() end
    r.gui=Instance.new("ScreenGui")
    r.gui.Name="Arc"
    r.gui.ResetOnSpawn=false
    r.gui.Parent=coreGui
    
    local w=Instance.new("Frame")
    w.Name="M"
    w.Size=UDim2.new(0,580,0,420)
    w.Position=UDim2.new(0.5,-290,0.5,-210)
    w.BackgroundColor3=t.main
    w.BorderSizePixel=0
    w.Parent=r.gui
    r.main=w
    
    local wCorner=Instance.new("UICorner")
    wCorner.CornerRadius=UDim.new(0,8)
    wCorner.Parent=w
    
    local s=Instance.new("UIStroke")
    s.Color=t.border
    s.Thickness=1
    s.Parent=w
    
    local gl=Instance.new("Frame")
    gl.Size=UDim2.new(1,0,0,2)
    gl.Position=UDim2.new(0,0,0,0)
    gl.BorderSizePixel=0
    gl.BackgroundColor3=t.accent
    gl.Parent=w
    
    local glCorner=Instance.new("UICorner")
    glCorner.CornerRadius=UDim.new(0,8)
    glCorner.Parent=gl
    
    local ug=Instance.new("UIGradient")
    ug.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(255,50,50)),
        ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,150,50)),
        ColorSequenceKeypoint.new(0.33,Color3.fromRGB(255,255,50)),
        ColorSequenceKeypoint.new(0.5,Color3.fromRGB(50,255,50)),
        ColorSequenceKeypoint.new(0.67,Color3.fromRGB(50,150,255)),
        ColorSequenceKeypoint.new(0.83,Color3.fromRGB(150,50,255)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(255,50,150))
    })
    ug.Parent=gl
    
    task.spawn(function()
        local offset=0
        while gl and gl.Parent do
            offset=(offset+0.005)%1
            ug.Offset=Vector2.new(offset,0)
            task.wait(0.03)
        end
    end)
    
    local tl=Instance.new("TextLabel")
    tl.Text=title:upper()
    tl.Size=UDim2.new(0,200,0,24)
    tl.Position=UDim2.new(0,12,0,8)
    tl.BackgroundTransparency=1
    tl.Font=Enum.Font.GothamBold
    tl.TextSize=14
    tl.TextColor3=t.accent
    tl.TextXAlignment=Enum.TextXAlignment.Left
    tl.Parent=w
    
    local tc=Instance.new("Frame")
    tc.Size=UDim2.new(1,-20,0,30)
    tc.Position=UDim2.new(0,10,0,38)
    tc.BackgroundColor3=t.darker
    tc.BorderSizePixel=0
    tc.Parent=w
    
    local tcCorner=Instance.new("UICorner")
    tcCorner.CornerRadius=UDim.new(0,5)
    tcCorner.Parent=tc
    
    local tcStroke=Instance.new("UIStroke")
    tcStroke.Color=t.stroke
    tcStroke.Thickness=1
    tcStroke.Parent=tc
    
    local tlay=Instance.new("UIListLayout")
    tlay.FillDirection=Enum.FillDirection.Horizontal
    tlay.HorizontalAlignment=Enum.HorizontalAlignment.Center
    tlay.VerticalAlignment=Enum.VerticalAlignment.Center
    tlay.Padding=UDim.new(0,5)
    tlay.Parent=tc
    
    local tcPadding=Instance.new("UIPadding")
    tcPadding.PaddingLeft=UDim.new(0,5)
    tcPadding.PaddingRight=UDim.new(0,5)
    tcPadding.PaddingTop=UDim.new(0,3)
    tcPadding.PaddingBottom=UDim.new(0,3)
    tcPadding.Parent=tc
    
    local pc=Instance.new("Frame")
    pc.Size=UDim2.new(1,-20,1,-84)
    pc.Position=UDim2.new(0,10,0,76)
    pc.BackgroundTransparency=1
    pc.Parent=w
    
    w.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 and i.Position.Y<w.AbsolutePosition.Y+30 then
            r.drag=true
            r.dragStart=i.Position
            r.startPos=w.Position
        end
    end)
    
    w.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement and r.drag then
            local d=i.Position-r.dragStart
            w.Position=UDim2.new(r.startPos.X.Scale,r.startPos.X.Offset+d.X,r.startPos.Y.Scale,r.startPos.Y.Offset+d.Y)
        end
    end)
    
    table.insert(r.conns,uis.InputChanged:Connect(function(i)
        if r.sliderDrag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=r.sliderDrag
            local rel=math.clamp((i.Position.X-d.bg.AbsolutePosition.X)/d.bg.AbsoluteSize.X,0,1)
            d.val=math.floor(d.min+(d.max-d.min)*rel)
            d.fill.Size=UDim2.new(rel,0,1,0)
            d.lbl.Text=d.text..": "..d.val
            if d.cb then d.cb(d.val) end
        end
    end))
    
    table.insert(r.conns,uis.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            r.drag=false
            r.sliderDrag=nil
        end
    end))
    
    local tabs={}
    function tabs:newtab(name)
        local btn=Instance.new("TextButton")
        btn.Text=name:upper()
        btn.Size=UDim2.new(0,85,1,0)
        btn.BackgroundColor3=Color3.fromRGB(0,0,0)
        btn.BackgroundTransparency=1
        btn.BorderSizePixel=0
        btn.Font=Enum.Font.GothamBold
        btn.TextSize=10
        btn.TextColor3=t.dim
        btn.Parent=tc
        
        local btnCorner=Instance.new("UICorner")
        btnCorner.CornerRadius=UDim.new(0,4)
        btnCorner.Parent=btn
        
        local indicator=Instance.new("Frame")
        indicator.Size=UDim2.new(1,-4,0,2)
        indicator.Position=UDim2.new(0,2,1,-2)
        indicator.BackgroundColor3=t.accent
        indicator.BorderSizePixel=0
        indicator.Visible=false
        indicator.Parent=btn
        
        local indCorner=Instance.new("UICorner")
        indCorner.CornerRadius=UDim.new(1,0)
        indCorner.Parent=indicator
        
        local page=Instance.new("ScrollingFrame")
        page.Size=UDim2.new(1,0,1,0)
        page.BackgroundTransparency=1
        page.Visible=false
        page.BorderSizePixel=0
        page.ScrollBarThickness=4
        page.ScrollBarImageColor3=t.accent
        page.ScrollingDirection=Enum.ScrollingDirection.Y
        page.CanvasSize=UDim2.new(0,0,0,0)
        page.AutomaticCanvasSize=Enum.AutomaticSize.Y
        page.Parent=pc
        
        local lc=Instance.new("Frame")
        lc.Size=UDim2.new(0.48,0,0,0)
        lc.BackgroundTransparency=1
        lc.AutomaticSize=Enum.AutomaticSize.Y
        lc.Parent=page
        local ll=Instance.new("UIListLayout")
        ll.Padding=UDim.new(0,12)
        ll.Parent=lc
        
        local rc=Instance.new("Frame")
        rc.Size=UDim2.new(0.48,0,0,0)
        rc.Position=UDim2.new(0.52,0,0,0)
        rc.BackgroundTransparency=1
        rc.AutomaticSize=Enum.AutomaticSize.Y
        rc.Parent=page
        local rl=Instance.new("UIListLayout")
        rl.Padding=UDim.new(0,12)
        rl.Parent=rc
        
        btn.MouseButton1Click:Connect(function()
            for _,p in ipairs(pc:GetChildren()) do p.Visible=false end
            for _,tb in ipairs(tc:GetChildren()) do
                if tb:IsA("TextButton") then 
                    tb.TextColor3=t.dim
                    tb.BackgroundTransparency=1
                    local ind=tb:FindFirstChild("Frame")
                    if ind then ind.Visible=false end
                end
            end
            page.Visible=true
            btn.TextColor3=t.accent
            btn.BackgroundTransparency=0.95
            btn.BackgroundColor3=t.accent
            indicator.Visible=true
        end)
        
        if #tc:GetChildren()==5 then
            page.Visible=true
            btn.TextColor3=t.accent
            btn.BackgroundTransparency=0.95
            btn.BackgroundColor3=t.accent
            indicator.Visible=true
        end
        
        local tl={}
        function tl:newgroupbox(side,gtitle)
            local col=side=="Right" and rc or lc
            local grp=Instance.new("Frame")
            grp.Size=UDim2.new(1,0,0,0)
            grp.BackgroundTransparency=1
            grp.AutomaticSize=Enum.AutomaticSize.Y
            grp.Parent=col
            
            local brd=Instance.new("Frame")
            brd.Size=UDim2.new(1,0,0,0)
            brd.Position=UDim2.new(0,0,0,8)
            brd.BackgroundColor3=t.main
            brd.BorderColor3=t.stroke
            brd.AutomaticSize=Enum.AutomaticSize.Y
            brd.Parent=grp
            
            local ttl=Instance.new("TextLabel")
            ttl.Text=gtitle:upper()
            ttl.Position=UDim2.new(0,10,0,12)
            ttl.AutomaticSize=Enum.AutomaticSize.X
            ttl.BackgroundColor3=t.main
            ttl.BorderSizePixel=0
            ttl.TextColor3=t.accent
            ttl.Font=Enum.Font.GothamBold
            ttl.TextSize=11
            ttl.ZIndex=2
            ttl.Parent=grp
            
            local cnt=Instance.new("Frame")
            cnt.Size=UDim2.new(1,-16,0,0)
            cnt.Position=UDim2.new(0,8,0,22)
            cnt.BackgroundTransparency=1
            cnt.AutomaticSize=Enum.AutomaticSize.Y
            cnt.Parent=brd
            local cl=Instance.new("UIListLayout")
            cl.Padding=UDim.new(0,8)
            cl.Parent=cnt
            local pd=Instance.new("UIPadding")
            pd.PaddingBottom=UDim.new(0,8)
            pd.Parent=brd
            
            local g={}
            function g:toggle(text,def,cb)
                local f=Instance.new("Frame")
                f.Size=UDim2.new(1,0,0,18)
                f.BackgroundTransparency=1
                f.Parent=cnt
                
                local box=Instance.new("Frame")
                box.Size=UDim2.new(0,14,0,14)
                box.Position=UDim2.new(0,0,0,2)
                box.BackgroundColor3=t.dark
                box.Parent=f
                
                local boxCorner=Instance.new("UICorner")
                boxCorner.CornerRadius=UDim.new(0,3)
                boxCorner.Parent=box
                
                local bs=Instance.new("UIStroke")
                bs.Color=t.stroke
                bs.Parent=box
                
                local lbl=Instance.new("TextLabel")
                lbl.Text=text
                lbl.Size=UDim2.new(1,-20,1,0)
                lbl.Position=UDim2.new(0,20,0,0)
                lbl.BackgroundTransparency=1
                lbl.TextXAlignment=Enum.TextXAlignment.Left
                lbl.TextColor3=t.dim
                lbl.Font=t.font
                lbl.TextSize=12
                lbl.Parent=f
                
                local b=Instance.new("TextButton")
                b.Size=UDim2.new(1,0,1,0)
                b.BackgroundTransparency=1
                b.Text=""
                b.Parent=f
                
                local en=def
                local function upd()
                    box.BackgroundColor3=en and t.accent or t.dark
                    bs.Color=en and t.accent or t.stroke
                    lbl.TextColor3=en and t.text or t.dim
                    if cb then cb(en) end
                end
                
                b.MouseButton1Click:Connect(function()
                    en=not en
                    upd()
                end)
                upd()
                return g
            end
            
            function g:slider(text,min,max,def,cb)
                local f=Instance.new("Frame")
                f.Size=UDim2.new(1,0,0,35)
                f.BackgroundTransparency=1
                f.Parent=cnt
                
                local lbl=Instance.new("TextLabel")
                lbl.Text=text..": "..def
                lbl.Size=UDim2.new(1,0,0,15)
                lbl.BackgroundTransparency=1
                lbl.TextXAlignment=Enum.TextXAlignment.Left
                lbl.TextColor3=t.dim
                lbl.Font=t.font
                lbl.TextSize=13
                lbl.Parent=f
                
                local bg=Instance.new("Frame")
                bg.Size=UDim2.new(1,0,0,12)
                bg.Position=UDim2.new(0,0,0,18)
                bg.BackgroundColor3=t.dark
                bg.BorderColor3=t.stroke
                bg.Parent=f
                
                local fill=Instance.new("Frame")
                fill.Size=UDim2.new((def-min)/(max-min),0,1,0)
                fill.BackgroundColor3=t.accent
                fill.BorderSizePixel=0
                fill.Parent=bg
                
                local data={bg=bg,fill=fill,lbl=lbl,text=text,min=min,max=max,val=def,cb=cb}
                bg.InputBegan:Connect(function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 then
                        r.sliderDrag=data
                    end
                end)
                return g
            end
            
            function g:button(text,cb)
                local b=Instance.new("TextButton")
                b.Size=UDim2.new(1,0,0,22)
                b.BackgroundColor3=t.dark
                b.BorderColor3=t.stroke
                b.Text=text
                b.TextColor3=t.text
                b.Font=t.font
                b.TextSize=13
                b.Parent=cnt
                b.MouseButton1Click:Connect(function()
                    if cb then cb() end
                end)
                return g
            end
            
            function g:dropdown(text,opts,def,cb)
                local f=Instance.new("Frame")
                f.Size=UDim2.new(1,0,0,40)
                f.BackgroundTransparency=1
                f.ClipsDescendants=false
                f.ZIndex=10
                f.Parent=cnt
                
                local lbl=Instance.new("TextLabel")
                lbl.Text=text
                lbl.Size=UDim2.new(1,0,0,15)
                lbl.BackgroundTransparency=1
                lbl.TextXAlignment=Enum.TextXAlignment.Left
                lbl.TextColor3=t.dim
                lbl.Font=t.font
                lbl.TextSize=13
                lbl.Parent=f
                
                local box=Instance.new("TextButton")
                box.Size=UDim2.new(1,0,0,20)
                box.Position=UDim2.new(0,0,0,18)
                box.BackgroundColor3=t.dark
                box.BorderColor3=t.stroke
                box.Text=def.." ▼"
                box.TextColor3=t.text
                box.Font=t.font
                box.TextSize=13
                box.Parent=f
                
                local ol=Instance.new("Frame")
                ol.Size=UDim2.new(1,0,0,#opts*20)
                ol.Position=UDim2.new(0,0,0,38)
                ol.BackgroundColor3=t.darker
                ol.BorderColor3=t.stroke
                ol.Visible=false
                ol.ZIndex=100
                ol.Parent=f
                local oll=Instance.new("UIListLayout")
                oll.Parent=ol
                
                local cur=def
                local open=false
                
                for _,opt in ipairs(opts) do
                    local ob=Instance.new("TextButton")
                    ob.Size=UDim2.new(1,0,0,20)
                    ob.BackgroundColor3=t.dark
                    ob.BorderSizePixel=0
                    ob.Text=opt
                    ob.TextColor3=opt==cur and t.accent or t.dim
                    ob.Font=t.font
                    ob.TextSize=12
                    ob.ZIndex=101
                    ob.Parent=ol
                    
                    ob.MouseButton1Click:Connect(function()
                        cur=opt
                        box.Text=opt.." ▼"
                        ol.Visible=false
                        open=false
                        f.Size=UDim2.new(1,0,0,40)
                        for _,b in ipairs(ol:GetChildren()) do
                            if b:IsA("TextButton") then
                                b.TextColor3=b.Text==cur and t.accent or t.dim
                            end
                        end
                        if cb then cb(cur) end
                    end)
                end
                
                box.MouseButton1Click:Connect(function()
                    open=not open
                    ol.Visible=open
                    f.Size=open and UDim2.new(1,0,0,40+#opts*20) or UDim2.new(1,0,0,40)
                end)
                return g
            end
            
            function g:keybind(text,def,cb)
                local f=Instance.new("Frame")
                f.Size=UDim2.new(1,0,0,20)
                f.BackgroundTransparency=1
                f.Parent=cnt
                
                local lbl=Instance.new("TextLabel")
                lbl.Text=text
                lbl.Size=UDim2.new(0.6,0,1,0)
                lbl.BackgroundTransparency=1
                lbl.TextXAlignment=Enum.TextXAlignment.Left
                lbl.TextColor3=t.dim
                lbl.Font=t.font
                lbl.TextSize=13
                lbl.Parent=f
                
                local b=Instance.new("TextButton")
                b.Size=UDim2.new(0.3,0,1,0)
                b.Position=UDim2.new(0.7,0,0,0)
                b.BackgroundColor3=Color3.fromRGB(22,22,22)
                b.BorderColor3=t.stroke
                b.Text="["..def.Name.."]"
                b.TextColor3=t.dim
                b.Font=t.font
                b.TextSize=11
                b.Parent=f
                
                local waiting=false
                b.MouseButton1Click:Connect(function()
                    waiting=true
                    b.Text="[...]"
                    b.TextColor3=t.accent
                end)
                
                table.insert(r.conns,uis.InputBegan:Connect(function(i)
                    if waiting and i.UserInputType==Enum.UserInputType.Keyboard then
                        waiting=false
                        b.Text="["..i.KeyCode.Name.."]"
                        b.TextColor3=t.dim
                        if cb then cb(i.KeyCode) end
                    end
                end))
                return g
            end
            
            function g:textbox(text,def,cb)
                local f=Instance.new("Frame")
                f.Size=UDim2.new(1,0,0,40)
                f.BackgroundTransparency=1
                f.Parent=cnt
                
                local lbl=Instance.new("TextLabel")
                lbl.Text=text
                lbl.Size=UDim2.new(1,0,0,15)
                lbl.BackgroundTransparency=1
                lbl.TextXAlignment=Enum.TextXAlignment.Left
                lbl.TextColor3=t.dim
                lbl.Font=t.font
                lbl.TextSize=13
                lbl.Parent=f
                
                local tb=Instance.new("TextBox")
                tb.Size=UDim2.new(1,0,0,20)
                tb.Position=UDim2.new(0,0,0,18)
                tb.BackgroundColor3=t.dark
                tb.BorderColor3=t.stroke
                tb.Text=def or ""
                tb.PlaceholderText="Enter..."
                tb.TextColor3=t.text
                tb.Font=t.font
                tb.TextSize=12
                tb.ClearTextOnFocus=false
                tb.Parent=f
                
                tb.FocusLost:Connect(function()
                    if cb then cb(tb.Text) end
                end)
                return g
            end
            
            return g
        end
        return tl
    end
    return tabs
end

function lib:cleanup()
    for _,c in ipairs(r.conns) do
        pcall(function() c:Disconnect() end)
    end
    r.conns={}
    if r.gui then r.gui:Destroy() end
    r.gui=nil
    r.main=nil
end

function lib:createhotkeys(parent)
    local f=Instance.new("Frame")
    f.Name="HK"
    f.Size=UDim2.new(0,160,0,24)
    f.Position=UDim2.new(1,-170,0,200)
    f.BackgroundColor3=t.main
    f.BackgroundTransparency=0.1
    f.BorderSizePixel=0
    f.Active=true
    f.Parent=parent
    
    local s=Instance.new("UIStroke")
    s.Color=t.stroke
    s.Parent=f
    
    local gl=Instance.new("Frame")
    gl.Size=UDim2.new(1,0,0,2)
    gl.BorderSizePixel=0
    gl.Parent=f
    
    local ug=Instance.new("UIGradient")
    ug.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,t.accent),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(100,200,50))
    })
    ug.Parent=gl
    
    local title=Instance.new("TextLabel")
    title.Text="hotkeys"
    title.Size=UDim2.new(1,0,0,20)
    title.Position=UDim2.new(0,0,0,3)
    title.BackgroundTransparency=1
    title.Font=t.font
    title.TextSize=11
    title.TextColor3=t.dim
    title.Parent=f
    
    local cont=Instance.new("Frame")
    cont.Name="C"
    cont.Size=UDim2.new(1,-8,1,-24)
    cont.Position=UDim2.new(0,4,0,22)
    cont.BackgroundTransparency=1
    cont.Parent=f
    
    local list=Instance.new("UIListLayout")
    list.Padding=UDim.new(0,2)
    list.Parent=cont
    
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        f.Size=UDim2.new(0,160,0,math.max(24,list.AbsoluteContentSize.Y+26))
    end)
    
    local drag,dstart,dpos=false,nil,nil
    f.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            drag=true
            dstart=i.Position
            dpos=f.Position
        end
    end)
    
    f.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement and drag then
            local d=i.Position-dstart
            f.Position=UDim2.new(dpos.X.Scale,dpos.X.Offset+d.X,dpos.Y.Scale,dpos.Y.Offset+d.Y)
        end
    end)
    
    table.insert(r.conns,uis.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            drag=false
        end
    end))
    
    return f
end

function lib:createwatermark(parent)
    local f=Instance.new("Frame")
    f.Size=UDim2.new(0,200,0,22)
    f.Position=UDim2.new(0,10,0,10)
    f.BackgroundColor3=t.main
    f.BackgroundTransparency=0.1
    f.BorderSizePixel=0
    f.Parent=parent
    
    local s=Instance.new("UIStroke")
    s.Color=t.stroke
    s.Parent=f
    
    local gl=Instance.new("Frame")
    gl.Size=UDim2.new(1,0,0,2)
    gl.BorderSizePixel=0
    gl.Parent=f
    
    local ug=Instance.new("UIGradient")
    ug.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,t.accent),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(100,200,50))
    })
    ug.Parent=gl
    
    local txt=Instance.new("TextLabel")
    txt.Name="T"
    txt.Size=UDim2.new(1,-10,1,-2)
    txt.Position=UDim2.new(0,5,0,2)
    txt.BackgroundTransparency=1
    txt.Font=t.font
    txt.TextSize=11
    txt.TextColor3=t.text
    txt.TextXAlignment=Enum.TextXAlignment.Left
    txt.Text="Arcanum.lua | loading..."
    txt.Parent=f
    
    return f,txt
end

function lib:createtimedisplay(parent)
    local f=Instance.new("Frame")
    f.Size=UDim2.new(0,80,0,22)
    f.Position=UDim2.new(1,-90,0,10)
    f.BackgroundColor3=t.main
    f.BackgroundTransparency=0.1
    f.BorderSizePixel=0
    f.Active=true
    f.Parent=parent
    
    local s=Instance.new("UIStroke")
    s.Color=t.stroke
    s.Parent=f
    
    local gl=Instance.new("Frame")
    gl.Size=UDim2.new(1,0,0,2)
    gl.BorderSizePixel=0
    gl.Parent=f
    
    local ug=Instance.new("UIGradient")
    ug.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,t.accent),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(100,200,50))
    })
    ug.Parent=gl
    
    local txt=Instance.new("TextLabel")
    txt.Name="T"
    txt.Size=UDim2.new(1,-10,1,-2)
    txt.Position=UDim2.new(0,5,0,2)
    txt.BackgroundTransparency=1
    txt.Font=t.font
    txt.TextSize=11
    txt.TextColor3=t.text
    txt.TextXAlignment=Enum.TextXAlignment.Center
    txt.Text="--:--:--"
    txt.Parent=f
    
    local drag,dstart,dpos=false,nil,nil
    f.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            drag=true
            dstart=i.Position
            dpos=f.Position
        end
    end)
    
    f.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement and drag then
            local d=i.Position-dstart
            f.Position=UDim2.new(dpos.X.Scale,dpos.X.Offset+d.X,dpos.Y.Scale,dpos.Y.Offset+d.Y)
        end
    end)
    
    table.insert(r.conns,uis.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            drag=false
        end
    end))
    
    return f,txt
end

function lib:updatehotkeys(hkframe,hotkeys)
    if not hkframe then return end
    local cont=hkframe:FindFirstChild("C")
    if not cont then return end
    
    for _,c in ipairs(cont:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    
    for name,data in pairs(hotkeys) do
        if data.active then
            local e=Instance.new("Frame")
            e.Size=UDim2.new(1,0,0,16)
            e.BackgroundTransparency=1
            e.Parent=cont
            
            local nl=Instance.new("TextLabel")
            nl.Text=name
            nl.Size=UDim2.new(0.65,0,1,0)
            nl.BackgroundTransparency=1
            nl.TextXAlignment=Enum.TextXAlignment.Left
            nl.Font=t.font
            nl.TextSize=11
            nl.TextColor3=t.text
            nl.Parent=e
            
            local kl=Instance.new("TextLabel")
            kl.Text="["..data.key.."]"
            kl.Size=UDim2.new(0.35,0,1,0)
            kl.Position=UDim2.new(0.65,0,0,0)
            kl.BackgroundTransparency=1
            kl.TextXAlignment=Enum.TextXAlignment.Right
            kl.Font=t.font
            kl.TextSize=10
            kl.TextColor3=t.dim
            kl.Parent=e
        end
    end
end


return lib
