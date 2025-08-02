local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local ESP = {
    Enabled = true,
    TracerOrigin = "Bottom", -- "Bottom" ou "Center"
    Settings = {
        ShowTracer2D = true,
        ShowTracer3D = false,
        ShowName = true,
        ShowDistance = true,
        TracerColor = Color3.new(1, 1, 1),
        Font = Drawing.Fonts.UI,
        Size = 13,
        DistanceOffset = Vector2.new(0, 15),
        Outline = true,
        MinDistance = 0,
        MaxDistance = 300,
        ShowHighlightOutline = false,
        ShowHighlightFill = false,
    },
    Objects = {}
}

-- Resolve input para Roblox Instance
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

-- Pega a parte principal (root) do objeto
local function getRootPart(obj)
    return obj and obj:IsA("Model") and obj:FindFirstChildWhichIsA("BasePart") or obj
end

-- Converte mundo para tela
local function worldToScreen(part)
    return Camera:WorldToViewportPoint(part.Position)
end

-- Distância câmera para posição
local function getDistance(pos)
    return (Camera.CFrame.Position - pos).Magnitude
end

-- Adiciona ESP em objeto
function ESP:Add(input, customName)
    local object = ESP:ResolvePath(input)
    if not object then return end

    local root = getRootPart(object)
    if not root then return end

    if ESP.Objects[object] then return end -- evita duplicação

    local esp = {
        Object = object,
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Tracer = Drawing.new("Line"),
    }

    for _, d in pairs({esp.Name, esp.Distance}) do
        d.Visible = false
        d.Center = true
        d.Font = ESP.Settings.Font
        d.Size = ESP.Settings.Size
        d.Outline = ESP.Settings.Outline
    end

    esp.Name.Color = ESP.Settings.TracerColor
    esp.Distance.Color = ESP.Settings.TracerColor

    esp.Tracer.Visible = false
    esp.Tracer.Color = ESP.Settings.TracerColor
    esp.Tracer.Thickness = 1

    -- Highlight (opcional)
    if ESP.Settings.ShowHighlightOutline or ESP.Settings.ShowHighlightFill then
        if object:IsA("Model") and not object.PrimaryPart then
            object.PrimaryPart = getRootPart(object)
        end
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESP_Highlight"
        highlight.Adornee = object
        highlight.FillColor = ESP.Settings.TracerColor
        highlight.OutlineColor = Color3.new(0,0,0)
        highlight.FillTransparency = ESP.Settings.ShowHighlightFill and 0.5 or 1
        highlight.OutlineTransparency = ESP.Settings.ShowHighlightOutline and 0 or 1
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = object
        esp.Highlight = highlight
    end

    ESP.Objects[object] = esp

    if ESP.Settings.ShowTracer3D then
        ESP:Create3DTracer(object, ESP.Settings.TracerColor)
    end

    if customName then
        esp.Name.Text = customName
    end
end

-- Remove ESP do objeto
function ESP:Remove(input)
    local object = ESP:ResolvePath(input)
    if not object then return end

    local esp = ESP.Objects[object]
    if not esp then return end

    for _, d in pairs({esp.Name, esp.Distance, esp.Tracer}) do
        if d and d.Remove then
            d:Remove()
        end
    end

    if esp.Beam3D then pcall(function() esp.Beam3D:Destroy() end) end
    if esp.OriginAttachment then pcall(function() esp.OriginAttachment:Destroy() end) end
    if esp.TargetAttachment then pcall(function() esp.TargetAttachment:Destroy() end) end

    if esp.Highlight then
        pcall(function() esp.Highlight:Destroy() end)
    end

    ESP.Objects[object] = nil
end

-- Cria tracer 3D
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

    if ESP.Objects[object] then
        ESP.Objects[object].Beam3D = beam
        ESP.Objects[object].OriginAttachment = origin
        ESP.Objects[object].TargetAttachment = target
    end
end

-- Limpa todos ESP
function ESP:Clear()
    for object in pairs(ESP.Objects) do
        ESP:Remove(object)
    end
end

-- Ativa/desativa ESP
function ESP:SetEnabled(state)
    ESP.Enabled = state
end

-- Atualiza ESP toda render
RunService.RenderStepped:Connect(function()
    if not ESP.Enabled then return end

    for object, esp in pairs(ESP.Objects) do
        local root = getRootPart(object)
        if not root or not object:IsDescendantOf(workspace) then
            ESP:Remove(object)
            continue
        end

        local screenPos, onScreen = worldToScreen(root)
        local dist = math.floor(getDistance(root.Position))

        if not onScreen or dist < ESP.Settings.MinDistance or dist > ESP.Settings.MaxDistance then
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.Tracer.Visible = false
            continue
        end

        -- Nome
        if ESP.Settings.ShowName then
            esp.Name.Position = Vector2.new(screenPos.X, screenPos.Y)
            if not esp.Name.Text or esp.Name.Text == "" then
                esp.Name.Text = esp.Object.Name
            end
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
            local originY = (ESP.TracerOrigin == "Bottom") and Camera.ViewportSize.Y or Camera.ViewportSize.Y / 2
            esp.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, originY)
            esp.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
            esp.Tracer.Visible = true
        else
            esp.Tracer.Visible = false
        end
    end
end)

return ESP
