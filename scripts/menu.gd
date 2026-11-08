extends CanvasLayer
## Startmenü von Creative Craft im Graphit-Stil von Creative OS:
## Neue Welt (Name, Seed, Sichtweite), Welt laden / löschen, Steuerung, Beenden.

signal start_requested(seed_value: int, radius: int, title: String)
signal load_requested(folder: String, data: Dictionary, radius: int)

const Controls = preload("res://scripts/controls.gd")
const SAVE_ROOT := "user://saves"

const GROUND := Color("#12151b")
const SURFACE := Color("#1c2029")
const RAISED := Color("#232836")
const TEXT := Color("#dce6ff")
const ACCENT := Color("#8fb3ff")
const FLAME := Color("#ffb07a")
const RADII := [3, 4, 5, 6, 8]

var atlas: Image
var radius := 5
var name_edit: LineEdit
var seed_edit: LineEdit
var radius_btn: Button
var loading: Label
var page_main: VBoxContainer
var page_load: VBoxContainer
var page_controls: VBoxContainer
var save_list: VBoxContainer
var splash: Label
var t := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var bg := ColorRect.new()
	bg.color = GROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	if atlas != null:
		var tile := atlas.get_region(Rect2i(Vector2i(32, 0), Vector2i(16, 16)))   # Erde
		tile.resize(96, 96, Image.INTERPOLATE_NEAREST)
		var pattern := TextureRect.new()
		pattern.texture = ImageTexture.create_from_image(tile)
		pattern.stretch_mode = TextureRect.STRETCH_TILE
		pattern.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pattern.set_anchors_preset(Control.PRESET_FULL_RECT)
		pattern.modulate = Color(1, 1, 1, 0.07)
		pattern.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pattern)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	center.add_child(stack)

	var icon_tex := load("res://icon.svg") as Texture2D
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(0, 100)
		stack.add_child(icon)
	var title := _label("CREATIVE CRAFT", 60, TEXT)
	stack.add_child(title)
	splash = _label("Jetzt mit Schafen, Betten und TNT!", 19, FLAME)
	stack.add_child(splash)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	stack.add_child(gap)

	# --- Hauptseite ---
	page_main = _page(stack)
	name_edit = _edit("Name der Welt", "Neue Welt")
	page_main.add_child(name_edit)
	seed_edit = _edit("Seed (leer = zufällig)", "")
	seed_edit.text_submitted.connect(func(_x): _on_new())
	page_main.add_child(seed_edit)
	radius_btn = _button("", _on_radius, false)
	page_main.add_child(radius_btn)
	_update_radius_text()
	page_main.add_child(_button("Neue Welt erstellen", _on_new, true))
	page_main.add_child(_button("Welt laden", _show_load, false))
	page_main.add_child(_button("Steuerung", func(): _show(page_controls), false))
	page_main.add_child(_button("Beenden", func(): get_tree().quit(), false))

	# --- Laden ---
	page_load = _page(stack)
	page_load.add_child(_label("Gespeicherte Welten", 24, TEXT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_load.add_child(scroll)
	save_list = VBoxContainer.new()
	save_list.add_theme_constant_override("separation", 8)
	save_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(save_list)
	page_load.add_child(_button("Zurück", func(): _show(page_main), false))

	# --- Steuerung ---
	page_controls = _page(stack)
	page_controls.add_child(_label("Steuerung", 24, TEXT))
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.custom_minimum_size = Vector2(620, 380)
	rtl.add_theme_color_override("default_color", TEXT)
	rtl.add_theme_font_size_override("normal_font_size", 15)
	rtl.add_theme_font_size_override("bold_font_size", 15)
	rtl.text = Controls.TEXT
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(SURFACE, Color(1, 1, 1, 0.08)))
	panel.add_child(rtl)
	page_controls.add_child(panel)
	page_controls.add_child(_button("Zurück", func(): _show(page_main), false))

	loading = _label("Welt wird geladen …", 30, TEXT)
	loading.visible = false
	stack.add_child(loading)
	_show(page_main)

	var footer := _label("Creative Craft 0.3  ·  Godot %s" % Engine.get_version_info()["string"], 13, Color(TEXT, 0.5))
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.anchor_right = 1.0
	footer.offset_top = -30
	footer.offset_right = -14
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(footer)


func _process(delta: float) -> void:
	t += delta
	if splash != null:
		splash.modulate.a = 0.75 + 0.25 * sin(t * 3.0)


# ---------------------------------------------------------------------------
func _page(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(460, 0)
	parent.add_child(v)
	return v


func _show(page: Control) -> void:
	for p in [page_main, page_load, page_controls]:
		p.visible = p == page


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(10)
	return sb


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _edit(placeholder: String, value: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = value
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.custom_minimum_size = Vector2(0, 46)
	e.add_theme_font_size_override("font_size", 18)
	e.add_theme_color_override("font_color", TEXT)
	e.add_theme_color_override("font_placeholder_color", Color(TEXT, 0.45))
	e.add_theme_stylebox_override("normal", _style(SURFACE, Color(1, 1, 1, 0.08)))
	e.add_theme_stylebox_override("focus", _style(SURFACE, ACCENT))
	return e


func _button(text: String, cb: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 19)
	if primary:
		b.add_theme_stylebox_override("normal", _style(ACCENT, ACCENT))
		b.add_theme_stylebox_override("hover", _style(ACCENT.lightened(0.15), ACCENT.lightened(0.15)))
		b.add_theme_stylebox_override("pressed", _style(ACCENT.darkened(0.15), ACCENT))
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, GROUND)
	else:
		b.add_theme_stylebox_override("normal", _style(RAISED, Color(1, 1, 1, 0.08)))
		b.add_theme_stylebox_override("hover", _style(RAISED.lightened(0.08), ACCENT))
		b.add_theme_stylebox_override("pressed", _style(SURFACE, ACCENT))
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, TEXT)
	b.pressed.connect(cb)
	return b


func _on_radius() -> void:
	var i := RADII.find(radius)
	radius = RADII[(i + 1) % RADII.size()]
	_update_radius_text()


func _update_radius_text() -> void:
	radius_btn.text = "Sichtweite: %d Chunks" % radius


func _on_new() -> void:
	if loading.visible:
		return
	var txt := seed_edit.text.strip_edges()
	var sv := 0
	if txt == "":
		sv = randi() % 1000000
	elif txt.is_valid_int():
		sv = int(txt)
	else:
		sv = absi(hash(txt)) % 1000000000
	var title := name_edit.text.strip_edges()
	if title == "":
		title = "Neue Welt"
	start_requested.emit(sv, radius, title)


# ---------------------------------------------------------------------------
# Spielstände
func _list_saves() -> Array:
	var out: Array = []
	var d := DirAccess.open(SAVE_ROOT)
	if d == null:
		return out
	for folder in d.get_directories():
		var cfg := ConfigFile.new()
		if cfg.load(SAVE_ROOT + "/" + folder + "/meta.cfg") != OK:
			continue
		out.append({
			"folder": folder,
			"name": str(cfg.get_value("save", "name", folder)),
			"day": int(cfg.get_value("save", "day", 1)),
			"time": str(cfg.get_value("save", "time", "")),
			"unix": float(cfg.get_value("save", "unix", 0.0)),
		})
	out.sort_custom(func(a, b): return a["unix"] > b["unix"])
	return out


func _show_load() -> void:
	for c in save_list.get_children():
		c.queue_free()
	var saves := _list_saves()
	if saves.is_empty():
		save_list.add_child(_label("Noch keine gespeicherten Welten.", 16, Color(TEXT, 0.6)))
	for sv in saves:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var folder: String = sv["folder"]
		var b := _button("%s   ·   Tag %d   ·   %s" % [sv["name"], sv["day"], sv["time"]], func(): _load(folder), false)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		var del := _button("Löschen", func(): pass, false)
		del.pressed.connect(func(): _on_delete(del, folder))
		del.custom_minimum_size = Vector2(110, 48)
		row.add_child(del)
		save_list.add_child(row)
	_show(page_load)


func _load(folder: String) -> void:
	if loading.visible:
		return
	var f := FileAccess.open(SAVE_ROOT + "/" + folder + "/world.dat", FileAccess.READ)
	if f == null:
		return
	var data = f.get_var(false)
	f.close()
	if not (data is Dictionary):
		return
	load_requested.emit(folder, data, radius)


func _on_delete(btn: Button, folder: String) -> void:
	if btn.text == "Löschen":
		btn.text = "Wirklich?"
	else:
		_delete(folder)


func _delete(folder: String) -> void:
	var path := SAVE_ROOT + "/" + folder
	var d := DirAccess.open(path)
	if d != null:
		for file in d.get_files():
			d.remove(file)
	DirAccess.remove_absolute(path)
	_show_load()


func show_loading() -> void:
	for p in [page_main, page_load, page_controls]:
		p.visible = false
	loading.visible = true
