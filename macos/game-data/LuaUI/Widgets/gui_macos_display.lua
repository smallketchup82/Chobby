-- This file is part of the Spring engine (GPL v2 or later), see LICENSE.html
function widget:GetInfo()
	return {name = "macOS Display", desc = "Native Retina rendering settings",
		author = "Zero-K macOS port (OpenAI Codex assisted)", license = "GNU GPL v2 or later",
		layer = 0, enabled = true}
end

options_path = "Settings/Graphics/Display"
options_order = {"retina", "metalFX", "hdr", "gpuSharing", "displayLink", "notch", "fps"}

local restartPrompt

local function ShowRestartPrompt(message)
	if restartPrompt then restartPrompt:Dispose() end
	local Chili = WG.Chili
	restartPrompt = Chili.Window:New {
		parent = Chili.Screen0, x = "30%", y = "35%", width = 450, height = 185,
		caption = "Restart required", resizable = false,
	}
	Chili.TextBox:New {
		parent = restartPrompt, x = 15, y = 25, right = 15, height = 85,
		text = message or "Quit Zero-K completely and reopen it to apply the new Retina mode. Starting another battle will not apply it.",
		font = {size = 16},
	}
	Chili.Button:New {
		parent = restartPrompt, x = "30%", right = "30%", bottom = 10, height = 35,
		caption = "Keep playing",
		OnClick = {function() restartPrompt:Dispose(); restartPrompt = nil end},
	}
end

options = {
	retina = {
		name = "Retina rendering (restart required)",
		desc = "Standard uses the least bandwidth. Retina text and UI keeps the world at standard resolution. Full Retina also draws the main game scene at backing resolution and costs more GPU time. Restart Zero-K after changing this setting.",
		type = "list",
		noSave = true,
		value = tostring(Spring.GetConfigInt("MacRetinaMode", 1)),
		simpleMode = true,
		everyMode = true,
		items = {
			{key = "0", name = "Standard"},
			{key = "1", name = "Retina text and UI"},
			{key = "2", name = "Full Retina"},
		},
		OnChange = function(self)
			local mode = tonumber(self.value)
			if Spring.GetConfigInt("MacRetinaMode", 1) == mode then return end
			Spring.SetConfigInt("MacRetinaMode", mode)
			if Spring.SendLuaMenuMsg then
				Spring.SendLuaMenuMsg("macRetinaMode " .. mode)
			end
			ShowRestartPrompt()
		end,
	},
	metalFX = {
		name = "MetalFX spatial upscaling",
		desc = "Upscales the world in Retina text and UI mode, keeping UI sharp. Applies immediately. Has no effect in Standard or Full Retina mode, or on a non-Retina display. May reduce performance. Falls back to bilinear if unavailable.",
		type = "bool", noSave = true, simpleMode = true, everyMode = true,
		value = Spring.GetConfigInt("MacMetalFXSpatial", 0) == 1,
		OnChange = function(self)
			local enabled = self.value and 1 or 0
			Spring.SetConfigInt("MacMetalFXSpatial", enabled)
			if Spring.SendLuaMenuMsg then
				Spring.SendLuaMenuMsg("macMetalFXSpatial " .. enabled)
			end
		end,
	},
	hdr = {
		name = "macOS HDR display output",
		desc = "Displays the game's existing HDR lighting on a macOS HDR display. Preserves normal scene colors and UI white; adds no extra bloom or highlight expansion. Configure game lighting under Graphics / HDR (experimental). Applies immediately. Requires shared GPU textures; uses SDR if unavailable.",
		type = "bool", noSave = true, simpleMode = true, everyMode = true,
		value = Spring.GetConfigInt("MacHDR", 0) == 1,
		OnChange = function(self)
			local enabled = self.value and 1 or 0
			Spring.SetConfigInt("MacHDR", enabled)
			if Spring.SendLuaMenuMsg then
				Spring.SendLuaMenuMsg("macHDR " .. enabled)
			end
		end,
	},
	gpuSharing = {
		name = "GPU resource sharing",
		desc = "Experimental GPU resource sharing for MetalFX and SDR presentation. Avoids CPU pixel transfers but still waits for GPU completion. Applies immediately. HDR display output always requires sharing, even when this switch is off. Unsupported resources fall back to CPU transfers.",
		type = "bool", noSave = true, simpleMode = true, everyMode = true,
		value = Spring.GetConfigInt("MacGPUSharing", 0) == 1,
		OnChange = function(self)
			local enabled = self.value and 1 or 0
			Spring.SetConfigInt("MacGPUSharing", enabled)
			if Spring.SendLuaMenuMsg then
				Spring.SendLuaMenuMsg("macGPUSharing " .. enabled)
			end
		end,
	},
	displayLink = {
		name = "Experimental DisplayLink frame pacing",
		desc = "Paces frames using the display refresh. Disabled by default; may reduce performance. Applies immediately.",
		type = "bool", noSave = true, simpleMode = true, everyMode = true,
		value = Spring.GetConfigInt("MacDisplayLink", 0) == 1,
		OnChange = function(self)
			local enabled = self.value and 1 or 0
			Spring.SetConfigInt("MacDisplayLink", enabled)
			if Spring.SendLuaMenuMsg then Spring.SendLuaMenuMsg("macDisplayLink " .. enabled) end
		end,
	},
	notch = {
		name = "Notchful fullscreen (restart required)",
		desc = "Allows fullscreen to cover the camera-housing area. The resource HUD automatically adapts to the display's notch; other fullscreen modes keep the default layout. Uses desktop fullscreen without a separate Space. Quit and reopen Zero-K after changing.",
		type = "bool", noSave = true, simpleMode = true, everyMode = true,
		value = Spring.GetConfigInt("MacNotchFullscreen", 0) == 1,
		OnChange = function(self)
			local enabled = self.value and 1 or 0
			if Spring.GetConfigInt("MacNotchFullscreen", 0) == enabled then return end
			Spring.SetConfigInt("MacNotchFullscreen", enabled)
			if Spring.SendLuaMenuMsg then Spring.SendLuaMenuMsg("macNotchFullscreen " .. enabled) end
			ShowRestartPrompt("Quit Zero-K completely and reopen it to apply notchful fullscreen. Content may be hidden behind the notch.")
		end,
	},
	fps = {
		name = "Show native FPS counter",
		desc = "Shows FPS, average frame interval and the active Retina mode. Also toggled with /fps.",
		type = "bool", noSave = true, simpleMode = true, everyMode = true,
		value = Spring.GetConfigInt("ShowFPS", 1) == 1,
		OnChange = function(self)
			Spring.SendCommands("fps " .. (self.value and "1" or "0"))
		end,
	},
}

