extends RefCounted
## Erzeugt alle Block-Texturen prozedural (16x16 Pixel pro Kachel, Atlas mit 8x8 Kacheln).
## So braucht das Projekt keine externen Bilddateien.

const B = preload("res://scripts/blocks.gd")
const T := 16
const N := 8

static var rng := RandomNumberGenerator.new()


static func build() -> Image:
	var img := Image.create(T * N, T * N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	rng.seed = 424242

	# --- Erde & Gras ---
	_noise(img, B.T_DIRT, Color(0.53, 0.38, 0.26), 0.10)
	_specks(img, B.T_DIRT, Color(0.40, 0.28, 0.19), 22)
	_specks(img, B.T_DIRT, Color(0.63, 0.48, 0.34), 10)

	_noise(img, B.T_GRASS_TOP, Color(0.37, 0.62, 0.24), 0.13)
	_specks(img, B.T_GRASS_TOP, Color(0.29, 0.51, 0.18), 26)

	_copy(img, B.T_DIRT, B.T_GRASS_SIDE)
	for x in T:
		var depth := 3 + rng.randi_range(0, 2)
		for y in depth:
			_px(img, B.T_GRASS_SIDE, x, y, _vary(Color(0.37, 0.62, 0.24), 0.12))

	# --- Stein & Co ---
	_noise(img, B.T_STONE, Color(0.50, 0.50, 0.50), 0.07)
	for i in 10:
		var sx := rng.randi_range(0, 13)
		var sy := rng.randi_range(0, 15)
		for k in rng.randi_range(2, 4):
			if sx + k < T:
				_px(img, B.T_STONE, sx + k, sy, _vary(Color(0.40, 0.40, 0.40), 0.05))

	_cobble(img, B.T_COBBLE, Color(0.52, 0.52, 0.52))

	for y in T:
		for x in T:
			var g := [0.18, 0.32, 0.48][rng.randi_range(0, 2)] as float
			_px(img, B.T_BEDROCK, x, y, _vary(Color(g, g, g), 0.1))

	for y in T:
		for x in T:
			var choices := [Color(0.50, 0.48, 0.47), Color(0.42, 0.40, 0.39), Color(0.60, 0.57, 0.55), Color(0.47, 0.42, 0.37)]
			_px(img, B.T_GRAVEL, x, y, _vary(choices[rng.randi_range(0, 3)], 0.06))

	_ore(img, B.T_COAL_ORE, Color(0.12, 0.12, 0.12))
	_ore(img, B.T_IRON_ORE, Color(0.85, 0.68, 0.52))
	_ore(img, B.T_DIAMOND_ORE, Color(0.40, 0.92, 0.88))

	# Steinziegel
	_noise(img, B.T_STONE_BRICKS, Color(0.52, 0.52, 0.52), 0.05)
	for y in T:
		for x in T:
			var ly := y % 8
			var off := 0 if y < 8 else 4
			var lx := (x + off) % 8
			if ly == 7 or lx == 7:
				_px(img, B.T_STONE_BRICKS, x, y, Color(0.32, 0.32, 0.32))
			elif ly == 0 or lx == 0:
				_px(img, B.T_STONE_BRICKS, x, y, _vary(Color(0.62, 0.62, 0.62), 0.03))

	# --- Holz ---
	for x in T:
		var col := _vary(Color(0.42, 0.32, 0.19), 0.14)
		for y in T:
			_px(img, B.T_LOG_SIDE, x, y, _vary(col, 0.06))
	for i in 7:
		var lx := rng.randi_range(0, 15)
		var ly := rng.randi_range(0, 11)
		for k in rng.randi_range(3, 6):
			if ly + k < T:
				_px(img, B.T_LOG_SIDE, lx, ly + k, Color(0.30, 0.22, 0.13))

	for y in T:
		for x in T:
			var d := Vector2(x - 7.5, y - 7.5).length()
			var c := Color(0.40, 0.30, 0.18)
			if d <= 6.8:
				c = Color(0.73, 0.59, 0.37) if int(d) % 2 == 0 else Color(0.63, 0.50, 0.30)
			_px(img, B.T_LOG_TOP, x, y, _vary(c, 0.05))

	var rows: Array = []
	for r in 4:
		rows.append(_vary(Color(0.72, 0.57, 0.35), 0.07))
	for y in T:
		var row := y / 4
		for x in T:
			var c: Color = rows[row]
			if y % 4 == 3:
				c = Color(0.46, 0.34, 0.20)
			elif x == (row * 7 + 3) % 16:
				c = Color(0.53, 0.40, 0.24)
			_px(img, B.T_PLANKS, x, y, _vary(c, 0.04))

	# Laub (mit Löchern -> Alpha-Scissor)
	for y in T:
		for x in T:
			if rng.randf() < 0.17:
				_px(img, B.T_LEAVES, x, y, Color(0, 0, 0, 0))
			else:
				_px(img, B.T_LEAVES, x, y, _vary(Color(0.22, 0.50, 0.15), 0.25))

	# --- Sand, Wasser, Glas, Schnee ---
	_noise(img, B.T_SAND, Color(0.86, 0.82, 0.60), 0.05)
	_specks(img, B.T_SAND, Color(0.78, 0.72, 0.50), 14)

	for y in T:
		for x in T:
			var c := _vary(Color(0.20, 0.40, 0.85, 0.72), 0.07)
			if (x + y * 3) % 11 == 0:
				c = Color(0.45, 0.62, 0.95, 0.72)
			_px(img, B.T_WATER, x, y, c)

	for i in T:
		_px(img, B.T_GLASS, i, 0, Color(0.82, 0.90, 0.95))
		_px(img, B.T_GLASS, i, 15, Color(0.70, 0.80, 0.86))
		_px(img, B.T_GLASS, 0, i, Color(0.82, 0.90, 0.95))
		_px(img, B.T_GLASS, 15, i, Color(0.70, 0.80, 0.86))
	for p in [Vector2i(3, 4), Vector2i(4, 3), Vector2i(5, 2), Vector2i(11, 12), Vector2i(12, 11)]:
		_px(img, B.T_GLASS, p.x, p.y, Color(1, 1, 1))

	_noise(img, B.T_SNOW, Color(0.95, 0.97, 1.0), 0.03)
	_copy(img, B.T_DIRT, B.T_SNOW_SIDE)
	for x in T:
		var depth := 3 + rng.randi_range(0, 1)
		for y in depth:
			_px(img, B.T_SNOW_SIDE, x, y, _vary(Color(0.95, 0.97, 1.0), 0.03))

	# --- Werkbank ---
	_copy(img, B.T_PLANKS, B.T_CT_TOP)
	_border(img, B.T_CT_TOP, Color(0.40, 0.28, 0.15))
	for i in range(2, 14):
		_px(img, B.T_CT_TOP, i, 2, Color(0.45, 0.33, 0.18))
		_px(img, B.T_CT_TOP, i, 13, Color(0.45, 0.33, 0.18))
		_px(img, B.T_CT_TOP, 2, i, Color(0.45, 0.33, 0.18))
		_px(img, B.T_CT_TOP, 13, i, Color(0.45, 0.33, 0.18))
	_copy(img, B.T_PLANKS, B.T_CT_SIDE)
	_rect(img, B.T_CT_SIDE, 0, 0, 16, 3, Color(0.45, 0.32, 0.18))
	_border(img, B.T_CT_SIDE, Color(0.36, 0.25, 0.13))
	_rect(img, B.T_CT_SIDE, 3, 6, 2, 8, Color(0.36, 0.25, 0.14))
	_rect(img, B.T_CT_SIDE, 2, 5, 4, 2, Color(0.62, 0.62, 0.62))
	_rect(img, B.T_CT_SIDE, 9, 6, 4, 7, Color(0.66, 0.66, 0.68))
	_rect(img, B.T_CT_SIDE, 9, 5, 4, 1, Color(0.36, 0.25, 0.14))

	# --- Ofen ---
	_noise(img, B.T_FURNACE_SIDE, Color(0.50, 0.50, 0.50), 0.07)
	_border(img, B.T_FURNACE_SIDE, Color(0.36, 0.36, 0.36))
	_copy(img, B.T_FURNACE_SIDE, B.T_FURNACE_FRONT)
	_rect(img, B.T_FURNACE_FRONT, 4, 8, 8, 6, Color(0.09, 0.09, 0.09))
	_rect(img, B.T_FURNACE_FRONT, 5, 12, 6, 1, Color(0.90, 0.50, 0.12))
	_rect(img, B.T_FURNACE_FRONT, 4, 3, 8, 2, Color(0.25, 0.25, 0.25))
	_noise(img, B.T_FURNACE_TOP, Color(0.58, 0.58, 0.58), 0.05)
	_border(img, B.T_FURNACE_TOP, Color(0.40, 0.40, 0.40))

	# --- Truhe ---
	_noise(img, B.T_CHEST_SIDE, Color(0.64, 0.44, 0.20), 0.08)
	_border(img, B.T_CHEST_SIDE, Color(0.33, 0.21, 0.10))
	_rect(img, B.T_CHEST_SIDE, 0, 5, 16, 1, Color(0.33, 0.21, 0.10))
	_copy(img, B.T_CHEST_SIDE, B.T_CHEST_FRONT)
	_rect(img, B.T_CHEST_FRONT, 7, 4, 2, 4, Color(0.82, 0.82, 0.82))
	_rect(img, B.T_CHEST_FRONT, 7, 7, 2, 1, Color(0.40, 0.40, 0.40))
	_noise(img, B.T_CHEST_TOP, Color(0.66, 0.46, 0.22), 0.08)
	_border(img, B.T_CHEST_TOP, Color(0.33, 0.21, 0.10))

	# --- Sandstein ---
	_noise(img, B.T_SANDSTONE, Color(0.86, 0.79, 0.56), 0.04)
	_rect(img, B.T_SANDSTONE, 0, 0, 16, 3, Color(0.90, 0.84, 0.62))
	_rect(img, B.T_SANDSTONE, 0, 12, 16, 1, Color(0.76, 0.68, 0.46))
	_rect(img, B.T_SANDSTONE, 0, 14, 16, 1, Color(0.76, 0.68, 0.46))
	_noise(img, B.T_SANDSTONE_TOP, Color(0.88, 0.82, 0.60), 0.04)
	_border(img, B.T_SANDSTONE_TOP, Color(0.80, 0.72, 0.50))

	# --- Erz-/Metallblöcke ---
	_metal(img, B.T_IRON_BLOCK, Color(0.85, 0.85, 0.86))
	_metal(img, B.T_DIAMOND_BLOCK, Color(0.40, 0.90, 0.85))
	_noise(img, B.T_COAL_BLOCK, Color(0.11, 0.11, 0.11), 0.15)
	_specks(img, B.T_COAL_BLOCK, Color(0.22, 0.22, 0.22), 20)

	# --- Pfad ---
	_noise(img, B.T_PATH_TOP, Color(0.58, 0.47, 0.30), 0.08)
	_copy(img, B.T_DIRT, B.T_PATH_SIDE)
	for x in T:
		_px(img, B.T_PATH_SIDE, x, 0, _vary(Color(0.58, 0.47, 0.30), 0.06))
		_px(img, B.T_PATH_SIDE, x, 1, _vary(Color(0.58, 0.47, 0.30), 0.06))

	# --- Pflanzen & Fackel (transparent) ---
	for y in range(6, 16):
		_px(img, B.T_TORCH, 7, y, Color(0.50, 0.35, 0.18))
		_px(img, B.T_TORCH, 8, y, Color(0.40, 0.28, 0.14))
	_rect(img, B.T_TORCH, 7, 4, 2, 2, Color(1.0, 0.85, 0.3))
	_px(img, B.T_TORCH, 7, 3, Color(1.0, 0.95, 0.6))
	_px(img, B.T_TORCH, 8, 3, Color(1.0, 0.6, 0.15))

	_flower(img, B.T_POPPY, Color(0.85, 0.10, 0.10), Color(0.20, 0.15, 0.10))
	_flower(img, B.T_DANDELION, Color(1.0, 0.85, 0.15), Color(0.95, 0.70, 0.10))

	for k in 7:
		var bx := rng.randi_range(2, 13)
		var bh := rng.randi_range(5, 12)
		var lean := rng.randi_range(-1, 1)
		for i in bh:
			var xx := bx + int(float(i) / float(bh) * lean * 2.0)
			_px(img, B.T_SHORT_GRASS, clampi(xx, 0, 15), 15 - i, _vary(Color(0.33, 0.60, 0.22), 0.15))

	# --- Wolle ---
	_wool(img, B.T_WOOL_WHITE, Color(0.92, 0.92, 0.92))
	_wool(img, B.T_WOOL_RED, Color(0.70, 0.16, 0.15))
	_wool(img, B.T_WOOL_YELLOW, Color(0.97, 0.78, 0.18))

	# --- Bett: rote Decke mit weißem Kissen, Seite mit Holzrahmen ---
	_wool(img, B.T_BED_TOP, Color(0.70, 0.16, 0.15))
	_rect(img, B.T_BED_TOP, 2, 1, 12, 4, Color(0.94, 0.94, 0.94))
	_border(img, B.T_BED_TOP, Color(0.50, 0.10, 0.10))
	_copy(img, B.T_PLANKS, B.T_BED_SIDE)
	_rect(img, B.T_BED_SIDE, 0, 0, 16, 6, Color(0.70, 0.16, 0.15))
	_rect(img, B.T_BED_SIDE, 0, 6, 16, 3, Color(0.94, 0.94, 0.94))
	_rect(img, B.T_BED_SIDE, 0, 13, 3, 3, Color(0.40, 0.28, 0.15))
	_rect(img, B.T_BED_SIDE, 13, 13, 3, 3, Color(0.40, 0.28, 0.15))
	for x in range(3, 13):
		for y in range(13, 16):
			_px(img, B.T_BED_SIDE, x, y, Color(0, 0, 0, 0))

	# --- TNT ---
	_noise(img, B.T_TNT_SIDE, Color(0.80, 0.18, 0.12), 0.08)
	for x in T:
		_px(img, B.T_TNT_SIDE, x, 0, Color(0.55, 0.10, 0.08))
		if x % 4 == 0:
			for y in T:
				_px(img, B.T_TNT_SIDE, x, y, _vary(Color(0.62, 0.12, 0.09), 0.05))
	_rect(img, B.T_TNT_SIDE, 0, 5, 16, 6, Color(0.92, 0.90, 0.86))
	var tnt := ["X X XX X X X", "  X  X XX  X", "  X  X X X X", "  X  X X  XX"]
	for r in tnt.size():
		var row: String = tnt[r]
		for i in row.length():
			if row[i] == "X":
				_px(img, B.T_TNT_SIDE, 2 + i, 6 + r, Color(0.10, 0.10, 0.10))
	_noise(img, B.T_TNT_TOP, Color(0.80, 0.18, 0.12), 0.08)
	_rect(img, B.T_TNT_TOP, 5, 5, 6, 6, Color(0.88, 0.86, 0.80))
	_rect(img, B.T_TNT_TOP, 7, 7, 2, 2, Color(0.15, 0.15, 0.15))
	_noise(img, B.T_TNT_BOTTOM, Color(0.75, 0.16, 0.11), 0.08)

	return img


static func _wool(img: Image, tile: int, c: Color) -> void:
	for y in T:
		for x in T:
			var f := 1.0 - 0.07 * float((x + y * 2) % 3)
			_px(img, tile, x, y, _vary(Color(c.r * f, c.g * f, c.b * f), 0.05))


# ---------------------------------------------------------------------------
static func _o(tile: int) -> Vector2i:
	return Vector2i((tile % N) * T, (tile / N) * T)


static func _px(img: Image, tile: int, x: int, y: int, c: Color) -> void:
	var o := _o(tile)
	img.set_pixel(o.x + x, o.y + y, c)


static func _getpx(img: Image, tile: int, x: int, y: int) -> Color:
	var o := _o(tile)
	return img.get_pixel(o.x + x, o.y + y)


static func _vary(c: Color, a: float) -> Color:
	var f := 1.0 + rng.randf_range(-a, a)
	return Color(clampf(c.r * f, 0.0, 1.0), clampf(c.g * f, 0.0, 1.0), clampf(c.b * f, 0.0, 1.0), c.a)


static func _noise(img: Image, tile: int, c: Color, a: float) -> void:
	for y in T:
		for x in T:
			_px(img, tile, x, y, _vary(c, a))


static func _specks(img: Image, tile: int, c: Color, n: int) -> void:
	for i in n:
		_px(img, tile, rng.randi_range(0, 15), rng.randi_range(0, 15), _vary(c, 0.05))


static func _copy(img: Image, src: int, dst: int) -> void:
	for y in T:
		for x in T:
			_px(img, dst, x, y, _getpx(img, src, x, y))


static func _rect(img: Image, tile: int, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and xx < T and yy >= 0 and yy < T:
				_px(img, tile, xx, yy, _vary(c, 0.04))


static func _border(img: Image, tile: int, c: Color) -> void:
	for i in T:
		_px(img, tile, i, 0, c)
		_px(img, tile, i, 15, c)
		_px(img, tile, 0, i, c)
		_px(img, tile, 15, i, c)


static func _metal(img: Image, tile: int, c: Color) -> void:
	_noise(img, tile, c, 0.03)
	_border(img, tile, c.darkened(0.25))
	for i in range(1, 15):
		_px(img, tile, i, 1, c.lightened(0.25))
		_px(img, tile, 1, i, c.lightened(0.25))


static func _ore(img: Image, tile: int, c: Color) -> void:
	_copy(img, B.T_STONE, tile)
	for k in 5:
		var cx := rng.randi_range(2, 13)
		var cy := rng.randi_range(2, 13)
		for j in 4:
			_px(img, tile, cx + rng.randi_range(-1, 1), cy + rng.randi_range(-1, 1), _vary(c, 0.12))


static func _cobble(img: Image, tile: int, base: Color) -> void:
	var pts: Array = []
	for i in 9:
		pts.append(Vector2(rng.randf() * 16.0, rng.randf() * 16.0))
	for y in T:
		for x in T:
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := 999.0
			var d2 := 999.0
			var idx := 0
			for k in pts.size():
				for ox in [-16.0, 0.0, 16.0]:
					for oy in [-16.0, 0.0, 16.0]:
						var q: Vector2 = pts[k] + Vector2(ox, oy)
						var d := p.distance_to(q)
						if d < d1:
							d2 = d1
							d1 = d
							idx = k
						elif d < d2:
							d2 = d
			var c := base.lightened(0.08 * float(idx % 3))
			if d2 - d1 < 1.2:
				c = base.darkened(0.45)
			_px(img, tile, x, y, _vary(c, 0.06))


static func _flower(img: Image, tile: int, petal: Color, center: Color) -> void:
	for y in range(8, 16):
		_px(img, tile, 8, y, Color(0.25, 0.55, 0.18))
	_px(img, tile, 7, 11, Color(0.30, 0.62, 0.20))
	_px(img, tile, 9, 12, Color(0.30, 0.62, 0.20))
	_px(img, tile, 10, 12, Color(0.30, 0.62, 0.20))
	for y in range(3, 10):
		for x in range(5, 12):
			if Vector2(x - 8, y - 6).length() <= 2.3:
				_px(img, tile, x, y, _vary(petal, 0.08))
	_px(img, tile, 8, 6, center)
