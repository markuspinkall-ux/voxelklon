extends CharacterBody3D
## Spieler: Bewegung (Laufen, Sprinten, Springen, Schwimmen), Abbauen mit
## Werkzeug-Geschwindigkeit, Platzieren, Kämpfen, Essen, Leben, Fallschaden, Ertrinken.

const Blocks = preload("res://scripts/blocks.gd")
const Items = preload("res://scripts/items.gd")
const Inventory = preload("res://scripts/inventory.gd")

const GRAVITY := 28.0
const JUMP := 8.6
const WALK := 4.3
const SPRINT := 5.8
const REACH := 5.0
const MOUSE_SENS := 0.0025
const WORLD_H := 80

var world
var main
var ui
var inventory = Inventory.new()
var head: Node3D
var camera: Camera3D
var highlight: MeshInstance3D
var selected := 0
var max_health := 20.0
var health := 20.0
var max_air := 10.0
var air := 10.0
var dead := false
var invuln := 0.0
var fall_top := 0.0
var knock := Vector3.ZERO
var mining_pos := Vector3i(0, -999, 0)
var mining_progress := 0.0
var mine_delay := 0.0
var use_cd := 0.0
var regen_t := 0.0
var drown_t := 0.0
var in_water := false
var head_in_water := false
var spawn_point := Vector3.ZERO
var target := {}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.2
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	head = Node3D.new()
	head.position = Vector3(0, 1.62, 0)
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.05
	camera.far = 400.0
	head.add_child(camera)
	camera.current = true
	highlight = _make_highlight()
	add_child(highlight)
	highlight.top_level = true
	fall_top = global_position.y
	rng.randomize()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _make_highlight() -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.05, 0.05, 0.05)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var s := 0.502
	var c := [Vector3(-s, -s, -s), Vector3(s, -s, -s), Vector3(s, -s, s), Vector3(-s, -s, s),
		Vector3(-s, s, -s), Vector3(s, s, -s), Vector3(s, s, s), Vector3(-s, s, s)]
	var edges := [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]]
	for e in edges:
		im.surface_add_vertex(c[e[0]])
		im.surface_add_vertex(c[e[1]])
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _unhandled_input(event: InputEvent) -> void:
	if dead or ui.is_open():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * MOUSE_SENS, -1.55, 1.55)
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			use_cd = 0.3
			mine_delay = 0.3
			return
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				selected = posmod(selected - 1, 9)
			MOUSE_BUTTON_WHEEL_DOWN:
				selected = posmod(selected + 1, 9)
			MOUSE_BUTTON_LEFT:
				_attack()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_9:
			selected = k - KEY_1
		elif k == KEY_Q:
			_drop_selected()


func _physics_process(delta: float) -> void:
	if dead:
		return
	if not world.is_chunk_ready(global_position):
		velocity = Vector3.ZERO
		return
	var input := Vector2.ZERO
	var active: bool = not ui.is_open() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if active:
		input = Input.get_vector("left", "right", "forward", "back")
	var wish := transform.basis * Vector3(input.x, 0.0, input.y)
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()
	in_water = world.get_block_v(global_position + Vector3(0, 0.5, 0)) == Blocks.WATER
	head_in_water = world.get_block_v(camera.global_position) == Blocks.WATER
	var spd := SPRINT if Input.is_action_pressed("sprint") else WALK
	if in_water:
		spd = 2.4
	var tgt := wish * spd + knock
	knock = knock.move_toward(Vector3.ZERO, 14.0 * delta)
	var accel := 50.0 if is_on_floor() else 16.0
	if in_water:
		accel = 20.0
	velocity.x = move_toward(velocity.x, tgt.x, accel * delta)
	velocity.z = move_toward(velocity.z, tgt.z, accel * delta)
	var jump: bool = active and Input.is_action_pressed("jump")
	if in_water:
		velocity.y = maxf(velocity.y - 9.0 * delta, -3.0)
		if jump:
			velocity.y = minf(velocity.y + 30.0 * delta, 3.5)
			if is_on_wall():
				velocity.y = 5.5
		fall_top = global_position.y
	else:
		if not is_on_floor():
			velocity.y = maxf(velocity.y - GRAVITY * delta, -60.0)
		elif jump:
			velocity.y = JUMP
	move_and_slide()
	if is_on_floor() or in_water:
		var fall := fall_top - global_position.y
		if fall > 3.5 and not in_water:
			take_damage(floorf(fall - 3.0), null)
		fall_top = global_position.y
	else:
		fall_top = maxf(fall_top, global_position.y)
	if global_position.y < -30.0:
		take_damage(1000.0, null)


