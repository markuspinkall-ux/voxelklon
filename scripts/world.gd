extends Node3D
## Unendliche Voxel-Welt in Chunks (16 x 80 x 16).
## Generiert Gelände (Ebenen, Gebirge mit Schneegipfeln, Seen/Meere), Höhlen,
## Erze, Bäume, Blumen und Villager-Dörfer.

const Blocks = preload("res://scripts/blocks.gd")
const ChunkScript = preload("res://scripts/chunk.gd")

signal village_ready(village: Dictionary)
signal chunk_built(c: Vector2i)

const CS := 16
const H := 80
const SECTIONS := 5
const SEA := 30
const VILLAGE_CELL := 112

var render_radius := 5

var world_seed := 0
var n_cont := FastNoiseLite.new()
var n_detail := FastNoiseLite.new()
var n_mount := FastNoiseLite.new()
var n_ridge := FastNoiseLite.new()
var n_forest := FastNoiseLite.new()
var n_cave1 := FastNoiseLite.new()
var n_cave2 := FastNoiseLite.new()

var chunk_data := {}    # Vector2i -> PackedByteArray
var chunk_maxy := {}    # Vector2i -> int
var chunk_nodes := {}   # Vector2i -> Chunk-Node
var villages := {}      # Vector2i (Dorf-Zelle) -> Dictionary oder null
var loot_chests := {}   # Vector3i -> true (Dorftruhen mit Beute)
var orient := {}        # Vector3i -> Flächenindex der Vorderseite (Ofen/Truhe)
var dirty := {}         # Vector3i(cx, section, cz) -> true
var load_queue: Array = []
var modified := {}      # Vector2i -> true (vom Spieler veränderte Chunks, werden gespeichert)
var saved_chunks := {}  # Vector2i -> [komprimierte Daten, maxy] aus einem Spielstand
var last_pc := Vector2i(999999, 999999)

var mat_opaque: StandardMaterial3D
var mat_cross: StandardMaterial3D
var mat_water: StandardMaterial3D


func setup(seed_value: int, atlas: Texture2D) -> void:
	world_seed = seed_value
	Blocks.setup()
	_noise(n_cont, 1, 0.0035, 4)
	_noise(n_detail, 2, 0.03, 3)
	_noise(n_mount, 3, 0.005, 2)
	_noise(n_ridge, 4, 0.012, 3)
	_noise(n_forest, 5, 0.01, 2)
	_noise(n_cave1, 6, 0.045, 1)
	_noise(n_cave2, 7, 0.045, 1)

	mat_opaque = StandardMaterial3D.new()
	mat_opaque.albedo_texture = atlas
	mat_opaque.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat_opaque.vertex_color_use_as_albedo = true
	mat_opaque.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat_opaque.alpha_scissor_threshold = 0.5
	mat_opaque.roughness = 1.0
	mat_opaque.metallic_specular = 0.0

	mat_cross = mat_opaque.duplicate()
	mat_cross.cull_mode = BaseMaterial3D.CULL_DISABLED

	mat_water = StandardMaterial3D.new()
	mat_water.albedo_texture = atlas
	mat_water.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat_water.vertex_color_use_as_albedo = true
	mat_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_water.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_water.roughness = 0.15
	mat_water.metallic_specular = 0.6


func _noise(n: FastNoiseLite, salt: int, freq: float, octaves: int) -> void:
	n.seed = world_seed + salt * 1013
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	if octaves > 1:
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = octaves
	else:
		n.fractal_type = FastNoiseLite.FRACTAL_NONE


func _hash2(x: int, z: int, salt: int) -> float:
	var h: int = (x * 73856093) ^ (z * 19349663) ^ ((world_seed + salt * 83492791) * 2654435761)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777216.0


# ---------------------------------------------------------------------------
# Gelände
func get_height(x: int, z: int) -> int:
	var c := n_cont.get_noise_2d(x, z)
	var d := n_detail.get_noise_2d(x, z)
	var m := n_mount.get_noise_2d(x, z)
	var h := 33.0 + c * 16.0 + d * 3.0
	var mask := clampf((m - 0.08) / 0.4, 0.0, 1.0)
	if mask > 0.0:
		var r := 1.0 - absf(n_ridge.get_noise_2d(x, z))
		h += mask * mask * r * r * 55.0 + mask * 4.0
	return clampi(int(h), 3, H - 12)


