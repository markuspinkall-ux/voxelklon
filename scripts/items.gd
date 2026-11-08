extends RefCounted
## Item-Register: alle Blöcke als Items, dazu Werkzeuge, Rohstoffe, Nahrung.
## Erzeugt außerdem alle Inventar-Icons (isometrische Blöcke + Pixel-Art-Items).

const Blocks = preload("res://scripts/blocks.gd")

static var items: Dictionary = {}
static var icons: Dictionary = {}


static func setup(atlas: Image) -> void:
	Blocks.setup()
	items.clear()
	for id in range(1, Blocks.COUNT):
		var d: Dictionary = Blocks.defs[id]
		var it: String = d["item"]
		if it == "":
			continue
		_add(it, d["name"], {"block": id})

	_add("stick", "Stock", {"fuel": 5.0})
	_add("coal", "Kohle", {"fuel": 80.0})
	_add("charcoal", "Holzkohle", {"fuel": 80.0})
	_add("raw_iron", "Roheisen")
	_add("iron_ingot", "Eisenbarren")
	_add("diamond", "Diamant")
	_add("apple", "Apfel", {"food": 4})
	_add("rotten_flesh", "Verrottetes Fleisch", {"food": 2})
	_add("gunpowder", "Schwarzpulver")
	_add("snowball", "Schneeball", {"stack": 16})
	_add("bucket", "Eimer", {"stack": 16})
	_add("water_bucket", "Wassereimer", {"stack": 1})
	_add("flint", "Feuerstein")
	_add("flint_and_steel", "Feuerzeug", {"stack": 1, "dur": 64})
	_add("shears", "Schere", {"stack": 1, "tool": "shears", "tier": 0, "speed": 5.0, "dur": 238})
	_add("red_dye", "Roter Farbstoff")
	_add("yellow_dye", "Gelber Farbstoff")
	_add("raw_mutton", "Rohes Hammelfleisch", {"food": 2})
	_add("cooked_mutton", "Gebratenes Hammelfleisch", {"food": 6})

	# Werkzeuge: [id-Präfix, Name, Stufe, Abbaugeschwindigkeit, Haltbarkeit]
	var mats := [
		["wooden", "Holz", 0, 2.0, 59],
		["stone", "Stein", 1, 4.0, 131],
		["iron", "Eisen", 2, 6.0, 250],
		["diamond", "Diamant", 3, 8.0, 1561],
	]
	# [Werkzeugtyp, Namensendung, Grundschaden]
	var tools := [
		["pickaxe", "spitzhacke", 2.0],
		["axe", "axt", 3.0],
		["shovel", "schaufel", 1.5],
		["sword", "schwert", 4.0],
	]
	for m in mats:
		for t in tools:
			var id: String = str(m[0]) + "_" + str(t[0])
			var nm: String = str(m[1]) + str(t[1])
			var extra := {
				"stack": 1, "tool": t[0], "tier": m[2], "speed": m[3],
				"dur": m[4], "damage": float(t[2]) + float(m[2]),
			}
			if m[0] == "wooden":
				extra["fuel"] = 10.0
			_add(id, nm, extra)

	# Brennstoffe (Sekunden Brenndauer, 10 s = 1 geschmolzenes Item)
	items["oak_log"]["fuel"] = 15.0
	items["oak_planks"]["fuel"] = 15.0
	items["crafting_table"]["fuel"] = 15.0
	items["chest"]["fuel"] = 15.0
	items["coal_block"]["fuel"] = 800.0

	_build_icons(atlas)


static func _add(id: String, name: String, extra: Dictionary = {}) -> void:
	var d := {
		"id": id, "name": name, "stack": 64, "block": -1, "tool": "", "tier": -1,
		"speed": 1.0, "dur": 0, "damage": 1.0, "food": 0, "fuel": 0.0,
	}
	d.merge(extra, true)
	items[id] = d


static func max_stack(id: String) -> int:
	if items.has(id):
		return int(items[id]["stack"])
	return 64


static func make_stack(id: String, count: int) -> Dictionary:
	var s := {"id": id, "count": count}
	if items.has(id):
		var dur: int = items[id]["dur"]
		if dur > 0:
			s["dur"] = dur
	return s


static func display_name(id: String) -> String:
	if items.has(id):
		return items[id]["name"]
	return id


# ---------------------------------------------------------------------------
# Icons
static func _build_icons(atlas: Image) -> void:
	icons.clear()
	for id in items.keys():
		var d: Dictionary = items[id]
		var b: int = d["block"]
		var img: Image
		if b >= 0:
			if Blocks.kind[b] == Blocks.CROSS:
				img = _tile_icon(atlas, Blocks.tile_side[b])
			else:
				img = _iso_icon(atlas, Blocks.tile_top[b], Blocks.tile_side[b], Blocks.tile_front[b])
		else:
			img = _item_image(id)
		icons[id] = ImageTexture.create_from_image(img)


static func _tile_origin(tile: int) -> Vector2i:
	return Vector2i((tile % 8) * 16, (tile / 8) * 16)


