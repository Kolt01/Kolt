local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local ESP = {
    Enabled = true,
    TracerOrigin = "Bottom", -- "Top", "Center", "Bottom", "LeftBottom", "RightBottom"
    Settings = {
        ShowTracer2D = true,
        ShowTracer3D = false,
        ShowName = true,
        ShowDistance = true,
        TracerColor = Color3.new(1, 1, 1),
        Font = Drawing.Fonts.UI, -- pode mudar para Arcade, System, Plex, Gotham se quiser
        Size = 13,
        DistanceOffset = Vector2.new(0, 15),
        Outline = true,
        MinDistance = 0,
        MaxDistance = 300,
        ShowHighlightOutline = true,
        ShowHighlightFill = true,
        HighlightFillColor = Color3.fromRGB(0, 255, 0),
        HighlightOutlineColor = Color3.fromRGB(0, 0, 0),
        DotSize = 6,
    },
    Objects = {}
}

function ESP:ResolvePath(input)
    if typeof(input) == "Instance" then
        return input
    elseif type(input) == "string" then
        local func, err = loadstring("return " .. input)
        if not func then
            warn("Falha ao compilar path: "..tostring(err))
            return nil
        end
        local ok, result = pcall(func)
        if not ok then
            warn("Falha ao executar path: "..tostring(result))
            return nil
        end
        return result
    elseif type(input) == "table" then
        if input.Parent and typeof(input.Parent) == "Instance" and type(input.Name) == "string" then
            return input.Parent:FindFirstChild(input.Name)
        end
        return nil
    else
        return nil
    end
end

local function getRootPart(obj)
    if obj and obj:IsA("Model") then
        if obj.PrimaryPart then
            return obj.PrimaryPart
        else
            return obj:FindFirstChildWhichIsA("BasePart")
        end
    elseif obj and obj:IsA("BasePart") then
        return obj
    end
    return nil
end

local function worldToScreen(pos)
    return Camera:WorldToViewportPoint(pos)
end

local function getDistance(pos)
    return (Camera.CFrame.Position - pos).Magnitude
end

-- Cria highlight estilo hub
local function CreateHighlight(target)
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Highlight"
    highlight.Adornee = target
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = ESP.Settings.HighlightFillColor
    highlight.OutlineColor = ESP.Settings.HighlightOutlineColor
    highlight.FillTransparency = ESP.Settings.ShowHighlightFill and 0.4 or 1
    highlight.OutlineTransparency = ESP.Settings.ShowHighlightOutline and 0 or 1
    highlight.Enabled = (ESP.Settings.ShowHighlightOutline or ESP.Settings.ShowHighlightFill)
    highlight.Parent = target
    return highlight
end

local function CreateText()
    local text = Drawing.new("Text")
    text.Visible = false
    text.Center = true
    text.Outline = ESP.Settings.Outline
    text.Font = ESP.Settings.Font
    text.Size = ESP.Settings.Size
    text.Color = ESP.Settings.TracerColor
    return text
end

local function CreateLine()
    local line = Drawing.new("Line")
    line.Visible = false
    line.Color = ESP.Settings.TracerColor
    line.Thickness = 1
    return line
end

local function CreateDot()
    local dot = Drawing.new("Circle")
    dot.Visible = false
    dot.Color = ESP.Settings.TracerColor
    dot.Thickness = 1
    dot.NumSides = 20
    dot.Filled = true
    dot.Radius = ESP.Settings.DotSize / 2
    return dot
end

function ESP:Add(input, customName)
    local object = ESP:ResolvePath(input)
    if not object then return end

    local root = getRootPart(object)
    if not root then return end

    if ESP.Objects[object] then return end -- evita duplicação

    local esp = {
        Object = object,
        Name = CreateText(),
        Distance = CreateText(),
        Tracer = CreateLine(),
        TracerDot = CreateDot(),
    }

    esp.Name.Text = customName or object.Name

    -- Highlight
    if ESP.Settings.ShowHighlightOutline or ESP.Settings.ShowHighlightFill then
        esp.Highlight = CreateHighlight(object)
    end

    ESP.Objects[object] = esp

    if ESP.Settings.ShowTracer3D then
        ESP:Create3DTracer(object, ESP.Settings.TracerColor)
    end
end