## Gibt (Oberflächenblock, Block darunter) zurück
func _surface(h: int, x: int, z: int) -> Vector2i:
	if h < SEA - 3:
		if n_detail.get_noise_2d(x * 3, z * 3) > 0.0:
			return Vector2i(Blocks.GRAVEL, Blocks.GRAVEL)
		return Vector2i(Blocks.SAND, Blocks.SAND)
	if h <= SEA + 1:
		return Vector2i(Blocks.SAND, Blocks.SAND)
	var snow_line := 58 + int(n_detail.get_noise_2d(x, z) * 6.0)
	if h >= snow_line:
		return Vector2i(Blocks.SNOW, Blocks.STONE)
	if h >= snow_line - 2:
		return Vector2i(Blocks.SNOWY_GRASS, Blocks.DIRT)
	if h >= snow_line - 9:
		return Vector2i(Blocks.STONE, Blocks.STONE)
	return Vector2i(Blocks.GRASS, Blocks.DIRT)


func generate_chunk_data(c: Vector2i) -> void:
	if saved_chunks.has(c):
		var e: Array = saved_chunks[c]
		var raw: PackedByteArray = e[0]
		chunk_data[c] = raw.decompress(CS * CS * H, FileAccess.COMPRESSION_ZSTD)
		chunk_maxy[c] = int(e[1])
		modified[c] = true
		return
	var data := PackedByteArray()
	data.resize(CS * CS * H)
	data.fill(0)
	var x0 := c.x * CS
	var z0 := c.y * CS
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(c.x, c.y, world_seed))
	var maxy := SEA
	var heights := PackedInt32Array()
	heights.resize(CS * CS)

	for lz in CS:
		for lx in CS:
			var wx := x0 + lx
			var wz := z0 + lz
			var h := get_height(wx, wz)
			heights[lx + lz * CS] = h
			if h > maxy:
				maxy = h
			var surf := _surface(h, wx, wz)
			var base := lx + lz * CS
			for y in range(0, h + 1):
				var id := Blocks.STONE
				if y == 0 or (y <= 2 and rng.randf() < 0.5):
					id = Blocks.BEDROCK
				elif y == h:
					id = surf.x
				elif y >= h - 3:
					id = surf.y
				else:
					var r := rng.randf()
					if r < 0.012 and y < 70:
						id = Blocks.COAL_ORE
					elif r < 0.019 and y < 48:
						id = Blocks.IRON_ORE
					elif r < 0.0215 and y < 16:
						id = Blocks.DIAMOND_ORE
				# Höhlen (Spaghetti-Tunnel)
				if y > 4 and y < h - 5 and id != Blocks.BEDROCK:
					if absf(n_cave1.get_noise_3d(wx, y * 1.6, wz)) < 0.075 and absf(n_cave2.get_noise_3d(wx, y * 1.6, wz)) < 0.075:
						id = Blocks.AIR
				data[base + y * 256] = id
			# Wasser bis zum Meeresspiegel
			for y in range(h + 1, SEA + 1):
				data[base + y * 256] = Blocks.WATER

	# Bäume (auch aus Nachbar-Chunks hineinragend)
	for tz in range(z0 - 2, z0 + CS + 2):
		for tx in range(x0 - 2, x0 + CS + 2):
			var forest := n_forest.get_noise_2d(tx, tz)
			var chance := 0.03 if forest > 0.15 else 0.004
			if _hash2(tx, tz, 11) >= chance:
				continue
			var th := get_height(tx, tz)
			if th <= SEA + 1:
				continue
			if _surface(th, tx, tz).x != Blocks.GRASS:
				continue
			if _in_village(tx, tz):
				continue
			var trunk := 4 + int(_hash2(tx, tz, 12) * 3.0)
			data = _tree(data, x0, z0, tx, th + 1, tz, trunk)

	# Pflanzen
	for lz in CS:
		for lx in CS:
			var h: int = heights[lx + lz * CS]
			if h + 1 >= H:
				continue
			var base := lx + lz * CS
			if data[base + h * 256] != Blocks.GRASS or data[base + (h + 1) * 256] != Blocks.AIR:
				continue
			var r := _hash2(x0 + lx, z0 + lz, 21)
			if r < 0.06:
				data[base + (h + 1) * 256] = Blocks.SHORT_GRASS
			elif r < 0.07:
				data[base + (h + 1) * 256] = Blocks.POPPY
			elif r < 0.08:
				data[base + (h + 1) * 256] = Blocks.DANDELION

	# Dörfer
	var gx0 := floori(float(x0) / VILLAGE_CELL)
	var gx1 := floori(float(x0 + CS - 1) / VILLAGE_CELL)
	var gz0 := floori(float(z0) / VILLAGE_CELL)
	var gz1 := floori(float(z0 + CS - 1) / VILLAGE_CELL)
	for gz in range(gz0, gz1 + 1):
		for gx in range(gx0, gx1 + 1):
			var v = village_at_cell(Vector2i(gx, gz))
			if v != null:
				data = _apply_village(data, v, x0, z0)

	chunk_data[c] = data
	chunk_maxy[c] = mini(H - 1, maxy + 12)


