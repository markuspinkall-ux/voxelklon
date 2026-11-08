extends CanvasLayer
## Benutzeroberfläche: HUD (Herzen, Luftblasen, Schnellleiste, Fadenkreuz),
## Inventar mit 2x2-Crafting, Werkbank (3x3), Truhe, Ofen, Rezeptbuch, Todesbildschirm.

const Items = preload("res://scripts/items.gd")
const Recipes = preload("res://scripts/recipes.gd")
const SlotScript = preload("res://scripts/slot.gd")

var player
var main
var mode := ""

var hud: Control
var hotbar: Array = []
var hearts: Array = []
var bubbles: Array = []
var tex_heart := {}
var tex_bubble: Texture2D
var break_bar: ProgressBar
var info: Label
var msg: Label
var msg_t := 0.0
var hurt_rect: ColorRect
var water_rect: ColorRect
var pause_label: Label
var death_panel: Control
var pause_panel: Control

var screen: Control
var title: Label
var craft_box: HBoxContainer
var craft_grid_ctrl: GridContainer
var craft_slots: Array = []
var craft_grid: Array = []
var craft_w := 2
var result_holder: Array = [null]
var chest_grid_ctrl: GridContainer
var chest_slots: Array = []
var chest_container: Array = []
var furnace_box: HBoxContainer
var f_slots: Array = []
var f_prog: ProgressBar
var f_burn: ProgressBar
var cur_furnace = null
var recipe_panel: PanelContainer
var cursor_stack = null
var cursor_icon: TextureRect
var cursor_count: Label
var hover_slot = null
var hover_label: Label

const DARK := Color(0.22, 0.22, 0.22)


func _ready() -> void:
	craft_grid.resize(9)
	craft_grid.fill(null)
	_make_textures()
	_build_hud()
	_build_screen()
	_build_death()
	_build_pause()
	process_mode = Node.PROCESS_MODE_ALWAYS


