-- ESP Library by Dhiogo
-- Suporta Model e BasePart
-- Funcionalidades: Chams Outline, Chams Filled, Names, Distance, Tracer (Top, Center, Bottom)
-- Modificações via esp:Modify(type, property, value)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local ESP = {}
ESP.__index = ESP

-- Configurações padrão globais da ESP
ESP.Settings = {
    Enabled = true,

    ShowChamsOutline = true,
    ChamsOutlineColor = Color3.new(1, 1, 1),
    ChamsOutlineThickness = 1.5,

    ShowChamsFill = true,
    ChamsFillColor = Color3.new(0, 0, 0),
    ChamsFillTransparency = 0.7,

    ShowName = true,
    NameColor = Color3.new(1, 1, 1),
    NameTextSize = 14,
    NameFont = Enum.Font.SourceSansBold,

    ShowDistance = true,
    DistanceColor = Color3.new(1, 1, 1),
    DistanceTextSize = 12,

    ShowTracer = true,
    TracerColor = Color3.new(1, 1, 1),
    TracerThickness = 1,
    TracerOrigin = "Bottom", -- Pode ser "Top", "Center" ou "Bottom"
}

-- Tabela que armazenará as ESPs ativas: chave = objeto, valor = espInstance
ESP.Entities = {}

-- Função utilitária para criar Drawing objects
local function CreateDrawing(type)
    local success, drawing = pcall(function() return Drawing.new(type) end)
    if success then return drawing else return nil end
end

-- Função para obter posição do tracer na parte, de acordo com posição escolhida
local function GetTracerPosition(part, position)
    local cf = part.CFrame
    local size = part.Size
    if position == "Top" then
        return (cf * CFrame.new(0, size.Y/2, 0)).p
    elseif position == "Center" then
        return cf.p
    elseif position == "Bottom" then
        return (cf * CFrame.new(0, -size.Y/2, 0)).p
    else
        return cf.p -- padrão Center
    end
end

-- Cria uma nova ESP para um objeto
function ESP.New(object)
    assert(object and (object:IsA("Model") or object:IsA("BasePart")),
        "ESP só suporta Model ou BasePart")

    local self = setmetatable({}, ESP)

    self.Object = object
    self.Chams = nil
    self.ChamsFill = nil
    self.NameLabel = nil
    self.DistanceLabel = nil
    self.TracerLine = nil
    self.TracerOriginCircle = nil

    -- Cria Highlight para chams
    self.Highlight = Instance.new("Highlight")
    self.Highlight.Adornee = (object:IsA("Model") and object.PrimaryPart) or object
    self.Highlight.FillColor = ESP.Settings.ChamsFillColor
    self.Highlight.FillTransparency = ESP.Settings.ChamsFillTransparency
    self.Highlight.OutlineColor = ESP.Settings.ChamsOutlineColor
    self.Highlight.OutlineTransparency = 0
    self.Highlight.Parent = game:GetService("CoreGui")

    -- Cria Drawing objects
    if ESP.Settings.ShowName then
        self.NameLabel = CreateDrawing("Text")
        self.NameLabel.Text = object.Name or "ESP"
        self.NameLabel.Size = ESP.Settings.NameTextSize
        self.NameLabel.Color = ESP.Settings.NameColor
        self.NameLabel.Center = true
        self.NameLabel.Outline = true
        self.NameLabel.OutlineColor = Color3.new(0, 0, 0)
        self.NameLabel.Visible = true
    end

    if ESP.Settings.ShowDistance then
        self.DistanceLabel = CreateDrawing("Text")
        self.DistanceLabel.Text = ""
        self.DistanceLabel.Size = ESP.Settings.DistanceTextSize
        self.DistanceLabel.Color = ESP.Settings.DistanceColor
        self.DistanceLabel.Center = true
        self.DistanceLabel.Outline = true
        self.DistanceLabel.OutlineColor = Color3.new(0, 0, 0)
        self.DistanceLabel.Visible = true
    end

    if ESP.Settings.ShowTracer then
        self.TracerLine = CreateDrawing("Line")
        self.TracerLine.Color = ESP.Settings.TracerColor
        self.TracerLine.Thickness = ESP.Settings.TracerThickness
        self.TracerLine.Visible = true

        self.TracerOriginCircle = CreateDrawing("Circle")
        self.TracerOriginCircle.Color = ESP.Settings.TracerColor
        self.TracerOriginCircle.Thickness = 1
        self.TracerOriginCircle.Radius = 4
        self.TracerOriginCircle.Filled = true
        self.TracerOriginCircle.Visible = true
    end

    -- Aplicar configurações iniciais ao Highlight
    self.Highlight.FillColor = ESP.Settings.ChamsFillColor
    self.Highlight.FillTransparency = ESP.Settings.ChamsFillTransparency
    self.Highlight.OutlineColor = ESP.Settings.ChamsOutlineColor
    self.Highlight.Enabled = ESP.Settings.ShowChamsOutline or ESP.Settings.ShowChamsFill

    return self
