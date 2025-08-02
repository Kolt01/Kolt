-- ESP Library by Dhiogo (orientada a endereço real, sem buscas)
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local ESP = {
    Enabled = true,
    Entities = {},
}

local defaultSettings = {
    ChamsOutline = true,
    ChamsFilled = false,
    ShowName = true,
    ShowDistance = true,
    ShowTracer = true,
    TracerColor = Color3.fromRGB(255, 255, 255),
    TracerOrigin = "Bottom", -- Top, Center, Bottom
    Label = nil,
}

local function createDrawingText(zIndex)
    local text = Drawing.new("Text")
    text.Size = 13
    text.Center = true
    text.Outline = true
    text.Font = 2
    text.Visible = false
    text.ZIndex = zIndex or 1
    return text
end

local function createLine()
    local line = Drawing.new("Line")
    line.Thickness = 1.5
    line.Color = Color3.fromRGB(255,255,255)
    line.Transparency = 1
    line.Visible = false
    return line
end

local function getObjectPosition(obj, originType)
    if obj:IsA("Model") then
        local cf, size = obj:GetBoundingBox()
        if originType == "Top" then
            return cf.Position + Vector3.new(0, size.Y / 2, 0)
        elseif originType == "Bottom" then
            return cf.Position - Vector3.new(0, size.Y / 2, 0)
        else
            return cf.Position
        end
    elseif obj:IsA("BasePart") then
        local cf, size = obj.CFrame, obj.Size
        if originType == "Top" then
            return cf.Position + Vector3.new(0, size.Y / 2, 0)
        elseif originType == "Bottom" then
            return cf.Position - Vector3.new(0, size.Y / 2, 0)
        else
            return cf.Position
        end
    end
    return nil
end

local ESPEntity = {}
ESPEntity.__index = ESPEntity

function ESPEntity:Set(prop, value)
    if self.Settings[prop] ~= nil then
        self.Settings[prop] = value
    end
end

function ESP:Add(opts)
    assert(opts.Object and opts.Object:IsA("Instance"), "ESP:Add requires an Instance")

    local object = opts.Object
    if not object:IsA("Model") and not object:IsA("BasePart") then
        warn("[ESP] Tipo de objeto não suportado:", object.ClassName)
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Adornee = object
    highlight.FillColor = opts.Color or Color3.fromRGB(255, 255, 255)
    highlight.OutlineColor = Color3.new(0, 0, 0)
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = object:IsA("Model") and object.PrimaryPart or object

    local entity = setmetatable({
        Object = object,
        Settings = table.clone(defaultSettings),
        Highlight = highlight,
        NameLabel = createDrawingText(2),
        DistanceLabel = createDrawingText(1),
        Tracer = createLine(),
    }, ESPEntity)

    if opts.Label then entity.Settings.Label = opts.Label end
    if opts.Color then
        highlight.FillColor = opts.Color
        entity.Tracer.Color = opts.Color
    end

    table.insert(ESP.Entities, entity)
    return entity
end

RunService.RenderStepped:Connect(function()
    for i = #ESP.Entities, 1, -1 do
        local entity = ESP.Entities[i]
        local obj = entity.Object
        local settings = entity.Settings

        if not obj or not obj:IsDescendantOf(workspace) then
            -- Cleanup
            if entity.Highlight then entity.Highlight:Destroy() end
            if entity.NameLabel then entity.NameLabel:Remove() end
            if entity.DistanceLabel then entity.DistanceLabel:Remove() end
            if entity.Tracer then entity.Tracer:Remove() end
            table.remove(ESP.Entities, i)
            continue
        end

        local pos = getObjectPosition(obj, settings.TracerOrigin)
        if not pos then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
        local distance = (Camera.CFrame.Position - pos).Magnitude

        -- Highlight update
        entity.Highlight.OutlineTransparency = settings.ChamsOutline and 0 or 1
        entity.Highlight.FillTransparency = settings.ChamsFilled and 0.5 or 1

        -- Labels
        if settings.ShowName and onScreen then
            entity.NameLabel.Position = Vector2.new(screenPos.X, screenPos.Y - 14)
            entity.NameLabel.Text = settings.Label or obj.Name
            entity.NameLabel.Visible = true
        else
            entity.NameLabel.Visible = false
        end

        if settings.ShowDistance and onScreen then
            entity.DistanceLabel.Position = Vector2.new(screenPos.X, screenPos.Y + 2)
            entity.DistanceLabel.Text = string.format("[%.1fm]", distance)
            entity.DistanceLabel.Visible = true
        else
            entity.DistanceLabel.Visible = false
        end

        -- Tracer
        if settings.ShowTracer and onScreen then
            entity.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            entity.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
            entity.Tracer.Color = settings.TracerColor
            entity.Tracer.Visible = true
        else
            entity.Tracer.Visible = false
        end
    end
end)

return ESP
