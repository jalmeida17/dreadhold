extends CanvasLayer
## Grizzle's Black Market: the dawn shop. A clear list of wares (Abilities / Supplies) on
## the left, the selected ware's details with a big BUY button on the right.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Boons := preload("res://scripts/data/boons.gd")

const PRICES := {"common": 60, "rare": 110, "epic": 180, "legendary": 300}
const POTION_PRICE := 40
const MEND_PRICE := 30
const QUOTES := [
	"Psst... finest goods this side of the grave!",
	"No refunds. No questions. No witnesses.",
	"Gold first, friend. Always gold first.",
	"Fell off a cart, these did. A very haunted cart.",
	"The dead don't need it. You might!",
]

signal begin_night

var player: Node
var director: Node
var root: Control
var list_box: VBoxContainer
var gold_label: Label
var quote_label: Label
var d_icon: TextureRect
var d_name: Label
var d_tag: Label
var d_owned: Label
var d_desc: Label
var d_price: Label
var buy_btn: Button
var restock_btn: Button
var portrait: TextureRect
var _portrait_frames: Array = []
var stock: Array = []          # [{kind, id, price, sold}]
var selected := 0
var restock_cost := 20
var rng := RandomNumberGenerator.new()
var _laugh_t := 0.0


func setup(p_player: Node, p_director: Node) -> void:
	player = p_player
	director = p_director
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	root = Control.new()
	root.theme = Game.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var frame := PanelContainer.new()
	frame.position = Vector2(150, 40)
	frame.custom_minimum_size = Vector2(980, 640)
	root.add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	frame.add_child(v)
	v.add_child(_header())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 4)
	list_box.custom_minimum_size = Vector2(520, 0)
	body.add_child(list_box)
	body.add_child(_details())
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	v.add_child(btns)
	restock_btn = Button.new()
	restock_btn.custom_minimum_size = Vector2(240, 52)
	restock_btn.add_theme_font_size_override("font_size", 18)
	restock_btn.pressed.connect(_restock)
	btns.add_child(restock_btn)
	var close := Button.new()
	close.text = "CLOSE  [ESC]"
	close.custom_minimum_size = Vector2(200, 52)
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(close_shop)
	btns.add_child(close)
	var go := Button.new()
	go.text = "BEGIN THE NIGHT"
	go.custom_minimum_size = Vector2(290, 52)
	go.add_theme_font_size_override("font_size", 22)
	go.pressed.connect(_begin)
	btns.add_child(go)


func _header() -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ppath := "res://assets/ui/portrait_goblin.png"
	if ResourceLoader.exists(ppath):
		var pt: Texture2D = load(ppath)
		var fs := pt.get_height()
		var n := maxi(1, pt.get_width() / fs)
		for i in n:
			var a := AtlasTexture.new()
			a.atlas = pt
			a.region = Rect2(i * fs + (fs - 48) / 2, (fs - 48) / 2, 48, 48)
			_portrait_frames.append(a)
		portrait.texture = _portrait_frames[0]
	head.add_child(portrait)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(hv)
	hv.add_child(UiTheme.title("GRIZZLE'S BLACK MARKET", 32, UiTheme.GOLD))
	quote_label = UiTheme.label("", 18, Color(0.75, 0.85, 0.55))
	hv.add_child(quote_label)
	var gold_box := HBoxContainer.new()
	gold_box.add_theme_constant_override("separation", 8)
	gold_box.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(gold_box)
	gold_box.add_child(UiTheme.pix(load("res://assets/ui/icons/gold.png"), 1.5))
	gold_label = UiTheme.title("0", 30, UiTheme.GOLD)
	gold_box.add_child(gold_label)
	return head


