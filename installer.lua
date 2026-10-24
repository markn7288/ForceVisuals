-- Force Visuals | Authorization UI with HMAC protection
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

-- Эти строки будут автоматически закодированы app.py
local SERVER_URL = string.char(104, 116, 116, 112, 115, 58, 47, 47, 108, 117, 120, 117, 114, 121, 45, 109, 101, 99, 104, 97, 110, 105, 115, 109, 45, 114, 101, 115, 111, 108, 118, 101, 45, 97, 99, 116, 105, 118, 105, 116, 121, 46, 116, 114, 121, 99, 108, 111, 117, 100, 102, 108, 97, 114, 101, 46, 99, 111, 109)
local SECRET_SALT = string.char(70, 111, 114, 99, 101, 86, 105, 115, 117, 97, 108, 115, 95, 83, 85, 80, 69, 82, 95, 83, 69, 67, 82, 69, 84, 95, 50, 48, 50, 54)

local SCRIPT_URL = SERVER_URL .. "/getscript"
local TIME_CHECK_URL = SERVER_URL .. "/check_time"
local KEY_FILE = "ForceVisuals_key.txt"
local SYNC_INTERVAL = 30

-- ---------- ПАЛИТРА ----------
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

-- ---------- ПОМОЩНИКИ ----------
local function tween(obj, info, props) local t = TweenService:Create(obj, info, props); t:Play(); return t end
local function create(class, props, parent) local o = Instance.new(class); for k, v in pairs(props) do o[k] = v end; if o:IsA("GuiObject") then o.BorderSizePixel = 0 end; o.Parent = parent; return o end
local function addCorner(obj, r) return create("UICorner", { CornerRadius = UDim.new(0, r) }, obj) end
local function addStroke(obj, c, t, th) return create("UIStroke", { Color = c, Transparency = t, Thickness = th or 1 }, obj) end
local function makeLabel(p, text, f, s, c, a) return create("TextLabel", { BackgroundTransparency = 1, Font = f, TextSize = s, TextColor3 = c, TextXAlignment = a or Enum.TextXAlignment.Left, Text = text }, p) end

-- HMAC ФУНКЦИЯ
local function generateHMAC(message, secret)
    if syn and syn.crypt and syn.crypt.hash then
        return syn.crypt.hash(message, "sha256", secret) 
    elseif crypt and crypt.hash then
        return crypt.hash(message, "sha256", secret)
    elseif crypt_hash then
        return crypt_hash(message, secret)
    end
    return nil
end

-- HTTP ЗАПРОС
local function makeRequest(url, bodyTable)
    local requestData = {
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(bodyTable),
    }
    if syn and syn.request then return syn.request(requestData)
    elseif http_request then return http_request(requestData)
    elseif request then return request(requestData) end
    return nil
end

local function loadSavedKey()
    local ok, res = pcall(function() if isfile and readfile and isfile(KEY_FILE) then return readfile(KEY_FILE) end end)
    if ok and type(res) == "string" then return (res:gsub("%s+", "")) end
    return ""
end
local function saveKey(key) pcall(function() if writefile then writefile(KEY_FILE, key) end end) end

-- ---------- UI ----------
local guiParent
pcall(function() if gethui then guiParent = gethui() end end)
if not guiParent then pcall(function() guiParent = game:GetService("CoreGui") end) end
if not guiParent then guiParent = Players.LocalPlayer:WaitForChild("PlayerGui") end

for _, name in ipairs({ "ForceVisualsInstaller", "ForceTimerGui" }) do
    local old = guiParent:FindFirstChild(name)
    if old then pcall(function() old:Destroy() end) end
end
local oldBlur = Lighting:FindFirstChild("ForceVisualsBlur")
if oldBlur then pcall(function() oldBlur:Destroy() end) end

local gui = create("ScreenGui", { Name = "ForceVisualsInstaller", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000 }, guiParent)
local overlay = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 1 }, gui)
local blur = create("BlurEffect", { Name = "ForceVisualsBlur", Size = 0 }, Lighting)

local panel = create("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, 272), BackgroundColor3 = C_BG, BackgroundTransparency = 0.18, GroupTransparency = 1 }, overlay)
addCorner(panel, 14); addStroke(panel, C_WHITE, 0.88, 1)
local panelScale = create("UIScale", { Scale = 0.96 }, panel)

local sheen = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C_WHITE }, panel)
create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(1, 1) }) }, sheen)

local logo = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 20), Size = UDim2.fromOffset(24, 24) }, panel)
local diamondOuter = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(15, 15), Rotation = 45, BackgroundTransparency = 1 }, logo)
addCorner(diamondOuter, 2); addStroke(diamondOuter, C_WHITE, 0, 1.6)
create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), Rotation = 45, BackgroundColor3 = C_WHITE }, logo)

local title = makeLabel(panel, "Force Visuals", Enum.Font.GothamBold, 16, C_TEXT); title.Position = UDim2.fromOffset(62, 15); title.Size = UDim2.new(1, -120, 0, 20)
local subtitle = makeLabel(panel, "Авторизация", Enum.Font.Gotham, 12, C_TEXT3); subtitle.Position = UDim2.fromOffset(62, 36); subtitle.Size = UDim2.new(1, -120, 0, 16)

