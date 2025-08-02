--[[
📦 Model ESP Library - Versão Refinada
👤 Autor: DH SOARES (Melhorias por Gemini & Copilot)

🎯 Função:
Sistema de ESP para destacar objetos do tipo Model ou BasePart no jogo, com suporte a Highlight, Text e Tracer.

🧩 Recursos:
✅ Nome e Distância
✅ Tracer
✅ Highlight (Fill e Outline configuráveis em 1 único objeto)
]]

local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera

local ModelESP = {
	Objects = {},
	Enabled = true,
}

local tracerOrigins = {
	Top = function(vs) return Vector2.new(vs.X / 2, 0) end,
	Center = function(vs) return Vector2.new(vs.X / 2, vs.Y / 2) end,
	Bottom = function(vs) return Vector2.new(vs.X / 2, vs.Y) end,
	Left = function(vs) return Vector2.new(0, vs.Y / 2) end,
	Right = function(vs) return Vector2.new(vs.X, vs.Y / 2) end,
}

local function getModelCenter(model)
	local total, count = Vector3.zero, 0
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 and p.CanCollide then
			total += p.Position
			count += 1
		end
	end
	if count > 0 then
		local center = total / count
		if center.Magnitude == center.Magnitude then
			return center
		end
	end
	return model.PrimaryPart and model.PrimaryPart.Position or (model:IsA("Model") and model.WorldPivot.Position) or nil
end

local function createDrawing(class, props)
	local obj = Drawing.new(class)
	for k, v in pairs(props) do obj[k] = v end
	return obj
end

function ModelESP:Add(target, config)
	if not target or not target:IsA("Instance") then return end

	local isModel, isBasePart = target:IsA("Model"), target:IsA("BasePart")
	if not isModel and not isBasePart then return end

	for _, obj in ipairs(target:GetChildren()) do
		if obj:IsA("Highlight") and obj.Name == "ESPHighlight" then
			obj:Destroy()
		end
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
		TracerOrigin = tracerOrigins[config.TracerOrigin] and config.TracerOrigin or "Bottom",
		MinDistance = config.MinDistance or 0,
		MaxDistance = config.MaxDistance or math.huge,
	}

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

	local highlight = Instance.new("Highlight")
	highlight.Name = "ESPHighlight"
	highlight.FillColor = cfg.Color
	highlight.OutlineColor = cfg.Color
	highlight.FillTransparency = cfg.HighlightFill and 0.6 or 1
	highlight.OutlineTransparency = cfg.HighlightOutline and 0 or 1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = target
	cfg.highlight = highlight

	table.insert(ModelESP.Objects, cfg)
end

function ModelESP:Remove(target)
	for i = #self.Objects, 1, -1 do
		local obj = self.Objects[i]
		if obj.Target == target then
			pcall(function() obj.tracerLine and obj.tracerLine:Remove() end)
			pcall(function() obj.nameText and obj.nameText:Remove() end)
			pcall(function() obj.distanceText and obj.distanceText:Remove() end)
			pcall(function() obj.highlight and obj.highlight:Destroy() end)
			table.remove(self.Objects, i)
		end
	end
end

function ModelESP:Clear()
	for _, obj in ipairs(self.Objects) do
		pcall(function() obj.tracerLine and obj.tracerLine:Remove() end)
		pcall(function() obj.nameText and obj.nameText:Remove() end)
		pcall(function() obj.distanceText and obj.distanceText:Remove() end)
		pcall(function() obj.highlight and obj.highlight:Destroy() end)
	end
	self.Objects = {}
end

RunService.RenderStepped:Connect(function()
	if not ModelESP.Enabled then return end
	local vs = camera.ViewportSize

	for i = #ModelESP.Objects, 1, -1 do
		local esp = ModelESP.Objects[i]
		local target = esp.Target
		if not target or not target.Parent or (target:IsA("Model") and not getModelCenter(target)) then
			ModelESP:Remove(target)
			continue
		end

		local pos3D = target:IsA("Model") and getModelCenter(target) or (target:IsA("BasePart") and target.Position)
		if not pos3D then
			ModelESP:Remove(target)
			continue
		end

		local success, pos2D = pcall(function()
			return camera:WorldToViewportPoint(pos3D)
		end)

		local onScreen = success and pos2D.Z > 0
		local distance = (camera.CFrame.Position - pos3D).Magnitude
		local visible = onScreen and distance >= esp.MinDistance and distance <= esp.MaxDistance

		if not visible or pos2D.X ~= pos2D.X or pos2D.Y ~= pos2D.Y then
			if esp.tracerLine then esp.tracerLine.Visible = false end
			if esp.nameText then esp.nameText.Visible = false end
			if esp.distanceText then esp.distanceText.Visible = false end
			if esp.highlight then esp.highlight.Enabled = false end
			continue
		end

		if esp.tracerLine then
			esp.tracerLine.From = tracerOrigins[esp.TracerOrigin](vs)
			esp.tracerLine.To = Vector2.new(pos2D.X, pos2D.Y)
			esp.tracerLine.Visible = true
			esp.tracerLine.Color = esp.Color
		end

		if esp.nameText then
			esp.nameText.Position = Vector2.new(pos2D.X, pos2D.Y - 20)
			esp.nameText.Visible = true
			esp.nameText.Text = esp.Name
			esp.nameText.Color = esp.Color
		end

		if esp.distanceText then
			esp.distanceText.Position = Vector2.new(pos2D.X, pos2D.Y + 6)
			esp.distanceText.Visible = true
			esp.distanceText.Text = string.format("%.1fm", distance)
			esp.distanceText.Color = esp.Color
		end

		if esp.highlight then
			esp.highlight.Enabled = true
			esp.highlight.FillColor = esp.Color
			esp.highlight.OutlineColor = esp.Color
			esp.highlight.FillTransparency = esp.HighlightFill and 0.6 or 1
			esp.highlight.OutlineTransparency = esp.HighlightOutline and 0 or 1
		end
	end
end)

return ModelESP
