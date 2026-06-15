local ok_services, InputService = pcall(function() return game:GetService("UserInputService") end)
local _,           TextService  = pcall(function() return game:GetService("TextService") end)
local _,           CoreGui      = pcall(function() return game:GetService("CoreGui") end)
local _,           Teams        = pcall(function() return game:GetService("Teams") end)
local _,           Players      = pcall(function() return game:GetService("Players") end)
local _,           RunService   = pcall(function() return game:GetService("RunService") end)
local _,           TweenService = pcall(function() return game:GetService("TweenService") end)

local RenderStepped = RunService and RunService.RenderStepped
local Heartbeat     = RunService and RunService.Heartbeat
local LocalPlayer   = Players and Players.LocalPlayer
local Mouse         = LocalPlayer and LocalPlayer:GetMouse()

local ProtectGui = (rawget(_G, "protectgui"))
    or (syn and rawget(syn, "protect_gui") and syn.protect_gui)
    or function() end

local ScreenGui = Instance.new("ScreenGui")
pcall(ProtectGui, ScreenGui)
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.ResetOnSpawn   = false
ScreenGui.Parent         = CoreGui

local Toggles = {}
local Options = {}
if getgenv then
    getgenv().Toggles = Toggles
    getgenv().Options = Options
end

local function MakeFont(weight, style)
    local ok, f = pcall(function()
        return Font.new(
            "rbxasset://fonts/families/DancingScript.json",
            weight or Enum.FontWeight.Regular,
            style  or Enum.FontStyle.Italic
        )
    end)
    if ok then return f end
    local ok2, f2 = pcall(function()
        return Font.new(
            "rbxasset://fonts/families/GothamSSm.json",
            weight or Enum.FontWeight.Regular,
            Enum.FontStyle.Italic
        )
    end)
    if ok2 then return f2 end
    return Enum.Font.GothamSemibold
end

local _boundsCache = {}
local function GetTextBounds(text, font, size, res)
    local fontKey = typeof(font) == "Font" and (font.Family .. tostring(font.Weight) .. tostring(font.Style)) or tostring(font)
    local key = tostring(text) .. fontKey .. tostring(size)
    if _boundsCache[key] then return _boundsCache[key].X, _boundsCache[key].Y end
    local ok, b = pcall(function()
        return TextService:GetTextSize(text, size, font, res or Vector2.new(1920, 1080))
    end)
    local v = ok and b or Vector2.new(#text * size * 0.6, size)
    _boundsCache[key] = v
    return v.X, v.Y
end

local Library = {
    Registry        = {};
    RegistryMap     = {};
    HudRegistry     = {};

    FontColor       = Color3.fromRGB(255, 255, 255);
    MainColor       = Color3.fromRGB(28,  28,  28);
    BackgroundColor = Color3.fromRGB(20,  20,  20);
    AccentColor     = Color3.fromRGB(0,   85,  255);
    OutlineColor    = Color3.fromRGB(50,  50,  50);
    RiskColor       = Color3.fromRGB(255, 50,  50);
    Black           = Color3.new(0, 0, 0);
    ToastSuccess    = Color3.fromRGB(40,  200, 100);
    ToastError      = Color3.fromRGB(220, 60,  60);
    ToastInfo       = Color3.fromRGB(0,   140, 255);
    ToastWarning    = Color3.fromRGB(255, 165, 0);

    CornerRadius    = UDim.new(0, 6);

    Font            = MakeFont();

    OpenedFrames    = {};
    DependencyBoxes = {};
    Signals         = {};
    Drawings        = {};
    ScreenGui       = ScreenGui;

    NotifyOnError   = true;

    WindowOutlineGradientTop    = Color3.fromRGB(0, 85, 255);
    WindowOutlineGradientBottom = Color3.fromRGB(0, 20, 80);
}

Library.AccentColorDark = (function()
    local H, S, V = Color3.toHSV(Library.AccentColor)
    return Color3.fromHSV(H, S, V / 1.5)
end)()

function Library:GetDarkerColor(c)
    if typeof(c) ~= "Color3" then return Color3.new(0, 0, 0) end
    local H, S, V = Color3.toHSV(c)
    return Color3.fromHSV(H, S, V / 1.5)
end

function Library:SafeCallback(f, ...)
    if type(f) ~= "function" then return end
    if not self.NotifyOnError then
        local ok, err = pcall(f, ...)
        return ok, err
    end
    local ok, err = pcall(f, ...)
    if not ok then
        local _, i = tostring(err):find(":%d+: ")
        self:Toast(i and tostring(err):sub(i + 1) or tostring(err), { Type = "Error", Time = 4 })
    end
    return ok
end

function Library:GiveSignal(sig)
    if sig then table.insert(self.Signals, sig) end
    return sig
end

function Library:GiveDrawing(d)
    if d then table.insert(self.Drawings, d) end
    return d
end

function Library:AttemptSave()
    if self.SaveManager then
        pcall(function() self.SaveManager:Save() end)
    end
end

function Library:Create(class, props)
    local inst = class
    if type(class) == "string" then
        inst = Instance.new(class)
    end
    if type(props) == "table" then
        for k, v in next, props do
            pcall(function() inst[k] = v end)
        end
    end
    return inst
end

function Library:ApplyCornerRadius(inst, radius)
    self:Create("UICorner", {
        CornerRadius = radius or self.CornerRadius;
        Parent       = inst;
    })
end

function Library:ApplyTextStroke(inst)
    pcall(function() inst.TextStrokeTransparency = 1 end)
    self:Create("UIStroke", {
        Color        = Color3.new(0, 0, 0);
        Thickness    = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent       = inst;
    })
end

function Library:CreateLabel(props, isHud)
    local lbl = self:Create("TextLabel", {
        BackgroundTransparency = 1;
        FontFace               = self.Font;
        TextColor3             = self.FontColor;
        TextSize               = 16;
        TextStrokeTransparency = 0;
    })
    self:ApplyTextStroke(lbl)
    self:AddToRegistry(lbl, { TextColor3 = "FontColor" }, isHud)
    return self:Create(lbl, props or {})
end

function Library:AddToRegistry(inst, props, isHud)
    if not inst then return end
    local data = { Instance = inst; Properties = props or {} }
    table.insert(self.Registry, data)
    self.RegistryMap[inst] = data
    if isHud then table.insert(self.HudRegistry, data) end
end

function Library:RemoveFromRegistry(inst)
    local data = self.RegistryMap[inst]
    if not data then return end
    for i = #self.Registry, 1, -1 do
        if self.Registry[i] == data then table.remove(self.Registry, i) end
    end
    for i = #self.HudRegistry, 1, -1 do
        if self.HudRegistry[i] == data then table.remove(self.HudRegistry, i) end
    end
    self.RegistryMap[inst] = nil
end

function Library:UpdateColorsUsingRegistry()
    for _, obj in next, self.Registry do
        if obj.Instance and obj.Instance.Parent then
            for prop, colorIdx in next, obj.Properties do
                pcall(function()
                    if type(colorIdx) == "string" then
                        obj.Instance[prop] = Library[colorIdx]
                    elseif type(colorIdx) == "function" then
                        obj.Instance[prop] = colorIdx()
                    end
                end)
            end
        end
    end
    Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor)
end

function Library:RefreshTheme()
    self.AccentColorDark = self:GetDarkerColor(self.AccentColor)
    self:UpdateColorsUsingRegistry()
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(inst)
    if Library.RegistryMap[inst] then
        Library:RemoveFromRegistry(inst)
    end
end))

local rainbowAccum, hue = 0, 0
Library:GiveSignal(Heartbeat:Connect(function(dt)
    rainbowAccum += dt
    if rainbowAccum >= 1 / 60 then
        rainbowAccum = 0
        hue = (hue + 1 / 400) % 1
        Library.CurrentRainbowHue   = hue
        Library.CurrentRainbowColor = Color3.fromHSV(hue, 0.8, 1)
    end
end))

function Library:MapValue(v, minA, maxA, minB, maxB)
    local t = (v - minA) / (maxA - minA)
    return (1 - t) * minB + t * maxB
end

function Library:GetViewportSize()
    local cam = workspace.CurrentCamera
    if cam then return cam.ViewportSize end
    return Vector2.new(1920, 1080)
end

function Library:MakeDraggable(frame, cutoff)
    frame.Active = true
    frame.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local op = Vector2.new(
            Mouse.X - frame.AbsolutePosition.X,
            Mouse.Y - frame.AbsolutePosition.Y
        )
        if op.Y > (cutoff or 40) then return end
        while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
            local vp  = self:GetViewportSize()
            local sx  = frame.AbsoluteSize.X
            local sy  = frame.AbsoluteSize.Y
            local nx  = math.clamp(Mouse.X - op.X, 0, vp.X - sx)
            local ny  = math.clamp(Mouse.Y - op.Y, 0, vp.Y - sy)
            frame.Position = UDim2.new(
                frame.Position.X.Scale, nx + sx * frame.AnchorPoint.X,
                frame.Position.Y.Scale, ny + sy * frame.AnchorPoint.Y
            )
            RenderStepped:Wait()
        end
    end)
end

function Library:MouseIsOverOpenedFrame()
    for frame in next, self.OpenedFrames do
        local p, s = frame.AbsolutePosition, frame.AbsoluteSize
        if Mouse.X >= p.X and Mouse.X <= p.X + s.X
        and Mouse.Y >= p.Y and Mouse.Y <= p.Y + s.Y then
            return true
        end
    end
end

function Library:IsMouseOverFrame(frame)
    if not frame or not frame.Parent then return false end
    local p, s = frame.AbsolutePosition, frame.AbsoluteSize
    return Mouse.X >= p.X and Mouse.X <= p.X + s.X
       and Mouse.Y >= p.Y and Mouse.Y <= p.Y + s.Y
end

function Library:UpdateDependencyBoxes()
    for _, db in next, self.DependencyBoxes do
        pcall(function() db:Update() end)
    end
end

