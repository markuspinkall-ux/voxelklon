extends RefCounted
## Block-Definitionen (IDs, Texturen, Härte, benötigtes Werkzeug, Drops)

const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const COBBLESTONE := 4
const OAK_LOG := 5
const OAK_PLANKS := 6
const OAK_LEAVES := 7
const SAND := 8
const WATER := 9
const GLASS := 10
const BEDROCK := 11
const COAL_ORE := 12
const IRON_ORE := 13
const DIAMOND_ORE := 14
const SNOW := 15
const CRAFTING_TABLE := 16
const FURNACE := 17
const CHEST := 18
const GRAVEL := 19
const STONE_BRICKS := 20
const SANDSTONE := 21
const IRON_BLOCK := 22
const DIAMOND_BLOCK := 23
const COAL_BLOCK := 24
const TORCH := 25
const POPPY := 26
const DANDELION := 27
const SHORT_GRASS := 28
const DIRT_PATH := 29
const SNOWY_GRASS := 30
const COUNT := 31

# Kachel-Indizes im Textur-Atlas (8x8 Kacheln à 16 px)
const T_GRASS_TOP := 0
const T_GRASS_SIDE := 1
const T_DIRT := 2
const T_STONE := 3
const T_COBBLE := 4
const T_LOG_SIDE := 5
const T_LOG_TOP := 6
const T_PLANKS := 7
const T_LEAVES := 8
const T_SAND := 9
const T_WATER := 10
const T_GLASS := 11
const T_BEDROCK := 12
const T_COAL_ORE := 13
const T_IRON_ORE := 14
const T_DIAMOND_ORE := 15
const T_SNOW := 16
const T_SNOW_SIDE := 17
const T_CT_TOP := 18
const T_CT_SIDE := 19
const T_FURNACE_FRONT := 20
const T_FURNACE_SIDE := 21
const T_FURNACE_TOP := 22
const T_CHEST_FRONT := 23
const T_CHEST_SIDE := 24
const T_CHEST_TOP := 25
const T_GRAVEL := 26
const T_STONE_BRICKS := 27
const T_SANDSTONE := 28
const T_IRON_BLOCK := 29
const T_DIAMOND_BLOCK := 30
const T_COAL_BLOCK := 31
const T_TORCH := 32
const T_POPPY := 33
const T_DANDELION := 34
const T_SHORT_GRASS := 35
const T_PATH_TOP := 36
const T_PATH_SIDE := 37
const T_SANDSTONE_TOP := 38

# Darstellungsarten
const CUBE := 0
const CROSS := 1
const LIQUID := 2

static var defs: Array = []
static var kind := PackedByteArray()
static var opaque := PackedByteArray()
static var solid := PackedByteArray()
static var tile_top := PackedInt32Array()
static var tile_bottom := PackedInt32Array()
static var tile_side := PackedInt32Array()
static var tile_front := PackedInt32Array()
static var _done := false