# ---------------------------------------------------------------------------
# Texturen für Herzen & Blasen
func _pattern_tex(rows: Array, colors: Dictionary, px_scale: int) -> ImageTexture:
	var h := rows.size()
	var w := String(rows[0]).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: String = rows[y]
		for x in w:
			var ch := row[x]
			if colors.has(ch):
				img.set_pixel(x, y, colors[ch])
	img.resize(w * px_scale, h * px_scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


func _make_textures() -> void:
	var full := [" XX XX ", "XRWXRRX", "XRRRRRX", " XRRRX ", "  XRX  ", "   X   "]
	var half := [" XX XX ", "XRWXDDX", "XRRRDDX", " XRRDX ", "  XRX  ", "   X   "]
	var empty := [" XX XX ", "XDDXDDX", "XDDDDDX", " XDDDX ", "  XDX  ", "   X   "]
	var cols := {"X": Color(0.12, 0.0, 0.0), "R": Color(0.88, 0.1, 0.1), "W": Color(1, 0.75, 0.75), "D": Color(0.28, 0.08, 0.08)}
	tex_heart["full"] = _pattern_tex(full, cols, 3)
	tex_heart["half"] = _pattern_tex(half, cols, 3)
	tex_heart["empty"] = _pattern_tex(empty, cols, 3)
	tex_bubble = _pattern_tex([" XXX ", "XWBBX", "XBBBX", "XBBBX", " XXX "],
		{"X": Color(0.1, 0.25, 0.6), "B": Color(0.45, 0.7, 1.0), "W": Color(1, 1, 1)}, 3)


func _label(text: String, size: int, color := Color(1, 1, 1), outline := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_constant_override("outline_size", 5)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _slot(container: Array, index: int, role: String, interactive := true):
	var s = SlotScript.new()
	s.container = container
	s.index = index
	s.role = role
	s.interactive = interactive
	if interactive:
		s.clicked.connect(_on_slot)
		s.hovered.connect(_on_hover)
	return s


# ---------------------------------------------------------------------------
# HUD
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	water_rect = ColorRect.new()
	water_rect.color = Color(0.08, 0.2, 0.6, 0.35)
	water_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	water_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water_rect.visible = false
	hud.add_child(water_rect)

	hurt_rect = ColorRect.new()
	hurt_rect.color = Color(1, 0, 0, 0)
	hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hurt_rect)

	var cross := Control.new()
	cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.draw.connect(func():
		var c := cross.size / 2.0
		cross.draw_rect(Rect2(c - Vector2(10, 1), Vector2(20, 2)), Color(1, 1, 1, 0.85))
		cross.draw_rect(Rect2(c - Vector2(1, 10), Vector2(2, 20)), Color(1, 1, 1, 0.85))
	)
	cross.resized.connect(cross.queue_redraw)
	hud.add_child(cross)

	break_bar = ProgressBar.new()
	break_bar.show_percentage = false
	break_bar.anchor_left = 0.5
	break_bar.anchor_right = 0.5
	break_bar.anchor_top = 0.5
	break_bar.anchor_bottom = 0.5
	break_bar.offset_left = -40
	break_bar.offset_right = 40
	break_bar.offset_top = 22
	break_bar.offset_bottom = 30
	break_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	break_bar.visible = false
	hud.add_child(break_bar)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -214
	bar.offset_right = 214
	bar.offset_top = -56
	bar.offset_bottom = -8
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bar)
	for i in 9:
		var s = _slot(player.inventory.slots, i, "inv", false)
		bar.add_child(s)
		hotbar.append(s)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 1)
	hb.anchor_left = 0.5
	hb.anchor_right = 0.5
	hb.anchor_top = 1.0
	hb.anchor_bottom = 1.0
	hb.offset_left = -214
	hb.offset_right = 0
	hb.offset_top = -82
	hb.offset_bottom = -60
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hb)
	for i in 10:
		var t := TextureRect.new()
		t.texture = tex_heart["full"]
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(t)
		hearts.append(t)

	var bb := HBoxContainer.new()
	bb.add_theme_constant_override("separation", 2)
	bb.alignment = BoxContainer.ALIGNMENT_END
	bb.anchor_left = 0.5
	bb.anchor_right = 0.5
	bb.anchor_top = 1.0
	bb.anchor_bottom = 1.0
	bb.offset_left = 0
	bb.offset_right = 214
	bb.offset_top = -80
	bb.offset_bottom = -60
	bb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bb)
	for i in 10:
		var t := TextureRect.new()
		t.texture = tex_bubble
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.visible = false
		bb.add_child(t)
		bubbles.append(t)

	info = _label("", 15)
	info.position = Vector2(10, 8)
	hud.add_child(info)

	var help := _label("WASD Laufen · Leertaste Springen/Schwimmen · Strg/Shift Sprinten · LMB Abbauen/Angreifen · RMB Platzieren/Benutzen · E Inventar · R Rezeptbuch · 1-9/Mausrad · Q Wegwerfen · Esc Pause · F11 Vollbild", 13, Color(1, 1, 1, 0.8))
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 10
	help.offset_top = -26
	hud.add_child(help)

	msg = _label("", 20, Color(1, 1, 0.75))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.anchor_left = 0.5
	msg.anchor_right = 0.5
	msg.anchor_top = 1.0
	msg.anchor_bottom = 1.0
	msg.offset_left = -400
	msg.offset_right = 400
	msg.offset_top = -125
	msg.offset_bottom = -95
	hud.add_child(msg)

	pause_label = _label("Pausiert – klicke ins Fenster, um weiterzuspielen", 26)
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.anchor_left = 0.5
	pause_label.anchor_right = 0.5
	pause_label.anchor_top = 0.35
	pause_label.anchor_bottom = 0.35
	pause_label.offset_left = -400
	pause_label.offset_right = 400
	pause_label.visible = false
	hud.add_child(pause_label)


# ---------------------------------------------------------------------------
# Inventar-Bildschirm
func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.78, 0.78, 0.78)
	sb.border_color = Color(0.25, 0.25, 0.25)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(14)
	return sb