static func _texel(atlas: Image, tile: int, u: int, v: int) -> Color:
	var o := _tile_origin(tile)
	return atlas.get_pixel(o.x + clampi(u, 0, 15), o.y + clampi(v, 0, 15))


static func _tile_icon(atlas: Image, tile: int) -> Image:
	var o := _tile_origin(tile)
	var img := atlas.get_region(Rect2i(o, Vector2i(16, 16)))
	img.resize(32, 32, Image.INTERPOLATE_NEAREST)
	return img


## Kleiner isometrischer Würfel wie im Minecraft-Inventar
static func _iso_icon(atlas: Image, top: int, side: int, front: int) -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pt := Vector2(16, 1)
	var pr := Vector2(30, 8)
	var pb := Vector2(16, 15)
	var pl := Vector2(2, 8)
	var down := Vector2(0, 15)
	var steps := 48
	for i in steps:
		for j in steps:
			var u := (i + 0.5) / steps
			var v := (j + 0.5) / steps
			var tu := int(u * 16.0)
			var tv := int(v * 16.0)
			_plot(img, pt + (pr - pt) * u + (pl - pt) * v, _texel(atlas, top, tu, tv), 1.0)
			_plot(img, pl + (pb - pl) * u + down * v, _texel(atlas, front, tu, tv), 0.78)
			_plot(img, pb + (pr - pb) * u + down * v, _texel(atlas, side, tu, tv), 0.58)
	return img


static func _plot(img: Image, p: Vector2, c: Color, shade: float) -> void:
	if c.a < 0.5:
		return
	var x := int(p.x)
	var y := int(p.y)
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, Color(c.r * shade, c.g * shade, c.b * shade, 1.0))


static func _item_image(id: String) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var d: Dictionary = items[id]
	var tool: String = d["tool"]
	if tool != "" and tool != "shears":
		var cols := [Color(0.66, 0.50, 0.29), Color(0.56, 0.56, 0.56), Color(0.90, 0.90, 0.92), Color(0.35, 0.90, 0.82)]
		_draw_tool(img, tool, cols[int(d["tier"])])
	else:
		match id:
			"stick":
				_line(img, 3, 13, 12, 4, Color(0.58, 0.40, 0.21))
				_line(img, 4, 13, 13, 4, Color(0.42, 0.29, 0.15))
			"coal":
				_disc(img, 8, 8, 5.0, Color(0.14, 0.14, 0.14))
				_dots(img, Color(0.32, 0.32, 0.32), 8, 8, 4.0, 7, 1)
			"charcoal":
				_disc(img, 8, 8, 5.0, Color(0.22, 0.18, 0.14))
				_dots(img, Color(0.38, 0.30, 0.22), 8, 8, 4.0, 7, 2)
			"raw_iron":
				_disc(img, 8, 9, 5.0, Color(0.78, 0.64, 0.52))
				_dots(img, Color(0.58, 0.44, 0.34), 8, 9, 4.0, 9, 3)
			"iron_ingot":
				_rect(img, 3, 7, 10, 4, Color(0.85, 0.85, 0.87))
				_rect(img, 4, 6, 8, 1, Color(0.97, 0.97, 0.98))
				_rect(img, 3, 10, 10, 1, Color(0.60, 0.60, 0.62))
			"diamond":
				for y in range(3, 14):
					var w := 5 - absi(y - 8)
					for x in range(8 - w, 9 + w):
						var c := Color(0.35, 0.92, 0.85) if y < 8 else Color(0.20, 0.72, 0.68)
						_px(img, x, y, c)
				_px(img, 7, 5, Color(0.9, 1, 1))
			"apple":
				_disc(img, 8, 9, 5.0, Color(0.86, 0.12, 0.12))
				_px(img, 6, 7, Color(1, 0.7, 0.7))
				_line(img, 8, 2, 8, 4, Color(0.40, 0.26, 0.12))
				_px(img, 9, 3, Color(0.25, 0.65, 0.2))
				_px(img, 10, 3, Color(0.25, 0.65, 0.2))
			"rotten_flesh":
				_disc(img, 7, 8, 4.5, Color(0.58, 0.32, 0.22))
				_disc(img, 10, 10, 3.0, Color(0.45, 0.50, 0.25))
				_dots(img, Color(0.35, 0.22, 0.15), 8, 9, 4.0, 8, 4)
			"gunpowder":
				_dots(img, Color(0.38, 0.38, 0.38), 8, 10, 5.0, 40, 5)
				_dots(img, Color(0.25, 0.25, 0.25), 8, 10, 4.0, 20, 6)
			"snowball":
				_disc(img, 8, 8, 4.5, Color(0.95, 0.97, 1.0))
				_dots(img, Color(0.78, 0.84, 0.92), 9, 9, 3.0, 6, 7)
			"bucket", "water_bucket":
				var g := Color(0.72, 0.72, 0.74)
				_line(img, 3, 5, 12, 5, g.lightened(0.2))
				for y in range(6, 14):
					var inset := (y - 6) / 3
					for x in range(3 + inset, 13 - inset):
						_px(img, x, y, g)
				_line(img, 3, 4, 6, 1, Color(0.5, 0.5, 0.52))
				_line(img, 6, 1, 9, 1, Color(0.5, 0.5, 0.52))
				_line(img, 9, 1, 12, 4, Color(0.5, 0.5, 0.52))
				if id == "water_bucket":
					_rect(img, 4, 6, 8, 2, Color(0.2, 0.4, 0.9))
				else:
					_rect(img, 4, 6, 8, 1, Color(0.35, 0.35, 0.36))
			"flint":
				for y in range(4, 14):
					var w := 1 + (y - 4) / 2 if y < 10 else 4 - (y - 10)
					for x in range(8 - w, 8 + w):
						_px(img, x, y, Color(0.22, 0.22, 0.24) if (x + y) % 3 else Color(0.38, 0.38, 0.42))
			"flint_and_steel":
				var st := Color(0.70, 0.70, 0.74)
				_line(img, 3, 5, 3, 11, st)
				_line(img, 3, 5, 7, 2, st)
				_line(img, 3, 11, 7, 14, st)
				_line(img, 4, 5, 4, 11, st.darkened(0.3))
				for y in range(5, 12):
					for x in range(9, 14):
						if absi(x - 11) + absi(y - 8) <= 3:
							_px(img, x, y, Color(0.25, 0.25, 0.27))
			"shears":
				var bl := Color(0.85, 0.85, 0.88)
				_line(img, 4, 4, 11, 11, bl)
				_line(img, 11, 4, 4, 11, bl)
				_line(img, 5, 4, 11, 10, bl.darkened(0.3))
				_disc(img, 12.5, 12.5, 2.0, Color(0.55, 0.30, 0.15))
				_disc(img, 3.5, 12.5, 2.0, Color(0.55, 0.30, 0.15))
				_px(img, 12, 12, Color(0, 0, 0, 0))
				_px(img, 3, 12, Color(0, 0, 0, 0))
			"red_dye", "yellow_dye":
				var dc := Color(0.80, 0.12, 0.12) if id == "red_dye" else Color(0.98, 0.82, 0.15)
				_disc(img, 8, 10, 4.0, dc)
				for y in range(3, 8):
					var w := (y - 2) / 2
					for x in range(8 - w, 9 + w):
						_px(img, x, y, dc)
				_px(img, 6, 9, dc.lightened(0.5))
			"raw_mutton", "cooked_mutton":
				var mc := Color(0.85, 0.35, 0.35) if id == "raw_mutton" else Color(0.55, 0.32, 0.18)
				_disc(img, 8, 9, 5.0, mc)
				_line(img, 4, 8, 12, 8, Color(0.95, 0.90, 0.85) if id == "raw_mutton" else Color(0.75, 0.55, 0.35))
				_rect(img, 12, 3, 2, 4, Color(0.92, 0.90, 0.85))
			_:
				_disc(img, 8, 8, 5.0, Color(1, 0, 1))
	img.resize(32, 32, Image.INTERPOLATE_NEAREST)
	return img


