extends Node3D
## Ein Chunk (16 x 80 x 16), aufgeteilt in 5 Abschnitte à 16 Blöcke Höhe.
## Jeder Abschnitt hat ein eigenes Mesh (fest / Pflanzen / Wasser) und eine
## eigene Kollisionsform, damit beim Abbauen nur ein kleiner Teil neu gebaut wird.

const Blocks = preload("res://scripts/blocks.gd")

const CS := 16
const H := 80
const SECTIONS := 5

const DX := [1, -1, 0, 0, 0, 0]
const DY := [0, 0, 1, -1, 0, 0]
const DZ := [0, 0, 0, 0, 1, -1]
const NORMALS := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
# Ecken je Fläche (im Uhrzeigersinn von außen gesehen = Godot-Vorderseite)
const CORNERS := [
	[Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0, 0)],
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	[Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, 0)],
	[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0)],
]
const SHADE := [0.80, 0.80, 1.0, 0.55, 0.68, 0.68]

var world
var cpos := Vector2i.ZERO
var sections: Array = []


class MeshBuf:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()

	func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, col: Color) -> void:
		var i := verts.size()
		verts.append(a)
		verts.append(b)
		verts.append(c)
		verts.append(d)
		for k in 4:
			norms.append(n)
			cols.append(col)
		uvs.append(ua)
		uvs.append(ub)
		uvs.append(uc)
		uvs.append(ud)
		idx.append(i)
		idx.append(i + 1)
		idx.append(i + 2)
		idx.append(i)
		idx.append(i + 2)
		idx.append(i + 3)

	func is_empty() -> bool:
		return verts.size() == 0

	func arrays() -> Array:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = verts
		a[Mesh.ARRAY_NORMAL] = norms
		a[Mesh.ARRAY_TEX_UV] = uvs
		a[Mesh.ARRAY_COLOR] = cols
		a[Mesh.ARRAY_INDEX] = idx
		return a


func build_all() -> void:
	for sy in SECTIONS:
		build_section(sy)


func build_section(sy: int) -> void:
	while sections.size() <= sy:
		sections.append({"nodes": []})
	var sec: Dictionary = sections[sy]
	for nd in sec["nodes"]:
		if is_instance_valid(nd):
			nd.queue_free()
	sec["nodes"] = []

	var data: PackedByteArray = world.chunk_data[cpos]
	var nxp: PackedByteArray = world.chunk_data.get(cpos + Vector2i(1, 0), PackedByteArray())
	var nxm: PackedByteArray = world.chunk_data.get(cpos + Vector2i(-1, 0), PackedByteArray())
	var nzp: PackedByteArray = world.chunk_data.get(cpos + Vector2i(0, 1), PackedByteArray())
	var nzm: PackedByteArray = world.chunk_data.get(cpos + Vector2i(0, -1), PackedByteArray())
	var maxy: int = world.chunk_maxy[cpos]
	var y0 := sy * 16
	var y1 := mini(y0 + 16, maxy + 1)
	if y1 <= y0:
		return

	var kind: PackedByteArray = Blocks.kind
	var opaque: PackedByteArray = Blocks.opaque
	var solid: PackedByteArray = Blocks.solid
	var t_top: PackedInt32Array = Blocks.tile_top
	var t_bot: PackedInt32Array = Blocks.tile_bottom
	var t_side: PackedInt32Array = Blocks.tile_side
	var t_front: PackedInt32Array = Blocks.tile_front

	var solid_buf := MeshBuf.new()
	var cross_buf := MeshBuf.new()
	var water_buf := MeshBuf.new()
	var col := PackedVector3Array()
	var torches: Array = []
	var wx0 := cpos.x * CS
	var wz0 := cpos.y * CS

	for y in range(y0, y1):
		for z in CS:
			for x in CS:
				var id: int = data[x + z * CS + y * 256]
				if id == 0:
					continue
				var k: int = kind[id]
				var p := Vector3(x, y, z)
				if k == Blocks.CROSS:
					_cross(cross_buf, p, t_side[id])
					if id == Blocks.TORCH:
						torches.append(p)
					continue
				var is_water := k == Blocks.LIQUID
				var buf: MeshBuf = water_buf if is_water else solid_buf
				var wh := 1.0
				if is_water and y + 1 < H and data[x + z * CS + (y + 1) * 256] != Blocks.WATER:
					wh = 0.875
				var front_face := -1
				if id == Blocks.FURNACE or id == Blocks.CHEST:
					front_face = world.orient.get(Vector3i(wx0 + x, y, wz0 + z), 4)
				for f in 6:
					var nx: int = x + DX[f]
					var ny: int = y + DY[f]
					var nz: int = z + DZ[f]
					var nid := 0
					if ny < 0:
						nid = Blocks.BEDROCK
					elif ny >= H:
						nid = 0
					elif nx < 0:
						nid = nxm[15 + nz * CS + ny * 256] if nxm.size() > 0 else 0
					elif nx >= CS:
						nid = nxp[nz * CS + ny * 256] if nxp.size() > 0 else 0
					elif nz < 0:
						nid = nzm[nx + 15 * CS + ny * 256] if nzm.size() > 0 else 0
					elif nz >= CS:
						nid = nzp[nx + ny * 256] if nzp.size() > 0 else 0
					else:
						nid = data[nx + nz * CS + ny * 256]
					if nid != 0:
						if opaque[nid] == 1 or nid == id:
							continue
					var tile: int
					if f == 2:
						tile = t_top[id]
					elif f == 3:
						tile = t_bot[id]
					elif f == front_face:
						tile = t_front[id]
					else:
						tile = t_side[id]
					_face(buf, f, p, tile, SHADE[f], wh)
					if solid[id] == 1:
						var c4: Array = CORNERS[f]
						var a: Vector3 = p + c4[0]
						var b: Vector3 = p + c4[1]
						var c: Vector3 = p + c4[2]
						var d: Vector3 = p + c4[3]
						col.append(a)
						col.append(b)
						col.append(c)
						col.append(a)
						col.append(c)
						col.append(d)

	var mesh := ArrayMesh.new()
	var pairs := [[solid_buf, world.mat_opaque], [cross_buf, world.mat_cross], [water_buf, world.mat_water]]
	for pair in pairs:
		var b: MeshBuf = pair[0]
		if b.is_empty():
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b.arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, pair[1])
	var nodes: Array = []
	if mesh.get_surface_count() > 0:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		add_child(mi)
		nodes.append(mi)
	if col.size() > 0:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(col)
		cs.shape = shape
		body.add_child(cs)
		add_child(body)
		nodes.append(body)
	for t in torches:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.78, 0.45)
		l.light_energy = 1.6
		l.omni_range = 9.0
		l.omni_attenuation = 1.2
		l.shadow_enabled = false
		l.position = (t as Vector3) + Vector3(0.5, 0.7, 0.5)
		add_child(l)
		nodes.append(l)
	sec["nodes"] = nodes


