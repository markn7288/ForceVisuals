-- Force Visuals | Authorization UI
-- Стиль как у панели ключей: тёмное стекло, белая основная кнопка, ромб-логотип.
-- Логика авторизации сохранена (/getscript, /check_time).

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local SERVER_URL = "https://governance-democrats-double-ohio.trycloudflare.com"
local SCRIPT_URL = SERVER_URL .. "/getscript"
local TIME_CHECK_URL = SERVER_URL .. "/check_time"
local KEY_FILE = "ForceVisuals_key.txt" -- последний введённый ключ подставляется автоматически
local SYNC_INTERVAL = 30                -- как часто таймер сверяется с сервером (сек)

-- ---------- палитра ----------
local C_BG = Color3.fromRGB(24, 24, 28)
local C_WHITE = Color3.fromRGB(255, 255, 255)
local C_DARK = Color3.fromRGB(11, 11, 13)
local C_TEXT = Color3.fromRGB(244, 244, 245)
local C_TEXT2 = Color3.fromRGB(161, 161, 170)
local C_TEXT3 = Color3.fromRGB(113, 113, 122)
local C_ERROR = Color3.fromRGB(248, 113, 113)
local C_WARN = Color3.fromRGB(242, 184, 99)
local C_SUCCESS = Color3.fromRGB(110, 231, 160)
local C_BTN = Color3.fromRGB(240, 240, 243)

local T_OPEN = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
local T_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local T_CLOSE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- ---------- помощники ----------
local function tween(obj, info, props)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function create(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
    o.Parent = parent
    return o
end

local function addCorner(obj, radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius) }, obj)
end

local function addStroke(obj, color, transparency, thickness)
    return create("UIStroke", { Color = color, Transparency = transparency, Thickness = thickness or 1 }, obj)
end

local function makeLabel(parent, text, font, size, color, xAlign)
    return create("TextLabel", {
        BackgroundTransparency = 1,
        Font = font,
        TextSize = size,
        TextColor3 = color,
        TextXAlignment = xAlign or Enum.TextXAlignment.Left,
        Text = text,
    }, parent)
end

local function makeRequest(url, key)
    local requestData = {
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode({ key = key }),
    }

    if syn and syn.request then
        return syn.request(requestData)
    elseif http_request then
        return http_request(requestData)
    elseif request then
        return request(requestData)
    end
    return nil
end

local function loadSavedKey()
    local ok, res = pcall(function()
        if isfile and readfile and isfile(KEY_FILE) then
            return readfile(KEY_FILE)
        end
    end)
    if ok and type(res) == "string" then
        return (res:gsub("%s+", ""))
    end
    return ""
end

local function saveKey(key)
    pcall(function()
        if writefile then writefile(KEY_FILE, key) end
    end)
end

-- ---------- куда класть интерфейс ----------
local guiParent
pcall(function()
    if gethui then guiParent = gethui() end
end)
if not guiParent then
    pcall(function() guiParent = game:GetService("CoreGui") end)
end
if not guiParent then
    guiParent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- убираем остатки предыдущего запуска
for _, name in ipairs({ "ForceVisualsInstaller", "ForceTimerGui" }) do
    local old = guiParent:FindFirstChild(name)
    if old then pcall(function() old:Destroy() end) end
end
local oldBlur = Lighting:FindFirstChild("ForceVisualsBlur")
if oldBlur then pcall(function() oldBlur:Destroy() end) end

-- ---------- окно авторизации ----------
local gui = create("ScreenGui", {
    Name = "ForceVisualsInstaller",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 1000,
}, guiParent)

local overlay = create("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 1,
}, gui)

local blur = create("BlurEffect", { Name = "ForceVisualsBlur", Size = 0 }, Lighting)

local panel = create("CanvasGroup", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(420, 272),
    BackgroundColor3 = C_BG,
    BackgroundTransparency = 0.18,
    GroupTransparency = 1,
}, overlay)
addCorner(panel, 14)
addStroke(panel, C_WHITE, 0.88, 1)

local panelScale = create("UIScale", { Scale = 0.96 }, panel)

