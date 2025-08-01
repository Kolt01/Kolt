-- ESP Library - Orientada a Endereço (Model / BasePart)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local ESP = {
    Enabled = true,
    TracerOrigin = "Bottom", -- Top, Center, Bottom
    TracerLength = 100,      -- Novo: comprimento extra para o tracer (cumprimento)
    TracerOutline = true,    -- Novo: contorno para tracer
    Settings = {
        ShowTracer = true,
        ShowHighlightOutline = true,
        ShowHighlightFill = true,
        ShowName = true,
        ShowDistance = true,
        ShowEntity2D = false,
        Font = Enum.Font.GothamBold, -- Fonte padrão, pode ser alterada
    },
    Distance = {
        Min = 0,     -- Distância mínima (em studs)
        Max = 1000,  -- Distância máxima (em studs)
    },
    Objects = {},
    Entity2D = {
        Shape = "Cylinder", -- Cylinder, Ball
        Color = Color3.fromRGB(255, 0, 0),
    },
}

-- Fontes disponíveis (roblox Drawing.Text suporta essas)
ESP.AvailableFonts = {
    Enum.Font.Arial,
    Enum.Font.ArialBold,
    Enum.Font.ArialItalic,
    Enum.Font.Gotham,
    Enum.Font.GothamBold,
    Enum.Font.GothamSemibold,
    Enum.Font.SourceSans,
    Enum.Font.SourceSansBold,
    Enum.Font.SourceSansSemibold,
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

    -- Tracer + Textos (nome e distância separados)
    if self.Settings.ShowTracer or self.Settings.ShowName or self.Settings.ShowDistance then  
        local tracer = Drawing.new("Line")  
        tracer.Thickness = 1.5  
        tracer.Color = color or Color3.fromRGB(255, 255, 255)  
        tracer.Visible = false  
        tracer.ZIndex = 5
        espData.Tracer = tracer  

        -- Se contorno ativo, cria uma linha contorno (espessura maior atrás)
        local tracerOutline
        if self.TracerOutline then
            tracerOutline = Drawing.new("Line")
            tracerOutline.Thickness = 3
            tracerOutline.Color = Color3.new(0, 0, 0) -- preto para contorno
            tracerOutline.Visible = false
            tracerOutline.ZIndex = 4
            espData.TracerOutline = tracerOutline
        end

        local nameText = Drawing.new("Text")
        nameText.Size = 14
        nameText.Center = true
        nameText.Outline = true
        nameText.Color = color or Color3.fromRGB(255, 255, 255)
        nameText.Visible = false
        nameText.Font = self.Settings.Font
        nameText.ZIndex = 10
        espData.NameText = nameText

        local distText = Drawing.new("Text")
        distText.Size = 12
        distText.Center = true
        distText.Outline = true
        distText.Color = color or Color3.fromRGB(200, 200, 200)
        distText.Visible = false
        distText.Font = self.Settings.Font
        distText.ZIndex = 10
        espData.DistanceText = distText
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
    local connection
    connection = RunService.RenderStepped:Connect(function()  
        if not object or not object.Parent then  
            self:RemoveESP(object)  
            connection:Disconnect()
            return  
        end  

        local pos = target.Position  
        local dist = getDistanceFromPlayer(pos)  
        if dist < (self.Distance.Min or 0) or dist > (self.Distance.Max or 9999) then  
            if espData.Highlight then espData.Highlight.Enabled = false end  
            if espData.Shape then espData.Shape.Visible = false end  
            if espData.Tracer then espData.Tracer.Visible = false end  
            if espData.TracerOutline then espData.TracerOutline.Visible = false end
            if espData.NameText then espData.NameText.Visible = false end  
            if espData.DistanceText then espData.DistanceText.Visible = false end  
            return  
        end  

        local screenPos, onScreen = Camera:WorldToViewportPoint(pos)  
        if not onScreen then
            if espData.Highlight then espData.Highlight.Enabled = false end  
            if espData.Shape then espData.Shape.Visible = false end  
            if espData.Tracer then espData.Tracer.Visible = false end  
            if espData.TracerOutline then espData.TracerOutline.Visible = false end
            if espData.NameText then espData.NameText.Visible = false end  
            if espData.DistanceText then espData.DistanceText.Visible = false end  
            return
        end

        local viewportSize = Camera.ViewportSize
        local origin = Vector2.new(viewportSize.X / 2, viewportSize.Y)
        if self.TracerOrigin == "Top" then
            origin = Vector2.new(viewportSize.X / 2, 0)
        elseif self.TracerOrigin == "Center" then
            origin = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
        end

        -- Ajuste do tracer para comprimento extra (cumprimento)
        local direction = (Vector2.new(screenPos.X, screenPos.Y) - origin).Unit
        local tracerEnd = origin + direction * (self.TracerLength or 100)

        -- Update Highlight e Shape
        if espData.Highlight then espData.Highlight.Enabled = true end  
        if espData.Shape then espData.Shape.Visible = true end  

        -- Update Tracer e contorno
        if espData.Tracer then
            espData.Tracer.Visible = self.Settings.ShowTracer
            espData.Tracer.From = origin
            espData.Tracer.To = tracerEnd
            espData.Tracer.Color = color or Color3.fromRGB(255, 255, 255)
        end
        if espData.TracerOutline then
            espData.TracerOutline.Visible = self.Settings.ShowTracer
            espData.TracerOutline.From = origin
            espData.TracerOutline.To = tracerEnd
        end

        -- Update texts separados (nome em cima, distância embaixo)
        if espData.NameText then
            espData.NameText.Text = self.Settings.ShowName and displayName or ""
            espData.NameText.Visible = self.Settings.ShowName and true or false
            espData.NameText.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
            espData.NameText.Color = color or Color3.fromRGB(255, 255, 255)
            espData.NameText.Font = self.Settings.Font
        end
        if espData.DistanceText then
            espData.DistanceText.Text = self.Settings.ShowDistance and ("[" .. math.floor(dist) .. "m]") or ""
            espData.DistanceText.Visible = self.Settings.ShowDistance and true or false
            espData.DistanceText.Position = Vector2.new(screenPos.X, screenPos.Y - 5)
            espData.DistanceText.Color = color or Color3.fromRGB(200, 200, 200)
            espData.DistanceText.Font = self.Settings.Font
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
        if espData.TracerOutline then pcall(function() espData.TracerOutline:Remove() end) end
        if espData.NameText then pcall(function() espData.NameText:Remove() end) end
        if espData.DistanceText then pcall(function() espData.DistanceText:Remove() end) end
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