function Library:AddToolTip(infoStr, hoverInst)
    if type(infoStr) ~= "string" or not hoverInst then return end
    local X, Y = GetTextBounds(infoStr, self.Font, 14)
    local tip = self:Create("Frame", {
        BackgroundColor3 = self.MainColor;
        BorderColor3     = self.OutlineColor;
        Size             = UDim2.fromOffset(X + 5, Y + 4);
        ZIndex           = 100;
        Parent           = ScreenGui;
        Visible          = false;
    })
    self:ApplyCornerRadius(tip)
    local lbl = self:CreateLabel({
        Position       = UDim2.fromOffset(3, 1);
        Size           = UDim2.fromOffset(X, Y);
        TextSize       = 14;
        Text           = infoStr;
        TextColor3     = self.FontColor;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex         = 101;
        Parent         = tip;
    })
    self:AddToRegistry(tip, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor" })
    self:AddToRegistry(lbl, { TextColor3 = "FontColor" })
    local hovering = false
    hoverInst.MouseEnter:Connect(function()
        if self:MouseIsOverOpenedFrame() then return end
        hovering = true
        tip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        tip.Visible  = true
        while hovering do
            Heartbeat:Wait()
            tip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end
    end)
    hoverInst.MouseLeave:Connect(function()
        hovering     = false
        tip.Visible  = false
    end)
end

function Library:OnHighlight(hoverInst, target, onProps, offProps)
    hoverInst.MouseEnter:Connect(function()
        local reg = self.RegistryMap[target]
        for prop, colorIdx in next, onProps do
            pcall(function() target[prop] = self[colorIdx] or colorIdx end)
            if reg and reg.Properties[prop] then reg.Properties[prop] = colorIdx end
        end
    end)
    hoverInst.MouseLeave:Connect(function()
        local reg = self.RegistryMap[target]
        for prop, colorIdx in next, offProps do
            pcall(function() target[prop] = self[colorIdx] or colorIdx end)
            if reg and reg.Properties[prop] then reg.Properties[prop] = colorIdx end
        end
    end)
end

local function GetPlayersString()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        table.insert(list, p.Name)
    end
    table.sort(list)
    return list
end

local function GetTeamsString()
    local list = {}
    for _, t in ipairs(Teams:GetTeams()) do
        table.insert(list, t.Name)
    end
    table.sort(list)
    return list
end

local _overlay
function Library:ShowOverlay(alpha, color)
    if not _overlay then
        _overlay = self:Create("Frame", {
            BackgroundColor3       = color or Color3.new(0, 0, 0);
            BackgroundTransparency = 1 - (alpha or 0.5);
            BorderSizePixel        = 0;
            Size                   = UDim2.fromScale(1, 1);
            ZIndex                 = 50;
            Parent                 = ScreenGui;
        })
    else
        _overlay.BackgroundTransparency = 1 - (alpha or 0.5)
        _overlay.BackgroundColor3       = color or Color3.new(0, 0, 0)
        _overlay.Visible                = true
    end
end

function Library:HideOverlay()
    if _overlay then _overlay.Visible = false end
end

do
    local ToastArea = Library:Create("Frame", {
        BackgroundTransparency = 1;
        AnchorPoint            = Vector2.new(1, 1);
        Position               = UDim2.new(1, -14, 1, -14);
        Size                   = UDim2.fromOffset(280, 0);
        ZIndex                 = 200;
        Parent                 = ScreenGui;
    })
    Library:Create("UIListLayout", {
        Padding           = UDim.new(0, 6);
        FillDirection     = Enum.FillDirection.Vertical;
        VerticalAlignment = Enum.VerticalAlignment.Bottom;
        SortOrder         = Enum.SortOrder.LayoutOrder;
        Parent            = ToastArea;
    })
    Library.ToastArea = ToastArea

    local TypeColors = {
        Success = "ToastSuccess";
        Error   = "ToastError";
        Info    = "ToastInfo";
        Warning = "ToastWarning";
    }

    function Library:Toast(text, opts)
        opts = opts or {}
        local ttype   = opts.Type    or "Info"
        local time    = opts.Time    or 4
        local title   = opts.Title
        local onClick = opts.OnClick
        local accent  = TypeColors[ttype] or "ToastInfo"
        local accentC = self[accent] or self.AccentColor
        local totalH  = title and 46 or 32
        local tw      = 280

        local outer = self:Create("Frame", {
            BackgroundColor3 = self.MainColor;
            BorderColor3     = self.OutlineColor;
            ClipsDescendants = true;
            Size             = UDim2.fromOffset(0, totalH);
            ZIndex           = 201;
            Parent           = ToastArea;
        })
        self:ApplyCornerRadius(outer)
        self:AddToRegistry(outer, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor" })

        local bar = self:Create("Frame", {
            BackgroundColor3 = accentC;
            BorderSizePixel  = 0;
            Size             = UDim2.new(0, 3, 1, 0);
            ZIndex           = 202;
            Parent           = outer;
        })
        self:AddToRegistry(bar, { BackgroundColor3 = accent })

        local y = 0
        if title then
            local tlbl = self:CreateLabel({
                Position       = UDim2.fromOffset(10, 4);
                Size           = UDim2.new(1, -10, 0, 16);
                TextSize       = 14;
                Text           = title;
                TextColor3     = accentC;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex         = 202;
                Parent         = outer;
            })
            self:AddToRegistry(tlbl, { TextColor3 = accent })
            y = 18
        end

        self:CreateLabel({
            Position       = UDim2.fromOffset(10, y + 4);
            Size           = UDim2.new(1, -10, 0, totalH - y - 8);
            TextSize       = 13;
            Text           = text;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextWrapped    = true;
            ZIndex         = 202;
            Parent         = outer;
        })

        local prog = self:Create("Frame", {
            BackgroundColor3 = accentC;
            BorderSizePixel  = 0;
            Position         = UDim2.new(0, 0, 1, -2);
            Size             = UDim2.new(1, 0, 0, 2);
            ZIndex           = 203;
            Parent           = outer;
        })
        self:AddToRegistry(prog, { BackgroundColor3 = accent })

        if onClick then
            outer.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    pcall(onClick)
                end
            end)
        end

        pcall(function()
            outer:TweenSize(UDim2.fromOffset(tw, totalH), "Out", "Quad", 0.25, true)
        end)

        task.spawn(function()
            local start = tick()
            while tick() - start < time and outer.Parent do
                local frac = 1 - (tick() - start) / time
                pcall(function() prog.Size = UDim2.new(frac, 0, 0, 2) end)
                Heartbeat:Wait()
            end
            pcall(function()
                outer:TweenSize(UDim2.fromOffset(0, totalH), "In", "Quad", 0.2, true)
            end)
            task.wait(0.22)
            pcall(function() outer:Destroy() end)
        end)
    end

    function Library:Notify(text, time)
        self:Toast(text, { Time = time or 5 })
    end
end

do
    local KS = {}
    Library.KeySystem = KS

    local SAVE_PATH = "LinoriaKey_%s.txt"

    local function tryRead(file)
        if not readfile then return nil end
        local ok, v = pcall(readfile, file)
        return ok and v or nil
    end

    local function trySave(file, val)
        if not writefile then return end
        pcall(writefile, file, val)
    end

    function KS:Create(cfg)
        assert(type(cfg) == "table", "KeySystem:Create requires a config table")
        cfg.Title     = cfg.Title    or "Key System"
        cfg.Subtitle  = cfg.Subtitle or "Enter your key to continue"
        cfg.OnSuccess = cfg.OnSuccess or function() end
        cfg.OnFail    = cfg.OnFail    or function() end
        cfg.Time      = cfg.Time      or 0

        local validKeys = {}
        if type(cfg.Key) == "string" then
            validKeys[cfg.Key:lower()] = true
        end
        if type(cfg.Keys) == "table" then
            for _, k in ipairs(cfg.Keys) do
                validKeys[k:lower()] = true
            end
        end

        local fileName = cfg.FileName or string.format(SAVE_PATH, cfg.Title:gsub("%s", "_"))

        if cfg.SaveKey then
            local saved = tryRead(fileName)
            if saved then
                local trimmed = saved:lower():match("^%s*(.-)%s*$") or ""
                if validKeys[trimmed] then
                    task.defer(cfg.OnSuccess)
                    return
                end
            end
        end

        Library:ShowOverlay(0.7)

        local W, H    = 380, 220
        local outerFrame = Library:Create("Frame", {
            AnchorPoint      = Vector2.new(0.5, 0.5);
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderSizePixel  = 0;
            Position         = UDim2.fromScale(0.5, 0.5);
            Size             = UDim2.fromOffset(W, H);
            ZIndex           = 60;
            Parent           = ScreenGui;
        })
        Library:ApplyCornerRadius(outerFrame)

        local inner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3     = Library.AccentColor;
            BorderMode       = Enum.BorderMode.Inset;
            Size             = UDim2.new(1, -2, 1, -2);
            Position         = UDim2.fromOffset(1, 1);
            ZIndex           = 61;
            Parent           = outerFrame;
        })
        Library:ApplyCornerRadius(inner)
        Library:AddToRegistry(inner, { BackgroundColor3 = "MainColor"; BorderColor3 = "AccentColor" })

        local accentBar = Library:Create("Frame", {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, 0, 0, 3);
            ZIndex           = 62;
            Parent           = inner;
        })
        Library:AddToRegistry(accentBar, { BackgroundColor3 = "AccentColor" })

        Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
            Rotation = -90;
            Parent   = inner;
        })

        Library:CreateLabel({
            Position       = UDim2.fromOffset(0, 12);
            Size           = UDim2.new(1, 0, 0, 28);
            TextSize       = 22;
            Text           = cfg.Title;
            ZIndex         = 62;
            Parent         = inner;
        })

        Library:CreateLabel({
            Position   = UDim2.fromOffset(0, 38);
            Size       = UDim2.new(1, 0, 0, 16);
            TextSize   = 13;
            Text       = cfg.Subtitle;
            TextColor3 = Color3.fromRGB(170, 170, 170);
            ZIndex     = 62;
            Parent     = inner;
        })

        local boxOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3     = Color3.new(0, 0, 0);
            Position         = UDim2.fromOffset(20, 70);
            Size             = UDim2.new(1, -40, 0, 30);
            ZIndex           = 62;
            Parent           = inner;
        })
        Library:ApplyCornerRadius(boxOuter)
        local boxInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3     = Library.OutlineColor;
            BorderMode       = Enum.BorderMode.Inset;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 63;
            Parent           = boxOuter;
        })
        Library:ApplyCornerRadius(boxInner)
        Library:AddToRegistry(boxInner, { BackgroundColor3 = "BackgroundColor"; BorderColor3 = "OutlineColor" })

        local box = Library:Create("TextBox", {
            BackgroundTransparency = 1;
            Position               = UDim2.fromOffset(8, 0);
            Size                   = UDim2.new(1, -8, 1, 0);
            FontFace               = Library.Font;
            PlaceholderText        = "Enter your key…";
            PlaceholderColor3      = Color3.fromRGB(100, 100, 100);
            Text                   = "";
            TextColor3             = Library.FontColor;
            TextSize               = 15;
            TextXAlignment         = Enum.TextXAlignment.Left;
            ZIndex                 = 64;
            Parent                 = boxInner;
        })
        Library:ApplyTextStroke(box)
        Library:AddToRegistry(box, { TextColor3 = "FontColor" })

        local statusLbl = Library:CreateLabel({
            Position       = UDim2.fromOffset(20, 108);
            Size           = UDim2.new(1, -40, 0, 16);
            TextSize       = 12;
            Text           = "";
            TextColor3     = Color3.fromRGB(140, 140, 140);
            TextXAlignment = Enum.TextXAlignment.Center;
            ZIndex         = 62;
            Parent         = inner;
        })

        local btnOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3     = Color3.new(0, 0, 0);
            Position         = UDim2.fromOffset(20, 130);
            Size             = UDim2.new(1, -40, 0, 30);
            ZIndex           = 62;
            Parent           = inner;
        })
        Library:ApplyCornerRadius(btnOuter)
        local btnInner = Library:Create("Frame", {
            BackgroundColor3 = Library.AccentColor;
            BorderColor3     = Library.AccentColorDark;
            BorderMode       = Enum.BorderMode.Inset;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 63;
            Parent           = btnOuter;
        })
        Library:ApplyCornerRadius(btnInner)
        Library:AddToRegistry(btnInner, { BackgroundColor3 = "AccentColor"; BorderColor3 = "AccentColorDark" })
        Library:Create("UIGradient", {
            Color    = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)) });
            Rotation = 90;
            Parent   = btnInner;
        })
        Library:CreateLabel({
            Size     = UDim2.fromScale(1, 1);
            TextSize = 15;
            Text     = "Verify Key";
            ZIndex   = 64;
            Parent   = btnInner;
        })
        Library:OnHighlight(btnOuter, btnOuter,
            { BorderColor3 = "FontColor" },
            { BorderColor3 = "Black" }
        )
        Library:CreateLabel({
            Position   = UDim2.fromOffset(0, 175);
            Size       = UDim2.new(1, 0, 0, 14);
            TextSize   = 11;
            Text       = "Press Enter or click Verify";
            TextColor3 = Color3.fromRGB(80, 80, 80);
            ZIndex     = 62;
            Parent     = inner;
        })

        Library:MakeDraggable(outerFrame, 60)

        local attempts = 0

        local function verify()
            local input = box.Text:match("^%s*(.-)%s*$"):lower()
            attempts += 1
            if validKeys[input] then
                statusLbl.Text       = "✓ Key accepted!"
                statusLbl.TextColor3 = Library.ToastSuccess
                if cfg.SaveKey then trySave(fileName, box.Text) end
                Library:Toast("Key verified successfully!", { Type = "Success", Title = cfg.Title })
                task.wait(0.8)
                pcall(function() outerFrame:Destroy() end)
                Library:HideOverlay()
                task.spawn(cfg.OnSuccess)
            else
                statusLbl.Text       = string.format("✗ Invalid key (attempt %d)", attempts)
                statusLbl.TextColor3 = Library.ToastError
                Library:Toast("Invalid key entered.", { Type = "Error", Time = 3 })
                local origPos = btnOuter.Position
                for i = 1, 4 do
                    task.wait(0.04)
                    local off = (i % 2 == 0) and 4 or -4
                    pcall(function() btnOuter.Position = origPos + UDim2.fromOffset(off, 0) end)
                end
                task.wait(0.04)
                pcall(function() btnOuter.Position = origPos end)
                if cfg.Time > 0 and attempts >= cfg.Time then
                    task.wait(0.5)
                    pcall(function() outerFrame:Destroy() end)
                    Library:HideOverlay()
                    task.spawn(cfg.OnFail, attempts)
                else
                    task.spawn(cfg.OnFail, attempts)
                end
            end
        end

        btnOuter.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then verify() end
        end)
        box.FocusLost:Connect(function(enter)
            if enter then verify() end
        end)
    end
end