static func setup() -> void:
	if _done:
		return
	_done = true
	defs.resize(COUNT)
	kind.resize(COUNT)
	opaque.resize(COUNT)
	solid.resize(COUNT)
	tile_top.resize(COUNT)
	tile_bottom.resize(COUNT)
	tile_side.resize(COUNT)
	tile_front.resize(COUNT)
	#  id              item               Name                       Kacheln [oben, unten, Seite, (Front)]                       Art     fest   blickdicht Härte Werkzeug  Stufe
	_d(AIR, "", "Luft", [0, 0, 0], LIQUID, false, false, -1.0, "", -1)
	_d(GRASS, "grass_block", "Grasblock", [T_GRASS_TOP, T_DIRT, T_GRASS_SIDE], CUBE, true, true, 0.6, "shovel", -1)
	_d(DIRT, "dirt", "Erde", [T_DIRT, T_DIRT, T_DIRT], CUBE, true, true, 0.5, "shovel", -1)
	_d(STONE, "stone", "Stein", [T_STONE, T_STONE, T_STONE], CUBE, true, true, 1.5, "pickaxe", 0)
	_d(COBBLESTONE, "cobblestone", "Bruchstein", [T_COBBLE, T_COBBLE, T_COBBLE], CUBE, true, true, 2.0, "pickaxe", 0)
	_d(OAK_LOG, "oak_log", "Eichenstamm", [T_LOG_TOP, T_LOG_TOP, T_LOG_SIDE], CUBE, true, true, 2.0, "axe", -1)
	_d(OAK_PLANKS, "oak_planks", "Eichenholzbretter", [T_PLANKS, T_PLANKS, T_PLANKS], CUBE, true, true, 2.0, "axe", -1)
	_d(OAK_LEAVES, "oak_leaves", "Eichenlaub", [T_LEAVES, T_LEAVES, T_LEAVES], CUBE, true, false, 0.2, "", -1)
	_d(SAND, "sand", "Sand", [T_SAND, T_SAND, T_SAND], CUBE, true, true, 0.5, "shovel", -1)
	_d(WATER, "", "Wasser", [T_WATER, T_WATER, T_WATER], LIQUID, false, false, -1.0, "", -1)
	_d(GLASS, "glass", "Glas", [T_GLASS, T_GLASS, T_GLASS], CUBE, true, false, 0.3, "", -1)
	_d(BEDROCK, "bedrock", "Grundgestein", [T_BEDROCK, T_BEDROCK, T_BEDROCK], CUBE, true, true, -1.0, "", -1)
	_d(COAL_ORE, "coal_ore", "Steinkohleerz", [T_COAL_ORE, T_COAL_ORE, T_COAL_ORE], CUBE, true, true, 3.0, "pickaxe", 0)
	_d(IRON_ORE, "iron_ore", "Eisenerz", [T_IRON_ORE, T_IRON_ORE, T_IRON_ORE], CUBE, true, true, 3.0, "pickaxe", 1)
	_d(DIAMOND_ORE, "diamond_ore", "Diamanterz", [T_DIAMOND_ORE, T_DIAMOND_ORE, T_DIAMOND_ORE], CUBE, true, true, 3.0, "pickaxe", 2)
	_d(SNOW, "snow_block", "Schneeblock", [T_SNOW, T_SNOW, T_SNOW], CUBE, true, true, 0.2, "shovel", -1)
	_d(CRAFTING_TABLE, "crafting_table", "Werkbank", [T_CT_TOP, T_PLANKS, T_CT_SIDE], CUBE, true, true, 2.5, "axe", -1)
	_d(FURNACE, "furnace", "Ofen", [T_FURNACE_TOP, T_FURNACE_TOP, T_FURNACE_SIDE, T_FURNACE_FRONT], CUBE, true, true, 3.5, "pickaxe", 0)
	_d(CHEST, "chest", "Truhe", [T_CHEST_TOP, T_CHEST_TOP, T_CHEST_SIDE, T_CHEST_FRONT], CUBE, true, true, 2.5, "axe", -1)
	_d(GRAVEL, "gravel", "Kies", [T_GRAVEL, T_GRAVEL, T_GRAVEL], CUBE, true, true, 0.6, "shovel", -1)
	_d(STONE_BRICKS, "stone_bricks", "Steinziegel", [T_STONE_BRICKS, T_STONE_BRICKS, T_STONE_BRICKS], CUBE, true, true, 1.5, "pickaxe", 0)
	_d(SANDSTONE, "sandstone", "Sandstein", [T_SANDSTONE_TOP, T_SANDSTONE_TOP, T_SANDSTONE], CUBE, true, true, 0.8, "pickaxe", 0)
	_d(IRON_BLOCK, "iron_block", "Eisenblock", [T_IRON_BLOCK, T_IRON_BLOCK, T_IRON_BLOCK], CUBE, true, true, 5.0, "pickaxe", 1)
	_d(DIAMOND_BLOCK, "diamond_block", "Diamantblock", [T_DIAMOND_BLOCK, T_DIAMOND_BLOCK, T_DIAMOND_BLOCK], CUBE, true, true, 5.0, "pickaxe", 2)
	_d(COAL_BLOCK, "coal_block", "Kohleblock", [T_COAL_BLOCK, T_COAL_BLOCK, T_COAL_BLOCK], CUBE, true, true, 5.0, "pickaxe", 0)
	_d(TORCH, "torch", "Fackel", [T_TORCH, T_TORCH, T_TORCH], CROSS, false, false, 0.0, "", -1)
	_d(POPPY, "poppy", "Mohn", [T_POPPY, T_POPPY, T_POPPY], CROSS, false, false, 0.0, "", -1)
	_d(DANDELION, "dandelion", "Löwenzahn", [T_DANDELION, T_DANDELION, T_DANDELION], CROSS, false, false, 0.0, "", -1)
	_d(SHORT_GRASS, "short_grass", "Gras", [T_SHORT_GRASS, T_SHORT_GRASS, T_SHORT_GRASS], CROSS, false, false, 0.0, "", -1)
	_d(DIRT_PATH, "dirt_path", "Trampelpfad", [T_PATH_TOP, T_DIRT, T_PATH_SIDE], CUBE, true, true, 0.65, "shovel", -1)
	_d(SNOWY_GRASS, "snowy_grass", "Verschneiter Grasblock", [T_SNOW, T_DIRT, T_SNOW_SIDE], CUBE, true, true, 0.6, "shovel", -1)


static func _d(id: int, item: String, name: String, tiles: Array, k: int, is_solid: bool, is_opaque: bool, hardness: float, tool: String, tier: int) -> void:
	defs[id] = {"item": item, "name": name, "hardness": hardness, "tool": tool, "tier": tier}
	kind[id] = k
	solid[id] = 1 if is_solid else 0
	opaque[id] = 1 if is_opaque else 0
	tile_top[id] = tiles[0]
	tile_bottom[id] = tiles[1]
	tile_side[id] = tiles[2]
	if tiles.size() > 3:
		tile_front[id] = tiles[3]
	else:
		tile_front[id] = tiles[2]


## Was fällt beim Abbauen heraus? Liste aus [item_id, anzahl]
static func get_drops(id: int, rng: RandomNumberGenerator) -> Array:
	match id:
		GRASS, DIRT_PATH, SNOWY_GRASS:
			return [["dirt", 1]]
		STONE:
			return [["cobblestone", 1]]
		COAL_ORE:
			return [["coal", 1]]
		IRON_ORE:
			return [["raw_iron", 1]]
		DIAMOND_ORE:
			return [["diamond", 1]]
		OAK_LEAVES:
			var r := rng.randf()
			if r < 0.05:
				return [["apple", 1]]
			if r < 0.10:
				return [["stick", 1]]
			return []
		SNOW:
			return [["snowball", 4]]
		GLASS, SHORT_GRASS, WATER, BEDROCK, AIR:
			return []
	var it: String = defs[id]["item"]
	if it == "":
		return []
	return [[it, 1]]


static func display_name(id: int) -> String:
	return defs[id]["name"]
