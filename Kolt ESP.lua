--[[
📦 Model ESP Library - Versão Modular
👤 Autor: DH SOARES (Melhorias por Gemini)

🎯 Função:
Sistema de ESP para destacar objetos do tipo Model ou BasePart no jogo, cobrindo todo o conteúdo de Models.

🧩 Recursos Suportados:
✅ Nome personalizado
✅ Distância até o alvo
✅ Tracer (linha do centro da tela até o alvo)
✅ Highlight Fill (preenchimento)
✅ Highlight Outline (contorno)

🔍 Observações:
Compatível com objetos diretamente referenciados (Model/BasePart).
Otimizado para uso em jogos como DOORS, com múltiplos objetos simultâneos.
]]

local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera

local ModelESP = {}
ModelESP.Objects = {}
ModelESP.Enabled = true

-- Define os pontos de origem para o tracer
local tracerOrigins = {
	Top = function(vs) return Vector2.new(vs.X / 2, 0) end,
	Center = function(vs) return Vector2.new(vs.X / 2, vs.Y / 2) end,
	Bottom = function(vs) return Vector2.new(vs.X / 2, vs.Y) end,
	Left = function(vs) return Vector2.new(0, vs.Y / 2) end,
	Right = function(vs) return Vector2.new(vs.X, vs.Y / 2) end,
}

-- Calcula o centro de um modelo, mesmo que não tenha um PrimaryPart definido
local function getModelCenter(model)
	local total, count = Vector3.zero, 0
	local parts = model:GetDescendants()

	for _, p in ipairs(parts) do
		if p:IsA("BasePart") and p.CanCollide and p.Transparency < 1 then -- Considera apenas partes visíveis e colidíveis
			total += p.Position
			count += 1
		end
	end

	if count == 0 then
		-- Fallback: If no visible BaseParts, try using WorldPivot or just the model's position
		if model.PrimaryPart then
			return model.PrimaryPart.Position
		elseif model:IsA("Model") and model.WorldPivot then
			return model.WorldPivot.Position
		else
			return nil
		end
	end

	local center = total / count
	if center.Magnitude ~= center.Magnitude then return nil end -- NaN check
	return center
end

-- Função auxiliar para criar objetos Drawing
local function createDrawing(class, props)
	local obj = Drawing.new(class)
	for k, v in pairs(props) do obj[k] = v end
	return obj
end

--- Adiciona um objeto para ser rastreado pelo ESP.
-- @param target (Instance) O objeto a ser rastreado (Model ou BasePart).
-- @param config (table) Tabela de configurações para o ESP.
function ModelESP:Add(target, config)
	if not target or not target:IsA("Instance") then return end

	local isModel = target:IsA("Model")
	local isBasePart = target:IsA("BasePart")

	if not isModel and not isBasePart then return end

	-- Remove highlights antigos para evitar duplicação
	for _, obj in pairs(target:GetChildren()) do
		if obj:IsA("Highlight") and obj.Name:match("^ESPHighlight") then obj:Destroy() end
	end

	local cfg = {
		Target = target,
		Color = config.Color or Color3.fromRGB(255, 255, 255),
		Name = config.Name or target.Name,
		ShowName = config.ShowName or false,
		ShowDistance = config.ShowDistance or false,
		Tracer = config.Tracer or false,
		HighlightFill = config.HighlightFill or false,
		HighlightOutline = config.HighlightOutline or false,
		TracerOrigin = config.TracerOrigin or "Bottom",
		MinDistance = config.MinDistance or 0,
		MaxDistance = config.MaxDistance or math.huge,
	}

	-- Inicializa Drawing objects
	cfg.tracerLine = cfg.Tracer and createDrawing("Line", {
		Thickness = 1.5,
		Color = cfg.Color,
		Transparency = 1,
		Visible = false
	}) or nil

	cfg.nameText = cfg.ShowName and createDrawing("Text", {
		Text = cfg.Name,
		Color = cfg.Color,
		Size = 16,
		Center = true,
		Outline = true,
		Font = 2,
		Visible = false
	}) or nil

	cfg.distanceText = cfg.ShowDistance and createDrawing("Text", {
		Text = "",
		Color = cfg.Color,
		Size = 14,
		Center = true,
		Outline = true,
		Font = 2,
		Visible = false
	}) or nil

	-- Inicializa Highlight objects
	if cfg.HighlightFill then
		local highlightFill = Instance.new("Highlight")
		highlightFill.Name = "ESPHighlightFill"
		highlightFill.FillColor = cfg.Color
		highlightFill.FillTransparency = 0.6
		highlightFill.OutlineTransparency = 1
		highlightFill.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlightFill.Parent = target -- Parent to the target itself
		cfg.highlightFill = highlightFill
	end

	if cfg.HighlightOutline then
		local highlightOutline = Instance.new("Highlight")
		highlightOutline.Name = "ESPHighlightOutline"
		highlightOutline.FillTransparency = 1
		highlightOutline.OutlineColor = cfg.Color
		highlightOutline.OutlineTransparency = 0
		highlightOutline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlightOutline.Parent = target -- Parent to the target itself
		cfg.highlightOutline = highlightOutline
	end

	table.insert(ModelESP.Objects, cfg)
