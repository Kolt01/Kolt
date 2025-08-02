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

local ESPEntity = {}
ESPEntity.__index = ESPEntity

function ESPEntity:Set(prop, value)
    if self.Settings[prop] ~= nil then
        self.Settings[prop] = value
    end
end

local function findBestPart(object)
    local parts = {}
    for _, v in ipairs(object:GetDescendants()) do
        if v:IsA("BasePart") and v:IsDescendantOf(workspace) then
            table.insert(parts, v)
        end
    end
    table.sort(parts, function(a, b)
        return (Camera.CFrame.Position - a.Position).Magnitude < (Camera.CFrame.Position - b.Position).Magnitude
    end)
    return parts[1]
end

function ESP:Add(opts)
    assert(opts.Object and opts.Object:IsA("Instance"), "ESP:Add requires an Instance")

    local basePart = nil
    local adornee = opts.Object

    if opts.Object:IsA("BasePart") then
        basePart = opts.Object
    elseif opts.Object:IsA("Model") and opts.Object.PrimaryPart then
        basePart = opts.Object.PrimaryPart
    else
        basePart = findBestPart(opts.Object)
        if not basePart then
            warn("[ESP] Nenhum BasePart encontrado em", opts.Object:GetFullName())
            return
        end
    end

    local highlight = Instance.new("Highlight")
    highlight.Adornee = adornee:IsA("Model") and adornee or adornee:FindFirstAncestorWhichIsA("Model") or basePart
    highlight.FillColor = opts.Color or Color3.fromRGB(255, 255, 255)
    highlight.OutlineColor = Color3.new(0, 0, 0)
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = basePart

    local entity = setmetatable({
        Object = basePart,
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

        local originWorld = getOriginPos(part, settings.TracerOrigin)
        local screenPos, onScreen = Camera:WorldToViewportPoint(originWorld)
        local distance = (Camera.CFrame.Position - originWorld).Magnitude

        -- Highlight
        entity.Highlight.OutlineTransparency = settings.ChamsOutline and 0 or 1
        entity.Highlight.FillTransparency = settings.ChamsFilled and 0.5 or 1

        -- Labels
        local baseX, baseY = screenPos.X, screenPos.Y + 6

        if settings.ShowName and onScreen then
            entity.NameLabel.Position = Vector2.new(baseX, baseY)
            entity.NameLabel.Text = settings.Label or part.Name
            entity.NameLabel.Visible = true
        else
            entity.NameLabel.Visible = false
        end

        if settings.ShowDistance and onScreen then
            entity.DistanceLabel.Position = Vector2.new(baseX, baseY + 14)
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