func _uv_base(tile: int) -> Vector2:
	return Vector2(float(tile % 8) * 0.125 + 0.0008, float(tile / 8) * 0.125 + 0.0008)


func _face(buf: MeshBuf, f: int, p: Vector3, tile: int, shade: float, wh: float) -> void:
	var c4: Array = CORNERS[f]
	var a: Vector3 = c4[0]
	var b: Vector3 = c4[1]
	var c: Vector3 = c4[2]
	var d: Vector3 = c4[3]
	if wh < 1.0:
		a.y *= wh
		b.y *= wh
		c.y *= wh
		d.y *= wh
	var uv := _uv_base(tile)
	var s := 0.1234
	var u0 := uv.x
	var v0 := uv.y
	var u1 := uv.x + s
	var v1 := uv.y + s
	var colr := Color(shade, shade, shade)
	var n: Vector3 = NORMALS[f]
	if f == 2 or f == 3:
		buf.add_quad(p + a, p + b, p + c, p + d, n, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1), colr)
	else:
		buf.add_quad(p + a, p + b, p + c, p + d, n, Vector2(u0, v1), Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), colr)


func _cross(buf: MeshBuf, p: Vector3, tile: int) -> void:
	var uv := _uv_base(tile)
	var s := 0.1234
	var ua := Vector2(uv.x, uv.y + s)
	var ub := Vector2(uv.x, uv.y)
	var uc := Vector2(uv.x + s, uv.y)
	var ud := Vector2(uv.x + s, uv.y + s)
	var w := Color(1, 1, 1)
	var o := 0.15
	var e := 0.85
	buf.add_quad(p + Vector3(o, 0, o), p + Vector3(o, 1, o), p + Vector3(e, 1, e), p + Vector3(e, 0, e), Vector3.UP, ua, ub, uc, ud, w)
	buf.add_quad(p + Vector3(o, 0, e), p + Vector3(o, 1, e), p + Vector3(e, 1, o), p + Vector3(e, 0, o), Vector3.UP, ua, ub, uc, ud, w)
