extends Node3D
## Hauptszene: baut Welt, Himmel, Tag/Nacht-Zyklus, Spieler und UI auf,
## spawnt Monster in der Nacht und Villager in Dörfern, verwaltet Truhen & Öfen.

const Blocks = preload("res://scripts/blocks.gd")
const Items = preload("res://scripts/items.gd")
const Recipes = preload("res://scripts/recipes.gd")
const TextureGen = preload("res://scripts/texture_gen.gd")
const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const UIScript = preload("res://scripts/ui.gd")
const MobScript = preload("res://scripts/mob.gd")
const MenuScript = preload("res://scripts/menu.gd")
const BlockMesh = preload("res://scripts/block_mesh.gd")

const DAY_LENGTH := 600.0   # Sekunden für einen ganzen Tag (wie Minecraft: 20 min -> hier 10 min)
const MAX_HOSTILE := 10

var world
var player
var ui
var mobs_root: Node3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var time_of_day := 0.03
var day := 1
var daylight := 1.0
var chests := {}     # Vector3i -> Array(27)
var furnaces := {}   # Vector3i -> Dictionary
var spawn_t := 3.0
var sky_t := 0.0
var was_night := false
var world_seed := 0


var atlas_img: Image
var menu
var save_title := "Neue Welt"
var save_folder := ""
var tnts: Array = []
var animal_chunks := {}
const AUTOSAVE_EVERY := 180.0
var autosave_t := AUTOSAVE_EVERY


func _ready() -> void:
	set_process(false)
	get_tree().auto_accept_quit = false
	_setup_input()
	randomize()
	atlas_img = TextureGen.build()
	Items.setup(atlas_img)
	Recipes.setup()
	# Für automatische Tests: godot --headless --path . -- --autostart
	if "--autostart" in OS.get_cmdline_user_args():
		_start_game(12345, 3, "Testwelt", "", null)
		return
	menu = MenuScript.new()
	menu.atlas = atlas_img
	add_child(menu)
	menu.start_requested.connect(func(sv: int, r: int, title: String): _start_game(sv, r, title, "", null))
	menu.load_requested.connect(func(folder: String, data: Dictionary, r: int): _start_game(int(data["seed"]), r, str(data["name"]), folder, data))


func _start_game(seed_value: int, radius: int, title: String, folder: String, data) -> void:
	world_seed = seed_value
	save_title = title
	save_folder = folder if folder != "" else _new_folder_name(title)
	if menu != null:
		menu.show_loading()
		# zwei Frames warten, damit der Ladehinweis angezeigt wird
		await get_tree().process_frame
		await get_tree().process_frame
	_setup_environment()

	world = WorldScript.new()
	world.render_radius = radius
	add_child(world)
	world.setup(world_seed, ImageTexture.create_from_image(atlas_img))
	world.village_ready.connect(_on_village_ready)
	world.chunk_built.connect(_on_chunk_built)

	mobs_root = Node3D.new()
	mobs_root.name = "Mobs"
	add_child(mobs_root)

	player = PlayerScript.new()
	player.world = world
	player.main = self
	ui = UIScript.new()
	ui.player = player
	ui.main = self
	player.ui = ui

	var pitch := 0.0
	if data != null:
		# --- Spielstand laden ---
		world.saved_chunks = data["chunks"]
		world.orient = data["orient"]
		chests = data["chests"]
		furnaces = data["furnaces"]
		time_of_day = float(data["time"])
		day = int(data["day"])
		var pd: Dictionary = data["player"]
		var inv: Array = pd["inv"]
		for i in mini(inv.size(), player.inventory.slots.size()):
			player.inventory.slots[i] = inv[i]
		player.selected = int(pd["selected"])
		player.health = float(pd["health"])
		player.air = float(pd["air"])
		player.spawn_point = pd["spawn"]
		player.rotation.y = float(pd["rot_y"])
		pitch = float(pd["pitch"])
		var pos: Vector3 = pd["pos"]
		world.generate_around(pos, 2)
		player.position = pos
	else:
		var sp := _find_spawn()
		world.generate_around(Vector3(sp.x, 0, sp.y), 2)
		var s: Vector2i = world.surface(sp.x, sp.y)
		player.position = Vector3(sp.x + 0.5, s.x + 1.05, sp.y + 0.5)
		player.spawn_point = player.position
	add_child(player)
	player.head.rotation.x = pitch
	add_child(ui)
	if menu != null:
		menu.queue_free()
		menu = null
	set_process(true)
	if data != null:
		ui.message("Welt „%s“ geladen – Tag %d" % [save_title, day])
	else:
		ui.message("Willkommen in Creative Craft! Schlag einen Baum (Linksklick halten) – E: Inventar, Esc: Menü")
	print("Creative Craft gestartet (Seed %d, %d Chunks geladen)" % [world_seed, world.chunk_nodes.size()])
	if "--savetest" in OS.get_cmdline_user_args():
		_run_save_test()