local BaseAddons = {}
do
    local Funcs = {}

    function Funcs:AddColorPicker(Idx, Info)
        assert(Info.Default, "AddColorPicker: Missing default value.")
        local ToggleLabel = self.TextLabel

        local CP = {
            Value        = Info.Default;
            Transparency = Info.Transparency or 0;
            Type         = "ColorPicker";
            Title        = type(Info.Title) == "string" and Info.Title or "Color picker";
            Callback     = Info.Callback or function() end;
        }

        function CP:SetHSVFromRGB(c)
            CP.Hue, CP.Sat, CP.Vib = Color3.toHSV(c)
        end
        CP:SetHSVFromRGB(CP.Value)

        local DisplayFrame = Library:Create("Frame", {
            BackgroundColor3 = CP.Value;
            BorderColor3     = Library:GetDarkerColor(CP.Value);
            BorderMode       = Enum.BorderMode.Inset;
            Size             = UDim2.new(0, 28, 0, 14);
            ZIndex           = 6;
            Parent           = ToggleLabel;
        })
        Library:ApplyCornerRadius(DisplayFrame, UDim.new(0, 3))

        Library:Create("ImageLabel", {
            BorderSizePixel = 0;
            Size            = UDim2.new(0, 27, 0, 13);
            ZIndex          = 5;
            Image           = "http://www.roblox.com/asset/?id=12977615774";
            Visible         = not not Info.Transparency;
            Parent          = DisplayFrame;
        })

        local pickerH = Info.Transparency and 271 or 253
        local PickerOuter = Library:Create("Frame", {
            Name             = "Color";
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderColor3     = Color3.new(0, 0, 0);
            Position         = UDim2.fromOffset(0, 0);
            Size             = UDim2.fromOffset(230, pickerH);
            Visible          = false;
            ZIndex           = 15;
            Parent           = ScreenGui;
        })
        Library:ApplyCornerRadius(PickerOuter)

        local function repositionPicker()
            if not DisplayFrame.Parent then return end
            PickerOuter.Position = UDim2.fromOffset(
                DisplayFrame.AbsolutePosition.X,
                DisplayFrame.AbsolutePosition.Y + 18
            )
        end
        DisplayFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(repositionPicker)
        task.defer(repositionPicker)

        local PickerInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3     = Library.OutlineColor;
            BorderMode       = Enum.BorderMode.Inset;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 16;
            Parent           = PickerOuter;
        })
        Library:ApplyCornerRadius(PickerInner)
        Library:AddToRegistry(PickerInner, { BackgroundColor3 = "BackgroundColor"; BorderColor3 = "OutlineColor" })

        local Highlight = Library:Create("Frame", {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, 0, 0, 2);
            ZIndex           = 17;
            Parent           = PickerInner;
        })
        Library:AddToRegistry(Highlight, { BackgroundColor3 = "AccentColor" })

        local SVOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Position     = UDim2.new(0, 4, 0, 25);
            Size         = UDim2.new(0, 200, 0, 200);
            ZIndex       = 17;
            Parent       = PickerInner;
        })
        Library:ApplyCornerRadius(SVOuter, UDim.new(0, 4))
        local SVInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3     = Library.OutlineColor;
            BorderMode       = Enum.BorderMode.Inset;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 18;
            Parent           = SVOuter;
        })
        Library:ApplyCornerRadius(SVInner, UDim.new(0, 4))
        Library:AddToRegistry(SVInner, { BackgroundColor3 = "BackgroundColor"; BorderColor3 = "OutlineColor" })
        local SVMap = Library:Create("ImageLabel", {
            BorderSizePixel = 0;
            Size            = UDim2.new(1, 0, 1, 0);
            ZIndex          = 18;
            Image           = "rbxassetid://4155801252";
            Parent          = SVInner;
        })
        Library:ApplyCornerRadius(SVMap, UDim.new(0, 4))
        local CursorOuter = Library:Create("ImageLabel", {
            AnchorPoint            = Vector2.new(0.5, 0.5);
            Size                   = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image                  = "http://www.roblox.com/asset/?id=9619665977";
            ImageColor3            = Color3.new(0, 0, 0);
            ZIndex                 = 19;
            Parent                 = SVMap;
        })
        Library:Create("ImageLabel", {
            Size                   = UDim2.new(0, 4, 0, 4);
            Position               = UDim2.fromOffset(1, 1);
            BackgroundTransparency = 1;
            Image                  = "http://www.roblox.com/asset/?id=9619665977";
            ZIndex                 = 20;
            Parent                 = CursorOuter;
        })

        local HueOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Position     = UDim2.new(0, 208, 0, 25);
            Size         = UDim2.new(0, 15, 0, 200);
            ZIndex       = 17;
            Parent       = PickerInner;
        })
        Library:ApplyCornerRadius(HueOuter, UDim.new(0, 4))
        local HueInner = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 18;
            Parent           = HueOuter;
        })
        Library:ApplyCornerRadius(HueInner, UDim.new(0, 4))
        local HueCursor = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint      = Vector2.new(0, 0.5);
            BorderColor3     = Color3.new(0, 0, 0);
            Size             = UDim2.new(1, 0, 0, 1);
            ZIndex           = 18;
            Parent           = HueInner;
        })
        local hueSeq = {}
        for h = 0, 1, 0.1 do
            table.insert(hueSeq, ColorSequenceKeypoint.new(h, Color3.fromHSV(h, 1, 1)))
        end
        Library:Create("UIGradient", { Color = ColorSequence.new(hueSeq); Rotation = 90; Parent = HueInner })

        local HexOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Position     = UDim2.fromOffset(4, 228);
            Size         = UDim2.new(0.5, -6, 0, 20);
            ZIndex       = 18;
            Parent       = PickerInner;
        })
        Library:ApplyCornerRadius(HexOuter, UDim.new(0, 3))
        local HexInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3     = Library.OutlineColor;
            BorderMode       = Enum.BorderMode.Inset;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 18;
            Parent           = HexOuter;
        })
        Library:ApplyCornerRadius(HexInner, UDim.new(0, 3))
        Library:AddToRegistry(HexInner, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor" })
        Library:Create("UIGradient", {
            Color    = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)) });
            Rotation = 90;
            Parent   = HexInner;
        })
        local HexBox = Library:Create("TextBox", {
            BackgroundTransparency = 1;
            Position               = UDim2.fromOffset(5, 0);
            Size                   = UDim2.new(1, -5, 1, 0);
            FontFace               = Library.Font;
            PlaceholderColor3      = Color3.fromRGB(190, 190, 190);
            PlaceholderText        = "Hex";
            Text                   = "#FFFFFF";
            TextColor3             = Library.FontColor;
            TextSize               = 14;
            TextXAlignment         = Enum.TextXAlignment.Left;
            ZIndex                 = 20;
            Parent                 = HexInner;
        })
        Library:ApplyTextStroke(HexBox)
        Library:AddToRegistry(HexBox, { TextColor3 = "FontColor" })

        local RgbOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Position     = UDim2.new(0.5, 2, 0, 228);
            Size         = UDim2.new(0.5, -6, 0, 20);
            ZIndex       = 18;
            Parent       = PickerInner;
        })
        Library:ApplyCornerRadius(RgbOuter, UDim.new(0, 3))
        local RgbInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3     = Library.OutlineColor;
            BorderMode       = Enum.BorderMode.Inset;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 18;
            Parent           = RgbOuter;
        })
        Library:ApplyCornerRadius(RgbInner, UDim.new(0, 3))
        Library:AddToRegistry(RgbInner, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor" })
        Library:Create("UIGradient", {
            Color    = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)) });
            Rotation = 90;
            Parent   = RgbInner;
        })
        local RgbBox = Library:Create("TextBox", {
            BackgroundTransparency = 1;
            Position               = UDim2.fromOffset(5, 0);
            Size                   = UDim2.new(1, -5, 1, 0);
            FontFace               = Library.Font;
            PlaceholderColor3      = Color3.fromRGB(190, 190, 190);
            PlaceholderText        = "RGB";
            Text                   = "255, 255, 255";
            TextColor3             = Library.FontColor;
            TextSize               = 14;
            TextXAlignment         = Enum.TextXAlignment.Left;
            ZIndex                 = 20;
            Parent                 = RgbInner;
        })
        Library:ApplyTextStroke(RgbBox)
        Library:AddToRegistry(RgbBox, { TextColor3 = "FontColor" })

        local AlphaInner, AlphaCursor
        if Info.Transparency then
            local AlphaOuter = Library:Create("Frame", {
                BorderColor3 = Color3.new(0, 0, 0);
                Position     = UDim2.fromOffset(4, 251);
                Size         = UDim2.new(1, -8, 0, 15);
                ZIndex       = 19;
                Parent       = PickerInner;
            })
            Library:ApplyCornerRadius(AlphaOuter, UDim.new(0, 3))
            AlphaInner = Library:Create("Frame", {
                BackgroundColor3 = CP.Value;
                BorderColor3     = Library.OutlineColor;
                BorderMode       = Enum.BorderMode.Inset;
                Size             = UDim2.new(1, 0, 1, 0);
                ZIndex           = 19;
                Parent           = AlphaOuter;
            })
            Library:ApplyCornerRadius(AlphaInner, UDim.new(0, 3))
            Library:AddToRegistry(AlphaInner, { BorderColor3 = "OutlineColor" })
            Library:Create("ImageLabel", {
                BackgroundTransparency = 1;
                Size                   = UDim2.new(1, 0, 1, 0);
                Image                  = "http://www.roblox.com/asset/?id=12978095818";
                ZIndex                 = 20;
                Parent                 = AlphaInner;
            })
            AlphaCursor = Library:Create("Frame", {
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint      = Vector2.new(0.5, 0);
                BorderColor3     = Color3.new(0, 0, 0);
                Size             = UDim2.new(0, 1, 1, 0);
                ZIndex           = 21;
                Parent           = AlphaInner;
            })
        end

        Library:CreateLabel({
            Size           = UDim2.new(1, 0, 0, 14);
            Position       = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize       = 14;
            Text           = CP.Title;
            TextWrapped    = false;
            ZIndex         = 16;
            Parent         = PickerInner;
        })

        local CtxContainer = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            ZIndex       = 14;
            Visible      = false;
            Parent       = ScreenGui;
        })
        Library:ApplyCornerRadius(CtxContainer)
        local CtxInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3     = Library.OutlineColor;
            BorderMode       = Enum.BorderMode.Inset;
            Size             = UDim2.fromScale(1, 1);
            ZIndex           = 15;
            Parent           = CtxContainer;
        })
        Library:ApplyCornerRadius(CtxInner)
        Library:AddToRegistry(CtxInner, { BackgroundColor3 = "BackgroundColor"; BorderColor3 = "OutlineColor" })
        local ctxLayout = Library:Create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = CtxInner })
        Library:Create("UIPadding", { PaddingLeft = UDim.new(0, 4); Parent = CtxInner })

        local function ctxUpdatePos()
            if not DisplayFrame.Parent then return end
            CtxContainer.Position = UDim2.fromOffset(
                DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X + 4,
                DisplayFrame.AbsolutePosition.Y + 1
            )
        end
        local function ctxUpdateSize()
            local w = 60
            for _, c in next, CtxInner:GetChildren() do
                if c:IsA("TextLabel") then w = math.max(w, c.TextBounds.X) end
            end
            CtxContainer.Size = UDim2.fromOffset(w + 8, ctxLayout.AbsoluteContentSize.Y + 4)
        end
        DisplayFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(ctxUpdatePos)
        ctxLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(ctxUpdateSize)
        task.defer(ctxUpdatePos)
        task.defer(ctxUpdateSize)

        local function addCtxOption(str, cb)
            local btn = Library:CreateLabel({
                Active         = false;
                Size           = UDim2.new(1, 0, 0, 15);
                TextSize       = 13;
                Text           = str;
                ZIndex         = 16;
                Parent         = CtxInner;
                TextXAlignment = Enum.TextXAlignment.Left;
            })
            Library:OnHighlight(btn, btn, { TextColor3 = "AccentColor" }, { TextColor3 = "FontColor" })
            btn.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    pcall(cb)
                end
            end)
        end

        addCtxOption("Copy colour", function()
            Library.ColorClipboard = CP.Value
            Library:Toast("Colour copied!", { Type = "Success", Time = 2 })
        end)
        addCtxOption("Paste colour", function()
            if not Library.ColorClipboard then
                return Library:Toast("No colour copied yet.", { Type = "Warning", Time = 2 })
            end
            CP:SetValueRGB(Library.ColorClipboard)
        end)
        addCtxOption("Copy HEX", function()
            pcall(setclipboard, CP.Value:ToHex())
            Library:Toast("Hex copied!", { Type = "Info", Time = 2 })
        end)
        addCtxOption("Copy RGB", function()
            pcall(setclipboard, table.concat({ math.floor(CP.Value.R * 255), math.floor(CP.Value.G * 255), math.floor(CP.Value.B * 255) }, ", "))
            Library:Toast("RGB copied!", { Type = "Info", Time = 2 })
        end)

        function CP:Display()
            CP.Value = Color3.fromHSV(CP.Hue, CP.Sat, CP.Vib)
            SVMap.BackgroundColor3 = Color3.fromHSV(CP.Hue, 1, 1)
            pcall(function()
                DisplayFrame.BackgroundColor3       = CP.Value
                DisplayFrame.BackgroundTransparency = CP.Transparency
                DisplayFrame.BorderColor3           = Library:GetDarkerColor(CP.Value)
            end)
            if AlphaInner then
                AlphaInner.BackgroundColor3 = CP.Value
                AlphaCursor.Position        = UDim2.new(1 - CP.Transparency, 0, 0, 0)
            end
            CursorOuter.Position = UDim2.new(CP.Sat, 0, 1 - CP.Vib, 0)
            HueCursor.Position   = UDim2.new(0, 0, CP.Hue, 0)
            HexBox.Text          = "#" .. CP.Value:ToHex()
            RgbBox.Text          = table.concat({ math.floor(CP.Value.R * 255), math.floor(CP.Value.G * 255), math.floor(CP.Value.B * 255) }, ", ")
            Library:SafeCallback(CP.Callback, CP.Value)
            Library:SafeCallback(CP.Changed,  CP.Value)
        end
        function CP:OnChanged(f) CP.Changed = f; f(CP.Value) end
        function CP:Show()
            for f in next, Library.OpenedFrames do
                if f.Name == "Color" then f.Visible = false; Library.OpenedFrames[f] = nil end
            end
            repositionPicker()
            PickerOuter.Visible = true
            Library.OpenedFrames[PickerOuter] = true
        end
        function CP:Hide()
            PickerOuter.Visible = false
            Library.OpenedFrames[PickerOuter] = nil
        end
        function CP:SetValue(hsv, trans)
            CP.Transparency = trans or 0
            CP:SetHSVFromRGB(Color3.fromHSV(hsv[1], hsv[2], hsv[3]))
            CP:Display()
        end
        function CP:SetValueRGB(c, trans)
            CP.Transparency = trans or 0
            CP:SetHSVFromRGB(c)
            CP:Display()
        end

        SVMap.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local minX = SVMap.AbsolutePosition.X
                    local maxX = minX + SVMap.AbsoluteSize.X
                    local minY = SVMap.AbsolutePosition.Y
                    local maxY = minY + SVMap.AbsoluteSize.Y
                    CP.Sat = (math.clamp(Mouse.X, minX, maxX) - minX) / (maxX - minX)
                    CP.Vib = 1 - ((math.clamp(Mouse.Y, minY, maxY) - minY) / (maxY - minY))
                    CP:Display()
                    RenderStepped:Wait()
                end
                Library:AttemptSave()
            end
        end)
        HueInner.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local minY = HueInner.AbsolutePosition.Y
                    local maxY = minY + HueInner.AbsoluteSize.Y
                    CP.Hue = (math.clamp(Mouse.Y, minY, maxY) - minY) / (maxY - minY)
                    CP:Display()
                    RenderStepped:Wait()
                end
                Library:AttemptSave()
            end
        end)
        if AlphaInner then
            AlphaInner.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                        local minX = AlphaInner.AbsolutePosition.X
                        local maxX = minX + AlphaInner.AbsoluteSize.X
                        CP.Transparency = 1 - ((math.clamp(Mouse.X, minX, maxX) - minX) / (maxX - minX))
                        CP:Display()
                        RenderStepped:Wait()
                    end
                    Library:AttemptSave()
                end
            end)
        end
        DisplayFrame.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if PickerOuter.Visible then CP:Hide() else CtxContainer.Visible = false; CP:Show() end
            elseif inp.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                CtxContainer.Visible = true; CP:Hide()
            end
        end)
        HexBox.FocusLost:Connect(function(enter)
            if enter then
                local ok, c = pcall(Color3.fromHex, HexBox.Text)
                if ok then CP:SetHSVFromRGB(c) end
            end
            CP:Display()
        end)
        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match("(%d+),%s*(%d+),%s*(%d+)")
                if r then CP:SetHSVFromRGB(Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))) end
            end
            CP:Display()
        end)
        Library:GiveSignal(InputService.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                local p, s = PickerOuter.AbsolutePosition, PickerOuter.AbsoluteSize
                if Mouse.X < p.X or Mouse.X > p.X + s.X or Mouse.Y < (p.Y - 21) or Mouse.Y > p.Y + s.Y then
                    CP:Hide()
                end
                if not Library:IsMouseOverFrame(CtxContainer) then CtxContainer.Visible = false end
            end
            if inp.UserInputType == Enum.UserInputType.MouseButton2 and CtxContainer.Visible then
                if not Library:IsMouseOverFrame(CtxContainer) and not Library:IsMouseOverFrame(DisplayFrame) then
                    CtxContainer.Visible = false
                end
            end
        end))

        CP:Display()
        CP.DisplayFrame = DisplayFrame
        Options[Idx] = CP
        return self
    end

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj   = self
        local ToggleLabel = self.TextLabel

        assert(Info.Default, "AddKeyPicker: Missing default value.")

        local KP = {
            Value           = Info.Default;
            Toggled         = false;
            Mode            = Info.Mode or "Toggle";
            Type            = "KeyPicker";
            Callback        = Info.Callback or function() end;
            ChangedCallback = Info.ChangedCallback or function() end;
            SyncToggleState = Info.SyncToggleState or false;
        }
        if KP.SyncToggleState then Info.Modes = { "Toggle" }; Info.Mode = "Toggle" end

        local PickOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3     = Color3.new(0, 0, 0);
            Size             = UDim2.new(0, 28, 0, 15);
            ZIndex           = 6;
            Parent           = ToggleLabel;
        })
        Library:ApplyCornerRadius(PickOuter, UDim.new(0, 3))
        local PickInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3     = Library.OutlineColor;
            BorderMode       = Enum.BorderMode.Inset;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 7;
            Parent           = PickOuter;
        })
        Library:ApplyCornerRadius(PickInner, UDim.new(0, 3))
        Library:AddToRegistry(PickInner, { BackgroundColor3 = "BackgroundColor"; BorderColor3 = "OutlineColor" })
        local DispLabel = Library:CreateLabel({
            Size        = UDim2.new(1, 0, 1, 0);
            TextSize    = 13;
            Text        = Info.Default;
            TextWrapped = true;
            ZIndex      = 8;
            Parent      = PickInner;
        })

        local ModeOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Position     = UDim2.fromOffset(0, 0);
            Size         = UDim2.new(0, 60, 0, 47);
            Visible      = false;
            ZIndex       = 14;
            Parent       = ScreenGui;
        })
        Library:ApplyCornerRadius(ModeOuter)

        local function repositionModeOuter()
            if not ToggleLabel.Parent then return end
            ModeOuter.Position = UDim2.fromOffset(
                ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4,
                ToggleLabel.AbsolutePosition.Y + 1
            )
        end
        ToggleLabel:GetPropertyChangedSignal("AbsolutePosition"):Connect(repositionModeOuter)
        task.defer(repositionModeOuter)

        local ModeInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3     = Library.OutlineColor;
            BorderMode       = Enum.BorderMode.Inset;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 15;
            Parent           = ModeOuter;
        })
        Library:ApplyCornerRadius(ModeInner)
        Library:AddToRegistry(ModeInner, { BackgroundColor3 = "BackgroundColor"; BorderColor3 = "OutlineColor" })
        Library:Create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = ModeInner })

        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left;
            Size           = UDim2.new(1, 0, 0, 18);
            TextSize       = 13;
            Visible        = false;
            ZIndex         = 110;
            Parent         = Library.KeybindContainer;
        }, true)

        local Modes       = Info.Modes or { "Always", "Toggle", "Hold" }
        local ModeButtons = {}

        for _, mode in next, Modes do
            local MB  = {}
            local lbl = Library:CreateLabel({
                Active         = false;
                Size           = UDim2.new(1, 0, 0, 15);
                TextSize       = 13;
                Text           = mode;
                ZIndex         = 16;
                Parent         = ModeInner;
            })
            function MB:Select()
                for _, b in next, ModeButtons do b:Deselect() end
                KP.Mode = mode
                pcall(function()
                    lbl.TextColor3 = Library.AccentColor
                    Library.RegistryMap[lbl].Properties.TextColor3 = "AccentColor"
                end)
                ModeOuter.Visible = false
            end
            function MB:Deselect()
                pcall(function()
                    lbl.TextColor3 = Library.FontColor
                    Library.RegistryMap[lbl].Properties.TextColor3 = "FontColor"
                end)
            end
            lbl.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    MB:Select(); Library:AttemptSave()
                end
            end)
            if mode == KP.Mode then MB:Select() end
            ModeButtons[mode] = MB
        end

        function KP:Update()
            if Info.NoUI then return end
            local state = KP:GetState()
            ContainerLabel.Text    = string.format("[%s] %s (%s)", KP.Value, Info.Text or Idx, KP.Mode or "?")
            ContainerLabel.Visible = true
            ContainerLabel.TextColor3 = state and Library.AccentColor or Library.FontColor
            local reg = Library.RegistryMap[ContainerLabel]
            if reg then reg.Properties.TextColor3 = state and "AccentColor" or "FontColor" end

            local ySize, xSize = 0, 0
            for _, lbl2 in next, Library.KeybindContainer:GetChildren() do
                if lbl2:IsA("TextLabel") and lbl2.Visible then
                    ySize += 18
                    if lbl2.TextBounds.X > xSize then xSize = lbl2.TextBounds.X end
                end
            end
            Library.KeybindFrame.Size = UDim2.new(0, math.max(xSize + 10, 210), 0, ySize + 23)
        end

        function KP:GetState()
            if KP.Mode == "Always" then
                return true
            elseif KP.Mode == "Hold" then
                if KP.Value == "None" then return false end
                local k = KP.Value
                if k == "MB1" then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                elseif k == "MB2" then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                else return InputService:IsKeyDown(Enum.KeyCode[k]) end
            else
                return KP.Toggled
            end
        end

        function KP:SetValue(data)
            local key, mode = data[1], data[2]
            DispLabel.Text = key
            KP.Value       = key
            if ModeButtons[mode] then ModeButtons[mode]:Select() end
            KP:Update()
        end

        function KP:OnClick(cb)   KP.Clicked  = cb end
        function KP:OnChanged(cb) KP.Changed  = cb; cb(KP.Value) end

        function KP:DoClick()
            if ParentObj.Type == "Toggle" and KP.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end
            Library:SafeCallback(KP.Callback, KP.Toggled)
            Library:SafeCallback(KP.Clicked,  KP.Toggled)
        end

        if ParentObj.Addons then table.insert(ParentObj.Addons, KP) end

        local picking = false
        PickOuter.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                picking = true
                DispLabel.Text = ""
                local brk  = false
                local dots = ""
                task.spawn(function()
                    while not brk do
                        dots = #dots >= 3 and "" or dots .. "."
                        DispLabel.Text = dots
                        task.wait(0.4)
                    end
                end)
                task.wait(0.2)
                local ev
                ev = Library:GiveSignal(InputService.InputBegan:Connect(function(inp2)
                    local key
                    if inp2.UserInputType == Enum.UserInputType.Keyboard then key = inp2.KeyCode.Name
                    elseif inp2.UserInputType == Enum.UserInputType.MouseButton1 then key = "MB1"
                    elseif inp2.UserInputType == Enum.UserInputType.MouseButton2 then key = "MB2" end
                    if not key then return end
                    brk     = true
                    picking = false
                    DispLabel.Text = key
                    KP.Value       = key
                    Library:SafeCallback(KP.ChangedCallback, inp2.KeyCode or inp2.UserInputType)
                    Library:SafeCallback(KP.Changed,         inp2.KeyCode or inp2.UserInputType)
                    Library:AttemptSave()
                    ev:Disconnect()
                end))
            elseif inp.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                repositionModeOuter()
                ModeOuter.Visible = true
            end
        end)

        Library:GiveSignal(InputService.InputBegan:Connect(function(inp)
            if not picking then
                if KP.Mode == "Toggle" then
                    local k = KP.Value
                    if (k == "MB1" and inp.UserInputType == Enum.UserInputType.MouseButton1)
                    or (k == "MB2" and inp.UserInputType == Enum.UserInputType.MouseButton2)
                    or (inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode.Name == k) then
                        KP.Toggled = not KP.Toggled
                        KP:DoClick()
                    end
                end
                KP:Update()
            end
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                local p, s = ModeOuter.AbsolutePosition, ModeOuter.AbsoluteSize
                if Mouse.X < p.X or Mouse.X > p.X + s.X or Mouse.Y < (p.Y - 21) or Mouse.Y > p.Y + s.Y then
                    ModeOuter.Visible = false
                end
            end
        end))
        Library:GiveSignal(InputService.InputEnded:Connect(function()
            if not picking then KP:Update() end
        end))

        KP:Update()
        Options[Idx] = KP
        return self
    end

    BaseAddons.__index = Funcs
    BaseAddons.__namecall = function(_, k, ...) return Funcs[k](...) end
