--[[
AURORA LITE SHADERS • Delta / Roblox (cliente)
Visual local: pós-processamento, brilho especular quando suportado, boost controlado
 de partículas, equalizador de áudio e motion blur de câmera configurável.

IMPORTANTE:
- Não é RTX real nem cria reflexos de espelho. O Roblox não expõe isso a um script local.
- Não substitui texturas/modelos do mapa por versões HD.
- Aumentar partículas pode reduzir FPS; deixe o boost desligado em aparelhos fracos.
- Execute novamente para substituir a interface anterior. Tudo é aplicado localmente.
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Encerra a versão anterior, se o executor permitir compartilhar o ambiente.
local sharedEnv
pcall(function()
    if getgenv then
        sharedEnv = getgenv()
    else
        sharedEnv = _G
    end
end)
if sharedEnv and sharedEnv.__AURORA_LITE_CLEANUP then
    pcall(sharedEnv.__AURORA_LITE_CLEANUP)
    sharedEnv.__AURORA_LITE_CLEANUP = nil
end

local CONNECTIONS = {}
local function keep(connection)
    table.insert(CONNECTIONS, connection)
    return connection
end

local GUI_NAME = "AURORA_LITE_SHADER_GUI"
local oldGui = playerGui:FindFirstChild(GUI_NAME)
if oldGui then oldGui:Destroy() end

local COLORS = {
    Color3.fromRGB(70, 224, 255),  -- Ciano
    Color3.fromRGB(173, 112, 255), -- Roxo
    Color3.fromRGB(255, 190, 82),  -- Dourado
    Color3.fromRGB(98, 255, 164),  -- Verde
    Color3.fromRGB(255, 105, 145), -- Rosa
}
local COLOR_NAMES = {"CIANO", "ROXO", "DOURADO", "VERDE", "ROSA"}
local themeIndex = 1
local accent = COLORS[themeIndex]

-- Cores independentes do tema da interface para o contorno do personagem.
local OUTLINE_COLORS = {
    Color3.fromRGB(70, 224, 255),   -- Ciano
    Color3.fromRGB(173, 112, 255),  -- Roxo
    Color3.fromRGB(255, 190, 82),   -- Dourado
    Color3.fromRGB(98, 255, 164),   -- Verde
    Color3.fromRGB(255, 105, 145),  -- Rosa
    Color3.fromRGB(255, 255, 255),  -- Branco
    Color3.fromRGB(255, 65, 65),    -- Vermelho
    Color3.fromRGB(65, 120, 255),   -- Azul
]
local OUTLINE_COLOR_NAMES = {"CIANO", "ROXO", "DOURADO", "VERDE", "ROSA", "BRANCO", "VERMELHO", "AZUL"}

local settings = {
    graphics = true,
    particles = false,
    sound = false,
    motionBlur = false,
    particleMultiplier = 1.6,
    blurStrength = 6,
    opacity = 0,
    lastOpacity = 0.12,
    presetIndex = 2,
    outline = false,
    outlineColorIndex = 1,
    outlineTransparency = 0,
    orbTransparency = 8,
    orbSize = 48,
}
local presets = {
    {name = "LEVE", bloom = 0.12, bloomSize = 14, threshold = 1.65, contrast = 0.06, saturation = 0.05, brightness = 0, rays = 0.015, raySpread = 0.55, diffuse = 0.75, specular = 0.8},
    {name = "EQUILIBRADO", bloom = 0.28, bloomSize = 22, threshold = 1.45, contrast = 0.12, saturation = 0.12, brightness = 0.015, rays = 0.055, raySpread = 0.7, diffuse = 0.9, specular = 1},
    {name = "CINEMÁTICO", bloom = 0.42, bloomSize = 30, threshold = 1.25, contrast = 0.18, saturation = 0.16, brightness = 0.02, rays = 0.10, raySpread = 0.78, diffuse = 1, specular = 1},
}

-- Outline apenas no próprio personagem, sem preenchimento e sem atravessar paredes.
local characterHighlight
local function applyCharacterOutline()
    local character = player.Character
    if not settings.outline or not character then
        if characterHighlight then
            pcall(function() characterHighlight:Destroy() end)
            characterHighlight = nil
        end
        return
    end

    if not characterHighlight or not characterHighlight.Parent or characterHighlight.Adornee ~= character then
        if characterHighlight then pcall(function() characterHighlight:Destroy() end) end
        characterHighlight = Instance.new("Highlight")
        characterHighlight.Name = "AURORA_LITE_CharacterOutline"
        characterHighlight.Adornee = character
        characterHighlight.FillTransparency = 1
        characterHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
        characterHighlight.Parent = character
    end
    characterHighlight.OutlineColor = OUTLINE_COLORS[settings.outlineColorIndex]
    characterHighlight.OutlineTransparency = math.clamp(settings.outlineTransparency / 100, 0, 1)
    characterHighlight.Enabled = true
end

keep(player.CharacterAdded:Connect(function()
    task.wait(0.25)
    if settings.outline then applyCharacterOutline() end
end))

-- Efeitos de pós-processamento: anexados à câmera para afetar só este cliente.
local bloom = Instance.new("BloomEffect")
bloom.Name = "AURORA_LITE_Bloom"
local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "AURORA_LITE_Color"
local sunRays = Instance.new("SunRaysEffect")
sunRays.Name = "AURORA_LITE_SunRays"
local motionBlur = Instance.new("BlurEffect")
motionBlur.Name = "AURORA_LITE_MotionBlur"
motionBlur.Size = 0
motionBlur.Enabled = false

local originalLighting = {}
pcall(function() originalLighting.EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale end)
pcall(function() originalLighting.EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale end)

local function attachEffectsToCamera()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    bloom.Parent = camera
    colorCorrection.Parent = camera
    sunRays.Parent = camera
    motionBlur.Parent = camera
end
attachEffectsToCamera()
keep(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attachEffectsToCamera))

local function applyPreset()
    local p = presets[settings.presetIndex]
    bloom.Intensity = p.bloom
    bloom.Size = p.bloomSize
    bloom.Threshold = p.threshold
    colorCorrection.Brightness = p.brightness
    colorCorrection.Contrast = p.contrast
    colorCorrection.Saturation = p.saturation
    colorCorrection.TintColor = Color3.fromRGB(235, 244, 255)
    sunRays.Intensity = p.rays
    sunRays.Spread = p.raySpread
    if settings.graphics then
        pcall(function() Lighting.EnvironmentDiffuseScale = p.diffuse end)
        pcall(function() Lighting.EnvironmentSpecularScale = p.specular end)
    else
        pcall(function() if originalLighting.EnvironmentDiffuseScale ~= nil then Lighting.EnvironmentDiffuseScale = originalLighting.EnvironmentDiffuseScale end end)
        pcall(function() if originalLighting.EnvironmentSpecularScale ~= nil then Lighting.EnvironmentSpecularScale = originalLighting.EnvironmentSpecularScale end end)
    end
    bloom.Enabled = settings.graphics
    colorCorrection.Enabled = settings.graphics
    sunRays.Enabled = settings.graphics
end
applyPreset()

local emitterOriginals = setmetatable({}, {__mode = "k"})
local audioEffects = setmetatable({}, {__mode = "k"})

local function rememberEmitter(emitter)
    if not emitterOriginals[emitter] then
        local data = {}
        pcall(function() data.Rate = emitter.Rate end)
        pcall(function() data.LightEmission = emitter.LightEmission end)
        emitterOriginals[emitter] = data
    end
end

local function updateEmitter(emitter)
    if not emitter or not emitter.Parent or not emitter:IsA("ParticleEmitter") then return end
    rememberEmitter(emitter)
    local original = emitterOriginals[emitter]
    if settings.particles then
        if original.Rate ~= nil then
            pcall(function() emitter.Rate = math.clamp(original.Rate * settings.particleMultiplier, 0, 90) end)
        end
        if original.LightEmission ~= nil then
            pcall(function() emitter.LightEmission = math.clamp(math.max(original.LightEmission, 0.45), 0, 1) end)
        end
    else
        if original.Rate ~= nil then pcall(function() emitter.Rate = original.Rate end) end
        if original.LightEmission ~= nil then pcall(function() emitter.LightEmission = original.LightEmission end) end
    end
end

local function updateAllEmitters()
    for _, instance in ipairs(Workspace:GetDescendants()) do
        if instance:IsA("ParticleEmitter") then updateEmitter(instance) end
    end
end

local function addAudioEnhancement(sound)
    if not sound or not sound:IsA("Sound") or not sound.Parent or audioEffects[sound] then return end
    local eq = Instance.new("EqualizerSoundEffect")
    eq.Name = "AURORA_LITE_EQ_LOCAL"
    eq.LowGain = 2.0
    eq.MidGain = 0.5
    eq.HighGain = 1.5
    eq.Enabled = true
    eq.Parent = sound
    audioEffects[sound] = eq
end

local function setAudioEnhancement(enabled)
    settings.sound = enabled
    if enabled then
        for _, instance in ipairs(Workspace:GetDescendants()) do
            if instance:IsA("Sound") then addAudioEnhancement(instance) end
        end
        for _, instance in ipairs(SoundService:GetDescendants()) do
            if instance:IsA("Sound") then addAudioEnhancement(instance) end
        end
    else
        for sound, effect in pairs(audioEffects) do
            if effect and effect.Parent then effect:Destroy() end
            audioEffects[sound] = nil
        end
    end
end

keep(Workspace.DescendantAdded:Connect(function(instance)
    if instance:IsA("ParticleEmitter") then
        if settings.particles then task.defer(updateEmitter, instance) else rememberEmitter(instance) end
    elseif settings.sound and instance:IsA("Sound") then
        task.defer(addAudioEnhancement, instance)
    end
end))
keep(SoundService.DescendantAdded:Connect(function(instance)
    if settings.sound and instance:IsA("Sound") then task.defer(addAudioEnhancement, instance) end
end))

-- Interface
local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function addCorner(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = object
    return corner
end

local function addStroke(object, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or accent
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0.2
    stroke.Parent = object
    return stroke
end

local function addGradient(object)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 33, 54)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 15, 27)),
    })
    gradient.Rotation = 35
    gradient.Parent = object
    return gradient
