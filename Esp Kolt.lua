-- ESP Library - Orientada a Endereço (Model / BasePart)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local ESP = {
    Enabled = true,
    TracerOrigin = "Bottom", -- Top, Center, Bottom
    Settings = {
        ShowTracer = true,
        ShowHighlightOutline = true,
        ShowHighlightFill = true,
        ShowName = true,
        ShowDistance = true,
        ShowEntity2D = false,
    },
    Objects = {},
    Entity2D = {
        Shape = "Cylinder", -- Cylinder, Ball
        Color = Color3.fromRGB(255, 0, 0),
    },
}

-- Utilitário para calcular distância
local function getDistanceFromPlayer(pos)
    if not Camera or not Camera.CFrame then return 0 end
    return (Camera.CFrame.Position - pos).Magnitude
end

-- Cria ESP em um objeto (Model/BasePart)
function ESP:AddESP(object, displayName, color)
    if not object or self.Objects[object] then return end
    local espData = { Parts = {} }

    -- Define alvo (ponto central do ESP)
    local target = object:IsA("Model") and object:FindFirstChildWhichIsA("BasePart") or object
    if not target then return end

    -- Highlight
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

    -- Tracer + Texto
    if self.Settings.ShowTracer or self.Settings.ShowName or self.Settings.ShowDistance then
        local tracer = Drawing.new("Line")
        tracer.Thickness = 1.5
        tracer.Color = color or Color3.fromRGB(255, 255, 255)
        tracer.Visible = self.Settings.ShowTracer
        espData.Tracer = tracer

        local text = Drawing.new("Text")
        text.Size = 14
        text.Center = true
        text.Outline = true
        text.Color = color or Color3.fromRGB(255, 255, 255)
        text.Visible = self.Settings.ShowName or self.Settings.ShowDistance
        espData.Text = text
    end

    -- Forma 3D (ESP Entity 2D simulada)
    if self.Settings.ShowEntity2D then
        local shape
        if self.Entity2D.Shape == "Cylinder" then
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

    -- Update loop
    RunService.RenderStepped:Connect(function()
        if not object or not object.Parent then
            self:RemoveESP(object)
            return
        end

        local pos = target.Position
        local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
        local origin = Camera.ViewportSize / 2
        if self.TracerOrigin == "Top" then origin = Vector2.new(origin.X, 0)
        elseif self.TracerOrigin == "Bottom" then origin = Vector2.new(origin.X, Camera.ViewportSize.Y)
        end

        if self.Objects[object] then
            local data = self.Objects[object]
            if data.Tracer then
                data.Tracer.Visible = onScreen and self.Settings.ShowTracer
                data.Tracer.From = origin
                data.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
            end
            if data.Text then
                local dist = getDistanceFromPlayer(pos)
                local text = ""
                if self.Settings.ShowName then text = text .. displayName end
                if self.Settings.ShowDistance then
                    text = text .. " [" .. math.floor(dist) .. "m]"
                end
                data.Text.Text = text
                data.Text.Visible = onScreen
                data.Text.Position = Vector2.new(screenPos.X, screenPos.Y - 15)
            end
        end
    end)
end

-- Remove ESP de um objeto
function ESP:RemoveESP(object)
    local espData = self.Objects[object]
    if espData then
        if espData.Highlight then pcall(function() espData.Highlight:Destroy() end) end
        if espData.Shape then pcall(function() espData.Shape:Destroy() end) end
        if espData.Tracer then pcall(function() espData.Tracer:Remove() end) end
        if espData.Text then pcall(function() espData.Text:Remove() end) end
        self.Objects[object] = nil
    end
end

-- Remove todos
function ESP:ClearAll()
    for obj in pairs(self.Objects) do
        self:RemoveESP(obj)
    end
end

return ESP