func _build_screen() -> void:
	screen = Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.visible = false
	add_child(screen)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	row.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	title = _label("Inventar", 20, DARK, false)
	vb.add_child(title)

	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 150)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(top)

	# Crafting
	craft_box = HBoxContainer.new()
	craft_box.add_theme_constant_override("separation", 14)
	craft_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(craft_box)
	craft_grid_ctrl = GridContainer.new()
	craft_grid_ctrl.columns = 2
	craft_grid_ctrl.add_theme_constant_override("h_separation", 4)
	craft_grid_ctrl.add_theme_constant_override("v_separation", 4)
	craft_box.add_child(craft_grid_ctrl)
	for i in 9:
		var s = _slot(craft_grid, i, "craft")
		craft_grid_ctrl.add_child(s)
		craft_slots.append(s)
	var arrow := _label("=>", 28, DARK, false)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	craft_box.add_child(arrow)
	var res = _slot(result_holder, 0, "result")
	res.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	res.custom_minimum_size = Vector2(52, 52)
	craft_box.add_child(res)

	# Truhe
	chest_container.resize(27)
	chest_container.fill(null)
	chest_grid_ctrl = GridContainer.new()
	chest_grid_ctrl.columns = 9
	chest_grid_ctrl.add_theme_constant_override("h_separation", 4)
	chest_grid_ctrl.add_theme_constant_override("v_separation", 4)
	top.add_child(chest_grid_ctrl)
	for i in 27:
		var s = _slot(chest_container, i, "chest")
		chest_grid_ctrl.add_child(s)
		chest_slots.append(s)

	# Ofen
	furnace_box = HBoxContainer.new()
	furnace_box.add_theme_constant_override("separation", 16)
	furnace_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(furnace_box)
	var fcol := VBoxContainer.new()
	fcol.add_theme_constant_override("separation", 6)
	furnace_box.add_child(fcol)
	var dummy: Array = [null, null, null]
	var s_in = _slot(dummy, 0, "fin")
	fcol.add_child(s_in)
	f_burn = ProgressBar.new()
	f_burn.show_percentage = false
	f_burn.custom_minimum_size = Vector2(44, 10)
	fcol.add_child(f_burn)
	var s_fuel = _slot(dummy, 1, "ffuel")
	fcol.add_child(s_fuel)
	var mid := VBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	furnace_box.add_child(mid)
	mid.add_child(_label("Schmelzen", 14, DARK, false))
	f_prog = ProgressBar.new()
	f_prog.show_percentage = false
	f_prog.custom_minimum_size = Vector2(90, 14)
	mid.add_child(f_prog)
	var s_out = _slot(dummy, 2, "fout")
	s_out.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s_out.custom_minimum_size = Vector2(52, 52)
	furnace_box.add_child(s_out)
	f_slots = [s_in, s_fuel, s_out]

	vb.add_child(_label("Inventar", 16, DARK, false))
	var main_grid := GridContainer.new()
	main_grid.columns = 9
	main_grid.add_theme_constant_override("h_separation", 4)
	main_grid.add_theme_constant_override("v_separation", 4)
	vb.add_child(main_grid)
	for i in range(9, 36):
		main_grid.add_child(_slot(player.inventory.slots, i, "inv"))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	vb.add_child(sp)
	var hot_grid := GridContainer.new()
	hot_grid.columns = 9
	hot_grid.add_theme_constant_override("h_separation", 4)
	vb.add_child(hot_grid)
	for i in 9:
		hot_grid.add_child(_slot(player.inventory.slots, i, "inv"))

	var btns := HBoxContainer.new()
	vb.add_child(btns)
	var rb := Button.new()
	rb.text = "Rezeptbuch (R)"
	rb.focus_mode = Control.FOCUS_NONE
	rb.pressed.connect(func(): recipe_panel.visible = not recipe_panel.visible)
	btns.add_child(rb)
	btns.add_child(_label("   Shift+Klick = schnell verschieben · Rechtsklick = halbieren / einzeln ablegen", 13, DARK, false))

	recipe_panel = PanelContainer.new()
	recipe_panel.add_theme_stylebox_override("panel", _panel_style())
	recipe_panel.visible = false
	row.add_child(recipe_panel)
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.custom_minimum_size = Vector2(460, 560)
	rtl.add_theme_color_override("default_color", DARK)
	rtl.add_theme_font_size_override("normal_font_size", 14)
	rtl.add_theme_font_size_override("bold_font_size", 14)
	rtl.text = Recipes.describe()
	recipe_panel.add_child(rtl)

	hover_label = _label("", 16)
	hover_label.visible = false
	screen.add_child(hover_label)

	cursor_icon = TextureRect.new()
	cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cursor_icon.size = Vector2(36, 36)
	cursor_icon.visible = false
	screen.add_child(cursor_icon)
	cursor_count = _label("", 15)
	cursor_count.position = Vector2(20, 18)
	cursor_icon.add_child(cursor_count)