end

-- Atualiza a ESP a cada frame
function ESP:Update()
    if not self.Object or not self.Highlight or not self.Highlight.Parent then
        self:Remove()
        return
    end

    -- Checa se objeto ainda existe no workspace
    if not (self.Object.Parent or (self.Object:IsA("Model") and self.Object.PrimaryPart and self.Object.PrimaryPart.Parent)) then
        self:Remove()
        return
    end

    -- Posição base para o texto: centro do objeto (PrimaryPart se Model)
    local part = (self.Object:IsA("Model") and self.Object.PrimaryPart) or self.Object
    if not part then return end

    local rootPos = part.Position
    local cameraPos = Camera.CFrame.Position

    -- Posição da etiqueta Nome (acima do objeto)
    if self.NameLabel and ESP.Settings.ShowName then
        local screenPos, onScreen = Camera:WorldToViewportPoint(rootPos + Vector3.new(0, part.Size.Y/2 + 0.5, 0))
        if onScreen then
            self.NameLabel.Position = Vector2.new(screenPos.X, screenPos.Y)
            self.NameLabel.Text = self.Object.Name
            self.NameLabel.Visible = true
        else
            self.NameLabel.Visible = false
        end
    elseif self.NameLabel then
        self.NameLabel.Visible = false
    end

    -- Distância
    if self.DistanceLabel and ESP.Settings.ShowDistance then
        local dist = (cameraPos - rootPos).Magnitude
        local screenPos, onScreen = Camera:WorldToViewportPoint(rootPos + Vector3.new(0, -part.Size.Y/2 - 0.3, 0))
        if onScreen then
            self.DistanceLabel.Position = Vector2.new(screenPos.X, screenPos.Y)
            self.DistanceLabel.Text = string.format("%.1fm", dist)
            self.DistanceLabel.Visible = true
        else
            self.DistanceLabel.Visible = false
        end
    elseif self.DistanceLabel then
        self.DistanceLabel.Visible = false
    end

    -- Tracer
    if self.TracerLine and ESP.Settings.ShowTracer then
        local tracerPos3D = GetTracerPosition(part, ESP.Settings.TracerOrigin)
        local origin2D = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y) -- base da tela (bottom-center)
        local screenPos, onScreen = Camera:WorldToViewportPoint(tracerPos3D)

        if onScreen then
            self.TracerLine.From = origin2D
            self.TracerLine.To = Vector2.new(screenPos.X, screenPos.Y)
            self.TracerLine.Color = ESP.Settings.TracerColor
            self.TracerLine.Thickness = ESP.Settings.TracerThickness
            self.TracerLine.Visible = true

            self.TracerOriginCircle.Position = origin2D
            self.TracerOriginCircle.Color = ESP.Settings.TracerColor
            self.TracerOriginCircle.Visible = true
        else
            self.TracerLine.Visible = false
            self.TracerOriginCircle.Visible = false
        end
    elseif self.TracerLine then
        self.TracerLine.Visible = false
        if self.TracerOriginCircle then
            self.TracerOriginCircle.Visible = false
        end
    end

    -- Highlight (Chams)
    self.Highlight.Enabled = ESP.Settings.Enabled and (ESP.Settings.ShowChamsFill or ESP.Settings.ShowChamsOutline)
    if self.Highlight.Enabled then
        self.Highlight.FillColor = ESP.Settings.ChamsFillColor
        self.Highlight.FillTransparency = ESP.Settings.ChamsFillTransparency
        self.Highlight.OutlineColor = ESP.Settings.ChamsOutlineColor
    end
end

