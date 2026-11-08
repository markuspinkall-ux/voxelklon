extends RefCounted
## Spielerinventar: 36 Plätze (0-8 = Schnellleiste, 9-35 = Hauptinventar).
## Ein Platz ist null oder ein Dictionary {"id": String, "count": int, ("dur": int)}.

const Items = preload("res://scripts/items.gd")

const SIZE := 36

var slots: Array = []


func _init() -> void:
	slots.resize(SIZE)
	slots.fill(null)


## Fügt Items hinzu und gibt die Anzahl zurück, die nicht mehr gepasst hat.
func add_item(id: String, count: int) -> int:
	var maxs: int = Items.max_stack(id)
	if maxs > 1:
		for i in SIZE:
			var s = slots[i]
			if s != null and s["id"] == id and int(s["count"]) < maxs:
				var mv: int = mini(count, maxs - int(s["count"]))
				s["count"] = int(s["count"]) + mv
				count -= mv
				if count <= 0:
					return 0
	for i in SIZE:
		if slots[i] == null:
			var n: int = mini(count, maxs)
			slots[i] = Items.make_stack(id, n)
			count -= n
			if count <= 0:
				return 0
	return count


## Fügt einen kompletten Stapel ein (z.B. Werkzeug mit Haltbarkeit). true = alles untergebracht.
func add_stack(st: Dictionary) -> bool:
	if st.has("dur"):
		for i in SIZE:
			if slots[i] == null:
				slots[i] = st
				return true
		return false
	return add_item(st["id"], int(st["count"])) == 0