static func _draw_tool(img: Image, tool: String, m: Color) -> void:
	var h := Color(0.47, 0.32, 0.16)
	var hd := h.darkened(0.3)
	var md := m.darkened(0.35)
	var ml := m.lightened(0.25)
	match tool:
		"sword":
			_line(img, 4, 11, 13, 2, m)
			_line(img, 5, 11, 13, 3, md)
			_line(img, 4, 10, 12, 2, ml)
			_line(img, 2, 9, 6, 13, md)
			_line(img, 1, 14, 3, 12, h)
			_line(img, 2, 14, 3, 13, hd)
		"pickaxe":
			_line(img, 2, 13, 10, 5, h)
			_line(img, 3, 13, 11, 5, hd)
			_line(img, 4, 2, 10, 2, m)
			_line(img, 4, 3, 10, 3, md)
			_line(img, 10, 2, 13, 5, ml)
			_line(img, 10, 3, 12, 5, m)
			_line(img, 13, 5, 13, 11, m)
			_line(img, 12, 5, 12, 11, md)
		"axe":
			_line(img, 2, 13, 11, 4, h)
			_line(img, 3, 13, 12, 4, hd)
			_rect(img, 8, 1, 4, 5, m)
			_rect(img, 12, 2, 2, 4, md)
			_rect(img, 8, 1, 4, 1, ml)
		"shovel":
			_line(img, 2, 13, 9, 6, h)
			_line(img, 3, 13, 10, 6, hd)
			_disc(img, 11.5, 4.5, 2.8, m)
			_px(img, 11, 3, ml)
			_px(img, 13, 6, md)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var guard := 0
	while guard < 64:
		guard += 1
		_px(img, x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in 16:
		for x in 16:
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
				_px(img, x, y, c)


static func _dots(img: Image, c: Color, cx: float, cy: float, r: float, n: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in n:
		var a := rng.randf() * TAU
		var d := rng.randf() * r
		_px(img, int(cx + cos(a) * d), int(cy + sin(a) * d), c)
