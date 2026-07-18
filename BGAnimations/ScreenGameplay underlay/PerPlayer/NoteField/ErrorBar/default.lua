local player, layout = ...
local pn = ToEnumShortString(player)
local mods = SL[pn].ActiveModifiers

-- don't allow error bar to appear in Casual gamemode via profile settings
--
-- StomperZ is excluded too: the error bar colours and trims its ticks against
-- ITG timing windows, which would be actively misleading next to StomperZ's much
-- tighter ones (12.5ms W1 vs ITG's 21.5ms).  The ErrorBar option rows are hidden
-- in StomperZ, but check here as well so a player profile can't smuggle it in.
if SL.Global.GameMode == "Casual" or SL.Global.GameMode == "StomperZ" then
    return
end

-- if mods.ErrorBar == "None" then
--     return
-- end

local af = Def.ActorFrame{
    Name="ErrorBarContainer"..pn
  }

local ErrorBarTypes = { "Colorful", "Monochrome", "Text", "Highlight", "Average" }

for i, barname in ipairs(ErrorBarTypes) do
    if mods[barname] then 
        af[#af+1] = LoadActor(barname .. ".lua", player, layout)
    end
end

return af