func _process(delta: float) -> void:
	if dead:
		highlight.visible = false
		return
	invuln = maxf(invuln - delta, 0.0)
	use_cd -= delta
	mine_delay -= delta
	_update_air(delta)
	_update_regen(delta)

	var active: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not ui.is_open()
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	target = world.raycast(origin, dir, REACH)
	var hit: bool = target.get("hit", false)
	highlight.visible = hit
	if hit:
		highlight.global_position = Vector3(target["pos"]) + Vector3(0.5, 0.5, 0.5)

	var mob_hit := _ray_mob()
	var mob_closer := false
	if not mob_hit.is_empty():
		mob_closer = not hit or origin.distance_to(mob_hit["position"]) < float(target["dist"])

	if active and hit and not mob_closer and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and mine_delay <= 0.0:
		var p: Vector3i = target["pos"]
		if p != mining_pos:
			mining_pos = p
			mining_progress = 0.0
		var t := break_time(world.get_block(p.x, p.y, p.z))
		if t >= 0.0:
			if t <= 0.0:
				mining_progress = 1.0
			else:
				mining_progress += delta / t
			if mining_progress >= 1.0:
				_break(p)
				mining_progress = 0.0
				mining_pos = Vector3i(0, -999, 0)
				mine_delay = 0.15
	else:
		mining_progress = 0.0
		mining_pos = Vector3i(0, -999, 0)

	if active and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and use_cd <= 0.0:
		use_cd = 0.25
		_use()


# ---------------------------------------------------------------------------
# Abbauen
func _held():
	return inventory.slots[selected]


func _can_harvest(id: int) -> bool:
	var tier: int = Blocks.defs[id]["tier"]
	if tier < 0:
		return true
	var st = _held()
	if st == null:
		return false
	var it: Dictionary = Items.items[st["id"]]
	return it["tool"] == Blocks.defs[id]["tool"] and int(it["tier"]) >= tier


func break_time(id: int) -> float:
	var d: Dictionary = Blocks.defs[id]
	var hard: float = d["hardness"]
	if hard < 0.0:
		return -1.0
	if hard == 0.0:
		return 0.0
	var speed := 1.0
	var st = _held()
	if st != null:
		var it: Dictionary = Items.items[st["id"]]
		if it["tool"] != "" and it["tool"] == d["tool"]:
			speed = float(it["speed"])
	var mult := 1.5 if _can_harvest(id) else 5.0
	return hard * mult / speed


func _break(p: Vector3i) -> void:
	var id := world.get_block(p.x, p.y, p.z) as int
	var harvest := _can_harvest(id)
	if float(Blocks.defs[id]["hardness"]) > 0.0:
		_damage_tool()
	_remove_block(p, id, harvest)
	var above := p + Vector3i(0, 1, 0)
	var aid: int = world.get_block(above.x, above.y, above.z)
	if Blocks.kind[aid] == Blocks.CROSS:
		_remove_block(above, aid, true)
	world.fill_water_if_adjacent(p.x, p.y, p.z)


func _remove_block(p: Vector3i, id: int, give: bool) -> void:
	world.set_block(p.x, p.y, p.z, Blocks.AIR)
	if id == Blocks.CHEST or id == Blocks.FURNACE:
		for st in main.take_container_items(p, id):
			if not inventory.add_stack(st):
				ui.message("Inventar voll – Items verloren!")
	if give:
		for drop in Blocks.get_drops(id, rng):
			give_item(drop[0], drop[1])


func give_item(id: String, count: int) -> void:
	var left: int = inventory.add_item(id, count)
	if left > 0:
		ui.message("Inventar voll!")


func _damage_tool() -> void:
	var st = _held()
	if st == null or not st.has("dur"):
		return
	st["dur"] = int(st["dur"]) - 1
	if int(st["dur"]) <= 0:
		inventory.slots[selected] = null
		ui.message("Dein Werkzeug ist zerbrochen!")


func _consume_one() -> void:
	var st = _held()
	if st == null:
		return
	st["count"] = int(st["count"]) - 1
	if int(st["count"]) <= 0:
		inventory.slots[selected] = null


func _replace_one(new_id: String) -> void:
	var st = _held()
	if st != null and int(st["count"]) == 1:
		inventory.slots[selected] = Items.make_stack(new_id, 1)
	else:
		_consume_one()
		give_item(new_id, 1)


func _drop_selected() -> void:
	# Kein Item-Entity-System: Q wirft ein Item weg (löscht es)
	var st = _held()
	if st != null:
		_consume_one()
		ui.message("%s weggeworfen" % Items.display_name(st["id"]))


