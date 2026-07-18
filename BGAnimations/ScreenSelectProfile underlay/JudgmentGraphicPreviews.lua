local args = ...
local af = args.af

local already_loaded = {}

for profile in ivalues(args.profile_data) do
	if profile.judgment ~= nil and profile.judgment ~= "" then
		local name = StripSpriteHints(profile.judgment)
		if not FindInTable(name, already_loaded) then
			-- This screen runs before a GameMode is necessarily settled, and a profile
			-- may have last used either a common judgment graphic or a StomperZ one,
			-- so check both directories rather than assuming the current GameMode.
			-- THEME:GetCurrentThemeDirectory() already has a trailing slash.
			local path
			for dir in ivalues({ "_judgments", "_judgments/StomperZ" }) do
				local candidate = ("/%sGraphics/%s/%s"):format(THEME:GetCurrentThemeDirectory(), dir, profile.judgment)
				if FILEMAN:DoesFileExist(candidate) then
					path = candidate
					break
				end
			end

			if path then

				af[#af+1] = Def.Sprite{
					Name="JudgmentGraphic_"..name,
					Texture=path,
					InitCommand=function(self)
						self:y(-50):animate(false)
					end
				}

				table.insert(already_loaded, name)
				break
			end
		end
	end
end

af[#af+1] = Def.Actor{ Name="JudgmentGraphic_None", InitCommand=function(self) self:visible(false) end }
