-- This file is part of Chobby (GPL v2 or later).
-- macOS port changes assisted by OpenAI Codex.
function widget:GetInfo()
	return {name = "macOS Display", desc = "Synchronizes the shared Retina setting with the game",
		author = "Zero-K macOS port", license = "GNU GPL v2 or later", layer = 0, enabled = true}
end

function widget:RecvLuaMsg(message)
	local mode = tonumber(message:match("^macRetinaMode ([012])$"))
	local configuration = WG.Chobby and WG.Chobby.Configuration
	local setting = configuration and configuration.gameConfig.settingsNames.MacRetinaMode
	if mode and setting then
		configuration:SetSettingsConfigOption("MacRetinaMode", setting.options[mode + 1].name)
	end
end