-- Remove a ESP
function ESP:Remove()
    if self.NameLabel then
        self.NameLabel.Visible = false
        self.NameLabel:Remove()
        self.NameLabel = nil
    end

    if self.DistanceLabel then
        self.DistanceLabel.Visible = false
        self.DistanceLabel:Remove()
        self.DistanceLabel = nil
    end

    if self.TracerLine then
        self.TracerLine.Visible = false
        self.TracerLine:Remove()
        self.TracerLine = nil
    end

    if self.TracerOriginCircle then
        self.TracerOriginCircle.Visible = false
        self.TracerOriginCircle:Remove()
        self.TracerOriginCircle = nil
    end

    if self.Highlight then
        self.Highlight:Destroy()
        self.Highlight = nil
    end

    ESP.Entities[self.Object] = nil
end

-- Adiciona objeto para ESP
function ESP.Add(object)
    if ESP.Entities[object] then return ESP.Entities[object] end
    local espInstance = ESP.New(object)
    ESP.Entities[object] = espInstance
    return espInstance
end

-- Remove objeto da ESP
function ESP.Remove(object)
    if ESP.Entities[object] then
        ESP.Entities[object]:Remove()
        ESP.Entities[object] = nil
    end
end

-- Limpa todas ESPs
function ESP.Clear()
    for obj, espInstance in pairs(ESP.Entities) do
        espInstance:Remove()
    end
    ESP.Entities = {}
end

-- Função para modificar configurações da ESP
-- type: string ("Tracer", "ChamsOutline", "ChamsFill", "Name", "Distance")
-- property: string (ex: "Color", "Thickness", "Transparency", "Position", "TextSize")
-- value: valor novo da propriedade
function ESP.Modify(type, property, value)
    type = type:lower()
    property = property:lower()

    if type == "tracer" then
        if property == "color" then
            ESP.Settings.TracerColor = value
        elseif property == "thickness" then
            ESP.Settings.TracerThickness = value
        elseif property == "origin" or property == "position" then
            -- Aceita: "Top", "Center", "Bottom"
            if type(value) == "string" then
                local v = value:lower()
                if v == "top" or v == "center" or v == "bottom" then
                    ESP.Settings.TracerOrigin = value
                end
            end
        end
    elseif type == "chamsoutline" then
        if property == "color" then
            ESP.Settings.ChamsOutlineColor = value
        elseif property == "thickness" then
            ESP.Settings.ChamsOutlineThickness = value
        elseif property == "enabled" then
            ESP.Settings.ShowChamsOutline = value
        end
    elseif type == "chamsfill" then
        if property == "color" then
            ESP.Settings.ChamsFillColor = value
        elseif property == "transparency" then
            ESP.Settings.ChamsFillTransparency = value
        elseif property == "enabled" then
            ESP.Settings.ShowChamsFill = value
        end
    elseif type == "name" then
        if property == "color" then
            ESP.Settings.NameColor = value
        elseif property == "textsize" then
            ESP.Settings.NameTextSize = value
        elseif property == "font" then
            ESP.Settings.NameFont = value
        elseif property == "enabled" then
            ESP.Settings.ShowName = value
        end
    elseif type == "distance" then
        if property == "color" then
            ESP.Settings.DistanceColor = value
        elseif property == "textsize" then
            ESP.Settings.DistanceTextSize = value
        elseif property == "enabled" then
            ESP.Settings.ShowDistance = value
        end
    elseif type == "enabled" and property == "esp" then
        ESP.Settings.Enabled = value
    end
end

-- Atualiza todas ESPs a cada frame
RunService.RenderStepped:Connect(function()
    if not ESP.Settings.Enabled then
        -- Esconde tudo se ESP estiver desabilitada
        for _, espInstance in pairs(ESP.Entities) do
            if espInstance.NameLabel then espInstance.NameLabel.Visible = false end
            if espInstance.DistanceLabel then espInstance.DistanceLabel.Visible = false end
            if espInstance.TracerLine then espInstance.TracerLine.Visible = false end
            if espInstance.TracerOriginCircle then espInstance.TracerOriginCircle.Visible = false end
            if espInstance.Highlight then espInstance.Highlight.Enabled = false end
        end
        return
    end

    for _, espInstance in pairs(ESP.Entities) do
        espInstance:Update()
    end
end)

return ESP
