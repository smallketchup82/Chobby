-- This file is part of Chobby (GPL v2 or later).
-- macOS port changes assisted by OpenAI Codex.
function widget:GetInfo()
	return {name = "macOS Report Context", desc = "Records local replay/frame context for optional reports",
		author = "Zero-K macOS port", license = "GNU GPL v2 or later", layer = 0, enabled = true}
end
local function EncodeContext(context)
	local fields = {}
	for key, value in pairs(context) do
		if type(value) == "number" then
			fields[#fields + 1] = '"' .. key .. '":' .. tostring(value)
		elseif type(value) == "string" then
			local escaped = value:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('%c', function(c) return string.format('\\u%04x', string.byte(c)) end)
			fields[#fields + 1] = '"' .. key .. '":"' .. escaped .. '"'
		end
	end
	return '{' .. table.concat(fields, ',') .. '}'
end
local elapsed = 0
local started = os.time()
local gameID
function widget:GameID(id) gameID = id end
function widget:Update(dt)
	elapsed = elapsed + dt
	if elapsed < 1 then return end
	elapsed = 0
	if Spring.GetConfigInt("MacDisableAllTelemetry", 0) == 1 then return end
	local replay = Spring.GetReplayRecordingFilePath and Spring.GetReplayRecordingFilePath()
	local context = {started_at = started, observed_at = os.time(), frame = Spring.GetGameFrame(),
		game = Game.gameName or Game.modName, version = Game.gameVersion or Game.modVersion,
		map = Game.mapName, game_id = gameID, replay = replay}
	local file = io.open("macos-report-game.json.tmp", "w")
	if file then
		file:write(EncodeContext(context)); file:close()
		os.rename("macos-report-game.json.tmp", "macos-report-game.json")
	end
	local request = io.open("macos-report-screenshot", "r")
	if request then
		request:close(); os.remove("macos-report-screenshot")
		Spring.SendCommands("screenshot png")
	end
end
