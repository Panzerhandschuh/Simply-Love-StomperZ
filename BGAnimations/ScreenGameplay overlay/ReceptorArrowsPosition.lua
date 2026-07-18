-- ReceptorArrow positions are hardcoded using Metrics.ini in Casual and ITG modes.
-- If we're in one of those modes, bail now.
if SL.Global.GameMode ~= "StomperZ" then return end

local player = ...

-- these numbers are relative to the ReceptorArrowsYStandard and ReceptorArrowsYReverse
-- positions already specified in Metrics, which StomperZ sets higher than ITG does
local ReceptorPositions = {
	Standard = {
		ITG = 45,
		StomperZ = 0
	},
	Reverse = {
		ITG = -30,
		StomperZ = 0
	}
}

return Def.Actor{
	DoneLoadingNextSongMessageCommand=function(self) self:queuecommand("Position") end,
	PositionCommand=function(self)

		local playeroptions = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
		local p = ToEnumShortString(player)

		local scroll = playeroptions:UsingReverse() and "Reverse" or "Standard"
		local position = SL[p].ActiveModifiers.ReceptorArrowsPosition

		-- The player's ActorFrame ("PlayerP1" or "PlayerP2") contains multiple important
		-- things like NoteField, Judgment, HoldJudgment, etc.  Shift the entire
		-- ActorFrame up/down, rather than trying to position its children individually.
		local playerAF = GetPlayerAF(p)
		if playerAF then
			playerAF:addy( ReceptorPositions[scroll][position] )
		end
	end
}