end

--- Remove um objeto do rastreamento ESP.
-- @param target (Instance) O objeto a ser removido.
function ModelESP:Remove(target)
	for i = #ModelESP.Objects, 1, -1 do
		local obj = ModelESP.Objects[i]
		if obj.Target == target then
			if obj.tracerLine then obj.tracerLine:Remove() end
			if obj.nameText then obj.nameText:Remove() end
			if obj.distanceText then obj.distanceText:Remove() end
			if obj.highlightFill then obj.highlightFill:Destroy() end
			if obj.highlightOutline then obj.highlightOutline:Destroy() end
			table.remove(ModelESP.Objects, i)
			break -- Assumes only one entry per target
		end
	end
end

--- Limpa todos os objetos rastreados pelo ESP.
function ModelESP:Clear()
	for _, obj in ipairs(ModelESP.Objects) do
		if obj.tracerLine then obj.tracerLine:Remove() end
		if obj.nameText then obj.nameText:Remove() end
		if obj.distanceText then obj.distanceText:Remove() end
		if obj.highlightFill then obj.highlightFill:Destroy() end
		if obj.highlightOutline then obj.highlightOutline:Destroy() end
	end
	ModelESP.Objects = {}
end

-- Loop principal de atualização do ESP
RunService.RenderStepped:Connect(function()
	if not ModelESP.Enabled then return end

	local vs = camera.ViewportSize

	for i = #ModelESP.Objects, 1, -1 do
		local esp = ModelESP.Objects[i]
		local target = esp.Target

		-- Verifica se o alvo ainda existe e é válido
		if not target or not target.Parent or (target:IsA("Model") and not getModelCenter(target)) then
			ModelESP:Remove(target)
			continue
		end

		local pos3D = target:IsA("Model") and getModelCenter(target) or target.Position
		if not pos3D then -- Should not happen if previous check is robust, but for safety
			ModelESP:Remove(target)
			continue
		end

		local success, pos2D = pcall(function()
			return camera:WorldToViewportPoint(pos3D)
		end)

		local onScreen = success and pos2D.Z > 0
		local distance = (camera.CFrame.Position - pos3D).Magnitude
		local visible = onScreen and distance >= esp.MinDistance and distance <= esp.MaxDistance

		-- Verificação adicional de posição inválida ou fora da tela
		if not visible or pos2D.X ~= pos2D.X or pos2D.Y ~= pos2D.Y then -- NaN check
			if esp.tracerLine then esp.tracerLine.Visible = false end
			if esp.nameText then esp.nameText.Visible = false end
			if esp.distanceText then esp.distanceText.Visible = false end
			if esp.highlightFill then esp.highlightFill.Enabled = false end
			if esp.highlightOutline then esp.highlightOutline.Enabled = false end
			continue
		end

		-- Atualiza o Tracer
		if esp.tracerLine then
			esp.tracerLine.From = tracerOrigins[esp.TracerOrigin](vs)
			esp.tracerLine.To = Vector2.new(pos2D.X, pos2D.Y)
			esp.tracerLine.Visible = true
			esp.tracerLine.Color = esp.Color
		end

		-- Atualiza o Nome
		if esp.nameText then
			esp.nameText.Position = Vector2.new(pos2D.X, pos2D.Y - 20)
			esp.nameText.Visible = true
			esp.nameText.Text = esp.Name
			esp.nameText.Color = esp.Color
		end

		-- Atualiza a Distância
		if esp.distanceText then
			esp.distanceText.Position = Vector2.new(pos2D.X, pos2D.Y + 6)
			esp.distanceText.Visible = true
			esp.distanceText.Text = string.format("%.1fm", distance) -- Removed division by 3.57 for more accurate meters
			esp.distanceText.Color = esp.Color
		end

		-- Ativa e atualiza os Highlights
		if esp.highlightFill then
			esp.highlightFill.Enabled = true
			esp.highlightFill.FillColor = esp.Color
			-- Highlight.Adornee is set once in Add function, no need to update here
		end
		if esp.highlightOutline then
			esp.highlightOutline.Enabled = true
			esp.highlightOutline.OutlineColor = esp.Color
			-- Highlight.Adornee is set once in Add function, no need to update here
		end
	end
end)

return ModelESP
