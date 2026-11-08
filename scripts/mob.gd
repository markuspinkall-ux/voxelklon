extends CharacterBody3D
## Kreaturen: Zombie (greift an, verbrennt am Tag), Creeper (zischt und explodiert)
## und Villager (laufen friedlich durchs Dorf, fliehen wenn man sie schlägt).
## Modelle werden aus einfachen Boxen gebaut (Minecraft-Stil).

const Blocks = preload("res://scripts/blocks.gd")

var kind := "zombie"
var world
var main
var player
var home := Vector3.ZERO
var health := 20.0
var hostile := true
var speed := 2.3
var height := 1.95
var model: Node3D
var legs: Array = []
var mats: Array = []
var hurt_t := 0.0
var attack_cd := 0.0
var wander_t := 0.0
var wander_target = null
var fuse := 0.0
var flee_t := 0.0
var anim := 0.0
var knock := Vector3.ZERO
var burn_t := 0.0
var last_flash := -1.0
var dead := false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.2
	match kind:
		"zombie":
			hostile = true
			speed = 2.3
			height = 1.95
		"creeper":
			hostile = true
			speed = 2.0
			height = 1.7
		"villager":
			hostile = false
			speed = 1.3
			height = 1.9
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = height
	cs.shape = cap
	cs.position = Vector3(0, height * 0.5, 0)
	add_child(cs)
	model = Node3D.new()
	add_child(model)
	match kind:
		"zombie":
			_build_zombie()
		"creeper":
			_build_creeper()
		"villager":
			_build_villager()
	if home == Vector3.ZERO:
		home = global_position
	rotation.y = randf() * TAU


# ---------------------------------------------------------------------------
# Modelle
func _part(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	mats.append([mat, col])
	return mi


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _build_zombie() -> void:
	var skin := Color(0.33, 0.56, 0.30)
	var shirt := Color(0.12, 0.55, 0.62)
	var pants := Color(0.25, 0.25, 0.62)
	for sx in [-1.0, 1.0]:
		var lp := _pivot(model, Vector3(0.125 * sx, 0.75, 0))
		_part(lp, Vector3(0.25, 0.75, 0.25), Vector3(0, -0.375, 0), pants)
		legs.append(lp)
		var ap := _pivot(model, Vector3(0.375 * sx, 1.375, 0))
		_part(ap, Vector3(0.25, 0.7, 0.25), Vector3(0, -0.3, 0), skin)
		ap.rotation.x = PI / 2.0
	_part(model, Vector3(0.5, 0.75, 0.25), Vector3(0, 1.125, 0), shirt)
	_part(model, Vector3(0.5, 0.5, 0.5), Vector3(0, 1.75, 0), skin)
	_part(model, Vector3(0.1, 0.06, 0.02), Vector3(-0.11, 1.78, -0.26), Color(0.05, 0.12, 0.05))
	_part(model, Vector3(0.1, 0.06, 0.02), Vector3(0.11, 1.78, -0.26), Color(0.05, 0.12, 0.05))


func _build_creeper() -> void:
	var g := Color(0.30, 0.68, 0.28)
	for p in [Vector2(-0.125, -0.15), Vector2(0.125, -0.15), Vector2(-0.125, 0.15), Vector2(0.125, 0.15)]:
		var lp := _pivot(model, Vector3(p.x, 0.375, p.y))
		_part(lp, Vector3(0.25, 0.375, 0.25), Vector3(0, -0.1875, 0), g.darkened(0.15))
		legs.append(lp)
	_part(model, Vector3(0.5, 0.75, 0.3), Vector3(0, 0.75, 0), g)
	_part(model, Vector3(0.5, 0.5, 0.5), Vector3(0, 1.375, 0), g.lightened(0.05))
	var black := Color(0.04, 0.06, 0.04)
	_part(model, Vector3(0.12, 0.12, 0.02), Vector3(-0.12, 1.45, -0.26), black)
	_part(model, Vector3(0.12, 0.12, 0.02), Vector3(0.12, 1.45, -0.26), black)
	_part(model, Vector3(0.12, 0.16, 0.02), Vector3(0, 1.30, -0.26), black)


func _build_villager() -> void:
	var robe := Color(0.45, 0.30, 0.18)
	var skin := Color(0.78, 0.58, 0.44)
	for sx in [-1.0, 1.0]:
		var lp := _pivot(model, Vector3(0.11 * sx, 0.4, 0))
		_part(lp, Vector3(0.2, 0.4, 0.2), Vector3(0, -0.2, 0), robe.darkened(0.3))
		legs.append(lp)
	_part(model, Vector3(0.5, 0.95, 0.32), Vector3(0, 0.875, 0), robe)
	_part(model, Vector3(0.5, 0.55, 0.5), Vector3(0, 1.625, 0), skin)
	_part(model, Vector3(0.12, 0.24, 0.12), Vector3(0, 1.5, -0.31), skin.darkened(0.08))
	_part(model, Vector3(0.08, 0.06, 0.02), Vector3(-0.13, 1.68, -0.26), Color(0.1, 0.45, 0.15))
	_part(model, Vector3(0.08, 0.06, 0.02), Vector3(0.13, 1.68, -0.26), Color(0.1, 0.45, 0.15))
	_part(model, Vector3(0.56, 0.18, 0.22), Vector3(0, 1.05, -0.24), robe.darkened(0.12))


# ---------------------------------------------------------------------------
# KI & Physik
func _physics_process(delta: float) -> void:
	if dead or not world.is_chunk_ready(global_position):
		return
	attack_cd -= delta
	hurt_t -= delta
	flee_t -= delta
	var dir := Vector3.ZERO
	var spd := speed
	var to_p: Vector3 = player.global_position - global_position
	var dist := to_p.length()
	var flat := Vector3(to_p.x, 0.0, to_p.z)
	var p_dead: bool = player.dead
	match kind:
		"zombie":
			if not p_dead and dist < 24.0:
				if flat.length() > 0.8:
					dir = flat.normalized()
				if dist < 1.7 and absf(to_p.y) < 1.6 and attack_cd <= 0.0:
					player.take_damage(3.0, global_position)
					attack_cd = 1.0
			else:
				dir = _wander(delta, 10.0)
			_sun_burn(delta)
		"creeper":
			if not p_dead and dist < 3.0:
				fuse += delta
				if fuse >= 1.5:
					_explode()
					return
			else:
				fuse = maxf(fuse - delta, 0.0)
				if not p_dead and dist < 16.0 and flat.length() > 0.5:
					dir = flat.normalized()
				else:
					dir = _wander(delta, 10.0)
		"villager":
			if flee_t > 0.0 and flat.length() > 0.01:
				dir = -flat.normalized()
				spd = 3.6
			else:
				dir = _wander(delta, 9.0)
				if dir == Vector3.ZERO and dist < 5.0:
					_face(flat)

	var in_water: bool = world.get_block_v(global_position + Vector3(0, 0.6, 0)) == Blocks.WATER
	var tgt := dir * spd + knock
	knock = knock.move_toward(Vector3.ZERO, 10.0 * delta)
	velocity.x = tgt.x
	velocity.z = tgt.z
	if in_water:
		velocity.y = minf(velocity.y + 14.0 * delta, 2.0)
	elif not is_on_floor():
		velocity.y = maxf(velocity.y - 28.0 * delta, -50.0)
	elif dir != Vector3.ZERO and is_on_wall():
		velocity.y = 8.6
	move_and_slide()
	if dir.length() > 0.01:
		_face(dir)
	_animate(delta, dir.length() > 0.01)
	if (hostile and dist > 100.0) or global_position.y < -20.0:
		queue_free()


func _wander(delta: float, radius: float) -> Vector3:
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = randf_range(3.0, 7.0)
		if randf() < 0.65:
			var a := randf() * TAU
			var r := randf() * radius
			var base := home if kind == "villager" else global_position
			wander_target = base + Vector3(cos(a) * r, 0.0, sin(a) * r)
		else:
			wander_target = null
	if wander_target == null:
		return Vector3.ZERO
	var d: Vector3 = wander_target - global_position
	d.y = 0.0
	if d.length() < 0.6:
		wander_target = null
		return Vector3.ZERO
	return d.normalized()


func _face(d: Vector3) -> void:
	if d.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), 0.2)