func _run_save_test() -> void:
	# Automatischer Test: Block setzen, Truhe füllen, speichern, wieder einlesen
	var p := Vector3i(floori(player.position.x), floori(player.position.y) + 3, floori(player.position.z))
	world.set_block(p.x, p.y, p.z, Blocks.TNT)
	player.inventory.add_item("shears", 1)
	get_chest(p + Vector3i(1, 0, 0))[0] = Items.make_stack("white_wool", 5)
	save_folder = "ci-savetest"
	var ok := save_game()
	var f := FileAccess.open(SAVE_ROOT + "/" + save_folder + "/world.dat", FileAccess.READ)
	var data = f.get_var(false) if f != null else null
	if ok and data is Dictionary and (data["chunks"] as Dictionary).size() > 0 and data["chests"].has(p + Vector3i(1, 0, 0)):
		var c: Vector2i = Vector2i(p.x >> 4, p.z >> 4)
		var e: Array = data["chunks"][c]
		var raw: PackedByteArray = (e[0] as PackedByteArray).decompress(16 * 16 * 80, FileAccess.COMPRESSION_ZSTD)
		var idx := (p.x & 15) + (p.z & 15) * 16 + p.y * 256
		if raw[idx] == Blocks.TNT:
			print("Speichertest OK")
			return
	push_error("Speichertest fehlgeschlagen")


func back_to_menu() -> void:
	save_game()
	get_tree().paused = false
	get_tree().reload_current_scene()


func quit_game() -> void:
	save_game()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()


# ---------------------------------------------------------------------------
# Speichern
const SAVE_ROOT := "user://saves"


func _new_folder_name(title: String) -> String:
	var base := ""
	for ch in title.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			base += ch
		elif base != "" and not base.ends_with("-"):
			base += "-"
	base = base.trim_suffix("-")
	if base == "":
		base = "welt"
	var fname := base
	var n := 2
	while DirAccess.dir_exists_absolute(SAVE_ROOT + "/" + fname):
		fname = "%s-%d" % [base, n]
		n += 1
	return fname


func save_game() -> bool:
	if world == null or player == null:
		return false
	if "--autostart" in OS.get_cmdline_user_args() and not "--savetest" in OS.get_cmdline_user_args():
		return false
	var dir := SAVE_ROOT + "/" + save_folder
	DirAccess.make_dir_recursive_absolute(dir)
	var alive: bool = not player.dead
	var data := {
		"version": 1,
		"name": save_title,
		"seed": world_seed,
		"time": time_of_day,
		"day": day,
		"player": {
			"pos": player.global_position if alive else player.spawn_point,
			"rot_y": player.rotation.y,
			"pitch": player.head.rotation.x,
			"health": player.health if alive else player.max_health,
			"air": player.max_air,
			"spawn": player.spawn_point,
			"inv": player.inventory.slots,
			"selected": player.selected,
		},
		"chests": chests,
		"furnaces": furnaces,
		"orient": world.orient,
		"chunks": world.export_modified(),
	}
	var f := FileAccess.open(dir + "/world.dat", FileAccess.WRITE)
	if f == null:
		push_error("Speichern fehlgeschlagen: %s" % dir)
		return false
	f.store_var(data, false)
	f.close()
	var cfg := ConfigFile.new()
	cfg.set_value("save", "name", save_title)
	cfg.set_value("save", "seed", world_seed)
	cfg.set_value("save", "day", day)
	cfg.set_value("save", "time", Time.get_datetime_string_from_system(false, true))
	cfg.set_value("save", "unix", Time.get_unix_time_from_system())
	cfg.save(dir + "/meta.cfg")
	autosave_t = AUTOSAVE_EVERY
	return true


