-- ESP Library by Dhiogo (orientada a endereço)
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")

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
    TracerOrigin = "Bottom",
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

local function getOriginPos(part, originType)
    local cf, size = part.CFrame, part.Size
    if originType == "Top" then
        return cf.Position + Vector3.new(0, size.Y / 2, 0)
    elseif originType == "Center" then
        return cf.Position
    elseif originType == "Bottom" then
        return cf.Position - Vector3.new(0, size.Y / 2, 0)
    else
        return cf.Position
    end
end

-- ESP Entity Wrapper
local ESPEntity = {}
ESPEntity.__index = ESPEntity

function ESPEntity:Set(prop, value)
    if self.Settings[prop] ~= nil then
        self.Settings[prop] = value
    end
end

function ESP:Add(opts)
    assert(opts.Object and opts.Object:IsA("BasePart"), "ESP:Add requires a BasePart")

    local highlight = Instance.new("Highlight")
    highlight.Adornee = opts.Object:FindFirstAncestorWhichIsA("Model") or opts.Object
    highlight.FillColor = opts.Color or Color3.fromRGB(255, 255, 255)
    highlight.OutlineColor = Color3.new(0, 0, 0)
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = opts.Object

    local entity = setmetatable({
        Object = opts.Object,
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
        local part = entity.Object
        local settings = entity.Settings

        if not part or not part:IsDescendantOf(workspace) then
            -- Cleanup
            if entity.Highlight then entity.Highlight:Destroy() end
            if entity.NameLabel then entity.NameLabel:Remove() end
            if entity.DistanceLabel then entity.DistanceLabel:Remove() end
            if entity.Tracer then entity.Tracer:Remove() end
            table.remove(ESP.Entities, i)
            continue
        end

        -- Visibility Check
        local originWorld = getOriginPos(part, settings.TracerOrigin)
        local screenPos, onScreen = Camera:WorldToViewportPoint(originWorld)
        local distance = (Camera.CFrame.Position - originWorld).Magnitude

        -- Update Highlight
        if settings.ChamsOutline then
            entity.Highlight.OutlineTransparency = 0
        else
            entity.Highlight.OutlineTransparency = 1
        end

        if settings.ChamsFilled then
            entity.Highlight.FillTransparency = 0.5
        else
            entity.Highlight.FillTransparency = 1
        end

        -- Update Name Label
        if settings.ShowName and onScreen then
            entity.NameLabel.Position = Vector2.new(screenPos.X, screenPos.Y - 16)
            entity.NameLabel.Text = settings.Label or part.Name
            entity.NameLabel.Visible = true
        else
            entity.NameLabel.Visible = false
        end

        -- Update Distance Label
        if settings.ShowDistance and onScreen then
            entity.DistanceLabel.Position = Vector2.new(screenPos.X, screenPos.Y + 4)
            entity.DistanceLabel.Text = string.format("[%.1fm]", distance)
            entity.DistanceLabel.Visible = true
        else
            entity.DistanceLabel.Visible = false
        end

        -- Update Tracer
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