func _setl(data: PackedByteArray, x0: int, z0: int, wx: int, wy: int, wz: int, id: int, only_air: bool) -> PackedByteArray:
	var lx := wx - x0
	var lz := wz - z0
	if lx < 0 or lx >= CS or lz < 0 or lz >= CS or wy < 1 or wy >= H:
		return data
	var i := lx + lz * CS + wy * 256
	if only_air and data[i] != Blocks.AIR:
		return data
	data[i] = id
	return data


func _tree(data: PackedByteArray, x0: int, z0: int, tx: int, ty: int, tz: int, trunk: int) -> PackedByteArray:
	for dy in range(trunk - 3, trunk + 1):
		var r := 2 if dy < trunk - 1 else 1
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) == r and absi(dz) == r:
					if dy == trunk or _hash2(tx + dx, tz + dz + dy * 7, 13) < 0.5:
						continue
				data = _setl(data, x0, z0, tx + dx, ty + dy, tz + dz, Blocks.OAK_LEAVES, true)
	for dy in trunk:
		data = _setl(data, x0, z0, tx, ty + dy, tz, Blocks.OAK_LOG, false)
	data = _setl(data, x0, z0, tx, ty - 1, tz, Blocks.DIRT, false)
	return data


# ---------------------------------------------------------------------------
# Dörfer
func village_at_cell(g: Vector2i):
	if villages.has(g):
		return villages[g]
	var v = null
	if _hash2(g.x, g.y, 77) < 0.5:
		var cx := g.x * VILLAGE_CELL + 30 + int(_hash2(g.x, g.y, 78) * (VILLAGE_CELL - 60))
		var cz := g.y * VILLAGE_CELL + 30 + int(_hash2(g.x, g.y, 79) * (VILLAGE_CELL - 60))
		if _village_site_ok(cx, cz):
			v = _build_village(cx, cz)
	villages[g] = v
	return v


func _in_village(x: int, z: int) -> bool:
	var g := Vector2i(floori(float(x) / VILLAGE_CELL), floori(float(z) / VILLAGE_CELL))
	var v = village_at_cell(g)
	if v == null:
		return false
	var c: Vector3i = v["center"]
	return Vector2(x - c.x, z - c.z).length() < 28.0


func _village_site_ok(cx: int, cz: int) -> bool:
	var h0 := get_height(cx, cz)
	if _surface(h0, cx, cz).x != Blocks.GRASS:
		return false
	var lo := h0
	var hi := h0
	for k in 8:
		var a := TAU * k / 8.0
		var h := get_height(cx + int(cos(a) * 18.0), cz + int(sin(a) * 18.0))
		lo = mini(lo, h)
		hi = maxi(hi, h)
	return lo > SEA + 1 and hi < 52 and hi - lo <= 7


