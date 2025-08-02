-- Biblioteca ESP com suporte a FOV alto
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local ESP = {
    Enabled = true,
    TracerOrigin = "Bottom",
    Settings = {
        ShowTracer = true,
        ShowHighlightOutline = true,
        ShowHighlightFill = true,
        ShowName = true,
        ShowDistance = true,
        ShowEntity2D = false,
    },
    Distance = {
        Min = 0,
        Max = 1000,
    },
    Objects = {},
    Entity2D = {
        Shape = "Cilindro",
        Color = Color3.fromRGB(255, 0, 0),
    },
}

-- Escala com base no FOV
local function getFOVScale()
    local defaultFOV = 70
    return Camera and (defaultFOV / Camera.FieldOfView) or 1
end

-- Distância até o jogador
local function getDistanceFromPlayer(pos)
    return Camera and (Camera.CFrame.Position - pos).Magnitude or 0
end

-- Posição real do objeto
local function getRealPosition(object)
    if object:IsA("Model") then
        return object:GetPivot().Position
    elseif object:IsA("BasePart") or object:IsA("Attachment") then
        return object.Position
    end
    return nil
end

function ESP:AddESP(object, displayName, color)
    if not object or self.Objects[object] then return end

    local target = object:IsA("Model") and object:FindFirstChildWhichIsA("BasePart") or object
    if not target then return end

    local espData = { Object = object }

    -- Highlight (robusto)
    if self.Settings.ShowHighlightOutline or self.Settings.ShowHighlightFill then
        local hl = Instance.new("Highlight")
        hl.Name = "ESP_Highlight"
        hl.Adornee = object
        hl.FillColor = color or Color3.fromRGB(255, 255, 255)
        hl.OutlineColor = color or Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = self.Settings.ShowHighlightFill and 0.5 or 1
        hl.OutlineTransparency = self.Settings.ShowHighlightOutline and 0 or 1
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = object
        espData.Highlight = hl
    end

    -- Desenho: Tracer + Texto
    if self.Settings.ShowTracer or self.Settings.ShowName or self.Settings.ShowDistance then
        local tracer = Drawing.new("Line")
        tracer.Thickness = 1.5
        tracer.Color = color or Color3.fromRGB(255, 255, 255)
        tracer.Visible = false
        espData.Tracer = tracer

        local text = Drawing.new("Text")
        text.Size = 14
        text.Center = true
        text.Outline = true
        text.Color = color or Color3.fromRGB(255, 255, 255)
        text.Visible = false
        espData.Text = text
    end

    -- Forma 2D simulada (opcional)
    if self.Settings.ShowEntity2D then
        local shape
        if self.Entity2D.Shape == "Cilindro" then
            shape = Instance.new("CylinderHandleAdornment")
        elseif self.Entity2D.Shape == "Ball" then
            shape = Instance.new("SphereHandleAdornment")
        end
        if shape then
            shape.Name = "ESP_Entity2D"
            shape.Adornee = target
            shape.AlwaysOnTop = true
            shape.ZIndex = 10
            shape.Color3 = self.Entity2D.Color
            shape.Transparency = 0.4
            shape.Radius = 2
            shape.Height = 4
            shape.Parent = target
            espData.Shape = shape
        end
    end

    self.Objects[object] = espData

    -- Atualização renderizada
    espData.Connection = RunService.RenderStepped:Connect(function()
        if not object or not object.Parent then
            self:RemoveESP(object)
            return
        end

        local pos = getRealPosition(object)
        if typeof(pos) ~= "Vector3" then return end

        local dist = getDistanceFromPlayer(pos)
        local scale = getFOVScale()

        if dist < (self.Distance.Min or 0) or dist > (self.Distance.Max or 9999) then
            if espData.Highlight then espData.Highlight.Enabled = false end
            if espData.Shape then espData.Shape.Visible = false end
            if espData.Tracer then espData.Tracer.Visible = false end
            if espData.Text then espData.Text.Visible = false end
            return
        end

        local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
        local origin = Camera.ViewportSize / 2
        if self.TracerOrigin == "Top" then
            origin = Vector2.new(origin.X, 0)
        elseif self.TracerOrigin == "Bottom" then
            origin = Vector2.new(origin.X, Camera.ViewportSize.Y)
        end

        if espData.Highlight then espData.Highlight.Enabled = true end

        if espData.Shape then
            espData.Shape.Visible = true
            espData.Shape.Radius = 2 * scale
            espData.Shape.Height = 4 * scale
        end

        if espData.Tracer then
            espData.Tracer.Visible = onScreen and self.Settings.ShowTracer
            espData.Tracer.From = origin
            espData.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
            espData.Tracer.Thickness = 1.5 * scale
        end

        if espData.Text then
            local label = ""
            if self.Settings.ShowName then label = label .. displayName end
            if self.Settings.ShowDistance then
                label = label .. " [" .. math.floor(dist) .. "m]"
            end
            espData.Text.Text = label
            espData.Text.Visible = onScreen
            espData.Text.Size = 14 * scale
            espData.Text.Position = Vector2.new(screenPos.X, screenPos.Y - 15 * scale)
        end
    end)
end

function ESP:RemoveESP(object)
    local espData = self.Objects[object]
    if espData then
        if espData.Connection then espData.Connection:Disconnect() end
        if espData.Highlight then pcall(function() espData.Highlight:Destroy() end) end
        if espData.Shape then pcall(function() espData.Shape:Destroy() end) end
        if espData.Tracer then pcall(function() espData.Tracer:Remove() end) end
        if espData.Text then pcall(function() espData.Text:Remove() end) end
        self.Objects[object] = nil
    end
end

function ESP:ClearAll()
    for obj in pairs(self.Objects) do
        self:RemoveESP(obj)
    end
end

return ESP
