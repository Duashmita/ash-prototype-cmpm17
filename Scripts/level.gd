extends Node2D
class_name Level

@export_file("*.tscn") var next_scene: String
@export_multiline var start_hint: String
@export var max_hop_tiles: int = 3

const CLIFF_TILES: Array[Vector2i] = [
	Vector2i(6, 0), Vector2i(6, 1), Vector2i(6, 2),
	Vector2i(7, 0), Vector2i(7, 1), Vector2i(7, 2),
]
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var layers: Array[TileMapLayer] = []
var chest: Chest


func _enter_tree() -> void:
	layers.clear()
	for node in find_children("*", "TileMapLayer"):
		layers.append(node)
	for node in get_children():
		if node is Chest:
			chest = node


static func of(node: Node) -> Level:
	while node != null and not node is Level:
		node = node.get_parent()
	return node


func _on_area_2d_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	if chest and not chest.is_open:
		body.show_hint("Not yet... follow the firefly to the chest.")
	elif next_scene.is_empty():
		body.show_hint("You made it out!", 5.0)
	else:
		get_tree().change_scene_to_file.call_deferred(next_scene)


func cell_at(world: Vector2) -> Vector2i:
	return layers[0].local_to_map(layers[0].to_local(world))


func cell_center(cell: Vector2i) -> Vector2:
	return layers[0].to_global(layers[0].map_to_local(cell))


func is_floor(world: Vector2) -> bool:
	for layer in layers:
		var c := layer.local_to_map(layer.to_local(world))
		if layer.get_cell_source_id(c) != -1 and not CLIFF_TILES.has(layer.get_cell_atlas_coords(c)):
			return true
	return false


func is_floor_cell(cell: Vector2i) -> bool:
	return is_floor(cell_center(cell))


func bounds() -> Rect2:
	var rect := Rect2()
	for layer in layers:
		var used := layer.get_used_rect()
		var size := Vector2(layer.tile_set.tile_size)
		var r := Rect2(layer.to_global(Vector2(used.position) * size), Vector2(used.size) * size)
		rect = r if rect.size == Vector2.ZERO else rect.merge(r)
	return rect


func can_hop(cell: Vector2i, dir: Vector2i) -> bool:
	return not is_floor_cell(cell + dir)


func hop_landing(cell: Vector2i, dir: Vector2i, side: int) -> Variant:
	if not can_hop(cell, dir):
		return null
	var perp := Vector2i(-dir.y, dir.x)
	for n in range(1, max_hop_tiles + 1):
		var c := cell + dir * n + perp * side
		if (side != 0 or n > 1) and is_floor_cell(c):
			return c
	return null


func hop_target(cell: Vector2i, facing: Vector2i, side: int = 1) -> Vector2i:
	var tries: Array = []
	if facing.x != 0 and facing.y != 0:
		var h := Vector2i(facing.x, 0)
		var v := Vector2i(0, facing.y)
		tries = [[h, facing.x * facing.y], [v, -facing.x * facing.y], [h, 0], [v, 0]]
	else:
		tries = [[facing, 0], [facing, side], [facing, -side]]
	for t in tries:
		var landing = hop_landing(cell, t[0], t[1])
		if landing != null:
			return landing
	return cell


func current_goal() -> Vector2:
	if chest and not chest.is_open:
		return chest.center()
	return $Area2D/CollisionShape2D.global_position


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := cell_at(from)
	var goal := cell_at(to)
	var area := bounds()
	var came_from := {start: start}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty() and not came_from.has(goal):
		var cell: Vector2i = queue.pop_front()
		var nexts: Array = []
		for dir in DIRS:
			if is_floor_cell(cell + dir):
				nexts.append(cell + dir)
			for side in [0, 1, -1]:
				nexts.append(hop_landing(cell, dir, side))
		for next in nexts:
			if next != null and not came_from.has(next) and area.has_point(cell_center(next)):
				came_from[next] = cell
				queue.append(next)
	var path := PackedVector2Array()
	if came_from.has(goal):
		var step := goal
		while step != start:
			path.insert(0, cell_center(step))
			step = came_from[step]
		path.insert(0, cell_center(start))
	return path