func _vb(pos: Array, ids: Array, x: int, y: int, z: int, id: int) -> void:
	if y < 1 or y >= H:
		return
	pos.append(Vector3i(x, y, z))
	ids.append(id)


func _build_village(cx: int, cz: int) -> Dictionary:
	var pos: Array = []
	var ids: Array = []
	var chests: Array = []
	var spawns: Array = []
	var cy := get_height(cx, cz)
	var n := 4 + int(_hash2(cx, cz, 31) * 3.0)
	var base_a := _hash2(cx, cz, 32) * TAU
	var houses: Array = []
	for i in n:
		var a := base_a + TAU * float(i) / float(n) + (_hash2(cx + i, cz, 33) - 0.5) * 0.4
		var dist := 14.0 + _hash2(cx, cz + i, 34) * 4.0
		houses.append(Vector2i(cx + roundi(cos(a) * dist), cz + roundi(sin(a) * dist)))
	for hp in houses:
		_vpath(pos, ids, cx, cz, hp.x, hp.y)
	_vwell(pos, ids, cx, cy, cz)
	for hp in houses:
		_vhouse(pos, ids, chests, spawns, hp.x, hp.y, cx, cz)
	for ch in chests:
		loot_chests[ch] = true
	return {
		"center": Vector3i(cx, cy, cz), "pos": pos, "ids": ids, "spawns": spawns,
		"spawned": false, "min": Vector2i(cx - 26, cz - 26), "max": Vector2i(cx + 26, cz + 26),
	}


func _vpath(pos: Array, ids: Array, x0: int, z0: int, x1: int, z1: int) -> void:
	var steps := maxi(absi(x1 - x0), absi(z1 - z0))
	if steps == 0:
		return
	var along_z := absi(z1 - z0) > absi(x1 - x0)
	for s in range(2, steps + 1):
		var t := float(s) / float(steps)
		var px := roundi(lerpf(x0, x1, t))
		var pz := roundi(lerpf(z0, z1, t))
		for o in 2:
			var qx := px + (o if along_z else 0)
			var qz := pz + (0 if along_z else o)
			var gy := get_height(qx, qz)
			if gy <= SEA:
				continue
			_vb(pos, ids, qx, gy, qz, Blocks.DIRT_PATH)
			_vb(pos, ids, qx, gy + 1, qz, Blocks.AIR)
			_vb(pos, ids, qx, gy + 2, qz, Blocks.AIR)


func _vwell(pos: Array, ids: Array, cx: int, cy: int, cz: int) -> void:
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var x := cx + dx
			var z := cz + dz
			var th := get_height(x, z)
			for y in range(th + 1, cy):
				_vb(pos, ids, x, y, z, Blocks.DIRT)
			for y in range(cy + 1, cy + 7):
				_vb(pos, ids, x, y, z, Blocks.AIR)
			if absi(dx) == 2 or absi(dz) == 2:
				_vb(pos, ids, x, cy, z, Blocks.DIRT_PATH)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var x := cx + dx
			var z := cz + dz
			var center := dx == 0 and dz == 0
			for y in range(cy - 3, cy + 1):
				_vb(pos, ids, x, y, z, Blocks.WATER if (center and y > cy - 3) else Blocks.COBBLESTONE)
			if not center:
				_vb(pos, ids, x, cy + 1, z, Blocks.COBBLESTONE)
			if absi(dx) == 1 and absi(dz) == 1:
				_vb(pos, ids, x, cy + 2, z, Blocks.OAK_LOG)
				_vb(pos, ids, x, cy + 3, z, Blocks.OAK_LOG)
			_vb(pos, ids, x, cy + 4, z, Blocks.OAK_PLANKS)
	_vb(pos, ids, cx, cy + 5, cz, Blocks.TORCH)