end

local panel = Instance.new("CanvasGroup")
panel.Name = "ShaderPanel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.BackgroundColor3 = Color3.fromRGB(13, 19, 32)
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.Visible = false
panel.GroupTransparency = 0
panel.ClipsDescendants = true
panel.Parent = gui
local function resizePanel()
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(900, 700)
    local width = math.max(280, math.min(viewport.X - 24, 1280))
    local height = math.max(360, math.min(viewport.Y - 86, 820))
    panel.Size = UDim2.fromOffset(width, height)
    panel.Position = UDim2.fromOffset(math.max(8, (viewport.X - width) / 2), math.max(8, (viewport.Y - height) / 2))
end
resizePanel()
addCorner(panel, 17)
local panelStroke = addStroke(panel, accent, 1.5, 0.13)
addGradient(panel)
keep(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(resizePanel))

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 56)
header.BackgroundColor3 = Color3.fromRGB(18, 29, 47)
header.BackgroundTransparency = 0.12
header.BorderSizePixel = 0
header.Parent = panel
addCorner(header, 16)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(16, 7)
title.Size = UDim2.new(1, -74, 0, 25)
title.Font = Enum.Font.GothamBold
title.Text = "✦ AURORA LITE SHADERS"
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = accent
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(17, 31)
subtitle.Size = UDim2.new(1, -78, 0, 16)
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "PAINEL DE CONFIGURAÇÃO  •  LOCAL"
subtitle.TextSize = 8
subtitle.TextColor3 = Color3.fromRGB(155, 174, 198)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "Minimize"
minimizeButton.Size = UDim2.fromOffset(32, 30)
minimizeButton.Position = UDim2.new(1, -42, 0, 12)
minimizeButton.BackgroundColor3 = Color3.fromRGB(34, 47, 67)
minimizeButton.Text = "—"
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 16
minimizeButton.TextColor3 = Color3.fromRGB(240, 245, 255)
minimizeButton.AutoButtonColor = true
minimizeButton.Parent = header
addCorner(minimizeButton, 9)

