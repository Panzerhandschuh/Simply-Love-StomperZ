-- Fetch each player's GrooveStats personal bests for the current chart before the new score
-- gets submitted, so ScreenEvaluation can compare the new score against the previous bests.
-- The results are stored in SL[pn].OnlinePB and consumed by ScreenEvaluation's AutoSubmitScore.lua.

if GAMESTATE:IsCourseMode() or not IsServiceAllowed(SL.GrooveStats.GetScores) then return end

local FindSelfEntry = function(leaderboard)
	if not leaderboard then return nil end
	for entry in ivalues(leaderboard) do
		if entry["isSelf"] then return entry end
	end
	return nil
end

local LeaderboardRequestProcessor = function(res)
	if res.error or res.statusCode ~= 200 then return end

	local data = JsonDecode(res.body)
	if not data then return end

	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		local pn = ToEnumShortString(player)
		local playerData = data["player"..(player == PLAYER_1 and 1 or 2)]

		if playerData and playerData["chartHash"] == SL[pn].Streams.Hash then
			local itgEntry = FindSelfEntry(playerData["gsLeaderboard"])
			local exEntry = FindSelfEntry(playerData["exLeaderboard"])

			SL[pn].OnlinePB = {
				Hash=playerData["chartHash"],
				-- Event charts get their own progress box, so the personal best box shouldn't display.
				IsEvent=(playerData["rpg"] ~= nil or playerData["itl"] ~= nil),
				-- Scores are in hundredths of a percent. nil means there's no score on GrooveStats yet.
				ITG=itgEntry and itgEntry["score"] or nil,
				EX=exEntry and exEntry["score"] or nil,
				ITGRank=itgEntry and itgEntry["rank"] or nil,
				EXRank=exEntry and exEntry["rank"] or nil,
			}
		end
	end
end

-- The spinner from RequestResponseActor isn't wanted during gameplay, so keep it hidden.
return Def.ActorFrame{
	InitCommand=function(self) self:visible(false) end,

	RequestResponseActor(0, 0)..{
		OnCommand=function(self)
			local sendRequest = false
			local headers = {}
			local query = {
				maxLeaderboardResults=3,
			}

			for player in ivalues(GAMESTATE:GetHumanPlayers()) do
				local pn = ToEnumShortString(player)
				local n = player == PLAYER_1 and 1 or 2
				-- Clear out any data from the previous song.
				SL[pn].OnlinePB = nil

				if SL[pn].ApiKey ~= "" and SL[pn].Streams.Hash ~= "" then
					query["chartHashP"..n] = SL[pn].Streams.Hash
					headers["x-api-key-player-"..n] = SL[pn].ApiKey
					sendRequest = true
				end
			end

			if sendRequest then
				self:playcommand("MakeGrooveStatsRequest", {
					endpoint="?action=playerLeaderboards&"..NETWORK:EncodeQueryParameters(query),
					method="GET",
					headers=headers,
					timeout=10,
					callback=LeaderboardRequestProcessor,
				})
			end
		end
	}
}
