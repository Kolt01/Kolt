-- ESP Library - Orientada a Endereço (Model / BasePart / outros)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local ESP = {
    Enabled = true,
    TracerOrigin = "Bottom", -- Top, Center, Bottom
    TracerLengthMultiplier = 1, -- 1 = tamanho padrão. Ex: 1.25 = 25% maior

    Fonts = {
        ["UI"] = 0,
        ["System"] = 1,
        ["Plex"] = 2,
        ["Monospace"] = 3,
    },

    Settings = {
        ShowTracer = true,
        ShowTracerOutline = true,
        ShowHighlightOutline = true,
        ShowHighlightFill = true,
        ShowName = true,
        ShowDistance = true,
        ShowEntity2D = false,
        Font = "Plex", -- Nome da fonte da tabela Fonts
    },

    TracerOutline = {
        Enabled = true,
        Color = Color3.fromRGB(0, 0, 0),
        Thickness = 3.5, -- precisa ser maior que o tracer normal
    },

    Distance = {
        Min = 0,
        Max = 1000,
    },

    Entity2D = {
        Shape = "Cylinder", -- Cylinder, Ball
        Color = Color3.fromRGB(255, 0, 0),
    },

    Objects = {},
}

local function getDistanceFromPlayer(pos)
    return (Camera.CFrame.Position - pos).Magnitude
end

function ESP:AddESP(object, displayName, color)
    if not object or self.Objects[object] then return end
    local espData = { Parts = {} }

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

    -- Tracer, Texts
    if self.Settings.ShowTracer or self.Settings.ShowName or self.Settings.ShowDistance then
        local tracer = Drawing.new("Line")
        tracer.Thickness = 1.5
        tracer.Color = color or Color3.fromRGB(255, 255, 255)
        tracer.Visible = false
        espData.Tracer = tracer

        -- Tracer outline (opcional)
        if self.Settings.ShowTracer and self.Settings.ShowTracerOutline then
            local outline = Drawing.new("Line")
            outline.Thickness = self.TracerOutline.Thickness
            outline.Color = self.TracerOutline.Color
            outline.Visible = false
            espData.TracerOutline = outline
        end

        local nameText = Drawing.new("Text")
        nameText.Size = 14
        nameText.Center = true
        nameText.Outline = true
        nameText.Color = color or Color3.fromRGB(255, 255, 255)
        nameText.Visible = false
        nameText.Font = self.Fonts[self.Settings.Font]
        espData.NameText = nameText

        local distanceText = Drawing.new("Text")
        distanceText.Size = 13
        distanceText.Center = true
        distanceText.Outline = true
        distanceText.Color = color or Color3.fromRGB(200, 200, 200)
        distanceText.Visible = false
        distanceText.Font = self.Fonts[self.Settings.Font]
        espData.DistanceText = distanceText
    end

    -- Entity 2D shape
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

    RunService.RenderStepped:Connect(function()
        if not object or not object.Parent then
            self:RemoveESP(object)
            return
        end

        local pos = target.Position
        local dist = getDistanceFromPlayer(pos)
        if dist < (ESP.Distance.Min or 0) or dist > (ESP.Distance.Max or 9999) then
            if espData.Highlight then espData.Highlight.Enabled = false end
            if espData.Shape then espData.Shape.Visible = false end
            if espData.Tracer then espData.Tracer.Visible = false end
            if espData.TracerOutline then espData.TracerOutline.Visible = false end
            if espData.NameText then espData.NameText.Visible = false end
            if espData.DistanceText then espData.DistanceText.Visible = false end
            return
        end

        local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
        if not onScreen then return end

        local origin = Camera.ViewportSize / 2
        if self.TracerOrigin == "Top" then origin = Vector2.new(origin.X, 0)
        elseif self.TracerOrigin == "Bottom" then origin = Vector2.new(origin.X, Camera.ViewportSize.Y)
        end

        local toPos = Vector2.new(screenPos.X, screenPos.Y)
        local fromPos = origin:Lerp(toPos, self.TracerLengthMultiplier)

        -- Tracer
        if espData.Tracer then
            espData.Tracer.From = fromPos
            espData.Tracer.To = toPos
            espData.Tracer.Visible = self.Settings.ShowTracer
        end

        -- Tracer Outline
        if espData.TracerOutline then
            espData.TracerOutline.From = fromPos
            espData.TracerOutline.To = toPos
            espData.TracerOutline.Visible = self.Settings.ShowTracer and self.Settings.ShowTracerOutline
        end

        -- Name
        if espData.NameText then
            espData.NameText.Text = self.Settings.ShowName and displayName or ""
            espData.NameText.Position = Vector2.new(screenPos.X, screenPos.Y - 18)
            espData.NameText.Visible = self.Settings.ShowName
        end

        -- Distance
        if espData.DistanceText then
            espData.DistanceText.Text = self.Settings.ShowDistance and ("[" .. math.floor(dist) .. "m]") or ""
            espData.DistanceText.Position = Vector2.new(screenPos.X, screenPos.Y)
            espData.DistanceText.Visible = self.Settings.ShowDistance
        end

        if espData.Highlight then espData.Highlight.Enabled = true end
        if espData.Shape then espData.Shape.Visible = true end
    end)
end

function ESP:RemoveESP(object)
    local data = self.Objects[object]
    if data then
        if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
        if data.Shape then pcall(function() data.Shape:Destroy() end) end
        if data.Tracer then pcall(function() data.Tracer:Remove() end) end
        if data.TracerOutline then pcall(function() data.TracerOutline:Remove() end) end
        if data.NameText then pcall(function() data.NameText:Remove() end) end
        if data.DistanceText then pcall(function() data.DistanceText:Remove() end) end
        self.Objects[object] = nil
    end
end

function ESP:ClearAll()
    for obj in pairs(self.Objects) do
        self:RemoveESP(obj)
    end
end

return ESP
