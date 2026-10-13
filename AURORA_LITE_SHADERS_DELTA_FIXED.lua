-- AURORA LITE SHADERS V2 - Delta / Roblox (cliente)
-- Efeitos locais: Bloom, ColorCorrection, SunRays, outline do personagem e menu flutuante.
-- Não cria RTX/reflexos reais nem altera o servidor.

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
if not player then return end
local playerGui = player:WaitForChild("PlayerGui")

-- Remove execução anterior
pcall(function()
    local env = (getgenv and getgenv()) or _G
    if env.__AURORA_LITE_CLEANUP then env.__AURORA_LITE_CLEANUP() end
end)
local old = playerGui:FindFirstChild("AURORA_LITE_SHADER_GUI")
if old then old:Destroy() end

local connections = {}
local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(connections, c)
    return c
end

local COLORS = {
    Color3.fromRGB(70,224,255), Color3.fromRGB(173,112,255),
    Color3.fromRGB(255,190,82), Color3.fromRGB(98,255,164),
    Color3.fromRGB(255,105,145), Color3.fromRGB(255,255,255),
}
local COLOR_NAMES = {"CIANO","ROXO","DOURADO","VERDE","ROSA","BRANCO"}
local OUTLINE_COLORS = {
    Color3.fromRGB(70,224,255), Color3.fromRGB(173,112,255),
    Color3.fromRGB(255,190,82), Color3.fromRGB(98,255,164),
    Color3.fromRGB(255,105,145), Color3.fromRGB(255,255,255),
    Color3.fromRGB(255,65,65), Color3.fromRGB(65,120,255),
}
local OUTLINE_NAMES = {"CIANO","ROXO","DOURADO","VERDE","ROSA","BRANCO","VERMELHO","AZUL"}
local themeIndex, outlineIndex = 1, 1
local settings = {visual=true, outline=false, opacity=0, orbOpacity=8, orbSize=48, outlineTransparency=0, preset=2}
local presets = {
    {name="LEVE", bloom=.12, size=14, threshold=1.65, contrast=.06, saturation=.05, brightness=0, rays=.015, spread=.55},
    {name="EQUILIBRADO", bloom=.28, size=22, threshold=1.45, contrast=.12, saturation=.12, brightness=.015, rays=.055, spread=.7},
    {name="CINEMÁTICO", bloom=.42, size=30, threshold=1.25, contrast=.18, saturation=.16, brightness=.02, rays=.10, spread=.78},
}

local gui = Instance.new("ScreenGui")
gui.Name = "AURORA_LITE_SHADER_GUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
end
local function stroke(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or COLORS[themeIndex]
    s.Thickness = thickness or 1
    s.Transparency = transparency or .2
    s.Parent = obj
    return s
end
local function label(parent, text, pos, size, fontSize, color, font)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Position = pos
    t.Size = size
    t.Font = font or Enum.Font.Gotham
    t.Text = text
    t.TextSize = fontSize or 12
    t.TextColor3 = color or Color3.new(1,1,1)
    t.TextWrapped = true
    t.Parent = parent
    return t
end

local panel = Instance.new("Frame")
panel.Name = "ShaderPanel"
panel.Size = UDim2.fromOffset(320, 430)
panel.Position = UDim2.new(.5, -160, .5, -215)
panel.BackgroundColor3 = Color3.fromRGB(13,19,32)
panel.BackgroundTransparency = .04
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 16)
local panelStroke = stroke(panel, COLORS[themeIndex], 1.5, .15)

local header = Instance.new("Frame")
header.Size = UDim2.new(1,0,0,58)
header.BackgroundColor3 = Color3.fromRGB(20,32,51)
header.BorderSizePixel = 0
header.Parent = panel
corner(header, 15)
label(header, "✦ AURORA LITE SHADERS", UDim2.fromOffset(14,5), UDim2.new(1,-58,0,27), 16, COLORS[themeIndex], Enum.Font.GothamBold)
label(header, "PAINEL VISUAL • CLIENT-SIDE", UDim2.fromOffset(15,31), UDim2.new(1,-60,0,17), 9, Color3.fromRGB(155,174,198))
local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(32,30)
close.Position = UDim2.new(1,-42,0,13)
close.Text = "—"
close.TextSize = 16
close.Font = Enum.Font.GothamBold
close.TextColor3 = Color3.new(1,1,1)
close.BackgroundColor3 = Color3.fromRGB(39,53,74)
close.BorderSizePixel = 0
close.Parent = header
corner(close, 8)

local content = Instance.new("ScrollingFrame")
content.Position = UDim2.fromOffset(12,68)
content.Size = UDim2.new(1,-24,1,-80)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = COLORS[themeIndex]
content.CanvasSize = UDim2.new(0,0,0,0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0,7)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local function section(text, order)
    local t = label(content, "  "..text, UDim2.new(), UDim2.new(1,-4,0,22), 10, COLORS[themeIndex], Enum.Font.GothamBold)
    t.LayoutOrder = order
