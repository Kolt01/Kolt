-- ESP Library v2 - com suporte a Tracer 3D
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
    },
    Objects = {}
}

-- Utilitários
local function getRootPart(obj)
    return obj:IsA("Model") and obj:FindFirstChildWhichIsA("BasePart") or obj
end

local function isVisible(part)
    if not part then return false end
    local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
    return onScreen and pos.Z > 0
end

local function worldToScreen(part)
    return Camera:WorldToViewportPoint(part.Position)
end

local function getDistance(pos)
    return (Camera.CFrame.Position - pos).Magnitude
end

-- Criar ESP
function ESP:Add(object, customName)
    local root = getRootPart(object)
    if not root then return end

    local esp = {
        Object = object,
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Tracer = Drawing.new("Line")
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

    ESP.Objects[object] = esp

    if ESP.Settings.ShowTracer3D then
        ESP:Create3DTracer(object, ESP.Settings.TracerColor)
    end
end

-- Tracer 3D via Beam
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
    beam.Color = ColorSequence.new(color or Color3.new(1, 1, 1))
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

-- Atualizador
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
            esp.Name.Text = object.Name
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

-- Remover
function ESP:Remove(object)
    local esp = ESP.Objects[object]
    if not esp then return end

    for _, d in pairs({esp.Name, esp.Distance, esp.Tracer}) do
        if d and d.Remove then d:Remove() end
    end

    if esp.Beam3D then pcall(function() esp.Beam3D:Destroy() end) end
    if esp.OriginAttachment then pcall(function() esp.OriginAttachment:Destroy() end) end
    if esp.TargetAttachment then pcall(function() esp.TargetAttachment:Destroy() end) end

    ESP.Objects[object] = nil
end

-- Limpar todos
function ESP:Clear()
    for object in pairs(ESP.Objects) do
        ESP:Remove(object)
    end
end

-- Ativar/Desativar
function ESP:SetEnabled(state)
    ESP.Enabled = state
end

return ESP
