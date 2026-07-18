return Def.Quad{
	Name="Header",
	InitCommand=function(self)
		self:diffuse(0,0,0,0.85):valign(0):xy( _screen.cx, 0 )
		self:zoomtowidth(_screen.w)

		-- StomperZ raises the receptors, so the header is halved to stay clear of them
		self:zoomtoheight(SL.Global.GameMode == "StomperZ" and 40 or 80)
	end
}