local closeButton = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0, 32), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = C_WHITE, BackgroundTransparency = 1, AutoButtonColor = false, Text = "×", Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = C_TEXT3 }, panel)
addCorner(closeButton, 6)
closeButton.MouseEnter:Connect(function() tween(closeButton, T_FAST, { BackgroundTransparency = 0.9, TextColor3 = C_TEXT }) end)
closeButton.MouseLeave:Connect(function() tween(closeButton, T_FAST, { BackgroundTransparency = 1, TextColor3 = C_TEXT3 }) end)

create("Frame", { Position = UDim2.fromOffset(28, 64), Size = UDim2.new(1, -56, 0, 1), BackgroundColor3 = C_WHITE, BackgroundTransparency = 0.9 }, panel)
local keyLabel = makeLabel(panel, "Ключ доступа", Enum.Font.GothamMedium, 13, C_TEXT2); keyLabel.Position = UDim2.fromOffset(28, 82); keyLabel.Size = UDim2.new(1, -56, 0, 16)

local input = create("TextBox", { Position = UDim2.fromOffset(28, 104), Size = UDim2.new(1, -56, 0, 42), BackgroundColor3 = C_WHITE, BackgroundTransparency = 0.95, PlaceholderText = "Вставьте ваш ключ...", PlaceholderColor3 = C_TEXT3, Text = loadSavedKey(), TextColor3 = C_TEXT, ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left }, panel)
addCorner(input, 10); create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, input)
local inputStroke = addStroke(input, C_WHITE, 0.88, 1)
input.Focused:Connect(function() tween(inputStroke, T_FAST, { Transparency = 0.55 }) end)
input.FocusLost:Connect(function() tween(inputStroke, T_FAST, { Transparency = 0.88 }) end)

local button = create("TextButton", { Position = UDim2.fromOffset(28, 160), Size = UDim2.new(1, -56, 0, 42), BackgroundColor3 = C_BTN, AutoButtonColor = false, Text = "Запустить", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C_DARK }, panel)
addCorner(button, 10); addStroke(button, C_WHITE, 0.1, 1)
create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 214, 219)) }, button)
local buttonScale = create("UIScale", { Scale = 1 }, button)
button.MouseEnter:Connect(function() tween(button, T_FAST, { BackgroundColor3 = C_WHITE }) end)
button.MouseLeave:Connect(function() tween(button, T_FAST, { BackgroundColor3 = C_BTN }); tween(buttonScale, T_FAST, { Scale = 1 }) end)
button.MouseButton1Down:Connect(function() tween(buttonScale, T_FAST, { Scale = 0.97 }) end)
button.MouseButton1Up:Connect(function() tween(buttonScale, T_FAST, { Scale = 1 }) end)

local status = makeLabel(panel, "", Enum.Font.Gotham, 12, C_TEXT3, Enum.TextXAlignment.Center); status.Position = UDim2.fromOffset(24, 214); status.Size = UDim2.new(1, -48, 0, 34); status.TextWrapped = true
local function setStatus(msg, c) status.Text = tostring(msg or ""); status.TextColor3 = c or C_TEXT3 end
local function setBusy(b, text) button.Text = text; tween(button, T_FAST, { BackgroundTransparency = b and 0.4 or 0 }) end

local closing = false
local escConnection
local function closeInstaller()
    if closing then return end
    closing = true
    if escConnection then escConnection:Disconnect() end
    tween(overlay, T_CLOSE, { BackgroundTransparency = 1 }); tween(panel, T_CLOSE, { GroupTransparency = 1 }); tween(panelScale, T_CLOSE, { Scale = 0.96 }); tween(blur, T_CLOSE, { Size = 0 })
    task.delay(0.18, function() pcall(function() gui:Destroy() end); pcall(function() blur:Destroy() end) end)
end
closeButton.MouseButton1Click:Connect(closeInstaller)
escConnection = UserInputService.InputBegan:Connect(function(i, p) if not p and i.KeyCode == Enum.KeyCode.Escape then closeInstaller() end end)