func _vhouse(pos: Array, ids: Array, chests: Array, spawns: Array, hx: int, hz: int, cx: int, cz: int) -> void:
	var y0 := get_height(hx, hz)
	if y0 <= SEA:
		y0 = SEA + 1
	var ddx := cx - hx
	var ddz := cz - hz
	var door := Vector2i(0, 3 * signi(ddz))
	if absi(ddx) > absi(ddz):
		door = Vector2i(3 * signi(ddx), 0)
	if door == Vector2i.ZERO:
		door = Vector2i(0, 3)
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			var x := hx + dx
			var z := hz + dz
			for y in range(y0 + 1, y0 + 10):
				_vb(pos, ids, x, y, z, Blocks.AIR)
			if absi(dx) <= 3 and absi(dz) <= 3:
				var th := get_height(x, z)
				for y in range(th + 1, y0):
					_vb(pos, ids, x, y, z, Blocks.COBBLESTONE)
				var border := absi(dx) == 3 or absi(dz) == 3
				_vb(pos, ids, x, y0, z, Blocks.COBBLESTONE if border else Blocks.OAK_PLANKS)
				if border:
					var corner := absi(dx) == 3 and absi(dz) == 3
					for y in range(y0 + 1, y0 + 4):
						var id := Blocks.OAK_LOG if corner else Blocks.OAK_PLANKS
						if not corner and y == y0 + 2 and (dx == 0 or dz == 0):
							id = Blocks.GLASS
						_vb(pos, ids, x, y, z, id)
	# Dach (Pyramide mit Überstand)
	for layer in 5:
		var r := 4 - layer
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if layer > 0 and absi(dx) != r and absi(dz) != r:
					continue
				var id := Blocks.OAK_PLANKS
				if r == 0:
					id = Blocks.OAK_LOG
				elif layer == 0 and (absi(dx) == 4 or absi(dz) == 4):
					id = Blocks.COBBLESTONE
				_vb(pos, ids, hx + dx, y0 + 4 + layer, hz + dz, id)
	# Tür (2 hoch)
	_vb(pos, ids, hx + door.x, y0 + 1, hz + door.y, Blocks.AIR)
	_vb(pos, ids, hx + door.x, y0 + 2, hz + door.y, Blocks.AIR)
	# Einrichtung
	_vb(pos, ids, hx - 2, y0 + 1, hz - 2, Blocks.CRAFTING_TABLE)
	_vb(pos, ids, hx + 2, y0 + 1, hz - 2, Blocks.CHEST)
	_vb(pos, ids, hx - 2, y0 + 1, hz + 2, Blocks.TORCH)
	chests.append(Vector3i(hx + 2, y0 + 1, hz - 2))
	spawns.append(Vector3(hx + 0.5, y0 + 1.05, hz + 0.5))


func _apply_village(data: PackedByteArray, v: Dictionary, x0: int, z0: int) -> PackedByteArray:
	var vmin: Vector2i = v["min"]
	var vmax: Vector2i = v["max"]
	if vmax.x < x0 or vmin.x >= x0 + CS or vmax.y < z0 or vmin.y >= z0 + CS:
		return data
	var pos: Array = v["pos"]
	var ids: Array = v["ids"]
	for i in pos.size():
		var p: Vector3i = pos[i]
		var lx := p.x - x0
		var lz := p.z - z0
		if lx < 0 or lx >= CS or lz < 0 or lz >= CS:
			continue
		data[lx + lz * CS + p.y * 256] = ids[i]
	return data


func _check_village_spawn(c: Vector2i) -> void:
	var gx := floori(float(c.x * CS) / VILLAGE_CELL)
	var gz := floori(float(c.y * CS) / VILLAGE_CELL)
	var v = village_at_cell(Vector2i(gx, gz))
	if v == null or v["spawned"]:
		return
	var center: Vector3i = v["center"]
	if Vector2i(center.x >> 4, center.z >> 4) == c:
		v["spawned"] = true
		village_ready.emit(v)


# ---------------------------------------------------------------------------
# Blockzugriff
func get_block(x: int, y: int, z: int) -> int:
	if y < 0 or y >= H:
		return Blocks.AIR
	var d = chunk_data.get(Vector2i(x >> 4, z >> 4))
	if d == null:
		return Blocks.AIR
	return d[(x & 15) + (z & 15) * CS + y * 256]


