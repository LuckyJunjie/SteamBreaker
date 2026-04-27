extends Node

## Steam Breaker Resource Cache Autoload
## 资源预加载与缓存管理器

# ============================================
# Cache Storage / 缓存存储
# ============================================
var _companions_cache: Dictionary = {}
var _bounties_cache: Dictionary = {}
var _parts_cache: Dictionary = {}
var _skills_cache: Dictionary = {}
var _ships_cache: Dictionary = {}
var _items_cache: Dictionary = {}

var _is_loaded: bool = false

# ============================================
# Initialization / 初始化
# ============================================

func _ready():
	print("[ResourceCache] Initializing resource cache...")
	_preload_all_resources()
	_is_loaded = true
	print("[ResourceCache] Cache ready.")

func _preload_all_resources() -> void:
	_preload_companions()
	_preload_bounties()
	_preload_parts()
	_preload_skills()
	_preload_ships()
	_preload_items()

# ============================================
# Companion Access / 伙伴资源访问
# ============================================

func _preload_companions() -> void:
	var companion_dir := "res://src/resources/companions/"
	var dir := DirAccess.open(companion_dir)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var path := companion_dir + file_name
				var comp: Resource = load(path)
				if comp and comp.get("companion_id"):
					_companions_cache[comp.companion_id] = comp
					print("[ResourceCache] Loaded companion: %s" % comp.companion_id)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_warning("[ResourceCache] Cannot open companions directory")

func get_companion(companion_id: String) -> Resource:
	return _companions_cache.get(companion_id)

func get_all_companions() -> Array[Resource]:
	return _companions_cache.values()

func get_companion_ids() -> Array[String]:
	return _companions_cache.keys()

func has_companion(companion_id: String) -> bool:
	return _companions_cache.has(companion_id)

# ============================================
# Bounty Access / 悬赏资源访问
# ============================================

func _preload_bounties() -> void:
	var bounty_dir := "res://src/resources/bounties/"
	var dir := DirAccess.open(bounty_dir)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var path := bounty_dir + file_name
				var bounty: Resource = load(path)
				if bounty and bounty.get("bounty_id"):
					_bounties_cache[bounty.bounty_id] = bounty
			file_name = dir.get_next()
		dir.list_dir_end()

func get_bounty(bounty_id: String) -> Resource:
	return _bounties_cache.get(bounty_id)

func get_all_bounties() -> Array[Resource]:
	return _bounties_cache.values()

func get_bounty_by_rank(rank: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for bounty in _bounties_cache.values():
		if bounty.get("rank") == rank:
			result.append(bounty)
	return result

# ============================================
# Ship Part Access / 船只配件访问
# ============================================

func _preload_parts() -> void:
	var part_dir := "res://src/resources/parts/"
	var dir := DirAccess.open(part_dir)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var path := part_dir + file_name
				var part: Resource = load(path)
				if part and part.get("part_id"):
					_parts_cache[part.part_id] = part
			file_name = dir.get_next()
		dir.list_dir_end()

func get_part(part_id: String) -> Resource:
	return _parts_cache.get(part_id)

func get_parts_by_type(part_type: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for part in _parts_cache.values():
		if part.get("part_type") == part_type:
			result.append(part)
	return result

# ============================================
# Skill Access / 技能资源访问
# ============================================

func _preload_skills() -> void:
	var skill_dir := "res://src/resources/skills/"
	var dir := DirAccess.open(skill_dir)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var path := skill_dir + file_name
				var skill: Resource = load(path)
				if skill and skill.get("skill_id"):
					_skills_cache[skill.skill_id] = skill
			file_name = dir.get_next()
		dir.list_dir_end()

func get_skill(skill_id: String) -> Resource:
	return _skills_cache.get(skill_id)

func get_all_skills() -> Array[Resource]:
	return _skills_cache.values()

# ============================================
# Ship Hull Access / 船体资源访问
# ============================================

func _preload_ships() -> void:
	var ship_dir := "res://src/resources/ships/"
	var dir := DirAccess.open(ship_dir)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var path := ship_dir + file_name
				var ship: Resource = load(path)
				if ship and ship.get("hull_id"):
					_ships_cache[ship.hull_id] = ship
			file_name = dir.get_next()
		dir.list_dir_end()

func get_ship_hull(hull_id: String) -> Resource:
	return _ships_cache.get(hull_id)

func get_all_ships() -> Array[Resource]:
	return _ships_cache.values()

# ============================================
# Item Access / 物品资源访问
# ============================================

func _preload_items() -> void:
	# Items may be in a dedicated items directory
	# Scan resources directory recursively for .tres files with item_id
	_scan_items_in_dir("res://src/resources/")
	# Fallback: hardcoded item definitions
	_items_cache["item_engine_oil"] = _make_simple_item("item_engine_oil", "机械润滑油", 50)
	_items_cache["item_gear_set"] = _make_simple_item("item_gear_set", "齿轮组", 80)
	_items_cache["item_rum"] = _make_simple_item("item_rum", "朗姆酒", 30)
	_items_cache["item_glowing_seaweed"] = _make_simple_item("item_glowing_seaweed", "发光海藻", 120)
	_items_cache["item_pearl"] = _make_simple_item("item_pearl", "珍珠", 200)
	_items_cache["item_thunder_rod"] = _make_simple_item("item_thunder_rod", "雷电棒", 150)

func _scan_items_in_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var full_path: String = dir_path.path_join(file_name)
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				_scan_items_in_dir(full_path)
		elif file_name.ends_with(".tres"):
			var res: Resource = load(full_path)
			if res and res.get("item_id"):
				_items_cache[res.item_id] = res
		file_name = dir.get_next()
	dir.list_dir_end()

func _make_simple_item(item_id: String, name: String, price: int) -> Dictionary:
	return {"item_id": item_id, "name": name, "price": price}

func get_item(item_id: String) -> Variant:
	return _items_cache.get(item_id)

func has_item(item_id: String) -> bool:
	return _items_cache.has(item_id)

# ============================================
# Utility Methods / 工具方法
# ============================================

func reload_all() -> void:
	_companions_cache.clear()
	_bounties_cache.clear()
	_parts_cache.clear()
	_skills_cache.clear()
	_ships_cache.clear()
	_items_cache.clear()
	_preload_all_resources()
	print("[ResourceCache] All resources reloaded")

func is_ready() -> bool:
	return _is_loaded

func get_cache_stats() -> Dictionary:
	return {
		"companions": _companions_cache.size(),
		"bounties": _bounties_cache.size(),
		"parts": _parts_cache.size(),
		"skills": _skills_cache.size(),
		"ships": _ships_cache.size(),
		"items": _items_cache.size(),
	}