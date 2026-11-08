extends CanvasLayer
## Startmenü von Creative Craft im Graphit-Stil von Creative OS.

signal start_requested(seed_value: int, radius: int)

const GROUND := Color("#12151b")
const SURFACE := Color("#1c2029")
const RAISED := Color("#232836")
const TEXT := Color("#dce6ff")
const ACCENT := Color("#8fb3ff")
const FLAME := Color("#ffb07a")
const RADII := [3, 4, 5, 6, 8]

var atlas: Image
var radius := 5
var seed_edit: LineEdit
var radius_btn: Button
var loading: Label
var box: VBoxContainer
var splash: Label
var t := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var bg := ColorRect.new()
	bg.color = GROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# dezentes Blockmuster im Hintergrund
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

	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(440, 0)
	center.add_child(box)

	var icon_tex := load("res://icon.svg") as Texture2D
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(0, 110)
		box.add_child(icon)

	var title := _label("CREATIVE CRAFT", 64, TEXT)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	box.add_child(title)

	splash = _label("Jetzt mit Dörfern und Creepern!", 20, FLAME)
	box.add_child(splash)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	box.add_child(gap)

	box.add_child(_button("Neue Welt starten", _on_start, true))

	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "Seed (leer = zufällig)"
	seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_edit.custom_minimum_size = Vector2(0, 46)
	seed_edit.add_theme_font_size_override("font_size", 18)
	seed_edit.add_theme_color_override("font_color", TEXT)
	seed_edit.add_theme_color_override("font_placeholder_color", Color(TEXT, 0.45))
	seed_edit.add_theme_stylebox_override("normal", _style(SURFACE, Color(1, 1, 1, 0.08)))
	seed_edit.add_theme_stylebox_override("focus", _style(SURFACE, ACCENT))
	seed_edit.text_submitted.connect(func(_t): _on_start())
	box.add_child(seed_edit)

	radius_btn = _button("", _on_radius, false)
	box.add_child(radius_btn)
	_update_radius_text()

	box.add_child(_button("Beenden", func(): get_tree().quit(), false))

	loading = _label("Welt wird erzeugt …", 30, TEXT)
	loading.visible = false
	center.add_child(loading)

	var footer := _label("Creative Craft 0.2  ·  Godot %s" % Engine.get_version_info()["string"], 13, Color(TEXT, 0.5))
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


func _button(text: String, cb: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	if primary:
		b.add_theme_stylebox_override("normal", _style(ACCENT, ACCENT))
		b.add_theme_stylebox_override("hover", _style(ACCENT.lightened(0.15), ACCENT.lightened(0.15)))
		b.add_theme_stylebox_override("pressed", _style(ACCENT.darkened(0.15), ACCENT))
		b.add_theme_color_override("font_color", GROUND)
		b.add_theme_color_override("font_hover_color", GROUND)
		b.add_theme_color_override("font_pressed_color", GROUND)
	else:
		b.add_theme_stylebox_override("normal", _style(RAISED, Color(1, 1, 1, 0.08)))
		b.add_theme_stylebox_override("hover", _style(RAISED.lightened(0.08), ACCENT))
		b.add_theme_stylebox_override("pressed", _style(SURFACE, ACCENT))
		b.add_theme_color_override("font_color", TEXT)
		b.add_theme_color_override("font_hover_color", TEXT)
		b.add_theme_color_override("font_pressed_color", TEXT)
	b.pressed.connect(cb)
	return b


func _on_radius() -> void:
	var i := RADII.find(radius)
	radius = RADII[(i + 1) % RADII.size()]
	_update_radius_text()


func _update_radius_text() -> void:
	radius_btn.text = "Sichtweite: %d Chunks" % radius


func _on_start() -> void:
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
	start_requested.emit(sv, radius)


func show_loading() -> void:
	box.visible = false
	loading.visible = true