func _build_pause() -> void:
	pause_panel = ColorRect.new()
	(pause_panel as ColorRect).color = Color(0.07, 0.08, 0.11, 0.78)
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false
	add_child(pause_panel)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(c)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.custom_minimum_size = Vector2(380, 0)
	c.add_child(vb)
	var l := _label("Spiel pausiert", 40, Color("#dce6ff"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	vb.add_child(_menu_button("Weiterspielen", close_pause, true))
	vb.add_child(_menu_button("Zum Hauptmenü", func(): main.back_to_menu(), false))
	vb.add_child(_menu_button("Spiel beenden", func(): get_tree().quit(), false))


func _menu_button(text: String, cb: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	var bg := Color("#8fb3ff") if primary else Color("#232836")
	var fg := Color("#12151b") if primary else Color("#dce6ff")
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg.lightened(0.12) if st == "hover" else bg
		sb.border_color = Color("#8fb3ff") if st != "normal" or primary else Color(1, 1, 1, 0.08)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(12)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.pressed.connect(cb)
	return b


func open_pause() -> void:
	mode = "pause"
	pause_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func close_pause() -> void:
	pause_panel.visible = false
	mode = ""
	get_tree().paused = false
	if not player.dead:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player.use_cd = 0.3
		player.mine_delay = 0.3


func _build_death() -> void:
	death_panel = ColorRect.new()
	(death_panel as ColorRect).color = Color(0.5, 0.0, 0.0, 0.55)
	death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_panel.visible = false
	add_child(death_panel)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_panel.add_child(c)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	c.add_child(vb)
	var l := _label("Du bist gestorben!", 44)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	var b := Button.new()
	b.text = "Wiederbeleben"
	b.custom_minimum_size = Vector2(260, 48)
	b.pressed.connect(func():
		death_panel.visible = false
		player.respawn()
	)
	vb.add_child(b)


# ---------------------------------------------------------------------------
# Öffnen / Schließen
func is_open() -> bool:
	return mode != ""


func open_inventory() -> void:
	_open("inventory", "Inventar – Handwerk (2x2)")


func open_crafting() -> void:
	_open("crafting", "Werkbank (3x3)")


func open_chest(arr: Array) -> void:
	for s in chest_slots:
		s.container = arr
	_open("chest", "Truhe")


func open_furnace(f: Dictionary) -> void:
	cur_furnace = f
	for s in f_slots:
		s.container = f["slots"]
	_open("furnace", "Ofen")


func _open(m: String, t: String) -> void:
	mode = m
	title.text = t
	craft_w = 3 if m == "crafting" else 2
	craft_box.visible = m == "inventory" or m == "crafting"
	craft_grid_ctrl.columns = craft_w
	for i in 9:
		craft_slots[i].visible = i < craft_w * craft_w
	chest_grid_ctrl.visible = m == "chest"
	furnace_box.visible = m == "furnace"
	screen.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_result()


func close() -> void:
	if mode == "":
		return
	if mode == "pause":
		close_pause()
		return
	for i in 9:
		if craft_grid[i] != null:
			_return_to_player(craft_grid[i])
			craft_grid[i] = null
	if cursor_stack != null:
		_return_to_player(cursor_stack)
		cursor_stack = null
	result_holder[0] = null
	cur_furnace = null
	hover_slot = null
	mode = ""
	screen.visible = false
	if not player.dead:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player.use_cd = 0.3
		player.mine_delay = 0.3


func _return_to_player(st: Dictionary) -> void:
	var left = _insert(player.inventory.slots, range(36), st)
	if left != null:
		message("Inventar voll – %s verloren" % Items.display_name(left["id"]))


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if player == null or player.dead:
		return
	match event.physical_keycode:
		KEY_E:
			if mode == "":
				open_inventory()
			elif mode != "pause":
				close()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if mode == "pause":
				close_pause()
			elif mode != "":
				close()
			else:
				open_pause()
			get_viewport().set_input_as_handled()
		KEY_R:
			if mode != "" and mode != "pause":
				recipe_panel.visible = not recipe_panel.visible
				get_viewport().set_input_as_handled()
		KEY_F11:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ---------------------------------------------------------------------------
# Klick-Logik
func _same(a, b) -> bool:
	return a != null and b != null and a["id"] == b["id"] and Items.max_stack(a["id"]) > 1 and not a.has("dur")


func _copy(st: Dictionary, n: int) -> Dictionary:
	var d := st.duplicate()
	d["count"] = n
	return d


func _accepts(slot, st) -> bool:
	if slot.role == "fout" or slot.role == "result":
		return false
	if slot.role == "ffuel":
		return float(Items.items[st["id"]]["fuel"]) > 0.0
	return true


func _on_hover(slot, inside: bool) -> void:
	if inside:
		hover_slot = slot
	elif hover_slot == slot:
		hover_slot = null


func _on_slot(slot, button: int, shift: bool) -> void:
	if slot.role == "result":
		_take_result(shift)
		return
	var c: Array = slot.container
	var i: int = slot.index
	if shift and button == MOUSE_BUTTON_LEFT:
		_quick_move(slot)
		_update_result()
		return
	var s = c[i]
	var take_only: bool = slot.role == "fout"
	if button == MOUSE_BUTTON_LEFT:
		if cursor_stack == null:
			if s != null:
				cursor_stack = s
				c[i] = null
		elif take_only:
			if _same(s, cursor_stack):
				var room: int = Items.max_stack(s["id"]) - int(cursor_stack["count"])
				var mv: int = mini(room, int(s["count"]))
				cursor_stack["count"] = int(cursor_stack["count"]) + mv
				s["count"] = int(s["count"]) - mv
				if int(s["count"]) <= 0:
					c[i] = null
		elif not _accepts(slot, cursor_stack):
			pass
		elif s == null:
			c[i] = cursor_stack
			cursor_stack = null
		elif _same(s, cursor_stack):
			var maxs: int = Items.max_stack(s["id"])
			var mv2: int = mini(int(cursor_stack["count"]), maxs - int(s["count"]))
			s["count"] = int(s["count"]) + mv2
			cursor_stack["count"] = int(cursor_stack["count"]) - mv2
			if int(cursor_stack["count"]) <= 0:
				cursor_stack = null
		else:
			c[i] = cursor_stack
			cursor_stack = s
	elif button == MOUSE_BUTTON_RIGHT:
		if cursor_stack == null:
			if s != null:
				var half: int = ceili(float(s["count"]) / 2.0)
				cursor_stack = _copy(s, half)
				s["count"] = int(s["count"]) - half
				if int(s["count"]) <= 0:
					c[i] = null
		elif not take_only and _accepts(slot, cursor_stack):
			if s == null:
				c[i] = _copy(cursor_stack, 1)
				cursor_stack["count"] = int(cursor_stack["count"]) - 1
			elif _same(s, cursor_stack) and int(s["count"]) < Items.max_stack(s["id"]):
				s["count"] = int(s["count"]) + 1
				cursor_stack["count"] = int(cursor_stack["count"]) - 1
			if cursor_stack != null and int(cursor_stack["count"]) <= 0:
				cursor_stack = null
	_update_result()


## Fügt st in die angegebenen Plätze ein. Rückgabe: Rest (oder null).
func _insert(c: Array, indices: Array, st: Dictionary):
	var maxs: int = Items.max_stack(st["id"])
	if maxs > 1 and not st.has("dur"):
		for i in indices:
			var s = c[i]
			if s != null and s["id"] == st["id"] and int(s["count"]) < maxs:
				var mv: int = mini(int(st["count"]), maxs - int(s["count"]))
				s["count"] = int(s["count"]) + mv
				st["count"] = int(st["count"]) - mv
				if int(st["count"]) <= 0:
					return null
	for i in indices:
		if c[i] == null:
			if int(st["count"]) <= maxs:
				c[i] = st
				return null
			c[i] = _copy(st, maxs)
			st["count"] = int(st["count"]) - maxs
	return st


func _quick_move(slot) -> void:
	var st = slot.get_slot_stack()
	if st == null:
		return
	var c: Array = slot.container
	var left = st
	if slot.role == "inv":
		if mode == "chest":
			left = _insert(chest_slots[0].container, range(27), st)
		elif mode == "furnace" and cur_furnace != null:
			var fs: Array = cur_furnace["slots"]
			if Recipes.smelting.has(st["id"]):
				left = _insert(fs, [0], st)
			elif float(Items.items[st["id"]]["fuel"]) > 0.0:
				left = _insert(fs, [1], st)
		elif slot.index < 9:
			left = _insert(c, range(9, 36), st)
		else:
			left = _insert(c, range(0, 9), st)
	else:
		left = _insert(player.inventory.slots, range(36), st)
	c[slot.index] = left


func _update_result() -> void:
	if mode != "inventory" and mode != "crafting":
		result_holder[0] = null
		return
	var ids: Array = []
	for i in craft_w * craft_w:
		ids.append(craft_grid[i]["id"] if craft_grid[i] != null else "")
	var r: Dictionary = Recipes.match_grid(ids, craft_w)
	if r.is_empty():
		result_holder[0] = null
	else:
		result_holder[0] = Items.make_stack(r["id"], r["count"])


func _consume_grid() -> void:
	for i in craft_w * craft_w:
		if craft_grid[i] != null:
			craft_grid[i]["count"] = int(craft_grid[i]["count"]) - 1
			if int(craft_grid[i]["count"]) <= 0:
				craft_grid[i] = null


func _take_result(shift: bool) -> void:
	var r = result_holder[0]
	if r == null:
		return
	if shift:
		var guard := 0
		while result_holder[0] != null and guard < 64:
			guard += 1
			var rr: Dictionary = result_holder[0]
			var probe := player.inventory.slots.duplicate(true) as Array
			if _insert(probe, range(36), rr.duplicate()) != null:
				message("Inventar voll!")
				break
			_insert(player.inventory.slots, range(36), rr.duplicate())
			_consume_grid()
			_update_result()
		return
	if cursor_stack == null:
		cursor_stack = r.duplicate()
	elif _same(cursor_stack, r) and int(cursor_stack["count"]) + int(r["count"]) <= Items.max_stack(r["id"]):
		cursor_stack["count"] = int(cursor_stack["count"]) + int(r["count"])
	else:
		return
	_consume_grid()
	_update_result()


# ---------------------------------------------------------------------------
func message(t: String) -> void:
	msg.text = t
	msg_t = 3.0


func flash_hurt() -> void:
	hurt_rect.color = Color(1, 0, 0, 0.35)


func show_death() -> void:
	death_panel.visible = true


func _process(delta: float) -> void:
	if player == null:
		return
	for i in 9:
		hotbar[i].selected = i == player.selected
	var hp: float = player.health
	for i in 10:
		var v := hp - i * 2.0
		if v >= 2.0:
			hearts[i].texture = tex_heart["full"]
		elif v >= 1.0:
			hearts[i].texture = tex_heart["half"]
		else:
			hearts[i].texture = tex_heart["empty"]
	var air: float = player.air
	var show_air: bool = air < player.max_air
	for i in 10:
		bubbles[i].visible = show_air and air > float(i)
	var mp: float = player.mining_progress
	break_bar.visible = mp > 0.0
	break_bar.value = mp * 100.0

	var p: Vector3 = player.global_position
	var hours: float = fmod(6.0 + main.time_of_day * 24.0, 24.0)
	var held := "-"
	var st = player.inventory.slots[player.selected]
	if st != null:
		held = Items.display_name(st["id"])
	info.text = "FPS %d   |   X %.1f  Y %.1f  Z %.1f   |   Tag %d  %02d:%02d   |   Hand: %s   |   Seed %d" % [
		Engine.get_frames_per_second(), p.x, p.y, p.z, main.day, int(hours), int(fmod(hours, 1.0) * 60.0), held, main.world_seed]

	msg_t -= delta
	msg.modulate.a = clampf(msg_t, 0.0, 1.0)
	hurt_rect.color = Color(1, 0, 0, maxf(hurt_rect.color.a - delta * 1.2, 0.0))
	water_rect.visible = player.head_in_water
	pause_label.visible = mode == "" and not player.dead and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED

	if screen.visible:
		var mpos := screen.get_local_mouse_position()
		if cursor_stack != null:
			cursor_icon.visible = true
			cursor_icon.texture = Items.icons.get(cursor_stack["id"])
			cursor_icon.position = mpos - Vector2(18, 18)
			var cnt: int = cursor_stack["count"]
			cursor_count.text = str(cnt) if cnt > 1 else ""
		else:
			cursor_icon.visible = false
		var hs = hover_slot.get_slot_stack() if hover_slot != null else null
		if hs != null and cursor_stack == null:
			hover_label.visible = true
			var txt := Items.display_name(hs["id"])
			if hs.has("dur"):
				txt += "  (%d/%d)" % [int(hs["dur"]), int(Items.items[hs["id"]]["dur"])]
			hover_label.text = txt
			hover_label.position = mpos + Vector2(16, -26)
		else:
			hover_label.visible = false
		if mode == "furnace" and cur_furnace != null:
			f_prog.value = float(cur_furnace["prog"]) / 10.0 * 100.0
			var bm: float = cur_furnace["burn_max"]
			f_burn.value = (float(cur_furnace["burn"]) / bm * 100.0) if bm > 0.0 else 0.0
