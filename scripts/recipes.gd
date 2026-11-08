extends RefCounted
## Handwerks- und Ofenrezepte (nach den originalen Minecraft-Rezepten).
## Geformte Rezepte dürfen – wie im Original – an beliebiger Stelle im Raster
## liegen und gespiegelt werden.

const Items = preload("res://scripts/items.gd")

static var shaped: Array = []
static var shapeless: Array = []
static var smelting: Dictionary = {}


static func setup() -> void:
	if shaped.size() > 0:
		return
	# --- Formlos ---
	_sl(["oak_log"], "oak_planks", 4)
	_sl(["iron_block"], "iron_ingot", 9)
	_sl(["diamond_block"], "diamond", 9)
	_sl(["coal_block"], "coal", 9)

	# --- Grundlagen ---
	_s(["P", "P"], {"P": "oak_planks"}, "stick", 4)
	_s(["PP", "PP"], {"P": "oak_planks"}, "crafting_table", 1)
	_s(["PPP", "P P", "PPP"], {"P": "oak_planks"}, "chest", 1)
	_s(["CCC", "C C", "CCC"], {"C": "cobblestone"}, "furnace", 1)
	_s(["C", "S"], {"C": ["coal", "charcoal"], "S": "stick"}, "torch", 4)

	# --- Werkzeuge & Waffen ---
	var mats := {"wooden": "oak_planks", "stone": "cobblestone", "iron": "iron_ingot", "diamond": "diamond"}
	for m in mats:
		var k := {"M": mats[m], "S": "stick"}
		_s(["MMM", " S ", " S "], k, str(m) + "_pickaxe", 1)
		_s(["MM", "MS", " S"], k, str(m) + "_axe", 1)
		_s(["M", "S", "S"], k, str(m) + "_shovel", 1)
		_s(["M", "M", "S"], k, str(m) + "_sword", 1)

	# --- Sonstiges ---
	_s(["I I", " I "], {"I": "iron_ingot"}, "bucket", 1)
	_s(["SS", "SS"], {"S": "stone"}, "stone_bricks", 4)
	_s(["SS", "SS"], {"S": "sand"}, "sandstone", 1)
	_s(["SS", "SS"], {"S": "snowball"}, "snow_block", 1)
	_s(["III", "III", "III"], {"I": "iron_ingot"}, "iron_block", 1)
	_s(["DDD", "DDD", "DDD"], {"D": "diamond"}, "diamond_block", 1)
	_s(["CCC", "CCC", "CCC"], {"C": "coal"}, "coal_block", 1)

	# --- Ofen ---
	smelting = {
		"raw_iron": "iron_ingot",
		"iron_ore": "iron_ingot",
		"sand": "glass",
		"cobblestone": "stone",
		"oak_log": "charcoal",
	}


static func _s(pattern: Array, key: Dictionary, out: String, count: int) -> void:
	shaped.append({"pattern": pattern, "key": key, "out": out, "count": count})


static func _sl(ing: Array, out: String, count: int) -> void:
	shapeless.append({"ing": ing, "out": out, "count": count})


## ids: Item-IDs des Rasters ("" = leer), Zeile für Zeile; w = Rasterbreite (2 oder 3)
static func match_grid(ids: Array, w: int) -> Dictionary:
	var minx := w
	var miny := w
	var maxx := -1
	var maxy := -1
	var used: Array = []
	for y in w:
		for x in w:
			var s: String = ids[y * w + x]
			if s != "":
				minx = mini(minx, x)
				miny = mini(miny, y)
				maxx = maxi(maxx, x)
				maxy = maxi(maxy, y)
				used.append(s)
	if maxx < 0:
		return {}
	var bw := maxx - minx + 1
	var bh := maxy - miny + 1
	for r in shaped:
		var p: Array = r["pattern"]
		if p.size() != bh or String(p[0]).length() != bw:
			continue
		for mirror in [false, true]:
			if _check(r, ids, w, minx, miny, bw, bh, mirror):
				return {"id": r["out"], "count": r["count"]}
	for r in shapeless:
		var ing: Array = r["ing"]
		if ing.size() != used.size():
			continue
		var rest := used.duplicate()
		var ok := true
		for i in ing:
			var idx := rest.find(i)
			if idx < 0:
				ok = false
				break
			rest.remove_at(idx)
		if ok:
			return {"id": r["out"], "count": r["count"]}
	return {}


static func _check(r: Dictionary, ids: Array, w: int, minx: int, miny: int, bw: int, bh: int, mirror: bool) -> bool:
	var p: Array = r["pattern"]
	var key: Dictionary = r["key"]
	for py in bh:
		var row: String = p[py]
		for px in bw:
			var ch := row[bw - 1 - px] if mirror else row[px]
			var have: String = ids[(miny + py) * w + minx + px]
			if ch == " ":
				if have != "":
					return false
				continue
			var want = key[ch]
			if want is Array:
				if not (want as Array).has(have):
					return false
			elif have != want:
				return false
	return true


static func _n(id) -> String:
	return Items.display_name(str(id))


## Text für das Rezeptbuch (BBCode)
static func describe() -> String:
	var lines := PackedStringArray()
	lines.append("[b]Rezeptbuch[/b]")
	lines.append("[i]Muster wie in Minecraft. · = leeres Feld. 3x3-Rezepte brauchen eine Werkbank.[/i]\n")
	lines.append("[u]Formlos (beliebige Position)[/u]")
	for r in shapeless:
		var parts := PackedStringArray()
		for i in r["ing"]:
			parts.append(_n(i))
		lines.append("- [b]%s[/b] x%d  =  %s" % [_n(r["out"]), int(r["count"]), " + ".join(parts)])
	lines.append("\n[u]Geformt[/u]")
	for r in shaped:
		var pat: Array = r["pattern"]
		var rows := PackedStringArray()
		var wide := pat.size() > 2
		for row in pat:
			var rs := String(row)
			if rs.length() > 2:
				wide = true
			rows.append(rs.replace(" ", "·"))
		var key: Dictionary = r["key"]
		var legend := PackedStringArray()
		for k in key:
			var v = key[k]
			var nm := ""
			if v is Array:
				var alt := PackedStringArray()
				for e in v:
					alt.append(_n(e))
				nm = " oder ".join(alt)
			else:
				nm = _n(v)
			legend.append("%s = %s" % [k, nm])
		var where := " (Werkbank)" if wide else ""
		lines.append("- [b]%s[/b] x%d%s:  [code]%s[/code]   %s" % [_n(r["out"]), int(r["count"]), where, " / ".join(rows), ", ".join(legend)])
	lines.append("\n[u]Ofen (oben Rohstoff, unten Brennstoff)[/u]")
	for k in smelting:
		lines.append("- %s  ->  [b]%s[/b]" % [_n(k), _n(smelting[k])])
	lines.append("\nBrennstoffe: Kohle, Holzkohle, Holz, Bretter, Stöcke, Holzwerkzeuge, Kohleblock")
	return "\n".join(lines)
