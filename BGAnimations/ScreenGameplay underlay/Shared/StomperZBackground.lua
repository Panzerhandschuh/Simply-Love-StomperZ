-- StomperZ replaces the song's background during gameplay with a flat dark field
-- and a triangle lattice, matching how the mode presents itself on
-- ScreenSelectPlayMode and ScreenEvaluation.
if SL.Global.GameMode ~= "StomperZ" then return end

-- Triangles1080.png is white line-art on transparency at full opacity, so the
-- brightness of the lattice is set here rather than baked into the asset.
--
-- 0.15 was picked to match the *perceived* faintness of the older, lower-resolution
-- Graphics/Triangles.png.  Note that matching by ink density alone would suggest ~0.27:
-- the two have near-identical mean alpha at that value.  But the old asset was blurry,
-- peaking at only 57/255 once downscaled, while this one has sharp 255 cores, so equal
-- average ink still reads as noticeably brighter.  Raise this for a bolder lattice.
local lattice_alpha = 0.15

-- The Quad is what actually hides the song background -- the lattice is line-art on
-- transparency and cannot cover anything on its own.
--
-- Triangles1080.png is exactly 16:9, as is the theme's virtual screen, so zoomto()
-- fills it without distortion.  StomperZ is widescreen-only by design; 4:3 would
-- stretch this and is deliberately not handled.
return Def.ActorFrame{
	Name="StomperZBackground",

	Def.Quad{
		InitCommand=function(self)
			self:Center():zoomto(_screen.w, _screen.h):diffuse(Color.Black)
		end
	},

	LoadActor( THEME:GetPathG("", "Triangles1080.png") )..{
		InitCommand=function(self)
			self:Center():zoomto(_screen.w, _screen.h):diffusealpha(lattice_alpha)
		end
	},
}