end

local BaseGroupbox = {}
do
    local Funcs = {}

    function Funcs:AddBlank(size)
        Library:Create("Frame", {
            BackgroundTransparency = 1;
            Size   = UDim2.new(1, 0, 0, size or 5);
            ZIndex = 1;
            Parent = self.Container;
        })
    end

    function Funcs:AddLabel(text, doesWrap)
        local lbl = {}
        local container = self.Container
        local tl = Library:CreateLabel({
            Size           = UDim2.new(1, -4, 0, 15);
            TextSize       = 14;
            Text           = text;
            TextWrapped    = doesWrap or false;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex         = 5;
            Parent         = container;
        })
        if doesWrap then
            local y = select(2, GetTextBounds(text, Library.Font, 14, Vector2.new(tl.AbsoluteSize.X, math.huge)))
            tl.Size = UDim2.new(1, -4, 0, y)
        else
            Library:Create("UIListLayout", {
                Padding             = UDim.new(0, 4);
                FillDirection       = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                SortOrder           = Enum.SortOrder.LayoutOrder;
                Parent              = tl;
            })
        end
        lbl.TextLabel = tl
        lbl.Container = container
        function lbl:SetText(t)
            tl.Text = t
            if doesWrap then
                local y = select(2, GetTextBounds(t, Library.Font, 14, Vector2.new(tl.AbsoluteSize.X, math.huge)))
                tl.Size = UDim2.new(1, -4, 0, y)
            end
            self:Resize()
        end
        if not doesWrap then setmetatable(lbl, BaseAddons) end
        self:AddBlank(5)
        self:Resize()
        return lbl
    end

    function Funcs:AddButton(...)
        local Btn = {}
        local function ParseParams(obj, ...)
            local p = select(1, ...)
            if type(p) == "table" then
                obj.Text        = p.Text
                obj.Func        = p.Func
                obj.DoubleClick = p.DoubleClick
                obj.Tooltip     = p.Tooltip
            else
                obj.Text = select(1, ...)
                obj.Func = select(2, ...)
            end
            assert(type(obj.Func) == "function", "AddButton: Func callback is missing.")
        end
        ParseParams(Btn, ...)

        local container = self.Container

        local function MakeBase(b)
            local outer = Library:Create("Frame", {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3     = Color3.new(0, 0, 0);
                Size             = UDim2.new(1, -4, 0, 20);
                ZIndex           = 5;
            })
            Library:ApplyCornerRadius(outer)
            local inner = Library:Create("Frame", {
                BackgroundColor3 = Library.MainColor;
                BorderColor3     = Library.OutlineColor;
                BorderMode       = Enum.BorderMode.Inset;
                Size             = UDim2.new(1, 0, 1, 0);
                ZIndex           = 6;
                Parent           = outer;
            })
            Library:ApplyCornerRadius(inner)
            local lbl = Library:CreateLabel({
                Size     = UDim2.new(1, 0, 1, 0);
                TextSize = 14;
                Text     = b.Text;
                ZIndex   = 6;
                Parent   = inner;
            })
            Library:Create("UIGradient", {
                Color    = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)) });
                Rotation = 90;
                Parent   = inner;
            })
            Library:AddToRegistry(outer, { BorderColor3 = "Black" })
            Library:AddToRegistry(inner, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor" })
            Library:OnHighlight(outer, outer, { BorderColor3 = "AccentColor" }, { BorderColor3 = "Black" })
            return outer, inner, lbl
        end

        local function InitEvents(b)
            local function ValidClick(inp)
                return not Library:MouseIsOverOpenedFrame() and inp.UserInputType == Enum.UserInputType.MouseButton1
            end
            b.Outer.InputBegan:Connect(function(inp)
                if not ValidClick(inp) or b.Locked then return end
                if b.DoubleClick then
                    Library:RemoveFromRegistry(b.Label)
                    Library:AddToRegistry(b.Label, { TextColor3 = "AccentColor" })
                    b.Label.TextColor3 = Library.AccentColor
                    b.Label.Text = "Are you sure?"
                    b.Locked = true
                    local clicked = false
                    local ev = b.Outer.InputBegan:Once(function(i2)
                        if ValidClick(i2) then clicked = true end
                    end)
                    task.delay(0.5, function() pcall(function() ev:Disconnect() end) end)
                    task.wait(0.5)
                    Library:RemoveFromRegistry(b.Label)
                    Library:AddToRegistry(b.Label, { TextColor3 = "FontColor" })
                    b.Label.TextColor3 = Library.FontColor
                    b.Label.Text = b.Text
                    task.defer(rawset, b, "Locked", false)
                    if clicked then Library:SafeCallback(b.Func) end
                    return
                end
                Library:SafeCallback(b.Func)
            end)
        end

        Btn.Outer, Btn.Inner, Btn.Label = MakeBase(Btn)
        Btn.Outer.Parent = container
        InitEvents(Btn)

        function Btn:AddTooltip(tt)
            if type(tt) == "string" then Library:AddToolTip(tt, self.Outer) end
            return self
        end
        function Btn:AddButton(...)
            local sub = {}
            ParseParams(sub, ...)
            self.Outer.Size = UDim2.new(0.5, -2, 0, 20)
            sub.Outer, sub.Inner, sub.Label = MakeBase(sub)
            sub.Outer.AnchorPoint = Vector2.new(0, 0)
            sub.Outer.Position    = UDim2.new(1, 3, 0, 0)
            sub.Outer.Size        = UDim2.new(0.5, -2, 0, 20)
            sub.Outer.Parent      = self.Outer.Parent
            InitEvents(sub)
            function sub:AddTooltip(tt)
                if type(tt) == "string" then Library:AddToolTip(tt, self.Outer) end
                return self
            end
            if type(sub.Tooltip) == "string" then sub:AddTooltip(sub.Tooltip) end
            return sub
        end
        if type(Btn.Tooltip) == "string" then Btn:AddTooltip(Btn.Tooltip) end
        self:AddBlank(5)
        self:Resize()
        return Btn
    end

    function Funcs:AddDivider()
        self:AddBlank(2)
        local outer = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3     = Color3.new(0, 0, 0);
            Size             = UDim2.new(1, -4, 0, 5);
            ZIndex           = 5;
            Parent           = self.Container;
        })
        local inner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3     = Library.OutlineColor;
            BorderMode       = Enum.BorderMode.Inset;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 6;
            Parent           = outer;
        })
        Library:AddToRegistry(outer, { BorderColor3 = "Black" })
        Library:AddToRegistry(inner, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor" })
        self:AddBlank(9)
        self:Resize()
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, "AddInput: Missing `Text`.")
        local TB = {
            Value    = Info.Default or "";
            Numeric  = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type     = "Input";
            Callback = Info.Callback or function() end;
        }
        local container = self.Container
        Library:CreateLabel({
            Size           = UDim2.new(1, 0, 0, 15);
            TextSize       = 14;
            Text           = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex         = 5;
            Parent         = container;
        })
        self:AddBlank(1)
        local outer = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3     = Color3.new(0, 0, 0);
            Size             = UDim2.new(1, -4, 0, 20);
            ZIndex           = 5;
            Parent           = container;
        })
        Library:ApplyCornerRadius(outer)
        local inner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3     = Library.OutlineColor;
            BorderMode       = Enum.BorderMode.Inset;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 6;
            Parent           = outer;
        })
        Library:ApplyCornerRadius(inner)
        Library:AddToRegistry(inner, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor" })
        Library:OnHighlight(outer, outer, { BorderColor3 = "AccentColor" }, { BorderColor3 = "Black" })
        if type(Info.Tooltip) == "string" then Library:AddToolTip(Info.Tooltip, outer) end
        Library:Create("UIGradient", {
            Color    = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)) });
            Rotation = 90;
            Parent   = inner;
        })
        local clip = Library:Create("Frame", {
            BackgroundTransparency = 1;
            ClipsDescendants       = true;
            Position               = UDim2.fromOffset(5, 0);
            Size                   = UDim2.new(1, -5, 1, 0);
            ZIndex                 = 7;
            Parent                 = inner;
        })
        local box = Library:Create("TextBox", {
            BackgroundTransparency = 1;
            Position               = UDim2.fromOffset(0, 0);
            Size                   = UDim2.fromScale(5, 1);
            FontFace               = Library.Font;
            PlaceholderColor3      = Color3.fromRGB(190, 190, 190);
            PlaceholderText        = Info.Placeholder or "";
            Text                   = Info.Default or "";
            TextColor3             = Library.FontColor;
            TextSize               = 14;
            TextXAlignment         = Enum.TextXAlignment.Left;
            ZIndex                 = 7;
            Parent                 = clip;
        })
        Library:ApplyTextStroke(box)
        Library:AddToRegistry(box, { TextColor3 = "FontColor" })

        function TB:SetValue(t)
            if Info.MaxLength and #t > Info.MaxLength then t = t:sub(1, Info.MaxLength) end
            if TB.Numeric and not tonumber(t) and #t > 0 then t = TB.Value end
            TB.Value = t; box.Text = t
            Library:SafeCallback(TB.Callback, TB.Value)
            Library:SafeCallback(TB.Changed,  TB.Value)
        end
        function TB:OnChanged(f) TB.Changed = f; f(TB.Value) end

        if TB.Finished then
            box.FocusLost:Connect(function(enter)
                if enter then TB:SetValue(box.Text); Library:AttemptSave() end
            end)
        else
            box:GetPropertyChangedSignal("Text"):Connect(function()
                TB:SetValue(box.Text); Library:AttemptSave()
            end)
        end

        local function updateCursor()
            local PADDING = 2
            local reveal  = clip.AbsoluteSize.X
            if not box:IsFocused() or box.TextBounds.X <= reveal - 2 * PADDING then
                box.Position = UDim2.fromOffset(PADDING, 0)
            else
                local cur = box.CursorPosition
                if cur ~= -1 then
                    local sub = string.sub(box.Text, 1, cur - 1)
                    local w   = TextService:GetTextSize(sub, box.TextSize, Enum.Font.GothamSemibold, Vector2.new(math.huge, math.huge)).X
                    local cur2 = box.Position.X.Offset + w
                    if cur2 < PADDING then
                        box.Position = UDim2.fromOffset(PADDING - w, 0)
                    elseif cur2 > reveal - PADDING - 1 then
                        box.Position = UDim2.fromOffset(reveal - w - PADDING - 1, 0)
                    end
                end
            end
        end
        task.spawn(updateCursor)
        box:GetPropertyChangedSignal("Text"):Connect(updateCursor)
        box:GetPropertyChangedSignal("CursorPosition"):Connect(updateCursor)
        box.FocusLost:Connect(updateCursor)
        box.Focused:Connect(updateCursor)

        self:AddBlank(5)
        self:Resize()
        Options[Idx] = TB
        return TB
    end

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, "AddToggle: Missing `Text`.")
        local Toggle = {
            Value    = Info.Default or false;
            Type     = "Toggle";
            Callback = Info.Callback or function() end;
            Addons   = {};
            Risky    = Info.Risky;
        }
        local container = self.Container
        local outer = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3     = Color3.new(0, 0, 0);
            Size             = UDim2.new(0, 13, 0, 13);
            ZIndex           = 5;
            Parent           = container;
        })
        Library:ApplyCornerRadius(outer, UDim.new(0, 3))
        Library:AddToRegistry(outer, { BorderColor3 = "Black" })
        local inner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3     = Library.OutlineColor;
            BorderMode       = Enum.BorderMode.Inset;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 6;
            Parent           = outer;
        })
        Library:ApplyCornerRadius(inner, UDim.new(0, 3))
        Library:AddToRegistry(inner, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor" })
        local lbl = Library:CreateLabel({
            Size           = UDim2.new(0, 216, 1, 0);
            Position       = UDim2.new(1, 6, 0, 0);
            TextSize       = 14;
            Text           = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex         = 6;
            Parent         = inner;
        })
        Library:Create("UIListLayout", {
            Padding             = UDim.new(0, 4);
            FillDirection       = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            SortOrder           = Enum.SortOrder.LayoutOrder;
            Parent              = lbl;
        })
        local region = Library:Create("Frame", {
            BackgroundTransparency = 1;
            Size   = UDim2.new(0, 170, 1, 0);
            ZIndex = 8;
            Parent = outer;
        })
        Library:OnHighlight(region, outer, { BorderColor3 = "AccentColor" }, { BorderColor3 = "Black" })

        if type(Info.Tooltip) == "string" then Library:AddToolTip(Info.Tooltip, region) end

        function Toggle:Display()
            inner.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor
            inner.BorderColor3     = Toggle.Value and Library.AccentColorDark or Library.OutlineColor
            local reg = Library.RegistryMap[inner]
            if reg then
                reg.Properties.BackgroundColor3 = Toggle.Value and "AccentColor" or "MainColor"
                reg.Properties.BorderColor3     = Toggle.Value and "AccentColorDark" or "OutlineColor"
            end
        end
        function Toggle:OnChanged(f) Toggle.Changed = f; f(Toggle.Value) end
        function Toggle:SetValue(b)
            b = not not b
            Toggle.Value = b
            Toggle:Display()
            for _, addon in next, Toggle.Addons do
                if addon.Type == "KeyPicker" and addon.SyncToggleState then
                    addon.Toggled = b; addon:Update()
                end
            end
            Library:SafeCallback(Toggle.Callback, Toggle.Value)
            Library:SafeCallback(Toggle.Changed,  Toggle.Value)
            Library:UpdateDependencyBoxes()
        end
        region.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value)
                Library:AttemptSave()
            end
        end)

        if Toggle.Risky then
            Library:RemoveFromRegistry(lbl)
            lbl.TextColor3 = Library.RiskColor
            Library:AddToRegistry(lbl, { TextColor3 = "RiskColor" })
        end

        Toggle:Display()
        self:AddBlank(Info.BlankSize or 7)
        self:Resize()
        Toggle.TextLabel = lbl
        Toggle.Container = container
        setmetatable(Toggle, BaseAddons)
        Toggles[Idx] = Toggle
        Library:UpdateDependencyBoxes()
        return Toggle
    end

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default  ~= nil, "AddSlider: Missing default.")
        assert(Info.Text,            "AddSlider: Missing text.")
        assert(Info.Min      ~= nil, "AddSlider: Missing min.")
        assert(Info.Max      ~= nil, "AddSlider: Missing max.")
        assert(Info.Rounding ~= nil, "AddSlider: Missing rounding.")

        local SL = {
            Value    = Info.Default;
            Min      = Info.Min;
            Max      = Info.Max;
            Rounding = Info.Rounding;
            Type     = "Slider";
            Callback = Info.Callback or function() end;
        }
        local container = self.Container

        if not Info.Compact then
            Library:CreateLabel({
                Size           = UDim2.new(1, 0, 0, 10);
                TextSize       = 14;
                Text           = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex         = 5;
                Parent         = container;
            })
            self:AddBlank(3)
        end

        local outer = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3     = Color3.new(0, 0, 0);
            Size             = UDim2.new(1, -4, 0, 13);
            ZIndex           = 5;
            Parent           = container;
        })
        Library:ApplyCornerRadius(outer, UDim.new(0, 3))
        Library:AddToRegistry(outer, { BorderColor3 = "Black" })
        local inner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3     = Library.OutlineColor;
            BorderMode       = Enum.BorderMode.Inset;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 6;
            Parent           = outer;
        })
        Library:ApplyCornerRadius(inner, UDim.new(0, 3))
        Library:AddToRegistry(inner, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor" })
        local fill = Library:Create("Frame", {
            BackgroundColor3 = Library.AccentColor;
            BorderColor3     = Library.AccentColorDark;
            Size             = UDim2.new(0, 0, 1, 0);
            ZIndex           = 7;
            Parent           = inner;
        })
        Library:ApplyCornerRadius(fill, UDim.new(0, 3))
        Library:AddToRegistry(fill, { BackgroundColor3 = "AccentColor"; BorderColor3 = "AccentColorDark" })
        local hideBorder = Library:Create("Frame", {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel  = 0;
            Position         = UDim2.new(1, 0, 0, 0);
            Size             = UDim2.new(0, 1, 1, 0);
            ZIndex           = 8;
            Parent           = fill;
        })
        Library:AddToRegistry(hideBorder, { BackgroundColor3 = "AccentColor" })
        local dispLbl = Library:CreateLabel({
            Size     = UDim2.new(1, 0, 1, 0);
            TextSize = 14;
            Text     = "";
            ZIndex   = 9;
            Parent   = inner;
        })
        Library:OnHighlight(outer, outer, { BorderColor3 = "AccentColor" }, { BorderColor3 = "Black" })
        if type(Info.Tooltip) == "string" then Library:AddToolTip(Info.Tooltip, outer) end

        local function Round(v)
            if SL.Rounding == 0 then return math.floor(v) end
            return tonumber(string.format("%." .. SL.Rounding .. "f", v))
        end

        local sliderMaxSize = 0
        local function getMaxSize()
            return inner.AbsoluteSize.X - 2
        end

        function SL:Display()
            local maxSz = getMaxSize()
            if maxSz <= 0 then maxSz = sliderMaxSize end
            local suf = Info.Suffix or ""
            if Info.Compact then
                dispLbl.Text = Info.Text .. ": " .. SL.Value .. suf
            elseif Info.HideMax then
                dispLbl.Text = SL.Value .. suf
            else
                dispLbl.Text = SL.Value .. suf .. "/" .. SL.Max .. suf
            end
            local x = math.ceil(Library:MapValue(SL.Value, SL.Min, SL.Max, 0, maxSz))
            fill.Size          = UDim2.new(0, x, 1, 0)
            hideBorder.Visible = (x ~= maxSz and x ~= 0)
        end
        function SL:OnChanged(f) SL.Changed = f; f(SL.Value) end
        function SL:SetValue(n)
            local num = tonumber(n)
            if not num then return end
            num = math.clamp(num, SL.Min, SL.Max)
            SL.Value = Round(num)
            SL:Display()
            Library:SafeCallback(SL.Callback, SL.Value)
            Library:SafeCallback(SL.Changed,  SL.Value)
        end

        inner:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            sliderMaxSize = getMaxSize()
            SL:Display()
        end)

        inner.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                local maxSz = getMaxSize()
                local mPos  = Mouse.X
                local gPos  = fill.Size.X.Offset
                local diff  = mPos - (fill.AbsolutePosition.X + gPos)
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nx   = math.clamp(gPos + (Mouse.X - mPos) + diff, 0, maxSz)
                    local nval = Round(Library:MapValue(nx, 0, maxSz, SL.Min, SL.Max))
                    local old  = SL.Value
                    SL.Value   = nval
                    SL:Display()
                    if nval ~= old then
                        Library:SafeCallback(SL.Callback, SL.Value)
                        Library:SafeCallback(SL.Changed,  SL.Value)
                    end
                    RenderStepped:Wait()
                end
                Library:AttemptSave()
            end
            if inp.UserInputType == Enum.UserInputType.MouseButton2 then
                local inputBox = Library:Create("TextBox", {
                    BackgroundTransparency = 1;
                    Size                   = UDim2.fromScale(1, 1);
                    FontFace               = Library.Font;
                    Text                   = tostring(SL.Value);
                    TextColor3             = Library.FontColor;
                    TextSize               = 14;
                    ZIndex                 = 20;
                    Parent                 = inner;
                })
                Library:ApplyTextStroke(inputBox)
                inputBox:CaptureFocus()
                inputBox.FocusLost:Connect(function(enter)
                    if enter then
                        local v = tonumber(inputBox.Text)
                        if v then SL:SetValue(v); Library:AttemptSave() end
                    end
                    if inputBox.Parent then
                        inputBox:Destroy()
                    end
                    SL:Display()
                end)
            end
        end)

        SL:Display()
        self:AddBlank(Info.BlankSize or 6)
        self:Resize()
        Options[Idx] = SL
        return SL
    end

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == "Player" then
            Info.Values = GetPlayersString(); Info.AllowNull = true
        elseif Info.SpecialType == "Team" then
            Info.Values = GetTeamsString(); Info.AllowNull = true
        end
        assert(Info.Values, "AddDropdown: Missing Values.")
        assert(Info.AllowNull or Info.Default, "AddDropdown: Missing default. Pass AllowNull=true if intentional.")
        if not Info.Text then Info.Compact = true end

        local DD = {
            Values      = Info.Values;
            Value       = Info.Multi and {} or nil;
            Multi       = Info.Multi;
            Type        = "Dropdown";
            SpecialType = Info.SpecialType;
            Callback    = Info.Callback or function() end;
        }
        local container = self.Container

        if not Info.Compact then
            Library:CreateLabel({
                Size           = UDim2.new(1, 0, 0, 10);
                TextSize       = 14;
                Text           = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex         = 5;
                Parent         = container;
            })
            self:AddBlank(3)
        end

        local dropOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3     = Color3.new(0, 0, 0);
            Size             = UDim2.new(1, -4, 0, 20);
            ZIndex           = 5;
            Parent           = container;
        })
        Library:ApplyCornerRadius(dropOuter)
        Library:AddToRegistry(dropOuter, { BorderColor3 = "Black" })
        local dropInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3     = Library.OutlineColor;
            BorderMode       = Enum.BorderMode.Inset;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 6;
            Parent           = dropOuter;
        })
        Library:ApplyCornerRadius(dropInner)
        Library:AddToRegistry(dropInner, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor" })
        Library:Create("UIGradient", {
            Color    = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)) });
            Rotation = 90;
            Parent   = dropInner;
        })
        local arrow = Library:Create("ImageLabel", {
            AnchorPoint            = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position               = UDim2.new(1, -16, 0.5, 0);
            Size                   = UDim2.new(0, 12, 0, 12);
            Image                  = "http://www.roblox.com/asset/?id=6282522798";
            ZIndex                 = 8;
            Parent                 = dropInner;
        })
        local itemList = Library:CreateLabel({
            Position       = UDim2.fromOffset(5, 0);
            Size           = UDim2.new(1, -5, 1, 0);
            TextSize       = 14;
            Text           = "--";
            TextXAlignment = Enum.TextXAlignment.Left;
            TextWrapped    = true;
            ZIndex         = 7;
            Parent         = dropInner;
        })
        Library:OnHighlight(dropOuter, dropOuter, { BorderColor3 = "AccentColor" }, { BorderColor3 = "Black" })
        if type(Info.Tooltip) == "string" then Library:AddToolTip(Info.Tooltip, dropOuter) end

        local MAX_ITEMS = 8
        local listOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3     = Color3.new(0, 0, 0);
            ZIndex           = 20;
            Visible          = false;
            Parent           = ScreenGui;
        })
        Library:ApplyCornerRadius(listOuter)

        local function reposListOuter()
            if not dropOuter.Parent then return end
            listOuter.Position = UDim2.fromOffset(dropOuter.AbsolutePosition.X, dropOuter.AbsolutePosition.Y + 21)
        end
        local function resizeListOuter(y)
            listOuter.Size = UDim2.fromOffset(dropOuter.AbsoluteSize.X, y or MAX_ITEMS * 20 + 2)
        end
        reposListOuter()
        resizeListOuter()
        dropOuter:GetPropertyChangedSignal("AbsolutePosition"):Connect(reposListOuter)

        local listInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3     = Library.OutlineColor;
            BorderMode       = Enum.BorderMode.Inset;
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 21;
            Parent           = listOuter;
        })
        Library:ApplyCornerRadius(listInner)
        Library:AddToRegistry(listInner, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor" })

        local searchBox = Library:Create("TextBox", {
            BackgroundColor3  = Library.BackgroundColor;
            BorderColor3      = Library.OutlineColor;
            BorderMode        = Enum.BorderMode.Inset;
            Size              = UDim2.new(1, 0, 0, 18);
            FontFace          = Library.Font;
            PlaceholderText   = "Search…";
            PlaceholderColor3 = Color3.fromRGB(100, 100, 100);
            Text              = "";
            TextColor3        = Library.FontColor;
            TextSize          = 13;
            TextXAlignment    = Enum.TextXAlignment.Left;
            ZIndex            = 23;
            Parent            = listInner;
        })
        Library:Create("UIPadding", { PaddingLeft = UDim.new(0, 4); Parent = searchBox })
        Library:AddToRegistry(searchBox, { BackgroundColor3 = "BackgroundColor"; BorderColor3 = "OutlineColor"; TextColor3 = "FontColor" })

        local scrolling = Library:Create("ScrollingFrame", {
            BackgroundTransparency = 1;
            BorderSizePixel        = 0;
            CanvasSize             = UDim2.new(0, 0, 0, 0);
            Position               = UDim2.fromOffset(0, 18);
            Size                   = UDim2.new(1, 0, 1, -18);
            ZIndex                 = 21;
            TopImage               = "rbxasset://textures/ui/Scroll/scroll-middle.png";
            BottomImage            = "rbxasset://textures/ui/Scroll/scroll-middle.png";
            ScrollBarThickness     = 3;
            ScrollBarImageColor3   = Library.AccentColor;
            Parent                 = listInner;
        })
        Library:AddToRegistry(scrolling, { ScrollBarImageColor3 = "AccentColor" })
        Library:Create("UIListLayout", {
            Padding       = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder     = Enum.SortOrder.LayoutOrder;
            Parent        = scrolling;
        })

        function DD:Display()
            local str = ""
            if Info.Multi then
                for _, v in next, DD.Values do
                    if DD.Value[v] then str = str .. v .. ", " end
                end
                str = str:sub(1, -3)
            else
                str = DD.Value or ""
            end
            itemList.Text = str == "" and "--" or str
        end

        function DD:GetActiveValues()
            if Info.Multi then
                local n = 0; for _ in next, DD.Value do n += 1 end; return n
            else
                return DD.Value and 1 or 0
            end
        end

        function DD:BuildDropdownList(filter)
            filter = (filter or ""):lower()
            for _, e in next, scrolling:GetChildren() do
                if not e:IsA("UIListLayout") then e:Destroy() end
            end
            local buttons = {}
            local count   = 0
            for _, value in next, DD.Values do
                if filter ~= "" and not value:lower():find(filter, 1, true) then continue end
                count += 1
                local tbl = {}
                local btn = Library:Create("Frame", {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3     = Library.OutlineColor;
                    BorderMode       = Enum.BorderMode.Middle;
                    Size             = UDim2.new(1, -1, 0, 20);
                    ZIndex           = 23;
                    Active           = true;
                    Parent           = scrolling;
                })
                Library:AddToRegistry(btn, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor" })
                local btnLbl = Library:CreateLabel({
                    Active         = false;
                    Size           = UDim2.new(1, -6, 1, 0);
                    Position       = UDim2.fromOffset(6, 0);
                    TextSize       = 14;
                    Text           = value;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex         = 25;
                    Parent         = btn;
                })
                Library:OnHighlight(btn, btn,
                    { BorderColor3 = "AccentColor"; ZIndex = 24 },
                    { BorderColor3 = "OutlineColor"; ZIndex = 23 }
                )
                local sel = Info.Multi and DD.Value[value] or DD.Value == value
                function tbl:Update()
                    sel = Info.Multi and DD.Value[value] or DD.Value == value
                    btnLbl.TextColor3 = sel and Library.AccentColor or Library.FontColor
                    local reg = Library.RegistryMap[btnLbl]
                    if reg then reg.Properties.TextColor3 = sel and "AccentColor" or "FontColor" end
                end
                btnLbl.InputBegan:Connect(function(inp)
                    if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    local try = not sel
                    if DD:GetActiveValues() == 1 and not try and not Info.AllowNull then return end
                    if Info.Multi then
                        sel = try
                        DD.Value[value] = try or nil
                    else
                        sel = try
                        DD.Value = try and value or nil
                        for _, b in next, buttons do b:Update() end
                    end
                    tbl:Update(); DD:Display()
                    Library:SafeCallback(DD.Callback, DD.Value)
                    Library:SafeCallback(DD.Changed,  DD.Value)
                    Library:AttemptSave()
                end)
                tbl:Update(); DD:Display()
                buttons[btn] = tbl
            end
            scrolling.CanvasSize = UDim2.fromOffset(0, count * 20 + 1)
            local y = math.clamp(count * 20, 0, MAX_ITEMS * 20) + 1
            resizeListOuter(y + 18)
        end

        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            DD:BuildDropdownList(searchBox.Text)
        end)

        function DD:SetValues(newValues)
            if newValues then
                DD.Values = newValues
                if Info.Multi then
                    local cleaned = {}
                    for k in next, DD.Value do
                        if table.find(DD.Values, k) then cleaned[k] = true end
                    end
                    DD.Value = cleaned
                elseif DD.Value and not table.find(DD.Values, DD.Value) then
                    DD.Value = nil
                end
            end
            DD:BuildDropdownList()
            DD:Display()
        end
        function DD:OpenDropdown()
            reposListOuter()
            listOuter.Visible = true
            Library.OpenedFrames[listOuter] = true
            arrow.Rotation = 180
            searchBox.Text = ""
            task.defer(function() pcall(function() searchBox:CaptureFocus() end) end)
        end
        function DD:CloseDropdown()
            listOuter.Visible = false
            Library.OpenedFrames[listOuter] = nil
            arrow.Rotation = 0
        end
        function DD:OnChanged(f) DD.Changed = f; f(DD.Value) end
        function DD:SetValue(val)
            if DD.Multi then
                local nt = {}
                for v in next, val do
                    if table.find(DD.Values, v) then nt[v] = true end
                end
                DD.Value = nt
            else
                DD.Value = (val and table.find(DD.Values, val)) and val or nil
            end
            DD:BuildDropdownList()
            DD:Display()
            Library:SafeCallback(DD.Callback, DD.Value)
            Library:SafeCallback(DD.Changed,  DD.Value)
        end

        dropOuter.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if listOuter.Visible then DD:CloseDropdown() else DD:OpenDropdown() end
            end
        end)
        Library:GiveSignal(InputService.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                local p, s = listOuter.AbsolutePosition, listOuter.AbsoluteSize
                if Mouse.X < p.X or Mouse.X > p.X + s.X or Mouse.Y < (p.Y - 21) or Mouse.Y > p.Y + s.Y then
                    DD:CloseDropdown()
                end
            end
        end))

        DD:BuildDropdownList()
        DD:Display()

        if type(Info.Default) == "string" then
            if table.find(DD.Values, Info.Default) then
                if Info.Multi then DD.Value[Info.Default] = true
                else DD.Value = Info.Default end
            end
        elseif type(Info.Default) == "table" then
            for _, v in next, Info.Default do
                if table.find(DD.Values, v) then
                    if Info.Multi then DD.Value[v] = true
                    else DD.Value = v end
                end
            end
        elseif type(Info.Default) == "number" and DD.Values[Info.Default] then
            if Info.Multi then DD.Value[DD.Values[Info.Default]] = true
            else DD.Value = DD.Values[Info.Default] end
        end
        DD:BuildDropdownList()
        DD:Display()

        self:AddBlank(Info.BlankSize or 5)
        self:Resize()
        Options[Idx] = DD
        return DD
    end

    function Funcs:AddDependencyBox()
        local Depbox = { Dependencies = {} }
        local container = self.Container
        local holder = Library:Create("Frame", {
            BackgroundTransparency = 1;
            Size    = UDim2.new(1, 0, 0, 0);
            Visible = false;
            Parent  = container;
        })
        local frame = Library:Create("Frame", {
            BackgroundTransparency = 1;
            Size   = UDim2.new(1, 0, 1, 0);
            Parent = holder;
        })
        local layout = Library:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder     = Enum.SortOrder.LayoutOrder;
            Parent        = frame;
        })
        local gb = self
        function Depbox:Resize()
            holder.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y)
            gb:Resize()
        end
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() Depbox:Resize() end)
        holder:GetPropertyChangedSignal("Visible"):Connect(function() Depbox:Resize() end)
        function Depbox:Update()
            for _, dep in next, Depbox.Dependencies do
                local elem, val = dep[1], dep[2]
                if elem.Type == "Toggle" and elem.Value ~= val then
                    holder.Visible = false; Depbox:Resize(); return
                end
            end
            holder.Visible = true; Depbox:Resize()
        end
        function Depbox:SetupDependencies(deps)
            for _, d in next, deps do
                assert(type(d) == "table",  "SetupDependencies: not a table")
                assert(d[1],                "SetupDependencies: missing element")
                assert(d[2] ~= nil,         "SetupDependencies: missing value")
            end
            Depbox.Dependencies = deps; Depbox:Update()
        end
        Depbox.Container = frame
        setmetatable(Depbox, BaseGroupbox)
        table.insert(Library.DependencyBoxes, Depbox)
        return Depbox
    end

    BaseGroupbox.__index = Funcs
    BaseGroupbox.__namecall = function(_, k, ...) return Funcs[k](...) end