func get_block_v(p: Vector3) -> int:
	return get_block(floori(p.x), floori(p.y), floori(p.z))


func set_block(x: int, y: int, z: int, id: int) -> void:
	if y < 0 or y >= H:
		return
	var c := Vector2i(x >> 4, z >> 4)
	if not chunk_data.has(c):
		return
	var d: PackedByteArray = chunk_data[c]
	var lx := x & 15
	var lz := z & 15
	d[lx + lz * CS + y * 256] = id
	chunk_data[c] = d
	modified[c] = true
	if y + 1 > int(chunk_maxy[c]):
		chunk_maxy[c] = mini(H - 1, y + 1)
	if id != Blocks.FURNACE and id != Blocks.CHEST:
		orient.erase(Vector3i(x, y, z))
	var sy := y >> 4
	_mark(c, sy)
	if lx == 0:
		_mark(c + Vector2i(-1, 0), sy)
	if lx == 15:
		_mark(c + Vector2i(1, 0), sy)
	if lz == 0:
		_mark(c + Vector2i(0, -1), sy)
	if lz == 15:
		_mark(c + Vector2i(0, 1), sy)
	if (y & 15) == 0 and sy > 0:
		_mark(c, sy - 1)
	if (y & 15) == 15 and sy < SECTIONS - 1:
		_mark(c, sy + 1)


func _mark(c: Vector2i, sy: int) -> void:
	dirty[Vector3i(c.x, sy, c.y)] = true


## Einfache Wasserphysik: Ein Loch neben Wasser läuft voll, Wasser fällt nach unten.
func fill_water_if_adjacent(x: int, y: int, z: int) -> void:
	if get_block(x, y, z) != Blocks.AIR:
		return
	for o in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, 1, 0)]:
		if get_block(x + o.x, y + o.y, z + o.z) == Blocks.WATER:
			set_block(x, y, z, Blocks.WATER)
			water_fall(x, y, z)
			return


func water_fall(x: int, y: int, z: int) -> void:
	var yy := y - 1
	var n := 0
	while yy > 0 and n < 24:
		var b := get_block(x, yy, z)
		if b != Blocks.AIR and Blocks.kind[b] != Blocks.CROSS:
			break
		set_block(x, yy, z, Blocks.WATER)
		yy -= 1
		n += 1


## Voxel-Raycast (DDA). Liefert {"hit", "pos": Vector3i, "normal": Vector3i, "dist"}
func raycast(origin: Vector3, dir: Vector3, max_dist: float, include_water := false) -> Dictionary:
	dir = dir.normalized()
	var x := floori(origin.x)
	var y := floori(origin.y)
	var z := floori(origin.z)
	var sx := 1 if dir.x > 0.0 else -1
	var sy := 1 if dir.y > 0.0 else -1
	var sz := 1 if dir.z > 0.0 else -1
	var tdx := INF
	var tdy := INF
	var tdz := INF
	var tmx := INF
	var tmy := INF
	var tmz := INF
	if dir.x != 0.0:
		tdx = absf(1.0 / dir.x)
		tmx = ((x + 1 - origin.x) if dir.x > 0.0 else (origin.x - x)) * tdx
	if dir.y != 0.0:
		tdy = absf(1.0 / dir.y)
		tmy = ((y + 1 - origin.y) if dir.y > 0.0 else (origin.y - y)) * tdy
	if dir.z != 0.0:
		tdz = absf(1.0 / dir.z)
		tmz = ((z + 1 - origin.z) if dir.z > 0.0 else (origin.z - z)) * tdz
	var n := Vector3i.ZERO
	var t := 0.0
	for i in 64:
		var id := get_block(x, y, z)
		if id != Blocks.AIR and (id != Blocks.WATER or include_water):
			return {"hit": true, "pos": Vector3i(x, y, z), "normal": n, "dist": t}
		if tmx < tmy and tmx < tmz:
			x += sx
			t = tmx
			tmx += tdx
			n = Vector3i(-sx, 0, 0)
		elif tmy < tmz:
			y += sy
			t = tmy
			tmy += tdy
			n = Vector3i(0, -sy, 0)
		else:
			z += sz
			t = tmz
			tmz += tdz
			n = Vector3i(0, 0, -sz)
		if t > max_dist:
			break
	return {"hit": false}


