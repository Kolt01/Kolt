--// ESP Library v1.0 - por Dhiogo
-- Suporte: Model, BasePart e estruturas complexas (via endereço)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera

local espObjects = {}
local config = {
    Enabled = true,

    -- Visuals
    ShowTracer = true,
    TracerOrigin = "Bottom", -- Top, Middle, Bottom
    ShowHighlightOutline = true,
    ShowHighlightFill = true,
    ShowName = true,
    ShowDistance = true,

    -- 2D Entity ESP
    ShowEntity2D = true,
    Entity2DShape = "RoundBox", -- RoundBox, Capsule, etc
    Entity2DColor = Color3.fromRGB(255, 255, 0),

    -- Estilos
    TextColor = Color3.fromRGB(255,255,255),
    TracerColor = Color3.fromRGB(255,255,255),
    OutlineColor = Color3.fromRGB(255,255,255),
    FillColor = Color3.fromRGB(255, 255, 255):Lerp(Color3.new(), 0.7),
}

local function createHighlight(target)
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Highlight"
    highlight.Adornee = target
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = config.FillColor
    highlight.FillTransparency = config.ShowHighlightFill and 0.5 or 1
    highlight.OutlineColor = config.OutlineColor
    highlight.OutlineTransparency = config.ShowHighlightOutline and 0 or 1
    highlight.Parent = target
    return highlight
end

local function createBillboardGui(target, name)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_NameDisplay"
    billboard.Size = UDim2.new(0, 100, 0, 30)
    billboard.AlwaysOnTop = true
    billboard.Adornee = target
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)

    local textLabel = Instance.new("TextLabel", billboard)
    textLabel.BackgroundTransparency = 1
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.TextColor3 = config.TextColor
    textLabel.TextStrokeTransparency = 0.5
    textLabel.TextScaled = true
    textLabel.Text = name

    billboard.Parent = target
    return billboard
end

local function createTracer(target)
    local line = Drawing.new("Line")
    line.Thickness = 1.5
    line.Color = config.TracerColor
    line.Visible = true
    espObjects[target].tracer = line
end

local function createEntity2D(target)
    local adornment = Instance.new("BoxHandleAdornment")
    adornment.Name = "ESP_Entity2D"
    adornment.Size = target.Size + Vector3.new(0.1, 0.1, 0.1)
    adornment.Adornee = target
    adornment.AlwaysOnTop = true
    adornment.ZIndex = 10
    adornment.Color3 = config.Entity2DColor
    adornment.Transparency = 0.4
    adornment.Parent = target
    adornment.Shape = Enum.AdornmentShape.Box
    adornment.CornerRadius = UDim.new(0, 4)
    return adornment
end

local function getTracerOrigin()
    if config.TracerOrigin == "Top" then
        return Camera.ViewportSize / 2 + Vector2.new(0, -200)
    elseif config.TracerOrigin == "Middle" then
        return Camera.ViewportSize / 2
    else
        return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
    end
end

local function updateESP()
    for target, data in pairs(espObjects) do
        if target and target:IsDescendantOf(workspace) then
            local pos, onScreen = Camera:WorldToViewportPoint(target.Position)
            if config.ShowTracer and data.tracer then
                local from = getTracerOrigin()
                data.tracer.From = from
                data.tracer.To = Vector2.new(pos.X, pos.Y)
                data.tracer.Visible = onScreen
            end

            if data.nameGui then
                data.nameGui.Enabled = config.ShowName or config.ShowDistance
                local distance = (Camera.CFrame.Position - target.Position).Magnitude
                data.nameGui.TextLabel.Text = (config.ShowName and target.Name or "")
                    .. (config.ShowDistance and (" [%.1fm]"):format(distance) or "")
            end
        else
            -- Cleanup
            if data.tracer then data.tracer:Remove() end
            if data.nameGui then data.nameGui:Destroy() end
            if data.highlight then data.highlight:Destroy() end
            if data.entity2d then data.entity2d:Destroy() end
            espObjects[target] = nil
        end
    end
end

RunService.RenderStepped:Connect(function()
    if config.Enabled then
        updateESP()
    end
end)

local module = {}

function module.AddESP(target)
    if espObjects[target] then return end

    local data = {}
    if target:IsA("Model") then
        target = target:FindFirstChildWhichIsA("BasePart") or target.PrimaryPart or target
    end

    if config.ShowTracer then
        createTracer(target)
    end

    if config.ShowName or config.ShowDistance then
        data.nameGui = createBillboardGui(target, target.Name)
    end

    if config.ShowHighlightOutline or config.ShowHighlightFill then
        data.highlight = createHighlight(target)
    end

    if config.ShowEntity2D then
        data.entity2d = createEntity2D(target)
    end

    espObjects[target] = data
end

function module.RemoveESP(target)
    local data = espObjects[target]
    if not data then return end

    if data.tracer then data.tracer:Remove() end
    if data.nameGui then data.nameGui:Destroy() end
    if data.highlight then data.highlight:Destroy() end
    if data.entity2d then data.entity2d:Destroy() end

    espObjects[target] = nil
end

function module.SetConfig(cfg)
    for k, v in pairs(cfg) do
        if config[k] ~= nil then
            config[k] = v
        end
    end
end

return module
