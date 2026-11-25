extends SceneTree
## Generates the UI art (icons, logo, RTS-style console, frames, boss plate, relic beam,
## boss-arena art). Separate from gen_art.gd. UI art is saved at 2x for the 1280x720 UI.
## Run:  tools/run_tool.sh res://tools/gen_ui.gd 300

const Painter := preload("res://tools/art/painter.gd")
const UIArt := preload("res://tools/art/ui_art.gd")
const Hud := preload("res://tools/ui/hud_art.gd")
const W3 := preload("res://tools/ui/wc3_art.gd")

var sheet: Array = []


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	print("gen_ui start")
	_save(UIArt.logo("DREADHOLD"), "res://assets/ui/logo.png")
	for n in ["cleave", "spin", "charge", "fireball", "frostnova", "blink", "shot", "volley", "dash", "potion",
			"damage", "health", "speed", "cooldown", "regen", "lifesteal", "crit", "armor", "resource", "gold", "area", "skull", "torch"]:
		_save(UIArt.icon(n), "res://assets/ui/icons/%s.png" % n)
	_save(UIArt.app_icon(), "res://assets/ui/icon.png")
	for c in ["warrior", "mage", "hunter"]:
		_save(W3.x2(W3.console(c)), "res://assets/ui/hud/console_%s.png" % c)
		_save(W3.x2(W3.topbar(c)), "res://assets/ui/hud/topbar_%s.png" % c)
		_save(W3.x2(W3.slot(c)), "res://assets/ui/wc3/slot_%s.png" % c)
		_save(W3.x2(Hud.crosshair(c)), "res://assets/ui/hud/cross_%s.png" % c)
	_save(W3.x2(W3.boss_plate()), "res://assets/ui/hud/boss_plate.png")
	_save(W3.x2(W3.gem_frames()), "res://assets/ui/hud/gems.png")
	_save(W3.x2(W3.moon()), "res://assets/ui/hud/moon.png")
	_save(W3.x2(W3.sun()), "res://assets/ui/hud/sun.png")
	_save(Hud.vignette(true), "res://assets/ui/hud/vignette_blood.png")
	_save(Hud.vignette(false), "res://assets/ui/hud/vignette_dark.png")
	_save(W3.x2(W3.frame()), "res://assets/ui/wc3/frame.png")
	_save(W3.x2(W3.tooltip()), "res://assets/ui/wc3/tooltip.png")
	for i in 4:
		_save(W3.x2(W3.button(i)), "res://assets/ui/wc3/button_%s.png" % ["normal", "hover", "pressed", "disabled"][i])
	_save(W3.x2(W3.tab(false)), "res://assets/ui/wc3/tab.png")
	_save(W3.x2(W3.tab(true)), "res://assets/ui/wc3/tab_on.png")
	_save(W3.x2(W3.bar_frame()), "res://assets/ui/wc3/bar_frame.png")
	var bars := {"hp": Color(0.15, 0.75, 0.15), "hp_low": Color(0.8, 0.12, 0.08), "rage": Color(0.85, 0.3, 0.05), "mana": Color(0.15, 0.4, 0.95),
		"focus": Color(0.8, 0.72, 0.15), "ghost": Color(0.95, 0.9, 0.7), "soul": Color(0.25, 0.9, 0.4), "night": Color(0.55, 0.45, 0.85)}
	for b in bars:
		_save(W3.x2(W3.bar_fill(bars[b])), "res://assets/ui/wc3/bar_%s.png" % b)
	_save(W3.x2(W3.grabber()), "res://assets/ui/wc3/grabber.png")
	_save(W3.x2(W3.check(true)), "res://assets/ui/wc3/check_on.png")
	_save(W3.x2(W3.check(false)), "res://assets/ui/wc3/check_off.png")
	_save(W3.x2(W3.cursor(false)), "res://assets/ui/cursor.png")
	_save(W3.x2(W3.cursor(true)), "res://assets/ui/cursor_hover.png")
	_save(W3.beam(), "res://assets/sprites/fx/beam.png")
	_save(W3.magic_circle(), "res://assets/sprites/fx/magic_circle.png")
	var sky := W3.sky_void()
	Painter.save_image(sky, "res://assets/textures/sky_void.png")
	Painter.save_image(W3.sky_variant(1101, Color(0.03, 0.035, 0.01), Color(0.55, 0.65, 0.15), Color(0.3, 0.35, 0.08), Color(0.12, 0.14, 0.04), 0.0005), "res://assets/textures/sky_rot.png")
	Painter.save_image(W3.sky_variant(1102, Color(0.06, 0.005, 0.005), Color(0.9, 0.3, 0.05), Color(0.45, 0.04, 0.04), Color(0.3, 0.06, 0.02), 0.0), "res://assets/textures/sky_hell.png")
	Painter.save_image(W3.sky_variant(1103, Color(0.03, 0.05, 0.1), Color(0.4, 0.75, 0.95), Color(0.55, 0.45, 0.9), Color(0.25, 0.32, 0.42), 0.0025), "res://assets/textures/sky_frost.png")
	_contact_sheet()
	print("gen_ui done in %d ms" % (Time.get_ticks_msec() - t0))
	quit()


func _save(img: Image, path: String) -> void:
	Painter.save_image(img, path)
	sheet.append(img)


func _contact_sheet() -> void:
	var x := 4
	var y := 4
	var row_h := 0
	var places: Array = []
	for im: Image in sheet:
		var w := im.get_width()
		var h := im.get_height()
		if x + w > 1600 and x > 4:
			x = 4
			y += row_h + 6
			row_h = 0
		places.append(Vector2i(x, y))
		x += w + 6
		row_h = maxi(row_h, h)
	var out := Image.create(1610, y + row_h + 4, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.2, 0.2, 0.24))
	for i in sheet.size():
		var im: Image = sheet[i]
		out.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), places[i])
	Painter.save_image(out, "res://tools/preview/ui_console.png")