func _animate(delta: float, moving: bool) -> void:
	if moving:
		anim += delta * 8.0
	else:
		anim = 0.0
	var sw := sin(anim) * 0.6 if moving else 0.0
	for i in legs.size():
		var l: Node3D = legs[i]
		l.rotation.x = sw if i % 2 == 0 else -sw


func _process(_delta: float) -> void:
	var flash := 0.0
	var fc := Color(1.0, 0.2, 0.2)
	if hurt_t > 0.0:
		flash = 0.6
	if kind == "creeper" and fuse > 0.0:
		var f := (sin(fuse * 20.0) * 0.5 + 0.5) * (fuse / 1.5)
		if f > flash:
			flash = f
			fc = Color(1, 1, 1)
		model.scale = Vector3.ONE * (1.0 + fuse * 0.12)
	elif model != null:
		model.scale = Vector3.ONE
	if absf(flash - last_flash) > 0.01:
		last_flash = flash
		for m in mats:
			var mat: StandardMaterial3D = m[0]
			mat.albedo_color = (m[1] as Color).lerp(fc, flash)


func _sun_burn(delta: float) -> void:
	if main.daylight > 0.6 and world.sky_exposed(global_position + Vector3(0, height, 0)):
		burn_t += delta
		if burn_t >= 1.0:
			burn_t = 0.0
			hurt(2.0, global_position, null)
	else:
		burn_t = 0.0


func hurt(amount: float, from_pos: Vector3, attacker) -> void:
	if dead:
		return
	health -= amount
	hurt_t = 0.3
	var k := global_position - from_pos
	k.y = 0.0
	if k.length() > 0.01:
		knock = k.normalized() * 6.0
		velocity.y = 4.5
	if kind == "villager":
		flee_t = 4.0
	if kind == "creeper":
		fuse = 0.0
	if health <= 0.0:
		_die(attacker)


func _die(attacker) -> void:
	dead = true
	if attacker != null and attacker == player:
		var n := randi() % 3
		if kind == "zombie" and n > 0:
			player.give_item("rotten_flesh", n)
		elif kind == "creeper" and n > 0:
			player.give_item("gunpowder", n)
	queue_free()


func _explode() -> void:
	dead = true
	main.explode(global_position + Vector3(0, 0.8, 0), 3.2, self)
	queue_free()