-- Layout principal: navegação por categorias à esquerda e opções à direita.
local sidebarWidth = math.clamp(panel.Size.X.Offset * 0.26, 92, 174)
local sidebar = Instance.new("Frame")
sidebar.Name = "Categories"
sidebar.Position = UDim2.fromOffset(10, 66)
sidebar.Size = UDim2.new(0, sidebarWidth, 1, -76)
sidebar.BackgroundColor3 = Color3.fromRGB(17, 26, 42)
sidebar.BackgroundTransparency = 0.08
sidebar.BorderSizePixel = 0
sidebar.Parent = panel
addCorner(sidebar, 12)

local sidebarTitle = Instance.new("TextLabel")
sidebarTitle.BackgroundTransparency = 1
sidebarTitle.Position = UDim2.fromOffset(10, 8)
sidebarTitle.Size = UDim2.new(1, -20, 0, 18)
sidebarTitle.Font = Enum.Font.GothamBold
sidebarTitle.Text = "CATEGORIAS"
sidebarTitle.TextSize = 9
sidebarTitle.TextColor3 = Color3.fromRGB(125, 148, 176)
sidebarTitle.TextXAlignment = Enum.TextXAlignment.Left
sidebarTitle.Parent = sidebar

local categoryList = Instance.new("UIListLayout")
categoryList.Padding = UDim.new(0, 7)
categoryList.SortOrder = Enum.SortOrder.LayoutOrder
categoryList.Parent = sidebar
sidebarTitle.LayoutOrder = 0

