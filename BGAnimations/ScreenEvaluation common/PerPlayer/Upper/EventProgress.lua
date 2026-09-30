-- File to handle Event specific (ITL/RPG) progress such as song scores, ranking points, quest completions, etc.

-- Unsure if it's possible to detect whether the chat module pane is active, so check that the file exists
local chatModule = FILEMAN:DoesFileExist(THEME:GetCurrentThemeDirectory() .. "Modules/TwitchChat.lua")

-- If there is no space for the ITL box, don't show it
if not IsUsingWideScreen() and (chatModule or #GAMESTATE:GetHumanPlayers() ~= 1) then return end

local player = ...
local pn = ToEnumShortString(player)

local CreateRPGBody = function(rpgData)
	local rpgStats = {
		tp = true,
		lp = true,
		bb = true,
		gold = true,
		jp = true
	}

	local score = rpgData["score"]
	local scoreDelta = rpgData["scoreDelta"]
	local rate = rpgData["rate"]
	local rateDelta = rpgData["rateDelta"]

	local qualifierImprovements = {}
	local statImprovements = {}
	if rpgData["statImprovements"] then
		for improvement in ivalues(rpgData["statImprovements"]) do
			if rpgStats[improvement.name] and improvement["gained"] > 0 then
				if #rpgData["statImprovements"] >= 5 and (improvement.name == "tp" or improvement.name == "lp") then
					table.insert(
						qualifierImprovements,
						string.format("+%d %s", improvement["gained"], string.upper(improvement["name"]))
					)
				else
					table.insert(
						statImprovements,
						string.format("+%d %s", improvement["gained"], string.upper(improvement["name"]))
					)
				end
			end
		end
	end

	local statsBody = string.format(
		"Score: %.2f%% (%+.2f%%)\n"..
		"Rate: %.2f (%+.2f)\n\n",
		score, scoreDelta, rate, rateDelta)

	if #qualifierImprovements == 1 then
			statsBody = statsBody .. qualifierImprovements[1] .. "\n"
	elseif #qualifierImprovements == 2 then
			statsBody = statsBody .. qualifierImprovements[1] .. " " .. qualifierImprovements[2] .. "\n"
	end
	for extraStats in ivalues(statImprovements) do
		statsBody = statsBody .. extraStats .. "\n"
	end

	return string.gsub(statsBody, "[\n\r]+$", "")
end

local CreateITLBody = function(itlData)
	local score = itlData["score"]
	local scoreDelta = itlData["scoreDelta"]
	local currentPoints = itlData["currentPoints"]
	local pointDelta = itlData["pointDelta"]
	local currentRankingPointTotal = itlData["currentRankingPointTotal"]
	local rankingDelta = itlData["rankingDelta"]
	local currentSongPointTotal = itlData["currentSongPointTotal"]
	local totalSongDelta = itlData["totalSongDelta"]
	local currentExPointTotal = itlData["currentExPointTotal"]
	local totalExDelta = itlData["totalExDelta"]
	local currentPointTotal = itlData["currentPointTotal"]
	local totalDelta = itlData["totalDelta"]

	return string.format(
		"EX Score: %.2f%% (%+.2f%%)\n"..
		"Points: %d (%+d)\n\n"..
		"Ranking Points: %d (%+d)\n"..
		"Song Points: %d (%+d)\n"..
		"EX Points: %d (%+d)\n"..
		"Total Points: %d (%+d)",
		score, scoreDelta, currentPoints, pointDelta,
		currentRankingPointTotal, rankingDelta,
		currentSongPointTotal, totalSongDelta,
		currentExPointTotal, totalExDelta,
		currentPointTotal, totalDelta
	)
end

local NewScoreTag = "(New)"

-- Scores are in hundredths of a percent so that deltas don't pick up floating point noise.
local CreatePBBody = function(pbData)
	local sections = {}

	-- EX first since it's what matters most for competitive play.
	for row in ivalues({ {"EX", pbData["ex"]}, {"ITG", pbData["itg"]} }) do
		local label, data = row[1], row[2]
		local section = string.format("%s: %.2f%%", label, data["score"]/100)

		if data["prevKnown"] and data["prev"] == nil then
			-- First score on GrooveStats for this chart, so there's nothing to compare against.
			section = section .. " " .. NewScoreTag
		elseif data["prevKnown"] then
			-- ScaleAndColorizeBody colors the delta by its sign: green for better, red for worse.
			-- A tie gets no sign so it stays the default color.
			local delta = data["score"] - data["prev"]
			local deltaFormat = delta == 0 and " (%.2f%%)" or " (%+.2f%%)"
			section = section .. string.format(deltaFormat, delta/100)
		end

		if data["rank"] then
			section = section .. string.format("\nRank: #%d", data["rank"])
		end
		sections[#sections+1] = section
	end

	return table.concat(sections, "\n\n")
end

-- Takes in an actor and both scales the text to fit within the box and
-- colorizes the text.
--
-- We colorize the following:
-- - Numbers (including decimals) in red if negative, green if positive.
-- - Quoted strings in green.
local ScaleAndColorizeBody = function(self, text, height, width, rowHeight, defaultColor)
	-- We don't want text to run out through the bottom.
	-- Incrementally adjust the zoom while adjust wrapwdithpixels until it fits.
	-- Not the prettiest solution but it works.
	for zoomVal=1.0, 0.1, -0.05 do
		self:zoom(zoomVal)
		self:wrapwidthpixels(width/(zoomVal))
		self:settext(text):visible(true)
		if self:GetHeight() * zoomVal <= height - rowHeight*1.5 then
			break
		end
	end

	local offset = 0
	while offset <= #text do
		-- Search for all numbers (decimals included).
		-- They may include the +/- prefixes and also potentially %/x as suffixes.
		local i, j = string.find(text, "[-+]?[%d]*%.?[%d]+[%%x]?", offset)
		-- No more numbers found. Break out.
		if i == nil then
			break
		end
		-- Extract the actual numeric text.
		local substring = string.sub(text, i, j)

		local clr = defaultColor

		-- Except negatives should be red.
		if substring:sub(1, 1) == "-" then
			clr = Color.Red
		-- And positives should be green.
		elseif substring:sub(1, 1) == "+" then
			clr = Color.Green
		end

		self:AddAttribute(i-1, {
			Length=#substring,
			Diffuse=clr
		})

		offset = j + 1
	end

	offset = 0

	while offset <= #text do
		-- Search for all quoted strings.
		local i, j = string.find(text, "\".-\"", offset)
		-- No more found. Break out.
		if i == nil then
			break
		end
		-- Extract the actual quoted text.
		local substring = string.sub(text, i, j)

		self:AddAttribute(i-1, {
			Length=#substring,
			Diffuse=Color.Green
		})

		offset = j + 1
	end
end

local ItlPink = color("1,0.2,0.406,1")
local RpgYellow = color("1,0.972,0.792,1")

-- Default position is on the other player's upper area where the grade should be
local posX = 381 * (player == PLAYER_1 and 1 or -1)
local posY = 109

local paneWidth = 156
local paneHeight = 144
local borderWidth = 2

local RowHeight = 25

local hasData = false

-- If that space is taken by a player or the twitch chat module,
-- put it to the side in widescreen mode.
if IsUsingWideScreen() and (chatModule or #GAMESTATE:GetHumanPlayers() > 1) then
	posX = 211 * (player == PLAYER_1 and -1 or 1)
	posY = 274
	paneWidth = 118
	paneHeight = 180
end

-- Random Event logo - 400x400px
-- TODO: SRPG Event logo dir
local EventLogoDir = THEME:GetCurrentThemeDirectory() .. "Graphics/ITL Online/"
logoFiles = findFiles(EventLogoDir,"png")
if #logoFiles > 0 then	
	logoImage = logoFiles[math.random(#logoFiles)]
end
local rpgLogoImage = THEME:GetPathG("", "_VisualStyles/SRPG10/logo_alt (doubleres).png")
local rpgDailyImages = {}

-- Ensure the header text fits within the box.
local FitHeader = function(header)
	for zoomVal=0.5, 0.1, -0.05 do
		header:zoom(zoomVal)
		header:wrapwidthpixels((paneWidth-6)/(zoomVal))
		if header:GetHeight() * zoomVal <= RowHeight*2 then
			break
		end
	end
end

local af = Def.ActorFrame{
	Name="EventProgress"..pn,

	InitCommand=function(self)
		self:xy(posX, posY)
		self:visible(false)
	end,

	SetDataCommand=function(self, params)
		if params.rpgData then
			hasData = true
			
			-- check for dailies (TODO)
			if params.rpgData["questsCompleted"] then
				for quest in ivalues(params.rpgData["questsCompleted"]) do
					if string.find(string.upper(quest["title"]), "UNAFFILIATED DAILY") then
						rpgDailyImages[#rpgDailyImages+1] = THEME:GetPathG("", "Stamina RPG/daily (doubleres).png")
					end
					
					if string.find(string.upper(quest["title"]), "SN DAILY") then
						rpgDailyImages[#rpgDailyImages+1] = THEME:GetPathG("", "Stamina RPG/daily_sn (doubleres).png")
					elseif string.find(string.upper(quest["title"]), "DPRT DAILY") then
						rpgDailyImages[#rpgDailyImages+1] = THEME:GetPathG("", "Stamina RPG/daily_dprt (doubleres).png")
					elseif string.find(string.upper(quest["title"]), "FE DAILY") then
						rpgDailyImages[#rpgDailyImages+1] = THEME:GetPathG("", "Stamina RPG/daily_fe (doubleres).png")
					elseif string.find(string.upper(quest["title"]), "NEP DAILY") then
						rpgDailyImages[#rpgDailyImages+1] = THEME:GetPathG("", "Stamina RPG/daily_nep (doubleres).png")
					end
				end
			end
			if #rpgDailyImages > 0 then
				self:queuecommand("DailyBadges")
			end
			
			local rpgString = CreateRPGBody(params.rpgData)
			ScaleAndColorizeBody(
				self:GetChild("BodyText"),
				rpgString,
				paneHeight - borderWidth,
				paneWidth - borderWidth,
				RowHeight,
				RpgYellow)

			self:GetChild("Header"):settext(params.rpgData["name"]:gsub("Stamina RPG", "SRPG"))
			FitHeader(self:GetChild("Header"))
			self:queuecommand("RPG")
		-- TODO: Add support for when a song is in both RPG and ITL
		elseif params.itlData and not hasData then
			hasData = true
			local itlString = CreateITLBody(params.itlData)
			
			ScaleAndColorizeBody(
				self:GetChild("BodyText"),
				itlString,
				paneHeight - borderWidth,
				paneWidth - borderWidth,
				RowHeight,
				ItlPink)

			self:GetChild("Header"):settext(params.itlData["name"]:gsub("ITL Online", "ITL"))
			FitHeader(self:GetChild("Header"))
		-- Fallback for charts that aren't part of an event: compare against GrooveStats personal bests.
		elseif params.pbData and not hasData then
			hasData = true
			local pbString = CreatePBBody(params.pbData)
			ScaleAndColorizeBody(
				self:GetChild("BodyText"),
				pbString,
				paneHeight - borderWidth,
				paneWidth - borderWidth,
				RowHeight,
				Color.White)

			-- New scores are improvements too, so color the tag like a positive delta.
			local offset = 1
			while true do
				local i, j = string.find(pbString, NewScoreTag, offset, true)
				if i == nil then break end
				self:GetChild("BodyText"):AddAttribute(i-1, {
					Length=#NewScoreTag,
					Diffuse=Color.Green
				})
				offset = j + 1
			end

			self:GetChild("Header"):settext("Personal Best")
			FitHeader(self:GetChild("Header"))
			self:queuecommand("PB")
			-- There's no event overlay to dismiss first, so show the box right away.
			self:visible(true)
		end
	end,

	MaybeShowCommand=function(self)
		self:visible(hasData)
	end,

	-- Draw border Quad
	Def.Quad {
		InitCommand=function(self)
			self:zoomto(paneWidth, paneHeight)
			self:diffuse(Color.White):diffusealpha(0.1)
		end
	},

	-- Draw background Quad
	Def.Quad {
		InitCommand=function(self)
			self:zoomto(paneWidth - borderWidth, paneHeight - borderWidth)
			self:diffuse(Color.Black):diffusealpha(0.85)
		end
	},

	-- Random event logo
	Def.Sprite {
		Texture=logoImage,
		Name="ITLLogo",
		InitCommand=function(self)
			self:zoom(0.2)
			self:diffusealpha(0.2)
		end,
		RPGCommand=function(self)
			self:visible(false)
		end,
		PBCommand=function(self)
			self:visible(false)
		end
	},

	-- GrooveStats logo for the personal best fallback
	Def.Sprite {
		Texture=THEME:GetPathG("", "GrooveStats.png"),
		Name="GSLogo",
		InitCommand=function(self)
			self:zoom(0.6)
			self:diffusealpha(0.2)
			self:visible(false)
		end,
		PBCommand=function(self)
			self:visible(true)
		end
	},
	
	-- RPG logo
	Def.Sprite {
		Name="RPGLogo",
		InitCommand=function(self)
			self:zoom(0.13)
			self:diffusealpha(0.25)
			self:visible(false)
		end,
		RPGCommand=function(self)
			self:Load(rpgLogoImage)
			self:visible(true)
		end
	},

	-- Header Text
	LoadFont("Wendy/_wendy small").. {
		Name="Header",
		Text="",
		InitCommand=function(self)
			self:zoom(0.5)
			self:y(-paneHeight/2 + 15)
		end
	},

	-- Main Body Text
	LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal").. {
		Name="BodyText",
		Text="",
		InitCommand=function(self)
			self:valign(0)
			self:wrapwidthpixels(paneWidth)
			self:y(-paneHeight/2 + RowHeight * 3/2)
		end,
	},
	
	-- RPG Daily Badges
	Def.Sprite {
		InitCommand=function(self)
			self:zoom(0.5)
			if chatModule then
				self:x(-40*(i-1)):y(-110)
			else
				self:x(pn == "P1" and 100 or -100):y(-55)
			end
		end,
		DailyBadgesCommand=function(self)
			if #rpgDailyImages >= 1 then
				self:Load(rpgDailyImages[1])
				self:visible(true)
			end
		end
	},
	
	Def.Sprite {
		InitCommand=function(self)
			self:zoom(0.5)
			if chatModule then
				self:x(-40+32*(i-1)):y(-110)
			else
				self:x(pn == "P1" and 100 or -100):y(-55+32)
			end
		end,
		DailyBadgesCommand=function(self)
			if #rpgDailyImages >= 2 then
				self:Load(rpgDailyImages[2])
				self:visible(true)
			end
		end
	},
}

return af