-- светлый блик сверху, как у стеклянных панелей на сайте
local sheen = create("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = C_WHITE,
}, panel)
create("UIGradient", {
    Rotation = 90,
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.9),
        NumberSequenceKeypoint.new(0.3, 1),
        NumberSequenceKeypoint.new(1, 1),
    }),
}, sheen)

-- логотип: ромб в ромбе
local logo = create("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(28, 20),
    Size = UDim2.fromOffset(24, 24),
}, panel)
local diamondOuter = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(15, 15),
    Rotation = 45,
    BackgroundTransparency = 1,
}, logo)
addCorner(diamondOuter, 2)
addStroke(diamondOuter, C_WHITE, 0, 1.6)
create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(6, 6),
    Rotation = 45,
    BackgroundColor3 = C_WHITE,
}, logo)

local title = makeLabel(panel, "Force Visuals", Enum.Font.GothamBold, 16, C_TEXT)
title.Position = UDim2.fromOffset(62, 15)
title.Size = UDim2.new(1, -120, 0, 20)

local subtitle = makeLabel(panel, "Авторизация", Enum.Font.Gotham, 12, C_TEXT3)
subtitle.Position = UDim2.fromOffset(62, 36)
subtitle.Size = UDim2.new(1, -120, 0, 16)

local closeButton = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -18, 0, 32),
    Size = UDim2.fromOffset(28, 28),
    BackgroundColor3 = C_WHITE,
    BackgroundTransparency = 1,
    AutoButtonColor = false,
    Text = "×",
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    TextColor3 = C_TEXT3,
}, panel)
addCorner(closeButton, 6)
closeButton.MouseEnter:Connect(function()
    tween(closeButton, T_FAST, { BackgroundTransparency = 0.9, TextColor3 = C_TEXT })
end)
closeButton.MouseLeave:Connect(function()
    tween(closeButton, T_FAST, { BackgroundTransparency = 1, TextColor3 = C_TEXT3 })
end)

create("Frame", {
    Position = UDim2.fromOffset(28, 64),
    Size = UDim2.new(1, -56, 0, 1),
    BackgroundColor3 = C_WHITE,
    BackgroundTransparency = 0.9,
}, panel)

local keyLabel = makeLabel(panel, "Ключ доступа", Enum.Font.GothamMedium, 13, C_TEXT2)
keyLabel.Position = UDim2.fromOffset(28, 82)
keyLabel.Size = UDim2.new(1, -56, 0, 16)

local input = create("TextBox", {
    Position = UDim2.fromOffset(28, 104),
    Size = UDim2.new(1, -56, 0, 42),
    BackgroundColor3 = C_WHITE,
    BackgroundTransparency = 0.95,
    PlaceholderText = "Вставьте ваш ключ...",
    PlaceholderColor3 = C_TEXT3,
    Text = loadSavedKey(),
    TextColor3 = C_TEXT,
    ClearTextOnFocus = false,
    Font = Enum.Font.Gotham,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
addCorner(input, 10)
create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, input)
local inputStroke = addStroke(input, C_WHITE, 0.88, 1)
input.Focused:Connect(function()
    tween(inputStroke, T_FAST, { Transparency = 0.55 })
end)
input.FocusLost:Connect(function()
    tween(inputStroke, T_FAST, { Transparency = 0.88 })
end)

local button = create("TextButton", {
    Position = UDim2.fromOffset(28, 160),
    Size = UDim2.new(1, -56, 0, 42),
    BackgroundColor3 = C_BTN,
    AutoButtonColor = false,
    Text = "Запустить",
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextColor3 = C_DARK,
}, panel)
addCorner(button, 10)
addStroke(button, C_WHITE, 0.1, 1)
create("UIGradient", {
    Rotation = 90,
    Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 214, 219)),
}, button)
local buttonScale = create("UIScale", { Scale = 1 }, button)
button.MouseEnter:Connect(function()
    tween(button, T_FAST, { BackgroundColor3 = C_WHITE })
end)
button.MouseLeave:Connect(function()
    tween(button, T_FAST, { BackgroundColor3 = C_BTN })
    tween(buttonScale, T_FAST, { Scale = 1 })
end)
button.MouseButton1Down:Connect(function()
    tween(buttonScale, T_FAST, { Scale = 0.97 })
end)
button.MouseButton1Up:Connect(function()
    tween(buttonScale, T_FAST, { Scale = 1 })
end)