# ---------------------------------------------------------------------------
# Schlafen & TNT
func try_sleep(p: Vector3i) -> void:
	player.spawn_point = Vector3(p.x + 0.5, p.y + 1.1, p.z + 0.5)
	if daylight >= 0.25:
		ui.message("Wiedereinstiegspunkt gesetzt. Schlafen kannst du nur nachts.")
		return
	for m in mobs_root.get_children():
		if m.hostile and not m.dead and m.global_position.distance_to(Vector3(p) + Vector3(0.5, 0.5, 0.5)) < 8.0:
			ui.message("Du kannst jetzt nicht schlafen – Monster in der Nähe!")
			return
	ui.sleep_fade()
	time_of_day = 0.0
	day += 1
	was_night = false
	ui.message("Guten Morgen! Wiedereinstiegspunkt gesetzt.")


func prime_tnt(p: Vector3i, fuse: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(p) + Vector3(0.5, 0.5, 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = BlockMesh.build(Blocks.TNT, 1.0, world.mat_opaque)
	root.add_child(mi)
	var flash := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.02, 1.02, 1.02)
	flash.mesh = bm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(1, 1, 1, 0.55)
	flash.material_override = fm
	root.add_child(flash)
	add_child(root)
	tnts.append({"node": root, "flash": flash, "t": fuse})


func _tick_tnt(delta: float) -> void:
	for i in range(tnts.size() - 1, -1, -1):
		var e: Dictionary = tnts[i]
		e["t"] = float(e["t"]) - delta
		var node: Node3D = e["node"]
		var flash: MeshInstance3D = e["flash"]
		flash.visible = fmod(float(e["t"]), 0.5) < 0.25
		node.scale = Vector3.ONE * (1.0 + maxf(0.0, 0.6 - float(e["t"])) * 0.25)
		if float(e["t"]) <= 0.0:
			var c := node.position
			node.queue_free()
			tnts.remove_at(i)
			explode(c, 4.0)


# ---------------------------------------------------------------------------
# Schafe
func _on_chunk_built(c: Vector2i) -> void:
	if animal_chunks.has(c):
		return
	animal_chunks[c] = true
	if world._hash2(c.x, c.y, 91) > 0.14:
		return
	var sheep := 0
	for m in mobs_root.get_children():
		if m.kind == "sheep":
			sheep += 1
	if sheep >= 40:
		return
	var n := 2 + int(world._hash2(c.x, c.y, 92) * 3.0)
	for i in n:
		var x := c.x * 16 + 2 + int(world._hash2(c.x + i, c.y, 93) * 12.0)
		var z := c.y * 16 + 2 + int(world._hash2(c.x, c.y + i, 94) * 12.0)
		var s: Vector2i = world.surface(x, z)
		if s.x > 0 and s.y == Blocks.GRASS:
			spawn_mob("sheep", Vector3(x + 0.5, s.x + 1.05, z + 0.5))


func _setup_input() -> void:
	var map := {
		"forward": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN],
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "sprint": [KEY_CTRL, KEY_SHIFT],
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func _setup_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_sky_affect = 0.0
	env.fog_depth_curve = 1.0
	env.fog_depth_begin = 45.0
	env.fog_depth_end = 80.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.shadow_enabled = false
	add_child(moon)


func _find_spawn() -> Vector2i:
	# Möglichst neben einem Dorf starten, damit man es gleich sieht
	var best = null
	var best_d := 1e9
	for gz in range(-3, 4):
		for gx in range(-3, 4):
			var v = world.village_at_cell(Vector2i(gx, gz))
			if v != null:
				var c: Vector3i = v["center"]
				var d := Vector2(c.x, c.z).length()
				if d < best_d:
					best_d = d
					best = c
	if best != null:
		return Vector2i(best.x + 4, best.z + 1)
	for r in range(0, 400, 4):
		for k in 8:
			var a := k * TAU / 8.0
			var x := int(cos(a) * r)
			var z := int(sin(a) * r)
			var h: int = world.get_height(x, z)
			if h > WorldScript.SEA + 1 and h < 50:
				return Vector2i(x, z)
	return Vector2i.ZERO


func _process(delta: float) -> void:
	time_of_day += delta / DAY_LENGTH
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
	_update_sky(delta)
	world.update(player.global_position)
	_tick_furnaces(delta)
	_spawn_tick(delta)
	_tick_tnt(delta)
	autosave_t -= delta
	if autosave_t <= 0.0:
		if save_game():
			ui.message("Welt automatisch gespeichert")
		autosave_t = AUTOSAVE_EVERY


# ---------------------------------------------------------------------------
# Himmel & Tag/Nacht
func _update_sky(delta: float) -> void:
	var t := time_of_day
	var sn := sin(t * TAU)
	daylight = clampf(0.5 + sn * 1.5, 0.0, 1.0)
	sun.rotation = Vector3(-t * TAU, deg_to_rad(25.0), 0.0)
	sun.light_energy = daylight * 0.8
	sun.visible = daylight > 0.02
	moon.rotation = Vector3(-t * TAU + PI, deg_to_rad(25.0), 0.0)
	moon.light_energy = (1.0 - daylight) * 0.18
	moon.visible = daylight < 0.98

	var underwater: bool = player.head_in_water
	sky_t -= delta
	if sky_t <= 0.0:
		sky_t = 0.2
		var day_top := Color(0.30, 0.52, 0.95)
		var day_hor := Color(0.68, 0.82, 1.0)
		var night_top := Color(0.01, 0.01, 0.05)
		var night_hor := Color(0.03, 0.04, 0.10)
		var top := night_top.lerp(day_top, daylight)
		var hor := night_hor.lerp(day_hor, daylight)
		var dusk := clampf(1.0 - absf(sn) * 2.5, 0.0, 1.0)
		hor = hor.lerp(Color(1.0, 0.55, 0.30), dusk * 0.55)
		sky_mat.sky_top_color = top
		sky_mat.sky_horizon_color = hor
		sky_mat.ground_horizon_color = hor
		sky_mat.ground_bottom_color = top.darkened(0.4)
		env.ambient_light_color = Color(0.55, 0.6, 0.85).lerp(Color(1, 1, 1), daylight)
		env.ambient_light_energy = 0.28 + 0.32 * daylight
		if underwater:
			env.fog_light_color = Color(0.08, 0.22, 0.5)
			env.fog_depth_begin = 0.0
			env.fog_depth_end = 16.0
		else:
			env.fog_light_color = hor
			env.fog_depth_begin = world.render_radius * 16.0 * 0.55
			env.fog_depth_end = world.render_radius * 16.0 * 0.98

	var night := daylight < 0.25
	if night and not was_night:
		ui.message("Die Nacht bricht herein – Monster kommen heraus! Bau dir einen Unterschlupf.")
	elif not night and was_night:
		ui.message("Ein neuer Tag beginnt. Zombies verbrennen in der Sonne.")
	was_night = night


# ---------------------------------------------------------------------------
# Kreaturen
func spawn_mob(kind: String, pos: Vector3, home := Vector3.ZERO):
	var m = MobScript.new()
	m.kind = kind
	m.world = world
	m.main = self
	m.player = player
	m.position = pos
	m.home = home if home != Vector3.ZERO else pos
	mobs_root.add_child(m)
	return m


func _on_village_ready(v: Dictionary) -> void:
	for sp in v["spawns"]:
		spawn_mob("villager", sp, sp)


func _spawn_tick(delta: float) -> void:
	spawn_t -= delta
	if spawn_t > 0.0:
		return
	spawn_t = 2.0
	if daylight >= 0.25 or player.dead:
		return
	var hostile := 0
	for m in mobs_root.get_children():
		if m.hostile:
			hostile += 1
	if hostile >= MAX_HOSTILE:
		return
	var a := randf() * TAU
	var d := randf_range(20.0, 40.0)
	var pp: Vector3 = player.global_position
	var x := floori(pp.x + cos(a) * d)
	var z := floori(pp.z + sin(a) * d)
	if not world.is_chunk_ready(Vector3(x, 0, z)):
		return
	var s: Vector2i = world.surface(x, z)
	if s.x < 0 or s.y == Blocks.WATER or s.y == Blocks.OAK_LEAVES:
		return
	var kind := "creeper" if randf() < 0.3 else "zombie"
	spawn_mob(kind, Vector3(x + 0.5, s.x + 1.05, z + 0.5))


func explode(center: Vector3, radius: float, source = null) -> void:
	var c := Vector3i(floori(center.x), floori(center.y), floori(center.z))
	var r := ceili(radius)
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var d := Vector3(dx, dy, dz).length()
				if d > radius - randf() * 0.8:
					continue
				var p := c + Vector3i(dx, dy, dz)
				var id: int = world.get_block(p.x, p.y, p.z)
				if id == Blocks.AIR or id == Blocks.BEDROCK or id == Blocks.WATER:
					continue
				if id == Blocks.TNT:
					world.set_block(p.x, p.y, p.z, Blocks.AIR)
					prime_tnt(p, randf_range(0.5, 1.5))
					continue
				if id == Blocks.CHEST or id == Blocks.FURNACE:
					chests.erase(p)
					furnaces.erase(p)
					world.loot_chests.erase(p)
				world.set_block(p.x, p.y, p.z, Blocks.AIR)
	var reach := radius * 2.0
	var pd: float = (player.global_position + Vector3(0, 0.9, 0)).distance_to(center)
	if pd < reach:
		player.invuln = 0.0
		player.take_damage(roundf((1.0 - pd / reach) * 18.0), center)
	for m in mobs_root.get_children():
		if m == source:
			continue
		var md: float = m.global_position.distance_to(center)
		if md < reach:
			m.hurt((1.0 - md / reach) * 18.0, center, null)


# ---------------------------------------------------------------------------
# Truhen & Öfen
func get_chest(p: Vector3i) -> Array:
	if not chests.has(p):
		var arr: Array = []
		arr.resize(27)
		arr.fill(null)
		if world.loot_chests.has(p):
			_fill_loot(arr, p)
			world.loot_chests.erase(p)
		chests[p] = arr
	return chests[p]


func _fill_loot(arr: Array, p: Vector3i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(p)
	var loot := [["apple", 1, 4], ["oak_planks", 2, 8], ["coal", 1, 5], ["torch", 2, 6], ["iron_ingot", 0, 3], ["stick", 1, 6], ["diamond", -4, 1]]
	for l in loot:
		var n := rng.randi_range(int(l[1]), int(l[2]))
		if n <= 0:
			continue
		var slot := rng.randi_range(0, 26)
		for k in 27:
			var idx := (slot + k) % 27
			if arr[idx] == null:
				arr[idx] = Items.make_stack(str(l[0]), n)
				break


func get_furnace(p: Vector3i) -> Dictionary:
	if not furnaces.has(p):
		furnaces[p] = {"slots": [null, null, null], "burn": 0.0, "burn_max": 0.0, "prog": 0.0}
	return furnaces[p]


## Liefert den Inhalt einer abgebauten Truhe/eines Ofens und entfernt ihn.
func take_container_items(p: Vector3i, id: int) -> Array:
	var out: Array = []
	if id == Blocks.CHEST:
		var arr: Array = get_chest(p)
		for s in arr:
			if s != null:
				out.append(s)
		chests.erase(p)
	elif id == Blocks.FURNACE and furnaces.has(p):
		for s in furnaces[p]["slots"]:
			if s != null:
				out.append(s)
		furnaces.erase(p)
	return out


func _tick_furnaces(delta: float) -> void:
	for f in furnaces.values():
		var s: Array = f["slots"]
		var inp = s[0]
		var out = s[2]
		var res := ""
		if inp != null and Recipes.smelting.has(inp["id"]):
			res = Recipes.smelting[inp["id"]]
		var can: bool = res != "" and (out == null or (out["id"] == res and int(out["count"]) < 64))
		if float(f["burn"]) > 0.0:
			f["burn"] = float(f["burn"]) - delta
		if float(f["burn"]) <= 0.0 and can and s[1] != null:
			var fuel: float = Items.items[s[1]["id"]]["fuel"]
			if fuel > 0.0:
				f["burn"] = fuel
				f["burn_max"] = fuel
				s[1]["count"] = int(s[1]["count"]) - 1
				if int(s[1]["count"]) <= 0:
					s[1] = null
		if float(f["burn"]) > 0.0 and can:
			f["prog"] = float(f["prog"]) + delta
			if float(f["prog"]) >= 10.0:
				f["prog"] = 0.0
				inp["count"] = int(inp["count"]) - 1
				if int(inp["count"]) <= 0:
					s[0] = null
				if out == null:
					s[2] = Items.make_stack(res, 1)
				else:
					out["count"] = int(out["count"]) + 1
		else:
			f["prog"] = maxf(float(f["prog"]) - delta * 2.0, 0.0)