local categoryEntries = {
    {key = "Visual", label = "✧  VISUAL"},
    {key = "Particulas", label = "✦  PARTÍCULAS"},
    {key = "AudioCamera", label = "♫  ÁUDIO / CÂMERA"},
    {key = "Interface", label = "⚙  INTERFACE"},
    {key = "Outline", label = "◈  OUTLINE"},
}
local pages, navButtons = {}, {}
local activeCategory = "Visual"
local scroll
local function setActiveCategory(key)
    activeCategory = key
    for name, page in pairs(pages) do page.Visible = (name == key) end
    for name, button in pairs(navButtons) do
        local selected = (name == key)
        button.BackgroundColor3 = selected and Color3.fromRGB(27, 66, 82) or Color3.fromRGB(23, 35, 53)
        button.TextColor3 = selected and accent or Color3.fromRGB(183, 198, 218)
        local stroke = button:FindFirstChildOfClass("UIStroke")
        if stroke then stroke.Color = selected and accent or Color3.fromRGB(70, 89, 116); stroke.Transparency = selected and 0.15 or 0.7 end
    end
    scroll = pages[key]
end

local mainContent = Instance.new("Frame")
mainContent.Name = "CategoryContent"
mainContent.Position = UDim2.fromOffset(sidebarWidth + 20, 66)
mainContent.Size = UDim2.new(1, -(sidebarWidth + 30), 1, -76)
mainContent.BackgroundTransparency = 1
mainContent.BorderSizePixel = 0
mainContent.Parent = panel

for index, entry in ipairs(categoryEntries) do
    local button = Instance.new("TextButton")
    button.Name = "Category_" .. entry.key
    button.Position = UDim2.fromOffset(6, 32 + (index - 1) * 43)
    button.Size = UDim2.new(1, -12, 0, 37)
    button.BackgroundColor3 = Color3.fromRGB(23, 35, 53)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamSemibold
    button.Text = entry.label
    button.TextSize = 9
    button.TextWrapped = true
    button.TextColor3 = Color3.fromRGB(183, 198, 218)
    button.AutoButtonColor = true
    button.LayoutOrder = index
    button.Parent = sidebar
    addCorner(button, 9)
    addStroke(button, Color3.fromRGB(70, 89, 116), 1, 0.7)
    navButtons[entry.key] = button
    button.Activated:Connect(function() setActiveCategory(entry.key) end)

    local page = Instance.new("ScrollingFrame")
    page.Name = "Page_" .. entry.key
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = accent
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.Visible = false
    page.Parent = mainContent
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 7)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = page
    pages[entry.key] = page
end
setActiveCategory("Visual")

local function makeActionButton(text, order, height)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -2, 0, height or 36)
    button.BackgroundColor3 = Color3.fromRGB(24, 35, 53)
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Font = Enum.Font.GothamSemibold
    button.Text = text
    button.TextSize = 11
    button.TextColor3 = Color3.fromRGB(232, 240, 252)
    button.LayoutOrder = order
    button.Parent = scroll
    addCorner(button, 10)
    addStroke(button, Color3.fromRGB(77, 101, 132), 1, 0.66)
    return button
end

local function addSection(text, order)
    local categoryBySection = {
        ["ILUMINAÇÃO E COR"] = "Visual",
        ["EFEITOS DE ITENS"] = "Particulas",
        ["ÁUDIO E CÂMERA"] = "AudioCamera",
        ["INTERFACE"] = "Interface",
        ["CONTORNO DO PERSONAGEM"] = "Outline",
    }
    local category = categoryBySection[text]
    if category then setActiveCategory(category) end
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -2, 0, 22)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = "  " .. text
    label.TextSize = 10
    label.TextColor3 = accent
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = 1
    label.Parent = scroll
    return label
end

local function addToggle(labelText, order, getter, setter)
    local button = makeActionButton("", order, 35)
    local function refresh()
        local on = getter()
        button.Text = labelText .. (on and "     ●  ON" or "     ○  OFF")
        button.TextColor3 = on and Color3.fromRGB(239, 250, 255) or Color3.fromRGB(183, 196, 214)
        button.BackgroundColor3 = on and Color3.fromRGB(24, 58, 70) or Color3.fromRGB(24, 35, 53)
        local stroke = button:FindFirstChildOfClass("UIStroke")
        if stroke then stroke.Color = on and accent or Color3.fromRGB(77, 101, 132) end
    end
    button.Activated:Connect(function()
        setter(not getter())
        refresh()
    end)
    refresh()
    return {button = button, refresh = refresh}