## Höchster fester Block (oder Wasser) einer Säule: Vector2i(y, id), y = -1 wenn unbekannt
func surface(x: int, z: int) -> Vector2i:
	var c := Vector2i(x >> 4, z >> 4)
	if not chunk_data.has(c):
		return Vector2i(-1, 0)
	var top: int = chunk_maxy[c]
	for y in range(top, 0, -1):
		var b := get_block(x, y, z)
		if b != Blocks.AIR and Blocks.kind[b] != Blocks.CROSS:
			return Vector2i(y, b)
	return Vector2i(-1, 0)


func sky_exposed(p: Vector3) -> bool:
	var x := floori(p.x)
	var z := floori(p.z)
	var c := Vector2i(x >> 4, z >> 4)
	if not chunk_data.has(c):
		return false
	var top: int = chunk_maxy[c]
	for y in range(maxi(floori(p.y), 0), top + 1):
		if Blocks.solid[get_block(x, y, z)] == 1:
			return false
	return true


func is_chunk_ready(p: Vector3) -> bool:
	return chunk_nodes.has(Vector2i(floori(p.x) >> 4, floori(p.z) >> 4))


# ---------------------------------------------------------------------------
# Laden / Entladen
func generate_around(center: Vector3, r: int) -> void:
	var pc := Vector2i(floori(center.x) >> 4, floori(center.z) >> 4)
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := pc + Vector2i(dx, dz)
			if not chunk_nodes.has(c):
				_build_chunk(c)


func update(center: Vector3) -> void:
	# 1) Geänderte Abschnitte neu bauen
	if dirty.size() > 0:
		var keys := dirty.keys()
		dirty.clear()
		for k in keys:
			var cc := Vector2i(k.x, k.z)
			if chunk_nodes.has(cc):
				chunk_nodes[cc].build_section(k.y)
	# 2) Ladeliste aktualisieren
	var pc := Vector2i(floori(center.x) >> 4, floori(center.z) >> 4)
	if pc != last_pc:
		last_pc = pc
		_rebuild_queue(pc)
		_unload_far(pc)
	# 3) Mit Zeitbudget neue Chunks bauen
	var start := Time.get_ticks_usec()
	while load_queue.size() > 0 and Time.get_ticks_usec() - start < 7000:
		var c: Vector2i = load_queue.pop_front()
		if not chunk_nodes.has(c):
			_build_chunk(c)


func _rebuild_queue(pc: Vector2i) -> void:
	load_queue.clear()
	var r := render_radius
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz > r * r + r:
				continue
			var c := pc + Vector2i(dx, dz)
			if not chunk_nodes.has(c):
				load_queue.append(c)
	load_queue.sort_custom(func(a, b): return (a - pc).length_squared() < (b - pc).length_squared())


func _unload_far(pc: Vector2i) -> void:
	for c in chunk_nodes.keys():
		var d: Vector2i = c - pc
		if maxi(absi(d.x), absi(d.y)) > render_radius + 2:
			chunk_nodes[c].queue_free()
			chunk_nodes.erase(c)


func _build_chunk(c: Vector2i) -> void:
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nb: Vector2i = c + o
		if not chunk_data.has(nb):
			generate_chunk_data(nb)
	var node := ChunkScript.new()
	node.world = self
	node.cpos = c
	node.position = Vector3(c.x * CS, 0, c.y * CS)
	add_child(node)
	node.build_all()
	chunk_nodes[c] = node
	_check_village_spawn(c)
	chunk_built.emit(c)


## Für den Spielstand: alle veränderten Chunks komprimiert (inkl. früher geladener)
func export_modified() -> Dictionary:
	var out := {}
	for c in saved_chunks:
		out[c] = saved_chunks[c]
	for c in modified:
		if chunk_data.has(c):
			var d: PackedByteArray = chunk_data[c]
			out[c] = [d.compress(FileAccess.COMPRESSION_ZSTD), chunk_maxy[c]]
	return out
