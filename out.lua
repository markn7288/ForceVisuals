--============================================================
-- Force v85 Performance Fix\n-- H / RightShift = menu  •  F4 = freecam
--============================================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Players              = game:GetService("Players")
local SoundService         = game:GetService("SoundService")
local UserInputService     = game:GetService("UserInputService")
local RunService           = game:GetService("RunService")
local TweenService         = game:GetService("TweenService")
local Lighting             = game:GetService("Lighting")
local Stats                = game:GetService("Stats")
local RS                   = game:GetService("ReplicatedStorage")
local CAS                  = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--============================================================
-- RUNTIME MANAGER
--============================================================

local ENV = (getgenv and getgenv()) or _G

if ENV.__DOORS_ESP_RUNTIME and ENV.__DOORS_ESP_RUNTIME.stop then
    pcall(function()
        if ENV.__DOORS_v84_BYPASS_CLEANUP then
            ENV.__DOORS_v84_BYPASS_CLEANUP()
        end
    end)
    pcall(function() ENV.__DOORS_ESP_RUNTIME:stop() end)
end

local Runtime = { alive = true, connections = {} }

function Runtime:connect(signal, callback)
    local ok, c = pcall(function()
        return signal:Connect(function(...)
            if not self.alive then return end
            callback(...)
        end)
    end)
    if ok and c then self.connections[#self.connections + 1] = c end
    return c
end

function Runtime:spawn(callback)
    return task.spawn(function() if self.alive then callback() end end)
end

function Runtime:stop()
    self.alive = false
    pcall(function()
        if ENV.__Force_v85_CLEAR_HIDING_MARKERS then ENV.__Force_v85_CLEAR_HIDING_MARKERS() end
    end)
    pcall(function()
        if ENV.__Force_v85_BYPASS_CLEANUP then
            ENV.__Force_v85_BYPASS_CLEANUP()
        end
    end)
    pcall(function() CAS:UnbindAction("Force_v85_CursorLock") end)
    for i = #self.connections, 1, -1 do
        local c = self.connections[i]
        pcall(function() if c then c:Disconnect() end end)
        self.connections[i] = nil
    end
end

ENV.__DOORS_ESP_RUNTIME = Runtime

--============================================================
-- SETTINGS
--============================================================

local ITEM_COLOR, MONSTER_COLOR, DOOR_COLOR, DOOR_DUPE_COLOR
local BOOK_COLOR, LEVER_COLOR, FUSE_COLOR, CHEST_COLOR
local LOCKED_CHEST_COLOR, HIDING_COLOR, FILLED_HIDING_COLOR
local ELECTRICAL_COLOR, PLAYER_COLOR, PLAYER_TRACER_COLOR
local NAMETAG_COLOR, ENTITY_TAG_COLOR
local KEY_COLOR, GATE_LEVER_COLOR, RUSH_LIKE_COLOR, EYES_ESP_COLOR
local SCAN_ENTITIES_DELAY, SCAN_FALLBACK_DELAY, SCAN_LOCKER_DELAY
local SCAN_OVERLAY_DELAY, ROOM_CACHE_TTL
local DRONE_CLEAN_INTERVAL
local DEFAULT_ESP_DISTANCE, MAX_ESP_DISTANCE, CONFIG

do
    -- Единая более контрастная палитра ESP.
    ITEM_COLOR           = Color3.fromRGB(85, 200, 255)
    MONSTER_COLOR        = Color3.fromRGB(255, 75, 75)
    DOOR_COLOR           = Color3.fromRGB(85, 255, 125)
    DOOR_DUPE_COLOR      = Color3.fromRGB(255, 65, 65)
    BOOK_COLOR           = Color3.fromRGB(255, 170, 85)
    LEVER_COLOR          = Color3.fromRGB(255, 145, 45)
    FUSE_COLOR           = Color3.fromRGB(255, 235, 75)
    CHEST_COLOR          = Color3.fromRGB(255, 195, 65)
    LOCKED_CHEST_COLOR   = Color3.fromRGB(255, 90, 90)
    HIDING_COLOR         = Color3.fromRGB(80, 255, 215)
    FILLED_HIDING_COLOR  = Color3.fromRGB(255, 115, 230)
    ELECTRICAL_COLOR     = Color3.fromRGB(100, 190, 255)
    PLAYER_COLOR         = Color3.fromRGB(120, 185, 255)
    PLAYER_TRACER_COLOR  = Color3.fromRGB(120, 185, 255)
    NAMETAG_COLOR        = Color3.fromRGB(245, 248, 255)
    ENTITY_TAG_COLOR     = Color3.fromRGB(255, 225, 225)
    KEY_COLOR            = Color3.fromRGB(255, 230, 75)
    GATE_LEVER_COLOR     = Color3.fromRGB(120, 160, 255)
    RUSH_LIKE_COLOR      = Color3.fromRGB(255, 110, 65)
    EYES_ESP_COLOR       = Color3.fromRGB(200, 120, 255)
    SCAN_ENTITIES_DELAY  = 1.0
    SCAN_FALLBACK_DELAY  = 6.0
    SCAN_LOCKER_DELAY    = 0.5
    SCAN_OVERLAY_DELAY   = 1.0
    ROOM_CACHE_TTL       = 1.5
    DRONE_CLEAN_INTERVAL = 2.0
    DEFAULT_ESP_DISTANCE = 150
    MAX_ESP_DISTANCE = 500
    CONFIG = { DISPLAY_ORDER = 110 }
end

--============================================================
-- DOORS REMOTES
--============================================================

local RemotesFolder = RS:FindFirstChild("RemotesFolder") or RS:FindFirstChild("Bricks")
local ClientModules = RS:FindFirstChild("ModulesClient") or RS:FindFirstChild("ClientModules")

--============================================================
-- STATE
--============================================================

local State, ESP_DISTANCE, SpeedValue, InstantInteract

do
    State = {
        EntityESP = true, ItemESP = true, DoorESP = true, LeverESP = true,
        BookESP = true, FuseESP = true, ChestESP = true, HidingESP = true,
        FilledHidingESP = true, ElectricalESP = true,
        PlayerESP = true, NameTags = true, EntityNameTags = false, WorldNameTags = true,
        PlayerHealthBar = true,
        EntityTracers = true, ItemTracers = true, PlayerTracers = true,
        AutoDeleteDrones = false, AutoDeleteAlma = false,
        Notify = true, Sound = true, Fullbright = true,
        Overlay = true, Freecam = false,
        SpeedBypass = false,
        JumpBypass = false,
        SlideBypass = false,
        InfiniteJump = false,
        CrouchSpoof = false,
        NoAcceleration = false,
        NoclipForward = false,
        InstantInteract = true,

        AllESP = true,

        -- Дополнительные ESP
        KeyESP = true,
        GateLeverESP = true,
        RushLikeESP = true,
        EyesESP = true,

        -- Anti / Bypass — по умолчанию выключены
        AntiEyes = false,
        AntiSeekObstructions = false,
        AntiDupe = false,
        AntiSnare = false,
        AntiHalt = false,
        AntiScreech = false,
        AntiDread = false,
        NoSurgeDamage = false,
        NoHaltDamage = false,
        NoScreechDamage = false,
        InfiniteItems = false,
    }
    ESP_DISTANCE = DEFAULT_ESP_DISTANCE
    SpeedValue = 16
end

--============================================================
-- CLEANUP (v53 - v84)
--============================================================

do
    for v = 53, 84 do
        for _, suffix in ipairs({"Menu","Overlay","Notifications","Tracers"}) do
            local old = playerGui:FindFirstChild("DOORS_v"..v.."_"..suffix)
            if old then pcall(function() old:Destroy() end) end
        end
        local nt = workspace:FindFirstChild("DOORS_v"..v.."_NameTags")
        if nt then pcall(function() nt:Destroy() end) end
        local oldSound = SoundService:FindFirstChild("DOORS_v"..v.."_Alert")
        if oldSound then pcall(function() oldSound:Destroy() end) end
    end
end

--============================================================
-- SOUND
--============================================================

local alertSound
do
    alertSound = Instance.new("Sound")
    alertSound.Name = "Force_v85_Alert"
    alertSound.SoundId = "rbxassetid://89421399531250"
    alertSound.Volume = 1.5
    alertSound.Parent = SoundService
end

--============================================================
-- HELPERS
--============================================================

local normalizeName, getChar, getRoot, isOwnChar, getWorldPos, isWithinDist

do
    normalizeName = function(s)
        s = string.lower(tostring(s))
        s = s:gsub("[%s_%-]", "")
        return s
    end
    getChar = function() return player.Character end
    getRoot = function(c) if not c then return nil end return c:FindFirstChild("HumanoidRootPart") end
    isOwnChar = function(obj)
        local c = getChar()
        return c and obj:IsDescendantOf(c) or false
    end
    getWorldPos = function(t)
        if not t then return nil end
        if t:IsA("BasePart") then return t.Position end
        if t:IsA("Model") then
            if t.PrimaryPart then return t.PrimaryPart.Position end
            local ok, pivot = pcall(function() return t:GetPivot() end)
            if ok and pivot then return pivot.Position end
            local part = t:FindFirstChildWhichIsA("BasePart", true)
            if part then return part.Position end
        end
        return nil
    end
    isWithinDist = function(pos, rootPos)
        if ESP_DISTANCE <= 0 then return true end
        if not pos then return false end
        if not rootPos then
            local root = getRoot(getChar())
            if not root then return true end
            rootPos = root.Position
        end
        return (rootPos - pos).Magnitude <= ESP_DISTANCE
    end
end

--============================================================
-- BYPASS HELPERS (из Nebula Hub)
--============================================================

--============================================================
-- REVIVE SYSTEM
--============================================================

do
    local function canRevive()
        if not RemotesFolder then return false end
        return RemotesFolder:FindFirstChild("Revive") ~= nil
    end

    local function doRevive()
        if not RemotesFolder then return false end
        local reviveRemote = RemotesFolder:FindFirstChild("Revive")
        if not reviveRemote then return false end

        local ok = pcall(function()
            reviveRemote:FireServer()
        end)
        return ok
    end

    ENV.__Force_v85_Revive = function()
        return doRevive()
    end

    ENV.__Force_v85_CanRevive = function()
        return canRevive()
    end
end


local Functions = {}

do
    local hidingCache = false
    local hidingCacheTime = 0
    local hidingMarkers = setmetatable({}, {__mode = "k"})
    local hidingMarkerConns = setmetatable({}, {__mode = "k"})

    local function refreshHidingMarker(obj)
        if not obj or not obj.Parent or not obj:IsA("ObjectValue") then
            hidingMarkers[obj] = nil
            return
        end
        if obj.Value == player then
            hidingMarkers[obj] = true
        else
            hidingMarkers[obj] = nil
        end
    end

    local function trackHidingMarker(obj)
        if not obj or not obj:IsA("ObjectValue") then return end
        refreshHidingMarker(obj)
        if not hidingMarkerConns[obj] then
            local ok, conn = pcall(function()
                return obj:GetPropertyChangedSignal("Value"):Connect(function()
                    refreshHidingMarker(obj)
                end)
            end)
            if ok and conn then hidingMarkerConns[obj] = conn end
        end
    end

    local function untrackHidingMarker(obj)
        hidingMarkers[obj] = nil
        local conn = hidingMarkerConns[obj]
        if conn then pcall(function() conn:Disconnect() end) end
        hidingMarkerConns[obj] = nil
    end

    pcall(function()
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") or obj:IsA("Folder") then
                for _, child in ipairs(obj:GetDescendants()) do
                    if child:IsA("ObjectValue") then trackHidingMarker(child) end
                end
            end
        end
    end)
    Runtime:connect(workspace.DescendantAdded, trackHidingMarker)
    Runtime:connect(workspace.DescendantRemoving, untrackHidingMarker)

    Functions.Hiding = function()
        local now = os.clock()
        if now - hidingCacheTime < 0.75 then
            return hidingCache
        end

        hidingCacheTime = now
        hidingCache = false

        local room = nil
        local cr = workspace:FindFirstChild("CurrentRooms")
        local gameData = RS:FindFirstChild("GameData")
        local latest = gameData and gameData:FindFirstChild("LatestRoom")
        if cr and latest then
            room = cr:FindFirstChild(tostring(latest.Value))
        end
        if not room then return false end

        for marker in pairs(hidingMarkers) do
            if marker and marker.Parent and marker.Value == player and marker:IsDescendantOf(room) then
                hidingCache = true
                break
            end
        end

        return hidingCache
    end
        Functions.GetInjuriesSpeed = function()
        local char = getChar()
        if not char then return 0 end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return 0 end
        return 0.075 * (hum.MaxHealth - hum.Health)
    end
    Functions.GetCurrentSpeed = function()
        local char = getChar()
        if not char then return 16 end
        local s = 15
        s += char:GetAttribute("SpeedBoost") or 0
        s += char:GetAttribute("SpeedBoostBehind") or 0
        s += char:GetAttribute("SpeedBoostExtra") or 0
        s -= Functions.GetInjuriesSpeed()
        return s
    end
end

    ENV.__Force_v85_CLEAR_HIDING_MARKERS = function()
        for obj, conn in pairs(hidingMarkerConns) do
            pcall(function() conn:Disconnect() end)
            hidingMarkerConns[obj] = nil
            hidingMarkers[obj] = nil
        end
    end


local noAccelState = { active = false, saved = {} }

local function applyNoAcceleration()
    local char = getChar()
    if not char then return end
    if State.NoAcceleration and not noAccelState.active then
        noAccelState.active = true
        noAccelState.saved = {}
        local root = char:FindFirstChild("HumanoidRootPart")
        local props = (root and root.CustomPhysicalProperties)
            or PhysicalProperties.new(0.7, 0.3, 0.5)
        local custom = PhysicalProperties.new(100, props.Friction, props.Elasticity, props.FrictionWeight, props.ElasticityWeight)
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                noAccelState.saved[part] = part.CustomPhysicalProperties
                part.CustomPhysicalProperties = custom
            end
        end
    elseif not State.NoAcceleration and noAccelState.active then
        noAccelState.active = false
        for part, oldProps in pairs(noAccelState.saved) do
            if part and part.Parent then
                pcall(function() part.CustomPhysicalProperties = oldProps end)
            end
        end
        noAccelState.saved = {}
    end
end

--============================================================
-- CURRENT ROOM CACHE
--============================================================

local getCurrentRoom = function() return nil end

do
    local cache, cacheTime = nil, 0
    getCurrentRoom = function(rootPos)
        local now = os.clock()

        if cache and cache.Parent and now - cacheTime < ROOM_CACHE_TTL then
            return cache
        end

        local cr = workspace:FindFirstChild("CurrentRooms")
        if not cr then
            cache = nil
            cacheTime = now
            return nil
        end

        -- Быстрый путь: LatestRoom обычно уже указывает точную комнату.
        pcall(function()
            local gameData = RS:FindFirstChild("GameData")
            local latest = gameData and gameData:FindFirstChild("LatestRoom")
            if latest then
                local room = cr:FindFirstChild(tostring(latest.Value))
                if room then
                    cache = room
                    cacheTime = now
                end
            end
        end)

        if cache and cache.Parent and now - cacheTime < ROOM_CACHE_TTL then
            return cache
        end

        -- Fallback только если LatestRoom недоступен.
        rootPos = rootPos or Vector3.zero
        local best, bestDist = nil, math.huge
        for _, room in ipairs(cr:GetChildren()) do
            if room:IsA("Model") then
                local pos = room.PrimaryPart and room.PrimaryPart.Position
                if not pos then
                    local ok, pivot = pcall(function() return room:GetPivot() end)
                    if ok and pivot then
                        pos = pivot.Position
                    else
                        local part = room:FindFirstChildWhichIsA("BasePart", true)
                        if part then pos = part.Position end
                    end
                end
                if pos then
                    local d = (rootPos - pos).Magnitude
                    if d < bestDist then
                        bestDist = d
                        best = room
                    end
                end
            end
        end

        cache = best
        cacheTime = now
        return best
    end
end

--============================================================
-- FULLBRIGHT (toggleable + auto-reapply)
--============================================================

local applyFB, removeFB, reapplyFullbright

do
    local fb = { active = false, light = {}, inst = {} }

    local fbTargets = {
        Ambient                  = Color3.fromRGB(255, 255, 255),
        OutdoorAmbient           = Color3.fromRGB(255, 255, 255),
        Brightness               = 3,
        ClockTime                = 14,
        GlobalShadows            = false,
        EnvironmentDiffuseScale  = 1,
        EnvironmentSpecularScale = 1,
        ExposureCompensation     = 0,
        FogStart                 = 0,
        FogEnd                   = 1e6,
        FogColor                 = Color3.fromRGB(255, 255, 255),
    }

    applyFB = function()
        if fb.active then return end
        fb.active = true
        fb.light = {
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd,
            FogStart = Lighting.FogStart,
            FogColor = Lighting.FogColor,
            GlobalShadows = Lighting.GlobalShadows,
            EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
            EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
            ExposureCompensation = Lighting.ExposureCompensation,
        }
        fb.inst = {}
        for k, v in pairs(fbTargets) do
            pcall(function() Lighting[k] = v end)
        end
        for _, obj in ipairs(Lighting:GetChildren()) do
            if obj:IsA("Atmosphere") then
                fb.inst[obj] = { den = obj.Density }
                obj.Density = 0
            elseif obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect")
                or obj:IsA("SunRaysEffect") or obj:IsA("DepthOfFieldEffect") then
                fb.inst[obj] = { en = obj.Enabled }
                obj.Enabled = false
            end
        end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Light") then
                fb.inst[obj] = { en = obj.Enabled }
                obj.Enabled = false
            end
        end
    end

    removeFB = function()
        if not fb.active then return end
        fb.active = false
        for k, v in pairs(fb.light) do
            pcall(function() Lighting[k] = v end)
        end
        for obj, d in pairs(fb.inst) do
            if obj and obj.Parent then
                pcall(function()
                    if d.en ~= nil then obj.Enabled = d.en end
                    if d.den ~= nil and obj:IsA("Atmosphere") then obj.Density = d.den end
                end)
            end
        end
        fb.light = {}
        fb.inst = {}
    end

    reapplyFullbright = function()
        if not fb.active then return end
        for k, v in pairs(fbTargets) do
            if Lighting[k] ~= v then
                pcall(function() Lighting[k] = v end)
            end
        end
        for obj in pairs(fb.inst) do
            if obj and obj.Parent then
                pcall(function()
                    if obj:IsA("Atmosphere") then
                        if obj.Density ~= 0 then obj.Density = 0 end
                    else
                        if obj.Enabled then obj.Enabled = false end
                    end
                end)
            end
        end
    end

    for prop in pairs(fbTargets) do
        Runtime:connect(Lighting:GetPropertyChangedSignal(prop), function()
            if not fb.active then return end
            if not State.Fullbright then return end
            task.defer(function() pcall(reapplyFullbright) end)
        end)
    end

    Runtime:spawn(function()
        while Runtime.alive do
            if fb.active and State.Fullbright then
                pcall(reapplyFullbright)
            end
            task.wait(0.5)
        end
    end)
end

--============================================================
-- NOTIFICATIONS
--============================================================

local showNotification

local RADAR_ENTITIES = {
    RUSH = true, AMBUSH = true, BASH = true, SCRIBBLES = true,
    BLITZ = true, SURGE = true, DRONE = true, DRONES = true,
}

local function isRadarEntity(name)
    return RADAR_ENTITIES[tostring(name):upper()] == true
end

do
    local notifyGui = Instance.new("ScreenGui")
    notifyGui.Name = "Force_v85_Notifications"
    notifyGui.ResetOnSpawn = false
    notifyGui.IgnoreGuiInset = true
    notifyGui.DisplayOrder = CONFIG.DISPLAY_ORDER
    notifyGui.Parent = playerGui

    local notifyContainer = Instance.new("Frame")
    notifyContainer.AnchorPoint = Vector2.new(0.5, 0)
    notifyContainer.Position = UDim2.new(0.5, 0, 0, 24)
    notifyContainer.Size = UDim2.new(0, 480, 0, 0)
    notifyContainer.AutomaticSize = Enum.AutomaticSize.Y
    notifyContainer.BackgroundTransparency = 1
    notifyContainer.Parent = notifyGui

    local notifyLayout = Instance.new("UIListLayout")
    notifyLayout.Padding = UDim.new(0, 10)
    notifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    notifyLayout.Parent = notifyContainer

    local trackedNotifications = {}

    local function closeNotification(data)
        if not data or data.closing then return end
        data.closing = true
        trackedNotifications[data.card] = nil
        pcall(function()
            if data.card and data.card.Parent then
                local tw = TweenService:Create(data.card, data.easeIn, {
                    Position = UDim2.fromOffset(0, -30),
                    BackgroundTransparency = 1,
                })
                if data.stroke then
                    TweenService:Create(data.stroke, data.easeIn, {Transparency = 1}):Play()
                end
                if data.radarDot then
                    TweenService:Create(data.radarDot, data.easeIn, {BackgroundTransparency = 1}):Play()
                end
                tw:Play()
                Runtime:connect(tw.Completed, function()
                    if data.card then data.card:Destroy() end
                end)
            end
        end)
    end

    local function getRadarFactor(target)
        if not target or not target.Parent then return nil end
        local root = getRoot(getChar())
        local targetPos = getWorldPos(target)
        if not root or not targetPos then return nil end
        local delta = targetPos - root.Position
        local flat = Vector3.new(delta.X, 0, delta.Z)
        if flat.Magnitude < 0.01 then return 0.5 end
        flat = flat.Unit
        local right = root.CFrame.RightVector
        local rightFlat = Vector3.new(right.X, 0, right.Z)
        if rightFlat.Magnitude < 0.01 then return 0.5 end
        rightFlat = rightFlat.Unit
        local lateral = math.clamp(flat:Dot(rightFlat), -1, 1)
        return math.clamp(0.5 + lateral * 0.5, 0, 1)
    end

    showNotification = function(title, textMsg, color, trackedObject, radarEnabled)
        if State and not State.Notify then return end
        pcall(function()
            local easeOut = TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
            local easeIn  = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            local isTracked = trackedObject ~= nil and trackedObject.Parent ~= nil
            local showRadar = isTracked and radarEnabled == true
            local cardHeight = showRadar and 88 or 68

            local card = Instance.new("Frame")
            card.Size = UDim2.fromOffset(460, cardHeight)
            card.Position = UDim2.fromOffset(0, -30)
            card.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
            card.BackgroundTransparency = 1
            card.BorderSizePixel = 0
            card.ClipsDescendants = true
            card.Parent = notifyContainer

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = card

            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(255, 255, 255)
            stroke.Thickness = 1
            stroke.Transparency = 1
            stroke.Parent = card

            local accent = Instance.new("Frame")
            accent.Size = UDim2.new(0, 4, 1, -16)
            accent.Position = UDim2.fromOffset(8, 8)
            accent.BackgroundColor3 = color or Color3.fromRGB(240, 240, 240)
            accent.BorderSizePixel = 0
            accent.Parent = card

            local ac = Instance.new("UICorner")
            ac.CornerRadius = UDim.new(1, 0)
            ac.Parent = accent

            local tLbl = Instance.new("TextLabel")
            tLbl.Position = UDim2.fromOffset(24, 13)
            tLbl.Size = UDim2.new(1, -40, 0, 18)
            tLbl.BackgroundTransparency = 1
            tLbl.Text = string.upper(tostring(title))
            tLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            tLbl.Font = Enum.Font.GothamBold
            tLbl.TextSize = 13
            tLbl.TextXAlignment = Enum.TextXAlignment.Left
            tLbl.Parent = card

            local mLbl = Instance.new("TextLabel")
            mLbl.Position = UDim2.fromOffset(24, 33)
            mLbl.Size = UDim2.new(1, -40, 0, 20)
            mLbl.BackgroundTransparency = 1
            mLbl.Text = tostring(textMsg)
            mLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
            mLbl.Font = Enum.Font.Gotham
            mLbl.TextSize = 14
            mLbl.TextXAlignment = Enum.TextXAlignment.Left
            mLbl.TextWrapped = true
            mLbl.TextTruncate = Enum.TextTruncate.AtEnd
            mLbl.Parent = card

            local radarTrack, radarDot
            if showRadar then
                radarTrack = Instance.new("Frame")
                radarTrack.Position = UDim2.fromOffset(24, 62)
                radarTrack.Size = UDim2.new(1, -48, 0, 4)
                radarTrack.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                radarTrack.BackgroundTransparency = 0.25
                radarTrack.BorderSizePixel = 0
                radarTrack.Parent = card
                local trackCorner = Instance.new("UICorner")
                trackCorner.CornerRadius = UDim.new(1, 0)
                trackCorner.Parent = radarTrack

                local radarCenter = Instance.new("Frame")
                radarCenter.AnchorPoint = Vector2.new(0.5, 0.5)
                radarCenter.Position = UDim2.new(0.5, 0, 0.5, 0)
                radarCenter.Size = UDim2.fromOffset(2, 10)
                radarCenter.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                radarCenter.BorderSizePixel = 0
                radarCenter.Parent = radarTrack

                radarDot = Instance.new("Frame")
                radarDot.AnchorPoint = Vector2.new(0.5, 0.5)
                radarDot.Position = UDim2.new(0.5, 0, 0.5, 0)
                radarDot.Size = UDim2.fromOffset(8, 8)
                radarDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                radarDot.BorderSizePixel = 0
                radarDot.Parent = radarTrack
                local dotCorner = Instance.new("UICorner")
                dotCorner.CornerRadius = UDim.new(1, 0)
                dotCorner.Parent = radarDot
                local dotStroke = Instance.new("UIStroke")
                dotStroke.Color = Color3.fromRGB(0, 0, 0)
                dotStroke.Thickness = 1
                dotStroke.Transparency = 0.15
                dotStroke.Parent = radarDot
            end

            TweenService:Create(card, easeOut, {
                Position = UDim2.fromOffset(0, 0),
                BackgroundTransparency = 0.25,
            }):Play()
            TweenService:Create(stroke, easeOut, {Transparency = 0.88}):Play()

            local data = {
                card = card, stroke = stroke,
                object = isTracked and trackedObject or nil,
                radarDot = radarDot, radarTrack = radarTrack,
                radarValue = 0.5, easeIn = easeIn, closing = false,
            }

            if isTracked then
                trackedNotifications[card] = data
            else
                task.delay(3.5, function() closeNotification(data) end)
            end
        end)
    end

    Runtime:spawn(function()
        while Runtime.alive do
            for card, data in pairs(trackedNotifications) do
                pcall(function()
                    if not card or not card.Parent then
                        trackedNotifications[card] = nil
                        return
                    end
                    local obj = data.object
                    local alive = obj and obj.Parent and obj:IsDescendantOf(workspace)
                    if not alive then closeNotification(data); return end
                    if data.radarDot and data.radarTrack then
                        local factor = getRadarFactor(obj)
                        if factor then
                            data.radarValue = data.radarValue + (factor - data.radarValue) * 0.22
                            data.radarDot.Position = UDim2.new(data.radarValue, 0, 0.5, 0)
                        end
                    end
                end)
            end
            task.wait(0.05)
        end
    end)
end

--============================================================
-- ESP CORE
--============================================================

local addESP, removeESPFrom, clearESPByTag, getESPTarget

do
    local espRegistry = {}
    local worldNameTags = setmetatable({}, {__mode = "k"})


    local function worldTagPart(target)
        if not target then return nil end
        if target:IsA('BasePart') then return target end
        if target:IsA('Model') then
            return target.PrimaryPart or target:FindFirstChildWhichIsA('BasePart', true)
        end
        return nil
    end

    local function niceWorldName(target, tag)
        if tag == 'DoorESP' then return 'Door' end
        if tag == 'LeverESP' then return 'Lever' end
        if tag == 'BookESP' then return 'Book' end
        if tag == 'FuseESP' then return 'Fuse' end
        if tag == 'ElectricalESP' then return 'Electrical' end
        if tag == 'KeyESP' then return 'Key' end
        if tag == 'GateLeverESP' then return 'Gate lever' end
        if tag == 'ItemESP' then return 'Item' end
        if tag == 'ChestESP' then
            local n = normalizeName(target.Name)
            if n and string.find(n, 'locked', 1, true) then return 'Locked chest' end
            return 'Chest'
        end
        if tag == 'HidingESP' or tag == 'FilledHidingESP' then
            local n = normalizeName(target.Name)
            if n:find('wardrobe', 1, true) then return 'Wardrobe' end
            if n:find('cupboard', 1, true) then return 'Cupboard' end
            if n:find('closet', 1, true) then return 'Closet' end
            if n:find('locker', 1, true) then return 'Locker' end
            if n:find('toolshed', 1, true) then return 'Tool shed' end
            if n:match('^hidingspot%d*$') then return 'Hiding spot' end
            return 'Hiding spot'
        end
        return worldTagLabels[tag] or 'Object'
    end

    local function addWorldNameTag(target, tag)
        if not State.WorldNameTags then return end
        if tag == 'EntityESP' or tag == 'RushLikeESP' or tag == 'EyesESP' then return end
        if not target or not target.Parent then return end
        local part = worldTagPart(target)
        if not part then return end
        local display = niceWorldName(target, tag)
        local old = worldNameTags[target]
        if old and old.Parent then
            local lbl = old:FindFirstChild('Label')
            if lbl then lbl.Text = display end
            old:SetAttribute('ForceTag', tag)
            old.Adornee = part
            return
        end
        pcall(function()
            local bb = Instance.new('BillboardGui')
            bb.Name = 'WorldNameTag'
            bb:SetAttribute('ForceTag', tag)
            bb.Adornee = part
            bb.Size = UDim2.fromOffset(170, 24)
            bb.StudsOffset = Vector3.new(0, 2.3, 0)
            bb.AlwaysOnTop = true
            bb.MaxDistance = 0
            bb.Parent = playerGui

            local lbl = Instance.new('TextLabel')
            lbl.Name = 'Label'
            lbl.Size = UDim2.fromScale(1, 1)
            lbl.BackgroundTransparency = 1
            lbl.Text = display
            lbl.TextColor3 = NAMETAG_COLOR
            lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            lbl.TextStrokeTransparency = 0.15
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 15
            lbl.TextTruncate = Enum.TextTruncate.AtEnd
            lbl.Parent = bb
            worldNameTags[target] = bb
        end)
    end

    local function removeWorldNameTag(target)
        local bb = worldNameTags[target]
        if bb then pcall(function() bb:Destroy() end) end
        worldNameTags[target] = nil
    end

    local function removeTagForTarget(target, tag)
        local bb = worldNameTags[target]
        if bb and bb:GetAttribute('ForceTag') == tag then
            removeWorldNameTag(target)
        end
    end

    ENV.__Force_v85_CLEAR_WORLD_NAMETAGS = function()
        for target, bb in pairs(worldNameTags) do
            pcall(function() bb:Destroy() end)
            worldNameTags[target] = nil
        end
    end

    -- Прозрачные Rush-like / Eyes-like модели:
    -- для рендера Highlight временно переводим почти полностью прозрачные
    -- части на Transparency=0.99 и добавляем локальный Humanoid только если
    -- он действительно нужен. Исходная прозрачность восстанавливается после
    -- удаления всех соответствующих ESP-подсветок.
    local transparentESPStates = setmetatable({}, {__mode = "k"})
    local transparentEntityTags = {
        EntityESP = true,
        RushLikeESP = true,
        EyesESP = true,
    }

    local function getTransparentSupportModel(target)
        if not target then return nil end
        if target:IsA("Model") then return target end
        return target:FindFirstAncestorOfClass("Model")
    end

    local function ensureTransparentSupportHumanoid(model, state)
        if state.createdHumanoid and state.createdHumanoid.Parent then return end
        if model:FindFirstChildOfClass("Humanoid") then return end

        local humanoid = Instance.new("Humanoid")
        humanoid.Name = "ForceHighlightHumanoid"
        pcall(function()
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
            humanoid.NameDisplayDistance = 0
            humanoid.HealthDisplayDistance = 0
            humanoid.DisplayName = ""
        end)
        state.createdHumanoid = humanoid
        humanoid.Parent = model
    end

    local function trackTransparentPart(model, state, part)
        if not part or not part:IsA("BasePart") then return end

        if not state.partConnections[part] then
            state.partConnections[part] = part:GetPropertyChangedSignal("Transparency"):Connect(function()
                if state.restoring or state.applying[part] or not part.Parent then return end
                local current = part.Transparency
                if current >= 0.99 then
                    -- Если сама игра снова скрывает эту часть, запоминаем
                    -- новое значение и применяем визуальный порог для Highlight.
                    state.originalTransparency[part] = current
                    state.applying[part] = true
                    pcall(function() part.Transparency = 0.99 end)
                    state.applying[part] = nil
                    ensureTransparentSupportHumanoid(model, state)
                end
            end)
        end

        if part.Transparency >= 0.99 then
            state.originalTransparency[part] = part.Transparency
            if part.Transparency ~= 0.99 then
                state.applying[part] = true
                pcall(function() part.Transparency = 0.99 end)
                state.applying[part] = nil
            end
            ensureTransparentSupportHumanoid(model, state)
        end
    end

    local function restoreTransparentSupport(model, force)
        local state = transparentESPStates[model]
        if not state then return end

        if not force and model and model.Parent then
            for tag in pairs(transparentEntityTags) do
                if model:FindFirstChild("ESP_" .. tag, true) then
                    return
                end
            end
        end

        state.restoring = true
        if state.descendantConnection then
            pcall(function() state.descendantConnection:Disconnect() end)
        end
        if state.destroyingConnection then
            pcall(function() state.destroyingConnection:Disconnect() end)
        end
        if state.ancestryConnection then
            pcall(function() state.ancestryConnection:Disconnect() end)
        end
        for part, conn in pairs(state.partConnections) do
            pcall(function() conn:Disconnect() end)
            state.partConnections[part] = nil
        end

        for part, original in pairs(state.originalTransparency) do
            if part and part.Parent then
                pcall(function()
                    -- Не перезаписываем возможное новое состояние игры.
                    if math.abs(part.Transparency - 0.99) < 0.0001 then
                        part.Transparency = original
                    end
                end)
            end
            state.originalTransparency[part] = nil
        end

        if state.createdHumanoid and state.createdHumanoid.Parent then
            pcall(function() state.createdHumanoid:Destroy() end)
        end
        transparentESPStates[model] = nil
    end

    local function prepareTransparentSupport(target, tag)
        if tag ~= "RushLikeESP" and tag ~= "EyesESP" then return end
        local model = getTransparentSupportModel(target)
        if not model or not model.Parent then return end

        local state = transparentESPStates[model]
        if state then return end

        state = {
            originalTransparency = {},
            partConnections = {},
            applying = {},
            createdHumanoid = nil,
            restoring = false,
            descendantConnection = nil,
            destroyingConnection = nil,
            ancestryConnection = nil,
        }
        transparentESPStates[model] = state

        -- Слушаем не только уже прозрачные части: некоторые сущности делают
        -- части прозрачными уже после появления модели в Workspace.
        for _, child in ipairs(model:GetDescendants()) do
            if child:IsA("BasePart") then
                trackTransparentPart(model, state, child)
            end
        end

        state.descendantConnection = model.DescendantAdded:Connect(function(child)
            if state.restoring then return end
            if child:IsA("BasePart") then
                trackTransparentPart(model, state, child)
            end
        end)
        state.destroyingConnection = model.Destroying:Connect(function()
            restoreTransparentSupport(model, true)
        end)
        state.ancestryConnection = model.AncestryChanged:Connect(function(_, parent)
            if parent == nil then
                restoreTransparentSupport(model, true)
            end
        end)
    end

    addESP = function(target, color, tag)
        if State and State.AllESP == false then return end
        if not target then return end
        if not target:IsA("Model") and not target:IsA("BasePart") then return end
        prepareTransparentSupport(target, tag)
        local name = "ESP_" .. tag
        local existing = target:FindFirstChild(name)
        if existing then
            pcall(function()
                existing.FillColor = color
                existing.OutlineColor = color
            end)
            espRegistry[tag] = espRegistry[tag] or {}
            espRegistry[tag][target] = existing
            addWorldNameTag(target, tag)
            return existing
        end
        local ok, h = pcall(function()
            local highlight = Instance.new("Highlight")
            highlight.Name = name
            highlight.Adornee = target
            highlight.FillColor = color
            highlight.FillTransparency = 0.65
            highlight.OutlineColor = color
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = target
            return highlight
        end)
        if ok and h then
            espRegistry[tag] = espRegistry[tag] or {}
            espRegistry[tag][target] = h
            addWorldNameTag(target, tag)
            return h
        end
    end

    removeESPFrom = function(target, tag)
        if not target then return end
        local name = "ESP_" .. tag
        local bucket = espRegistry[tag]
        pcall(function()
            local h = target:FindFirstChild(name)
            if h then h:Destroy() end
        end)
        if bucket then bucket[target] = nil end
        removeTagForTarget(target, tag)
        if transparentEntityTags[tag] then
            local model = getTransparentSupportModel(target)
            if model then restoreTransparentSupport(model, false) end
        end
    end

    clearESPByTag = function(tag)
        local bucket = espRegistry[tag]
        if not bucket then return end
        for target, h in pairs(bucket) do
            pcall(function()
                if h and h.Parent then h:Destroy()
                elseif target and target.Parent then
                    local found = target:FindFirstChild("ESP_" .. tag)
                    if found then found:Destroy() end
                end
            end)
            bucket[target] = nil
            removeTagForTarget(target, tag)
            if transparentEntityTags[tag] then
                local model = getTransparentSupportModel(target)
                if model then restoreTransparentSupport(model, false) end
            end
        end
    end

    getESPTarget = function(obj)
        if obj:IsA("Model") then return obj end
        if obj:IsA("Tool") then
            local m = obj:FindFirstChildWhichIsA("Model")
            if m then return m end
            local h = obj:FindFirstChild("Handle")
            if h and h:IsA("BasePart") then return h end
        end
        if obj:IsA("BasePart") then return obj end
        return nil
    end
end

--============================================================
-- DOOR
--============================================================

local getDoorTargets, isDupeDoor, addDoorESP

do
    getDoorTargets = function(m)
        if not m or not m:IsA("Model") then return {} end
        local targets, seen = {}, {}
        for _, child in ipairs(m:GetChildren()) do
            if child:IsA("BasePart") and normalizeName(child.Name) == "door" then
                if not seen[child] then targets[#targets + 1] = child; seen[child] = true end
            end
        end
        if #targets > 0 then return targets end
        for _, pn in ipairs({ "Main", "DoorPart", "DoorPanel" }) do
            local p = m:FindFirstChild(pn)
            if p and p:IsA("BasePart") and not seen[p] then
                targets[#targets + 1] = p; seen[p] = true
            end
        end
        if #targets > 0 then return targets end
        if m.PrimaryPart then return { m.PrimaryPart } end
        return {}
    end

    isDupeDoor = function(m)
        if m:GetAttribute("IsDupe") == true then return true end
        if m:GetAttribute("Dupe") == true then return true end
        if m:GetAttribute("Fake") == true then return true end
        if m:GetAttribute("IsFake") == true then return true end
        local mn = normalizeName(m.Name)
        if mn == "dupedoor" or mn == "fakedoor" then return true end
        return false
    end

    addDoorESP = function(m)
        if not State.DoorESP then return end
        local dupe = isDupeDoor(m)
        local color = dupe and DOOR_DUPE_COLOR or DOOR_COLOR
        for _, target in ipairs(getDoorTargets(m)) do
            local h = addESP(target, color, "DoorESP")
            if h then
                pcall(function()
                    h.FillTransparency = 1
                    h.OutlineTransparency = 0
                    h.OutlineColor = color
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                end)
            end
        end
    end
end

--============================================================
-- DICTIONARIES
--============================================================

local items, monsters, noESPEntities, levers, electricals
local books, fuses, normalChests, lockedChests, mandrakeHoles
local moneyKeywords, nonMoney, moneyContainers
local isMoneyName, isMoneyPrompt

do
    items = {
        peachcobbler=true, objectscanner=true,
        crucifix=true, bulklight=true, compass=true,
        glowsticks=true, glowstick=true,
        knockbackstick=true, candle=true, shakelight=true,
        starbottle=true, boxinggloves=true, riftcandle=true,
        batterypack=true, nannerpeel=true,
        bandagepack=true, bandage=true, bandages=true,
        riftjar=true, pocketmirror=true, tipjar=true,
        knockbomb=true, lockpick=true, lockpicks=true,
        alarmclock=true, bomb=true, shears=true,
        snakebox=true, starvial=true, gweensoda=true,
        stopsign=true, aloevera=true, aloe=true,
        bread=true, lighter=true, skeletonkey=true,
        smoothie=true, straplight=true, nanner=true,
        lantern=true, laserpointer=true,
        vitamins=true, vitamin=true, pizza=true,
        starjug=true, cheese=true, donut=true,
        holygrenade=true, riftsmoothie=true,
        flashlight=true, multitool=true, goldgun=true,
        bigbomb=true, honeypot=true,
        key=true, roomkey=true, hotelkey=true,
        electricalroomkey=true, keyobtain=true, keymodel=true,
        backdoorroomkey=true, backdoorkey=true,
        a60key=true, a90key=true, a120key=true,
        moonlightcandle=true, moonlightfloat=true,
        lotus=true, lotusflower=true,
        lotuspetal=true, lotuspetals=true,
        worldlotus=true, camera=true, spray=true,
        glitchfragment=true, lunchbox=true,
        papercup=true, papercupblue=true,
        papercuppurple=true, papercupred=true,
        paperplane=true, coinroll=true,
        fihfood=true, packofgweensoda=true,
        waitingticket=true,
    }

    monsters = {
        rush="RUSH", rushmoving="RUSH", rushnew="RUSH", rushmovingnew="RUSH",
        ambush="AMBUSH", ambushmoving="AMBUSH", ambushnew="AMBUSH", ambushmovingnew="AMBUSH",
        figure="FIGURE", figuremoving="FIGURE", figurerig="FIGURE", figurenew="FIGURE",
        figuremodel="FIGURE", figurebody="FIGURE", figurehead="FIGURE",
        eyes="EYES", eyesnew="EYES", eyesrig="EYES",
        screech="SCREECH", screechnew="SCREECH", screechrig="SCREECH",
        screechmodel="SCREECH", screechv2="SCREECH", screechbody="SCREECH",
        halt="HALT", haltnew="HALT", dupe="DUPE", dupenew="DUPE",
        hide="HIDE", hidenew="HIDE", jack="JACK", jacknew="JACK",
        timothy="TIMOTHY", timothynew="TIMOTHY",
        dread="DREAD", dreadnew="DREAD", shadow="SHADOW",
        snare="SNARE", snarenew="SNARE", snarebase="SNARE", snaretrap="SNARE",
        sally="SALLY", sallynew="SALLY",
        giggle="GIGGLE", giggleceiling="GIGGLE",
        gloombat="GLOOMBAT", gloombats="GLOOMBATS", gloombatswarm="GLOOMBAT SWARM",
        grumble="GRUMBLE", grumblemoving="GRUMBLE",
        grumblenew="GRUMBLE", grumblemovingnew="GRUMBLE",
        queengrumble="QUEEN GRUMBLE",
        haste="HASTE", hastenew="HASTE",
        blitz="BLITZ", blitznew="BLITZ",
        backdoorrush="BLITZ", backdoorrushnew="BLITZ",
        lookman="LOOKMAN", lookmaneyes="LOOKMAN",
        lookmannew="LOOKMAN", lookmaneyesnew="LOOKMAN",
        backdoorlookman="LOOKMAN", backdoorlookmaneyes="LOOKMAN",
        vacuum="VACUUM", vacuumnew="VACUUM",
        a60="A-60", ["a-60"]="A-60", a90="A-90", ["a-90"]="A-90",
        a120="A-120", ["a-120"]="A-120",
        bramble="BRAMBLE", liveentitybramble="BRAMBLE", bramblecollapsed="BRAMBLE",
        eyestalk="EYESTALK", groundskeeper="GROUNDSKEEPER",
        mandrake="MANDRAKE", mandrakelive="MANDRAKE LIVE",
        monument="MONUMENT", monumentnew="MONUMENT", monumententity="MONUMENT",
        surge="SURGE", surgenew="SURGE", grampy="GRAMPY",
        honcho="HONCHO", drone="DRONE", drones="DRONES",
        dronenew="DRONE", dronesnew="DRONES",
        forgetmenot="FORGET-ME-NOT", teller="TELLER", alma="ALMA",
        bash="BASH", bashnew="BASH", bashmoving="BASH", bashmovingnew="BASH",
        ransom="RANSOM", ransomnew="RANSOM",
        ransomentity="RANSOM", ransommoving="RANSOM",
        scribble="SCRIBBLES", scribbles="SCRIBBLES",
        scribblemoving="SCRIBBLES", scribblemovingnew="SCRIBBLES",
        stem="STEM", stems="STEMS", portrait="PORTRAIT",
        creak="CREAK", creaknew="CREAK", noise="NOISE", noisenew="NOISE",
        hijack="HIJACK", cobbler="COBBLER",
        voided="VOIDED",
    }

    noESPEntities = { GLOOMBAT = true, ["GLOOMBAT SWARM"] = true }

    levers = {
        lever=true, levermodel=true, basementlever=true,
        basementlevermodel=true, leverbasement=true,
        backdoorlever=true, backdoorlevermodel=true,
        backdoorbasementlever=true, timerlever=true,
        timerlevermodel=true, timelever=true, timelevermodel=true,
        generatorlever=true, pulllever=true, keylever=true,
    }

    electricals = { livebreakerpolepickup=true, electricalkeyobtain=true }
    books = { book=true, librarybook=true, bookinteractive=true, libraryhintpaper=true, livehintbook=true }
    fuses = { fuse=true, fuses=true, fusebox=true, fuseobject=true, generatorfuse=true }
    normalChests = { chest=true, lootchest=true, chestbox=true }
    lockedChests = { lockedchest=true, lockchest=true, chestlocked=true }
    mandrakeHoles = { mandrakehole=true, mandrakeholes=true }

    moneyKeywords = {
        "gold", "coin", "cash", "money", "nugget",
        "dollar", "bill", "wallet", "pouch", "sack",
        "loot", "treasure", "gem", "jewel", "diamond",
        "banknote", "bankroll", "goldbar",
        "silver", "bronze", "penny", "nickel", "dime", "quarter",
    }

    nonMoney = {
        candle=true, lighter=true, flashlight=true,
        battery=true, batteries=true, vitamin=true, vitamins=true,
        bandage=true, bandages=true, bandagepack=true, painkillers=true,
        lockpick=true, lockpicks=true, crucifix=true, shears=true,
        smoothie=true, donut=true, aloe=true, aloevera=true,
        herbofviridis=true, greenherb=true, alarmclock=true,
        key=true, roomkey=true, hotelkey=true, skeletonkey=true,
        electricalroomkey=true, keyobtain=true, keymodel=true,
        tapeplayer=true, cassette=true, screwdriver=true, bucket=true,
        crankinghandle=true, vinylrecord=true, tab=true,
        bulklight=true, straplight=true, shakelight=true,
        glowstick=true, glowsticks=true, gloomstick=true,
        laserpointer=true, batterypack=true, multitool=true,
        cheese=true, bread=true, gweensoda=true,
        moonlightcandle=true, moonlightfloat=true,
        starlightbottle=true, starbottle=true,
        starlightvial=true, starvial=true, starlightjug=true, starjug=true,
        backdoorroomkey=true, backdoorkey=true,
        a60key=true, a90key=true, a120key=true,
        lantern=true, compass=true, ironkey=true,
        lotus=true, lotusflower=true, lotuspetal=true, lotuspetals=true,
        worldlotus=true, camera=true, spray=true,
        riftjar=true, tipjar=true, glitchfragment=true,
        pizza=true, waitingticket=true, lunchbox=true,
        papercup=true, papercupblue=true, papercuppurple=true, papercupred=true,
        paperplane=true, coinroll=true,
        fihfood=true, packofgweensoda=true, honeypot=true,
    }

    moneyContainers = {
        cashregister=true, register=true, cashbox=true,
        moneybag=true, money=true, piggybank=true, vault=true,
    }

    isMoneyName = function(text)
        local n = normalizeName(text)
        if nonMoney[n] then return false end
        for _, kw in ipairs(moneyKeywords) do
            if string.find(n, kw, 1, true) then return true end
        end
        return false
    end

    isMoneyPrompt = function(prompt)
        if isMoneyName(prompt.ActionText or "") then return true end
        if isMoneyName(prompt.ObjectText or "") then return true end
        if isMoneyName(prompt.Name) then return true end
        return false
    end
end

--============================================================
-- HIDING
--============================================================

local hidingNames, hidingKeywords, hidingBlacklist, isHidingBlacklisted, getHidingTarget, isHidingFilled

do
    hidingNames = {
        cupboard=true, wardrobe=true, closet=true,
        locker=true, hidingplace=true, mineslocker=true,
        metalwardrobe=true, metalcloset=true,
        backdoorlocker=true, backdoorwardrobe=true, backdoorcloset=true,
        roomslocker=true, alocker=true, toolshed=true, toolsheds=true,
    }

    hidingKeywords = { "cupboard", "wardrobe", "closet", "locker", "hidingplace", "toolshed" }

    local function getArchivesAssets()
        local cr = workspace:FindFirstChild("CurrentRooms")
        if not cr then return nil end
        local r3 = cr:FindFirstChild("3")
        if not r3 then return nil end
        return r3:FindFirstChild("Assets")
    end

    local function getArchiveHidingTarget(obj)
        local assets = getArchivesAssets()
        if not assets then return nil end
        local model = obj:IsA("Model") and obj or obj:FindFirstAncestorOfClass("Model")
        if not model or model.Parent ~= assets then return nil end
        local n = normalizeName(model.Name)
        if n:match("^hidingspot%d*$") then return model end
        return nil
    end

    hidingBlacklist = {
        lockersmall=true, lockersmalllocked=true,
        brokenlocker=true, brokenlockers=true, lockerbroken=true,
        brokenwardrobe=true, brokencupboard=true, brokentoolshed=true,
    }

    isHidingBlacklisted = function(mName)
        if hidingBlacklist[mName] == true then return true end
        if string.match(mName, "^minessideroomlockers%d*$") then return true end
        return string.find(mName, "broken", 1, true) ~= nil
    end

    local function readBoolMarker(model, name)
        local attr = model:GetAttribute(name)
        if attr == true then return true end
        local v = model:FindFirstChild(name, true)
        if v and v:IsA("BoolValue") and v.Value then return true end
        return false
    end

    isHidingFilled = function(model)
        return readBoolMarker(model, "Filled")
            or readBoolMarker(model, "Occupied")
            or readBoolMarker(model, "IsOccupied")
    end

    getHidingTarget = function(obj, name)
        local archiveTarget = getArchiveHidingTarget(obj)
        if archiveTarget then return archiveTarget, "archives" end
        local model = obj:IsA("Model") and obj
            or (obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Model") and obj.Parent)
        if not model then return nil, nil end
        local mName = normalizeName(model.Name)
        if isHidingBlacklisted(mName) then return nil, nil end
        if mName:match("^hidingspot%d*$") then return model, "working" end
        local matches = hidingNames[mName] or hidingNames[name]
        if not matches then
            for _, kw in ipairs(hidingKeywords) do
                if string.find(mName, kw, 1, true) then matches = true; break end
            end
        end
        if not matches then return nil, nil end
        return model, "working"
    end
end

--============================================================
-- ROOM / ENTITY HELPERS
--============================================================

local getRoom, getEntityName, getEntityRoot, findFigureRoot, isRealItem

do
    getRoom = function(obj)
        local cr = workspace:FindFirstChild("CurrentRooms")
        if not cr then return workspace end
        local cur = obj
        while cur and cur ~= workspace do
            if cur.Parent == cr then return cur end
            cur = cur.Parent
        end
        return workspace
    end

    getEntityName = function(obj)
        if not obj:IsA("Model") and not obj:IsA("Tool") then return nil end
        return monsters[normalizeName(obj.Name)]
    end

    getEntityRoot = function(obj)
        if not obj:IsA("Model") and not obj:IsA("Tool") then return nil end
        local ent = getEntityName(obj)
        if not ent then return nil end
        local p = obj.Parent
        if p == workspace then return obj end
        local cr = workspace:FindFirstChild("CurrentRooms")
        if cr and p and p.Parent == cr then return obj end
        local current = obj
        while current and current ~= workspace do
            local parent = current.Parent
            if not parent then break end
            if parent:IsA("Model") or parent:IsA("Tool") then
                local pe = monsters[normalizeName(parent.Name)]
                if pe == ent then current = parent else break end
            else break end
        end
        return current
    end

    findFigureRoot = function(obj)
        local current = obj
        while current and current ~= workspace do
            if current:IsA("Model") or current:IsA("Tool") then
                local n = normalizeName(current.Name)
                if n == "figure" or n == "figuremoving" or n == "figurerig"
                    or n == "figurenew" or n == "figuremodel"
                    or n == "figurebody" or n == "figurehead" then
                    return current
                end
            end
            current = current.Parent
        end
        return nil
    end

    isRealItem = function(obj, name)
        if not items[name] then return false end
        -- These newer pickups may lack the usual Handle/Hitbox/Prompt markers.
        if (name == "peachcobbler" or name == "objectscanner")
            and (obj:IsA("Model") or obj:IsA("Tool")) then
            return true
        end
        if obj:IsA("Tool") then return true end
        if obj:IsA("Model") then
            if obj:FindFirstChildWhichIsA("ProximityPrompt", true) then return true end
            if obj:FindFirstChild("Handle") then return true end
            if obj:FindFirstChild("Hitbox") then return true end
            return false
        end
        if obj:IsA("BasePart") then
            local p = obj.Parent
            if p and (p:IsA("Model") or p:IsA("Tool")) then return false end
            return true
        end
        return false
    end
end

--============================================================
-- ENTITY NAME TAGS
--============================================================

local entityNameTags, removeEntityNameTag, clearAllEntityNameTags, addEntityNameTag

do
    entityNameTags = {}

    removeEntityNameTag = function(target)
        local tag = entityNameTags[target]
        if tag then pcall(function() tag:Destroy() end) end
        entityNameTags[target] = nil
    end

    clearAllEntityNameTags = function()
        for target in pairs(entityNameTags) do removeEntityNameTag(target) end
    end

    addEntityNameTag = function(target, name)
        if State.AllESP == false then return end
        if not State.EntityNameTags then return end
        if not target or not target.Parent then return end
        if entityNameTags[target] then return end
        local part = nil
        if target:IsA("Model") then
            part = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
        elseif target:IsA("BasePart") then part = target end
        if not part then return end
        pcall(function()
            local bb = Instance.new("BillboardGui")
            bb.Name = "EntityNameTag"
            bb.Adornee = part
            bb.Size = UDim2.fromOffset(200, 22)
            bb.StudsOffset = Vector3.new(0, 2.5, 0)
            bb.AlwaysOnTop = true
            bb.MaxDistance = 0
            bb.Parent = part
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.fromScale(1, 1)
            lbl.BackgroundTransparency = 1
            lbl.Text = name
            lbl.TextColor3 = ENTITY_TAG_COLOR
            lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            lbl.TextStrokeTransparency = 0.2
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 16
            lbl.Parent = bb
            entityNameTags[target] = bb
        end)
    end
end

--============================================================
-- TRACERS
--============================================================

local tracers, getTracer, destroyTracer, drawTracer

do
    local tracerGui = Instance.new("ScreenGui")
    tracerGui.Name = "Force_v85_Tracers"
    tracerGui.ResetOnSpawn = false
    tracerGui.IgnoreGuiInset = true
    tracerGui.DisplayOrder = 30
    tracerGui.Parent = playerGui

    local tracerFolder = Instance.new("Folder")
    tracerFolder.Parent = tracerGui

    tracers = {}

    getTracer = function(target, kind)
        if State.AllESP == false then return nil end
        if not target then return nil end

        local entry = tracers[target]
        if entry then
            entry.kind = kind
            return entry.line
        end

        local line = Instance.new("Frame")
        line.Name = "Tracer"
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.BorderSizePixel = 0
        line.ZIndex = 4
        line.Parent = tracerFolder

        tracers[target] = {
            line = line,
            kind = kind,
        }

        return line
    end

    destroyTracer = function(target)
        local entry = tracers[target]
        if not entry then return end

        if entry.line then
            pcall(function()
                entry.line:Destroy()
            end)
        end

        tracers[target] = nil
    end

    local function hideLine(line)
        if line then
            line.Visible = false
        end
    end

    -- Рисуем tracer относительно текущей камеры.
    -- Для цели за спиной экранная проекция зеркалится относительно центра,
    -- поэтому направление не переворачивается при развороте на 180°.
    drawTracer = function(line, pos, color, cam, vp, center)
        if not cam or not line or not line.Parent or not pos then
            hideLine(line)
            return
        end

        if vp.X <= 0 or vp.Y <= 0 then
            hideLine(line)
            return
        end

        local screen = cam:WorldToViewportPoint(pos)
        local target
        local onScreen =
            screen.Z > 0
            and screen.X >= 0 and screen.X <= vp.X
            and screen.Y >= 0 and screen.Y <= vp.Y

        if onScreen then
            target = Vector2.new(screen.X, screen.Y)
        else
            local projected = Vector2.new(screen.X, screen.Y)

            -- Цель за камерой: WorldToViewportPoint даёт зеркальную
            -- экранную проекцию. Отражаем её обратно относительно центра.
            if screen.Z <= 0 then
                local delta = projected - center

                if delta.Magnitude > 0.5 then
                    projected = center - delta
                else
                    -- Полностью за спиной по центру: направляем вниз,
                    -- чтобы линия не исчезала и не прыгала случайно.
                    projected = center + Vector2.new(0, math.max(1, vp.Y * 0.45))
                end
            end

            local deltaToTarget = projected - center

            if deltaToTarget.Magnitude < 0.5 then
                -- Редкий случай: цель почти совпала с центром.
                -- Используем мировое направление как стабильный fallback.
                local worldDir = pos - cam.CFrame.Position
                if worldDir.Magnitude > 0.001 then
                    local localDir = cam.CFrame:VectorToObjectSpace(worldDir.Unit)
                    local fallback = Vector2.new(localDir.X, -localDir.Y)

                    if fallback.Magnitude > 0.001 then
                        deltaToTarget = fallback.Unit
                    else
                        deltaToTarget = Vector2.new(0, 1)
                    end
                else
                    hideLine(line)
                    return
                end
            end

            local maxX = math.max(1, vp.X * 0.5 - 6)
            local maxY = math.max(1, vp.Y * 0.5 - 6)

            local scaleX =
                math.abs(deltaToTarget.X) > 0.0001
                and (maxX / math.abs(deltaToTarget.X))
                or math.huge

            local scaleY =
                math.abs(deltaToTarget.Y) > 0.0001
                and (maxY / math.abs(deltaToTarget.Y))
                or math.huge

            local scale = math.min(scaleX, scaleY)
            target = center + deltaToTarget * scale
        end

        local delta = target - Vector2.new(vp.X * 0.5, vp.Y * 0.5)
        local len = delta.Magnitude

        if len < 1 then
            hideLine(line)
            return
        end

        local origin = center
        local mid = origin + delta * 0.5

        line.Visible = true
        line.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
        line.Position = UDim2.fromOffset(mid.X, mid.Y)
        line.Size = UDim2.fromOffset(math.max(1, len), 1)
        line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    end

    local function canDrawEntry(entry)
        if not entry or not entry.kind then
            return false
        end

        if entry.kind == "Entity" then
            return State.EntityTracers
        elseif entry.kind == "Item" then
            return State.ItemTracers
        elseif entry.kind == "Player" then
            return State.PlayerTracers
        end

        return false
    end

    local function updatePlayerTracers()
        if State.AllESP == false or not State.PlayerTracers then return end

        for _, tp in ipairs(Players:GetPlayers()) do
            if tp ~= player and tp.Character then
                local target =
                    tp.Character:FindFirstChild("HumanoidRootPart")
                    or tp.Character:FindFirstChild("Head")

                if target then
                    getTracer(target, "Player")
                end
            end
        end
    end

    local worldTracerAccumulator = 0

    Runtime:connect(RunService.RenderStepped, function(dt)
        local cam = workspace.CurrentCamera
        if not cam then
            return
        end

        -- Эти значения одинаковы для всех tracer-ов этого кадра.
        -- Не вычисляем их заново для каждого объекта.
        local vp = cam.ViewportSize
        local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)

        local localRoot = getRoot(getChar())
        local rootPos = localRoot and localRoot.Position or nil
        worldTracerAccumulator += dt
        local updateWorld = worldTracerAccumulator >= (1 / 30)
        if updateWorld then worldTracerAccumulator = 0 end

        for target, entry in pairs(tracers) do
            if entry and entry.kind ~= "Player" and not updateWorld then
                continue
            end
            local valid = target and target.Parent

            if not valid or not canDrawEntry(entry) then
                destroyTracer(target)
            else
                local pos = getWorldPos(target)
                local within =
                    entry.kind == "Player"
                    or isWithinDist(pos, rootPos)

                if pos and within then
                    local color =
                        entry.kind == "Player"
                        and PLAYER_TRACER_COLOR
                        or (entry.kind == "Item" and ITEM_COLOR or MONSTER_COLOR)

                    drawTracer(entry.line, pos, color, cam, vp, center)
                else
                    hideLine(entry.line)
                end
            end
        end

        -- Обновляем список player targets только один раз за кадр.
        if State.PlayerTracers then
            updatePlayerTracers()
        end
    end)

    Runtime:spawn(function()
        while Runtime.alive do
            pcall(function()
                local remove = {}

                for target in pairs(tracers) do
                    if not target or not target.Parent then
                        remove[#remove + 1] = target
                    end
                end

                for i = 1, #remove do
                    destroyTracer(remove[i])
                end
            end)

            task.wait(1)
        end
    end)

    _G.__Force_v85_clearTracers = function(kind)
        for target, entry in pairs(tracers) do
            if not kind or entry.kind == kind then
                destroyTracer(target)
            end
        end
    end
end

--============================================================
-- ENTITY NOTIFICATIONS
--============================================================

local alertedEntities, previousCounts
local buildEntityMessage, playAlertSound, processEntityAlerts

do
    alertedEntities = {}
    previousCounts = {}

    buildEntityMessage = function(entities)
        local parts = {}
        for ent, count in pairs(entities) do
            if count > 1 then parts[#parts + 1] = ent .. " x" .. count
            else parts[#parts + 1] = ent end
        end
        table.sort(parts)
        return table.concat(parts, " | ")
    end

    playAlertSound = function()
        if not State.Sound then return end
        pcall(function() alertSound:Stop(); alertSound:Play() end)
    end

    processEntityAlerts = function(counts)
        local toNotify = {}
        for room, ents in pairs(counts) do
            previousCounts[room] = previousCounts[room] or {}
            toNotify[room] = {}
            for ent, c in pairs(ents) do
                local prev = previousCounts[room][ent] or 0
                if c ~= prev and ent ~= "GIGGLE" and ent ~= "SNARE" then
                    toNotify[room][ent] = c
                end
                previousCounts[room][ent] = c
            end
            for ent in pairs(previousCounts[room]) do
                if not ents[ent] then previousCounts[room][ent] = nil end
            end
            if next(previousCounts[room]) == nil then previousCounts[room] = nil end
        end
        for room in pairs(previousCounts) do
            if not counts[room] then previousCounts[room] = nil end
        end
        if not State.Notify then return end
        for room, ents in pairs(toNotify) do
            if next(ents) then
                local msg = buildEntityMessage(ents)
                if msg ~= "" then
                    local trackedTarget = nil
                    local radarEnabled = false
                    local roots = alertedEntities.__entityRoots
                    local roomRoots = roots and roots[room]
                    if roomRoots then
                        for ent in pairs(ents) do
                            local candidate = roomRoots[ent]
                            if candidate and candidate:IsDescendantOf(workspace) then
                                if not trackedTarget then trackedTarget = candidate end
                                if isRadarEntity(ent) then
                                    trackedTarget = candidate
                                    radarEnabled = true
                                    break
                                end
                            end
                        end
                    end
                    showNotification("Entity", msg .. " обнаружен!", MONSTER_COLOR, trackedTarget, radarEnabled)
                    playAlertSound()
                end
            end
        end
    end
end

--============================================================
-- PLAYER ESP / NAMETAGS
--============================================================

local addPlayerESP, clearPlayerESP, nameTagFolder, nameTags
local removeNameTag, addNameTag, refreshNameTags, updateHealthBar

do
    local nameTagHealthConnections = {}

    addPlayerESP = function(tp)
        if State.AllESP == false then return end
        if tp == player then return end
        if not State.PlayerESP then return end
        local c = tp.Character
        if not c then return end
        if c:FindFirstChild("DOORS_PlayerESP") then return end
        pcall(function()
            local h = Instance.new("Highlight")
            h.Name = "DOORS_PlayerESP"
            h.Adornee = c
            h.FillColor = PLAYER_COLOR
            h.FillTransparency = 0.78
            h.OutlineColor = PLAYER_COLOR
            h.OutlineTransparency = 0
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent = c
        end)
    end

    clearPlayerESP = function()
        for _, tp in ipairs(Players:GetPlayers()) do
            pcall(function()
                if tp ~= player and tp.Character then
                    local h = tp.Character:FindFirstChild("DOORS_PlayerESP")
                    if h then h:Destroy() end
                end
            end)
        end
    end

    nameTagFolder = Instance.new("Folder")
    nameTagFolder.Name = "Force_v85_NameTags"
    nameTagFolder.Parent = workspace

    nameTags = {}

    updateHealthBar = function(humanoid, fill)
        if not humanoid or not fill or not fill.Parent then return end
        local pct = 0
        if humanoid.MaxHealth > 0 then pct = humanoid.Health / humanoid.MaxHealth end
        fill.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
        if pct > 0.6 then fill.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
        elseif pct > 0.3 then fill.BackgroundColor3 = Color3.fromRGB(240, 200, 60)
        else fill.BackgroundColor3 = Color3.fromRGB(230, 70, 70) end
    end

    removeNameTag = function(tp)
        local c = nameTagHealthConnections[tp]
        if c then pcall(function() c:Disconnect() end); nameTagHealthConnections[tp] = nil end
        local t = nameTags[tp]
        if t then pcall(function() t:Destroy() end) end
        nameTags[tp] = nil
    end

    addNameTag = function(tp)
        if State.AllESP == false then return end
        if tp == player then return end
        if not State.NameTags then return end
        local c = tp.Character
        if not c then return end
        local head = c:FindFirstChild("Head")
        if not head then return end
        removeNameTag(tp)
        pcall(function()
            local bb = Instance.new("BillboardGui")
            bb.Name = "NameTag_" .. tp.UserId
            bb.Adornee = head
            bb.Size = UDim2.fromOffset(230, 50)
            bb.StudsOffset = Vector3.new(0, 3.15, 0)
            bb.AlwaysOnTop = true
            bb.MaxDistance = 0
            bb.Parent = nameTagFolder

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, 22)
            lbl.BackgroundTransparency = 1
            lbl.Text = tp.DisplayName
            lbl.TextColor3 = NAMETAG_COLOR
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 18
            lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            lbl.TextStrokeTransparency = 0.1
            lbl.TextTruncate = Enum.TextTruncate.AtEnd
            lbl.Parent = bb

            local hpBg = Instance.new("Frame")
            hpBg.Name = "HPBack"
            hpBg.Size = UDim2.new(0.7, 0, 0, 8)
            hpBg.Position = UDim2.new(0.15, 0, 0, 26)
            hpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            hpBg.BackgroundTransparency = 0.2
            hpBg.BorderSizePixel = 0
            hpBg.Visible = State.PlayerHealthBar
            hpBg.Parent = bb

            local hpBgC = Instance.new("UICorner")
            hpBgC.CornerRadius = UDim.new(1, 0)
            hpBgC.Parent = hpBg

            local hpBgS = Instance.new("UIStroke")
            hpBgS.Color = Color3.fromRGB(255, 255, 255)
            hpBgS.Thickness = 1
            hpBgS.Transparency = 0.6
            hpBgS.Parent = hpBg

            local hpFill = Instance.new("Frame")
            hpFill.Name = "HPFill"
            hpFill.Size = UDim2.new(1, 0, 1, 0)
            hpFill.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
            hpFill.BorderSizePixel = 0
            hpFill.Parent = hpBg

            local hpFillC = Instance.new("UICorner")
            hpFillC.CornerRadius = UDim.new(1, 0)
            hpFillC.Parent = hpFill

            local hum = c:FindFirstChildOfClass("Humanoid")
            if hum then
                updateHealthBar(hum, hpFill)
                nameTagHealthConnections[tp] = Runtime:connect(hum.HealthChanged, function()
                    updateHealthBar(hum, hpFill)
                end)
            end
            nameTags[tp] = bb
        end)
    end

    refreshNameTags = function()
        if not State.NameTags then
            for tp in pairs(nameTags) do removeNameTag(tp) end
            return
        end
        for _, tp in ipairs(Players:GetPlayers()) do
            if tp ~= player then addNameTag(tp) end
        end
    end

    Runtime:connect(Players.PlayerAdded, function(tp)
        if tp == player then return end
        Runtime:connect(tp.CharacterAdded, function()
            task.wait(0.5)
            if not Runtime.alive then return end
            addNameTag(tp); addPlayerESP(tp)
        end)
    end)
    Runtime:connect(Players.PlayerRemoving, removeNameTag)

    for _, tp in ipairs(Players:GetPlayers()) do
        if tp ~= player then
            Runtime:connect(tp.CharacterAdded, function()
                task.wait(0.5)
                if not Runtime.alive then return end
                addNameTag(tp); addPlayerESP(tp)
            end)
        end
    end
end

--============================================================
-- TIME
--============================================================

local getTimeText

do
    local function tryParseTime(v)
        if v == nil then return nil end
        if type(v) == "string" then
            local h, m, ap = v:match("(%d+):(%d+)%s*(%a*)")
            if h and m then
                h, m = tonumber(h), tonumber(m)
                ap = (ap or ""):upper()
                if ap == "PM" and h < 12 then h = h + 12 end
                if ap == "AM" and h == 12 then h = 0 end
                return h, m
            end
            local num = tonumber(v)
            if num then v = num else return nil end
        end
        if type(v) ~= "number" then return nil end
        local hours, minutes
        if v >= 0 and v <= 13 then
            local total = v + 12
            hours = math.floor(total) % 24
            minutes = math.floor((total - math.floor(total)) * 60 + 0.5)
        elseif v > 13 and v <= 1440 then
            hours = math.floor(v / 60) % 24
            minutes = math.floor(v) % 60
        elseif v > 1440 and v <= 86400 * 2 then
            hours = math.floor(v / 3600) % 24
            minutes = math.floor(v / 60) % 60
        else
            hours = math.floor(v / 3600) % 24
            minutes = math.floor(v / 60) % 60
        end
        if hours == nil then return nil end
        return hours, minutes
    end

    local function fmt12h(h, m)
        if h == nil then return "--:--" end
        h = h % 24
        local ap = h >= 12 and "PM" or "AM"
        local h12 = h % 12
        if h12 == 0 then h12 = 12 end
        return string.format("%02d:%02d %s", h12, m, ap)
    end

    getTimeText = function()
        local gd = RS:FindFirstChild("GameData")
        if not gd then return "--:--" end
        for _, name in ipairs({ "ArchivesClockTime", "Clock", "ArchivesClockObservation" }) do
            local obj = gd:FindFirstChild(name)
            if obj and obj:IsA("ValueBase") then
                local h, m = tryParseTime(obj.Value)
                if h then return fmt12h(h, m) end
            end
        end
        return "--:--"
    end
end

--============================================================
-- OVERLAY
--============================================================

local overlay

do
    local overlayGui = Instance.new("ScreenGui")
    overlayGui.Name = "Force_v85_Overlay"
    overlayGui.ResetOnSpawn = false
    overlayGui.DisplayOrder = 20
    overlayGui.IgnoreGuiInset = true
    overlayGui.Parent = playerGui

    overlay = Instance.new("Frame")
    overlay.Size = UDim2.fromOffset(400, 110)
    overlay.Position = UDim2.fromOffset(24, 60)
    overlay.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    overlay.BackgroundTransparency = 0.15
    overlay.BorderSizePixel = 0
    overlay.ClipsDescendants = true
    overlay.Visible = State.Overlay
    overlay.Parent = overlayGui

    local ocn = Instance.new("UICorner")
    ocn.CornerRadius = UDim.new(0, 10)
    ocn.Parent = overlay

    local ostr = Instance.new("UIStroke")
    ostr.Color = Color3.fromRGB(255, 255, 255)
    ostr.Thickness = 1
    ostr.Transparency = 0.92
    ostr.Parent = overlay

    local overlayHeader = Instance.new("TextButton")
    overlayHeader.Name = "HeaderBar"
    overlayHeader.Size = UDim2.new(1, 0, 0, 36)
    overlayHeader.BackgroundTransparency = 1
    overlayHeader.BorderSizePixel = 0
    overlayHeader.Text = ""
    overlayHeader.AutoButtonColor = false
    overlayHeader.Parent = overlay

    local oTitle = Instance.new("TextLabel")
    oTitle.Size = UDim2.new(0.6, 0, 1, 0)
    oTitle.Position = UDim2.fromOffset(18, 0)
    oTitle.BackgroundTransparency = 1
    oTitle.Text = "DOORS // INFO"
    oTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    oTitle.Font = Enum.Font.GothamBold
    oTitle.TextSize = 12
    oTitle.TextXAlignment = Enum.TextXAlignment.Left
    oTitle.Parent = overlayHeader

    local oStatus = Instance.new("TextLabel")
    oStatus.Size = UDim2.new(0.3, 0, 1, 0)
    oStatus.Position = UDim2.new(1, -18, 0, 0)
    oStatus.AnchorPoint = Vector2.new(1, 0)
    oStatus.BackgroundTransparency = 1
    oStatus.Text = "● ONLINE"
    oStatus.TextColor3 = Color3.fromRGB(90, 220, 130)
    oStatus.Font = Enum.Font.GothamBold
    oStatus.TextSize = 10
    oStatus.TextXAlignment = Enum.TextXAlignment.Right
    oStatus.Parent = overlayHeader

    local function makeTile(index, title, color)
        local tile = Instance.new("Frame")
        tile.Size = UDim2.new(0.25, 0, 0, 60)
        tile.Position = UDim2.new((index - 1) * 0.25, 0, 0, 42)
        tile.BackgroundTransparency = 1
        tile.BorderSizePixel = 0
        tile.Parent = overlay

        if index > 1 then
            local sep = Instance.new("Frame")
            sep.Size = UDim2.new(0, 1, 0, 32)
            sep.Position = UDim2.new(0, 0, 0.5, 0)
            sep.AnchorPoint = Vector2.new(0, 0.5)
            sep.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            sep.BackgroundTransparency = 0.85
            sep.BorderSizePixel = 0
            sep.Parent = tile
        end

        local accent = Instance.new("Frame")
        accent.Size = UDim2.new(0, 3, 0, 18)
        accent.Position = UDim2.new(0, 12, 0, 6)
        accent.BackgroundColor3 = color
        accent.BorderSizePixel = 0
        accent.Parent = tile

        local ac = Instance.new("UICorner")
        ac.CornerRadius = UDim.new(1, 0)
        ac.Parent = accent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.6, 0, 0, 14)
        lbl.Position = UDim2.new(0, 22, 0, 6)
        lbl.BackgroundTransparency = 1
        lbl.Text = string.upper(title)
        lbl.TextColor3 = Color3.fromRGB(140, 140, 140)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = tile

        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(1, 0, 0, 26)
        val.Position = UDim2.new(0, 0, 0, 24)
        val.BackgroundTransparency = 1
        val.Text = "--"
        val.TextColor3 = Color3.fromRGB(255, 255, 255)
        val.Font = Enum.Font.GothamBold
        val.TextSize = 17
        val.TextXAlignment = Enum.TextXAlignment.Center
        val.TextTruncate = Enum.TextTruncate.AtEnd
        val.Parent = tile
        return val
    end

    local overlayFPS  = makeTile(1, "FPS",  Color3.fromRGB(90, 220, 130))
    local overlayPing = makeTile(2, "PING", Color3.fromRGB(255, 200, 80))
    local overlayRoom = makeTile(3, "ROOM", Color3.fromRGB(120, 200, 255))
    local overlayTime = makeTile(4, "TIME", Color3.fromRGB(255, 160, 200))

    local fpsFrames = 0
    local fpsStart = os.clock()
    local currentFPS = 60

    Runtime:connect(RunService.RenderStepped, function()
        fpsFrames = fpsFrames + 1
        local now = os.clock()
        if now - fpsStart >= 1.0 then
            currentFPS = math.floor(fpsFrames / (now - fpsStart) + 0.5)
            fpsFrames = 0
            fpsStart = now
        end
    end)

    local function getPing()
        local r = 0
        pcall(function()
            local i = Stats.Network.ServerStatsItem
            local p = i:FindFirstChild("Data Ping")
            if p then r = math.floor(p:GetValue()) end
        end)
        return r
    end

    local roomCache = {}
    local roomCacheTime = 0

    local function getRoomNumber()
        local gameData = RS:FindFirstChild("GameData")
        local latest = gameData and gameData:FindFirstChild("LatestRoom")
        if latest and latest.Value ~= nil then
            return tostring(latest.Value)
        end

        -- Fallback только если GameData/LatestRoom недоступен.
        local root = getRoot(getChar())
        if not root then return "--" end
        local now = os.clock()
        if now - roomCacheTime > 10 then
            roomCacheTime = now
            table.clear(roomCache)
            local cr = workspace:FindFirstChild("CurrentRooms")
            if cr then
                for _, room in ipairs(cr:GetChildren()) do
                    if room:IsA("Model") or room:IsA("Folder") then
                        local pos = room.PrimaryPart and room.PrimaryPart.Position
                        if not pos then
                            local ok, pivot = pcall(function() return room:GetPivot() end)
                            if ok and pivot then pos = pivot.Position end
                        end
                        local number = room.Name:match("%-?%d+")
                        if pos and number then roomCache[room] = {pos = pos, number = number} end
                    end
                end
            end
        end
        local best, bd = nil, math.huge
        for room, data in pairs(roomCache) do
            if room and room.Parent then
                local d = (root.Position - data.pos).Magnitude
                if d < bd then bd = d; best = data.number end
            else
                roomCache[room] = nil
            end
        end
        return best and tostring(best) or "--"
    end

    Runtime:spawn(function()
        while Runtime.alive do
            pcall(function()
                overlay.Visible = State.Overlay
                if State.Overlay then
                    overlayFPS.Text  = tostring(currentFPS)
                    overlayPing.Text = tostring(getPing())
                    overlayRoom.Text = tostring(getRoomNumber())
                    overlayTime.Text = getTimeText()
                end
            end)
            task.wait(SCAN_OVERLAY_DELAY)
        end
    end)

    local overlayDragging = false
    local overlayStart, overlayStartPos

    Runtime:connect(overlayHeader.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            overlayDragging = true
            overlayStart = input.Position
            overlayStartPos = overlay.Position
        end
    end)
    Runtime:connect(overlayHeader.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            overlayDragging = false
        end
    end)

    Runtime:connect(UserInputService.InputChanged, function(input)
        if not overlayDragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - overlayStart
            overlay.Position = UDim2.new(
                overlayStartPos.X.Scale, overlayStartPos.X.Offset + d.X,
                overlayStartPos.Y.Scale, overlayStartPos.Y.Offset + d.Y
            )
        end
    end)
end

--============================================================
-- FREECAM
--============================================================

local freecamSetEnabled
local cameraModule
local playerControls
local menuOpen = false

do
    local freecam = { enabled = false, speed = 80, pos = nil, rot = nil }
    local freecamInput = { W=false, A=false, S=false, D=false, Space=false, Ctrl=false, Shift=false }
    local freecamRMB = false

    freecamSetEnabled = function(on)
        if on == freecam.enabled then return end
        freecam.enabled = on
        State.Freecam = on
        local cam = workspace.CurrentCamera
        if not cam then return end
        if on then
            freecam.pos = cam.CFrame.Position
            local rx, ry = cam.CFrame:ToEulerAnglesYXZ()
            freecam.rot = Vector2.new(ry, rx)
            pcall(function() if cameraModule then cameraModule:Disable() end end)
            cam.CameraType = Enum.CameraType.Scriptable
            cam.CFrame = CFrame.new(freecam.pos)
                * CFrame.Angles(0, freecam.rot.X, 0)
                * CFrame.Angles(freecam.rot.Y, 0, 0)
        else
            cam.CameraType = Enum.CameraType.Custom
            pcall(function()
                if cameraModule and not menuOpen then cameraModule:Enable() end
            end)
        end
        if State.Notify then
            showNotification("Freecam", on and "Enabled" or "Disabled",
                on and Color3.fromRGB(120, 220, 255) or Color3.fromRGB(160, 160, 160))
        end
    end

    Runtime:connect(UserInputService.InputBegan, function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.F4 then
            freecamSetEnabled(not freecam.enabled)
            return
        end
        if not freecam.enabled then return end
        if input.KeyCode == Enum.KeyCode.W then freecamInput.W = true end
        if input.KeyCode == Enum.KeyCode.A then freecamInput.A = true end
        if input.KeyCode == Enum.KeyCode.S then freecamInput.S = true end
        if input.KeyCode == Enum.KeyCode.D then freecamInput.D = true end
        if input.KeyCode == Enum.KeyCode.Space then freecamInput.Space = true end
        if input.KeyCode == Enum.KeyCode.LeftControl
            or input.KeyCode == Enum.KeyCode.RightControl then freecamInput.Ctrl = true end
        if input.KeyCode == Enum.KeyCode.LeftShift
            or input.KeyCode == Enum.KeyCode.RightShift then freecamInput.Shift = true end
    end)

    Runtime:connect(UserInputService.InputEnded, function(input)
        if input.KeyCode == Enum.KeyCode.W then freecamInput.W = false end
        if input.KeyCode == Enum.KeyCode.A then freecamInput.A = false end
        if input.KeyCode == Enum.KeyCode.S then freecamInput.S = false end
        if input.KeyCode == Enum.KeyCode.D then freecamInput.D = false end
        if input.KeyCode == Enum.KeyCode.Space then freecamInput.Space = false end
        if input.KeyCode == Enum.KeyCode.LeftControl
            or input.KeyCode == Enum.KeyCode.RightControl then freecamInput.Ctrl = false end
        if input.KeyCode == Enum.KeyCode.LeftShift
            or input.KeyCode == Enum.KeyCode.RightShift then freecamInput.Shift = false end
    end)

    Runtime:connect(UserInputService.InputBegan, function(input, gp)
        if gp then return end
        if not freecam.enabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            freecamRMB = true
            pcall(function()
                UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                UserInputService.MouseIconEnabled = false
            end)
        end
    end)

    Runtime:connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            freecamRMB = false
            if freecam.enabled and not menuOpen then
                pcall(function()
                    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                    UserInputService.MouseIconEnabled = true
                end)
            end
        end
    end)

    Runtime:connect(UserInputService.InputChanged, function(input)
        if not freecam.enabled then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement and freecamRMB then
            local delta = input.Delta
            freecam.rot = Vector2.new(
                freecam.rot.X + delta.X * 0.003,
                math.clamp(freecam.rot.Y + delta.Y * 0.003, -math.rad(89), math.rad(89))
            )
        end
    end)

    Runtime:connect(RunService.RenderStepped, function(dt)
        if not freecam.enabled then return end
        local cam = workspace.CurrentCamera
        if not cam or not freecam.pos or not freecam.rot then return end
        local speed = freecam.speed
        if freecamInput.Shift then speed = speed * 3 end
        if freecamInput.Ctrl then speed = speed * 0.3 end
        local move = Vector3.new(0, 0, 0)
        if freecamInput.W then move = move + Vector3.new(0, 0, -1) end
        if freecamInput.S then move = move + Vector3.new(0, 0, 1) end
        if freecamInput.D then move = move + Vector3.new(1, 0, 0) end
        if freecamInput.A then move = move + Vector3.new(-1, 0, 0) end
        if freecamInput.Space then move = move + Vector3.new(0, 1, 0) end
        if freecamInput.Ctrl then move = move + Vector3.new(0, -1, 0) end
        if move.Magnitude > 0 then move = move.Unit end
        local cf = CFrame.new(freecam.pos)
            * CFrame.Angles(0, freecam.rot.X, 0)
            * CFrame.Angles(freecam.rot.Y, 0, 0)
        freecam.pos = freecam.pos + cf:VectorToWorldSpace(move) * speed * dt
        cam.CFrame = CFrame.new(freecam.pos)
            * CFrame.Angles(0, freecam.rot.X, 0)
            * CFrame.Angles(freecam.rot.Y, 0, 0)
    end)
end

local MenuUI
--============================================================
-- MENU (TAB UI)
--============================================================

do
    local UI = {}
    local MENU_W, MENU_H = 900, 600
    local HEADER_H = 60
    local TABS_H = 40
    local CONTENT_Y = HEADER_H + TABS_H + 8
    local SIDE_PAD = 48
    local OPEN_KEY = Enum.KeyCode.RightShift
    local TAB_COUNT = 5
    local ROW_GAP = 12
    local TOGGLE_H = 42
    local SLIDER_H = 54
    local C_BG = Color3.fromRGB(15, 15, 15)
    local C_WHITE = Color3.fromRGB(255, 255, 255)
    local C_TEXT = Color3.fromRGB(215, 215, 225)
    local C_SECONDARY = Color3.fromRGB(140, 140, 140)
    local T_OPEN = TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    local T_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local oldGui = playerGui:FindFirstChild('TabsMenu')
    if oldGui then pcall(function() oldGui:Destroy() end) end

    local gui = Instance.new('ScreenGui')
    gui.Name = 'TabsMenu'
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 90
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui

    local window = Instance.new('CanvasGroup')
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.new(0.5, 0, 0.5, 0)
    window.Size = UDim2.fromOffset(MENU_W, MENU_H)
    window.BackgroundColor3 = C_BG
    window.BackgroundTransparency = 0.12
    window.BorderSizePixel = 0
    window.GroupTransparency = 1
    window.Visible = false
    window.ClipsDescendants = true
    window.Parent = gui

    local windowCorner = Instance.new('UICorner')
    windowCorner.CornerRadius = UDim.new(0, 16)
    windowCorner.Parent = window

    local windowStroke = Instance.new('UIStroke')
    windowStroke.Thickness = 1
    windowStroke.Color = C_WHITE
    windowStroke.Transparency = 0.9
    windowStroke.Parent = window

    local windowScale = Instance.new('UIScale')
    windowScale.Scale = 0.96
    windowScale.Parent = window

    local headerBar = Instance.new('Frame')
    headerBar.Size = UDim2.new(1, 0, 0, HEADER_H)
    headerBar.BackgroundTransparency = 1
    headerBar.BorderSizePixel = 0
    headerBar.Parent = window

    local titleLabel = Instance.new('TextLabel')
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 24
    titleLabel.TextColor3 = C_WHITE
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = 'Force'
    titleLabel.Position = UDim2.new(0, SIDE_PAD, 0, 0)
    titleLabel.Size = UDim2.new(1, -SIDE_PAD * 2 - 80, 0, 38)
    titleLabel.Parent = headerBar

    local subtitleLabel = Instance.new('TextLabel')
    subtitleLabel.BackgroundTransparency = 1
    subtitleLabel.Font = Enum.Font.Gotham
    subtitleLabel.TextSize = 12
    subtitleLabel.TextColor3 = C_SECONDARY
    subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    subtitleLabel.Text = 'ESP • players • bypass • movement • visual'
    subtitleLabel.Position = UDim2.new(0, SIDE_PAD, 0, 38)
    subtitleLabel.Size = UDim2.new(1, -SIDE_PAD * 2 - 80, 0, 16)
    subtitleLabel.Parent = headerBar

    local closeBtn = Instance.new('TextButton')
    closeBtn.AnchorPoint = Vector2.new(1, 0.5)
    closeBtn.Position = UDim2.new(1, -SIDE_PAD, 0.5, 0)
    closeBtn.Size = UDim2.fromOffset(32, 32)
    closeBtn.BackgroundTransparency = 1
    closeBtn.AutoButtonColor = false
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 22
    closeBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
    closeBtn.Text = 'X'
    closeBtn.Parent = headerBar

    Runtime:connect(closeBtn.MouseEnter, function()
        TweenService:Create(closeBtn, T_FAST, {TextColor3 = C_WHITE}):Play()
    end)
    Runtime:connect(closeBtn.MouseLeave, function()
        TweenService:Create(closeBtn, T_FAST, {TextColor3 = Color3.fromRGB(160, 160, 160)}):Play()
    end)

    local tabBar = Instance.new('Frame')
    tabBar.Position = UDim2.new(0, SIDE_PAD, 0, HEADER_H)
    tabBar.Size = UDim2.new(1, -SIDE_PAD * 2, 0, TABS_H)
    tabBar.BackgroundTransparency = 1
    tabBar.BorderSizePixel = 0
    tabBar.Parent = window

    local tabDivider = Instance.new('Frame')
    tabDivider.Position = UDim2.new(0, SIDE_PAD, 0, HEADER_H + TABS_H)
    tabDivider.Size = UDim2.new(1, -SIDE_PAD * 2, 0, 1)
    tabDivider.BackgroundColor3 = C_WHITE
    tabDivider.BackgroundTransparency = 0.85
    tabDivider.BorderSizePixel = 0
    tabDivider.Parent = window

    local indicator = Instance.new('Frame')
    indicator.Position = UDim2.new(0, 10, 1, -2)
    indicator.Size = UDim2.new(1 / TAB_COUNT, -20, 0, 2)
    indicator.BackgroundColor3 = C_WHITE
    indicator.BorderSizePixel = 0
    indicator.ZIndex = 3
    indicator.Parent = tabBar
    local indicatorCorner = Instance.new('UICorner')
    indicatorCorner.CornerRadius = UDim.new(1, 0)
    indicatorCorner.Parent = indicator

    local tabs = {}
    local pages = {}
    local currentTab = 0

    local pageNames = {'ESP', 'Players', 'Bypass', 'Movement', 'Visual'}
    local pageDesc = {
        'Objects and entities in the current rooms',
        'Player ESP, names and tracers',
        'Protection, bypasses and item helpers',
        'Speed and movement controls',
        'Visual settings, distance and alerts',
    }

    local function addCorner(obj, radius)
        local c = Instance.new('UICorner')
        c.CornerRadius = UDim.new(0, radius)
        c.Parent = obj
        return c
    end

    local function addSectionHeader(parent, title, desc, order)
        local box = Instance.new('Frame')
        box.Size = UDim2.new(1, 0, 0, 28)
        box.BackgroundTransparency = 1
        box.LayoutOrder = order
        box.Parent = parent

        local d = Instance.new('TextLabel')
        d.BackgroundTransparency = 1
        d.Font = Enum.Font.Gotham
        d.TextSize = 13
        d.TextColor3 = C_SECONDARY
        d.TextXAlignment = Enum.TextXAlignment.Left
        d.Text = desc
        d.Position = UDim2.new(0, 0, 0, 2)
        d.Size = UDim2.new(1, 0, 0, 22)
        d.TextWrapped = true
        d.Parent = box
    end

    local function makePage(index)
        local page = Instance.new('Frame')
        page.Name = 'Page' .. index
        page.Position = UDim2.new(0, 0, 0, CONTENT_Y)
        page.Size = UDim2.new(1, 0, 1, -CONTENT_Y)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.Visible = false
        page.Parent = window

        local scroll = Instance.new('ScrollingFrame')
        scroll.Name = 'Content'
        scroll.Position = UDim2.new(0, 0, 0, 0)
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = C_WHITE
        scroll.ScrollBarImageTransparency = 0.5
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.Parent = page

        local pad = Instance.new('UIPadding')
        pad.PaddingTop = UDim.new(0, 8)
        pad.PaddingBottom = UDim.new(0, 36)
        pad.PaddingLeft = UDim.new(0, SIDE_PAD)
        pad.PaddingRight = UDim.new(0, SIDE_PAD)
        pad.Parent = scroll

        local list = Instance.new('UIListLayout')
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Padding = UDim.new(0, ROW_GAP)
        list.Parent = scroll

        pages[index] = {frame = page, scroll = scroll, order = 0}
        return pages[index]
    end

    local function createTab(index, name)
        local button = Instance.new('TextButton')
        button.Position = UDim2.new((index - 1) / TAB_COUNT, 0, 0, 0)
        button.Size = UDim2.new(1 / TAB_COUNT, 0, 1, 0)
        button.BackgroundTransparency = 1
        button.BorderSizePixel = 0
        button.AutoButtonColor = false
        button.Font = Enum.Font.GothamBold
        button.TextSize = 13
        button.TextColor3 = C_SECONDARY
        button.Text = name
        button.Parent = tabBar

        tabs[index] = {button = button}

        Runtime:connect(button.MouseEnter, function()
            if currentTab ~= index then
                TweenService:Create(button, T_FAST, {TextColor3 = C_TEXT}):Play()
            end
        end)
        Runtime:connect(button.MouseLeave, function()
            if currentTab ~= index then
                TweenService:Create(button, T_FAST, {TextColor3 = C_SECONDARY}):Play()
            end
        end)
        Runtime:connect(button.MouseButton1Click, function()
            if currentTab == index then return end
            local old = tabs[currentTab]
            if old then
                pages[currentTab].frame.Visible = false
                TweenService:Create(old.button, T_FAST, {TextColor3 = C_SECONDARY}):Play()
            end
            currentTab = index
            pages[index].frame.Visible = true
            TweenService:Create(button, T_FAST, {TextColor3 = C_WHITE}):Play()
            TweenService:Create(indicator, T_OPEN, {
                Position = UDim2.new((index - 1) / TAB_COUNT, 10, 1, -2),
            }):Play()
        end)
    end

    for i = 1, TAB_COUNT do
        makePage(i)
        createTab(i, pageNames[i])
        addSectionHeader(pages[i].scroll, pageNames[i], pageDesc[i], 1)
    end

    function UI.currentPage(index)
        return pages[index]
    end

    function UI.nextOrder(index)
        local pd = pages[index]
        pd.order += 1
        return pd.order
    end

    function UI.text(index, txt, bold, size, color)
        local pd = pages[index]
        local lbl = Instance.new('TextLabel')
        lbl.Size = UDim2.new(1, 0, 0, 0)
        lbl.AutomaticSize = Enum.AutomaticSize.Y
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = color or C_TEXT
        lbl.TextSize = size or 14
        lbl.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextWrapped = true
        lbl.Text = txt
        lbl.LayoutOrder = UI.nextOrder(index)
        lbl.Parent = pd.scroll
        return lbl
    end

    function UI.toggle(index, txt, key, onChange)
        local pd = pages[index]
        local row = Instance.new('TextButton')
        row.Size = UDim2.new(1, 0, 0, TOGGLE_H)
        row.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
        row.BackgroundTransparency = 0.18
        row.BorderSizePixel = 0
        row.AutoButtonColor = false
        row.Text = ''
        row.LayoutOrder = UI.nextOrder(index)
        row.Parent = pd.scroll
        addCorner(row, 8)

        local rs = Instance.new('UIStroke')
        rs.Thickness = 1
        rs.Color = C_WHITE
        rs.Transparency = 0.94
        rs.Parent = row

        local l = Instance.new('TextLabel')
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.Gotham
        l.TextSize = 15
        l.TextColor3 = C_TEXT
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = txt
        l.Position = UDim2.new(0, 14, 0, 0)
        l.Size = UDim2.new(1, -86, 1, 0)
        l.Parent = row

        local s = Instance.new('Frame')
        s.Size = UDim2.fromOffset(52, 28)
        s.Position = UDim2.new(1, -14, 0.5, 0)
        s.AnchorPoint = Vector2.new(1, 0.5)
        s.BackgroundColor3 = State[key] and Color3.fromRGB(240, 240, 240) or Color3.fromRGB(40, 40, 40)
        s.BorderSizePixel = 0
        s.Parent = row
        addCorner(s, 14)

        local knob = Instance.new('Frame')
        knob.Size = UDim2.fromOffset(20, 20)
        knob.Position = State[key] and UDim2.new(1, -24, 0.5, 0) or UDim2.new(0, 4, 0.5, 0)
        knob.AnchorPoint = Vector2.new(0, 0.5)
        knob.BackgroundColor3 = State[key] and Color3.fromRGB(20, 20, 20) or C_WHITE
        knob.BorderSizePixel = 0
        knob.Parent = s
        addCorner(knob, 10)

        local function updateHover(on)
            TweenService:Create(row, T_FAST, {
                BackgroundTransparency = on and 0.06 or 0.18
            }):Play()
        end

        Runtime:connect(row.MouseEnter, function() updateHover(true) end)
        Runtime:connect(row.MouseLeave, function() updateHover(false) end)
        Runtime:connect(row.MouseButton1Click, function()
            State[key] = not State[key]
            local on = State[key]
            TweenService:Create(knob, T_FAST, {
                Position = on and UDim2.new(1, -24, 0.5, 0) or UDim2.new(0, 4, 0.5, 0),
                BackgroundColor3 = on and Color3.fromRGB(20, 20, 20) or C_WHITE,
            }):Play()
            TweenService:Create(s, T_FAST, {
                BackgroundColor3 = on and Color3.fromRGB(240, 240, 240) or Color3.fromRGB(40, 40, 40),
            }):Play()
            if onChange then onChange(on) end
        end)
        return row
    end

    function UI.slider(index, txt, min, max, default, onChange)
        min = min or 0
        max = max or 500
        default = default or min
        local pd = pages[index]
        local row = Instance.new('Frame')
        row.Size = UDim2.new(1, 0, 0, SLIDER_H)
        row.BackgroundTransparency = 1
        row.LayoutOrder = UI.nextOrder(index)
        row.Parent = pd.scroll

        local l = Instance.new('TextLabel')
        l.Size = UDim2.new(1, 0, 0, 18)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.Gotham
        l.TextSize = 14
        l.TextColor3 = C_TEXT
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = txt .. ': ' .. tostring(default)
        l.Parent = row

        local t = Instance.new('TextButton')
        t.Size = UDim2.new(1, 0, 0, 20)
        t.Position = UDim2.new(0, 0, 1, -20)
        t.BackgroundTransparency = 1
        t.Text = ''
        t.Parent = row

        local track = Instance.new('Frame')
        track.Size = UDim2.new(1, 0, 0, 8)
        track.Position = UDim2.new(0, 0, 0.5, 0)
        track.AnchorPoint = Vector2.new(0, 0.5)
        track.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        track.BorderSizePixel = 0
        track.Parent = t
        addCorner(track, 4)

        local score = math.clamp((default - min) / math.max(1, (max - min)), 0, 1)
        local fill = Instance.new('Frame')
        fill.Size = UDim2.new(score, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
        fill.BorderSizePixel = 0
        fill.Parent = track
        addCorner(fill, 4)

        local knob = Instance.new('Frame')
        knob.Size = UDim2.fromOffset(20, 20)
        knob.Position = UDim2.new(score, 0, 0.5, 0)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.BackgroundColor3 = C_WHITE
        knob.BorderSizePixel = 0
        knob.Parent = track
        addCorner(knob, 10)

        local dragging = false
        local function applyValue(value)
            value = math.clamp(math.floor(value + 0.5), min, max)
            local sc = math.clamp((value - min) / math.max(1, (max - min)), 0, 1)
            l.Text = txt .. ': ' .. tostring(value)
            TweenService:Create(fill, T_FAST, {Size = UDim2.new(sc, 0, 1, 0)}):Play()
            TweenService:Create(knob, T_FAST, {Position = UDim2.new(sc, 0, 0.5, 0)}):Play()
            if onChange then onChange(value) end
        end
        local function update(input)
            local sc = math.clamp((input.Position.X - t.AbsolutePosition.X) / math.max(1, t.AbsoluteSize.X), 0, 1)
            applyValue(min + (max - min) * sc)
        end

        Runtime:connect(t.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                update(input)
            end
        end)
        Runtime:connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        Runtime:connect(UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                update(input)
            end
        end)
    end

    function UI.sliderWithInput(index, txt, min, max, default, onChange)
        min = min or 0
        max = max or 500
        default = default or min
        local pd = pages[index]
        local row = Instance.new('Frame')
        row.Size = UDim2.new(1, 0, 0, SLIDER_H)
        row.BackgroundTransparency = 1
        row.LayoutOrder = UI.nextOrder(index)
        row.Parent = pd.scroll

        local l = Instance.new('TextLabel')
        l.Size = UDim2.new(0.6, 0, 0, 18)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.Gotham
        l.TextSize = 14
        l.TextColor3 = C_TEXT
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = txt
        l.Parent = row

        local inputBox = Instance.new('TextBox')
        inputBox.Size = UDim2.fromOffset(70, 22)
        inputBox.Position = UDim2.new(1, -70, 0, -2)
        inputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
        inputBox.BackgroundTransparency = 0.15
        inputBox.BorderSizePixel = 0
        inputBox.Text = tostring(default)
        inputBox.TextColor3 = Color3.fromRGB(240, 240, 245)
        inputBox.Font = Enum.Font.GothamBold
        inputBox.TextSize = 13
        inputBox.ClearTextOnFocus = false
        inputBox.Parent = row
        addCorner(inputBox, 6)
        local inputStroke = Instance.new('UIStroke')
        inputStroke.Thickness = 1
        inputStroke.Color = Color3.fromRGB(90, 90, 110)
        inputStroke.Transparency = 0.4
        inputStroke.Parent = inputBox

        local t = Instance.new('TextButton')
        t.Size = UDim2.new(1, 0, 0, 20)
        t.Position = UDim2.new(0, 0, 1, -20)
        t.BackgroundTransparency = 1
        t.Text = ''
        t.Parent = row

        local track = Instance.new('Frame')
        track.Size = UDim2.new(1, 0, 0, 8)
        track.Position = UDim2.new(0, 0, 0.5, 0)
        track.AnchorPoint = Vector2.new(0, 0.5)
        track.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        track.BorderSizePixel = 0
        track.Parent = t
        addCorner(track, 4)

        local score = math.clamp((default - min) / math.max(1, (max - min)), 0, 1)
        local fill = Instance.new('Frame')
        fill.Size = UDim2.new(score, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
        fill.BorderSizePixel = 0
        fill.Parent = track
        addCorner(fill, 4)

        local knob = Instance.new('Frame')
        knob.Size = UDim2.fromOffset(20, 20)
        knob.Position = UDim2.new(score, 0, 0.5, 0)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.BackgroundColor3 = C_WHITE
        knob.BorderSizePixel = 0
        knob.Parent = track
        addCorner(knob, 10)

        local dragging = false
        local lastValue = default
        local function applyValue(value)
            value = math.clamp(math.floor(value + 0.5), min, max)
            lastValue = value
            local sc = math.clamp((value - min) / math.max(1, (max - min)), 0, 1)
            TweenService:Create(fill, T_FAST, {Size = UDim2.new(sc, 0, 1, 0)}):Play()
            TweenService:Create(knob, T_FAST, {Position = UDim2.new(sc, 0, 0.5, 0)}):Play()
            inputBox.Text = tostring(value)
            if onChange then onChange(value) end
        end
        local function update(input)
            local sc = math.clamp((input.Position.X - t.AbsolutePosition.X) / math.max(1, t.AbsoluteSize.X), 0, 1)
            applyValue(min + (max - min) * sc)
        end

        Runtime:connect(t.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                update(input)
            end
        end)
        Runtime:connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        Runtime:connect(UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                update(input)
            end
        end)
        Runtime:connect(inputBox.FocusLost, function()
            local num = tonumber(inputBox.Text)
            if num then applyValue(num) else inputBox.Text = tostring(lastValue) end
        end)
    end

    function UI.warnBadge(index, txt)
        local pd = pages[index]
        local outer = Instance.new('Frame')
        outer.Size = UDim2.new(1, 0, 0, 0)
        outer.AutomaticSize = Enum.AutomaticSize.Y
        outer.BackgroundTransparency = 1
        outer.LayoutOrder = UI.nextOrder(index)
        outer.Parent = pd.scroll

        local inner = Instance.new('Frame')
        inner.Size = UDim2.new(1, 0, 0, 0)
        inner.AutomaticSize = Enum.AutomaticSize.Y
        inner.BackgroundColor3 = Color3.fromRGB(28, 22, 14)
        inner.BackgroundTransparency = 0.1
        inner.BorderSizePixel = 0
        inner.Parent = outer
        addCorner(inner, 8)
        local st = Instance.new('UIStroke')
        st.Thickness = 1
        st.Color = Color3.fromRGB(200, 140, 40)
        st.Transparency = 0.4
        st.Parent = inner
        local ip = Instance.new('UIPadding')
        ip.PaddingTop = UDim.new(0, 8)
        ip.PaddingBottom = UDim.new(0, 8)
        ip.PaddingLeft = UDim.new(0, 12)
        ip.PaddingRight = UDim.new(0, 12)
        ip.Parent = inner

        local row = Instance.new('Frame')
        row.Size = UDim2.new(1, 0, 0, 0)
        row.AutomaticSize = Enum.AutomaticSize.Y
        row.BackgroundTransparency = 1
        row.Parent = inner

        local badge = Instance.new('Frame')
        badge.Size = UDim2.fromOffset(52, 22)
        badge.BackgroundColor3 = Color3.fromRGB(45, 30, 15)
        badge.BorderSizePixel = 0
        badge.Parent = row
        addCorner(badge, 6)
        local bs = Instance.new('UIStroke')
        bs.Thickness = 1
        bs.Color = Color3.fromRGB(200, 140, 40)
        bs.Transparency = 0.3
        bs.Parent = badge
        local bt = Instance.new('TextLabel')
        bt.Size = UDim2.new(1, 0, 1, -2)
        bt.BackgroundTransparency = 1
        bt.TextColor3 = Color3.fromRGB(235, 165, 50)
        bt.TextSize = 12
        bt.Font = Enum.Font.GothamBold
        bt.Text = 'WARN'
        bt.Parent = badge

        local lbl = Instance.new('TextLabel')
        lbl.Size = UDim2.new(1, -64, 0, 0)
        lbl.Position = UDim2.new(0, 64, 0, 0)
        lbl.AutomaticSize = Enum.AutomaticSize.Y
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(215, 200, 180)
        lbl.TextSize = 13
        lbl.Font = Enum.Font.Gotham
        lbl.Text = txt
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextWrapped = true
        lbl.Parent = row
        return outer
    end

    function UI.actionButton(index, txt, callback)
        local pd = pages[index]
        local b = Instance.new('TextButton')
        b.Size = UDim2.new(1, 0, 0, 42)
        b.BackgroundColor3 = Color3.fromRGB(40, 60, 90)
        b.BorderSizePixel = 0
        b.Text = txt
        b.TextColor3 = Color3.fromRGB(220, 235, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 15
        b.AutoButtonColor = false
        b.LayoutOrder = UI.nextOrder(index)
        b.Parent = pd.scroll
        addCorner(b, 8)
        local st = Instance.new('UIStroke')
        st.Thickness = 1
        st.Color = Color3.fromRGB(90, 140, 200)
        st.Transparency = 0.4
        st.Parent = b
        Runtime:connect(b.MouseEnter, function()
            TweenService:Create(b, T_FAST, {BackgroundColor3 = Color3.fromRGB(55, 85, 125)}):Play()
        end)
        Runtime:connect(b.MouseLeave, function()
            TweenService:Create(b, T_FAST, {BackgroundColor3 = Color3.fromRGB(40, 60, 90)}):Play()
        end)
        Runtime:connect(b.MouseButton1Click, function()
            if callback then callback() end
        end)
        return b
    end

    UI.gui = gui
    UI.window = window
    UI.windowScale = windowScale
    UI.stroke = windowStroke
    UI.closeBtn = closeBtn
    UI.headerBar = headerBar
    UI.openKey = OPEN_KEY
    UI.tabs = tabs
    UI.pages = pages
    UI.tabCount = TAB_COUNT
    UI.indicator = indicator
    UI.tOpen = T_OPEN
    UI.tFast = T_FAST

    function UI.setTab(index, instant)
        if currentTab == index then
            pages[index].frame.Visible = true
            return
        end
        local old = tabs[currentTab]
        if old and pages[currentTab] then
            pages[currentTab].frame.Visible = false
            old.button.TextColor3 = C_SECONDARY
        end
        currentTab = index
        pages[index].frame.Visible = true
        tabs[index].button.TextColor3 = C_WHITE
        local goal = UDim2.new((index - 1) / TAB_COUNT, 10, 1, -2)
        if instant then indicator.Position = goal else TweenService:Create(indicator, T_OPEN, {Position = goal}):Play() end
    end

    MenuUI = UI
end


--============================================================
-- ESP MENU TAG MAP
--============================================================

local ESP_KEY_TO_TAG = {
    EntityESP = 'EntityESP', ItemESP = 'ItemESP', DoorESP = 'DoorESP',
    LeverESP = 'LeverESP', BookESP = 'BookESP', FuseESP = 'FuseESP',
    ChestESP = 'ChestESP', HidingESP = 'HidingESP',
    FilledHidingESP = 'FilledHidingESP', ElectricalESP = 'ElectricalESP',
    KeyESP = 'KeyESP', GateLeverESP = 'GateLeverESP',
    RushLikeESP = 'RushLikeESP', EyesESP = 'EyesESP',
}

--============================================================
-- ANTI / BYPASS CORE
-- Портировано из пользовательского подгона с более безопасным
-- восстановлением исходных свойств при выключении.
--============================================================

local Bypass = {}

do
    local moduleDisabledByUs = {}
    local remoteState = {}
    local seekSaved = setmetatable({}, {__mode = "k"})
    local snareSaved = setmetatable({}, {__mode = "k"})
    local dupeSaved = setmetatable({}, {__mode = "k"})
    local fakePrompts = setmetatable({}, {__mode = "k"})
    local promptOriginalState = setmetatable({}, {__mode = "k"})
    local promptContainer = Instance.new("Folder")
    promptContainer.Name = "Force_v85_InfiniteItems"
    promptContainer.Parent = playerGui

    local infiniteItemNames = {
        lockpick = true,
        shears = true,
        skeletonkey = true,
        multitool = true,
    }

    local lockPromptNames = {
        unlockprompt = true,
        skullprompt = true,
        lockprompt = true,
        thingtoenable = true,
        fusesprompt = true,
        activateeventprompt = true,
    }

    local function getEntityModules()
        local cm = ClientModules or RS:FindFirstChild("ModulesClient") or RS:FindFirstChild("ClientModules")
        return cm and cm:FindFirstChild("EntityModules") or nil
    end

    local function setModuleDisabled(name, disabled)
        local folder = getEntityModules()
        if not folder then return end

        local normal = folder:FindFirstChild(name)
        local hidden = folder:FindFirstChild("_" .. name)

        if disabled then
            if normal and normal:IsA("ModuleScript") then
                moduleDisabledByUs[name] = true
                pcall(function() normal.Name = "_" .. name end)
            end
        elseif moduleDisabledByUs[name] then
            if hidden and hidden:IsA("ModuleScript") then
                pcall(function() hidden.Name = name end)
            end
            moduleDisabledByUs[name] = nil
        end
    end

    local function getRemote(name)
        if remoteState[name] and remoteState[name].real then
            return remoteState[name]
        end

        local real = RemotesFolder and RemotesFolder:FindFirstChild(name)
        if not real then return nil end

        local fake = Instance.new("RemoteEvent")
        fake.Name = name
        fake.Parent = nil

        local data = {
            real = real,
            fake = fake,
            parent = real.Parent,
        }
        remoteState[name] = data
        return data
    end

    local function setRemoteDisabled(name, disabled)
        local data = getRemote(name)
        if not data then return end

        if disabled then
            pcall(function()
                if data.real and data.real.Parent then data.real.Parent = nil end
                data.fake.Parent = RemotesFolder
            end)
        else
            pcall(function()
                if data.parent and data.real then data.real.Parent = data.parent end
                data.fake.Parent = nil
            end)
        end
    end

    local function isLockPrompt(prompt)
        if not prompt or not prompt:IsA("ProximityPrompt") then return false end
        if prompt:GetAttribute("FakePrompt") then return false end

        local n = normalizeName(prompt.Name)
        if lockPromptNames[n] then return true end

        local p = prompt.Parent
        if p and p:GetAttribute("Locked") == true then return true end

        local pp = p and p.Parent
        if pp and pp.Name == "Locker_Small_Locked"
            and prompt.Name == "ActivateEventPrompt" then
            return true
        end

        return false
    end

    local function firePromptSimple(prompt)
        if not prompt or not prompt.Parent then return false end

        local ok, fn = pcall(function() return fireproximityprompt end)
        if ok and type(fn) == "function" then
            local okFire = pcall(fn, prompt)
            if okFire then return true end
        end

        local okFallback = pcall(function()
            local original = prompt.HoldDuration
            prompt.HoldDuration = 0
            prompt:InputHoldBegin()
            task.wait(0.03)
            prompt:InputHoldEnd()
            prompt.HoldDuration = original
        end)
        return okFallback
    end

    local function prepareInfinitePrompt(obj)
        if not State.InfiniteItems then return end
        if not obj or not obj:IsA("ProximityPrompt") then return end
        if obj:GetAttribute("FakePrompt") then return end
        if not isLockPrompt(obj) then return end
        if fakePrompts[obj] then return end
        if not obj.Parent or not obj:IsDescendantOf(workspace) then return end

        local originalParent = obj.Parent
        local oldEnabled = obj.Enabled
        local clone
        local ok = pcall(function()
            local oldArchivable = obj.Archivable
            obj.Archivable = true
            clone = obj:Clone()
            obj.Archivable = oldArchivable
            if not clone then error("Clone failed") end

            clone.Name = obj.Name .. "_Fake"
            clone:SetAttribute("FakePrompt", true)
            clone.Enabled = true
            clone.Parent = originalParent

            fakePrompts[clone] = obj
            promptOriginalState[obj] = {
                Parent = originalParent,
                Enabled = oldEnabled,
            }

            -- Настоящий prompt оставляем в мире, но временно отключаем.
            -- Так игра продолжает видеть правильную структуру объекта.
            obj.Enabled = false

            obj.Destroying:Once(function()
                if clone and clone.Parent then
                    pcall(function() clone:Destroy() end)
                end
                fakePrompts[clone] = nil
                promptOriginalState[obj] = nil
            end)
        end)

        if not ok or not clone then
            if clone and clone.Parent then pcall(function() clone:Destroy() end) end
            fakePrompts[clone] = nil
            promptOriginalState[obj] = nil
            pcall(function() obj.Enabled = oldEnabled end)
        end
    end

    local function restoreInfinitePrompts()
        for fake, original in pairs(fakePrompts) do
            pcall(function()
                local saved = original and promptOriginalState[original]
                if original and original.Parent then
                    original.Enabled = saved and saved.Enabled or true
                end
                if fake and fake.Parent then fake:Destroy() end
            end)
            fakePrompts[fake] = nil
            if original then promptOriginalState[original] = nil end
        end

        -- На случай, если fake prompt исчез раньше обычного cleanup.
        for original, saved in pairs(promptOriginalState) do
            pcall(function()
                if original and original.Parent then
                    original.Enabled = saved.Enabled
                end
            end)
            promptOriginalState[original] = nil
        end
    end

    local function setupInfinitePrompts()
        if not State.InfiniteItems then
            restoreInfinitePrompts()
            return
        end

        pcall(function()
            local currentRooms = workspace:FindFirstChild("CurrentRooms")
            if currentRooms then
                for _, obj in ipairs(currentRooms:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") then prepareInfinitePrompt(obj) end
                end
            end
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj:IsA("Model") or obj:IsA("Folder") then
                    for _, child in ipairs(obj:GetDescendants()) do
                        if child:IsA("ProximityPrompt") then prepareInfinitePrompt(child) end
                    end
                end
            end
        end)
    end

    Runtime:connect(workspace.DescendantAdded, function(obj)
        if State.InfiniteItems and obj:IsA("ProximityPrompt") then
            task.defer(function() prepareInfinitePrompt(obj) end)
        end
    end)

    Runtime:connect(game:GetService("ProximityPromptService").PromptTriggered, function(prompt)
        if not State.InfiniteItems then return end

        local original = fakePrompts[prompt]
        if not original or not original.Parent then return end

        local char = getChar()
        local tool = char and char:FindFirstChildOfClass("Tool")
        if not tool then return end

        local toolKey = normalizeName(tool.Name)
        if not infiniteItemNames[toolKey] then return end

        local dropRemote = RemotesFolder and RemotesFolder:FindFirstChild("DropItem")
        if not dropRemote then return end

        local toolName = tool.Name
        local completed = false
        local drops = workspace:FindFirstChild("Drops")
        local backpack = player:FindFirstChildOfClass("Backpack")
        local connections = {}

        local function disconnectAll()
            for i = #connections, 1, -1 do
                local c = connections[i]
                pcall(function() if c then c:Disconnect() end end)
                connections[i] = nil
            end
        end

        local function useOriginalPrompt()
            if completed then return end
            completed = true
            pcall(function()
                if not original or not original.Parent then return end
                original.Enabled = true
                task.defer(function()
                    if original and original.Parent then
                        firePromptSimple(original)
                        task.delay(0.12, function()
                            if original and original.Parent and State.InfiniteItems then
                                pcall(function() original.Enabled = false end)
                            end
                        end)
                    end
                end)
            end)
            disconnectAll()
        end

        local function checkReturned(obj)
            if completed or not obj then return false end
            if not obj:IsA("Tool") then return false end
            return normalizeName(obj.Name) == toolKey
        end

        if drops then
            connections[#connections + 1] = drops.ChildAdded:Connect(function(newTool)
                if checkReturned(newTool) then
                    -- В оригинальном подгоне ModulePrompt из Drops срабатывал первым.
                    pcall(function()
                        local modulePrompt = newTool:FindFirstChild("ModulePrompt")
                        if modulePrompt and modulePrompt:IsA("ProximityPrompt") then
                            firePromptSimple(modulePrompt)
                        end
                    end)
                    useOriginalPrompt()
                end
            end)
        end

        if char then
            connections[#connections + 1] = char.ChildAdded:Connect(function(newTool)
                if checkReturned(newTool) then useOriginalPrompt() end
            end)
        end

        if backpack then
            connections[#connections + 1] = backpack.ChildAdded:Connect(function(newTool)
                if checkReturned(newTool) then useOriginalPrompt() end
            end)
        end

        pcall(function() dropRemote:FireServer(tool) end)

        Runtime:spawn(function()
            for _ = 1, 50 do
                if completed or not Runtime.alive or not State.InfiniteItems then break end
                local currentChar = getChar()
                local currentBackpack = player:FindFirstChildOfClass("Backpack")
                local returned = nil
                if currentChar then returned = currentChar:FindFirstChild(toolName) end
                if not returned and currentBackpack then returned = currentBackpack:FindFirstChild(toolName) end
                if returned then
                    useOriginalPrompt()
                    break
                end
                task.wait(0.04)
            end
            if not completed then
                disconnectAll()
                completed = true
            end
        end)
    end)

    local function patchSnare(obj)
        if not obj or not State.AntiSnare then return end
        local current = obj
        for _ = 1, 4 do
            if not current then break end
            if current.Name == "Snare" then
                local hitbox = current:FindFirstChild("Hitbox")
                if hitbox and hitbox:IsA("BasePart") then
                    if snareSaved[hitbox] == nil then
                        snareSaved[hitbox] = hitbox.CanTouch
                    end
                    hitbox.CanTouch = false
                end
                break
            end
            current = current.Parent
        end
    end

    local function patchSeek(obj)
        if not obj or not State.AntiSeekObstructions then return end
        local current = obj
        for _ = 1, 5 do
            if not current then break end
            if current.Name == "ChandelierObstruction" then
                local hurt = current:FindFirstChild("HurtPart")
                if hurt and hurt:IsA("BasePart") then
                    if not seekSaved[hurt] then
                        seekSaved[hurt] = { CanTouch = hurt.CanTouch }
                    end
                    hurt.CanTouch = false
                end
                break
            elseif current.Name == "Seek_Arm" then
                local part = current:FindFirstChild("AnimatorPart")
                if part and part:IsA("BasePart") then
                    if not seekSaved[part] then
                        seekSaved[part] = {
                            CanTouch = part.CanTouch,
                            Transparency = part.Transparency,
                            Color = part.Color,
                        }
                    end
                    part.CanTouch = false
                    part.Transparency = 0.7
                    part.Color = Color3.fromRGB(0, 255, 0)
                end
                break
            end
            current = current.Parent
        end
    end

    local restoreSavedRoomBypasses

    local function patchDupe(obj)
        if not obj or not State.AntiDupe then return end
        local current = obj
        for _ = 1, 3 do
            if not current then break end
            if current.Name == "SideroomDupe" then
                local doorFake = current:FindFirstChild("DoorFake")
                local hidden = doorFake and doorFake:FindFirstChild("Hidden")
                if hidden and hidden:IsA("BasePart") then
                    if dupeSaved[hidden] == nil then dupeSaved[hidden] = hidden.CanTouch end
                    hidden.CanTouch = false
                end
                local lock = doorFake and doorFake:FindFirstChild("Lock")
                local prompt = lock and lock:FindFirstChildOfClass("ProximityPrompt")
                if prompt then
                    if dupeSaved[prompt] == nil then dupeSaved[prompt] = prompt.Enabled end
                    prompt.Enabled = false
                end
                break
            end
            current = current.Parent
        end
    end

    local function getActiveRoom()
        local cr = workspace:FindFirstChild("CurrentRooms")
        if not cr then return nil end
        local gameData = RS:FindFirstChild("GameData")
        local latest = gameData and gameData:FindFirstChild("LatestRoom")
        local room = latest and cr:FindFirstChild(tostring(latest.Value))
        if not room then
            local root = getRoot(getChar())
            room = root and getCurrentRoom(root.Position) or nil
        end
        return room
    end

    local function scanRoomBypasses()
        local room = getActiveRoom()
        if not room then return end

        if State.AntiDupe or State.AntiSnare then
            for _, obj in ipairs(room:GetChildren()) do
                if State.AntiDupe and obj.Name == "SideroomDupe" then patchDupe(obj) end
                if State.AntiSnare and obj.Name == "Snare" then patchSnare(obj) end
            end
        end

        if State.AntiSeekObstructions then
            local assets = room:FindFirstChild("Assets")
            if assets then
                for _, obj in ipairs(assets:GetChildren()) do
                    patchSeek(obj)
                end
            end
        end
    end

    Runtime:connect(workspace.DescendantAdded, function(obj)
        if State.AntiSnare then patchSnare(obj) end
        if State.AntiSeekObstructions then patchSeek(obj) end
        if State.AntiDupe then patchDupe(obj) end
    end)

    local function updateRoomBypasses()
        if State.AntiSeekObstructions or State.AntiDupe or State.AntiSnare then
            scanRoomBypasses()
        else
            restoreSavedRoomBypasses()
        end
    end

    restoreSavedRoomBypasses = function()
        for inst, oldValue in pairs(dupeSaved) do
            if inst and inst.Parent then
                pcall(function()
                    if inst:IsA("BasePart") then
                        inst.CanTouch = oldValue
                    elseif inst:IsA("ProximityPrompt") then
                        inst.Enabled = oldValue
                    end
                end)
            end
            dupeSaved[inst] = nil
        end

        for inst, oldValue in pairs(snareSaved) do
            if inst and inst.Parent then
                pcall(function() inst.CanTouch = oldValue end)
            end
            snareSaved[inst] = nil
        end

        for inst, old in pairs(seekSaved) do
            if inst and inst.Parent then
                pcall(function()
                    if old.CanTouch ~= nil then inst.CanTouch = old.CanTouch end
                    if old.Transparency ~= nil then inst.Transparency = old.Transparency end
                    if old.Color ~= nil and inst:IsA("BasePart") then inst.Color = old.Color end
                end)
            end
            seekSaved[inst] = nil
        end
    end

    local function applyModuleStates()
        setModuleDisabled("Shade", State.AntiHalt)
        setModuleDisabled("Screech", State.AntiScreech)
        setModuleDisabled("Dread", State.AntiDread)
    end

    Bypass.sync = function(key, value)
        if key == "AntiHalt" then
            setModuleDisabled("Shade", value)
        elseif key == "AntiScreech" then
            setModuleDisabled("Screech", value)
        elseif key == "AntiDread" then
            setModuleDisabled("Dread", value)
        elseif key == "NoSurgeDamage" then
            setRemoteDisabled("SurgeRemote", value)
        elseif key == "NoHaltDamage" then
            setRemoteDisabled("ShadeResult", value)
        elseif key == "NoScreechDamage" then
            setRemoteDisabled("Screech", value)
        elseif key == "InfiniteItems" then
            setupInfinitePrompts()
        end
    end

    Bypass.cleanup = function()
        restoreInfinitePrompts()
        restoreSavedRoomBypasses()

        for name in pairs(moduleDisabledByUs) do
            setModuleDisabled(name, false)
        end
        for name in pairs(remoteState) do
            setRemoteDisabled(name, false)
        end
        State.InfiniteItems = false
        State.AntiEyes = false
        State.AntiSeekObstructions = false
        State.AntiDupe = false
        State.AntiSnare = false
        State.AntiHalt = false
        State.AntiScreech = false
        State.AntiDread = false
        State.NoSurgeDamage = false
        State.NoHaltDamage = false
        State.NoScreechDamage = false
        State.NoclipForward = false
        State.InstantInteract = true
        pcall(function() if Bypass.setNoclipForward then Bypass.setNoclipForward(false) end end)
        pcall(function() if InstantInteract and InstantInteract.setEnabled then InstantInteract.setEnabled(true) end end)
    end

    ENV.__Force_v85_BYPASS_CLEANUP = Bypass.cleanup

    Runtime:connect(player.CharacterAdded, function()
        task.delay(0.5, function()
            if Runtime.alive and State.InfiniteItems then
                setupInfinitePrompts()
            end
            if Runtime.alive then applyModuleStates() end
        end)
    end)

    local eyesPresent = workspace:FindFirstChild("Eyes") ~= nil
    local motorReplication = RemotesFolder and RemotesFolder:FindFirstChild("MotorReplication")

    Runtime:connect(workspace.DescendantAdded, function(obj)
        local n = normalizeName(obj.Name)
        if n == "eyes" or n == "eyesnew" then
            eyesPresent = true
        end
    end)

    Runtime:connect(workspace.DescendantRemoving, function(obj)
        local n = normalizeName(obj.Name)
        if n == "eyes" or n == "eyesnew" then
            task.defer(function()
                eyesPresent = workspace:FindFirstChild("Eyes") ~= nil
            end)
        end
    end)

    Runtime:connect(RunService.RenderStepped, function()
        if not State.AntiEyes or not eyesPresent then return end
        if not motorReplication or not motorReplication.Parent then
            motorReplication = RemotesFolder and RemotesFolder:FindFirstChild("MotorReplication")
        end
        if motorReplication then
            pcall(function() motorReplication:FireServer(-890) end)
        end
    end)

    Runtime:spawn(function()
        while Runtime.alive do
            pcall(function()
                updateRoomBypasses()
                if State.AntiHalt or State.AntiScreech or State.AntiDread then
                    applyModuleStates()
                end
            end)
            task.wait(0.2)
        end
    end)
end

local function onToggleChange(key, on)
    if key == "Fullbright" then
        if State.Fullbright then applyFB() else removeFB() end
    elseif key == "Overlay" then
        overlay.Visible = State.Overlay
    elseif key == "NameTags" then
        refreshNameTags()
    elseif key == "EntityNameTags" then
        if not State.EntityNameTags then clearAllEntityNameTags() end
    elseif key == "WorldNameTags" then
        if not State.WorldNameTags then
            pcall(function() if ENV.__Force_v85_CLEAR_WORLD_NAMETAGS then ENV.__Force_v85_CLEAR_WORLD_NAMETAGS() end end)
        else
            pcall(function() if ENV.__Force_v85_RESCAN_ESP then ENV.__Force_v85_RESCAN_ESP() end end)
        end
    elseif key == "PlayerESP" then
        if State.PlayerESP then
            for _, tp in ipairs(Players:GetPlayers()) do
                if tp ~= player then addPlayerESP(tp) end
            end
        else clearPlayerESP() end
    elseif key == "PlayerHealthBar" then
        for _, bb in pairs(nameTags) do
            local hp = bb and bb:FindFirstChild("HPBack")
            if hp then hp.Visible = State.PlayerHealthBar end
        end
    elseif key == "AllESP" then
        if not State.AllESP then
            clearPlayerESP()
            clearAllEntityNameTags()
            pcall(function() if ENV.__Force_v85_CLEAR_WORLD_NAMETAGS then ENV.__Force_v85_CLEAR_WORLD_NAMETAGS() end end)
            for _, tag in pairs(ESP_KEY_TO_TAG) do
                pcall(function() clearESPByTag(tag) end)
            end
            pcall(function() if _G.__Force_v85_clearTracers then _G.__Force_v85_clearTracers() end end)
        else
            pcall(function()
                for _, tp in ipairs(Players:GetPlayers()) do
                    if tp ~= player and State.PlayerESP then addPlayerESP(tp) end
                end
                if State.NameTags then refreshNameTags() end
                if ENV.__Force_v85_RESCAN_ESP then
                    ENV.__Force_v85_RESCAN_ESP()
                end
            end)
        end
    elseif key == "EntityTracers" and not State.EntityTracers then
        pcall(function() if _G.__Force_v85_clearTracers then _G.__Force_v85_clearTracers("Entity") end end)
    elseif key == "ItemTracers" and not State.ItemTracers then
        pcall(function() if _G.__Force_v85_clearTracers then _G.__Force_v85_clearTracers("Item") end end)
    elseif key == "PlayerTracers" and not State.PlayerTracers then
        pcall(function() if _G.__Force_v85_clearTracers then _G.__Force_v85_clearTracers("Player") end end)
    elseif key == "NoclipForward" and not State.NoclipForward then
        pcall(function() if Bypass and Bypass.setNoclipForward then Bypass.setNoclipForward(false) end end)
    elseif key == "InstantInteract" then
        pcall(function() if InstantInteract and InstantInteract.setEnabled then InstantInteract.setEnabled(on) end end)
    elseif key == "AntiEyes"
        or key == "AntiSeekObstructions"
        or key == "AntiDupe"
        or key == "AntiSnare"
        or key == "AntiHalt"
        or key == "AntiScreech"
        or key == "AntiDread"
        or key == "NoSurgeDamage"
        or key == "NoHaltDamage"
        or key == "NoScreechDamage"
        or key == "InfiniteItems" then
        pcall(function() if Bypass and Bypass.sync then Bypass.sync(key, State[key]) end end)
    else
        local tag = ESP_KEY_TO_TAG[key]
        if tag and not on then
            clearESPByTag(tag)
            if tag == "DoorESP" then
                pcall(function() clearESPByTag("DoorESP") end)
            end
        end
    end
end

-- MENU CONTENT

do
    local M = MenuUI
    M.toggle(1, 'ESP Master', 'AllESP', function(on) onToggleChange('AllESP', on) end)
    M.toggle(1, 'Entity ESP', 'EntityESP', function(on) onToggleChange('EntityESP', on) end)
    M.toggle(1, 'Item ESP', 'ItemESP', function(on) onToggleChange('ItemESP', on) end)
    M.toggle(1, 'Door ESP', 'DoorESP', function(on) onToggleChange('DoorESP', on) end)
    M.toggle(1, 'Lever ESP', 'LeverESP', function(on) onToggleChange('LeverESP', on) end)
    M.toggle(1, 'Book ESP', 'BookESP', function(on) onToggleChange('BookESP', on) end)
    M.toggle(1, 'Fuse ESP', 'FuseESP', function(on) onToggleChange('FuseESP', on) end)
    M.toggle(1, 'Chest ESP', 'ChestESP', function(on) onToggleChange('ChestESP', on) end)
    M.toggle(1, 'Hiding ESP', 'HidingESP', function(on) onToggleChange('HidingESP', on) end)
    M.toggle(1, 'Filled Hiding', 'FilledHidingESP', function(on) onToggleChange('FilledHidingESP', on) end)
    M.toggle(1, 'Electrical ESP', 'ElectricalESP', function(on) onToggleChange('ElectricalESP', on) end)
    M.toggle(1, 'Key ESP', 'KeyESP', function(on) onToggleChange('KeyESP', on) end)
    M.toggle(1, 'Gate Lever ESP', 'GateLeverESP', function(on) onToggleChange('GateLeverESP', on) end)
    M.toggle(1, 'Rush-like ESP', 'RushLikeESP', function(on) onToggleChange('RushLikeESP', on) end)
    M.toggle(1, 'Eyes / Lookman ESP', 'EyesESP', function(on) onToggleChange('EyesESP', on) end)
    M.toggle(2, 'Player ESP', 'PlayerESP', function(on) onToggleChange('PlayerESP', on) end)
    M.toggle(2, 'Player name tags', 'NameTags', function(on) onToggleChange('NameTags', on) end)
    M.toggle(2, 'Player HP Bar', 'PlayerHealthBar', function(on) onToggleChange('PlayerHealthBar', on) end)
    M.toggle(2, 'Entity name tags', 'EntityNameTags', function(on) onToggleChange('EntityNameTags', on) end)
    M.toggle(2, 'World name tags', 'WorldNameTags', function(on) onToggleChange('WorldNameTags', on) end)
    M.toggle(2, 'Player Tracers', 'PlayerTracers', function(on) onToggleChange('PlayerTracers', on) end)
    M.toggle(2, 'Entity Tracers', 'EntityTracers', function(on) onToggleChange('EntityTracers', on) end)
    M.toggle(2, 'Item Tracers', 'ItemTracers', function(on) onToggleChange('ItemTracers', on) end)

    -- Bypass
    M.actionButton(3, 'Revive', function()
        local ok = false
        pcall(function()
            if ENV.__Force_v85_Revive then
                ok = ENV.__Force_v85_Revive() == true
            end
        end)
        if not ok and State.Notify and showNotification then
            showNotification('Force', 'Revive remote не найден.', Color3.fromRGB(255, 90, 90))
        elseif ok and State.Notify and showNotification then
            showNotification('Force', 'Возрождение запрошено.', Color3.fromRGB(120, 255, 170))
        end
    end)
    M.toggle(3, 'Delete Drones', 'AutoDeleteDrones', function(on) onToggleChange('AutoDeleteDrones', on) end)
    M.toggle(3, 'Delete Alma', 'AutoDeleteAlma', function(on) onToggleChange('AutoDeleteAlma', on) end)
    M.toggle(3, 'Anti-Eyes', 'AntiEyes', function(on) onToggleChange('AntiEyes', on) end)
    M.toggle(3, 'Anti-Seek-Obstructions', 'AntiSeekObstructions', function(on) onToggleChange('AntiSeekObstructions', on) end)
    M.toggle(3, 'Anti-Dupe', 'AntiDupe', function(on) onToggleChange('AntiDupe', on) end)
    M.toggle(3, 'Anti-Snare', 'AntiSnare', function(on) onToggleChange('AntiSnare', on) end)
    M.toggle(3, 'Anti-Halt', 'AntiHalt', function(on) onToggleChange('AntiHalt', on) end)
    M.toggle(3, 'Anti-Screech', 'AntiScreech', function(on) onToggleChange('AntiScreech', on) end)
    M.toggle(3, 'Anti-Dread', 'AntiDread', function(on) onToggleChange('AntiDread', on) end)
    M.toggle(3, 'No Surge Damage', 'NoSurgeDamage', function(on) onToggleChange('NoSurgeDamage', on) end)
    M.toggle(3, 'No Halt Damage', 'NoHaltDamage', function(on) onToggleChange('NoHaltDamage', on) end)
    M.toggle(3, 'No Screech Damage', 'NoScreechDamage', function(on) onToggleChange('NoScreechDamage', on) end)
    M.toggle(3, 'Infinite Items', 'InfiniteItems', function(on) onToggleChange('InfiniteItems', on) end)
    M.toggle(3, 'Instant Interact', 'InstantInteract', function(on) onToggleChange('InstantInteract', on) end)
    M.text(3, 'J = вкл / выкл мгновенное взаимодействие с ProximityPrompt.', false, 12, Color3.fromRGB(110, 110, 110))
    M.warnBadge(3, 'Infinite items: Lockpick, Skeleton Key, Shears и Multitool.')
    M.toggle(4, 'Noclip + Auto Forward (N)', 'NoclipForward', function(on)
        pcall(function() if Bypass and Bypass.setNoclipForward then Bypass.setNoclipForward(on) end end)
    end)
    M.warnBadge(4, 'N — быстрое включение/выключение. Скорость авто-движения: 1.')
    M.toggle(4, 'Speed Bypass', 'SpeedBypass', function(on)
        State.SpeedBypass = on
        if not on then
            pcall(function()
                local hum = getChar() and getChar():FindFirstChildOfClass('Humanoid')
                if hum then hum.WalkSpeed = Functions.GetCurrentSpeed() end
            end)
        end
    end)
    M.sliderWithInput(4, 'Speed', 16, 200, 16, function(v) SpeedValue = v end)
    M.toggle(4, 'Jump Bypass (CanJump)', 'JumpBypass', function(on) State.JumpBypass = on end)
    M.toggle(4, 'Slide Bypass (CanSlide)', 'SlideBypass', function(on) State.SlideBypass = on end)
    M.toggle(4, 'Infinite Jump', 'InfiniteJump', function(on) State.InfiniteJump = on end)
    M.toggle(4, 'Crouch Spoof (тихий шаг)', 'CrouchSpoof', function(on) State.CrouchSpoof = on end)
    M.toggle(4, 'No Acceleration (без скольжения)', 'NoAcceleration', function(on)
        State.NoAcceleration = on
        if not on then applyNoAcceleration() end
    end)

    M.toggle(5, 'Fullbright (Anti-Fog)', 'Fullbright', function(on) onToggleChange('Fullbright', on) end)
    M.toggle(5, 'Overlay', 'Overlay', function(on) onToggleChange('Overlay', on) end)
    M.slider(5, 'ESP Distance', 0, MAX_ESP_DISTANCE, DEFAULT_ESP_DISTANCE, function(v)
        ESP_DISTANCE = v
    end)
    M.toggle(5, 'Notifications', 'Notify', function(on) onToggleChange('Notify', on) end)
    M.toggle(5, 'Sound', 'Sound', function(on) onToggleChange('Sound', on) end)
    M.text(5, 'Force • H / RightShift = menu • F4 = freecam', false, 12, Color3.fromRGB(110, 110, 110))
end

--============================================================
-- OPEN / CLOSE + CURSOR
--============================================================

do
    local M = MenuUI

    pcall(function()
        local pm = require(player:WaitForChild('PlayerScripts'):WaitForChild('PlayerModule'))
        if pm then
            playerControls = pm:GetControls()
            cameraModule = pm:GetCameras()
        end
    end)

    local originalMouseBehavior, originalMouseIcon, originalModal
    local cursorStateSaved = false

    local function saveCursorState()
        if cursorStateSaved then return end
        cursorStateSaved = true
        pcall(function()
            originalMouseBehavior = UserInputService.MouseBehavior
            originalMouseIcon = UserInputService.MouseIconEnabled
            originalModal = UserInputService.ModalEnabled
        end)
    end

    local function restoreCursorState()
        pcall(function()
            if originalMouseBehavior then UserInputService.MouseBehavior = originalMouseBehavior end
            if originalMouseIcon ~= nil then UserInputService.MouseIconEnabled = originalMouseIcon end
            if originalModal ~= nil then UserInputService.ModalEnabled = originalModal end
        end)
        cursorStateSaved = false
    end

    local function forceUnlockCursor()
        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
            UserInputService.ModalEnabled = false
        end)
        pcall(function() if playerControls then playerControls:Enable() end end)
        pcall(function() if cameraModule and not State.Freecam then cameraModule:Disable() end end)
    end

    Runtime:connect(RunService.RenderStepped, function()
        if not menuOpen then return end
        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
            UserInputService.ModalEnabled = false
        end)
    end)

    local function setMenu(open)
        menuOpen = open
        if open then
            M.window.Visible = true
            M.window.GroupTransparency = 1
            M.windowScale.Scale = 0.96
            TweenService:Create(M.window, M.tOpen, {GroupTransparency = 0}):Play()
            TweenService:Create(M.windowScale, M.tOpen, {Scale = 1}):Play()
            forceUnlockCursor()
            return
        end

        TweenService:Create(M.window, M.tFast, {GroupTransparency = 1}):Play()
        TweenService:Create(M.windowScale, M.tFast, {Scale = 0.96}):Play()
        task.delay(0.16, function()
            if not menuOpen then M.window.Visible = false end
        end)
        pcall(function()
            if playerControls then playerControls:Enable() end
            if cameraModule and not State.Freecam then cameraModule:Enable() end
        end)
        task.delay(0.05, restoreCursorState)
    end

    M.setMenu = setMenu

    Runtime:connect(M.closeBtn.MouseButton1Click, function()
        setMenu(false)
    end)

    Runtime:connect(UserInputService.InputBegan, function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.H or input.KeyCode == Enum.KeyCode.RightShift then
            setMenu(not menuOpen)
        end
    end)

    M.setTab(1, true)
    setMenu(true)
end

--============================================================
-- MOVEMENT BYPASS (Speed / Jump / Slide / Infinite Jump / Crouch Spoof)
--============================================================

do
    local lastCrouchFire = 0

    Runtime:connect(RunService.RenderStepped, function()
        local char = getChar()
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end

        -- SpeedBypass: WalkSpeed + fire Crouch чтобы сервер думал что крадёшься
        if State.SpeedBypass and not Functions.Hiding() then
            hum.WalkSpeed = SpeedValue
            local now = os.clock()
            if now - lastCrouchFire > 0.1 and RemotesFolder then
                lastCrouchFire = now
                local crouch = RemotesFolder:FindFirstChild("Crouch")
                if crouch then
                    pcall(function() crouch:FireServer(true, true) end)
                end
            end
        end

        -- JumpBypass
        if State.JumpBypass then
            pcall(function() char:SetAttribute("CanJump", true) end)
        end

        -- SlideBypass
        if State.SlideBypass then
            pcall(function() char:SetAttribute("CanSlide", true) end)
        end

        -- CrouchSpoof
        if State.CrouchSpoof and not State.SpeedBypass then
            local now = os.clock()
            if now - lastCrouchFire > 0.5 and RemotesFolder then
                lastCrouchFire = now
                local crouch = RemotesFolder:FindFirstChild("Crouch")
                if crouch then
                    pcall(function() crouch:FireServer(true) end)
                end
            end
        end

        -- NoAcceleration
        pcall(applyNoAcceleration)
    end)

    -- Infinite Jump
    Runtime:connect(UserInputService.JumpRequest, function()
        if not State.InfiniteJump then return end
        local char = getChar()
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        task.wait(0.05)
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
    end)

    Runtime:connect(player.CharacterAdded, function()
        noAccelState.active = false
        noAccelState.saved = {}
    end)
end

--============================================================
-- NOCLIP + AUTO FORWARD (N)
-- N — вкл/выкл ноклип + автоматическое движение вперёд по камере.
--============================================================

do
    local noclipState = {
        active = false,
        speed = 1,
        liftSpeed = 0,
        savedCollision = setmetatable({}, {__mode = "k"}),
    }

    local function setNoclipEnabled(enabled)
        noclipState.active = enabled
        local char = getChar()
        if not char then return end

        if enabled then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    if noclipState.savedCollision[part] == nil then
                        noclipState.savedCollision[part] = part.CanCollide
                    end
                    part.CanCollide = false
                end
            end
        else
            for part, oldValue in pairs(noclipState.savedCollision) do
                if part and part.Parent then
                    pcall(function() part.CanCollide = oldValue end)
                end
                noclipState.savedCollision[part] = nil
            end
        end
    end

    Runtime:connect(RunService.Stepped, function()
        if not noclipState.active then return end
        local char = getChar()
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if noclipState.savedCollision[part] == nil then
                    noclipState.savedCollision[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    end)

    Runtime:connect(RunService.RenderStepped, function(dt)
        if not noclipState.active then return end

        local char = getChar()
        local cam = workspace.CurrentCamera
        if not char or not cam then return end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end

        local look = cam.CFrame.LookVector
        local forward = Vector3.new(look.X, 0, look.Z)
        if forward.Magnitude < 0.01 then return end
        forward = forward.Unit

        local movement = forward * noclipState.speed * dt
        if noclipState.liftSpeed ~= 0 then
            movement += Vector3.new(0, noclipState.liftSpeed * dt, 0)
        end

        pcall(function()
            hrp.CFrame = hrp.CFrame + movement
        end)
    end)

    Runtime:connect(UserInputService.InputBegan, function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.N then
            setNoclipEnabled(not noclipState.active)
        end
    end)

    Runtime:connect(player.CharacterAdded, function()
        noclipState.active = false
        noclipState.savedCollision = setmetatable({}, {__mode = "k"})
    end)

    Runtime:spawn(function()
        while Runtime.alive do
            if not noclipState.active then
                for part in pairs(noclipState.savedCollision) do
                    noclipState.savedCollision[part] = nil
                end
            end
            task.wait(1)
        end
    end)

    Bypass.setNoclipForward = setNoclipEnabled
    Bypass.getNoclipForwardState = function() return noclipState.active end
end

--============================================================
-- INSTANT INTERACT
--============================================================

do
    local function initInstantInteract()
        local enabled = State.InstantInteract == true
        local savedDurations = setmetatable({}, {__mode = "k"})
        local running = true

        local trackedPrompts = setmetatable({}, {__mode = "k"})

        local function applyPrompt(prompt)
            if not prompt or not prompt:IsA("ProximityPrompt") then return end
            trackedPrompts[prompt] = true
            if savedDurations[prompt] == nil then
                savedDurations[prompt] = prompt.HoldDuration
            end
            if enabled then
                pcall(function() prompt.HoldDuration = 0 end)
            end
        end

        local function scan(container)
            if not container then return end
            local count = 0
            for _, obj in ipairs(container:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    applyPrompt(obj)
                    count += 1
                    if count % 250 == 0 then
                        task.wait()
                    end
                end
            end
        end

        local function restoreAll()
            for prompt, duration in pairs(savedDurations) do
                if prompt and prompt.Parent then
                    pcall(function() prompt.HoldDuration = duration end)
                end
            end
        end

        local api = {}
        function api.setEnabled(on)
            enabled = on == true
            State.InstantInteract = enabled
            if enabled then
                -- Используем уже отслеживаемые prompt'ы вместо нового полного скана Workspace.
                for prompt in pairs(trackedPrompts) do
                    if prompt and prompt.Parent then
                        applyPrompt(prompt)
                    else
                        trackedPrompts[prompt] = nil
                    end
                end
            else
                restoreAll()
            end
        end

        Runtime:connect(workspace.DescendantAdded, function(obj)
            if obj:IsA("ProximityPrompt") then
                trackedPrompts[obj] = true
                applyPrompt(obj)
            end
        end)

        -- Не сканируем CurrentRooms на каждом Heartbeat.
        -- Поддерживаем только уже найденные prompt'ы.
        Runtime:spawn(function()
            while Runtime.alive and running do
                if enabled then
                    for prompt in pairs(trackedPrompts) do
                        if not prompt or not prompt.Parent then
                            trackedPrompts[prompt] = nil
                        else
                            if savedDurations[prompt] == nil then
                                savedDurations[prompt] = prompt.HoldDuration
                            end
                            if prompt.HoldDuration ~= 0 then
                                pcall(function() prompt.HoldDuration = 0 end)
                            end
                        end
                    end
                end
                task.wait(2.0)
            end
        end)

        Runtime:connect(UserInputService.InputBegan, function(input, processed)
            if processed then return end
            if input.KeyCode == Enum.KeyCode.J then
                api.setEnabled(not enabled)
            end
        end)

        scan(workspace)

        return api
    end

    InstantInteract = initInstantInteract()
end

--============================================================
-- SCANNER 1 — ENTITIES
--============================================================

local frameEntityCounts = {}

local function scanEntityForAlert(obj)
    if not obj or not obj.Parent then return end
    if isOwnChar(obj) then return end
    if not obj:IsA("Model") and not obj:IsA("Tool") then return end

    local rootObj = obj
    local ent = getEntityName(obj)

    if not ent then
        local figureRoot = findFigureRoot(obj)
        if figureRoot then
            rootObj = figureRoot
            ent = "FIGURE"
        end
    end

    if not ent or ent == "VOID" then return end

    if ent ~= "FIGURE" then
        local checkedRoot = getEntityRoot(obj)
        if checkedRoot ~= obj then return end
        rootObj = checkedRoot
    end

    local room = getRoom(rootObj)
    frameEntityCounts[room] = frameEntityCounts[room] or {}
    frameEntityCounts[room][ent] = (frameEntityCounts[room][ent] or 0) + 1

    alertedEntities.__entityRoots = alertedEntities.__entityRoots or {}
    alertedEntities.__entityRoots[room] = alertedEntities.__entityRoots[room] or {}
    alertedEntities.__entityRoots[room][ent] = rootObj

    if noESPEntities[ent] then return end

    if State.EntityESP then
        local t = getESPTarget(rootObj)
        if t then
            local pos = getWorldPos(t)
            local root = getRoot(getChar())
            local rootPos = root and root.Position or nil
            if isWithinDist(pos, rootPos) then
                if State.EntityESP then
                    addESP(t, MONSTER_COLOR, "EntityESP")
                else
                    removeESPFrom(t, "EntityESP")
                end

                if State.RushLikeESP
                    and (ent == "RUSH" or ent == "AMBUSH" or ent == "BLITZ"
                        or ent == "SURGE" or ent == "BASH" or ent == "SCRIBBLES"
                        or ent == "DRONE" or ent == "DRONES") then
                    addESP(t, RUSH_LIKE_COLOR, "RushLikeESP")
                else
                    removeESPFrom(t, "RushLikeESP")
                end

                if State.EyesESP and (ent == "EYES" or ent == "LOOKMAN") then
                    addESP(t, EYES_ESP_COLOR, "EyesESP")
                else
                    removeESPFrom(t, "EyesESP")
                end

                if State.EntityNameTags then addEntityNameTag(t, ent) end
                if State.EntityTracers and pos and ent ~= "SNARE" and ent ~= "DUPE" and ent ~= "MANDRAKE" and ent ~= "MANDRAKE LIVE" then
                    getTracer(t, "Entity")
                end
            else
                removeESPFrom(t, "EntityESP")
                removeESPFrom(t, "RushLikeESP")
                removeESPFrom(t, "EyesESP")
            end
        end
    end
end

local function scanEntityTopLevel()
    frameEntityCounts = {}
    alertedEntities.__entityRoots = {}

    local stampedeFound = false
    for _, obj in ipairs(workspace:GetChildren()) do
        local fn = string.lower(obj.Name)
        if string.find(fn, "dronesstampede", 1, true)
            or string.find(fn, "dronestampede", 1, true) then
            stampedeFound = true

            if State.RushLikeESP then
                local stampedeTarget = getESPTarget(obj)
                if stampedeTarget then
                    local stampedePos = getWorldPos(stampedeTarget)
                    local localRoot = getRoot(getChar())
                    local localRootPos = localRoot and localRoot.Position or nil
                    if isWithinDist(stampedePos, localRootPos) then
                        addESP(stampedeTarget, RUSH_LIKE_COLOR, "RushLikeESP")
                    else
                        removeESPFrom(stampedeTarget, "RushLikeESP")
                    end
                end
            end

            local k = "DRONE_STAMPEDE_ALERT"
            if not alertedEntities[k] then
                alertedEntities[k] = true
                showNotification("Archives", "Часпик дронов обнаружен!", Color3.fromRGB(255, 180, 60), obj, true)
                playAlertSound()
            end
        end
        local nrm = normalizeName(obj.Name)
        if nrm == "gloombatswarm" then
            for _, inner in ipairs(obj:GetDescendants()) do
                scanEntityForAlert(inner)
            end
        else
            scanEntityForAlert(obj)
        end
    end

    if not stampedeFound then
        alertedEntities["DRONE_STAMPEDE_ALERT"] = nil
    end

    for target in pairs(entityNameTags) do
        if not target or not target.Parent then removeEntityNameTag(target) end
    end

    processEntityAlerts(frameEntityCounts)
end

Runtime:spawn(function()
    while Runtime.alive do
        pcall(scanEntityTopLevel)
        task.wait(SCAN_ENTITIES_DELAY)
    end
end)

--============================================================
-- DELETE DRONES
--============================================================

do
    local droneTargets = {}

    local function trackCleanupTarget(obj)
        if not obj or not obj:IsDescendantOf(workspace) then return end
        local n = normalizeName(obj.Name)
        if string.find(n, "drone", 1, true) then
            droneTargets[obj] = true
        end
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        trackCleanupTarget(obj)
    end
    Runtime:connect(workspace.DescendantAdded, trackCleanupTarget)

    Runtime:spawn(function()
        while Runtime.alive do
            pcall(function()
                if State.AutoDeleteDrones then
                    for obj in pairs(droneTargets) do
                        if not obj or not obj.Parent then
                            droneTargets[obj] = nil
                        elseif obj:IsDescendantOf(workspace) then
                            droneTargets[obj] = nil
                            pcall(function() obj:Destroy() end)
                            task.wait(0.1)
                        else
                            droneTargets[obj] = nil
                        end
                    end
                end
            end)
            task.wait(DRONE_CLEAN_INTERVAL)
        end
    end)
end

--============================================================
-- DELETE ALMA
--============================================================

do
    local almaTarget = nil

    local function updateAlmaTarget(obj)
        if obj and obj.Name == "Alma" and obj:IsA("Model") and obj.Parent == workspace then
            almaTarget = obj
        end
    end

    updateAlmaTarget(workspace:FindFirstChild("Alma"))

    Runtime:connect(workspace.ChildAdded, function(obj)
        if obj.Name == "Alma" and obj:IsA("Model") then
            almaTarget = obj
            if State.AutoDeleteAlma then
                pcall(function() obj:Destroy() end)
                almaTarget = nil
            end
        end
    end)

    Runtime:connect(workspace.ChildRemoved, function(obj)
        if obj == almaTarget then almaTarget = nil end
    end)

    Runtime:spawn(function()
        while Runtime.alive do
            pcall(function()
                if State.AutoDeleteAlma then
                    local alma = almaTarget
                    if not alma or not alma.Parent then
                        alma = workspace:FindFirstChild("Alma")
                        if alma and alma:IsA("Model") then almaTarget = alma
                        else almaTarget = nil end
                    end
                    if almaTarget and almaTarget.Parent == workspace then
                        pcall(function() almaTarget:Destroy() end)
                        almaTarget = nil
                    end
                end
            end)
            task.wait(0.5)
        end
    end)
end

--============================================================
-- SCANNER 2 — WORLD
--============================================================

local function processWorldObject(obj)
    pcall(function()
        if not obj or not obj.Parent then return end
        if isOwnChar(obj) then return end

        local name = normalizeName(obj.Name)
        local rawName = string.lower(obj.Name)
        local root = getRoot(getChar())
        local rootPos = root and root.Position or nil

        -- STAIRWELL ESP
        -- Fire Alarm: CurrentRooms > room > Assets > Switches > StairwellFireAlarm > Base
        if obj:IsA("BasePart")
            and obj.Name == "Base"
            and obj.Parent and obj.Parent.Name == "StairwellFireAlarm"
            and obj.Parent.Parent and obj.Parent.Parent.Name == "Switches"
            and obj.Parent.Parent.Parent and obj.Parent.Parent.Parent.Name == "Assets"
            and obj.Parent.Parent.Parent.Parent
            and obj.Parent.Parent.Parent.Parent.Parent == workspace.CurrentRooms then
            if isWithinDist(obj.Position, rootPos) then
                if State.LeverESP then
                    addESP(obj, LEVER_COLOR, "LeverESP")
                else
                    removeESPFrom(obj, "LeverESP")
                end
            else
                removeESPFrom(obj, "LeverESP")
            end
            return
        end

        -- Fire Escape: CurrentRooms > room > Assets > StairwellBlastDoor > Main
        if obj:IsA("BasePart")
            and obj.Name == "Main"
            and obj.Parent and obj.Parent.Name == "StairwellBlastDoor"
            and obj.Parent.Parent and obj.Parent.Parent.Name == "Assets"
            and obj.Parent.Parent.Parent
            and obj.Parent.Parent.Parent.Parent == workspace.CurrentRooms then
            if isWithinDist(obj.Position, rootPos) then
                if State.HidingESP then
                    addESP(obj, HIDING_COLOR, "HidingESP")
                else
                    removeESPFrom(obj, "HidingESP")
                end
                removeESPFrom(obj, "FilledHidingESP")
            else
                removeESPFrom(obj, "HidingESP")
                removeESPFrom(obj, "FilledHidingESP")
            end
            return
        end

        -- MouseHole entity target: MouseHole > Hole > HoleBase
        if obj:IsA("BasePart")
            and obj.Name == "HoleBase"
            and obj.Parent and obj.Parent.Name == "Hole"
            and obj.Parent.Parent and obj.Parent.Parent.Name == "MouseHole" then
            if State.EntityESP and isWithinDist(obj.Position, rootPos) then
                addESP(obj, MONSTER_COLOR, "EntityESP")
            else
                removeESPFrom(obj, "EntityESP")
            end
            return
        end

        if obj:IsA("Model") or obj:IsA("Tool") then
            local rootObj = obj
            local ent = getEntityName(obj)

            if not ent then
                local figureRoot = findFigureRoot(obj)
                if figureRoot then
                    rootObj = figureRoot
                    ent = "FIGURE"
                end
            end

            if ent and ent ~= "VOID" then
                if ent ~= "FIGURE" then
                    local checkedRoot = getEntityRoot(rootObj)
                    if checkedRoot ~= rootObj then return end
                end
                if not noESPEntities[ent] and State.EntityESP then
                    local t = getESPTarget(rootObj)
                    if t then
                        local pos = getWorldPos(t)
                        if isWithinDist(pos, rootPos) then
                            if State.EntityESP then
                                addESP(t, MONSTER_COLOR, "EntityESP")
                            else
                                removeESPFrom(t, "EntityESP")
                            end

                            if State.RushLikeESP
                                and (ent == "RUSH" or ent == "AMBUSH" or ent == "BLITZ"
                                    or ent == "SURGE" or ent == "BASH" or ent == "SCRIBBLES"
                                    or ent == "DRONE" or ent == "DRONES") then
                                addESP(t, RUSH_LIKE_COLOR, "RushLikeESP")
                            else
                                removeESPFrom(t, "RushLikeESP")
                            end

                            if State.EyesESP and (ent == "EYES" or ent == "LOOKMAN") then
                                addESP(t, EYES_ESP_COLOR, "EyesESP")
                            else
                                removeESPFrom(t, "EyesESP")
                            end

                            if State.EntityNameTags then addEntityNameTag(t, ent) end
                            if State.EntityTracers and pos and ent ~= "SNARE" and ent ~= "DUPE" and ent ~= "MANDRAKE" and ent ~= "MANDRAKE LIVE" then
                                getTracer(t, "Entity")
                            end
                        else
                            removeESPFrom(t, "EntityESP")
                            removeESPFrom(t, "RushLikeESP")
                            removeESPFrom(t, "EyesESP")
                        end
                    end
                end
                return
            end
        end

        -- Key ESP (позаимствован из подгона, но встроен в общий registry)
        local isKeyObject =
            name == "keyobtain" or name == "keyobtainfake"
            or name == "roomkey" or name == "hotelkey"
            or name == "key" or name == "keymodel"
            or name == "electricalroomkey" or name == "backdoorroomkey"
            or name == "backdoorkey" or name == "ironkey"
            or name == "keyiron"

        if isKeyObject then
            local t = getESPTarget(obj)
            if t then
                local pos = getWorldPos(t)
                if isWithinDist(pos, rootPos) then
                    if State.KeyESP then
                        addESP(t, KEY_COLOR, "KeyESP")
                    else
                        removeESPFrom(t, "KeyESP")
                    end
                    if State.ItemESP and isRealItem(obj, name) then
                        addESP(t, ITEM_COLOR, "ItemESP")
                        if State.ItemTracers and pos then getTracer(t, "Item") end
                    end
                else
                    removeESPFrom(t, "KeyESP")
                    removeESPFrom(t, "ItemESP")
                end
            end
            return
        end

        if State.GateLeverESP and name == "leverforgate" then
            local t = getESPTarget(obj)
            if t then
                local pos = getWorldPos(t)
                if isWithinDist(pos, rootPos) then
                    addESP(t, GATE_LEVER_COLOR, "GateLeverESP")
                else
                    removeESPFrom(t, "GateLeverESP")
                end
            end
            return
        end

        if State.ItemESP and isRealItem(obj, name) then
            local t = getESPTarget(obj)
            if t then
                local pos = getWorldPos(t)
                if isWithinDist(pos, rootPos) then
                    addESP(t, ITEM_COLOR, "ItemESP")
                    if State.ItemTracers and pos then getTracer(t, "Item") end
                end
            end
            return
        end

        if State.LeverESP then
            local isL = levers[name] or string.find(name, "lever", 1, true) ~= nil
            if isL then
                local t = getESPTarget(obj)
                if t then
                    local pos = getWorldPos(t)
                    if isWithinDist(pos, rootPos) then addESP(t, LEVER_COLOR, "LeverESP") end
                end
                return
            end
        end

        if State.ElectricalESP then
            local isE = electricals[name]
                or string.find(name, "electrical", 1, true) ~= nil
                or string.find(name, "breaker", 1, true) ~= nil
            if isE then
                local t = getESPTarget(obj)
                if t then
                    local pos = getWorldPos(t)
                    if isWithinDist(pos, rootPos) then addESP(t, ELECTRICAL_COLOR, "ElectricalESP") end
                end
                return
            end
        end

        if State.BookESP and books[name] then
            local t = getESPTarget(obj)
            if t then
                local pos = getWorldPos(t)
                if isWithinDist(pos, rootPos) then addESP(t, BOOK_COLOR, "BookESP") end
            end
            return
        end

        if State.FuseESP then
            local isF = fuses[name] or string.find(name, "fuse", 1, true) ~= nil
            if isF then
                local t = getESPTarget(obj)
                if t then
                    local pos = getWorldPos(t)
                    if isWithinDist(pos, rootPos) then addESP(t, FUSE_COLOR, "FuseESP") end
                end
                return
            end
        end

        if State.ChestESP and lockedChests[name] then
            local t = getESPTarget(obj)
            if t then
                local pos = getWorldPos(t)
                if isWithinDist(pos, rootPos) then addESP(t, LOCKED_CHEST_COLOR, "ChestESP") end
            end
            return
        end

        if State.ChestESP and normalChests[name] then
            local t = getESPTarget(obj)
            if t then
                local pos = getWorldPos(t)
                if isWithinDist(pos, rootPos) then addESP(t, CHEST_COLOR, "ChestESP") end
            end
            return
        end

        if State.ChestESP and mandrakeHoles[name] then
            local t = getESPTarget(obj)
            if t then
                local pos = getWorldPos(t)
                if isWithinDist(pos, rootPos) then addESP(t, CHEST_COLOR, "ChestESP") end
            end
            return
        end

        local ht = getHidingTarget(obj, name)
        if ht then
            local pos = getWorldPos(ht)
            if isWithinDist(pos, rootPos) then
                local filled = isHidingFilled(ht)
                if filled and State.FilledHidingESP then
                    addESP(ht, FILLED_HIDING_COLOR, "FilledHidingESP")
                else
                    removeESPFrom(ht, "FilledHidingESP")
                end
                if State.HidingESP then
                    addESP(ht, HIDING_COLOR, "HidingESP")
                else
                    removeESPFrom(ht, "HidingESP")
                end
            else
                removeESPFrom(ht, "HidingESP")
                removeESPFrom(ht, "FilledHidingESP")
            end
            return
        end

        if State.DoorESP and obj:IsA("Model") and rawName == "door" then
            addDoorESP(obj)
        end
    end)
end

ENV.__Force_v85_RESCAN_ESP = function()
    if not Runtime.alive or State.AllESP == false then return end
    pcall(function()
        local root = getRoot(getChar())
        if root and type(getCurrentRoom) == "function" then
            local room = getCurrentRoom(root.Position)
            if room then
                for _, obj in ipairs(room:GetDescendants()) do
                    processWorldObject(obj)
                end
            end
        end

        -- Верхнеуровневые объекты (Rush, DronesStampede и т.п.).
        for _, obj in ipairs(workspace:GetChildren()) do
            processWorldObject(obj)
        end
    end)
end

Runtime:connect(workspace.DescendantAdded, processWorldObject)

Runtime:connect(Players.PlayerRemoving, function(tp)
    if not tp or tp == player then return end
    pcall(function()
        local character = tp.Character
        if character and _G.__Force_v85_clearTracers then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then destroyTracer(part) end
            end
        end
    end)
end)

Runtime:spawn(function()
    task.wait(1)
    if not Runtime.alive then return end
    local count = 0
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if not Runtime.alive then break end
            processWorldObject(obj)
            count += 1
            if count % 250 == 0 then
                task.wait()
            end
        end
    end)
end)

Runtime:spawn(function()
    while Runtime.alive do
        pcall(function()
            if State.AllESP == false then return end
            local root = getRoot(getChar())
            if not root or type(getCurrentRoom) ~= "function" then return end

            local room = getCurrentRoom(root.Position)
            if not room then return end

            -- Редкая reconciliation-проверка только текущей комнаты.
            -- Новые объекты и так обрабатываются через DescendantAdded.
            for _, obj in ipairs(room:GetDescendants()) do
                processWorldObject(obj)
            end
        end)
        task.wait(math.max(SCAN_FALLBACK_DELAY, 20))
    end
end)

--============================================================
-- SCREECH FAST DETECTOR
--============================================================

do
    local lastScreechObjects = {}

    local function handleScreechObject(obj)
        if not obj or not obj.Parent then return end
        if isOwnChar(obj) then return end
        local n = normalizeName(obj.Name)
        local isScreech =
            n == "screech" or n == "screechnew" or n == "screechrig"
            or n == "screechmodel" or n == "screechv2" or n == "screechbody"
        if not isScreech then return end

        local now = os.clock()
        if lastScreechObjects[obj] and now - lastScreechObjects[obj] < 1.5 then return end
        lastScreechObjects[obj] = now

        local target = getESPTarget(obj)
        local root = getRoot(getChar())
        local rootPos = root and root.Position or nil

        if target and State.EntityESP then
            local pos = getWorldPos(target)
            if isWithinDist(pos, rootPos) then
                addESP(target, MONSTER_COLOR, "EntityESP")
                if State.EntityNameTags then addEntityNameTag(target, "SCREECH") end
            end
        end
        if State.Notify then
            showNotification("Entity", "SCREECH обнаружен!", MONSTER_COLOR)
            playAlertSound()
        end
    end

    Runtime:connect(workspace.DescendantAdded, function(obj)
        pcall(function()
            handleScreechObject(obj)
            local parent = obj.Parent
            for _ = 1, 4 do
                if not parent then break end
                handleScreechObject(parent)
                parent = parent.Parent
            end
        end)
    end)

    Runtime:spawn(function()
        while Runtime.alive do
            pcall(function()
                local now = os.clock()
                for obj, stamp in pairs(lastScreechObjects) do
                    if not obj or not obj.Parent or now - stamp > 10 then
                        lastScreechObjects[obj] = nil
                    end
                end
            end)
            task.wait(5)
        end
    end)
end

--============================================================
-- RESPAWN
--============================================================

Runtime:connect(player.CharacterAdded, function()
    task.wait(0.75)
    pcall(function()
        if State.NameTags then
            for _, tp in ipairs(Players:GetPlayers()) do
                if tp ~= player then addNameTag(tp) end
            end
        end
    end)
    pcall(function()
        if State.Fullbright then
            applyFB()
            reapplyFullbright()
        end
    end)
end)

--============================================================
-- INIT
--============================================================

task.delay(0.3, function()
    pcall(function()
        if State.Fullbright then applyFB() end
    end)
end)

task.delay(0.7, function()
    pcall(refreshNameTags)
end)

task.delay(1, function()
    pcall(function()
        if State.Notify then
            showNotification("Force", "H / RightShift = menu  •  F4 = freecam", PLAYER_COLOR)
        end
    end)
end)

print("[Force] Loaded OK")