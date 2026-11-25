extends RefCounted
## Helpers for pixel-art Sprite3D billboards.

static func make(tex: Texture2D, frames: int, world_h: float, billboard: bool = true, shaded: bool = true) -> Sprite3D:
	## Sprite whose full frame is world_h metres tall. The sprite is centred, so the caller
	## should place it at y = world_h / 2 above the feet (see `feet_y`).
	var s := Sprite3D.new()
	s.texture = tex
	s.hframes = maxi(frames, 1)
	s.pixel_size = world_h / float(tex.get_height())
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = shaded
	s.double_sided = true
	s.position.y = world_h * 0.5
	return s


static func frame_count(tex: Texture2D) -> int:
	return maxi(1, int(round(float(tex.get_width()) / float(tex.get_height()))))
