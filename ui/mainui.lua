local lib = {}
lib.runtime = {gui=nil,main=nil,drag=false,dragInput=nil,dragStart=nil,startPos=nil,conns={},sliderDrag=nil,resizing=false,resizeStart=nil,resizeStartSize=nil}
lib.theme = {
    main=Color3.fromRGB(17,17,17),group=Color3.fromRGB(22,22,22),stroke=Color3.fromRGB(35,35,35),
    accent=Color3.fromRGB(80,200,120),text=Color3.fromRGB(255,255,255),dim=Color3.fromRGB(150,150,150),
    font=Enum.Font.Gotham,dark=Color3.fromRGB(20,20,20),darker=Color3.fromRGB(15,15,15),border=Color3.fromRGB(40,40,40),
    accentDark=Color3.fromRGB(50,160,90),tabActive=Color3.fromRGB(25,25,25)
}
local t=lib.theme
local r=lib.runtime
local uis=game:GetService("UserInputService")
local ts=game:GetService("TweenService")

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
            offset=(offset+0.003)%2
            ug.Offset=Vector2.new(offset-1,0)
            task.wait()
        end
    end)
    
    local centerText=Instance.new("TextLabel")
    centerText.Text="ARCANUM"
    centerText.Size=UDim2.new(0,300,0,60)
    centerText.Position=UDim2.new(0.5,-150,0.5,-30)
    centerText.BackgroundTransparency=1
    centerText.Font=Enum.Font.GothamBold
    centerText.TextSize=48
    centerText.TextTransparency=0.92
    centerText.ZIndex=0
    centerText.Parent=r.gui
    
    local ctGrad=Instance.new("UIGradient")
    ctGrad.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(255,50,50)),
        ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,150,50)),
        ColorSequenceKeypoint.new(0.33,Color3.fromRGB(255,255,50)),
        ColorSequenceKeypoint.new(0.5,Color3.fromRGB(50,255,50)),
        ColorSequenceKeypoint.new(0.67,Color3.fromRGB(50,150,255)),
        ColorSequenceKeypoint.new(0.83,Color3.fromRGB(150,50,255)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(255,50,150))
    })
    ctGrad.Parent=centerText
    
    task.spawn(function()
        local offset=0
        while centerText and centerText.Parent do
            offset=(offset+0.002)%2
            ctGrad.Offset=Vector2.new(offset,0)
            task.wait()
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
    
    local resizer=Instance.new("ImageLabel")
    resizer.Size=UDim2.new(0,12,0,12)
    resizer.Position=UDim2.new(1,-14,1,-14)
    resizer.BackgroundTransparency=1
    resizer.ImageTransparency=1
    resizer.Parent=w
    
    local resizerBtn=Instance.new("TextButton")
    resizerBtn.Size=UDim2.new(0,16,0,16)
    resizerBtn.Position=UDim2.new(1,-16,1,-16)
    resizerBtn.BackgroundTransparency=1
    resizerBtn.Text=""
    resizerBtn.Parent=w
    
    resizerBtn.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            r.resizing=true
            r.resizeStart=Vector2.new(i.Position.X,i.Position.Y)
            r.resizeStartSize=w.AbsoluteSize
        end
    end)
    
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
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            local mousePos=Vector2.new(i.Position.X,i.Position.Y)
            local winPos=w.AbsolutePosition
            if mousePos.Y<winPos.Y+32 then
                r.drag=true
                r.dragInput=i
                r.dragStart=mousePos
                r.startPos=w.AbsolutePosition
            end
        end
    end)
    
    table.insert(r.conns,uis.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement then
            if r.drag and r.dragInput then
                local delta=Vector2.new(i.Position.X,i.Position.Y)-r.dragStart
                local newPos=r.startPos+delta
                w.Position=UDim2.new(0,newPos.X,0,newPos.Y)
            end
            if r.resizing then
                local mousePos=Vector2.new(i.Position.X,i.Position.Y)
                local delta=mousePos-r.resizeStart
                local newW=math.max(450,r.resizeStartSize.X+delta.X)
                local newH=math.max(350,r.resizeStartSize.Y+delta.Y)
                w.Size=UDim2.new(0,newW,0,newH)
            end
        end
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
            r.dragInput=nil
            r.sliderDrag=nil
            r.resizing=false
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
            brd.Position=UDim2.new(0,0,0,6)
            brd.BackgroundColor3=t.darker
            brd.BorderSizePixel=0
            brd.AutomaticSize=Enum.AutomaticSize.Y
            brd.Parent=grp
            
            local brdCorner=Instance.new("UICorner")
            brdCorner.CornerRadius=UDim.new(0,5)
            brdCorner.Parent=brd
            
            local brdStroke=Instance.new("UIStroke")
            brdStroke.Color=t.stroke
            brdStroke.Thickness=1
            brdStroke.Parent=brd
            
            local ttl=Instance.new("TextLabel")
            ttl.Text=gtitle:upper()
            ttl.Position=UDim2.new(0,8,0,10)
            ttl.AutomaticSize=Enum.AutomaticSize.X
            ttl.BackgroundColor3=t.darker
            ttl.BorderSizePixel=0
            ttl.TextColor3=t.accent
            ttl.Font=Enum.Font.GothamBold
            ttl.TextSize=10
            ttl.ZIndex=2
            ttl.Parent=grp
            
            local ttlPad=Instance.new("UIPadding")
            ttlPad.PaddingLeft=UDim.new(0,4)
            ttlPad.PaddingRight=UDim.new(0,4)
            ttlPad.Parent=ttl
            
            local cnt=Instance.new("Frame")
            cnt.Size=UDim2.new(1,-12,0,0)
            cnt.Position=UDim2.new(0,6,0,18)
            cnt.BackgroundTransparency=1
            cnt.AutomaticSize=Enum.AutomaticSize.Y
            cnt.Parent=brd
            local cl=Instance.new("UIListLayout")
            cl.Padding=UDim.new(0,6)
            cl.Parent=cnt
            local pd=Instance.new("UIPadding")
            pd.PaddingBottom=UDim.new(0,6)
            pd.Parent=brd
            
            local g={}
            function g:toggle(text,def,cb,keybind)
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
                
                local bindBtn
                if keybind then
                    lbl.Size=UDim2.new(1,-80,1,0)
                    
                    bindBtn=Instance.new("TextButton")
                    bindBtn.Size=UDim2.new(0,50,0,16)
                    bindBtn.Position=UDim2.new(1,-52,0,1)
                    bindBtn.BackgroundColor3=t.dark
                    bindBtn.BorderSizePixel=0
                    bindBtn.Text="["..keybind.Name.."]"
                    bindBtn.TextColor3=t.dim
                    bindBtn.Font=t.font
                    bindBtn.TextSize=9
                    bindBtn.Parent=f
                    
                    local bCorner=Instance.new("UICorner")
                    bCorner.CornerRadius=UDim.new(0,3)
                    bCorner.Parent=bindBtn
                    
                    local bStroke=Instance.new("UIStroke")
                    bStroke.Color=t.stroke
                    bStroke.Thickness=1
                    bStroke.Parent=bindBtn
                    
                    local waiting=false
                    bindBtn.MouseButton1Click:Connect(function()
                        waiting=true
                        bindBtn.Text="[...]"
                        bindBtn.TextColor3=t.accent
                    end)
                    
                    table.insert(r.conns,uis.InputBegan:Connect(function(i)
                        if waiting and i.UserInputType==Enum.UserInputType.Keyboard then
                            waiting=false
                            bindBtn.Text="["..i.KeyCode.Name.."]"
                            bindBtn.TextColor3=t.dim
                        end
                    end))
                end
                
                local b=Instance.new("TextButton")
                b.Size=UDim2.new(1,0,1,0)
                b.BackgroundTransparency=1
                b.Text=""
                b.ZIndex=2
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
                f.Size=UDim2.new(1,0,0,30)
                f.BackgroundTransparency=1
                f.Parent=cnt
                
                local lbl=Instance.new("TextLabel")
                lbl.Text=text..": "..def
                lbl.Size=UDim2.new(1,0,0,12)
                lbl.BackgroundTransparency=1
                lbl.TextXAlignment=Enum.TextXAlignment.Left
                lbl.TextColor3=t.dim
                lbl.Font=t.font
                lbl.TextSize=11
                lbl.Parent=f
                
                local bg=Instance.new("Frame")
                bg.Size=UDim2.new(1,0,0,10)
                bg.Position=UDim2.new(0,0,0,16)
                bg.BackgroundColor3=t.dark
                bg.BorderSizePixel=0
                bg.Parent=f
                
                local bgCorner=Instance.new("UICorner")
                bgCorner.CornerRadius=UDim.new(0,3)
                bgCorner.Parent=bg
                
                local bgStroke=Instance.new("UIStroke")
                bgStroke.Color=t.stroke
                bgStroke.Thickness=1
                bgStroke.Parent=bg
                
                local fill=Instance.new("Frame")
                fill.Size=UDim2.new((def-min)/(max-min),0,1,0)
                fill.BackgroundColor3=t.accent
                fill.BorderSizePixel=0
                fill.Parent=bg
                
                local fillCorner=Instance.new("UICorner")
                fillCorner.CornerRadius=UDim.new(0,3)
                fillCorner.Parent=fill
                
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
                b.Size=UDim2.new(1,0,0,20)
                b.BackgroundColor3=t.dark
                b.BorderSizePixel=0
                b.Text=text
                b.TextColor3=t.text
                b.Font=t.font
                b.TextSize=11
                b.Parent=cnt
                
                local bCorner=Instance.new("UICorner")
                bCorner.CornerRadius=UDim.new(0,4)
                bCorner.Parent=b
                
                local bStroke=Instance.new("UIStroke")
                bStroke.Color=t.stroke
                bStroke.Thickness=1
                bStroke.Parent=b
                
                b.MouseButton1Click:Connect(function()
                    if cb then cb() end
                end)
                return g
            end
            
            function g:dropdown(text,opts,def,cb)
                local f=Instance.new("Frame")
                f.Size=UDim2.new(1,0,0,34)
                f.BackgroundTransparency=1
                f.ClipsDescendants=false
                f.ZIndex=10
                f.Parent=cnt
                
                local lbl=Instance.new("TextLabel")
                lbl.Text=text
                lbl.Size=UDim2.new(1,0,0,12)
                lbl.BackgroundTransparency=1
                lbl.TextXAlignment=Enum.TextXAlignment.Left
                lbl.TextColor3=t.dim
                lbl.Font=t.font
                lbl.TextSize=11
                lbl.Parent=f
                
                local box=Instance.new("TextButton")
                box.Size=UDim2.new(1,0,0,18)
                box.Position=UDim2.new(0,0,0,16)
                box.BackgroundColor3=t.dark
                box.BorderSizePixel=0
                box.Text=def.." ▼"
                box.TextColor3=t.text
                box.Font=t.font
                box.TextSize=11
                box.Parent=f
                
                local boxCorner=Instance.new("UICorner")
                boxCorner.CornerRadius=UDim.new(0,3)
                boxCorner.Parent=box
                
                local boxStroke=Instance.new("UIStroke")
                boxStroke.Color=t.stroke
                boxStroke.Thickness=1
                boxStroke.Parent=box
                
                local popup=Instance.new("Frame")
                popup.Size=UDim2.new(0,0,0,0)
                popup.Position=UDim2.new(0,0,0,36)
                popup.BackgroundColor3=t.dark
                popup.BorderSizePixel=0
                popup.Visible=false
                popup.ClipsDescendants=true
                popup.ZIndex=200
                popup.Parent=r.gui
                
                local popCorner=Instance.new("UICorner")
                popCorner.CornerRadius=UDim.new(0,3)
                popCorner.Parent=popup
                
                local popStroke=Instance.new("UIStroke")
                popStroke.Color=t.stroke
                popStroke.Thickness=1
                popStroke.Parent=popup
                
                local scroll=Instance.new("ScrollingFrame")
                scroll.Size=UDim2.new(1,-4,1,-4)
                scroll.Position=UDim2.new(0,2,0,2)
                scroll.BackgroundTransparency=1
                scroll.BorderSizePixel=0
                scroll.ScrollBarThickness=3
                scroll.ScrollBarImageColor3=t.accent
                scroll.CanvasSize=UDim2.new(0,0,0,#opts*20)
                scroll.ZIndex=201
                scroll.Parent=popup
                
                local oll=Instance.new("UIListLayout")
                oll.Parent=scroll
                
                local cur=def
                local open=false
                
                for _,opt in ipairs(opts) do
                    local ob=Instance.new("TextButton")
                    ob.Size=UDim2.new(1,0,0,20)
                    ob.BackgroundColor3=t.darker
                    ob.BackgroundTransparency=opt==cur and 0 or 1
                    ob.BorderSizePixel=0
                    ob.Text=opt
                    ob.TextColor3=opt==cur and t.accent or t.dim
                    ob.Font=t.font
                    ob.TextSize=11
                    ob.ZIndex=202
                    ob.Parent=scroll
                    
                    ob.MouseButton1Click:Connect(function()
                        cur=opt
                        box.Text=opt.." ▼"
                        ts:Create(popup,TweenInfo.new(0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Size=UDim2.new(0,box.AbsoluteSize.X,0,0)}):Play()
                        task.wait(0.15)
                        popup.Visible=false
                        open=false
                        for _,b in ipairs(scroll:GetChildren()) do
                            if b:IsA("TextButton") then
                                b.TextColor3=b.Text==cur and t.accent or t.dim
                                b.BackgroundTransparency=b.Text==cur and 0 or 1
                            end
                        end
                        if cb then cb(cur) end
                    end)
                end
                
                box.MouseButton1Click:Connect(function()
                    open=not open
                    if open then
                        local absPos=box.AbsolutePosition
                        local targetH=math.min(#opts*20+4,200)
                        popup.Position=UDim2.new(0,absPos.X,0,absPos.Y+20)
                        popup.Size=UDim2.new(0,0,0,0)
                        popup.Visible=true
                        ts:Create(popup,TweenInfo.new(0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(0,box.AbsoluteSize.X,0,targetH)}):Play()
                    else
                        ts:Create(popup,TweenInfo.new(0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Size=UDim2.new(0,box.AbsoluteSize.X,0,0)}):Play()
                        task.wait(0.15)
                        popup.Visible=false
                    end
                end)
                
                table.insert(r.conns,uis.InputBegan:Connect(function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 and open then
                        local mp=uis:GetMouseLocation()
                        local pp=popup.AbsolutePosition
                        local ps=popup.AbsoluteSize
                        local bp=box.AbsolutePosition
                        local bs=box.AbsoluteSize
                        if (mp.X<pp.X or mp.X>pp.X+ps.X or mp.Y<pp.Y or mp.Y>pp.Y+ps.Y) and
                           (mp.X<bp.X or mp.X>bp.X+bs.X or mp.Y<bp.Y or mp.Y>bp.Y+bs.Y) then
                            ts:Create(popup,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(0,0,0,0)}):Play()
                            task.wait(0.2)
                            popup.Visible=false
                            open=false
                        end
                    end
                end))
                
                return g
            end
            
            function g:multidropdown(text,opts,defs,cb)
                local f=Instance.new("Frame")
                f.Size=UDim2.new(1,0,0,34)
                f.BackgroundTransparency=1
                f.ClipsDescendants=false
                f.ZIndex=10
                f.Parent=cnt
                
                local lbl=Instance.new("TextLabel")
                lbl.Text=text
                lbl.Size=UDim2.new(1,0,0,12)
                lbl.BackgroundTransparency=1
                lbl.TextXAlignment=Enum.TextXAlignment.Left
                lbl.TextColor3=t.dim
                lbl.Font=t.font
                lbl.TextSize=11
                lbl.Parent=f
                
                local selected={}
                for _,d in ipairs(defs) do selected[d]=true end
                
                local function getDisplayText()
                    local s={}
                    for _,o in ipairs(opts) do if selected[o] then table.insert(s,o) end end
                    return #s>0 and table.concat(s,", ").." ▼" or "None ▼"
                end
                
                local box=Instance.new("TextButton")
                box.Size=UDim2.new(1,0,0,18)
                box.Position=UDim2.new(0,0,0,16)
                box.BackgroundColor3=t.dark
                box.BorderSizePixel=0
                box.Text=getDisplayText()
                box.TextColor3=t.text
                box.Font=t.font
                box.TextSize=11
                box.TextTruncate=Enum.TextTruncate.AtEnd
                box.Parent=f
                
                local boxCorner=Instance.new("UICorner")
                boxCorner.CornerRadius=UDim.new(0,3)
                boxCorner.Parent=box
                
                local boxStroke=Instance.new("UIStroke")
                boxStroke.Color=t.stroke
                boxStroke.Thickness=1
                boxStroke.Parent=box
                
                local popup=Instance.new("Frame")
                popup.Size=UDim2.new(0,0,0,0)
                popup.Position=UDim2.new(0,0,0,36)
                popup.BackgroundColor3=t.dark
                popup.BorderSizePixel=0
                popup.Visible=false
                popup.ClipsDescendants=true
                popup.ZIndex=200
                popup.Parent=r.gui
                
                local popCorner=Instance.new("UICorner")
                popCorner.CornerRadius=UDim.new(0,3)
                popCorner.Parent=popup
                
                local popStroke=Instance.new("UIStroke")
                popStroke.Color=t.stroke
                popStroke.Thickness=1
                popStroke.Parent=popup
                
                local scroll=Instance.new("ScrollingFrame")
                scroll.Size=UDim2.new(1,-4,1,-4)
                scroll.Position=UDim2.new(0,2,0,2)
                scroll.BackgroundTransparency=1
                scroll.BorderSizePixel=0
                scroll.ScrollBarThickness=3
                scroll.ScrollBarImageColor3=t.accent
                scroll.CanvasSize=UDim2.new(0,0,0,#opts*22)
                scroll.ZIndex=201
                scroll.Parent=popup
                
                local oll=Instance.new("UIListLayout")
                oll.Parent=scroll
                
                local open=false
                local checkboxes={}
                
                for _,opt in ipairs(opts) do
                    local ob=Instance.new("Frame")
                    ob.Size=UDim2.new(1,0,0,22)
                    ob.BackgroundTransparency=1
                    ob.ZIndex=202
                    ob.Parent=scroll
                    
                    local chk=Instance.new("Frame")
                    chk.Size=UDim2.new(0,14,0,14)
                    chk.Position=UDim2.new(0,4,0,4)
                    chk.BackgroundColor3=selected[opt] and t.accent or t.dark
                    chk.BorderSizePixel=0
                    chk.ZIndex=203
                    chk.Parent=ob
                    
                    local chkCorner=Instance.new("UICorner")
                    chkCorner.CornerRadius=UDim.new(0,3)
                    chkCorner.Parent=chk
                    
                    local chkStroke=Instance.new("UIStroke")
                    chkStroke.Color=selected[opt] and t.accent or t.stroke
                    chkStroke.Thickness=1
                    chkStroke.ZIndex=203
                    chkStroke.Parent=chk
                    
                    local otxt=Instance.new("TextLabel")
                    otxt.Text=opt
                    otxt.Size=UDim2.new(1,-24,1,0)
                    otxt.Position=UDim2.new(0,22,0,0)
                    otxt.BackgroundTransparency=1
                    otxt.TextXAlignment=Enum.TextXAlignment.Left
                    otxt.TextColor3=selected[opt] and t.accent or t.dim
                    otxt.Font=t.font
                    otxt.TextSize=11
                    otxt.ZIndex=203
                    otxt.Parent=ob
                    
                    local btn=Instance.new("TextButton")
                    btn.Size=UDim2.new(1,0,1,0)
                    btn.BackgroundTransparency=1
                    btn.Text=""
                    btn.ZIndex=204
                    btn.Parent=ob
                    
                    checkboxes[opt]={chk=chk,stroke=chkStroke,txt=otxt}
                    
                    btn.MouseButton1Click:Connect(function()
                        selected[opt]=not selected[opt]
                        chk.BackgroundColor3=selected[opt] and t.accent or t.dark
                        chkStroke.Color=selected[opt] and t.accent or t.stroke
                        otxt.TextColor3=selected[opt] and t.accent or t.dim
                        box.Text=getDisplayText()
                        local s={}
                        for _,o in ipairs(opts) do if selected[o] then table.insert(s,o) end end
                        if cb then cb(s) end
                    end)
                end
                
                box.MouseButton1Click:Connect(function()
                    open=not open
                    if open then
                        local absPos=box.AbsolutePosition
                        local targetH=math.min(#opts*22+4,200)
                        popup.Position=UDim2.new(0,absPos.X,0,absPos.Y+20)
                        popup.Size=UDim2.new(0,0,0,0)
                        popup.Visible=true
                        ts:Create(popup,TweenInfo.new(0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(0,box.AbsoluteSize.X,0,targetH)}):Play()
                    else
                        ts:Create(popup,TweenInfo.new(0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Size=UDim2.new(0,box.AbsoluteSize.X,0,0)}):Play()
                        task.wait(0.15)
                        popup.Visible=false
                    end
                end)
                
                table.insert(r.conns,uis.InputBegan:Connect(function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 and open then
                        local mp=uis:GetMouseLocation()
                        local pp=popup.AbsolutePosition
                        local ps=popup.AbsoluteSize
                        local bp=box.AbsolutePosition
                        local bs=box.AbsoluteSize
                        if (mp.X<pp.X or mp.X>pp.X+ps.X or mp.Y<pp.Y or mp.Y>pp.Y+ps.Y) and
                           (mp.X<bp.X or mp.X>bp.X+bs.X or mp.Y<bp.Y or mp.Y>bp.Y+bs.Y) then
                            ts:Create(popup,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(0,0,0,0)}):Play()
                            task.wait(0.2)
                            popup.Visible=false
                            open=false
                        end
                    end
                end))
                
                return g
            end
            
            function g:keybind(text,def,cb)
                local f=Instance.new("Frame")
                f.Size=UDim2.new(1,0,0,18)
                f.BackgroundTransparency=1
                f.Parent=cnt
                
                local lbl=Instance.new("TextLabel")
                lbl.Text=text
                lbl.Size=UDim2.new(0.65,0,1,0)
                lbl.BackgroundTransparency=1
                lbl.TextXAlignment=Enum.TextXAlignment.Left
                lbl.TextColor3=t.dim
                lbl.Font=t.font
                lbl.TextSize=11
                lbl.Parent=f
                
                local b=Instance.new("TextButton")
                b.Size=UDim2.new(0.3,0,0,16)
                b.Position=UDim2.new(0.7,0,0,1)
                b.BackgroundColor3=t.dark
                b.BorderSizePixel=0
                b.Text="["..def.Name.."]"
                b.TextColor3=t.dim
                b.Font=t.font
                b.TextSize=9
                b.Parent=f
                
                local bCorner=Instance.new("UICorner")
                bCorner.CornerRadius=UDim.new(0,3)
                bCorner.Parent=b
                
                local bStroke=Instance.new("UIStroke")
                bStroke.Color=t.stroke
                bStroke.Thickness=1
                bStroke.Parent=b
                
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
                f.Size=UDim2.new(1,0,0,34)
                f.BackgroundTransparency=1
                f.Parent=cnt
                
                local lbl=Instance.new("TextLabel")
                lbl.Text=text
                lbl.Size=UDim2.new(1,0,0,12)
                lbl.BackgroundTransparency=1
                lbl.TextXAlignment=Enum.TextXAlignment.Left
                lbl.TextColor3=t.dim
                lbl.Font=t.font
                lbl.TextSize=11
                lbl.Parent=f
                
                local tb=Instance.new("TextBox")
                tb.Size=UDim2.new(1,0,0,18)
                tb.Position=UDim2.new(0,0,0,16)
                tb.BackgroundColor3=t.dark
                tb.BorderSizePixel=0
                tb.Text=def or ""
                tb.PlaceholderText="Enter..."
                tb.TextColor3=t.text
                tb.Font=t.font
                tb.TextSize=11
                tb.ClearTextOnFocus=false
                tb.Parent=f
                
                local tbCorner=Instance.new("UICorner")
                tbCorner.CornerRadius=UDim.new(0,3)
                tbCorner.Parent=tb
                
                local tbStroke=Instance.new("UIStroke")
                tbStroke.Color=t.stroke
                tbStroke.Thickness=1
                tbStroke.Parent=tb
                
                tb.FocusLost:Connect(function()
                    if cb then cb(tb.Text) end
                end)
                return g
            end
            
            function g:colorpicker(text,def,cb)
                local f=Instance.new("Frame")
                f.Size=UDim2.new(1,0,0,18)
                f.BackgroundTransparency=1
                f.Parent=cnt
                
                local lbl=Instance.new("TextLabel")
                lbl.Text=text
                lbl.Size=UDim2.new(0.7,0,1,0)
                lbl.BackgroundTransparency=1
                lbl.TextXAlignment=Enum.TextXAlignment.Left
                lbl.TextColor3=t.dim
                lbl.Font=t.font
                lbl.TextSize=11
                lbl.Parent=f
                
                local preview=Instance.new("TextButton")
                preview.Size=UDim2.new(0,40,0,16)
                preview.Position=UDim2.new(1,-42,0,1)
                preview.BackgroundColor3=def
                preview.BorderSizePixel=0
                preview.Text=""
                preview.Parent=f
                
                local pCorner=Instance.new("UICorner")
                pCorner.CornerRadius=UDim.new(0,3)
                pCorner.Parent=preview
                
                local pStroke=Instance.new("UIStroke")
                pStroke.Color=t.stroke
                pStroke.Thickness=1
                pStroke.Parent=preview
                
                local picker=Instance.new("Frame")
                picker.Size=UDim2.new(0,0,0,0)
                picker.BackgroundColor3=t.darker
                picker.BorderSizePixel=0
                picker.Visible=false
                picker.ClipsDescendants=true
                picker.ZIndex=200
                picker.Parent=r.gui
                
                local pkCorner=Instance.new("UICorner")
                pkCorner.CornerRadius=UDim.new(0,5)
                pkCorner.Parent=picker
                
                local pkStroke=Instance.new("UIStroke")
                pkStroke.Color=t.accent
                pkStroke.Thickness=1
                pkStroke.Parent=picker
                
                local wheel=Instance.new("ImageLabel")
                wheel.Size=UDim2.new(0,120,0,120)
                wheel.Position=UDim2.new(0,10,0,10)
                wheel.BackgroundTransparency=1
                wheel.Image="rbxassetid://698052001"
                wheel.ZIndex=201
                wheel.Parent=picker
                
                local alphaSlider=Instance.new("Frame")
                alphaSlider.Size=UDim2.new(0,120,0,12)
                alphaSlider.Position=UDim2.new(0,10,0,138)
                alphaSlider.BackgroundColor3=Color3.fromRGB(255,255,255)
                alphaSlider.BorderSizePixel=0
                alphaSlider.ZIndex=201
                alphaSlider.Parent=picker
                
                local asCorner=Instance.new("UICorner")
                asCorner.CornerRadius=UDim.new(0,3)
                asCorner.Parent=alphaSlider
                
                local asGrad=Instance.new("UIGradient")
                asGrad.Transparency=NumberSequence.new({
                    NumberSequenceKeypoint.new(0,0),
                    NumberSequenceKeypoint.new(1,1)
                })
                asGrad.Parent=alphaSlider
                
                local alphaFill=Instance.new("Frame")
                alphaFill.Size=UDim2.new(1,0,1,0)
                alphaFill.BackgroundColor3=def
                alphaFill.BorderSizePixel=0
                alphaFill.ZIndex=200
                alphaFill.Parent=alphaSlider
                
                local afCorner=Instance.new("UICorner")
                afCorner.CornerRadius=UDim.new(0,3)
                afCorner.Parent=alphaFill
                
                local curColor=def
                local curAlpha=1
                local open=false
                
                preview.MouseButton1Click:Connect(function()
                    open=not open
                    if open then
                        local absPos=preview.AbsolutePosition
                        picker.Position=UDim2.new(0,absPos.X-100,0,absPos.Y+20)
                        picker.Size=UDim2.new(0,0,0,0)
                        picker.Visible=true
                        ts:Create(picker,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(0,140,0,160)}):Play()
                    else
                        ts:Create(picker,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(0,0,0,0)}):Play()
                        task.wait(0.2)
                        picker.Visible=false
                    end
                end)
                
                wheel.InputBegan:Connect(function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 then
                        local function update()
                            local mp=uis:GetMouseLocation()
                            local center=wheel.AbsolutePosition+wheel.AbsoluteSize/2
                            local delta=mp-center
                            local angle=math.atan2(delta.Y,delta.X)
                            local dist=math.min((delta.Magnitude/(wheel.AbsoluteSize.X/2)),1)
                            local hue=(angle+math.pi)/(2*math.pi)
                            curColor=Color3.fromHSV(hue,dist,1)
                            preview.BackgroundColor3=curColor
                            alphaFill.BackgroundColor3=curColor
                            if cb then cb(curColor,curAlpha) end
                        end
                        update()
                        local conn
                        conn=uis.InputChanged:Connect(function(i2)
                            if i2.UserInputType==Enum.UserInputType.MouseMovement then
                                update()
                            end
                        end)
                        local endConn
                        endConn=uis.InputEnded:Connect(function(i2)
                            if i2.UserInputType==Enum.UserInputType.MouseButton1 then
                                conn:Disconnect()
                                endConn:Disconnect()
                            end
                        end)
                    end
                end)
                
                alphaSlider.InputBegan:Connect(function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 then
                        local function update()
                            local mp=uis:GetMouseLocation()
                            local rel=math.clamp((mp.X-alphaSlider.AbsolutePosition.X)/alphaSlider.AbsoluteSize.X,0,1)
                            curAlpha=1-rel
                            if cb then cb(curColor,curAlpha) end
                        end
                        update()
                        local conn
                        conn=uis.InputChanged:Connect(function(i2)
                            if i2.UserInputType==Enum.UserInputType.MouseMovement then
                                update()
                            end
                        end)
                        local endConn
                        endConn=uis.InputEnded:Connect(function(i2)
                            if i2.UserInputType==Enum.UserInputType.MouseButton1 then
                                conn:Disconnect()
                                endConn:Disconnect()
                            end
                        end)
                    end
                end)
                
                table.insert(r.conns,uis.InputBegan:Connect(function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 and open then
                        local mp=uis:GetMouseLocation()
                        local pp=picker.AbsolutePosition
                        local ps=picker.AbsoluteSize
                        local bp=preview.AbsolutePosition
                        local bs=preview.AbsoluteSize
                        if (mp.X<pp.X or mp.X>pp.X+ps.X or mp.Y<pp.Y or mp.Y>pp.Y+ps.Y) and
                           (mp.X<bp.X or mp.X>bp.X+bs.X or mp.Y<bp.Y or mp.Y>bp.Y+bs.Y) then
                            ts:Create(picker,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(0,0,0,0)}):Play()
                            task.wait(0.2)
                            picker.Visible=false
                            open=false
                        end
                    end
                end))
                
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
    gl.BackgroundColor3=t.accent
    gl.Parent=f
    
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
            offset=(offset+0.003)%2
            ug.Offset=Vector2.new(offset-1,0)
            task.wait()
        end
    end)
    
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
    gl.BackgroundColor3=t.accent
    gl.Parent=f
    
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
            offset=(offset+0.003)%2
            ug.Offset=Vector2.new(offset-1,0)
            task.wait()
        end
    end)
    
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
    gl.BackgroundColor3=t.accent
    gl.Parent=f
    
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
            offset=(offset+0.003)%2
            ug.Offset=Vector2.new(offset-1,0)
            task.wait()
        end
    end)
    
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
