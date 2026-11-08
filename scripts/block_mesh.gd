extends RefCounted
## Baut einen einzelnen texturierten Block als Mesh (für Hand, gezündetes TNT usw.)

const Blocks = preload("res://scripts/blocks.gd")
const ChunkScript = preload("res://scripts/chunk.gd")


static func build(b: int, size: float, mat: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for f in 6:
		var tile: int = Blocks.tile_side[b]
		if f == 2:
			tile = Blocks.tile_top[b]
		elif f == 3:
			tile = Blocks.tile_bottom[b]
		elif f == 4:
			tile = Blocks.tile_front[b]
		var u0 := float(tile % 8) * 0.125 + 0.0008
		var v0 := float(tile / 8) * 0.125 + 0.0008
		var u1 := u0 + 0.1234
		var v1 := v0 + 0.1234
		var c4: Array = ChunkScript.CORNERS[f]
		var base := verts.size()
		for k in 4:
			var c: Vector3 = c4[k]
			verts.append((c - Vector3(0.5, 0.5, 0.5)) * size)
			norms.append(ChunkScript.NORMALS[f])
			var sh: float = ChunkScript.SHADE[f]
			cols.append(Color(sh, sh, sh))
		if f == 2 or f == 3:
			uvs.append_array(PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]))
		else:
			uvs.append_array(PackedVector2Array([Vector2(u0, v1), Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1)]))
		idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, mat)
	return mesh