function ESP:Remove(input)
    local object = ESP:ResolvePath(input)
    if not object then return end

    local esp = ESP.Objects[object]
    if not esp then return end

    esp.Name:Remove()
    esp.Distance:Remove()
    esp.Tracer:Remove()
    esp.TracerDot:Remove()

    if esp.Highlight then
        esp.Highlight:Destroy()
    end

    if esp.Beam3D then esp.Beam3D:Destroy() end
    if esp.OriginAttachment then esp.OriginAttachment:Destroy() end
    if esp.TargetAttachment then esp.TargetAttachment:Destroy() end

    ESP.Objects[object] = nil
end

function ESP:Create3DTracer(object, color)
    local root = getRootPart(object)
    if not root then return end

    local origin = Instance.new("Attachment")
    origin.Name = "_ESP_Origin"
    origin.Parent = Camera

    local target = Instance.new("Attachment")
    target.Name = "_ESP_Target"
    target.Parent = root

    local beam = Instance.new("Beam")
    beam.Attachment0 = origin
    beam.Attachment1 = target
    beam.Width0 = 0.1
    beam.Width1 = 0.1
    beam.Color = ColorSequence.new(color or Color3.new(1,1,1))
    beam.FaceCamera = true
    beam.AlwaysOnTop = true
    beam.Name = "_ESP_Beam"
    beam.Parent = origin

    local esp = ESP.Objects[object]
    if esp then
        esp.Beam3D = beam
        esp.OriginAttachment = origin
        esp.TargetAttachment = target
    end
end

function ESP:Clear()
    for object in pairs(ESP.Objects) do
        ESP:Remove(object)
    end
end

function ESP:SetEnabled(state)
    ESP.Enabled = state
end

RunService.RenderStepped:Connect(function()
    if not ESP.Enabled then return end

    local viewportSize = Camera.ViewportSize

    -- Define o ponto de origem do tracer
    local function getTracerOrigin()
        if ESP.TracerOrigin == "Top" then
            return Vector2.new(viewportSize.X/2, viewportSize.Y * 0.1)
        elseif ESP.TracerOrigin == "Center" then
            return Vector2.new(viewportSize.X/2, viewportSize.Y/2)
        elseif ESP.TracerOrigin == "Bottom" then
            return Vector2.new(viewportSize.X/2, viewportSize.Y * 0.9)
        elseif ESP.TracerOrigin == "LeftBottom" then
            return Vector2.new(viewportSize.X * 0.1, viewportSize.Y * 0.9)
        elseif ESP.TracerOrigin == "RightBottom" then
            return Vector2.new(viewportSize.X * 0.9, viewportSize.Y * 0.9)
        else
            return Vector2.new(viewportSize.X/2, viewportSize.Y * 0.9)
        end
    end

    for object, esp in pairs(ESP.Objects) do
        local root = getRootPart(object)
        if not root or not object:IsDescendantOf(workspace) then
            ESP:Remove(object)
            continue
        end

        -- Ponto superior do objeto (usar BoundingBox)
        local cf = root.CFrame
        local size = root.Size
        local topPos = cf * Vector3.new(0, size.Y/2, 0)

        local screenPos, onScreen = worldToScreen(topPos)
        local dist = math.floor(getDistance(topPos))

        if not onScreen or dist < ESP.Settings.MinDistance or dist > ESP.Settings.MaxDistance then
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.Tracer.Visible = false
            esp.TracerDot.Visible = false
            goto continue
        end

        -- Nome
        if ESP.Settings.ShowName then
            esp.Name.Position = Vector2.new(screenPos.X, screenPos.Y)
            esp.Name.Visible = true
        else
            esp.Name.Visible = false
        end

        -- Distância
        if ESP.Settings.ShowDistance then
            esp.Distance.Position = Vector2.new(screenPos.X, screenPos.Y) + ESP.Settings.DistanceOffset
            esp.Distance.Text = tostring(dist) .. "m"
            esp.Distance.Visible = true
        else
            esp.Distance.Visible = false
        end

        -- Tracer 2D
        if ESP.Settings.ShowTracer2D then
            local fromPos = getTracerOrigin()
            esp.Tracer.From = fromPos
            esp.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
            esp.Tracer.Color = ESP.Settings.TracerColor
            esp.Tracer.Visible = true

            -- Dot na origem
            esp.TracerDot.Position = fromPos
            esp.TracerDot.Color = ESP.Settings.TracerColor
            esp.TracerDot.Visible = true
        else
            esp.Tracer.Visible = false
            esp.TracerDot.Visible = false
        end

        ::continue::
    end
end)

return ESP
----------------------END-------------------------------------
