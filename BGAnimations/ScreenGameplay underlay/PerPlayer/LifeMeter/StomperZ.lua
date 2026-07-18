local player = ...
local p = ToEnumShortString(player)
local x = GetNotefieldX( player )
local under, over, full

-- These panels fade out toward the notefield using faderight()/fadeleft(), which
-- ramps *alpha* to transparent.  They must not use diffuse*edge(0,0,0,1) for this:
-- that ramps toward opaque black, which paints over the background rather than
-- blending into it -- visible as a black band against the StomperZ gameplay
-- background.  This matches the preview in ScreenSelectPlayMode underlay/default.lua.
--
-- The consequence is that the three layers are translucent, so any two that overlap
-- will blend into a false colour rather than the upper one simply hiding the lower.
-- Both overlaps are therefore prevented explicitly:
--   * green is cropped away wherever blue covers it (see LifeChangedMessageCommand)
--   * green and blue are concealed entirely while purple is showing (Hot)
local colors = {
	under = color("#00c263"),	-- green, below the halfway mark
	over  = color("#0073ff"),	-- blue, above the halfway mark
	full  = color("#6517e0"),	-- purple, shown while HealthState_Hot
}

-- left and right panels are mirror images of each other; the only differences are
-- which screen edge they hang off and which way they fade
local PanelInit = function(side, c)
	return function(self)
		self:vertalign(top)
			:horizalign(side)
			:xy( GetNotefieldWidth()/2 * (side==left and -1 or 1), 40 )
			:zoomto( 50, _screen.h-40 )
			:diffuse( c )

		if side == left then self:faderight(1) else self:fadeleft(1) end
	end
end

local ChangeSize = function(self, params)
	self:finishtweening():decelerate(0.2)
		:croptop(params.CropTop):cropbottom(params.CropBottom)
end

local af = Def.ActorFrame{
	Name="LifeMeter_"..p,
	InitCommand=function(self)
		self:xy(x,0)
	end,
	HealthStateChangedMessageCommand=function(self,params)
		if(params.PlayerNumber == player) then
			if(params.HealthState == 'HealthState_Hot') then
				full:queuecommand("Hot")
				-- fade these out over the same duration purple fades in
				under:playcommand("Conceal")
				over:playcommand("Conceal")
			elseif params.HealthState == "HealthState_Dead" then
				full:queuecommand("Dead")
				under:playcommand("Reveal")
				over:playcommand("Reveal")
			else
				full:queuecommand("NotHot")
				under:playcommand("Reveal")
				over:playcommand("Reveal")
			end
		end
	end,
	LifeChangedMessageCommand=function(self,params)
		if(params.Player == player) then
			local life = params.LifeMeter:GetLife()

			-- croptop() reveals each panel from the bottom up
			local over_top, under_top
			if life >= 0.5 then
				over_top  = scale(life, 0.5,1,  1,0)
				under_top = 0
			else
				over_top  = 1
				under_top = scale(life, 0,0.5,  1,0)
			end

			over:playcommand("ChangeSize",  {CropTop=over_top, CropBottom=0})
			-- blue occupies the bottom (1 - over_top) of the panel, so crop that much
			-- off the bottom of green; the two then tile rather than overlap
			under:playcommand("ChangeSize", {CropTop=under_top, CropBottom=1-over_top})
		end
	end,


	Def.ActorFrame{
		Name="Under",
		InitCommand=function(self)
			under = self
			-- StomperZ starts at full life, and therefore Hot, so the purple panel is
			-- what shows first; HealthStateChangedMessage only fires on a *change*.
			self:diffusealpha(0)
		end,
		ConcealCommand=function(self) self:stoptweening():decelerate(1):diffusealpha(0) end,
		RevealCommand=function(self) self:stoptweening():diffusealpha(1) end,

		Def.Quad{ Name="Left",  InitCommand=PanelInit(left,  colors.under), ChangeSizeCommand=ChangeSize },
		Def.Quad{ Name="Right", InitCommand=PanelInit(right, colors.under), ChangeSizeCommand=ChangeSize },
	},

	Def.ActorFrame{
		Name="Over",
		InitCommand=function(self)
			over = self
			self:diffusealpha(0)
		end,
		ConcealCommand=function(self) self:stoptweening():decelerate(1):diffusealpha(0) end,
		RevealCommand=function(self) self:stoptweening():diffusealpha(1) end,

		Def.Quad{ Name="Left",  InitCommand=PanelInit(left,  colors.over), ChangeSizeCommand=ChangeSize },
		Def.Quad{ Name="Right", InitCommand=PanelInit(right, colors.over), ChangeSizeCommand=ChangeSize },
	},

	Def.ActorFrame{
		Name="Full",
		InitCommand=function(self) full = self end,

		Def.Quad{
			Name="Left",
			InitCommand=PanelInit(left, colors.full),
			HotCommand=function(self)
				self:stoptweening():decelerate(1):diffusealpha(1)
			end,
			NotHotCommand=function(self)
				-- also restores purple in case DeadCommand left this red;
				-- safe to recolour here because alpha is going to 0 anyway
				self:stoptweening():diffuse( colors.full ):diffusealpha(0)
			end,
			DeadCommand=function(self)
				self:stoptweening():diffuse(1,0,0,0)
					:accelerate(0.2):diffusealpha(1):decelerate(0.4):diffusealpha(0)
			end
		},
		Def.Quad{
			Name="Right",
			InitCommand=PanelInit(right, colors.full),
			HotCommand=function(self)
				self:stoptweening():decelerate(1):diffusealpha(1)
			end,
			NotHotCommand=function(self)
				-- also restores purple in case DeadCommand left this red;
				-- safe to recolour here because alpha is going to 0 anyway
				self:stoptweening():diffuse( colors.full ):diffusealpha(0)
			end,
			DeadCommand=function(self)
				self:stoptweening():diffuse(1,0,0,0)
					:accelerate(0.2):diffusealpha(1):decelerate(0.4):diffusealpha(0)
			end
		}
	},

}

return af
