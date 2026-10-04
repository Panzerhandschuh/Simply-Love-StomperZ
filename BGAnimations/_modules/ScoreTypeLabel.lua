-- A small boxed "ITG" or "EX" label for the top left corner of a leaderboard pane.
--
-- args.EX is whether the leaderboard shows EX scores.
-- args.Text optionally replaces the "ITG"/"EX" text (e.g. "Machine" for local HighScores).
-- Play "Set" with {EX=bool} to change it later (e.g. once GrooveStats responds).

local args = ...

local minBoxWidth = 22
local boxHeight = 16
local borderWidth = 1
local padding = 4

local SetType = function(text, ex)
	text:settext(args.Text or (ex and "EX" or "ITG"))
	text:diffuse(ex and SL.JudgmentColors["ITG"][1] or Color.White)
end

-- Grows the box to fit the text, keeping its left edge in place.
local Resize = function(af)
	local text = af:GetChild("Text")
	local boxWidth = math.max(minBoxWidth, text:GetZoomedWidth() + padding)
	af:GetChild("Border"):zoomto(boxWidth + borderWidth*2, boxHeight + borderWidth*2)
	af:GetChild("Background"):zoomto(boxWidth, boxHeight)
	text:x(boxWidth/2)
end

return Def.ActorFrame{
	Name="ScoreTypeLabel",
	InitCommand=function(self)
		-- left edge of the box, just left of and above the first row's rank, in the pane's top left corner
		self:xy(-176 - minBoxWidth/2, 16)
	end,
	-- after the children's InitCommands have set the text
	OnCommand=function(self)
		Resize(self)
	end,
	SetCommand=function(self, params)
		SetType(self:GetChild("Text"), params.EX)
		Resize(self)
	end,

	-- Border, styled like the personal best box
	Def.Quad{
		Name="Border",
		InitCommand=function(self)
			self:horizalign(left):x(-borderWidth)
			self:diffuse(Color.White):diffusealpha(0.1)
		end
	},

	-- Background
	Def.Quad{
		Name="Background",
		InitCommand=function(self)
			self:horizalign(left)
			self:diffuse(Color.Black):diffusealpha(0.85)
		end
	},

	LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
		Name="Text",
		InitCommand=function(self)
			self:zoom(0.5)
			SetType(self, args.EX)
		end
	}
}
