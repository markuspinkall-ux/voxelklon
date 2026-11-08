extends Control
## Ein Inventarplatz. Zeigt Icon, Anzahl und Haltbarkeit und meldet Klicks an die UI.

const Items = preload("res://scripts/items.gd")

signal clicked(slot, button: int, shift: bool)
signal hovered(slot, inside: bool)

var container: Array = []
var index := 0
var role := "inv"
var selected := false
var interactive := true


func _init() -> void:
	custom_minimum_size = Vector2(44, 44)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	mouse_entered.connect(func(): hovered.emit(self, true))
	mouse_exited.connect(func(): hovered.emit(self, false))


func get_stack() -> Variant:
	if index < container.size():
		return container[index]
	return null


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.16, 0.16, 0.16, 0.9))
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(0.42, 0.42, 0.42, 0.9))
	draw_rect(Rect2(Vector2(2, 2), Vector2(size.x - 4, 2)), Color(0.30, 0.30, 0.30, 0.9))
	if role == "result":
		draw_rect(r, Color(0.95, 0.85, 0.3, 0.9), false, 2.0)
	if selected:
		draw_rect(r.grow(-1.0), Color(1, 1, 1), false, 3.0)
	var st: Variant = get_stack()
	if st == null:
		return
	var tex: Texture2D = Items.icons.get(st["id"])
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2(6, 6), size - Vector2(12, 12)), false)
	var cnt: int = st["count"]
	var font := ThemeDB.fallback_font
	if cnt > 1:
		var txt := str(cnt)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var pos := Vector2(size.x - 4.0 - w, size.y - 5.0)
		draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1))
	if st.has("dur") and Items.items.has(st["id"]):
		var maxd: int = Items.items[st["id"]]["dur"]
		var cur: int = st["dur"]
		if maxd > 0 and cur < maxd:
			var f := clampf(float(cur) / float(maxd), 0.0, 1.0)
			draw_rect(Rect2(Vector2(6, size.y - 8), Vector2(size.x - 12, 3)), Color(0, 0, 0))
			draw_rect(Rect2(Vector2(6, size.y - 8), Vector2((size.x - 12) * f, 3)), Color(1.0 - f, f, 0.1))


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			clicked.emit(self, event.button_index, event.shift_pressed)
			accept_event()