end
local function button(text, order, height)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-4,0,height or 36)
    b.BackgroundColor3 = Color3.fromRGB(24,35,53)
    b.BorderSizePixel = 0
    b.AutoButtonColor = true
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 11
    b.TextColor3 = Color3.fromRGB(232,240,252)
    b.Text = text
    b.LayoutOrder = order
    b.Parent = content
    corner(b, 9)
    stroke(b, Color3.fromRGB(77,101,132), 1, .65)
    return b
end

local bloom = Instance.new("BloomEffect")
bloom.Name = "AURORA_LITE_Bloom"
bloom.Parent = Lighting
local color = Instance.new("ColorCorrectionEffect")
color.Name = "AURORA_LITE_Color"
color.TintColor = Color3.fromRGB(235,244,255)
color.Parent = Lighting
local rays = Instance.new("SunRaysEffect")
rays.Name = "AURORA_LITE_SunRays"
rays.Parent = Lighting
local highlight
local function applyPreset()
    local p = presets[settings.preset]
    bloom.Intensity, bloom.Size, bloom.Threshold = p.bloom, p.size, p.threshold
    color.Brightness, color.Contrast, color.Saturation = p.brightness, p.contrast, p.saturation
    rays.Intensity, rays.Spread = p.rays, p.spread
    bloom.Enabled, color.Enabled, rays.Enabled = settings.visual, settings.visual, settings.visual
end
local function applyOutline()
    local character = player.Character
    if not settings.outline or not character then
        if highlight then pcall(function() highlight:Destroy() end); highlight = nil end
        return
    end
    if not highlight or not highlight.Parent or highlight.Adornee ~= character then
        if highlight then pcall(function() highlight:Destroy() end) end
        highlight = Instance.new("Highlight")
        highlight.Name = "AURORA_LITE_Outline"
        highlight.Adornee = character
        highlight.FillTransparency = 1
        highlight.DepthMode = Enum.HighlightDepthMode.Occluded
        highlight.Parent = character
    end
    highlight.OutlineColor = OUTLINE_COLORS[outlineIndex]
    highlight.OutlineTransparency = settings.outlineTransparency / 100
    highlight.Enabled = true
end
connect(player.CharacterAdded, function()
    task.wait(.3)
    if settings.outline then applyOutline() end
end)
applyPreset()

section("ILUMINAÇÃO E COR", 1)
local presetButton = button("Perfil visual: EQUILIBRADO  ▸", 2)
presetButton.Activated:Connect(function()
    settings.preset = settings.preset % #presets + 1
    applyPreset()
    presetButton.Text = "Perfil visual: "..presets[settings.preset].name.."  ▸"
end)
local visualButton = button("Bloom + cor + raios de sol: ON", 3)
visualButton.Activated:Connect(function()
    settings.visual = not settings.visual
    applyPreset()
    visualButton.Text = "Bloom + cor + raios de sol: "..(settings.visual and "ON" or "OFF")
end)

section("OUTLINE", 4)
local outlineButton = button("Outline no personagem: OFF", 5)
outlineButton.Activated:Connect(function()
    settings.outline = not settings.outline
    applyOutline()
    outlineButton.Text = "Outline no personagem: "..(settings.outline and "ON" or "OFF")
end)
local outlineColorButton = button("Cor da outline: CIANO", 6)
outlineColorButton.Activated:Connect(function()
    outlineIndex = outlineIndex % #OUTLINE_COLORS + 1
    outlineColorButton.Text = "Cor da outline: "..OUTLINE_NAMES[outlineIndex]
    outlineColorButton.TextColor3 = OUTLINE_COLORS[outlineIndex]
    applyOutline()
end)
local outlineTransparencyButton = button("Transparência outline: 0%", 7)
outlineTransparencyButton.Activated:Connect(function()
    settings.outlineTransparency = (settings.outlineTransparency + 20) % 100
    outlineTransparencyButton.Text = "Transparência outline: "..settings.outlineTransparency.."%"
    applyOutline()
end)

section("INTERFACE", 8)
local transparencyButton = button("Transparência do painel: 0%", 9)
transparencyButton.Activated:Connect(function()
    settings.opacity = (settings.opacity + 10) % 90
    panel.BackgroundTransparency = settings.opacity / 100
    transparencyButton.Text = "Transparência do painel: "..settings.opacity.."%"
end)
local orbOpacityButton = button("Transparência da bolinha: 8%", 10)
local orbSizeButton = button("Tamanho da bolinha: 48", 11)
local themeButton = button("Cor do menu: CIANO", 12)
local resetButton = button("RESTAURAR CONFIGURAÇÕES", 13)
label(content, "Efeitos locais. A aparência depende do jogo e do dispositivo; não é RTX real.", UDim2.new(), UDim2.new(1,-4,0,35), 9, Color3.fromRGB(139,157,180)).LayoutOrder = 14