function widget:Initialize()
	if Platform.osFamily ~= "MacOS" and Platform.osFamily ~= "MacOSX" then
		widgetHandler:RemoveWidget(self)
	end
end

-- Use the notch HUD only while native fullscreen actually covers the camera
-- area. Retain the game's resource controls, tooltips and reserve actions.
local economySpacing
local savedEconomyWidth, savedExpandedWidth
local spacingElapsed = 0

local function ResourceControls(resource, reserveName)
	local reserve = resource:GetObjectByName(reserveName)
	if not reserve then return end
	local icon, labels = nil, {}
	for _, child in ipairs(resource.children) do
		if child.file and (child.file:find("ibeam.png", 1, true) or child.file:find("energy.png", 1, true)) then
			icon = child
		elseif child.classname == "label" then
			labels[#labels + 1] = child
		end
	end
	if not icon then return end
	-- The ordinary economy panel places quantity, income and deficit left to right.
	table.sort(labels, function(a, b) return a.x < b.x end)
	local originalLabels = {}
	for i = 1, math.min(3, #labels) do
		local label = labels[i]
		originalLabels[i] = {control = label, font = label.font, hitTest = label.HitTest,
			tooltip = label.tooltip, autosize = label.autosize, align = label.align, valign = label.valign,
			updateLayout = label.UpdateLayout, draw = label.DrawControl}
	end
	local flowText = {}
	for _, child in ipairs(reserve.parent.children) do
		if child.classname == "progressbar" then
			flowText[#flowText + 1] = {control = child, font = child.font, offset = child.fontOffset, draw = child.DrawControl}
		end
	end
	return {icon = icon, holder = reserve.parent, labels = originalLabels, flowText = flowText}
end

local function DrawCenteredResourceText(control)
	local caption = control.caption
	if not caption or caption == "" then return end
	local font = control.font
	-- Glyph positions already compensate for the font's overall descender.
	-- Only the caption's own descender needs centering (notably for arrows).
	local _, descender = font:GetTextHeight(caption)
	local x, y = 0, 0
	-- Old Chili draws in parent coordinates; Chili 2.1 translates controls first.
	if WG.Chili.CHILI_DIRNAME:find("chili_old/", 1, true) then
		x, y = control.x, control.y
	end
	font:Draw(caption, x + control.width / 2, y + control.height / 2 + descender / 2, "center", "center")
end

local function PositionResourceText(controls, scale)
	local labels = controls.labels
	if #labels ~= 3 then return end
	if controls.fontScale ~= scale then
		for i, original in ipairs(labels) do
			local label = original.control
			-- The 16-point frame has a 10-point colored fill. A 14-point
			-- font matches that visible height with the game's current font.
			local size = 14 / scale
			label.font = WG.GetSpecialFont(size, "mac_notch_resource_" .. i, {
				color = original.font.color, outline = true, outlineWidth = 1, outlineWeight = 2,
			})
			label.autosize, label.align, label.valign = false, "center", "center"
			-- Glyphs fit the bar even when the font's line spacing is taller.
			label.UpdateLayout = function(self) self._caption = self.caption end
			label.DrawControl = DrawCenteredResourceText
			label:UpdateLayout()
			if i == 1 then
				label.tooltip = nil
				label.HitTest = function() return nil end
			else
				-- Retain rate tooltips while allowing Ctrl-click reserve changes.
				label.HitTest = function(self)
					local _, ctrl = Spring.GetModKeyState()
					if not ctrl then return self end
				end
			end
			label:BringToFront()
			label:Invalidate()
		end
		for _, original in ipairs(controls.flowText) do
			local bar, draw = original.control, original.draw
			-- The arrow glyph is shorter than digits at the same point size.
			-- Scale it to match the approved visible size of the rate text.
			bar.font = WG.GetSpecialFont(20 / scale, "mac_notch_flow", {
				color = original.font.color, outline = true, outlineWidth = 1, outlineWeight = 2,
			})
			bar.DrawControl = function(self)
				local caption = self.caption
				self.caption = ""
				-- The energy warning overlay is a second, full-value fill.
				-- Keep its arrows, without a rectangular tint over the compact bar.
				if not self.noSkin then draw(self) end
				self.caption = caption
				DrawCenteredResourceText(self)
			end
			bar:Invalidate()
		end
		controls.fontScale = scale
	end
	local icon, holder = controls.icon, controls.holder
	labels[1].control:SetPos(icon.x - 16 / scale, icon.y, icon.width + 32 / scale, icon.height)
	labels[2].control:SetPos(holder.x, holder.y, holder.width / 2, holder.height)
	labels[3].control:SetPos(holder.x + holder.width / 2, holder.y, holder.width / 2, holder.height)
end

local function SizeResourceControls(controls, resource, topHeight, scale, isMetal)
	if not controls then return end
	local padding = resource.padding or {0, 0, 0, 0}
	local clientWidth = resource.width - padding[1] - padding[3]
	local iconSize, barWidth, barHeight = math.min(28 / scale, topHeight), 210 / scale, 16 / scale
	local barX = isMetal and (clientWidth - barWidth - 8 / scale) or 38 / scale
	local iconX = isMetal and (barX - iconSize - 6 / scale) or 4 / scale
	controls.icon:SetPos(iconX, math.max(0, (topHeight - iconSize) / 2 - padding[2]), iconSize, iconSize)
	controls.holder:SetPos(barX, math.max(0, (topHeight - barHeight) / 2 - padding[2]), barWidth, barHeight)
	PositionResourceText(controls, scale)
end

local function RestoreEconomySpacing()
	if economySpacing and not economySpacing.panel.disposed then
		local state = economySpacing
		state.panel:SetPos(state.x, nil, state.width)
		state.metal:SetPosRelative(0, nil, "50%")
		state.energy:SetPosRelative("50%", nil, "50%")
		state.metal.DrawControl = state.metalDraw
		state.energy.DrawControl = state.energyDraw
		state.metal:Invalidate()
		state.energy:Invalidate()
		state.strip:Dispose()
		for _, controls in pairs(state.resourceControls) do
			controls.icon:SetPosRelative("1%", "10%", "17%", "80%")
			controls.holder:SetPosRelative("17%", "10%", "79%", "38%")
			for _, original in ipairs(controls.flowText) do
				original.control.font = original.font
				original.control.fontOffset = original.offset
				original.control.DrawControl = original.draw
				original.control:Invalidate()
			end
			for i, original in ipairs(controls.labels) do
				local label = original.control
				label.font, label.HitTest, label.tooltip = original.font, original.hitTest, original.tooltip
				label.autosize, label.align, label.valign = original.autosize, original.align, original.valign
				label.UpdateLayout = original.updateLayout
				label.DrawControl = original.draw
				label:SetPosRelative(({"18%", "44%", "70%"})[i], "47%", "26%", "45%")
				label:Invalidate()
			end
		end
	end
	economySpacing = nil
end

function widget:SetConfigData(data)
	savedEconomyWidth = data.economyWidth
	savedExpandedWidth = data.expandedWidth
end

function widget:GetConfigData()
	return {economyWidth = savedEconomyWidth, expandedWidth = savedExpandedWidth}
end

function widget:Update(dt)
	spacingElapsed = spacingElapsed + dt
	if spacingElapsed < 0.2 then return end
	spacingElapsed = 0
	local screen = WG.Chili and WG.Chili.Screen0
	local notchLeft, notchRight
	if Spring.GetMacNotchGeometry then notchLeft, notchRight = Spring.GetMacNotchGeometry() end
	if not screen or not notchLeft then
		RestoreEconomySpacing()
		return
	end
	local panel = screen:GetChildByName("EconomyPanelDefaultTwo")
	local main = panel and panel:GetChildByName("Main Display")
	local metal = main and main:GetChildByName("Metal")
	local energy = main and main:GetChildByName("Energy")
	if not metal or not energy then RestoreEconomySpacing(); return end
	local gap = (notchRight - notchLeft + 15) / (WG.uiScale or 1)
	if not economySpacing or economySpacing.panel ~= panel then
		RestoreEconomySpacing()
		local width = panel.width
		if savedEconomyWidth and savedExpandedWidth and math.abs(width - savedExpandedWidth) < 0.01 then
			width = savedEconomyWidth
		end
		local strip = WG.Chili.Panel:New {
			parent = main, name = "macOS Center Topbar", classname = "panel_0001_small",
			x = 0, y = 0, width = width + gap, height = 38 / (WG.uiScale or 1),
			backgroundColor = {1, 1, 1, 0.95},
		}
		strip:SendToBack()
		economySpacing = {panel = panel, metal = metal, energy = energy, strip = strip,
			metalDraw = metal.DrawControl, energyDraw = energy.DrawControl,
			resourceControls = {metal = ResourceControls(metal, "MetalReserveBar"), energy = ResourceControls(energy, "EnergyReserveBar")},
			width = width, x = screen.width / 2 - width / 2}
		metal.DrawControl = function() end
		energy.DrawControl = function() end
		metal:Invalidate()
		energy:Invalidate()
	end
	local width = economySpacing.width
	savedEconomyWidth, savedExpandedWidth = width, width + gap
	local center = math.floor((notchLeft + notchRight) / 2) / (WG.uiScale or 1)
	panel:SetPos(center - (width + gap) / 2, nil, width + gap)
	metal:SetPos(0, nil, width / 2)
	energy:SetPos(width / 2 + gap, nil, width / 2)
	local commands = screen:GetChildByName("globalCommandsWindow")
	local scale = WG.uiScale or 1
	local topHeight = commands and commands.height or 38 / scale
	-- Fill only the uncovered middle; overlapping the existing side panels
	-- doubles their translucent backgrounds into dark rectangles.
	local menu = screen:GetChildByName("epicmenubar")
	local stripLeft = commands and (commands.x + commands.width) or panel.x
	local stripRight = menu and menu.x or (panel.x + width + gap)
	economySpacing.strip:SetPos(stripLeft - panel.x, 0, math.max(0, stripRight - stripLeft), topHeight)
	-- The skin's lower border is outside the usable toolbox area.
	local stripPadding = economySpacing.strip.padding
	local contentHeight = topHeight - stripPadding[4]
	SizeResourceControls(economySpacing.resourceControls.metal, metal, contentHeight, scale, true)
	SizeResourceControls(economySpacing.resourceControls.energy, energy, contentHeight, scale, false)
end

function widget:Shutdown()
	RestoreEconomySpacing()
	if restartPrompt then restartPrompt:Dispose(); restartPrompt = nil end
end