end

do
    Library.NotificationArea = Library:Create("Frame", {
        BackgroundTransparency = 1;
        Position = UDim2.fromOffset(0, 40);
        Size     = UDim2.fromOffset(300, 200);
        ZIndex   = 100;
        Parent   = ScreenGui;
    })
    Library:Create("UIListLayout", {
        Padding       = UDim.new(0, 4);
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder     = Enum.SortOrder.LayoutOrder;
        Parent        = Library.NotificationArea;
    })

    local wmOuter = Library:Create("Frame", {
        BorderColor3 = Color3.new(0, 0, 0);
        Position     = UDim2.fromOffset(100, 10);
        Size         = UDim2.fromOffset(213, 20);
        ZIndex       = 200;
        Visible      = false;
        Parent       = ScreenGui;
    })
    Library:ApplyCornerRadius(wmOuter)
    local wmInner = Library:Create("Frame", {
        BackgroundColor3 = Library.MainColor;
        BorderColor3     = Library.AccentColor;
        BorderMode       = Enum.BorderMode.Inset;
        Size             = UDim2.new(1, 0, 1, 0);
        ZIndex           = 201;
        Parent           = wmOuter;
    })
    Library:ApplyCornerRadius(wmInner)
    Library:AddToRegistry(wmInner, { BackgroundColor3 = "MainColor"; BorderColor3 = "AccentColor" })
    local wmFrame = Library:Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel  = 0;
        Position         = UDim2.fromOffset(1, 1);
        Size             = UDim2.new(1, -2, 1, -2);
        ZIndex           = 202;
        Parent           = wmInner;
    })
    Library:ApplyCornerRadius(wmFrame)
    local wmGrad = Library:Create("UIGradient", {
        Color    = ColorSequence.new({ ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)), ColorSequenceKeypoint.new(1, Library.MainColor) });
        Rotation = -90;
        Parent   = wmFrame;
    })
    Library:AddToRegistry(wmGrad, { Color = function()
        return ColorSequence.new({ ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)), ColorSequenceKeypoint.new(1, Library.MainColor) })
    end })
    local wmLabel = Library:CreateLabel({
        Position       = UDim2.fromOffset(5, 0);
        Size           = UDim2.new(1, -4, 1, 0);
        TextSize       = 14;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex         = 203;
        Parent         = wmFrame;
    })
    Library.Watermark     = wmOuter
    Library.WatermarkText = wmLabel
    Library:MakeDraggable(wmOuter)

    local kbOuter = Library:Create("Frame", {
        AnchorPoint  = Vector2.new(0, 0.5);
        BorderColor3 = Color3.new(0, 0, 0);
        Position     = UDim2.new(0, 10, 0.5, 0);
        Size         = UDim2.fromOffset(210, 20);
        Visible      = false;
        ZIndex       = 100;
        Parent       = ScreenGui;
    })
    Library:ApplyCornerRadius(kbOuter)
    local kbInner = Library:Create("Frame", {
        BackgroundColor3 = Library.MainColor;
        BorderColor3     = Library.OutlineColor;
        BorderMode       = Enum.BorderMode.Inset;
        Size             = UDim2.new(1, 0, 1, 0);
        ZIndex           = 101;
        Parent           = kbOuter;
    })
    Library:ApplyCornerRadius(kbInner)
    Library:AddToRegistry(kbInner, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor" }, true)
    local kbColor = Library:Create("Frame", {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel  = 0;
        Size             = UDim2.new(1, 0, 0, 2);
        ZIndex           = 102;
        Parent           = kbInner;
    })
    Library:AddToRegistry(kbColor, { BackgroundColor3 = "AccentColor" }, true)
    Library:CreateLabel({
        Size           = UDim2.new(1, 0, 0, 20);
        Position       = UDim2.fromOffset(5, 2);
        TextXAlignment = Enum.TextXAlignment.Left;
        Text           = "Keybinds";
        ZIndex         = 104;
        Parent         = kbInner;
    })
    local kbContainer = Library:Create("Frame", {
        BackgroundTransparency = 1;
        Size     = UDim2.new(1, 0, 1, -20);
        Position = UDim2.new(0, 0, 0, 20);
        ZIndex   = 1;
        Parent   = kbInner;
    })
    Library:Create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = kbContainer })
    Library:Create("UIPadding", { PaddingLeft = UDim.new(0, 5); Parent = kbContainer })
    Library.KeybindFrame     = kbOuter
    Library.KeybindContainer = kbContainer
    Library:MakeDraggable(kbOuter)
