local player = ...
local p = ToEnumShortString(player)
local x = GetNotefieldX( player )
local under, over, full

-- The top of the panels is aligned with "Surround" so that the notefield's target
-- positions and the density graph both have the same room to breathe.
local top_y = 80

-- These panels fade out toward the notefield using faderight()/fadeleft(), which
-- ramps *alpha* to transparent.  They must not use diffuse*edge(0,0,0,1) for this:
-- that ramps toward opaque black, which paints over the background rather than
-- blending into it -- visible as a black band against the gameplay background.
--
-- The consequence is that the three layers are translucent, so any two that overlap
-- will blend into a false colour rather than the upper one simply hiding the lower.
-- Both overlaps are therefore prevented explicitly:
--   * green is cropped away wherever blue covers it (see SetLife)
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
			:xy( GetNotefieldWidth()/2 * (side==left and -1 or 1), top_y )
			:zoomto( 50, _screen.h-top_y )
			:diffuse( c )

		if side == left then self:faderight(1) else self:fadeleft(1) end
	end
end

local ChangeSize = function(self, params)
	self:finishtweening():decelerate(0.2)
		:croptop(params.CropTop):cropbottom(params.CropBottom)
end

-- croptop() reveals each panel from the bottom up
local SetLife = function(life)
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

local SetHealthState = function(state)
	if state == "HealthState_Hot" then
		full:playcommand("Hot")
		-- fade these out over the same duration purple fades in
		under:playcommand("Conceal")
		over:playcommand("Conceal")
	elseif state == "HealthState_Dead" then
		full:playcommand("Dead")
		under:playcommand("Reveal")
		over:playcommand("Reveal")
	else
		full:playcommand("NotHot")
		under:playcommand("Reveal")
		over:playcommand("Reveal")
	end
end

local af = Def.ActorFrame{
	Name="LifeMeter_"..p,
	InitCommand=function(self)
		self:xy(x,0)
	end,
	-- Neither LifeChangedMessage nor HealthStateChangedMessage fires until something
	-- actually changes, so the starting state has to be seeded here.  Which layer is
	-- visible at the start depends on the Life Difficulty: StomperZ begins at full
	-- life (Hot, so purple shows) while ITG begins at half (green and blue show).
	OnCommand=function(self)
		SetLife( THEME:GetMetric("LifeMeterBar", "InitialValue") )
		SetHealthState( GAMESTATE:GetPlayerState(player):GetHealthState() )
	end,
	HealthStateChangedMessageCommand=function(self,params)
		if(params.PlayerNumber == player) then
			SetHealthState(params.HealthState)
		end
	end,
	LifeChangedMessageCommand=function(self,params)
		if(params.Player == player) then
			SetLife( params.LifeMeter:GetLife() )
		end
	end,


	Def.ActorFrame{
		Name="Under",
		InitCommand=function(self)
			under = self
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
