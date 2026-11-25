local function createWindAdapter(WindUI)
    local camera=workspace.CurrentCamera
    local size=camera and camera.ViewportSize or Vector2.new(800,600)
    local base=table.clone(WindUI:GetThemes().Dark)
    local palettes={Dark={154,130,255},Darker={120,142,180},Aqua={65,203,218},Amethyst={190,125,255},Rose={235,139,172},Light={105,86,205}}
    for name,rgb in pairs(palettes)do
        local theme=table.clone(base)theme.Name=name
        local light=name=="Light"
        theme.Background=light and Color3.fromRGB(238,240,248)or Color3.fromRGB(15,17,24)
        theme.Accent=light and Color3.fromRGB(250,251,255)or Color3.fromRGB(22,25,35)
        theme.ElementBackground=light and Color3.fromRGB(224,228,239)or Color3.fromRGB(28,31,43)
        theme.Text=light and Color3.fromRGB(27,30,42)or Color3.fromRGB(238,240,250)
        theme.Icon=light and Color3.fromRGB(80,85,110)or Color3.fromRGB(164,171,194)
        theme.Placeholder=theme.Icon
        theme.Primary=Color3.fromRGB(table.unpack(rgb))theme.Toggle=theme.Primary theme.Slider=theme.Primary theme.Checkbox=theme.Primary
        WindUI:AddTheme(theme)
    end
    local nativeWindow=WindUI:CreateWindow({Title="JewHub",Author="Prison Life",Icon="shield",Folder="JewHubPrisonUI",
        Size=UDim2.fromOffset(math.min(740,size.X-32),math.min(560,size.Y-48)),MinSize=Vector2.new(400,320),
        SideBarWidth=165,Theme="Dark",Transparent=false,Acrylic=false,Resizable=true,HideSearchBar=false,
        ToggleKey=Enum.KeyCode.RightShift,IgnoreAlerts=true,
        OpenButton={Title="JewHub",Icon="shield",OnlyMobile=false,Enabled=true}})
    -- Our menu handler accepts Right Shift even if Roblox consumes the key.
    nativeWindow:SetToggleKey(nil)
    local destroyNative=nativeWindow.Destroy
    nativeWindow.Destroy=function(self)self:Close()end
    local UI={Options={},Unloaded=false}
    function UI:SetTheme(value)WindUI:SetTheme(value)end
    function UI:Notify(o)WindUI:Notify({Title=o.Title,Content=o.Content,Duration=o.Duration or 5,Icon="shield"})end
    function UI:Destroy()
        if self.Unloaded then return end self.Unloaded=true destroyNative(nativeWindow)
    end
    local window={native=nativeWindow}
    function window:IsVisible()return not nativeWindow.Closed end
    function window:SetVisible(visible)
        if UI.Unloaded then return end
        if visible and nativeWindow.Closed then nativeWindow:Open()elseif not visible and not nativeWindow.Closed then nativeWindow:Close()end
    end
    function window:Minimize()self:SetVisible(not self:IsVisible())end
    local tabs={}
    local function wrapTab(native)
        local tab={}
        local function control(kind,id,o)
            local w={_value=o.Default,kind=kind}
            local raw
            local function publish(v)
                if kind=="Slider"then v=tonumber(v)end
                if w._value==v then return end
                w._value=v
                if o.Callback then o.Callback(v)end
                if w.changed then w.changed(v)end
            end
            local common={Title=o.Title,Desc=o.Description,Callback=publish}
            if kind=="Toggle"then common.Value=o.Default common.Type="Toggle"raw=native:Toggle(common)
            elseif kind=="Slider"then common.Value={Min=o.Min,Max=o.Max,Default=o.Default}common.Step=o.Step or (o.Rounding==0 and 1 or 0.01)raw=native:Slider(common)
            elseif kind=="Dropdown"then common.Values=o.Values common.Value=o.Default common.Multi=false common.AllowNone=true raw=native:Dropdown(common)
            elseif kind=="Colorpicker"then common.Default=o.Default raw=native:Colorpicker(common)
            elseif kind=="Input"then common.Value=o.Default common.Placeholder=o.Placeholder raw=native:Input(common)
            elseif kind=="Keybind"then
                common.Value=o.Default
                common.Callback=function()if w.clicked then w.clicked()end end
                raw=native:Keybind(common)
            end
            w.raw=raw
            setmetatable(w,{__index=function(self,key)
                if key=="Value"then return kind=="Keybind"and raw.Value or self._value end
                if key=="Picking"then return raw.Picking end
            end})
            function w:SetValue(value)
                if kind=="Dropdown"then raw:Select(value)else raw:Set(value)end
                publish(value)
            end
            function w:SetValueRGB(value)self:SetValue(value)end
            function w:SetValues(values)raw:Refresh(values)end
            function w:OnChanged(callback)self.changed=callback callback(self.Value)end
            function w:OnClick(callback)self.clicked=callback end
            UI.Options[id]=w return w
        end
        for _,kind in {"Toggle","Slider","Dropdown","Colorpicker","Input","Keybind"}do
            tab["Add"..kind]=function(_,id,o)return control(kind,id,o)end
        end
        function tab:AddParagraph(o)return native:Paragraph({Title=o.Title,Desc=o.Content})end
        function tab:AddButton(o)return native:Button({Title=o.Title,Desc=o.Description,Callback=o.Callback})end
        return tab
    end
    local natives={}
    for _,entry in {{"Home","house"},{"Combat","crosshair"},{"Visuals","eye"},{"Weapons","swords"},{"Player","user"},{"Travel","map-pin"},{"Settings","settings"}}do
        local native=nativeWindow:Tab({Title=entry[1],Icon=entry[2]})
        natives[entry[1]]=native tabs[entry[1]]=wrapTab(native)
    end
    natives.Home:Select()
    local routes={ESP="Visuals",Aimlock="Combat"}
    local serial=0
    local adapter={}
    function adapter:CreateTab(name)
        local tab=assert(tabs[routes[name]or name],"Unknown menu tab: "..name)
        local function id(flag)serial+=1 return flag or "PL_Control_"..serial end
        local out={}
        function out:CreateToggle(o)
            local w=tab:AddToggle(id(o.Flag),{Title=o.Name,Default=o.CurrentValue})w:OnChanged(o.Callback)
            return{Set=function(_,v)w:SetValue(v)end}
        end
        function out:CreateSlider(o)
            local w=tab:AddSlider(id(o.Flag),{Title=o.Name,Default=o.CurrentValue,Min=o.Range[1],Max=o.Range[2],Step=o.Increment,Callback=o.Callback})
            return{Set=function(_,v)w:SetValue(v)end}
        end
        function out:CreateDropdown(o)
            local w=tab:AddDropdown(id(o.Flag),{Title=o.Name,Default=o.CurrentOption[1],Values=o.Options})w:OnChanged(function(v)o.Callback({v})end)
            return{Set=function(_,v)w:SetValue(type(v)=="table"and v[1]or v)end}
        end
        function out:CreateColorPicker(o)
            local w=tab:AddColorpicker(id(o.Flag),{Title=o.Name,Default=o.Color})w:OnChanged(o.Callback)
            return{Set=function(_,v)w:SetValueRGB(v)end}
        end
        function out:CreateLabel(text)
            local p=tab:AddParagraph({Title=name,Content=text})return{Set=function(_,v)p:SetDesc(v)end}
        end
        return out
    end
    function adapter:Notify(o)UI:Notify(o)end
    return UI,window,tabs,adapter
end