end

local activeSliderUpdate, launcher, dot, orbStroke

local function addSlider(labelText, order, minValue, maxValue, initialValue, suffix, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -2, 0, 51)
    holder.BackgroundColor3 = Color3.fromRGB(20, 30, 47)
    holder.BackgroundTransparency = 0.04
    holder.BorderSizePixel = 0
    holder.LayoutOrder = order
    holder.Parent = scroll
    addCorner(holder, 10)
    addStroke(holder, Color3.fromRGB(74, 94, 123), 1, 0.74)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(9, 4)
    label.Size = UDim2.new(1, -18, 0, 17)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 10
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.fromRGB(221, 232, 246)
    label.Parent = holder

    local rail = Instance.new("TextButton")
    rail.BackgroundColor3 = Color3.fromRGB(52, 65, 84)
    rail.BorderSizePixel = 0
    rail.Position = UDim2.fromOffset(10, 31)
    rail.Size = UDim2.new(1, -20, 0, 6)
    rail.Text = ""
    rail.AutoButtonColor = false
    rail.Parent = holder
    addCorner(rail, 6)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = accent
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.Parent = rail
    addCorner(fill, 6)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(12, 12)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(245, 250, 255)
    knob.BorderSizePixel = 0
    knob.Parent = rail
    addCorner(knob, 10)
    addStroke(knob, accent, 1.5, 0)

    local value = initialValue
    local function draw()
        local ratio = (value - minValue) / (maxValue - minValue)
        ratio = math.clamp(ratio, 0, 1)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        knob.Position = UDim2.new(ratio, 0, 0.5, 0)
        local formatted
        if suffix == "x" then formatted = string.format("%.1fx", value)
        elseif suffix == "%" then formatted = string.format("%d%%", math.floor(value + 0.5))
        else formatted = string.format("%d", math.floor(value + 0.5)) end
        label.Text = labelText .. "   " .. formatted
        fill.BackgroundColor3 = accent
    end
    local function setFromX(x)
        local width = math.max(rail.AbsoluteSize.X, 1)
        local ratio = math.clamp((x - rail.AbsolutePosition.X) / width, 0, 1)
        value = minValue + ratio * (maxValue - minValue)
        if suffix ~= "x" then value = math.floor(value + 0.5) else value = math.floor(value * 10 + 0.5) / 10 end
        draw()
        callback(value)
    end
    rail.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            setFromX(input.Position.X)
            activeSliderUpdate = setFromX
        end
    end)
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            setFromX(input.Position.X)
            activeSliderUpdate = setFromX
        end
    end)
    draw()
    return {
        holder = holder,
        get = function() return value end,
        set = function(newValue) value = math.clamp(newValue, minValue, maxValue); draw(); callback(value) end,
        setAccent = function() fill.BackgroundColor3 = accent; local stroke = knob:FindFirstChildOfClass("UIStroke"); if stroke then stroke.Color = accent end end,
    }
end

local profileButton, themeButton, graphicsToggle, particleToggle, soundToggle, motionToggle
local particleSlider, blurSlider, opacitySlider
local outlineToggle, outlineColorButton, outlineTransparencySlider
keep(UserInputService.InputChanged:Connect(function(input)
    if activeSliderUpdate and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        activeSliderUpdate(input.Position.X)
    end
end))
keep(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        activeSliderUpdate = nil
    end
end))

addSection("ILUMINAÇÃO E COR", 1)
profileButton = makeActionButton("", 2, 36)
local function refreshProfile()
    profileButton.Text = "PERFIL VISUAL     ▸  " .. presets[settings.presetIndex].name
    profileButton.TextColor3 = accent
end
profileButton.Activated:Connect(function()
    settings.presetIndex = settings.presetIndex % #presets + 1
    applyPreset()
    refreshProfile()
end)
refreshProfile()

graphicsToggle = addToggle("Bloom + cor + raios de sol", 3,
    function() return settings.graphics end,
    function(value)
        settings.graphics = value
        applyPreset()
        if not value then
            pcall(function() if originalLighting.EnvironmentDiffuseScale ~= nil then Lighting.EnvironmentDiffuseScale = originalLighting.EnvironmentDiffuseScale end end)
            pcall(function() if originalLighting.EnvironmentSpecularScale ~= nil then Lighting.EnvironmentSpecularScale = originalLighting.EnvironmentSpecularScale end end)
        else
            applyPreset()
        end
    end)