local orb = Instance.new("TextButton")
orb.Name = "AuroraOrb"
orb.Size = UDim2.fromOffset(settings.orbSize, settings.orbSize)
orb.Position = UDim2.fromOffset(18,160)
orb.BackgroundColor3 = Color3.fromRGB(18,33,53)
orb.BackgroundTransparency = settings.orbOpacity / 100
orb.BorderSizePixel = 0
orb.Text = "✦"
orb.TextSize = 22
orb.Font = Enum.Font.GothamBold
orb.TextColor3 = COLORS[themeIndex]
orb.TextTransparency = settings.orbOpacity / 100
orb.Parent = gui
corner(orb, 40)
local orbStroke = stroke(orb, COLORS[themeIndex], 2, .02)

orbOpacityButton.Activated:Connect(function()
    settings.orbOpacity = (settings.orbOpacity + 10) % 100
    orb.BackgroundTransparency = settings.orbOpacity / 100
    orb.TextTransparency = settings.orbOpacity / 100
    orbStroke.Transparency = math.clamp(settings.orbOpacity / 100, .02, .95)
    orbOpacityButton.Text = "Transparência da bolinha: "..settings.orbOpacity.."%"
end)
orbSizeButton.Activated:Connect(function()
    settings.orbSize = settings.orbSize >= 68 and 36 or settings.orbSize + 8
    orb.Size = UDim2.fromOffset(settings.orbSize, settings.orbSize)
    orbSizeButton.Text = "Tamanho da bolinha: "..settings.orbSize
end)
themeButton.Activated:Connect(function()
    themeIndex = themeIndex % #COLORS + 1
    local c = COLORS[themeIndex]
    panelStroke.Color, orbStroke.Color = c, c
    orb.TextColor3 = c
    content.ScrollBarImageColor3 = c
    themeButton.Text = "Cor do menu: "..COLOR_NAMES[themeIndex]
    themeButton.TextColor3 = c
    presetButton.TextColor3 = c
end)
resetButton.Activated:Connect(function()
    settings.visual, settings.outline, settings.opacity = true, false, 0
    settings.orbOpacity, settings.orbSize, settings.outlineTransparency, settings.preset = 8, 48, 0, 2
    outlineIndex, themeIndex = 1, 1
    applyPreset(); applyOutline()
    panel.BackgroundTransparency = .04
    orb.Size = UDim2.fromOffset(48,48)
    orb.BackgroundTransparency, orb.TextTransparency = .08,.08
    orb.TextColor3 = COLORS[1]
    orbStroke.Color, orbStroke.Transparency = COLORS[1],.02
    panelStroke.Color = COLORS[1]
    visualButton.Text = "Bloom + cor + raios de sol: ON"
    outlineButton.Text = "Outline no personagem: OFF"
    outlineColorButton.Text = "Cor da outline: CIANO"
    outlineColorButton.TextColor3 = COLORS[1]
    outlineTransparencyButton.Text = "Transparência outline: 0%"
    transparencyButton.Text = "Transparência do painel: 0%"
    orbOpacityButton.Text = "Transparência da bolinha: 8%"
    orbSizeButton.Text = "Tamanho da bolinha: 48"
    themeButton.Text = "Cor do menu: CIANO"
    presetButton.Text = "Perfil visual: EQUILIBRADO  ▸"
end)

orb.Activated:Connect(function() panel.Visible = not panel.Visible end)
close.Activated:Connect(function() panel.Visible = false end)

-- Arrastar o painel pelo cabeçalho e a bolinha com mouse ou toque.
local function makeDraggable(handle, object)
    local dragging, startPos, startInput = false, nil, nil
    connect(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startInput = input.Position
            startPos = Vector2.new(object.Position.X.Offset, object.Position.Y.Offset)
            connect(input.Changed, function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    connect(UIS.InputChanged, function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - startInput
            local camera = Workspace.CurrentCamera
            local vp = camera and camera.ViewportSize or Vector2.new(360,700)
            local maxX = math.max(0, vp.X - object.AbsoluteSize.X)
            local maxY = math.max(0, vp.Y - object.AbsoluteSize.Y)
            object.Position = UDim2.fromOffset(math.clamp(startPos.X + delta.X,0,maxX), math.clamp(startPos.Y + delta.Y,0,maxY))
        end
    end)
end
makeDraggable(header, panel)
makeDraggable(orb, orb)

local cleaned = false
local function cleanup()
    if cleaned then return end
    cleaned = true
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    pcall(function() bloom:Destroy() end)
    pcall(function() color:Destroy() end)
    pcall(function() rays:Destroy() end)
    pcall(function() if highlight then highlight:Destroy() end end)
    pcall(function() if gui then gui:Destroy() end end)
end
pcall(function()
    local env = (getgenv and getgenv()) or _G
    env.__AURORA_LITE_CLEANUP = cleanup
end)
print("[AURORA LITE V2] Carregado! Toque na bolinha ✦ para abrir o menu.")