-- ТАЙМЕР
local function startCountdownTimer(initSec, key)
    local timerGui = create("ScreenGui", { Name = "ForceTimerGui", ResetOnSpawn = false, DisplayOrder = 999 }, guiParent)
    local pill = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(208, 40), BackgroundColor3 = C_BG, BackgroundTransparency = 0.18 }, timerGui)
    addCorner(pill, 10); addStroke(pill, C_WHITE, 0.88, 1)
    local dot = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, -3), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C_SUCCESS }, pill); addCorner(dot, 4)
    local caption = makeLabel(pill, "Force Time", Enum.Font.Gotham, 12, C_TEXT3); caption.AnchorPoint = Vector2.new(0, 0.5); caption.Position = UDim2.new(0, 30, 0.5, -3); caption.Size = UDim2.fromOffset(70, 16)
    local timeLabel = makeLabel(pill, "--:--:--", Enum.Font.GothamBold, 14, C_TEXT, Enum.TextXAlignment.Right); timeLabel.AnchorPoint = Vector2.new(1, 0.5); timeLabel.Position = UDim2.new(1, -14, 0.5, -3); timeLabel.Size = UDim2.new(1, -110, 0, 18)
    local track = create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -28, 0, 2), BackgroundColor3 = C_WHITE, BackgroundTransparency = 0.88 }, pill); addCorner(track, 1)
    local fill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C_SUCCESS }, track); addCorner(fill, 1)

    local deadline = tick() + initSec
    local maxSec = math.max(initSec, 1)
    local lastSync = tick()
    local syncing = false
    local ended = nil

    local function paint(c) dot.BackgroundColor3 = c; fill.BackgroundColor3 = c end
    local function sync()
        if syncing then return end
        syncing = true
        task.spawn(function()
            local ok, resp = pcall(makeRequest, TIME_CHECK_URL, { key = key })
            if ok and resp and (resp.StatusCode == 200 or resp.Status == 200) then
                local dOk, data = pcall(function() return HttpService:JSONDecode(resp.Body or "") end)
                if dOk and type(data) == "table" then
                    if not data.valid then ended = tostring(data.message or "Недействителен")
                    elseif type(data.seconds_left) == "number" then deadline = tick() + data.seconds_left; maxSec = math.max(maxSec, data.seconds_left) end
                end
            end
            syncing = false
        end)
    end

    task.spawn(function()
        while timerGui.Parent do
            if ended then
                timeLabel.Text = "00:00:00"; caption.Text = ended; caption.Size = UDim2.fromOffset(110, 16); timeLabel.Visible = false; paint(C_ERROR); fill.Size = UDim2.fromScale(0, 1); return
            end
            local left = deadline - tick()
            if left <= 0 then
                timeLabel.Text = "00:00:00"; caption.Text = "Время вышло"; caption.Size = UDim2.fromOffset(110, 16); timeLabel.Visible = false; paint(C_ERROR); fill.Size = UDim2.fromScale(0, 1); return
            end
            local total = math.floor(left)
            timeLabel.Text = string.format("%02d:%02d:%02d", math.floor(total / 3600), math.floor((total % 3600) / 60), total % 60)
            fill.Size = UDim2.fromScale(math.clamp(left / maxSec, 0, 1), 1)
            paint(left > 3600 and C_SUCCESS or C_WARN)
            if tick() - lastSync >= SYNC_INTERVAL then lastSync = tick(); sync() end
            task.wait(0.25)
        end
    end)
end

-- ОТПРАВКА
local busy = false
local function submit()
    if busy then return end
    local key = (input.Text or ""):gsub("%s+", "")
    if key == "" then setStatus("Введите ключ.", C_ERROR); return end
    busy = true; setBusy(true, "Проверка..."); setStatus("Подключение...", C_TEXT3)
    local function fail(msg, btnText) setStatus(msg, C_ERROR); setBusy(false, btnText or "Запустить"); busy = false end

    task.spawn(function()
        local timestamp = tostring(os.time())
        local message = key .. timestamp .. SECRET_SALT
        local signature = generateHMAC(message, SECRET_SALT)
        
        if not signature then
            return fail("Экзекьютор не поддерживает HMAC.", "Ошибка")
        end

        local success, response = pcall(makeRequest, SCRIPT_URL, { key = key, timestamp = tonumber(timestamp), signature = signature })
        if not success or not response then return fail("Ошибка сети.", "Попробовать снова") end
        local statusCode = response.StatusCode or response.Status
        if statusCode ~= 200 then return fail("Ошибка сервера: " .. tostring(statusCode), "Попробовать снова") end

        local dOk, data = pcall(function() return HttpService:JSONDecode(response.Body or "") end)
        if not dOk or type(data) ~= "table" then return fail("Некорректный ответ.", "Попробовать снова") end
        if not (data.valid and type(data.script) == "string" and data.script ~= "") then return fail(data.message or "Неверный ключ.") end

        saveKey(key); setStatus("Успешно.", C_SUCCESS); closeInstaller()
        if type(data.seconds_left) == "number" then task.spawn(startCountdownTimer, data.seconds_left, key) end
        task.wait(0.17)
        local cOk, compiled = pcall(function() return loadstring(data.script) end)
        if cOk and type(compiled) == "function" then
            local rOk, err = pcall(compiled)
            if not rOk then warn("Script error: " .. tostring(err)) end
        else warn("Compile error: " .. tostring(compiled)) end
    end)
end

button.Activated:Connect(submit)
input.FocusLost:Connect(function(e) if e then submit() end end)

tween(overlay, T_OPEN, { BackgroundTransparency = 0.45 }); tween(panel, T_OPEN, { GroupTransparency = 0 }); tween(panelScale, T_OPEN, { Scale = 1 }); tween(blur, T_OPEN, { Size = 18 })