local schema={
    {"Combat","silent","Silent aim",false},
    {"Combat","hitChance","Silent hit chance",100,0,100,1},
    {"Combat","hitPart","Silent hit part","Head",{"Head","Body","Random"}},
    {"Combat","silentRadius","Silent aim radius (px)",180,20,600,5},
    {"Combat","silentWall","Silent line-of-sight check",true},
    {"Combat","teamCheck","Ignore teammates",true},
    {"Combat","spawnCheck","Ignore spawn protection",true},
    {"Combat","ignoreGuards","Ignore guards",false},
    {"Combat","ignoreInmates","Ignore inmates",false},
    {"Combat","ignoreCriminals","Ignore criminals",false},
    {"Combat","autoShoot","Auto shoot acquired aim target",false},
    {"Combat","shotInterval","Auto shoot interval (s)",0.15,0.05,1,0.01},
    {"Visuals","targetTracker","Live target tracker",true},
    {"Visuals","showFov","Show silent aim radius",false},
    {"Visuals","crosshair","Center dot crosshair",false},
    {"Visuals","espNames","Player names",true},
    {"Visuals","espNameType","Name format","Display name",{"Display name","Username","Both"}},
    {"Visuals","espTextSize","Label text size",13,10,22,1},
    {"Visuals","espDistance","Distance labels",true},
    {"Visuals","espHealth","Health bars",true},
    {"Visuals","espHealthText","Health numbers",false},
    {"Visuals","espHealthGradient","Health-based bar colours",true},
    {"Visuals","espHealthSmooth","Health-bar response time",0.15,0,0.75,0.05},
    {"Visuals","espWeapon","Equipped weapon labels",false},
    {"Visuals","espSkeleton","Skeletons",false},
    {"Visuals","espSkeletonWidth","Skeleton thickness",1,1,5,1},
    {"Visuals","espSkeletonOutline","Skeleton outlines",true},
    {"Visuals","espHead","Head dots",false},
    {"Visuals","espRange","ESP distance limit",1500,100,5000,50},
    {"Weapons","noSpread","No spread (client attributes)",false},
    {"Weapons","automatic","Automatic fire (client attributes)",false},
    {"Weapons","rapidFire","Rapid fire",false},
    {"Weapons","rapidMultiplier","Fire-rate multiplier",2,1,10,1},
    {"Weapons","fastReload","Override reload time",false},
    {"Weapons","reloadTime","Reload time (s)",0.5,0.1,3,0.1},
    {"Weapons","weaponColour","Local weapon colour",false},
    {"Weapons","neonWeapon","Neon material",false},
    {"Weapons","weaponOpacity","Weapon opacity",100,0,100,1},
    {"Weapons","autoPickup","Get selected weapon after respawn",false},
    {"Player","speed","Override walk speed",false},
    {"Player","walkSpeed","Walk speed",24,8,150,1},
    {"Player","jump","Override jump power",false},
    {"Player","jumpPower","Jump power",65,0,200,5},
    {"Player","infiniteJump","Extra jumps",false},
    {"Player","noclip","Noclip",false},
    {"Player","fly","Fly",false},
    {"Player","flySpeed","Flight speed",50,10,150,5},
    {"Player","fovOverride","Override camera FOV",false},
    {"Player","fov","Camera FOV",90,50,120,1},
    {"Visuals","fullbright","Fullbright",false},
    {"Visuals","noFog","Remove fog",false},
    {"Visuals","customTime","Override time of day",false},
    {"Visuals","clockTime","Time of day",14,0,24,0.5},
    {"Settings","theme","Interface theme","Dark",{"Dark","Darker","Light","Aqua","Amethyst","Rose"}},
}
local function validatePrisonSettings(saved)
    assert(type(saved)=="table","Invalid settings")local out={}
    for _,entry in schema do
        local key,default=entry[2],entry[4]local v=saved[key]if v==nil then v=default end
        assert(type(v)==type(default),"Invalid setting: "..key)
        if type(v)=="number"then assert(v==v and v>=entry[5]and v<=entry[6],"Out-of-range setting: "..key)
        elseif type(entry[5])=="table"then assert(table.find(entry[5],v),"Invalid option: "..key)end
        out[key]=v
    end
    return out
end


local function aimlockAlpha(smoothing, dt)
    -- A larger smoothing value gives a longer response time, independent of FPS.
    return 1 - math.exp(-60 * math.clamp(dt, 0, 0.1) / smoothing)
end