local status = makeLabel(panel, "", Enum.Font.Gotham, 12, C_TEXT3, Enum.TextXAlignment.Center)
status.Position = UDim2.fromOffset(24, 214)
status.Size = UDim2.new(1, -48, 0, 34)
status.TextWrapped = true

local function setStatus(message, color)
    status.Text = tostring(message or "")
    status.TextColor3 = color or C_TEXT3
end

local function setBusy(isBusy, text)
    button.Text = text
    tween(button, T_FAST, { BackgroundTransparency = isBusy and 0.4 or 0 })
end

-- ---------- закрытие ----------
local closing = false
local escConnection
local function closeInstaller()
    if closing then return end
    closing = true
    if escConnection then escConnection:Disconnect() end
    tween(overlay, T_CLOSE, { BackgroundTransparency = 1 })
    tween(panel, T_CLOSE, { GroupTransparency = 1 })
    tween(panelScale, T_CLOSE, { Scale = 0.96 })
    tween(blur, T_CLOSE, { Size = 0 })
    task.delay(0.18, function()
        pcall(function() gui:Destroy() end)
        pcall(function() blur:Destroy() end)
    end)
end

closeButton.MouseButton1Click:Connect(closeInstaller)
escConnection = UserInputService.InputBegan:Connect(function(inputObject, processed)
    if not processed and inputObject.KeyCode == Enum.KeyCode.Escape then
        closeInstaller()
    end
end)

-- ---------- таймер ----------
local function startCountdownTimer(initialSeconds, key)
    local timerGui = create("ScreenGui", {
        Name = "ForceTimerGui",
        ResetOnSpawn = false,
        DisplayOrder = 999,
    }, guiParent)

    local pill = create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -20, 1, -20),
        Size = UDim2.fromOffset(208, 40),
        BackgroundColor3 = C_BG,
        BackgroundTransparency = 0.18,
    }, timerGui)
    addCorner(pill, 10)
    addStroke(pill, C_WHITE, 0.88, 1)

    local dot = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 14, 0.5, -3),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = C_SUCCESS,
    }, pill)
    addCorner(dot, 4)

    local caption = makeLabel(pill, "Force Time", Enum.Font.Gotham, 12, C_TEXT3)
    caption.AnchorPoint = Vector2.new(0, 0.5)
    caption.Position = UDim2.new(0, 30, 0.5, -3)
    caption.Size = UDim2.fromOffset(70, 16)

    local timeLabel = makeLabel(pill, "--:--:--", Enum.Font.GothamBold, 14, C_TEXT, Enum.TextXAlignment.Right)
    timeLabel.AnchorPoint = Vector2.new(1, 0.5)
    timeLabel.Position = UDim2.new(1, -14, 0.5, -3)
    timeLabel.Size = UDim2.new(1, -110, 0, 18)

    local track = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -6),
        Size = UDim2.new(1, -28, 0, 2),
        BackgroundColor3 = C_WHITE,
        BackgroundTransparency = 0.88,
    }, pill)
    addCorner(track, 1)
    local fill = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C_SUCCESS,
    }, track)
    addCorner(fill, 1)

    local deadline = tick() + initialSeconds
    local maxSeconds = math.max(initialSeconds, 1)
    local lastSync = tick()
    local syncing = false
    local ended -- nil, либо текст причины, если ключ удалён/истёк по данным сервера

    local function paint(color)
        dot.BackgroundColor3 = color
        fill.BackgroundColor3 = color
    end

    local function syncWithServer()
        if syncing then return end
        syncing = true
        task.spawn(function()
            local ok, response = pcall(makeRequest, TIME_CHECK_URL, key)
            if ok and response and (response.StatusCode == 200 or response.Status == 200) then
                local decodeOk, data = pcall(function()
                    return HttpService:JSONDecode(response.Body or "")
                end)
                if decodeOk and type(data) == "table" then
                    if not data.valid then
                        ended = tostring(data.message or "Ключ недействителен")
                    elseif type(data.seconds_left) == "number" then
                        -- сервер — источник истины: подхватываем и продление, и сокращение
                        deadline = tick() + data.seconds_left
                        maxSeconds = math.max(maxSeconds, data.seconds_left)
                    end
                end
            end
            syncing = false
        end)
    end

    task.spawn(function()
        while timerGui.Parent do
            if ended then
                timeLabel.Text = "00:00:00"
                caption.Text = ended
                caption.Size = UDim2.fromOffset(110, 16)
                timeLabel.Visible = false
                paint(C_ERROR)
                fill.Size = UDim2.fromScale(0, 1)
                return
            end

            local left = deadline - tick()
            if left <= 0 then
                timeLabel.Text = "00:00:00"
                caption.Text = "Время вышло"
                caption.Size = UDim2.fromOffset(110, 16)
                timeLabel.Visible = false
                paint(C_ERROR)
                fill.Size = UDim2.fromScale(0, 1)
                return
            end

            local total = math.floor(left)
            timeLabel.Text = string.format("%02d:%02d:%02d",
                math.floor(total / 3600), math.floor((total % 3600) / 60), total % 60)
            fill.Size = UDim2.fromScale(math.clamp(left / maxSeconds, 0, 1), 1)
            paint(left > 3600 and C_SUCCESS or C_WARN)

            if tick() - lastSync >= SYNC_INTERVAL then
                lastSync = tick()
                syncWithServer()
            end

            task.wait(0.25)
        end
    end)
