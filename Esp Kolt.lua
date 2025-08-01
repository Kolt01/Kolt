--[[ ██████████████████ ESP LIB ██████████████████ ]]
-- ✅ Suporte a: Tracer, Highlight, Nome, Distância, ESP2D (Rounded)
-- 📌 By Dhiogo - https://raw.githubusercontent.com/Kolt01/Kolt/refs/heads/main/Esp%20Kolt.lua

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local espObjects = {}
local connections = {}

local function createHighlight(target, fill, outline, color)
	local h = Instance.new("Highlight")
	h.Adornee = target
	h.FillColor = fill and color or Color3.new()
	h.OutlineColor = outline and color or Color3.new()
	h.FillTransparency = fill and 0.5 or 1
	h.OutlineTransparency = outline and 0 or 1
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Name = "_ESPHighlight"
	h.Parent = target
	return h
end

local function createTextLabel(name)
	local text = Drawing.new("Text")
	text.Text = name
	text.Size = 14
	text.Center = true
	text.Outline = true
	text.Font = 2
	text.Visible = false
	return text
end

local function createLine()
	local line = Drawing.new("Line")
	line.Thickness = 1.5
	line.Color = Color3.fromRGB(255, 255, 255)
	line.Visible = false
	return line
end

local function createESP2D(shape, color)
	local obj
	if shape == "RoundedBox" then
		obj = Drawing.new("Square")
		obj.Filled = false
		obj.Thickness = 2
		obj.Visible = false
		obj.Color = color
		obj.Transparency = 1
		obj.Radius = 8
	elseif shape == "Circle" then
		obj = Drawing.new("Circle")
		obj.NumSides = 30
		obj.Visible = false
		obj.Color = color
	end
	return obj
end

local function distanceBetween(p1, p2)
	return (p1 - p2).Magnitude
end

local function isOnScreen(worldPos)
	local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
	return screenPos, onScreen
end

local function updateESP(obj)
	local render = connections[obj]
	if not render then return end

	local adornee = obj.Adornee:IsA("Model") and obj.Adornee.PrimaryPart or obj.Adornee
	if not adornee then return end

	render.RenderStepped = RunService.RenderStepped:Connect(function()
		if not adornee or not adornee:IsDescendantOf(workspace) then return end

		local screenPos, onScreen = isOnScreen(adornee.Position)
		local distance = math.floor(distanceBetween(Camera.CFrame.Position, adornee.Position))

		if obj.Text then
			obj.Text.Position = Vector2.new(screenPos.X, screenPos.Y - 15)
			obj.Text.Text = string.format("%s [%sm]", obj.Name or "ESP", distance)
			obj.Text.Visible = onScreen
		end

		if obj.Tracer then
			local origin = {
				Top = Vector2.new(Camera.ViewportSize.X / 2, 0),
				Middle = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2),
				Bottom = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
			}[obj.TracerOrigin or "Bottom"]

			obj.TracerLine.From = origin
			obj.TracerLine.To = Vector2.new(screenPos.X, screenPos.Y)
			obj.TracerLine.Visible = onScreen
		end

		if obj.ESP2D and obj.ESP2D.Enabled then
			local size = math.clamp(1000 / distance, 6, 40)
			obj.ESP2D.Shape.Position = Vector2.new(screenPos.X - size / 2, screenPos.Y - size / 2)
			obj.ESP2D.Shape.Size = Vector2.new(size, size)
			obj.ESP2D.Shape.Visible = onScreen
		end
	end)
end

local ESP = {}

function ESP.AddESP(settings)
	local target = settings.Target
	if not target then return end

	local holder = {
		Adornee = target,
		Name = settings.Name or "ESP",
	}

	-- Highlight
	if settings.HighlightOutline or settings.HighlightFill then
		createHighlight(target, settings.HighlightFill, settings.HighlightOutline, settings.Color or Color3.fromRGB(255,255,255))
	end

	-- Name & Distance
	if settings.Name or settings.ShowDistance then
		holder.Text = createTextLabel(settings.Name or "ESP")
	end

	-- Tracer
	if settings.Tracer then
		holder.Tracer = true
		holder.TracerOrigin = settings.TracerOrigin or "Bottom"
		holder.TracerLine = createLine()
	end

	-- ESP2D
	if settings.ESP2D and settings.ESP2D.Enabled then
		holder.ESP2D = {
			Enabled = true,
			Shape = createESP2D(settings.ESP2D.Shape, settings.ESP2D.Color or Color3.fromRGB(255, 255, 255))
		}
	end

	connections[holder] = {}
	updateESP(holder)
	table.insert(espObjects, holder)
end

function ESP.RemoveAll()
	for _, esp in pairs(espObjects) do
		if esp.Text then pcall(function() esp.Text:Remove() end) end
		if esp.TracerLine then pcall(function() esp.TracerLine:Remove() end) end
		if esp.ESP2D and esp.ESP2D.Shape then pcall(function() esp.ESP2D.Shape:Remove() end) end
	end
	for _, c in pairs(connections) do
		if c.RenderStepped then c.RenderStepped:Disconnect() end
	end
	for _, e in pairs(workspace:GetDescendants()) do
		if e:IsA("Highlight") and e.Name == "_ESPHighlight" then e:Destroy() end
	end
	espObjects = {}
	connections = {}
end

return ESP
