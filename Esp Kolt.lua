-- ESP Library orientada a objeto por Dhiogo
-- Pronta para ser usada via loadstring

local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")

local ESP = {}
ESP.__index = ESP

ESP.Objects = {}
ESP.Settings = {
    Enabled = false,
    ShowName = false,
    ShowDistance = false,
    ShowTracer = false,
    TracerOrigin = "Bottom",
    ShowHighlightOutline = false,
    ShowHighlightFill = false,
    NameColor = Color3.new(1, 1, 1),
    DistanceColor = Color3.new(1, 1, 1),
    TracerColor = Color3.new(1, 1, 1),
}

function ESP:Add(object, label)
    local data = {
        Object = object,
        Label = label or object.Name,
        Highlight = nil,
        NameLabel = Drawing.new("Text"),
        DistanceLabel = Drawing.new("Text"),
        Tracer = Drawing.new("Line"),
    }

    -- Setup Drawing Text
    for _, text in ipairs({data.NameLabel, data.DistanceLabel}) do
        text.Visible = false
        text.Center = true
        text.Outline = true
        text.Font = 2
    end
    data.NameLabel.Size = 16
    data.DistanceLabel.Size = 14

    -- Setup Tracer
    data.Tracer.Visible = false
    data.Tracer.Thickness = 1.5
    data.Tracer.Color = ESP.Settings.TracerColor

    -- Setup Highlight
    local highlight = Instance.new("Highlight")
    highlight.Enabled = false
    highlight.FillColor = Color3.new(1, 1, 1)
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.Adornee = object
    highlight.Parent = object
    data.Highlight = highlight

    table.insert(ESP.Objects, data)
end

function ESP:Clear()
    for _, v in ipairs(self.Objects) do
        if v.Highlight then v.Highlight:Destroy() end
        if v.NameLabel then v.NameLabel:Remove() end
        if v.DistanceLabel then v.DistanceLabel:Remove() end
        if v.Tracer then v.Tracer:Remove() end
    end
    self.Objects = {}
end

function ESP:Update()
    if not ESP.Settings.Enabled then
        for _, v in ipairs(self.Objects) do
            if v.Highlight then v.Highlight.Enabled = false end
            v.NameLabel.Visible = false
            v.DistanceLabel.Visible = false
            v.Tracer.Visible = false
        end
        return
    end

    for i = #self.Objects, 1, -1 do
        local v = self.Objects[i]
        local obj = v.Object
        if not obj or not obj.Parent then
            table.remove(self.Objects, i)
            continue
        end

        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
        if not part then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then
            v.NameLabel.Visible = false
            v.DistanceLabel.Visible = false
            v.Tracer.Visible = false
            if v.Highlight then v.Highlight.Enabled = false end
            continue
        end

        local pos2D = Vector2.new(screenPos.X, screenPos.Y)
        local dist = (Camera.CFrame.Position - part.Position).Magnitude

        -- Nome
        if ESP.Settings.ShowName then
            v.NameLabel.Text = v.Label
            v.NameLabel.Color = ESP.Settings.NameColor
            v.NameLabel.Position = pos2D + Vector2.new(0, -20)
            v.NameLabel.Visible = true
        else
            v.NameLabel.Visible = false
        end

        -- Distância
        if ESP.Settings.ShowDistance then
            v.DistanceLabel.Text = string.format("%.1fm", dist)
            v.DistanceLabel.Color = ESP.Settings.DistanceColor
            v.DistanceLabel.Position = pos2D
            v.DistanceLabel.Visible = true
        else
            v.DistanceLabel.Visible = false
        end

        -- Tracer
        if ESP.Settings.ShowTracer then
            local originY = (ESP.Settings.TracerOrigin == "Top" and 0)
                or (ESP.Settings.TracerOrigin == "Center" and Camera.ViewportSize.Y / 2)
                or Camera.ViewportSize.Y
            local origin = Vector2.new(Camera.ViewportSize.X / 2, originY)
            v.Tracer.From = origin
            v.Tracer.To = pos2D
            v.Tracer.Color = ESP.Settings.TracerColor
            v.Tracer.Visible = true
        else
            v.Tracer.Visible = false
        end

        -- Highlight
        if v.Highlight then
            v.Highlight.Enabled = ESP.Settings.ShowHighlightOutline or ESP.Settings.ShowHighlightFill
            v.Highlight.OutlineTransparency = ESP.Settings.ShowHighlightOutline and 0 or 1
            v.Highlight.FillTransparency = ESP.Settings.ShowHighlightFill and 0.5 or 1
            v.Highlight.OutlineColor = ESP.Settings.TracerColor
            v.Highlight.FillColor = ESP.Settings.TracerColor
        end
    end
end

-- Atualização contínua
RunService.RenderStepped:Connect(function()
    ESP:Update()
end)

return ESP