addSection("EFEITOS DE ITENS", 4)
particleToggle = addToggle("Boost de partículas (local)", 5,
    function() return settings.particles end,
    function(value)
        settings.particles = value
        updateAllEmitters()
    end)
particleSlider = addSlider("Quantidade de partículas", 6, 1, 2.5, settings.particleMultiplier, "x", function(value)
    settings.particleMultiplier = value
    if settings.particles then updateAllEmitters() end
end)

addSection("ÁUDIO E CÂMERA", 7)
soundToggle = addToggle("Áudio mais encorpado (EQ leve)", 8,
    function() return settings.sound end,
    function(value) setAudioEnhancement(value) end)
motionToggle = addToggle("Motion blur dinâmico", 9,
    function() return settings.motionBlur end,
    function(value)
        settings.motionBlur = value
        motionBlur.Enabled = value
        if not value then motionBlur.Size = 0 end
    end)
blurSlider = addSlider("Força do motion blur", 10, 0, 14, settings.blurStrength, "", function(value)
    settings.blurStrength = value
    if value <= 0 then motionBlur.Size = 0 end
end)

addSection("INTERFACE", 11)
opacitySlider = addSlider("Transparência da janela", 12, 0, 100, settings.opacity, "%", function(value)
    local previousOpacity = settings.opacity
    settings.opacity = value
    if value >= 100 then
        if previousOpacity < 85 then settings.lastOpacity = previousOpacity / 100 end
        panel.Visible = false
        launcher.Visible = false
        dot.Visible = true
    elseif value >= 85 then
        if previousOpacity < 85 then settings.lastOpacity = previousOpacity / 100 end
        panel.GroupTransparency = value / 100
        panel.Visible = true
        launcher.Visible = false
        dot.Visible = true
    else
        settings.lastOpacity = math.clamp(value / 100, 0, 0.84)
        panel.GroupTransparency = value / 100
        panel.Visible = true
        launcher.Visible = false
        dot.Visible = false
    end
end)

local orbTransparencySlider = addSlider("Transparência da bolinha", 13, 0, 90, settings.orbTransparency, "%", function(value)
    settings.orbTransparency = value
    if launcher then launcher.BackgroundTransparency = value / 100; launcher.TextTransparency = value / 100 end
    if orbStroke then orbStroke.Transparency = math.clamp(value / 100, 0.02, 0.95) end
end)
local orbSizeSlider = addSlider("Tamanho da bolinha", 14, 34, 72, settings.orbSize, "", function(value)
    settings.orbSize = value
    if launcher then launcher.Size = UDim2.fromOffset(value, value) end
    if dot and launcher then dot.Position = UDim2.fromOffset(launcher.Position.X.Offset + value / 2 - 5, launcher.Position.Y.Offset + value / 2 - 5) end
end)

themeButton = makeActionButton("Cor do menu     ▸  CIANO", 15, 35)
themeButton.Activated:Connect(function()
    themeIndex = themeIndex % #COLORS + 1
    accent = COLORS[themeIndex]
    panelStroke.Color = accent
    title.TextColor3 = accent
    scroll.ScrollBarImageColor3 = accent
    refreshProfile()
    themeButton.Text = "Cor do menu     ▸  " .. COLOR_NAMES[themeIndex]
    themeButton.TextColor3 = accent
    if orbStroke then orbStroke.Color = accent end
    if launcher then launcher.TextColor3 = accent end
    if dot then dot.BackgroundColor3 = accent end
    for _, page in pairs(pages) do page.ScrollBarImageColor3 = accent end
    for _, navButton in pairs(navButtons) do
        local stroke = navButton:FindFirstChildOfClass("UIStroke")
        if stroke and navButton.Name == "Category_" .. activeCategory then stroke.Color = accent end
    end
    if particleSlider then particleSlider.setAccent() end
    if blurSlider then blurSlider.setAccent() end
    if opacitySlider then opacitySlider.setAccent() end
    if orbTransparencySlider then orbTransparencySlider.setAccent() end
    if orbSizeSlider then orbSizeSlider.setAccent() end
    if outlineTransparencySlider then outlineTransparencySlider.setAccent() end
end)

addSection("CONTORNO DO PERSONAGEM", 14)
outlineToggle = addToggle("Outline no meu personagem", 15,
    function() return settings.outline end,
    function(value)
        settings.outline = value
        applyCharacterOutline()
    end)

