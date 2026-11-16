extends CharacterBody2D
class_name Firefly

enum State { IDLE, GUIDE, SCOUT, BURST, CAUGHT }

static var collected := 0

@export var guide_target: NodePath

const SPEED := 45.0
const ATTACK_SPEED := 110.0
const SIGHT := 56.0
const NEAR := 40.0
const LEAD_TILES := 3

var state := State.IDLE
var home := Vector2.ZERO
var route := PackedVector2Array()
var route_age := 0.0
var bob := randf() * TAU

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	home = global_position
	sprite.play("flying")
	if not guide_target.is_empty():
		state = State.GUIDE
		add_to_group("guide_fireflies")


func _physics_process(delta: float) -> void:
	bob += delta * 4.0
	sprite.position.y = sin(bob) * 1.5
	var player: Player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	match state:
		State.IDLE: _idle(player, delta)
		State.GUIDE: _guide(player, delta)
		State.SCOUT: _scout(player, delta)


func _idle(player: Player, delta: float) -> void:
	if $Area2D.overlaps_body(player):
		catch()
	elif global_position.distance_to(player.global_position) < NEAR:
		var away := global_position + (global_position - player.global_position).normalized() * 8.0
		if away.distance_to(home) < 14.0:
			_fly_to(away, SPEED * 0.6, delta)
	else:
		_fly_to(home, SPEED * 0.3, delta)


func _guide(player: Player, delta: float) -> void:
	if global_position.distance_to(player.global_position) < NEAR:
		_fly_to(get_node(guide_target).global_position + Vector2(8, -6), SPEED, delta)


func _scout(player: Player, delta: float) -> void:
	var enemy := _enemy_in_sight()
	if enemy:
		_fly_to(enemy.global_position, ATTACK_SPEED, delta)
		if global_position.distance_to(enemy.global_position) < 6.0:
			var dir := (enemy.global_position - global_position).normalized()
			enemy.hit(dir)
			global_position -= dir * 20.0
		return

	route_age -= delta
	if route_age <= 0.0:
		route_age = 0.5
		var level := Level.of(self)
		route = level.find_path(player.feet(), level.current_goal())
	if route.size() <= 1:
		_fly_to(player.global_position + Vector2(0, -14), SPEED, delta)
	else:
		_fly_to(route[mini(LEAD_TILES, route.size() - 1)] + Vector2(0, -6), SPEED, delta)


func _enemy_in_sight() -> Node2D:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.dead and global_position.distance_to(enemy.global_position) < SIGHT:
			return enemy
	return null


func _fly_to(point: Vector2, speed: float, delta: float) -> void:
	global_position = global_position.move_toward(point, speed * delta)
	if absf(point.x - global_position.x) > 0.5:
		sprite.flip_h = point.x < global_position.x


func release() -> void:
	state = State.IDLE
	home = global_position


func catch() -> void:
	state = State.CAUGHT
	collected += 1
	if collected == 1:
		get_tree().get_first_node_in_group("player").show_hint("Press E to send a firefly ahead. It lights the way and fights slimes.", 4.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2(2, 2), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)
