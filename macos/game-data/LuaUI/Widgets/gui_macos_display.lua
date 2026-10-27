-- This file is part of the Spring engine (GPL v2 or later), see LICENSE.html
function widget:GetInfo()
	return {name = "macOS Display", desc = "Native Retina rendering settings",
		author = "Zero-K macOS port (OpenAI Codex assisted)", license = "GNU GPL v2 or later",
		layer = 0, enabled = true}
end

options_path = "Settings/Graphics/Display"
options_order = {"retina", "fps"}

local restartPrompt

local function ShowRestartPrompt()
	if restartPrompt then restartPrompt:Dispose() end
	local Chili = WG.Chili
	restartPrompt = Chili.Window:New {
		parent = Chili.Screen0, x = "30%", y = "35%", width = 450, height = 185,
		caption = "Restart required", resizable = false,
	}
	Chili.TextBox:New {
		parent = restartPrompt, x = 15, y = 25, right = 15, height = 85,
		text = "Quit Zero-K completely and reopen it to apply the new Retina mode. Starting another battle will not apply it.",
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

function widget:Shutdown()
	if restartPrompt then restartPrompt:Dispose(); restartPrompt = nil end
end