outlineColorButton = makeActionButton("Cor da Outline     ▸  " .. OUTLINE_COLOR_NAMES[settings.outlineColorIndex], 16, 35)
local function refreshOutlineColorButton()
    local selected = OUTLINE_COLORS[settings.outlineColorIndex]
    outlineColorButton.Text = "Cor da Outline     ▸  " .. OUTLINE_COLOR_NAMES[settings.outlineColorIndex]
    outlineColorButton.TextColor3 = selected
    outlineColorButton.BackgroundColor3 = Color3.fromRGB(24, 35, 53)
    local stroke = outlineColorButton:FindFirstChildOfClass("UIStroke")
    if stroke then stroke.Color = selected end
end
outlineColorButton.Activated:Connect(function()
    settings.outlineColorIndex = settings.outlineColorIndex % #OUTLINE_COLORS + 1
    refreshOutlineColorButton()
    applyCharacterOutline()
end)
refreshOutlineColorButton()

outlineTransparencySlider = addSlider("Transparência da Outline", 17, 0, 80, settings.outlineTransparency, "%", function(value)
    settings.outlineTransparency = value
    applyCharacterOutline()
end)

local resetButton = makeActionButton("RESTAURAR CONFIGURAÇÕES", 18, 36)
resetButton.Parent = pages.Interface
resetButton.LayoutOrder = 18
resetButton.Activated:Connect(function()
    settings.graphics = true
    settings.particles = false
    settings.sound = false
    settings.motionBlur = false
    settings.particleMultiplier = 1.6
    settings.blurStrength = 6
    settings.presetIndex = 2
    settings.opacity = 0
    settings.lastOpacity = 0.12
    settings.outline = false
    settings.outlineColorIndex = 1
    settings.outlineTransparency = 0
    settings.orbTransparency = 8
    settings.orbSize = 48
    applyCharacterOutline()
    applyPreset()
    updateAllEmitters()
    setAudioEnhancement(false)
    motionBlur.Enabled = false
    motionBlur.Size = 0
    particleSlider.set(settings.particleMultiplier)
    blurSlider.set(settings.blurStrength)
    opacitySlider.set(0)
    orbTransparencySlider.set(8)
    orbSizeSlider.set(48)
    outlineTransparencySlider.set(0)
    outlineToggle.refresh()
    refreshOutlineColorButton()
    graphicsToggle.refresh()
    particleToggle.refresh()
    soundToggle.refresh()
    motionToggle.refresh()
    refreshProfile()
    panel.GroupTransparency = 0
    panel.Visible = true
    launcher.Visible = false
    dot.Visible = false
    setActiveCategory("Visual")
end)

local note = Instance.new("TextLabel")
note.Size = UDim2.new(1, -4, 0, 28)
note.BackgroundTransparency = 1
note.Font = Enum.Font.Gotham
note.Text = "Reflexos RTX/HD real dependem do jogo. Boost alto pode baixar o FPS."
note.TextWrapped = true
note.TextSize = 8
note.TextColor3 = Color3.fromRGB(139, 157, 180)
note.LayoutOrder = 19
note.Parent = pages.Interface
setActiveCategory("Visual")

-- Botão-bola para abrir/minimizar. Arrastável em mouse e toque.
launcher = Instance.new("TextButton")
launcher.Name = "AuroraOrb"
launcher.Size = UDim2.fromOffset(settings.orbSize, settings.orbSize)
launcher.Position = UDim2.fromOffset(16, 160)
launcher.BackgroundColor3 = Color3.fromRGB(18, 33, 53)
launcher.BackgroundTransparency = settings.orbTransparency / 100
launcher.BorderSizePixel = 0
launcher.Text = "✦"
launcher.TextSize = 22
launcher.Font = Enum.Font.GothamBold
launcher.TextColor3 = accent
launcher.TextTransparency = settings.orbTransparency / 100
launcher.AutoButtonColor = true
launcher.Visible = true
launcher.Parent = gui
addCorner(launcher, 30)
orbStroke = addStroke(launcher, accent, 2, 0.02)
addGradient(launcher)

-- Ponto de retorno quando o menu está 100% invisível.
dot = Instance.new("TextButton")
dot.Name = "InvisibleAnchor"
dot.Size = UDim2.fromOffset(10, 10)
dot.Position = UDim2.fromOffset(22, 156)
dot.BackgroundColor3 = accent
dot.BorderSizePixel = 0
dot.Text = ""
dot.AutoButtonColor = true
dot.Visible = false
dot.Parent = gui
addCorner(dot, 10)
addStroke(dot, Color3.fromRGB(245, 250, 255), 1, 0.18)

local function syncFloatingControls()
    if launcher and dot then
        dot.Position = UDim2.fromOffset(
            launcher.Position.X.Offset + settings.orbSize / 2 - dot.Size.X.Offset / 2,
            launcher.Position.Y.Offset + settings.orbSize / 2 - dot.Size.Y.Offset / 2
        )
    end