func _details() -> Control:
	var panel := PanelContainer.new()
	var tip := StyleBoxTexture.new()
	tip.texture = load("res://assets/ui/wc3/tooltip.png")
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		tip.set_texture_margin(side, 8)
		tip.set_content_margin(side, 18)
	panel.add_theme_stylebox_override("panel", tip)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	v.add_child(top)
	d_icon = TextureRect.new()
	d_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	d_icon.stretch_mode = TextureRect.STRETCH_SCALE
	d_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	d_icon.custom_minimum_size = Vector2(72, 72)
	d_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(d_icon)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(tv)
	d_name = UiTheme.title("", 24, UiTheme.GOLD)
	d_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_name.custom_minimum_size = Vector2(260, 0)
	tv.add_child(d_name)
	d_tag = UiTheme.label("", 16, UiTheme.GREY)
	tv.add_child(d_tag)
	d_owned = UiTheme.label("", 16, Color(0.75, 0.85, 0.55))
	v.add_child(d_owned)
	d_desc = UiTheme.label("", 19, UiTheme.CREAM)
	d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_desc.custom_minimum_size = Vector2(340, 90)
	v.add_child(d_desc)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	d_price = UiTheme.title("", 26, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(d_price)
	buy_btn = Button.new()
	buy_btn.text = "BUY"
	buy_btn.custom_minimum_size = Vector2(0, 58)
	buy_btn.add_theme_font_size_override("font_size", 26)
	buy_btn.pressed.connect(func(): _buy(selected))
	v.add_child(buy_btn)
	return panel


# ======================================================================= stock

func new_stock() -> void:
	## Called at each dawn: 6 random abilities/upgrades + a potion + mending.
	restock_cost = 20
	_roll()


func _roll() -> void:
	stock.clear()
	for id in Boons.roll(player.class_id, player.boons, 6, rng):
		stock.append({"kind": "boon", "id": id, "price": int(PRICES[Boons.BOONS[id].rarity]), "sold": false})
	stock.append({"kind": "potion", "id": "potion", "price": POTION_PRICE, "sold": false})
	stock.append({"kind": "mend", "id": "mend", "price": MEND_PRICE, "sold": false})
	selected = 0


func open_shop() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	quote_label.text = QUOTES[rng.randi_range(0, QUOTES.size() - 1)]
	root.visible = true
	_refresh()
	Sfx.play("coin_pickup", -4.0)


func close_shop() -> void:
	root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.play("ui_click")


func is_open() -> bool:
	return root.visible


func _unhandled_input(event: InputEvent) -> void:
	if root.visible and event.is_action_pressed("pause"):
		close_shop()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_laugh_t = maxf(_laugh_t - delta, 0.0)
	if _portrait_frames.size() > 1:
		portrait.texture = _portrait_frames[1 if _laugh_t > 0.0 else 0]


# ======================================================================= helpers

func _ware_name(w: Dictionary) -> String:
	match w.kind:
		"potion":
			return "Health Potion"
		"mend":
			return "Mend Wounds"
	return str(Boons.BOONS[w.id].name)


func _ware_icon(w: Dictionary) -> Texture2D:
	match w.kind:
		"potion":
			return load("res://assets/ui/icons/potion.png")
		"mend":
			return load("res://assets/ui/icons/health.png")
	return load("res://assets/ui/icons/%s.png" % Boons.BOONS[w.id].icon)


func _ware_color(w: Dictionary) -> Color:
	if w.kind == "boon":
		return Boons.RARITY_COLOR[Boons.BOONS[w.id].rarity]
	return UiTheme.CREAM


func _ware_tag(w: Dictionary) -> String:
	match w.kind:
		"potion":
			return "Supply"
		"mend":
			return "Service"
	var b: Dictionary = Boons.BOONS[w.id]
	var t := str(b.rarity).capitalize()
	if b.has("class"):
		t += "  -  " + str(b["class"]).capitalize()
	return t


func _can_buy(w: Dictionary) -> bool:
	if w.sold or player.gold < int(w.price):
		return false
	match w.kind:
		"potion":
			return player.potions < player.max_potions
		"mend":
			return player.hp < player.max_hp
	return true


func _row_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


# ======================================================================= list & details

func _refresh() -> void:
	gold_label.text = str(player.gold)
	restock_btn.text = "RESTOCK  (%dg)" % restock_cost
	restock_btn.disabled = player.gold < restock_cost
	for c in list_box.get_children():
		c.queue_free()
	list_box.add_child(UiTheme.title("ABILITIES & UPGRADES", 16, UiTheme.GOLD))
	for i in stock.size():
		if i == stock.size() - 2:
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(0, 6)
			list_box.add_child(sp)
			list_box.add_child(UiTheme.title("SUPPLIES", 16, UiTheme.GOLD))
		list_box.add_child(_row(i))
	_show_details()


func _row(i: int) -> Button:
	var w: Dictionary = stock[i]
	var b := Button.new()
	b.custom_minimum_size = Vector2(520, 44)
	var sel := i == selected
	b.add_theme_stylebox_override("normal", _row_style(Color(0.1, 0.09, 0.09, 0.95) if not sel else Color(0.2, 0.17, 0.1, 0.95), UiTheme.GOLD if sel else Color(0.28, 0.26, 0.24)))
	b.add_theme_stylebox_override("hover", _row_style(Color(0.16, 0.14, 0.12, 0.95), UiTheme.GOLD_DARK if not sel else UiTheme.GOLD))
	b.add_theme_stylebox_override("pressed", _row_style(Color(0.22, 0.18, 0.1, 0.95), UiTheme.GOLD))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -12
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := UiTheme.pix(_ware_icon(w), 1.5)
	if w.sold:
		ic.modulate = Color(0.35, 0.35, 0.35)
	h.add_child(ic)
	var n := UiTheme.title(_ware_name(w), 18, _ware_color(w) if not w.sold else UiTheme.GREY)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(n)
	var tag := UiTheme.label(_ware_tag(w), 14, UiTheme.GREY)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tag)
	var ptxt := "SOLD" if w.sold else "%d g" % int(w.price)
	var pcol := UiTheme.GREY if w.sold else (UiTheme.GOLD if player.gold >= int(w.price) else UiTheme.RED)
	var p := UiTheme.title(ptxt, 18, pcol, HORIZONTAL_ALIGNMENT_RIGHT)
	p.custom_minimum_size = Vector2(70, 0)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(p)
	b.mouse_entered.connect(func(): Sfx.play("ui_hover", -10.0))
	b.pressed.connect(func():
		selected = i
		Sfx.play("ui_click", -6.0)
		_refresh())
	b.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.double_click:
			selected = i
			_buy(i))
	return b