end

-- ---------- запуск ----------
local busy = false

local function submit()
    if busy then return end
    local key = (input.Text or ""):gsub("%s+", "") -- ключ часто копируют с пробелами и переносами
    if key == "" then
        setStatus("Введите ключ доступа.", C_ERROR)
        return
    end

    busy = true
    setBusy(true, "Проверка...")
    setStatus("Подключение к серверу...", C_TEXT3)

    local function fail(message, buttonText)
        setStatus(message, C_ERROR)
        setBusy(false, buttonText or "Запустить")
        busy = false
    end

    task.spawn(function()
        local success, response = pcall(makeRequest, SCRIPT_URL, key)
        if not success or not response then
            return fail("Ошибка сети. Экзекьютор не поддерживается.", "Попробовать снова")
        end

        local statusCode = response.StatusCode or response.Status
        if statusCode ~= 200 then
            return fail("Ошибка сервера: " .. tostring(statusCode or "unknown"), "Попробовать снова")
        end

        local decodeOk, data = pcall(function()
            return HttpService:JSONDecode(response.Body or "")
        end)
        if not decodeOk or type(data) ~= "table" then
            return fail("Сервер вернул некорректный ответ.", "Попробовать снова")
        end

        if not (data.valid and type(data.script) == "string" and data.script ~= "") then
            return fail(data.message or "Неверный или истёкший ключ.")
        end

        saveKey(key)
        setStatus("Авторизация успешна.", C_SUCCESS)
        closeInstaller()

        if type(data.seconds_left) == "number" then
            task.spawn(startCountdownTimer, data.seconds_left, key)
        end

        task.wait(0.17)
        local compileOk, compiled = pcall(function()
            return loadstring(data.script)
        end)
        if compileOk and type(compiled) == "function" then
            local runOk, runError = pcall(compiled)
            if not runOk then warn("Script error: " .. tostring(runError)) end
        else
            warn("Failed to compile script: " .. tostring(compiled))
        end
    end)
end

button.Activated:Connect(submit)
input.FocusLost:Connect(function(enterPressed)
    if enterPressed then submit() end
end)

-- появление
tween(overlay, T_OPEN, { BackgroundTransparency = 0.45 })
tween(panel, T_OPEN, { GroupTransparency = 0 })
tween(panelScale, T_OPEN, { Scale = 1 })
tween(blur, T_OPEN, { Size = 18 })