end

local function makeDraggable(handle)
    local dragging = false
    local startPosition
    local startInput
    local isPanel = (handle == header)
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startInput = input.Position
            local object = isPanel and panel or handle
            startPosition = Vector2.new(object.Position.X.Offset, object.Position.Y.Offset)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    keep(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - startInput
            local camera = Workspace.CurrentCamera
            local viewport = camera and camera.ViewportSize or Vector2.new(360, 700)
            local object = isPanel and panel or handle
            local maxX = math.max(0, viewport.X - object.AbsoluteSize.X)
            local maxY = math.max(0, viewport.Y - object.AbsoluteSize.Y)
            object.Position = UDim2.fromOffset(
                math.clamp(startPosition.X + delta.X, 0, maxX),
                math.clamp(startPosition.Y + delta.Y, 0, maxY)
            )
            if handle == launcher then syncFloatingControls() end
        end
    end))
end

makeDraggable(header)
makeDraggable(launcher)
makeDraggable(dot)
syncFloatingControls()

launcher.Activated:Connect(function()
    panel.GroupTransparency = settings.opacity / 100
    panel.Visible = true
    launcher.Visible = false
    dot.Visible = settings.opacity >= 85
end)
minimizeButton.Activated:Connect(function()
    panel.Visible = false
    if settings.opacity >= 85 then
        dot.Visible = true
        launcher.Visible = false
    else
        launcher.Visible = true
        dot.Visible = false
    end
end)
dot.Activated:Connect(function()
    local restoreOpacity = math.clamp(settings.lastOpacity * 100, 0, 84)
    settings.opacity = restoreOpacity
    opacitySlider.set(restoreOpacity)
    panel.GroupTransparency = restoreOpacity / 100
    panel.Visible = true
    launcher.Visible = false
    dot.Visible = false
end)

-- Motion blur baseado na rotação da câmera, com suavização e limite configurável.
local previousCameraCFrame
local smoothedBlur = 0
keep(RunService.RenderStepped:Connect(function(dt)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    if not settings.motionBlur or settings.blurStrength <= 0 then
        smoothedBlur = math.max(0, smoothedBlur - dt * 45)
        motionBlur.Size = smoothedBlur
        previousCameraCFrame = camera.CFrame
        return
    end
    local current = camera.CFrame
    local target = 0
    if previousCameraCFrame then
        local dotProduct = math.clamp(previousCameraCFrame.LookVector:Dot(current.LookVector), -1, 1)
        local angle = math.acos(dotProduct)
        target = math.clamp(angle * 110, 0, 1) * settings.blurStrength
    end
    previousCameraCFrame = current
    smoothedBlur = smoothedBlur + (target - smoothedBlur) * math.clamp(dt * 14, 0, 1)
    motionBlur.Size = math.clamp(smoothedBlur, 0, 14)
end))

local function cleanup()
    for _, connection in ipairs(CONNECTIONS) do
        pcall(function() connection:Disconnect() end)
    end
    for emitter, original in pairs(emitterOriginals) do
        if emitter and emitter.Parent then
            if original.Rate ~= nil then pcall(function() emitter.Rate = original.Rate end) end
            if original.LightEmission ~= nil then pcall(function() emitter.LightEmission = original.LightEmission end) end
        end
    end
    for _, effect in pairs(audioEffects) do
        pcall(function() if effect and effect.Parent then effect:Destroy() end end)
    end
    pcall(function() if bloom then bloom:Destroy() end end)
    pcall(function() if colorCorrection then colorCorrection:Destroy() end end)
    pcall(function() if sunRays then sunRays:Destroy() end end)
    pcall(function() if motionBlur then motionBlur:Destroy() end end)
    pcall(function() if characterHighlight then characterHighlight:Destroy(); characterHighlight = nil end end)
    pcall(function() if originalLighting.EnvironmentDiffuseScale ~= nil then Lighting.EnvironmentDiffuseScale = originalLighting.EnvironmentDiffuseScale end end)
    pcall(function() if originalLighting.EnvironmentSpecularScale ~= nil then Lighting.EnvironmentSpecularScale = originalLighting.EnvironmentSpecularScale end end)
    pcall(function() if gui and gui.Parent then gui:Destroy() end end)
end

if sharedEnv then sharedEnv.__AURORA_LITE_CLEANUP = cleanup end

print("[AURORA LITE] Menu flutuante carregado. Use a bolinha ✦; categorias e controles de transparência/tamanho disponíveis. Outline configurável disponível.")
