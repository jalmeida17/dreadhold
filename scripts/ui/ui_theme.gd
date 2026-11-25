extends RefCounted
## UI theme and small widget helpers. UI runs at 1280x720; pixel-art UI textures are
## authored at 2x already. Font: Pixelify Sans (SIL OFL), bold weight for titles.

const FONT_PIXEL := "res://assets/fonts/ofl/PixelifySans.ttf"

const GOLD := Color(1.0, 0.82, 0.3)
const GOLD_DARK := Color(0.7, 0.52, 0.18)
const CREAM := Color(0.93, 0.9, 0.84)
const GREY := Color(0.62, 0.6, 0.56)
const GREEN := Color(0.35, 0.95, 0.35)
const RED := Color(0.95, 0.25, 0.2)
const BLUE := Color(0.45, 0.65, 1.0)

static var title_font: Font
static var body_font: Font


static func build_fonts() -> void:
	## Pixelify Sans (SIL OFL): a readable pixel font; bold weight for titles.
	var base: FontFile = load(FONT_PIXEL)
	base.hinting = TextServer.HINTING_NONE
	var ts := TextServerManager.get_primary_interface()
	var tv := FontVariation.new()
	tv.base_font = base
	tv.variation_opentype = {ts.name_to_tag("wght"): 700}
	# the fi/fl ligatures of this font read badly in game text: keep plain letters
	var no_liga := {ts.name_to_tag("liga"): 0, ts.name_to_tag("clig"): 0, ts.name_to_tag("dlig"): 0}
	tv.opentype_features = no_liga
	title_font = tv
	var bv := FontVariation.new()
	bv.base_font = base
	bv.variation_opentype = {ts.name_to_tag("wght"): 450}
	bv.opentype_features = no_liga
	body_font = bv


static func _sb(path: String, margin: int, content_h: int = -1, content_v: int = -1) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sb.set_texture_margin(side, margin)
	var ch := content_h if content_h >= 0 else margin
	var cv := content_v if content_v >= 0 else margin
	sb.content_margin_left = ch
	sb.content_margin_right = ch
	sb.content_margin_top = cv
	sb.content_margin_bottom = cv
	return sb


static func build_theme() -> Theme:
	if body_font == null:
		build_fonts()
	var t := Theme.new()
	t.default_font = body_font
	t.default_font_size = 18
	for cls in ["Label", "RichTextLabel"]:
		t.set_color("font_color", cls, CREAM)
		t.set_color("font_shadow_color", cls, Color(0, 0, 0, 0.85))
		t.set_constant("shadow_offset_x", cls, 2)
		t.set_constant("shadow_offset_y", cls, 2)
	t.set_color("default_color", "RichTextLabel", CREAM)
	t.set_font("normal_font", "RichTextLabel", body_font)
	t.set_font("bold_font", "RichTextLabel", title_font)

	t.set_stylebox("normal", "Button", _sb("res://assets/ui/wc3/button_normal.png", 10, 18, 8))
	t.set_stylebox("hover", "Button", _sb("res://assets/ui/wc3/button_hover.png", 10, 18, 8))
	t.set_stylebox("pressed", "Button", _sb("res://assets/ui/wc3/button_pressed.png", 10, 18, 8))
	t.set_stylebox("disabled", "Button", _sb("res://assets/ui/wc3/button_disabled.png", 10, 18, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", title_font)
	t.set_font_size("font_size", "Button", 20)
	t.set_color("font_color", "Button", GOLD)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.95, 0.7))
	t.set_color("font_pressed_color", "Button", GOLD_DARK)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", GREY)
	t.set_color("font_outline_color", "Button", Color(0, 0, 0))
	t.set_constant("outline_size", "Button", 4)

	var frame := _sb("res://assets/ui/wc3/frame.png", 28, 34, 30)
	t.set_stylebox("panel", "Panel", frame)
	t.set_stylebox("panel", "PanelContainer", frame)
	var tip := _sb("res://assets/ui/wc3/tooltip.png", 8, 12, 10)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", CREAM)
	t.set_font("font", "TooltipLabel", body_font)
	t.set_font_size("font_size", "TooltipLabel", 16)

	var bar_bg := _sb("res://assets/ui/wc3/bar_frame.png", 4, 0, 0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", _sb("res://assets/ui/wc3/bar_hp.png", 4, 0, 0))

	var track := _sb("res://assets/ui/wc3/bar_frame.png", 4, 0, 0)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", _sb("res://assets/ui/wc3/bar_rage.png", 4, 0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", _sb("res://assets/ui/wc3/bar_rage.png", 4, 0, 0))
	t.set_icon("grabber", "HSlider", load("res://assets/ui/wc3/grabber.png"))
	t.set_icon("grabber_highlight", "HSlider", load("res://assets/ui/wc3/grabber.png"))

	t.set_icon("checked", "CheckBox", load("res://assets/ui/wc3/check_on.png"))
	t.set_icon("unchecked", "CheckBox", load("res://assets/ui/wc3/check_off.png"))
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		t.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckBox", CREAM)
	t.set_color("font_hover_color", "CheckBox", GOLD)
	t.set_color("font_pressed_color", "CheckBox", CREAM)
	return t


# ------------------------------------------------------------------ widget helpers

static func title(text: String, size: int = 32, color: Color = GOLD, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(size / 7, 3))
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func label(text: String, size: int = 18, color: Color = CREAM, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func pix(tex: Texture2D, scale: float = 1.0) -> TextureRect:
	## Pixel-art image at an integer scale with nearest filtering.
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = tex.get_size() * scale
	r.size = tex.get_size() * scale
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func frame_tex(tex: Texture2D, frame: int, frames: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	var fw := tex.get_width() / frames
	a.region = Rect2(frame * fw, 0, fw, tex.get_height())
	return a


static func bar_style(name: String) -> StyleBoxTexture:
	return _sb("res://assets/ui/wc3/bar_%s.png" % name, 4, 0, 0)


static func bar(size: Vector2, fill: String) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = size
	b.size = size
	b.show_percentage = false
	b.max_value = 100.0
	b.add_theme_stylebox_override("fill", bar_style(fill))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func roman(n: int) -> String:
	var vals := [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var syms := ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	var out := ""
	var v := maxi(n, 1)
	for i in vals.size():
		while v >= vals[i]:
			out += syms[i]
			v -= vals[i]
	return out