func _show_details() -> void:
	if stock.is_empty():
		return
	var w: Dictionary = stock[clampi(selected, 0, stock.size() - 1)]
	d_icon.texture = _ware_icon(w)
	d_name.text = _ware_name(w)
	d_name.add_theme_color_override("font_color", _ware_color(w))
	d_tag.text = _ware_tag(w)
	match w.kind:
		"potion":
			d_owned.text = "You carry %d / %d potions" % [player.potions, player.max_potions]
			d_desc.text = "Restores half of your health over a moment. Drink it with [%s]." % Game.key_label(KEY_R)
		"mend":
			d_owned.text = "Health %d / %d" % [int(player.hp), int(player.max_hp)]
			d_desc.text = "Grizzle patches you up. Restores all of your health right now."
		_:
			var b: Dictionary = Boons.BOONS[w.id]
			d_owned.text = "Owned %d / %d" % [int(player.boons.get(w.id, 0)), int(b.max)]
			d_desc.text = str(b.desc)
	if w.sold:
		d_price.text = "SOLD"
		d_price.add_theme_color_override("font_color", UiTheme.GREY)
	else:
		d_price.text = "%d gold" % int(w.price)
		d_price.add_theme_color_override("font_color", UiTheme.GOLD if player.gold >= int(w.price) else UiTheme.RED)
	buy_btn.disabled = not _can_buy(w)
	buy_btn.text = "BUY" if not w.sold else "SOLD OUT"


func _buy(i: int) -> void:
	var w: Dictionary = stock[i]
	if not _can_buy(w):
		Sfx.play("ui_click", -6.0)
		return
	player.gold -= int(w.price)
	w.sold = true
	match w.kind:
		"potion":
			player.potions += 1
			w.sold = player.potions >= player.max_potions
		"mend":
			player.heal(player.max_hp)
		_:
			player.apply_boon(w.id)
	director.stat_add("gold_spent", float(w.price))
	Sfx.play("coin_pickup")
	Sfx.play("boon_select", -6.0)
	_laugh_t = 0.8
	_refresh()


func _restock() -> void:
	if player.gold < restock_cost:
		Sfx.play("ui_click", -6.0)
		return
	player.gold -= restock_cost
	restock_cost += 15
	_roll()
	Sfx.play("ui_confirm")
	_laugh_t = 0.6
	_refresh()


func _begin() -> void:
	close_shop()
	begin_night.emit()


func bot_shop() -> void:
	## Test autopilot: buy the first affordable ability then start the night.
	for i in stock.size():
		if stock[i].kind == "boon" and _can_buy(stock[i]):
			_buy(i)
			break
	_begin()
