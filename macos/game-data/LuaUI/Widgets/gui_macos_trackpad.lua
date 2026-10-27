-- This file is part of the Spring engine (GPL v2 or later), see LICENSE.html

function widget:GetInfo()
	return {
		name = "macOS Trackpad",
		desc = "Gesture camera controls for the native macOS engine",
		author = "Zero-K macOS port (OpenAI Codex assisted)",
		license = "GNU GPL v2 or later",
		layer = 0,
		enabled = true,
	}
end

options_path = "Settings/Camera/Trackpad"
options_order = {"enabled", "pan", "zoom", "tilt", "invert", "momentum", "help"}

local function BooleanOption(name, key, default)
	return {
		name = name,
		type = "bool",
		simpleMode = true,
		everyMode = true,
		value = Spring.GetConfigInt(key, default and 1 or 0) == 1,
		OnChange = function(self)
			Spring.SetConfigInt(key, self.value and 1 or 0)
		end,
	}
end

local function SensitivityOption(name, key)
	return {
		name = name,
		type = "number",
		simpleMode = true,
		everyMode = true,
		value = Spring.GetConfigFloat(key, 1),
		min = 0.1,
		max = 4,
		step = 0.1,
		OnChange = function(self)
			Spring.SetConfigFloat(key, self.value)
		end,
	}
end

options = {
	enabled = BooleanOption("Trackpad camera controls", "MacTrackpadEnabled", true),
	pan = SensitivityOption("Pan sensitivity", "MacTrackpadPanSpeed"),
	zoom = SensitivityOption("Pinch sensitivity", "MacTrackpadZoomSpeed"),
	tilt = SensitivityOption("Tilt sensitivity", "MacTrackpadTiltSpeed"),
	invert = BooleanOption("Reverse camera pan", "MacTrackpadInvertPan", false),
	momentum = BooleanOption("Camera momentum", "MacTrackpadMomentum", false),
	help = {
		name = "Two fingers: pan. Pinch: zoom. Three fingers up/down: tilt. Option + two fingers: tilt fallback. Taps and right-clicks use macOS settings. Move Mission Control/App Exposé to four fingers if they intercept tilt.",
		type = "text",
		simpleMode = true,
		everyMode = true,
	},
}

function widget:Initialize()
	if Platform.osFamily ~= "MacOS" and Platform.osFamily ~= "MacOSX" then
		widgetHandler:RemoveWidget(self)
		return
	end
	for _, key in ipairs(options_order) do
		local option = options[key]
		if option.OnChange then
			option:OnChange()
		end
	end
end