end

function Library:SetWatermarkVisibility(b) self.Watermark.Visible = b end
function Library:SetWatermark(text)
    local X, Y = GetTextBounds(text, self.Font, 14)
    self.Watermark.Size     = UDim2.fromOffset(X + 15, math.floor(Y * 1.5) + 3)
    self.WatermarkText.Text = text
    self:SetWatermarkVisibility(true)
end

function Library:CreateWindow(cfg)
    if type(cfg) ~= "table" then
        cfg = { Title = tostring(cfg), AutoShow = false }
    end
    cfg.Title        = type(cfg.Title) == "string" and cfg.Title or "Window"
    cfg.TabPadding   = type(cfg.TabPadding) == "number" and cfg.TabPadding or 0
    cfg.MenuFadeTime = type(cfg.MenuFadeTime) == "number" and cfg.MenuFadeTime or 0.2
    cfg.AnchorPoint  = typeof(cfg.AnchorPoint) == "Vector2" and cfg.AnchorPoint or Vector2.zero
    cfg.Position     = typeof(cfg.Position) == "UDim2" and cfg.Position or UDim2.fromOffset(175, 50)
    cfg.Size         = typeof(cfg.Size) == "UDim2" and cfg.Size or UDim2.fromOffset(550, 600)
    if cfg.Center then
        cfg.AnchorPoint = Vector2.new(0.5, 0.5)
        cfg.Position    = UDim2.fromScale(0.5, 0.5)
    end

    local Window = { Tabs = {} }

    local outer = Library:Create("Frame", {
        AnchorPoint      = cfg.AnchorPoint;
        BackgroundColor3 = Color3.new(0, 0, 0);
        BorderSizePixel  = 0;
        Position         = cfg.Position;
        Size             = cfg.Size;
        Visible          = false;
        ZIndex           = 1;
        Parent           = ScreenGui;
    })
    Library:ApplyCornerRadius(outer)
    Library:MakeDraggable(outer, 25)

    local gradStroke = Library:Create("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
        Thickness       = 1.5;
        Parent          = outer;
    })
    Library:Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library.WindowOutlineGradientBottom);
            ColorSequenceKeypoint.new(1, Library.WindowOutlineGradientTop);
        });
        Rotation = 90;
        Parent   = gradStroke;
    })
    Library:AddToRegistry(gradStroke, { Color = function()
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library.WindowOutlineGradientBottom);
            ColorSequenceKeypoint.new(1, Library.WindowOutlineGradientTop);
        })
    end })

    local mainInner = Library:Create("Frame", {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel  = 0;
        Position         = UDim2.fromOffset(1, 1);
        Size             = UDim2.new(1, -2, 1, -2);
        ZIndex           = 1;
        Parent           = outer;
    })
    Library:ApplyCornerRadius(mainInner)
    Library:AddToRegistry(mainInner, { BackgroundColor3 = "MainColor" })

    local titleLbl = Library:CreateLabel({
        Position       = UDim2.fromOffset(7, 0);
        Size           = UDim2.new(0, 0, 0, 25);
        Text           = cfg.Title;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex         = 1;
        Parent         = mainInner;
    })

    local sectionOuter = Library:Create("Frame", {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3     = Library.OutlineColor;
        Position         = UDim2.fromOffset(8, 25);
        Size             = UDim2.new(1, -16, 1, -33);
        ZIndex           = 1;
        Parent           = mainInner;
    })
    Library:ApplyCornerRadius(sectionOuter, UDim.new(0, 4))
    Library:AddToRegistry(sectionOuter, { BackgroundColor3 = "BackgroundColor"; BorderColor3 = "OutlineColor" })
    local sectionInner = Library:Create("Frame", {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3     = Color3.new(0, 0, 0);
        BorderMode       = Enum.BorderMode.Inset;
        Size             = UDim2.new(1, 0, 1, 0);
        ZIndex           = 1;
        Parent           = sectionOuter;
    })
    Library:ApplyCornerRadius(sectionInner, UDim.new(0, 4))
    Library:AddToRegistry(sectionInner, { BackgroundColor3 = "BackgroundColor" })

    local tabArea = Library:Create("Frame", {
        BackgroundTransparency = 1;
        Position = UDim2.fromOffset(8, 8);
        Size     = UDim2.new(1, -16, 0, 21);
        ZIndex   = 1;
        Parent   = sectionInner;
    })
    Library:Create("UIListLayout", {
        Padding       = UDim.new(0, cfg.TabPadding);
        FillDirection = Enum.FillDirection.Horizontal;
        SortOrder     = Enum.SortOrder.LayoutOrder;
        Parent        = tabArea;
    })
    local tabContainer = Library:Create("Frame", {
        BackgroundColor3 = Library.MainColor;
        BorderColor3     = Library.OutlineColor;
        Position         = UDim2.fromOffset(8, 30);
        Size             = UDim2.new(1, -16, 1, -38);
        ZIndex           = 2;
        Parent           = sectionInner;
    })
    Library:ApplyCornerRadius(tabContainer, UDim.new(0, 4))
    Library:AddToRegistry(tabContainer, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor" })

    function Window:SetWindowTitle(t) titleLbl.Text = t end

    function Window:AddTab(name)
        local Tab = { Groupboxes = {}; Tabboxes = {} }

        local tabW  = select(1, GetTextBounds(name, Library.Font, 16))
        local tabBtn = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3     = Library.OutlineColor;
            Size             = UDim2.new(0, tabW + 12, 1, 0);
            ZIndex           = 1;
            Parent           = tabArea;
        })
        Library:ApplyCornerRadius(tabBtn, UDim.new(0, 3))
        Library:AddToRegistry(tabBtn, { BackgroundColor3 = "BackgroundColor"; BorderColor3 = "OutlineColor" })
        Library:CreateLabel({ Position = UDim2.fromOffset(0, 0); Size = UDim2.new(1, 0, 1, -1); Text = name; ZIndex = 1; Parent = tabBtn })
        local blocker = Library:Create("Frame", {
            BackgroundColor3       = Library.MainColor;
            BorderSizePixel        = 0;
            Position               = UDim2.new(0, 0, 1, 0);
            Size                   = UDim2.new(1, 0, 0, 1);
            BackgroundTransparency = 1;
            ZIndex                 = 3;
            Parent                 = tabBtn;
        })
        Library:AddToRegistry(blocker, { BackgroundColor3 = "MainColor" })

        local tabFrame = Library:Create("Frame", {
            Name                   = "TabFrame";
            BackgroundTransparency = 1;
            Size                   = UDim2.new(1, 0, 1, 0);
            Visible                = false;
            ZIndex                 = 2;
            Parent                 = tabContainer;
        })

        local function MakeSide(isLeft)
            local side = Library:Create("ScrollingFrame", {
                BackgroundTransparency = 1;
                BorderSizePixel        = 0;
                Position               = isLeft and UDim2.new(0, 7, 0, 7) or UDim2.new(0.5, 5, 0, 7);
                Size                   = UDim2.new(0.5, -12, 1, -14);
                CanvasSize             = UDim2.new(0, 0, 0, 0);
                BottomImage            = "";
                TopImage               = "";
                ScrollBarThickness     = 0;
                ZIndex                 = 2;
                Parent                 = tabFrame;
            })
            Library:Create("UIListLayout", {
                Padding             = UDim.new(0, 8);
                FillDirection       = Enum.FillDirection.Vertical;
                SortOrder           = Enum.SortOrder.LayoutOrder;
                HorizontalAlignment = Enum.HorizontalAlignment.Center;
                Parent              = side;
            })
            local sideLayout = side:WaitForChild("UIListLayout")
            sideLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                side.CanvasSize = UDim2.fromOffset(0, sideLayout.AbsoluteContentSize.Y)
            end)
            return side
        end
        local leftSide  = MakeSide(true)
        local rightSide = MakeSide(false)

        function Tab:ShowTab()
            for _, t in next, Window.Tabs do t:HideTab() end
            blocker.BackgroundTransparency = 0
            tabBtn.BackgroundColor3 = Library.MainColor
            local reg = Library.RegistryMap[tabBtn]
            if reg then reg.Properties.BackgroundColor3 = "MainColor" end
            tabFrame.Visible = true
        end
        function Tab:HideTab()
            blocker.BackgroundTransparency = 1
            tabBtn.BackgroundColor3 = Library.BackgroundColor
            local reg = Library.RegistryMap[tabBtn]
            if reg then reg.Properties.BackgroundColor3 = "BackgroundColor" end
            tabFrame.Visible = false
        end

        function Tab:AddGroupbox(info)
            local GB   = {}
            local side = info.Side == 1 and leftSide or rightSide
            local boxOuter = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3     = Library.OutlineColor;
                BorderMode       = Enum.BorderMode.Inset;
                Size             = UDim2.new(1, 0, 0, 0);
                ZIndex           = 2;
                Parent           = side;
            })
            Library:ApplyCornerRadius(boxOuter, UDim.new(0, 4))
            Library:AddToRegistry(boxOuter, { BackgroundColor3 = "BackgroundColor"; BorderColor3 = "OutlineColor" })
            local boxInner = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3     = Color3.new(0, 0, 0);
                Size             = UDim2.new(1, -2, 1, -2);
                Position         = UDim2.fromOffset(1, 1);
                ZIndex           = 4;
                Parent           = boxOuter;
            })
            Library:ApplyCornerRadius(boxInner, UDim.new(0, 4))
            Library:AddToRegistry(boxInner, { BackgroundColor3 = "BackgroundColor" })
            local hl = Library:Create("Frame", {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel  = 0;
                Size             = UDim2.new(1, 0, 0, 2);
                ZIndex           = 5;
                Parent           = boxInner;
            })
            Library:AddToRegistry(hl, { BackgroundColor3 = "AccentColor" })
            Library:CreateLabel({
                Size           = UDim2.new(1, 0, 0, 18);
                Position       = UDim2.fromOffset(4, 2);
                TextSize       = 14;
                Text           = info.Name;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex         = 5;
                Parent         = boxInner;
            })
            local cont = Library:Create("Frame", {
                BackgroundTransparency = 1;
                Position = UDim2.fromOffset(4, 20);
                Size     = UDim2.new(1, -4, 1, -20);
                ZIndex   = 1;
                Parent   = boxInner;
            })
            Library:Create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = cont })
            function GB:Resize()
                local sz = 0
                for _, e in next, GB.Container:GetChildren() do
                    if not e:IsA("UIListLayout") and e.Visible then sz += e.Size.Y.Offset end
                end
                boxOuter.Size = UDim2.new(1, 0, 0, 20 + sz + 4)
            end
            GB.Container = cont
            setmetatable(GB, BaseGroupbox)
            GB:AddBlank(3); GB:Resize()
            Tab.Groupboxes[info.Name] = GB
            return GB
        end
        function Tab:AddLeftGroupbox(n)  return Tab:AddGroupbox({ Side = 1; Name = n }) end
        function Tab:AddRightGroupbox(n) return Tab:AddGroupbox({ Side = 2; Name = n }) end

        function Tab:AddTabbox(info)
            local Tabbox = { Tabs = {} }
            local side   = info.Side == 1 and leftSide or rightSide
            local boxOuter = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3     = Library.OutlineColor;
                BorderMode       = Enum.BorderMode.Inset;
                Size             = UDim2.new(1, 0, 0, 0);
                ZIndex           = 2;
                Parent           = side;
            })
            Library:ApplyCornerRadius(boxOuter, UDim.new(0, 4))
            Library:AddToRegistry(boxOuter, { BackgroundColor3 = "BackgroundColor"; BorderColor3 = "OutlineColor" })
            local boxInner = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3     = Color3.new(0, 0, 0);
                Size             = UDim2.new(1, -2, 1, -2);
                Position         = UDim2.fromOffset(1, 1);
                ZIndex           = 4;
                Parent           = boxOuter;
            })
            Library:ApplyCornerRadius(boxInner, UDim.new(0, 4))
            Library:AddToRegistry(boxInner, { BackgroundColor3 = "BackgroundColor" })
            local hl = Library:Create("Frame", {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel  = 0;
                Size             = UDim2.new(1, 0, 0, 2);
                ZIndex           = 10;
                Parent           = boxInner;
            })
            Library:AddToRegistry(hl, { BackgroundColor3 = "AccentColor" })
            local tbBtns = Library:Create("Frame", {
                BackgroundTransparency = 1;
                Position = UDim2.fromOffset(0, 1);
                Size     = UDim2.new(1, 0, 0, 18);
                ZIndex   = 5;
                Parent   = boxInner;
            })
            Library:Create("UIListLayout", {
                FillDirection       = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder           = Enum.SortOrder.LayoutOrder;
                Parent              = tbBtns;
            })

            function Tabbox:AddTab(tname)
                local TT  = {}
                local btn = Library:Create("Frame", {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3     = Color3.new(0, 0, 0);
                    Size             = UDim2.new(0.5, 0, 1, 0);
                    ZIndex           = 6;
                    Parent           = tbBtns;
                })
                Library:ApplyCornerRadius(btn, UDim.new(0, 3))
                Library:AddToRegistry(btn, { BackgroundColor3 = "MainColor" })
                Library:CreateLabel({ Size = UDim2.new(1, 0, 1, 0); TextSize = 14; Text = tname; ZIndex = 7; Parent = btn })
                local block = Library:Create("Frame", {
                    BackgroundColor3 = Library.BackgroundColor;
                    BorderSizePixel  = 0;
                    Position         = UDim2.new(0, 0, 1, 0);
                    Size             = UDim2.new(1, 0, 0, 1);
                    Visible          = false;
                    ZIndex           = 9;
                    Parent           = btn;
                })
                Library:AddToRegistry(block, { BackgroundColor3 = "BackgroundColor" })
                local cont = Library:Create("Frame", {
                    BackgroundTransparency = 1;
                    Position = UDim2.fromOffset(4, 20);
                    Size     = UDim2.new(1, -4, 1, -20);
                    ZIndex   = 1;
                    Visible  = false;
                    Parent   = boxInner;
                })
                Library:Create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = cont })

                function TT:Show()
                    for _, t in next, Tabbox.Tabs do t:Hide() end
                    cont.Visible = true; block.Visible = true
                    btn.BackgroundColor3 = Library.BackgroundColor
                    local reg = Library.RegistryMap[btn]
                    if reg then reg.Properties.BackgroundColor3 = "BackgroundColor" end
                    TT:Resize()
                end
                function TT:Hide()
                    cont.Visible = false; block.Visible = false
                    btn.BackgroundColor3 = Library.MainColor
                    local reg = Library.RegistryMap[btn]
                    if reg then reg.Properties.BackgroundColor3 = "MainColor" end
                end
                function TT:Resize()
                    local tc = 0
                    for _ in next, Tabbox.Tabs do tc += 1 end
                    for _, b in next, tbBtns:GetChildren() do
                        if not b:IsA("UIListLayout") then b.Size = UDim2.new(1 / tc, 0, 1, 0) end
                    end
                    if not cont.Visible then return end
                    local sz = 0
                    for _, e in next, TT.Container:GetChildren() do
                        if not e:IsA("UIListLayout") and e.Visible then sz += e.Size.Y.Offset end
                    end
                    boxOuter.Size = UDim2.new(1, 0, 0, 20 + sz + 4)
                end
                btn.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                        TT:Show()
                    end
                end)
                TT.Container = cont
                Tabbox.Tabs[tname] = TT
                setmetatable(TT, BaseGroupbox)
                TT:AddBlank(3); TT:Resize()
                if #tbBtns:GetChildren() == 2 then TT:Show() end
                return TT
            end
            Tab.Tabboxes[info.Name or ""] = Tabbox
            return Tabbox
        end
        function Tab:AddLeftTabbox(n)  return Tab:AddTabbox({ Name = n; Side = 1 }) end
        function Tab:AddRightTabbox(n) return Tab:AddTabbox({ Name = n; Side = 2 }) end

        tabBtn.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then Tab:ShowTab() end
        end)
        if #tabContainer:GetChildren() == 1 then Tab:ShowTab() end
        Window.Tabs[name] = Tab
        return Tab
    end

    local transCache = {}
    local toggled    = false
    local fading     = false

    function Library:Toggle()
        if fading then return end
        local ft = cfg.MenuFadeTime
        fading   = true
        toggled  = not toggled

        if toggled then
            outer.Visible = true
            task.spawn(function()
                local prevState = InputService.MouseIconEnabled
                local cur  = Library:GiveDrawing(Drawing.new("Triangle"))
                local curO = Library:GiveDrawing(Drawing.new("Triangle"))
                cur.Thickness  = 1; cur.Filled  = true;  cur.Visible = true
                curO.Thickness = 1; curO.Filled = false; curO.Color  = Color3.new(0, 0, 0); curO.Visible = true
                while toggled and ScreenGui.Parent do
                    InputService.MouseIconEnabled = false
                    local mp = InputService:GetMouseLocation()
                    cur.Color  = Library.AccentColor
                    cur.PointA = mp;                     curO.PointA = mp
                    cur.PointB = mp + Vector2.new(16, 6); curO.PointB = cur.PointB
                    cur.PointC = mp + Vector2.new(6, 16); curO.PointC = cur.PointC
                    RenderStepped:Wait()
                end
                InputService.MouseIconEnabled = prevState
                cur:Remove(); curO:Remove()
                for i = #Library.Drawings, 1, -1 do
                    if Library.Drawings[i] == cur or Library.Drawings[i] == curO then
                        table.remove(Library.Drawings, i)
                    end
                end
            end)
        end

        for _, desc in next, outer:GetDescendants() do
            local props = {}
            if desc:IsA("ImageLabel") then
                props = { "ImageTransparency", "BackgroundTransparency" }
            elseif desc:IsA("TextLabel") or desc:IsA("TextBox") then
                props = { "TextTransparency" }
            elseif desc:IsA("Frame") or desc:IsA("ScrollingFrame") then
                props = { "BackgroundTransparency" }
            elseif desc:IsA("UIStroke") then
                props = { "Transparency" }
            end
            local cache = transCache[desc]
            if not cache then cache = {}; transCache[desc] = cache end
            for _, prop in next, props do
                if not cache[prop] then cache[prop] = desc[prop] end
                if cache[prop] == 1 then continue end
                pcall(function()
                    TweenService:Create(desc, TweenInfo.new(ft, Enum.EasingStyle.Linear), { [prop] = toggled and cache[prop] or 1 }):Play()
                end)
            end
        end
        task.wait(ft)
        outer.Visible = toggled
        fading = false
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(inp, processed)
        if type(Library.ToggleKeybind) == "table" and Library.ToggleKeybind.Type == "KeyPicker" then
            if inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(function() Library:Toggle() end)
            end
        elseif inp.KeyCode == Enum.KeyCode.RightControl
            or (inp.KeyCode == Enum.KeyCode.RightShift and not processed) then
            task.spawn(function() Library:Toggle() end)
        end
    end))

    if cfg.AutoShow then task.spawn(function() Library:Toggle() end) end
    Window.Holder = outer
    return Window
end

function Library:Unload()
    for i = #self.Signals, 1, -1 do
        local c = table.remove(self.Signals, i)
        pcall(function() c:Disconnect() end)
    end
    for _, d in ipairs(self.Drawings) do
        pcall(function() d:Remove() end)
    end
    if self.OnUnload then pcall(self.OnUnload) end
    pcall(function() ScreenGui:Destroy() end)
end

function Library:SetOnUnload(cb) self.OnUnload = cb end

local function onPlayerChange()
    local list = GetPlayersString()
    for _, v in next, Options do
        if v.Type == "Dropdown" and v.SpecialType == "Player" then
            pcall(function() v:SetValues(list) end)
        end
    end
end
Library:GiveSignal(Players.PlayerAdded:Connect(onPlayerChange))
Library:GiveSignal(Players.PlayerRemoving:Connect(onPlayerChange))

if getgenv then getgenv().Library = Library end
return Library