# ---------------------------------------------------------------------------
# Benutzen / Platzieren
func _use() -> void:
	var hit: bool = target.get("hit", false)
	var p := Vector3i.ZERO
	var n := Vector3i.ZERO
	if hit:
		p = target["pos"]
		n = target["normal"]
		var id: int = world.get_block(p.x, p.y, p.z)
		if id == Blocks.CRAFTING_TABLE:
			ui.open_crafting()
			use_cd = 0.5
			return
		if id == Blocks.CHEST:
			ui.open_chest(main.get_chest(p))
			use_cd = 0.5
			return
		if id == Blocks.FURNACE:
			ui.open_furnace(main.get_furnace(p))
			use_cd = 0.5
			return
	var st = _held()
	if st == null:
		return
	var sid: String = st["id"]
	var it: Dictionary = Items.items[sid]

	if int(it["food"]) > 0:
		if health < max_health:
			health = minf(max_health, health + float(it["food"]))
			_consume_one()
			ui.message("Mampf! +%d Leben" % int(it["food"]))
		return

	if sid == "bucket":
		var wh: Dictionary = world.raycast(camera.global_position, -camera.global_transform.basis.z, REACH, true)
		if wh.get("hit", false):
			var wp: Vector3i = wh["pos"]
			if world.get_block(wp.x, wp.y, wp.z) == Blocks.WATER:
				world.set_block(wp.x, wp.y, wp.z, Blocks.AIR)
				world.fill_water_if_adjacent(wp.x, wp.y, wp.z)
				_replace_one("water_bucket")
		return

	if not hit:
		return

	var place := p + n
	var hit_id: int = world.get_block(p.x, p.y, p.z)
	if hit_id == Blocks.SHORT_GRASS:
		place = p

	if sid == "water_bucket":
		if _replaceable(world.get_block(place.x, place.y, place.z)):
			world.set_block(place.x, place.y, place.z, Blocks.WATER)
			world.water_fall(place.x, place.y, place.z)
			_replace_one("bucket")
		return

	var b: int = it["block"]
	if b < 0:
		return
	if place.y < 1 or place.y >= WORLD_H:
		return
	if not _replaceable(world.get_block(place.x, place.y, place.z)):
		return
	if Blocks.kind[b] == Blocks.CROSS:
		var below: int = world.get_block(place.x, place.y - 1, place.z)
		if Blocks.solid[below] == 0 or Blocks.opaque[below] == 0:
			return
		if b != Blocks.TORCH and not (below == Blocks.GRASS or below == Blocks.DIRT or below == Blocks.SNOWY_GRASS):
			return
	elif Blocks.solid[b] == 1 and _intersects_body(place):
		return
	if b == Blocks.FURNACE or b == Blocks.CHEST:
		world.orient[place] = _facing_face()
	world.set_block(place.x, place.y, place.z, b)
	_consume_one()


func _replaceable(id: int) -> bool:
	return id == Blocks.AIR or id == Blocks.WATER or id == Blocks.SHORT_GRASS


func _intersects_body(t: Vector3i) -> bool:
	var pmin := global_position + Vector3(-0.3, 0.0, -0.3)
	var pmax := global_position + Vector3(0.3, 1.8, 0.3)
	return pmax.x > t.x and pmin.x < t.x + 1 and pmax.y > t.y and pmin.y < t.y + 1 and pmax.z > t.z and pmin.z < t.z + 1


## Vorderseite zeigt zum Spieler (Flächenindex wie in chunk.gd: 0 +X, 1 -X, 4 +Z, 5 -Z)
func _facing_face() -> int:
	var f := camera.global_transform.basis.z
	if absf(f.x) > absf(f.z):
		return 0 if f.x > 0.0 else 1
	return 4 if f.z > 0.0 else 5


# ---------------------------------------------------------------------------
# Kampf
func _ray_mob() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 3.5
	var q := PhysicsRayQueryParameters3D.create(from, to, 4)
	return space.intersect_ray(q)


func _attack() -> void:
	var res := _ray_mob()
	if res.is_empty():
		return
	var from := camera.global_position
	if target.get("hit", false) and float(target["dist"]) < from.distance_to(res["position"]):
		return
	var mob = res["collider"]
	if mob == null or not mob.has_method("hurt"):
		return
	var dmg := 1.0
	var st = _held()
	if st != null:
		dmg = float(Items.items[st["id"]]["damage"])
	if Input.is_action_pressed("sprint"):
		dmg += 1.0
	mob.hurt(dmg, global_position, self)
	_damage_tool()


func take_damage(amount: float, from_pos) -> void:
	if dead or invuln > 0.0 or amount <= 0.0:
		return
	health -= amount
	invuln = 0.5
	ui.flash_hurt()
	if from_pos != null:
		var d: Vector3 = global_position - from_pos
		d.y = 0.0
		if d.length() > 0.01:
			knock = d.normalized() * 7.0
		velocity.y = 5.0
	if health <= 0.0:
		health = 0.0
		_die()


func _die() -> void:
	dead = true
	mining_progress = 0.0
	ui.close()
	ui.show_death()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func respawn() -> void:
	dead = false
	health = max_health
	air = max_air
	invuln = 1.0
	knock = Vector3.ZERO
	velocity = Vector3.ZERO
	global_position = spawn_point
	fall_top = spawn_point.y
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _update_air(delta: float) -> void:
	if head_in_water:
		air -= delta
		if air <= 0.0:
			air = 0.0
			drown_t += delta
			if drown_t >= 1.0:
				drown_t = 0.0
				invuln = 0.0
				take_damage(2.0, null)
	else:
		air = minf(max_air, air + delta * 4.0)
		drown_t = 0.0


func _update_regen(delta: float) -> void:
	if health >= max_health:
		regen_t = 0.0
		return
	regen_t += delta
	if regen_t >= 4.0:
		regen_t = 0.0
		health = minf(max_health, health + 1.0)
