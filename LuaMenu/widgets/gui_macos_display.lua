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
	local metalFX = tonumber(message:match("^macMetalFXSpatial ([01])$"))
	local metalFXSetting = configuration and configuration.gameConfig.settingsNames.MacMetalFXSpatial
	if metalFX and metalFXSetting then
		configuration:SetSettingsConfigOption("MacMetalFXSpatial", metalFXSetting.options[metalFX + 1].name)
	end
	local notch = tonumber(message:match("^macNotchFullscreen ([01])$"))
	local notchSetting = configuration and configuration.gameConfig.settingsNames.MacNotchFullscreen
	if notch and notchSetting then
		configuration:SetSettingsConfigOption("MacNotchFullscreen", notchSetting.options[notch + 1].name)
	end
	local hdr = tonumber(message:match("^macHDR ([01])$"))
	local hdrSetting = configuration and configuration.gameConfig.settingsNames.MacHDR
	if hdr and hdrSetting then
		configuration:SetSettingsConfigOption("MacHDR", hdrSetting.options[hdr + 1].name)
	end
	local sharing = tonumber(message:match("^macGPUSharing ([01])$"))
	local sharingSetting = configuration and configuration.gameConfig.settingsNames.MacGPUSharing
	if sharing and sharingSetting then
		configuration:SetSettingsConfigOption("MacGPUSharing", sharingSetting.options[sharing + 1].name)
	end
	local enabled = tonumber(message:match("^macDisplayLink ([01])$"))
	local setting = configuration and configuration.gameConfig.settingsNames.MacDisplayLink
	if enabled and setting then configuration:SetSettingsConfigOption("MacDisplayLink", setting.options[enabled + 1].name) end
end

local reportElapsed = 0
function widget:Update(dt)
	if Platform.osFamily ~= "MacOS" and Platform.osFamily ~= "MacOSX" then return end
	reportElapsed = reportElapsed + dt
	if reportElapsed < 1 then return end
	reportElapsed = 0
	local configuration = WG.Chobby and WG.Chobby.Configuration
	if configuration and Spring.GetConfigInt("MacReportConfiguration", 0) == 1 then
		local file = io.open("macos-report-lobby.json", "w")
		if file then
			file:write(Spring.Utilities.json.encode({settingsMenuValues = configuration.settingsMenuValues, game_settings = configuration.game_settings}))
			file:close()
		end
	end
	if Spring.GetGameName() ~= "" then return end
	local request = io.open("macos-report-screenshot", "r")
	if request then
		request:close()
		os.remove("macos-report-screenshot")
		Spring.SendCommands("screenshot png")
	end
end
