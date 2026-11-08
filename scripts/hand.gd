extends Node3D
## Ego-Perspektive: Arm bzw. gehaltenes Item unten rechts im Bild.
## Schwingt beim Abbauen (dauerhaft), Schlagen, Bauen und Essen; wippt beim Laufen.
## Leere Hand -> Arm, Block -> kleiner Würfel, Werkzeug/Item -> Pixel-Sprite.

const Blocks = preload("res://scripts/blocks.gd")
const Items = preload("res://scripts/items.gd")
const BlockMesh = preload("res://scripts/block_mesh.gd")

const BASE_POS := Vector3(0.40, -0.36, -0.58)
const SWING_TIME := 0.28

var player
var arm: MeshInstance3D
var item_root: Node3D
var item_node: Node3D = null
var current_id := "<keins>"
var swing_t := 1.0
var mining := false
var bob := 0.0


func _ready() -> void:
	position = BASE_POS
	arm = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.13, 0.13, 0.48)
	arm.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.66, 0.50)
	mat.roughness = 1.0
	arm.material_override = mat
	arm.position = Vector3(0.0, -0.03, 0.2)
	arm.rotation_degrees = Vector3(8, -12, 0)
	arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arm)
	item_root = Node3D.new()
	add_child(item_root)


## Einmal ausholen (Schlagen, Platzieren, Essen)
func swing() -> void:
	if swing_t > 0.35:
		swing_t = 0.0


func _process(delta: float) -> void:
	_refresh_item()
	if mining and swing_t >= 1.0:
		swing_t = 0.0
	swing_t = minf(swing_t + delta / SWING_TIME, 1.0)
	var s := sin(swing_t * PI)
	var s2 := sin(sqrt(swing_t) * PI)

	# Wippen beim Laufen
	var vel: Vector3 = player.velocity
	var spd := Vector2(vel.x, vel.z).length()
	var walking: bool = player.is_on_floor() and spd > 0.5
	if walking:
		bob += delta * spd * 2.4
	else:
		bob = lerpf(bob, round(bob / PI) * PI, minf(delta * 6.0, 1.0))
	var amt := clampf(spd / 4.3, 0.0, 1.0) if walking else 0.0
	var bx := sin(bob) * 0.014 * amt
	var by := -absf(cos(bob)) * 0.018 * amt

	position = BASE_POS + Vector3(-s2 * 0.13 + bx, s2 * 0.05 - s * 0.10 + by, -s2 * 0.10)
	rotation = Vector3(-s * 0.85, s2 * 0.55, -s * 0.25)


func _refresh_item() -> void:
	var st = player.inventory.slots[player.selected]
	var id: String = st["id"] if st != null else ""
	if id == current_id:
		return
	current_id = id
	if item_node != null:
		item_node.queue_free()
		item_node = null
	arm.visible = id == ""
	if id == "":
		return
	var b: int = Items.items[id]["block"]
	if b >= 0 and Blocks.kind[b] != Blocks.CROSS:
		item_node = _block_node(b)
	else:
		item_node = _sprite_node(id, Items.items[id]["tool"] != "")
	item_root.add_child(item_node)
	swing_t = 1.0


func _sprite_node(id: String, is_tool: bool) -> Node3D:
	var sp := Sprite3D.new()
	sp.texture = Items.icons[id]
	sp.pixel_size = 0.42 / 32.0
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sp.double_sided = true
	sp.shaded = true
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Griff (unten links im Icon) liegt in der Hand, Spitze zeigt nach vorne oben
	sp.position = Vector3(-0.02, 0.14, -0.06)
	if is_tool:
		sp.rotation_degrees = Vector3(0, -65, 18)
	else:
		sp.rotation_degrees = Vector3(0, -35, 0)
	return sp


func _block_node(b: int) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BlockMesh.build(b, 0.24, player.world.mat_opaque)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(-0.04, 0.06, -0.08)
	mi.rotation_degrees = Vector3(10, 40, 0)
	return mi