local function validateVisualAimConfig(saved)
    assert(type(saved) == "table", "ESP/aimlock settings are missing.")
    local normalized = {}
    for _, key in { "esp", "tracers", "boxes", "fill", "chams", "espTeamCheck",
        "aimlock", "holdRightMouse", "aimTeamCheck", "wallCheck" } do
        assert(type(saved[key]) == "boolean", "Invalid ESP/aimlock setting: " .. key)
        normalized[key] = saved[key]
    end
    for key, bounds in { smoothing = { 1, 100 }, radius = { 20, 800 }, opacity = { 0, 100 } } do
        local value = saved[key]
        assert(type(value) == "number" and value == value and value >= bounds[1]
            and value <= bounds[2], "Invalid ESP/aimlock setting: " .. key)
        normalized[key] = value
    end
    assert(saved.part == "Head" or saved.part == "Body" or saved.part == "Closest", "Invalid aimlock target part.")
    local color=saved.color or {90,200,255}
    assert(type(color)=="table" and #color==3,"Invalid ESP colour")
    normalized.color={}
    for i=1,3 do
        local channel=color[i]
        assert(type(channel)=="number" and channel==channel and channel>=0 and channel<=255 and channel%1==0,"Invalid ESP colour channel")
        normalized.color[i]=channel
    end
    normalized.part = saved.part
    return normalized
end

local function installVisualAim(window, Rayfield, player)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Input = game:GetService("UserInputService")
    local state = { esp = false, tracers = false, boxes = true, fill = false, chams = true,
        espTeamCheck = false, aimlock = false, holdRightMouse = false, aimTeamCheck = false,
        wallCheck = true, smoothing = 10, radius = 300, opacity = 25, part = "Head",color={90,200,255} }
    local widgets, actors, connections = {}, {}, {}
    local alive, lockedPlayer, lastError = true, nil, nil
    local featurePack, aimSuppressed
    local trackedPart
    local binding = "SandboxVisualAim_" .. game:GetService("HttpService"):GenerateGUID(false)
    local gui = Instance.new("ScreenGui")
    gui.Name = "SandboxESP"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 80
    gui.Parent = player:WaitForChild("PlayerGui")
    local tint = Color3.fromRGB(90, 200, 255)
    local tab = window:CreateTab("ESP", 4483362458)
    local aimTab = window:CreateTab("Aimlock", 4483362458)
    local status = aimTab:CreateLabel("Enable aimlock to track players. Higher smoothing = slower tracking.")
    local function toggle(where, name, key)
        widgets[key] = where:CreateToggle({ Name = name, CurrentValue = state[key], Flag = "VA_" .. key,
            Callback = function(value)
                state[key] = value
                if key == "aimlock" then lockedPlayer = nil end
            end })
    end
    widgets.color=tab:CreateColorPicker({Name="ESP colour",Flag="VA_Color",Color=tint,Callback=function(value)
        state.color={math.floor(value.R*255+0.5),math.floor(value.G*255+0.5),math.floor(value.B*255+0.5)}
        tint=Color3.fromRGB(table.unpack(state.color))
        for _,actor in pairs(actors)do
            actor.box.BackgroundColor3=tint actor.outline.Color=tint actor.tracer.BackgroundColor3=tint
            actor.info.TextColor3=tint actor.dot.BackgroundColor3=tint
            if actor.highlight then actor.highlight.FillColor=tint actor.highlight.OutlineColor=tint end
            for _,line in pairs(actor.skeleton)do line.BackgroundColor3=tint end
        end
    end})
    toggle(tab, "Enable ESP", "esp")
    toggle(tab, "Tracers", "tracers")
    toggle(tab, "Boxes", "boxes")
    toggle(tab, "Box fill", "fill")
    toggle(tab, "Chams (through walls)", "chams")
    toggle(tab, "Ignore teammates", "espTeamCheck")
    widgets.opacity = tab:CreateSlider({ Name = "Fill / chams opacity", Range = { 0, 100 }, Increment = 1,
        Suffix = "%", CurrentValue = state.opacity, Flag = "VA_opacity",
        Callback = function(value) state.opacity = value end })
    toggle(aimTab, "Enable aimlock", "aimlock")
    toggle(aimTab, "Only while holding right mouse", "holdRightMouse")
    toggle(aimTab, "Ignore teammates", "aimTeamCheck")
    toggle(aimTab, "Check line of sight", "wallCheck")
    widgets.smoothing = aimTab:CreateSlider({ Name = "Smoothing (higher = slower)", Range = { 1, 100 },
        Increment = 1, CurrentValue = state.smoothing, Flag = "VA_smoothing",
        Callback = function(value) state.smoothing = value end })
    widgets.radius = aimTab:CreateSlider({ Name = "Aimlock radius", Range = { 20, 800 }, Increment = 10,
        CurrentValue = state.radius, Suffix = "pixels", Flag = "VA_radius",
        Callback = function(value) state.radius = value end })
    widgets.part = aimTab:CreateDropdown({ Name = "Target part", Options = { "Head", "Body", "Closest" },
        CurrentOption = { state.part }, MultipleOptions = false, Flag = "VA_part",
        Callback = function(value)
            state.part = type(value) == "table" and value[1] or value
            lockedPlayer = nil
        end })

    local function opponent(other, teamCheck)
        if other~=player and teamCheck and featurePack and featurePack.isTeammate and featurePack:isTeammate(other) then return false end
        return other ~= player and (not teamCheck or player.Neutral or other.Neutral
            or not player.Team or other.Team ~= player.Team)
    end
    local function removeActor(other)
        local actor = actors[other]
        if not actor then return end
        actor.box:Destroy()
        actor.tracer:Destroy()
        for _,instance in actor.extras do instance:Destroy() end
        if actor.highlight then actor.highlight:Destroy() end
        actors[other] = nil
        if lockedPlayer == other then lockedPlayer = nil end
    end
    local function makeActor(other)
        local box = Instance.new("Frame")
        box.Name = "PlayerBox"
        box.BorderSizePixel = 0
        box.BackgroundColor3 = tint
        box.Visible = false
        box.Parent = gui
        local outline = Instance.new("UIStroke")
        outline.Color = tint
        outline.Thickness = 2
        outline.Parent = box
        local tracer = Instance.new("Frame")
        tracer.Name = "PlayerTracer"
        tracer.AnchorPoint = Vector2.new(0.5, 0.5)
        tracer.BorderSizePixel = 0
        tracer.BackgroundColor3 = tint
        tracer.Visible = false
        tracer.Parent = gui
        local function label(name,font,color)
            local text=Instance.new("TextLabel")text.Name=name text.BackgroundTransparency=1
            text.Font=font text.TextColor3=color text.TextStrokeColor3=Color3.fromRGB(0,0,0)text.TextStrokeTransparency=0.25
            text.TextSize=13 text.TextWrapped=false text.TextScaled=false text.RichText=false
            text.TextTruncate=Enum.TextTruncate.AtEnd text.AnchorPoint=Vector2.new(0.5,0)
            text.Size=UDim2.fromOffset(240,18)text.Visible=false text.Parent=gui return text
        end
        local info=label("PlayerInfo",Enum.Font.GothamMedium,tint)
        local details=label("PlayerDetails",Enum.Font.Gotham,Color3.fromRGB(235,235,240))
        local weapon=label("PlayerWeapon",Enum.Font.Gotham,Color3.fromRGB(200,204,214))
        local health=Instance.new("Frame") health.BorderSizePixel=0 health.BackgroundColor3=Color3.fromRGB(25,25,25) health.Visible=false health.Parent=gui
        local healthFill=Instance.new("Frame") healthFill.BorderSizePixel=0 healthFill.BackgroundColor3=Color3.fromRGB(60,255,100) healthFill.Parent=health
        local dot=Instance.new("Frame") dot.BorderSizePixel=0 dot.BackgroundColor3=tint dot.Size=UDim2.fromOffset(7,7) dot.AnchorPoint=Vector2.new(0.5,0.5) dot.Visible=false dot.Parent=gui
        local dotCorner=Instance.new("UICorner") dotCorner.CornerRadius=UDim.new(1,0) dotCorner.Parent=dot
        local actor = { box = box, outline = outline, tracer = tracer, info=info,details=details,weapon=weapon,health=health,healthFill=healthFill,dot=dot,
            skeleton={},skeletonOutlines={},extras={info,details,weapon,health,dot} }
        actors[other] = actor
        return actor
    end
    local function getBounds(camera, character)
        local cf, size = character:GetBoundingBox()
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        for _, x in { -1, 1 } do
            for _, y in { -1, 1 } do
                for _, z in { -1, 1 } do
                    local point = camera:WorldToViewportPoint(cf * Vector3.new(size.X * x / 2, size.Y * y / 2, size.Z * z / 2))
                    -- Skip boxes intersecting the camera plane to avoid huge inverted rectangles.
                    if point.Z <= 0.05 then return end
                    minX, minY = math.min(minX, point.X), math.min(minY, point.Y)
                    maxX, maxY = math.max(maxX, point.X), math.max(maxY, point.Y)
                end
            end
        end
        local viewport = camera.ViewportSize
        if maxX < 0 or maxY < 0 or minX > viewport.X or minY > viewport.Y then return end
        return minX, minY, maxX, maxY
    end
    local function drawActor(other, camera, dt)
        local actor = actors[other] or makeActor(other)
        actor.box.Visible, actor.tracer.Visible = false, false
        for _,instance in actor.extras do instance.Visible=false end
        local character = other.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local show = state.esp and opponent(other, state.espTeamCheck) and character
            and character.Parent and humanoid and humanoid.Health > 0
        local extras=featurePack and featurePack.state
        local root=character and character:FindFirstChild("HumanoidRootPart")
        if show and extras then
            if not root or (root.Position-camera.CFrame.Position).Magnitude>extras.espRange then show=false end
            if not extras.espLobby and featurePack:isInDuel()==false then show=false end
        end
        if actor.character ~= character then
            if actor.highlight then actor.highlight:Destroy() actor.highlight = nil end
            actor.character = character
            actor.healthRatio = nil
        end
        if show and state.chams and not actor.highlight then
            local highlight = Instance.new("Highlight")
            highlight.Name = "SandboxCham"
            highlight.Adornee = character
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillColor, highlight.OutlineColor = tint, tint
            highlight.OutlineTransparency = 0
            highlight.Parent = character
            actor.highlight = highlight
        end
        if actor.highlight then
            actor.highlight.Enabled = not not (show and state.chams)
            actor.highlight.FillTransparency = 1 - state.opacity / 100
        end
        if not show or not (state.boxes or state.fill or state.tracers or extras) then return end
        local left, top, right, bottom = getBounds(camera, character)
        if not left then return end
        actor.box.Position = UDim2.fromOffset(left, top)
        actor.box.Size = UDim2.fromOffset(math.max(1, right - left), math.max(1, bottom - top))
        actor.box.BackgroundTransparency = state.fill and (1 - state.opacity / 100) or 1
        actor.outline.Enabled = state.boxes
        actor.box.Visible = state.boxes or state.fill
        if extras then
            local text={}
            actor.info.Text=""
            if extras.espNames then
                local display=other.DisplayName or other.Name
                local mode=extras.espNameType
                local name=mode=="Username" and other.Name or display
                if mode=="Both" and display~=other.Name then name=display.." (@"..other.Name..")" end
                actor.info.Text=name
            end
            if extras.espDistance then table.insert(text,string.format("%.0f studs",(root.Position-camera.CFrame.Position).Magnitude)) end
            if extras.espHealthText then table.insert(text,string.format("%d HP",math.ceil(humanoid.Health))) end
            local size=extras.espTextSize or 13
            local detailSize=math.max(10,size-2)
            local rowHeight=size+5
            local center=(left+right)/2
            actor.info.TextSize=size actor.info.Size=UDim2.fromOffset(240,rowHeight)
            actor.info.Position=UDim2.fromOffset(center,top-rowHeight-3)actor.info.Visible=extras.espNames
            actor.details.Text=table.concat(text,"  ·  ")actor.details.TextSize=detailSize
            actor.details.Size=UDim2.fromOffset(240,rowHeight)actor.details.Position=UDim2.fromOffset(center,bottom+3)
            actor.details.Visible=#text>0
            local weapon=extras.espWeapon and featurePack:getWeaponName(other)or nil
            actor.weapon.Text=weapon or "" actor.weapon.TextSize=detailSize
            actor.weapon.Size=UDim2.fromOffset(240,rowHeight)
            actor.weapon.Position=UDim2.fromOffset(center,bottom+3+(#text>0 and rowHeight or 0))
            actor.weapon.Visible=weapon~=nil and weapon~=""
            actor.health.Position=UDim2.fromOffset(left-7,top) actor.health.Size=UDim2.fromOffset(4,math.max(1,bottom-top))
            local fraction=math.clamp(humanoid.Health/math.max(1,humanoid.MaxHealth),0,1)
            local response=extras.espHealthSmooth or 0
            if actor.healthRatio==nil or response<=0 or not extras.espHealth then
                actor.healthRatio=fraction
            else
                local alpha=1-math.exp(-math.max(0,dt)/response)
                actor.healthRatio+=(fraction-actor.healthRatio)*alpha
            end
            local ratio=actor.healthRatio
            actor.healthFill.Position=UDim2.fromScale(0,1-ratio) actor.healthFill.Size=UDim2.fromScale(1,ratio)
            -- Red to yellow to green; colour reflects actual health, even while the bar animates.
            actor.healthFill.BackgroundColor3=extras.espHealthGradient
                and Color3.fromRGB(math.floor(255*math.min(1,2*(1-fraction))),math.floor(255*math.min(1,2*fraction)),40)
                or Color3.fromRGB(60,255,100)
            actor.health.Visible=extras.espHealth
            local head=character:FindFirstChild("Head")
            if extras.espHead and head then
                local point,onScreen=camera:WorldToViewportPoint(head.Position)
                actor.dot.Position=UDim2.fromOffset(point.X,point.Y) actor.dot.Visible=onScreen and point.Z>0
            end
            if extras.espSkeleton then
                local pairsR15={{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},
                    {"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
                    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},
                    {"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}}
                local pairsR6={{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}
                for index,pair in character:FindFirstChild("UpperTorso") and pairsR15 or pairsR6 do
                    local a,b=character:FindFirstChild(pair[1]),character:FindFirstChild(pair[2])
                    if a and b then
                        local p,onA=camera:WorldToViewportPoint(a.Position) local q,onB=camera:WorldToViewportPoint(b.Position)
                        if onA and onB and p.Z>0 and q.Z>0 then
                            local line=actor.skeleton[index]
                            if not line then
                                line=Instance.new("Frame") line.BorderSizePixel=0 line.BackgroundColor3=tint line.AnchorPoint=Vector2.new(0.5,0.5) line.Parent=gui
                                line.Name="PlayerSkeleton"
                                local stroke=Instance.new("UIStroke")stroke.Name="SkeletonOutline"stroke.Color=Color3.fromRGB(0,0,0)stroke.Thickness=1 stroke.Enabled=false stroke.Parent=line
                                actor.skeleton[index]=line actor.skeletonOutlines[index]=stroke table.insert(actor.extras,line)
                            end
                            local delta=Vector2.new(q.X-p.X,q.Y-p.Y)
                            line.Position=UDim2.fromOffset((p.X+q.X)/2,(p.Y+q.Y)/2) line.Size=UDim2.fromOffset(delta.Magnitude,extras.espSkeletonWidth or 1)
                            actor.skeletonOutlines[index].Enabled=extras.espSkeletonOutline==true
                            line.Rotation=math.deg(math.atan2(delta.Y,delta.X)) line.Visible=true
                        end
                    end
                end
            end
        end
        if state.tracers then
            local origin = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y - 5)
            local destination = Vector2.new((left + right) / 2, bottom)
            local delta = destination - origin
            actor.tracer.Position = UDim2.fromOffset((origin.X + destination.X) / 2, (origin.Y + destination.Y) / 2)
            actor.tracer.Size = UDim2.fromOffset(delta.Magnitude, 2)
            actor.tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
            actor.tracer.Visible = true
        end
    end
    local function aimPart(other, camera, params)
        if not other or other.Parent ~= Players or not opponent(other, state.aimTeamCheck) then return end
        local character = other.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end
        local part
        if state.part == "Head" or state.part=="Closest" then part = character:FindFirstChild("Head", true)
            or (state.part=="Closest" and (character:FindFirstChild("UpperTorso",true) or character:FindFirstChild("HumanoidRootPart",true)))
        else
            part = character:FindFirstChild("UpperTorso", true) or character:FindFirstChild("Torso", true)
                or character:FindFirstChild("HumanoidRootPart", true)
        end
        if not part or not part:IsA("BasePart") then return end
        if state.part=="Closest" then
            local head=character:FindFirstChild("Head",true)
            local body=character:FindFirstChild("UpperTorso",true) or character:FindFirstChild("HumanoidRootPart",true)
            local best=math.huge
            for _,candidate in {head,body} do
                if candidate then local p,onScreen=camera:WorldToViewportPoint(candidate.Position)
                    local d=(Vector2.new(p.X,p.Y)-camera.ViewportSize/2).Magnitude
                    if onScreen and d<best then part,best=candidate,d end
                end
            end
        end
        if featurePack and not featurePack:qualifies(other,part) then return end
        local point, visible = camera:WorldToViewportPoint(part.Position)
        if not visible or point.Z <= 0 then return end
        local distance = (Vector2.new(point.X, point.Y) - camera.ViewportSize / 2).Magnitude
        if distance > state.radius then return end
        if state.wallCheck and not (featurePack and featurePack.state.aimTrackWalls) then
            local result = workspace:Raycast(camera.CFrame.Position, part.Position - camera.CFrame.Position, params)
            if result and not result.Instance:IsDescendantOf(character) then return end
        end
        return part, distance
    end
    local function track(camera, dt)
        if (aimSuppressed and aimSuppressed()) or not state.aimlock or Input:GetFocusedTextBox()
            or (featurePack and not featurePack:allowsAim())
            or (state.holdRightMouse and not Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)) then
            lockedPlayer = nil
            return
        end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local excluded = { camera }
        if player.Character then table.insert(excluded, player.Character) end
        params.FilterDescendantsInstances = excluded
        if featurePack and featurePack.state.aimContinuous then lockedPlayer=nil end
        local part = aimPart(lockedPlayer, camera, params)
        if not part then
            lockedPlayer = nil
            local best = state.radius
            for _, other in Players:GetPlayers() do
                local candidate, distance = aimPart(other, camera, params)
                if candidate and distance <= best then
                    part, lockedPlayer, best = candidate, other, distance
                end
            end
        end
        trackedPart=part
        if part then
            local origin = camera.CFrame.Position
            if (part.Position - origin).Magnitude > 0.001 then
                local position=featurePack and featurePack:prediction(part,featurePack.state.aimPrediction) or part.Position
                local goal=CFrame.lookAt(origin,position)
                camera.CFrame = featurePack and featurePack.state.aimInstant and goal or camera.CFrame:Lerp(goal, aimlockAlpha(state.smoothing, dt))
            end
        end
    end
    local function cleanup()
        if not alive then return end
        alive = false
        RunService:UnbindFromRenderStep(binding)
        for _, connection in connections do connection:Disconnect() end
        local keys = {}
        for other in pairs(actors) do table.insert(keys, other) end
        for _, other in keys do removeActor(other) end
        gui:Destroy()
    end
    table.insert(connections, Players.PlayerRemoving:Connect(removeActor))
    local statusElapsed = 0
    RunService:BindToRenderStep(binding, Enum.RenderPriority.Last.Value + 2, function(dt)
        if not alive then return end
        local ok, message = pcall(function()
            local camera = workspace.CurrentCamera
            if not camera then return end
            for _, other in Players:GetPlayers() do
                if other ~= player then drawActor(other, camera, dt) end
            end
            track(camera, dt)
            statusElapsed += dt
            if statusElapsed >= 0.25 then
                statusElapsed = 0
                if lastError then status:Set(lastError)
                elseif not state.aimlock then status:Set("Aimlock off. Higher smoothing = slower tracking.")
                elseif lockedPlayer then status:Set("Tracking " .. lockedPlayer.Name .. " | smoothing " .. state.smoothing)
                elseif state.holdRightMouse and not Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                    status:Set("Hold right mouse to acquire a target.")
                else status:Set("No target: check radius, team filter, visibility, and living players.") end
            end
        end)
        if not ok then
            state.esp, state.aimlock = false, false
            lockedPlayer = nil
            lastError = "ESP/aimlock error: " .. tostring(message)
            status:Set(lastError)
            for _, actor in pairs(actors) do
                actor.box.Visible, actor.tracer.Visible = false, false
                if actor.highlight then actor.highlight.Enabled = false end
                for _,instance in actor.extras do instance.Visible=false end
            end
            warn(lastError)
        end
    end)
    local api = {}
    function api:setFeaturePack(value) featurePack=value end
    function api:setAimSuppressed(callback) aimSuppressed=callback end
    function api:getLockTarget()
        local camera=workspace.CurrentCamera
        if not alive or not state.aimlock or not lockedPlayer or not camera or not trackedPart or not trackedPart.Parent then return end
        local humanoid=lockedPlayer.Character and lockedPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health<=0 then return end
        return trackedPart
    end
    function api:export() return validateVisualAimConfig(state) end
    function api:prepare(saved)
        local normalized = validateVisualAimConfig(saved)
        return function()
            for key, value in pairs(normalized) do
                widgets[key]:Set(key == "color" and Color3.fromRGB(table.unpack(value)) or (key == "part" and { value } or value))
            end
            lockedPlayer = nil
        end
    end
    return cleanup, api
end


local function installPrisonCore(UI,tabs,adapter,visual,environment)
    local Players=game:GetService("Players")local player=Players.LocalPlayer
    local Run=game:GetService("RunService")local Input=game:GetService("UserInputService")
    local Lighting=game:GetService("Lighting")local Http=game:GetService("HttpService")
    local state=validatePrisonSettings({})state.espLobby=true
    local widgets,connections,changes,actors={},{},{},{}
    local alive=true local api={state=state}local skinColor=Color3.fromRGB(164,132,255)
    local selectedGun="MP5"local selectedLocation="Armory"local selectedPlayer=""
    local binding="JewHubPrison_"..Http:GenerateGUID(false)
    local function notify(message)adapter:Notify({Title="JewHub · Prison Life",Content=tostring(message)})end
    local reported={}
    local function report(key,message)if not reported[key]then reported[key]=true notify(message)end end
    local function connect(signal,callback)local c=signal:Connect(callback)table.insert(connections,c)return c end
    local function liveCharacter(other)
        local char=other.Character local hum=char and char:FindFirstChildOfClass("Humanoid")local root=char and char:FindFirstChild("HumanoidRootPart")
        if hum and hum.Health>0 and root then return char,hum,root end
    end
    -- Each property/attribute retains its true initial value, including nil and false.
    local function restore(instance,key)
        local group=changes[instance]local r=group and group[key]if not r then return end
        pcall(function()
            local current
            if r.attribute then current=instance:GetAttribute(key)else current=instance[key]end
            if current==r.applied then if r.attribute then instance:SetAttribute(key,r.base)else instance[key]=r.base end end
        end)
        group[key]=nil if next(group)==nil then changes[instance]=nil end
    end
    local function write(instance,key,value,enabled,attribute)
        if not instance then return end
        if not enabled then restore(instance,key)return end
        changes[instance]=changes[instance]or {}local group=changes[instance]local r=group[key]
        if not r then
            local base if attribute then base=instance:GetAttribute(key)else base=instance[key]end
            r={base=base,attribute=attribute}group[key]=r
        end
        r.applied=value if attribute then instance:SetAttribute(key,value)else instance[key]=value end
    end
    function api:isInDuel()return true end
    function api:isTeammate(other)return player.Team~=nil and not player.Neutral and not other.Neutral and player.Team==other.Team end
    function api:qualifies(other,part)
        if other==player or not part or not part.Parent then return false end
        if state.teamCheck and self:isTeammate(other)then return false end
        local char=other.Character if not char then return false end
        if state.spawnCheck and char:FindFirstChildOfClass("ForceField")then return false end
        local team=other.Team and other.Team.Name
        return not((team=="Guards"and state.ignoreGuards)or(team=="Inmates"and state.ignoreInmates)or(team=="Criminals"and state.ignoreCriminals))
    end
    function api:allowsAim()return true end
    function api:prediction(part)return part.Position end
    function api:getWeaponName(other)local tool=other.Character and other.Character:FindFirstChildOfClass("Tool")return tool and tool.Name end
    local function pickTarget(origin,randomPart)
        local camera=workspace.CurrentCamera if not camera then return end
        local center=camera.ViewportSize/2 local best=state.silentRadius local chosen
        local params=RaycastParams.new()params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={player.Character,camera}
        for _,other in Players:GetPlayers()do
            local char=liveCharacter(other)
            if char then
                local mode=state.hitPart
                if mode=="Random"then mode=randomPart and(math.random(1,2)==1 and "Head"or "Body")or "Body"end
                local part=mode=="Head"and char:FindFirstChild("Head")or(char:FindFirstChild("UpperTorso")or char:FindFirstChild("Torso")or char:FindFirstChild("HumanoidRootPart"))
                if part and api:qualifies(other,part)then
                    local point,onScreen=camera:WorldToViewportPoint(part.Position)
                    local distance=(Vector2.new(point.X,point.Y)-center).Magnitude
                    if onScreen and point.Z>0 and distance<=best then
                        local hit=state.silentWall and workspace:Raycast(origin,part.Position-origin,params)
                        if not hit or hit.Instance:IsDescendantOf(char)then best=distance chosen=part end
                    end
                end
            end
        end
        return chosen
    end
    local lastSilentPart,lastSilentAt
    local castFunction,originalCast
    local function installSilent()
        if castFunction then return true end
        if type(filtergc)~="function"or type(hookfunction)~="function"then
            report("silent","Silent aim needs filtergc and hookfunction; aimlock and ESP remain available.")return false
        end
        local ok,result=pcall(filtergc,"function",{Name="castRay"},true)
        if not ok or type(result)~="function"then report("cast","Could not find this game's castRay function. Silent aim is unavailable in this build.")return false end
        castFunction=result
        local hooked,old=pcall(hookfunction,castFunction,function(...)
            local args=table.pack(...)
            if alive and state.silent and not Input:GetFocusedTextBox()and typeof(args[1])=="Vector3"and typeof(args[2])=="Vector3"and math.random(1,100)<=state.hitChance then
                local success,part=pcall(pickTarget,args[1],true)
                if success and part then args[2]=part.Position lastSilentPart=part lastSilentAt=os.clock()end
            end
            return originalCast(table.unpack(args,1,args.n))
        end)
        if not hooked or type(old)~="function"then castFunction=nil report("hook","The executor could not install silent aim.")return false end
        originalCast=old return true
    end
    for _,entry in schema do
        local tab,key,title,default=tabs[entry[1]],entry[2],entry[3],entry[4]
        local function change(v)
            state[key]=v
            if key=="theme"then UI:SetTheme(v)end
            if key=="silent"and v and not installSilent()then state.silent=false if widgets.silent then widgets.silent:SetValue(false)end end
        end
        if type(default)=="boolean"then
            widgets[key]=tab:AddToggle("PL_"..key,{Title=title,Default=default})widgets[key]:OnChanged(change)
        elseif type(default)=="number"then
            widgets[key]=tab:AddSlider("PL_"..key,{Title=title,Default=default,Min=entry[5],Max=entry[6],Step=entry[7],Rounding=entry[7]<1 and 2 or 0,Callback=change})
        else
            widgets[key]=tab:AddDropdown("PL_"..key,{Title=title,Default=default,Values=entry[5],Multi=false})widgets[key]:OnChanged(change)
        end
    end
    local colorPicker=tabs.Weapons:AddColorpicker("PL_weaponTint",{Title="Weapon colour",Default=skinColor})
    colorPicker:OnChanged(function()skinColor=colorPicker.Value end)
    tabs.Home:AddParagraph({Title="JewHub · Prison Life",Content="Prison Life Script Is Here!"})
    tabs.Home:AddParagraph({Title="Compatibility",Content="Built for the Prison Life version using gun Tool attributes and castRay. ESP and movement use standard Roblox APIs. Server rules still apply to shots, reloads and pickups."})
    tabs.Combat:AddParagraph({Title="Aim controls",Content="Aimlock moves the camera. Silent aim redirects the native castRay destination when supported. Larger smoothing values track more slowly. Auto shoot requires silent aim or an acquired aimlock target."})
    tabs.Weapons:AddParagraph({Title="Weapon support",Content="Uses existing SpreadRadius, AutoFire, ReloadTime and FireRate attributes. Colour/material changes are local previews. Server checks can limit these controls."})
    local locations={Armory=Vector3.new(826,102,2295),["Inside Prison"]=Vector3.new(915,102,2388),["Secret Room"]=Vector3.new(701,102,2354),
        ["Prison Yard"]=Vector3.new(796,100,2541),["Criminal Base"]=Vector3.new(-975,110,2058),["Car Spawner"]=Vector3.new(599,100,2504),Kitchen=Vector3.new(925,102,2228)}
    local names={}for name in pairs(locations)do table.insert(names,name)end table.sort(names)
    local location=tabs.Travel:AddDropdown("PL_location",{Title="Location",Values=names,Default=selectedLocation,Multi=false})location:OnChanged(function(v)selectedLocation=v end)
    local returnPosition
    tabs.Travel:AddButton({Title="Teleport to location",Callback=function()
        local char,_,root=liveCharacter(player)if not char then notify("Spawn before teleporting.")return end
        returnPosition=root.CFrame char:PivotTo(CFrame.new(locations[selectedLocation]))
    end})
    tabs.Travel:AddButton({Title="Return to previous position",Callback=function()local char=liveCharacter(player)if char and returnPosition then char:PivotTo(returnPosition)end end})
    local targetDropdown=tabs.Travel:AddDropdown("PL_player",{Title="Player",Values={},Multi=false})
    targetDropdown:OnChanged(function(v)selectedPlayer=v end)
    local function refreshPlayers()
        local values={}for _,p in Players:GetPlayers()do if p~=player then table.insert(values,p.Name)end end table.sort(values)
        targetDropdown:SetValues(values)if selectedPlayer~=""and not table.find(values,selectedPlayer)then selectedPlayer=""end
    end
    refreshPlayers()connect(Players.PlayerAdded,refreshPlayers)connect(Players.PlayerRemoving,function()task.defer(refreshPlayers)end)
    tabs.Travel:AddButton({Title="Teleport beside selected player",Callback=function()
        local other=Players:FindFirstChild(selectedPlayer)local char=liveCharacter(player)local root
        if other then local _,_,r=liveCharacter(other)root=r end
        if char and root then char:PivotTo(root.CFrame*CFrame.new(3,0,0))else notify("Select a living player.")end
    end})
    tabs.Travel:AddButton({Title="Flip occupied vehicle upright",Callback=function()
        local _,hum=liveCharacter(player)local seat=hum and hum.SeatPart local model=seat and seat:FindFirstAncestorOfClass("Model")
        if not model then notify("Sit in a vehicle first.")return end
        local pivot=model:GetPivot()local _,yaw=pivot:ToOrientation()model:PivotTo(CFrame.new(pivot.Position+Vector3.new(0,3,0))*CFrame.Angles(0,yaw,0))
    end})
    local giverBusy=false
    local gun=tabs.Weapons:AddDropdown("PL_gun",{Title="Pickup weapon",Values={"MP5","M4A1","Remington 870","AK-47"},Default=selectedGun,Multi=false})gun:OnChanged(function(v)selectedGun=v end)
    local function pickup()
        if giverBusy or not alive then return end
        local char,_,root=liveCharacter(player)if not char then notify("Spawn before getting a weapon.")return end
        local backpack=player:FindFirstChildOfClass("Backpack")
        if char:FindFirstChild(selectedGun)or(backpack and backpack:FindFirstChild(selectedGun))then return end
        if type(firetouchinterest)~="function"then report("touch","Weapon pickup needs firetouchinterest. You can still teleport to the armory.")return end
        local giver
        for _,obj in workspace:GetDescendants()do
            if obj.Name=="TouchGiver"and obj:GetAttribute("ToolName")==selectedGun then giver=obj:IsA("BasePart")and obj or obj:FindFirstChildWhichIsA("BasePart")if giver then break end end
        end
        if not giver then notify("No matching weapon giver found in this game build.")return end
        giverBusy=true
        task.spawn(function()
            local before=root.CFrame
            local ok,err=pcall(function()
                char:PivotTo(giver.CFrame*CFrame.new(0,3,0))task.wait(0.2)
                if not alive or player.Character~=char or not giver.Parent then return end
                firetouchinterest(root,giver,0)task.wait(0.15)firetouchinterest(root,giver,1)
            end)
            if player.Character==char and root.Parent then pcall(function()char:PivotTo(before)end)end
            giverBusy=false if not ok and alive then notify("Pickup failed: "..tostring(err))end
        end)
    end
    tabs.Weapons:AddButton({Title="Get selected weapon",Callback=pickup})
    connect(player.CharacterAdded,function(char)
        task.delay(1,function()if alive and state.autoPickup and player.Character==char then pickup()end end)
    end)
    connect(Input.JumpRequest,function()
        if alive and state.infiniteJump and not Input:GetFocusedTextBox()then local _,hum=liveCharacter(player)if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping)end end
    end)
    local function updateWeapons()
        local tools={}
        for _,container in {player.Character,player:FindFirstChildOfClass("Backpack")}do
            if container then for _,tool in container:GetChildren()do if tool:IsA("Tool")then table.insert(tools,tool)end end end
        end
        for _,tool in tools do
            local function attribute(name,value,enabled)
                if tool:GetAttribute(name)~=nil then write(tool,name,value,enabled,true)end
            end
            attribute("SpreadRadius",0,state.noSpread)attribute("AutoFire",true,state.automatic)
            attribute("ReloadTime",state.reloadTime,state.fastReload)
            local original=changes[tool]and changes[tool].FireRate
            local base=original and original.base or tool:GetAttribute("FireRate")
            if type(base)=="number"and base>0 then attribute("FireRate",math.max(0.02,base/state.rapidMultiplier),state.rapidFire)end
            if state.weaponColour or state.neonWeapon or state.weaponOpacity<100 or changes[tool]then
                for _,part in tool:GetDescendants()do if part:IsA("BasePart")then
                    write(part,"Color",skinColor,state.weaponColour)write(part,"Material",Enum.Material.Neon,state.neonWeapon)
                    write(part,"LocalTransparencyModifier",1-state.weaponOpacity/100,state.weaponOpacity<100)
                end end
            end
        end
        -- Restore toggled-off cosmetic properties even if the tool's attributes were never modified.
        local restoreList={}
        for obj,group in pairs(changes)do for key in pairs(group)do
            if(key=="Color"and not state.weaponColour)or(key=="Material"and not state.neonWeapon)or(key=="LocalTransparencyModifier"and state.weaponOpacity==100)then table.insert(restoreList,{obj,key})end
        end end
        for _,entry in restoreList do restore(entry[1],entry[2])end
    end
    local overlay=Instance.new("ScreenGui")overlay.Name="JewHubPrisonOverlay"overlay.ResetOnSpawn=false overlay.IgnoreGuiInset=true overlay.Parent=player:WaitForChild("PlayerGui")
    local ring=Instance.new("Frame")ring.Name="SilentAimRadius"ring.AnchorPoint=Vector2.new(0.5,0.5)ring.BackgroundTransparency=1 ring.Visible=false ring.Parent=overlay
    local corner=Instance.new("UICorner")corner.CornerRadius=UDim.new(1,0)corner.Parent=ring
    local stroke=Instance.new("UIStroke")stroke.Color=Color3.fromRGB(164,132,255)stroke.Thickness=1 stroke.Transparency=0.3 stroke.Parent=ring
    local dot=Instance.new("Frame")dot.Name="Crosshair"dot.AnchorPoint=Vector2.new(0.5,0.5)dot.Size=UDim2.fromOffset(4,4)dot.BackgroundColor3=Color3.fromRGB(245,245,250)dot.BorderSizePixel=0 dot.Visible=false dot.Parent=overlay
    local dotCorner=Instance.new("UICorner")dotCorner.CornerRadius=UDim.new(1,0)dotCorner.Parent=dot
    Run:BindToRenderStep(binding,Enum.RenderPriority.Last.Value+5,function()
        local camera=workspace.CurrentCamera local show=alive and camera and not Input:GetFocusedTextBox()
        ring.Visible=not not(show and state.showFov)dot.Visible=not not(show and state.crosshair)
        if camera then
            local center=camera.ViewportSize/2 ring.Position=UDim2.fromOffset(center.X,center.Y)dot.Position=ring.Position
            ring.Size=UDim2.fromOffset(state.silentRadius*2,state.silentRadius*2)
        end
    end)
    local elapsed,lastShot=0,0
    connect(Run.Stepped,function()
        if not alive then return end
        local char=player.Character
        if char then for _,part in char:GetDescendants()do if part:IsA("BasePart")then write(part,"CanCollide",false,state.noclip)end end end
    end)
    connect(Run.Heartbeat,function(dt)
        if not alive then return end
        local ok,err=pcall(function()
            local char,hum,root=liveCharacter(player)local camera=workspace.CurrentCamera
            if hum then
                write(hum,"WalkSpeed",state.walkSpeed,state.speed)
                write(hum,"UseJumpPower",true,state.jump)write(hum,"JumpPower",state.jumpPower,state.jump)
                write(hum,"AutoRotate",false,state.fly)
            end
            if state.fly and root and camera then
                local move=Vector3.zero
                if not Input:GetFocusedTextBox()then
                    local function held(key)return Input:IsKeyDown(Enum.KeyCode[key])end
                    if held("W")then move+=camera.CFrame.LookVector end if held("S")then move-=camera.CFrame.LookVector end
                    if held("D")then move+=camera.CFrame.RightVector end if held("A")then move-=camera.CFrame.RightVector end
                    if held("Space")then move+=Vector3.yAxis end if held("LeftControl")then move-=Vector3.yAxis end
                end
                root.AssemblyLinearVelocity=move.Magnitude>0 and move.Unit*state.flySpeed or Vector3.zero
            end
            if camera then write(camera,"FieldOfView",state.fov,state.fovOverride)end
            elapsed+=dt if elapsed>=0.25 then
                elapsed=0 updateWeapons()
                write(Lighting,"Brightness",3,state.fullbright)write(Lighting,"Ambient",Color3.fromRGB(180,180,180),state.fullbright)
                write(Lighting,"FogEnd",100000,state.noFog)write(Lighting,"ClockTime",state.clockTime,state.customTime)
            end
            if state.autoShoot and camera and not Input:GetFocusedTextBox()and os.clock()-lastShot>=state.shotInterval then
                local target=state.silent and pickTarget(camera.CFrame.Position,false)or visual:getLockTarget()
                local tool=char and char:FindFirstChildOfClass("Tool")
                if target and tool then lastShot=os.clock()tool:Activate()end
            end
        end)
        if not ok then report("runtime", "Feature update: "..tostring(err))end
    end)
    visual:setFeaturePack(api)
    local cleaned=false
    local function cleanup()
        if cleaned then return end cleaned=true alive=false
        Run:UnbindFromRenderStep(binding)overlay:Destroy()
        for _,connection in connections do connection:Disconnect()end
        if castFunction and originalCast then pcall(hookfunction,castFunction,originalCast)end
        local restoreList={}for obj,group in pairs(changes)do for key in pairs(group)do table.insert(restoreList,{obj,key})end end
        for _,entry in restoreList do restore(entry[1],entry[2])end
    end
    return cleanup,{state=state,widgets=widgets,notify=notify,colorPicker=colorPicker,
        getTracking=function()
            if not alive or Input:GetFocusedTextBox()then return nil,"Idle"end
            if state.silent and lastSilentPart and lastSilentPart.Parent and os.clock()-(lastSilentAt or 0)<0.3 then return lastSilentPart,"Silent shot"end
            local locked=visual:getLockTarget()
            if locked then return locked,"Aimlock"end
            local camera=workspace.CurrentCamera
            if state.silent and camera then return pickTarget(camera.CFrame.Position,false),"Silent candidate"end
            return nil,"Idle"
        end,
        getColor=function()return skinColor end,getGun=function()return selectedGun end,setGun=function(v)gun:SetValue(v)end}
end


local function installPrisonConfig(UI,tab,core,visual,environment)
    local Http=game:GetService("HttpService")
    local fs=type(writefile)=="function"and type(readfile)=="function"and type(isfile)=="function"and type(makefolder)=="function"and type(isfolder)=="function"
    local folder="JewHub/PrisonLife"local profile="default"
    local memory=environment.__JewHubPrisonProfiles or {}environment.__JewHubPrisonProfiles=memory
    if fs then
        local ok=pcall(function()if not isfolder("JewHub")then makefolder("JewHub")end if not isfolder(folder)then makefolder(folder)end end)
        if not ok then fs=false end
    end
    local keybinds={}
    local function notify(message)core.notify(message)end
    local function safe(callback)return function()local ok,err=pcall(callback)if not ok then notify(tostring(err))end end end
    local function validName(name)
        assert(type(name)=="string"and #name>=1 and #name<=48 and name:match("^[%w_-]+$"),"Config name: use 1–48 letters, numbers, _ or -.")return name
    end
    local function keyName(v)return typeof(v)=="EnumItem"and v.Name or tostring(v)end
    for _,entry in {{"Aimlock","VA_aimlock"},{"Silent aim","PL_silent"},{"ESP","VA_esp"},{"Fly","PL_fly"},{"Noclip","PL_noclip"}}do
        local name,flag=entry[1],entry[2]
        local bind=tab:AddKeybind("PL_Bind_"..flag,{Title=name.." keybind",Default="None",Mode="Toggle"})
        bind:OnClick(function()
            local target=UI.Options[flag]
            if target and not game:GetService("UserInputService"):GetFocusedTextBox()then target:SetValue(not target.Value)end
        end)
        keybinds[flag]=bind
    end
    local menuBind=tab:AddKeybind("PL_MenuKey",{Title="Show / hide menu",Default="RightShift",Mode="Toggle"})
    keybinds.menu=menuBind
    local input=tab:AddInput("PL_profile",{Title="Config name",Default=profile,Placeholder="default",Finished=true,Callback=function(value)profile=value end})
    local function capture()
        local keys={}for flag,bind in pairs(keybinds)do keys[flag]=keyName(bind.Value)end
        local c=core.getColor()
        return{version=1,settings=validatePrisonSettings(core.state),visual=visual:export(),gun=core.getGun(),
            weaponColor={math.round(c.R*255),math.round(c.G*255),math.round(c.B*255)},keybinds=keys}
    end
    local function prepare(saved)
        assert(type(saved)=="table"and saved.version==1,"Unsupported config format")
        local settings=validatePrisonSettings(saved.settings)local commitVisual=visual:prepare(saved.visual)
        local color=saved.weaponColor assert(type(color)=="table"and #color==3,"Invalid weapon colour")
        for _,v in color do assert(type(v)=="number"and v==v and v>=0 and v<=255 and v%1==0,"Invalid colour channel")end
        assert(table.find({"MP5","M4A1","Remington 870","AK-47"},saved.gun),"Invalid weapon selection")
        assert(type(saved.keybinds)=="table","Missing keybind settings")
        for flag,v in pairs(saved.keybinds)do
            assert(keybinds[flag]and type(v)=="string","Invalid keybind")
            assert(v=="None"or v=="MB1"or v=="MB2"or Enum.KeyCode[v]~=nil,"Unknown keybind")
        end
        return function()
            for key,value in pairs(settings)do core.widgets[key]:SetValue(value)end
            commitVisual()core.colorPicker:SetValueRGB(Color3.fromRGB(table.unpack(color)))core.setGun(saved.gun)
            for flag,value in pairs(saved.keybinds)do
                if flag=="menu"and value=="RightControl"then value="RightShift"end
                keybinds[flag]:SetValue(value,"Toggle")
            end
        end
    end
    local function save(name)
        name=validName(name)local encoded=Http:JSONEncode(capture())
        if fs then writefile(folder.."/"..name..".json",encoded)else memory[name]=encoded end
    end
    local function load(name)
        name=validName(name)local raw
        if fs then assert(isfile(folder.."/"..name..".json"),"Config not found")raw=readfile(folder.."/"..name..".json")else raw=memory[name]end
        assert(raw,"Config not found")prepare(Http:JSONDecode(raw))()
    end
    tab:AddButton({Title="Save config",Description="Overwrites this profile if it already exists.",Callback=safe(function()save(profile)notify("Saved "..profile)end)})
    tab:AddButton({Title="Load config",Callback=safe(function()load(profile)notify("Loaded "..profile)end)})
    tab:AddButton({Title="Use this config on script startup",Description="Loads settings when you execute the script; does not auto-inject it.",Callback=safe(function()
        save(profile)if fs then writefile(folder.."/autoload.txt",profile)else memory.__autoload=profile end notify("Startup config: "..profile)
    end)})
    tab:AddButton({Title="Clear startup config",Callback=safe(function()
        if fs then writefile(folder.."/autoload.txt","")else memory.__autoload=nil end notify("Startup config cleared.")
    end)})
    tab:AddButton({Title="Copy script loader",Callback=function()
        if type(setclipboard)=="function"then setclipboard('loadstring(game:HttpGet("https://raw.githubusercontent.com/ryanonthehub/JewHub/refs/heads/main/PrisonLife.luau"))()')notify("Loader copied.")else notify("Clipboard API is unavailable.")end
    end})
    tab:AddParagraph({Title="Config storage",Content=fs and "Profiles save in JewHub/PrisonLife in your executor's workspace."or "File APIs unavailable: profiles last for this executor session only."})
    local function autoload()
        local ok,err=pcall(function()
            local name=memory.__autoload if fs and isfile(folder.."/autoload.txt")then name=readfile(folder.."/autoload.txt")end
            if name and name~=""then load(name)input:SetValue(name)profile=name notify("Loaded startup config "..name)end
        end)
        if not ok then notify("Startup config skipped: "..tostring(err))end
    end
    return autoload,{capture=capture,prepare=prepare,save=save,load=load}
end


local function installPrisonMenu(UI,window)
    local Input=game:GetService("UserInputService")
    local originalDestroy=UI.Destroy
    local alive=true
    -- One owner for menu input prevents the library and our handler toggling twice.
    local function setVisible(value)
        if not alive or UI.Unloaded then return end
        window:SetVisible(value)
    end
    window.Minimize=function()setVisible(not window:IsVisible())end
    UI.Destroy=function()setVisible(false)end
    local connection=Input.InputBegan:Connect(function(input)
        if not alive or Input:GetFocusedTextBox()then return end
        for _,option in pairs(UI.Options)do if option.kind=="Keybind"and option.Picking then return end end
        local custom=UI.Options.PL_MenuKey
        local selected=custom and custom.Value
        -- Right Shift always works, even when a saved profile uses another key.
        if input.KeyCode==Enum.KeyCode.RightShift or(selected and input.KeyCode.Name==selected)then
            setVisible(not window:IsVisible())
        end
    end)
    return function()
        if not alive then return end alive=false connection:Disconnect()
        UI.Destroy=originalDestroy
    end
end


local function installPrisonTracker(core,player)
    local Players=game:GetService("Players")local Run=game:GetService("RunService")local Input=game:GetService("UserInputService")
    local binding="JewHubTracker_"..game:GetService("HttpService"):GenerateGUID(false)
    local gui=Instance.new("ScreenGui")gui.Name="JewHubLiveTracker"gui.IgnoreGuiInset=true gui.ResetOnSpawn=false gui.DisplayOrder=85 gui.Parent=player:WaitForChild("PlayerGui")
    local function frame(name,parent,color)
        local obj=Instance.new("Frame")obj.Name=name obj.BorderSizePixel=0 obj.BackgroundColor3=color obj.Parent=parent return obj
    end
    local dark=Color3.fromRGB(17,20,29)local accent=Color3.fromRGB(165,143,255)
    local card=frame("TrackerCard",gui,dark)card.Size=UDim2.fromOffset(308,112)card.BackgroundTransparency=0.06 card.Active=true
    local corner=Instance.new("UICorner")corner.CornerRadius=UDim.new(0,12)corner.Parent=card
    local border=Instance.new("UIStroke")border.Color=Color3.fromRGB(74,78,101)border.Transparency=0.4 border.Thickness=1 border.Parent=card
    local function label(name,text,x,y,width,height,size,color)
        local obj=Instance.new("TextLabel")obj.Name=name obj.BackgroundTransparency=1 obj.Text=text obj.TextColor3=color
        obj.Font=Enum.Font.GothamMedium obj.TextSize=size obj.TextXAlignment=Enum.TextXAlignment.Left
        obj.TextWrapped=false obj.TextTruncate=Enum.TextTruncate.AtEnd obj.RichText=false
        obj.Position=UDim2.fromOffset(x,y)obj.Size=UDim2.fromOffset(width,height)obj.Parent=card return obj
    end
    local muted=Color3.fromRGB(153,160,183)
    label("TrackerTitle","LIVE TARGET",16,10,110,16,10,muted)
    local mode=label("TrackerMode","IDLE",137,10,155,16,10,accent)mode.TextXAlignment=Enum.TextXAlignment.Right
    local name=label("TrackerName","No target",16,32,276,22,16,Color3.fromRGB(240,242,250))
    local detail=label("TrackerDetails","Enable Aimlock or Silent Aim",16,59,276,16,11,muted)
    local healthText=label("TrackerHealth","",16,84,276,15,10,muted)healthText.TextXAlignment=Enum.TextXAlignment.Right
    local track=frame("TrackerHealthTrack",card,Color3.fromRGB(44,49,65))track.Position=UDim2.fromOffset(16,89)track.Size=UDim2.fromOffset(190,5)
    local fill=frame("TrackerHealthFill",track,accent)fill.Size=UDim2.fromScale(0,1)
    for _,obj in {track,fill}do local radius=Instance.new("UICorner")radius.CornerRadius=UDim.new(1,0)radius.Parent=obj end
    local camera=workspace.CurrentCamera
    local viewport=camera and camera.ViewportSize or Vector2.new(800,600)
    local position=Vector2.new(math.max(12,viewport.X-332),math.max(12,viewport.Y-150))
    local function place()
        camera=workspace.CurrentCamera if not camera then return end
        viewport=camera.ViewportSize
        position=Vector2.new(math.clamp(position.X,8,math.max(8,viewport.X-316)),math.clamp(position.Y,8,math.max(8,viewport.Y-120)))
        card.Position=UDim2.fromOffset(position.X,position.Y)
    end
    place()
    local dragInput,dragStart,dragPosition
    local connections={}
    table.insert(connections,card.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragInput=input dragStart=input.Position dragPosition=position
        end
    end))
    table.insert(connections,Input.InputChanged:Connect(function(input)
        if dragInput and(input.UserInputType==Enum.UserInputType.MouseMovement or input==dragInput)then
            local delta=input.Position-dragStart position=dragPosition+Vector2.new(delta.X,delta.Y)place()
        end
    end))
    table.insert(connections,Input.InputEnded:Connect(function(input)
        if input==dragInput or input.UserInputType==Enum.UserInputType.MouseButton1 then dragInput=nil end
    end))
    local active,elapsed,part,trackingMode,ratio=true,0,nil,"Idle",nil
    local function idle()
        name.Text="No target"detail.Text="Enable Aimlock or Silent Aim"mode.Text="IDLE"healthText.Text=""track.Visible=false ratio=nil
    end
    Run:BindToRenderStep(binding,Enum.RenderPriority.Last.Value+8,function(dt)
        if not active then return end
        card.Visible=core.state.targetTracker
        if not card.Visible then part=nil ratio=nil return end
        place()elapsed+=dt
        if elapsed>=0.1 then
            elapsed=0 local ok,target,kind=pcall(core.getTracking)
            if ok then if target~=part then ratio=nil end part,trackingMode=target,kind else part=nil end
        end
        local character=part and part.Parent
        local targetPlayer=character and Players:GetPlayerFromCharacter(character)
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local root=character and character:FindFirstChild("HumanoidRootPart")
        if not targetPlayer or not humanoid or humanoid.Health<=0 or not root then idle()return end
        name.Text=targetPlayer.DisplayName or targetPlayer.Name
        mode.Text=string.upper(trackingMode or "Tracking")
        local origin=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local distance=origin and string.format("%.0f studs",(origin.Position-root.Position).Magnitude)or ""
        local tool=character:FindFirstChildOfClass("Tool")
        detail.Text="@"..targetPlayer.Name.."  ·  "..distance..(tool and "  ·  "..tool.Name or "")
        local fraction=math.clamp(humanoid.Health/math.max(1,humanoid.MaxHealth),0,1)
        ratio=ratio and ratio+(fraction-ratio)*(1-math.exp(-math.max(0,dt)/0.12))or fraction
        fill.Size=UDim2.fromScale(ratio,1)track.Visible=true
        healthText.Text=string.format("%d / %d HP",math.ceil(humanoid.Health),math.ceil(humanoid.MaxHealth))
        fill.BackgroundColor3=fraction<0.3 and Color3.fromRGB(248,126,139)or accent
    end)
    return function()
        if not active then return end active=false
        Run:UnbindFromRenderStep(binding)for _,c in connections do c:Disconnect()end gui:Destroy()
    end
end


-- JewHub · Prison Life | WindUI edition
-- Reference: https://github.com/Lutosys/opensrc/blob/main/PrisonlifeFullScript.lua
-- Independent implementation. No telemetry or remote reference-script execution.
if not game:IsLoaded()then game.Loaded:Wait()end
local environment=type(getgenv)=="function"and getgenv()or _G
if environment.__JewHubPrison then pcall(environment.__JewHubPrison.cleanup)end
local function bootError(message)warn("[JewHub Prison Life] "..tostring(message))end
local ok,NativeUI=pcall(function()
    assert(type(loadstring)=="function","This version needs an executor with loadstring and HTTP support.")
    local source=game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua")
    local chunk,err=loadstring(source)assert(chunk,err)return chunk()
end)
if not ok or type(NativeUI)~="table"then bootError(NativeUI)return end
local UI,window,tabs,adapter=createWindAdapter(NativeUI)
local player=game:GetService("Players").LocalPlayer
local cleanupVisual,visual,cleanupCore,cleanupMenu,cleanupTracker
local cleaned=false
local function cleanup()
    if cleaned then return end cleaned=true
    if cleanupTracker then cleanupTracker()end
    if cleanupMenu then cleanupMenu()end
    if cleanupCore then cleanupCore()end
    if cleanupVisual then cleanupVisual()end
    if not UI.Unloaded then UI:Destroy()end
    if environment.__JewHubPrison and environment.__JewHubPrison.cleanup==cleanup then environment.__JewHubPrison=nil end
end
local success,err=pcall(function()
    cleanupVisual,visual=installVisualAim(adapter,adapter,player)
    local core
    cleanupCore,core=installPrisonCore(UI,tabs,adapter,visual,environment)
    local autoload,config=installPrisonConfig(UI,tabs.Settings,core,visual,environment)
    tabs.Settings:AddButton({Title="Unload JewHub",Description="Restores modified properties and removes this menu.",Callback=cleanup})
    cleanupMenu=installPrisonMenu(UI,window)
    cleanupTracker=installPrisonTracker(core,player)
    environment.__JewHubPrison={cleanup=cleanup,config=config}
    autoload()
    adapter:Notify({Title="JewHub · Prison Life",Content="Ready. Right Shift shows or hides the menu."})
end)
if not success then bootError(err)cleanup()end
