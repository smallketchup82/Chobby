function widget:GetInfo()
	return {
		name = "ZkMacOS Announcement",
		desc = "Announces ZkMacOS at game start and marks your starting commander",
		author = "Zero-K macOS port (OpenAI Codex assisted)",
		license = "GNU GPL v2 or later",
		layer = 0,
		enabled = true,
	}
end

local started = false
local markCommander = false
local myPlayerID
local markerPosition

function widget:Initialize()
	if (Platform.osFamily ~= "MacOS" and Platform.osFamily ~= "MacOSX")
		or Spring.IsReplay() or Spring.GetSpectatingState() or Spring.GetGameFrame() > 0 then
		widgetHandler:RemoveWidget(self)
	end
end

function widget:GameStart()
	if started or Spring.IsReplay() or Spring.GetSpectatingState() then
		return
	end
	started = true
	myPlayerID = Spring.GetMyPlayerID()
	markCommander = Spring.GetConfigInt("MacAnnounceMarker", 1) == 1
	if Spring.GetConfigInt("MacAnnounceChat", 1) == 1 then
		Spring.SendCommands("say Playing on ZkMacOS; sorry if technical issues disconnect me.")
	end
	if not markCommander then
		widgetHandler:RemoveWidget(self)
	end
end

function widget:GameFrame(frame)
	if not started or not markCommander or (frame - 1) % 15 ~= 0 then
		return
	end
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget(self)
		return
	end

	-- Capture the spawn position before the commander starts moving.
	if not markerPosition then
		local teamID = Spring.GetMyTeamID()
		local originalTeamID = Spring.GetPlayerRulesParam(myPlayerID, "commshare_orig_teamid") or teamID
		for _, unitID in ipairs(Spring.GetTeamUnits(teamID) or {}) do
			local def = UnitDefs[Spring.GetUnitDefID(unitID)]
			local params = def and def.customParams
			local ownerTeam = Spring.GetUnitRulesParam(unitID, "commander_owner_team")
			if params and (params.level or params.dynamic_comm)
				and (ownerTeam == originalTeamID or (ownerTeam == nil and originalTeamID == teamID)) then
				local x, _, z = Spring.GetUnitPosition(unitID)
				if x then
					markerPosition = {x, Spring.GetGroundHeight(x, z), z}
					break
				end
			end
		end
	end

	-- Zero-K erases commander start markers on frame 4. Allow that networked
	-- cleanup to finish before placing our ordinary, persistent map marker.
	if markerPosition and frame >= 30 then
		Spring.MarkerAddPoint(markerPosition[1], markerPosition[2], markerPosition[3], "Playing on ZkMacOS", false)
		markCommander = false
		widgetHandler:RemoveWidget(self)
	end
end
